class_name ChunkManager
extends Node3D
## Streams chunks in a square around the player. Generation is deterministic,
## so chunks can be freed aggressively and rebuilt identical later.

const CELL := 12.0
const LOAD_R := 3
const UNLOAD_R := 5
const BUDGET := 3  # chunks built per frame, closest first
const WARM_R := 1  # 3x3 is enough collision coverage for a safe arrival
const BUILD_SLICE_USEC := 6000  # stop streaming after roughly 6ms this frame
## 12m cells at a 6% hit rate produce one optional set per ~200m of newly
## explored off-route space. The authored objective route gets an exact 2–3
## instead; this roll only keeps the endless world going beyond it.
const OPTIONAL_VHS_CELL_RATE := 0.06
const OPTIONAL_VHS_SALT := 7349
## One charging station per run is dead. Never the first floor (the honest
## station has to be taught before it can lie), never the Poolrooms (its
## stations sit off the standard lattice) and never the final floor.
const BROKEN_STATION_FLOORS := [1, 2, 3, 4, 5, 6, 8, 9]
const NO_BROKEN_STATION := Vector2i(1 << 30, 1 << 30)

signal chunk_built(chunk: Chunk)

var world_seed := 1
var theme := 0
var player: Node3D
var descent := false
var descent_floor_idx := 0
var descent_route: DescentRoute
## One mutable resolver is shared by route guidance, rendered chunks and
## figures. WorldGen stays seed-pure; Descent's blackout openings live here.
var descent_topology: DescentTopology
var blackout := false
var anomalies := {}
## Mirrored from DescentRun so a target or arrival room that streams out and
## back rebuilds in the state the run is actually in.
var descent_arrival_used := false
var descent_lift_called := false
var descent_lift_wait := 0.0
var descent_lift_open := false
var descent_tape_watched := false
## The run's base seed, distinct from this manager's per-level world_seed.
## The tape deal is per-session, so the ritual needs the seed the whole run
## shares rather than the floor's derived one.
var descent_base_seed := 1
## One-way bleed toward the next floor, mirrored from the run: 0 builds a
## clean floor, 1 builds a floor already half-claimed by what is below it.
var bleed := 0.0
var bleed_theme := -1
## Whether the run's one dead station has already sprung, mirrored from
## DescentRun so a streamed-out trap rebuilds already-triggered.
var descent_broken_station_tried := false
var chunks := {}
var queued := {}
var _broken_cell := NO_BROKEN_STATION
var _broken_cell_ready := false
static var _dev_timing := false


func warm_up(center: Vector2i) -> void:
	# Level changes happen behind a fade, but synchronously constructing 25
	# dense chunks still held the main thread for too long. Build the safe 3x3
	# neighbourhood now; the normal distance-sorted queue fills the 7x7 view.
	for dz in range(-WARM_R, WARM_R + 1):
		for dx in range(-WARM_R, WARM_R + 1):
			var c := center + Vector2i(dx, dz)
			if not chunks.has(c):
				_build(c)


func _process(_dt: float) -> void:
	if player == null or not player.is_inside_tree():
		return
	var pc := Vector2i(
		floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))

	for dz in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var c := pc + Vector2i(dx, dz)
			if not chunks.has(c) and not queued.has(c):
				queued[c] = true

	if not queued.is_empty():
		var keys: Array = queued.keys()
		keys.sort_custom(func(a, b): return _cheb(a, pc) < _cheb(b, pc))
		var built := 0
		var slice_start := Time.get_ticks_usec()
		for c in keys:
			queued.erase(c)
			if _cheb(c, pc) > LOAD_R or chunks.has(c):
				continue
			_build(c)
			built += 1
			if built >= BUDGET or Time.get_ticks_usec() - slice_start >= BUILD_SLICE_USEC:
				break

	for c in chunks.keys():
		if _cheb(c, pc) > UNLOAD_R:
			chunks[c].queue_free()
			chunks.erase(c)


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _build(c: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var config := {}
	if descent and descent_route != null:
		var optional_vhs := _is_optional_vhs_cell(c)
		var ritual_cell := descent_route.objective_ritual_cell()
		config = {
			"descent": true,
			"target": c == descent_route.target,
			"target_wall": descent_route.target_wall,
			# Which cell hosts the objective altar (the target itself on most
			# floors), and whether this floor is one where they differ — the
			# target chunk words its refusal differently when the tape is not
			# in the room the player is standing in.
			"ritual_cell": c == ritual_cell,
			"ritual_remote": ritual_cell != descent_route.target,
			"final": descent_floor_idx >= DescentRun.FLOOR_COUNT - 1,
			"floor_idx": descent_floor_idx,
			"anomaly": int(anomalies.get(c, -1)),
			"topology": descent_topology,
			"blackout": blackout,
			"arrival": descent_route.origin_wall >= 0 \
				and c == descent_route.origin,
			"arrival_wall": descent_route.origin_wall,
			"arrival_used": descent_arrival_used,
			"lift_called": descent_lift_called,
			"lift_wait": descent_lift_wait,
			"lift_open": descent_lift_open,
			"tape_watched": descent_tape_watched,
			"base_seed": descent_base_seed,
			"bleed": bleed,
			"bleed_theme": bleed_theme,
			"optional_vhs": optional_vhs,
			"optional_vhs_key": "floor:%d:cell:%d:%d" % [
				descent_floor_idx, c.x, c.y] if optional_vhs else "",
			"broken_station": c == _broken_station_cell(),
			"broken_station_tried": descent_broken_station_tried,
		}
	# The waiting-figure anomaly builds a live figure during construction, so
	# its target has to be in the config rather than assigned afterwards.
	config["player"] = player
	var ch := Chunk.new(world_seed, c, theme, config)
	if _dev_timing:
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if ms > 4.0:
			print("chunk %s built in %.1f ms (theme %d, style %d)" % [c, ms, theme, ch.style])
	ch.position = Vector3(c.x * CELL, 0.0, c.y * CELL)
	add_child(ch)
	chunks[c] = ch
	chunk_built.emit(ch)


func _is_optional_vhs_cell(c: Vector2i) -> bool:
	if not descent or descent_route == null \
			or c == descent_route.origin or c == descent_route.target \
			or c == descent_route.objective_ritual_cell():
		return false
	if descent_route.optional_vhs_cells().has(c):
		return true
	# Route frequency is explicitly authored above. Independent rolls here
	# would make a lucky route contain six televisions and another contain none.
	if descent_route.is_path_cell(c):
		return false
	if theme == 9 and not Chunk.pool_style_dry(
			WorldGen.cell_style(world_seed, c, theme)):
		return false
	var has_wall := false
	for dir in 4:
		var edge := descent_topology.edge_info(c, dir) \
			if descent_topology != null else \
			WorldGen.edge_info(world_seed, c, dir, theme)
		if edge["wall"]:
			has_wall = true
			break
	if not has_wall:
		return false
	return WorldGen.r01(world_seed ^ descent_base_seed, c.x, c.y,
		OPTIONAL_VHS_SALT + descent_floor_idx * 17) < OPTIONAL_VHS_CELL_RATE


## The lattice cell whose station is the run's one dead unit, or the sentinel
## on every other floor. Deterministic from the run seed and the route: the
## floor is seeded, the cell is the station macro-cell nearest the 60% point
## of the path, so the trap sits where the player is actually likely to walk.
## Cached — the manager is rebuilt per level, so the cache is per floor.
func _broken_station_cell() -> Vector2i:
	if _broken_cell_ready:
		return _broken_cell
	_broken_cell_ready = true
	_broken_cell = NO_BROKEN_STATION
	if not descent or descent_route == null:
		return _broken_cell
	var pick: int = BROKEN_STATION_FLOORS[posmod(
		WorldGen.h(descent_base_seed, 77, 13, 5501),
		BROKEN_STATION_FLOORS.size())]
	if descent_floor_idx != pick:
		return _broken_cell
	var path := descent_route.path_from_origin()
	if path.size() < 8:
		return _broken_cell
	var p := path[int(float(path.size()) * 0.6)]
	# Snap to the station lattice (both axes ≡ 1 mod 3).
	var c := Vector2i(roundi(float(p.x - 1) / 3.0) * 3 + 1,
		roundi(float(p.y - 1) / 3.0) * 3 + 1)
	# The objective, arrival and remote-ritual rooms keep their honest power.
	if c == descent_route.target or c == descent_route.origin \
			or c == descent_route.objective_ritual_cell():
		c.x += 3
	_broken_cell = c
	return _broken_cell


func set_blackout(on: bool) -> void:
	blackout = on
	for ch in chunks.values():
		if is_instance_valid(ch):
			(ch as Chunk).set_blackout(on)


func chunk_at(c: Vector2i) -> Chunk:
	if not chunks.has(c) or not is_instance_valid(chunks[c]):
		return null
	return chunks[c] as Chunk


func set_anomaly(at: Vector2i, kind: int) -> void:
	anomalies[at] = kind
	if chunks.has(at) and is_instance_valid(chunks[at]):
		(chunks[at] as Chunk).activate_anomaly(kind)


## A runtime edge belongs to both neighbouring chunks. Remove both old scene
## trees immediately (so their collision leaves the world), then regenerate
## them from the shared topology while the blackout hides the operation.
func rebuild_cells(cells: Array[Vector2i]) -> void:
	var unique := {}
	for at in cells:
		unique[at] = true
	for key in unique:
		var at: Vector2i = key
		queued.erase(at)
		if chunks.has(at):
			var old := chunks[at] as Chunk
			chunks.erase(at)
			if is_instance_valid(old):
				remove_child(old)
				old.queue_free()
	for key in unique:
		var at: Vector2i = key
		_build(at)
