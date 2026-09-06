class_name ChunkManager
extends Node3D
## Streams chunks in a square around the player. Generation is deterministic,
## so chunks can be freed aggressively and rebuilt identical later.

const CELL := WorldGen.CELL_SIZE
## Base visible neighbourhood. Owning room anchors are retained too, so a
## merged room never loses its furniture while one of its member cells remains.
const LOAD_R := 2
## One cell of hysteresis prevents boundary churn without retaining the former
## 9x9 worst-case neighbourhood near long-route objectives.
const UNLOAD_R := 3
## A complete authored chunk can already consume the frame's build allowance.
## Building only one per frame prevents three individually legal rooms from
## stacking into a visible hitch; the 3x3 warm-up keeps collision ahead safe.
const BUDGET := 1  # chunks built per frame; selection below assumes one
const BUILD_BUDGET_USEC := 3000
const LOOKAHEAD_SECONDS := 1.5
const WARM_R := 1  # 3x3 is enough collision coverage for a safe arrival
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
var _wanted := {}
var _ahead := {}
var _last_center := NO_BROKEN_STATION
var _last_ahead := NO_BROKEN_STATION
var _pending_chunk: Chunk
var _pending_cell := NO_BROKEN_STATION
var _chunks_since_prefetch := 0
var _pending_run_state: Array = []
var _staged_cells: Array[Vector2i] = []
var _staged_index := 0
var _staged_state := -1
var _staged_replacements := {}
var _staged_snapshots := {}
var _staged_ready := Callable()
var _staged_failed := Callable()
var _staged_committed := Callable()
var _broken_cell := NO_BROKEN_STATION
var _broken_cell_ready := false
## Floor-scoped durable state for runtime objects. Unlike resident chunks this
## registry survives streaming, including a reality where an object is absent
## and later mutates back into existence.
var _runtime_state := ChunkRuntimeState.new()
## Focused audit seam: fail before either old collision or staged nodes change.
var fail_next_staged_commit := false
static var _dev_timing := false


## While a floor transition is in flight the player node still stands at the
## OUTGOING floor's coordinates — the teleport happens only after the arrival
## probes pass. Streaming around that stale position freed the freshly warmed
## arrival chunks whenever the previous floor's lift room was more than
## UNLOAD_R cells from the new arrival (i.e. almost every real ride), so the
## probes ran against an empty physics world and every landing fell back to
## the raw requested point (root-caused 2026-08-22 via --test-ride). Until
## the player is actually near this focus, streaming follows it instead of
## the player; the first frame the player closes within LOAD_R it clears
## itself and normal player-centred streaming resumes.
var stream_focus := Vector3.INF


func warm_up(center: Vector2i) -> void:
	# Level changes happen behind a fade, but synchronously constructing 25
	# dense chunks still held the main thread for too long. Build the safe 3x3
	# neighbourhood now; the normal distance-sorted queue fills the 5x5 view.
	for dz in range(-WARM_R, WARM_R + 1):
		for dx in range(-WARM_R, WARM_R + 1):
			var c := center + Vector2i(dx, dz)
			if not chunks.has(c):
				_build(c)


func _process(_dt: float) -> void:
	if player == null or not player.is_inside_tree():
		return
	# A blackout gives us several fully obscured seconds. Spend at most one room
	# per frame preparing the next reality, and do not stack ordinary streaming
	# work on the same frame.
	if _process_staged_rebuild():
		return
	var pc := Vector2i(
		floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	if stream_focus != Vector3.INF:
		var fc := Vector2i(floori(stream_focus.x / CELL),
			floori(stream_focus.z / CELL))
		if _cheb(pc, fc) <= LOAD_R:
			stream_focus = Vector3.INF
		else:
			pc = fc

	var prediction := player.global_position
	if stream_focus != Vector3.INF:
		prediction = stream_focus
	elif player is CharacterBody3D:
		var motion: Vector3 = (player as CharacterBody3D).velocity * LOOKAHEAD_SECONDS
		motion.y = 0.0
		prediction += motion.limit_length(CELL * 0.9)
	var ahead_cell := Vector2i(floori(prediction.x / CELL), floori(prediction.z / CELL))
	if pc != _last_center or ahead_cell != _last_ahead:
		_last_center = pc
		_last_ahead = ahead_cell
		_wanted = _room_complete_cells(pc)
		_ahead = _room_complete_cells(ahead_cell)
		_refill_queue()


	if _pending_chunk != null and (chunks.has(_pending_cell) or
			(not _wanted.has(_pending_cell) and not _ahead.has(_pending_cell))):
		_cancel_pending()
	var run_state := _pending_run_state
	if _pending_chunk != null or not queued.is_empty():
		run_state = [descent_arrival_used, descent_lift_called, descent_lift_open,
			descent_tape_watched, descent_broken_station_tried, bleed, bleed_theme]
	if _pending_chunk != null and _pending_run_state != run_state:
		_cancel_pending()
	var loading_asset := FloorResourcePreloader.poll()
	if _pending_chunk == null and not queued.is_empty():
		var closest := NO_BROKEN_STATION
		var best := INF
		var stale: Array[Vector2i] = []
		for key in queued:
			var c: Vector2i = key
			if chunks.has(c) or (not _wanted.has(c) and not _ahead.has(c)):
				stale.append(c)
				continue
			var centre := Vector3((c.x + 0.5) * CELL, prediction.y, (c.y + 0.5) * CELL)
			var score := centre.distance_squared_to(prediction)
			if _cheb(c, pc) <= WARM_R:
				score -= 100000.0
			elif not _wanted.has(c):
				score += 100000.0
			if score < best or (score == best and
					(c.x < closest.x or (c.x == closest.x and c.y < closest.y))):
				closest = c
				best = score
		for c in stale:
			queued.erase(c)
		if closest != NO_BROKEN_STATION and (not loading_asset or _cheb(closest, pc) <= WARM_R):
			queued.erase(closest)
			_pending_run_state = run_state
			_pending_cell = closest
			_pending_chunk = Chunk.new(world_seed, closest, theme,
				_build_spec(closest), true)
			_pending_chunk.position = Vector3(closest.x * CELL, 0.0, closest.y * CELL)
	if _pending_chunk != null:
		var started := Time.get_ticks_usec()
		var urgent := _cheb(_pending_cell, pc) <= WARM_R or (descent_route != null and
			(_pending_cell == descent_route.target or _pending_cell == descent_route.origin))
		while true:
			if _pending_chunk.build_next_stage():
				var complete := _pending_chunk
				var at := _pending_cell
				_pending_chunk = null
				_pending_cell = NO_BROKEN_STATION
				_install_chunk(at, complete)
				_chunks_since_prefetch += 1
				break
			if not urgent and Time.get_ticks_usec() - started >= BUILD_BUDGET_USEC:
				break

	for c in chunks.keys():
		var ch := chunks[c] as Chunk
		var show: bool = _wanted.has(c)
		if ch.visible != show:
			ch.visible = show
		if _cheb(c, pc) > UNLOAD_R and not show and not _ahead.has(c):
			_capture_chunk_runtime(ch)
			ch.queue_free()
			chunks.erase(c)

	# Keep one decode in flight, between chunk builds. Never consume a request
	# before it completes or stack first-use decoding with ordinary generation.
	if _pending_chunk == null and (_chunks_since_prefetch >= 2 or queued.is_empty()):
		FloorResourcePreloader.request_next()
		_chunks_since_prefetch = 0


func _room_complete_cells(center: Vector2i) -> Dictionary:
	var cells := {}
	for dz in range(-LOAD_R, LOAD_R + 1):
		for dx in range(-LOAD_R, LOAD_R + 1):
			var at := center + Vector2i(dx, dz)
			cells[at] = true
			var corridor := WorldGen.annex_corridor_axis(world_seed, at) if theme == 2 \
				else WorldGen.corridor(world_seed, at)
			if corridor == 0:
				var anchor := WorldGen.annex_room_id(world_seed, at) if theme == 2 \
					else WorldGen.room_id(world_seed, at)
				cells[anchor] = true
	return cells


func _refill_queue() -> void:
	for cells in [_wanted, _ahead]:
		for c in cells:
			if not chunks.has(c) and c != _pending_cell:
				queued[c] = true


func _cancel_pending() -> void:
	if _pending_cell != NO_BROKEN_STATION and (_wanted.has(_pending_cell) or _ahead.has(_pending_cell)):
		queued[_pending_cell] = true
	if _pending_chunk != null:
		_pending_chunk.free()
		_pending_chunk = null
	_pending_cell = NO_BROKEN_STATION


func _install_chunk(c: Vector2i, chunk: Chunk) -> void:
	chunk.restore_runtime_state(_runtime_state.subset_for_cells([c]))
	chunk.set_blackout(blackout)
	# Added only to complete live chunks: fingerprints of authored geometry
	# stay comparable and PhotoDirector never observes half-built content.
	chunk.prepare_runtime_rendering()
	add_child(chunk)
	chunks[c] = chunk
	chunk_built.emit(chunk)


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _build(c: Vector2i, install := true,
		topology_state_override := -1) -> Chunk:
	var t0 := Time.get_ticks_usec()
	var spec := _build_spec(c, topology_state_override)
	var ch := Chunk.new(world_seed, c, theme, spec)
	if not install:
		ch.restore_runtime_state(_runtime_state.subset_for_cells([c]))
	if _dev_timing:
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if ms > 4.0:
			print("chunk %s built in %.1f ms (theme %d, style %d)" % [c, ms, theme, ch.style])
	ch.position = Vector3(c.x * CELL, 0.0, c.y * CELL)
	if install:
		_install_chunk(c, ch)
	return ch


func _build_spec(c: Vector2i, topology_state_override := -1) -> ChunkBuildSpec:
	var spec := ChunkBuildSpec.new()
	spec.player = player as Player
	if descent and descent_route != null:
		var optional_vhs := _is_optional_vhs_cell(c)
		spec.descent = true
		spec.casino_landmark = str(descent_route.casino_landmarks.get(
			WorldGen.room_id(world_seed, c), ""))
		spec.target = c == descent_route.target
		spec.target_wall = descent_route.target_wall
		spec.final = descent_floor_idx >= DescentRun.FLOOR_COUNT - 1
		spec.floor_idx = descent_floor_idx
		spec.anomaly = int(anomalies.get(c, -1))
		spec.topology = descent_topology
		spec.topology_state_override = topology_state_override
		spec.blackout = blackout
		spec.arrival = descent_route.origin_wall >= 0 and c == descent_route.origin
		spec.arrival_wall = descent_route.origin_wall
		spec.arrival_used = descent_arrival_used
		spec.lift_called = descent_lift_called
		spec.lift_wait = descent_lift_wait
		spec.lift_open = descent_lift_open
		spec.tape_watched = descent_tape_watched
		spec.base_seed = descent_base_seed
		spec.bleed = bleed
		spec.bleed_theme = bleed_theme
		spec.optional_vhs = optional_vhs
		spec.optional_vhs_key = "floor:%d:cell:%d:%d" % [
			descent_floor_idx, c.x, c.y] if optional_vhs else ""
		spec.broken_station = c == _broken_station_cell()
		spec.broken_station_tried = descent_broken_station_tried
		spec.player = player as Player
	return spec


## Prepare only rooms that are currently resident. Unloaded changed rooms have
## no scene or collision to replace and will naturally build from the committed
## topology later. The ready callback atomically accepts or rejects the staged
## set after the final room has constructed.
func stage_rebuild_cells(cells: Array[Vector2i], state_override: int,
		when_staged: Callable, when_failed := Callable(),
		when_committed := Callable()) -> bool:
	if not _staged_cells.is_empty() or state_override < 0 \
			or not when_staged.is_valid():
		return false
	_cancel_pending()
	var unique := {}
	for at in cells:
		if chunks.has(at) and is_instance_valid(chunks[at]):
			unique[at] = true
	if unique.is_empty():
		return false
	for key in unique:
		var at: Vector2i = key
		_staged_cells.append(at)
		queued.erase(at)
		var captured := (chunks[at] as Chunk).capture_runtime_state()
		_runtime_state.merge(captured)
		_staged_snapshots[at] = captured
	_staged_cells.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	_staged_index = 0
	_staged_state = state_override
	_staged_ready = when_staged
	_staged_failed = when_failed
	_staged_committed = when_committed
	return true


func _process_staged_rebuild() -> bool:
	if _staged_cells.is_empty():
		return false
	var at := _staged_cells[_staged_index]
	var replacement := _build(at, false, _staged_state)
	_staged_replacements[at] = replacement
	if not replacement.mutation_rebuild_valid():
		if _staged_failed.is_valid():
			_staged_failed.call("replacement failed furniture/doorway validation")
		_discard_staged_rebuild()
		return true
	_staged_index += 1
	if _staged_index < _staged_cells.size():
		return true
	var accepted := bool(_staged_ready.call())
	if accepted:
		var committed_callback := _staged_committed
		if _commit_staged_rebuild():
			if committed_callback.is_valid():
				committed_callback.call()
		else:
			if _staged_failed.is_valid():
				_staged_failed.call("atomic scene commit rejected")
			_discard_staged_rebuild()
	else:
		_discard_staged_rebuild()
	return true


func _commit_staged_rebuild() -> bool:
	if fail_next_staged_commit:
		fail_next_staged_commit = false
		return false
	# This is the last fallible gate. Do not remove a single old collider until
	# every replacement still exists and is ready to enter the tree.
	for at in _staged_cells:
		if not _staged_replacements.has(at) \
				or not is_instance_valid(_staged_replacements[at]):
			return false
	for at in _staged_cells:
		if chunks.has(at):
			var old := chunks[at] as Chunk
			chunks.erase(at)
			if is_instance_valid(old):
				remove_child(old)
				old.queue_free()
	for at in _staged_cells:
		var replacement := _staged_replacements[at] as Chunk
		replacement.descent_topology_state_override = -1
		replacement.prepare_runtime_rendering()
		add_child(replacement)
		chunks[at] = replacement
		var snapshot := _staged_snapshots.get(at, null) as ChunkRuntimeState
		if snapshot != null:
			replacement.restore_runtime_state(snapshot)
		replacement.restore_runtime_state(
			_runtime_state.subset_for_cells([at]))
		chunk_built.emit(replacement)
	_clear_staged_rebuild(false)
	return true


func _discard_staged_rebuild() -> void:
	_clear_staged_rebuild(true)


func _clear_staged_rebuild(free_replacements: bool) -> void:
	if free_replacements:
		for replacement in _staged_replacements.values():
			if is_instance_valid(replacement):
				(replacement as Chunk).free()
	_staged_cells.clear()
	_staged_index = 0
	_staged_state = -1
	_staged_replacements.clear()
	_staged_snapshots.clear()
	_staged_ready = Callable()
	_staged_failed = Callable()
	_staged_committed = Callable()


func _exit_tree() -> void:
	_cancel_pending()
	if not _staged_cells.is_empty():
		_discard_staged_rebuild()


func _is_optional_vhs_cell(c: Vector2i) -> bool:
	if not descent or descent_route == null \
			or c == descent_route.origin or c == descent_route.target:
		return false
	if descent_route.optional_vhs_cells().has(c):
		return true
	# Route frequency is explicitly authored above. Independent rolls here
	# would make a lucky route contain six televisions and another contain none.
	if descent_route.is_path_room(c):
		return false
	var room := WorldGen.annex_room_id(world_seed, c) if theme == 2 \
		else WorldGen.room_id(world_seed, c)
	# Merged-room furniture is owned by the anchor chunk, so only that chunk can
	# make an honest collision-aware placement decision for an off-route set.
	if room != c:
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
	# The objective and arrival rooms keep their honest power.
	if c == descent_route.target or c == descent_route.origin:
		c.x += 3
	_broken_cell = c
	return _broken_cell


func set_blackout(on: bool) -> void:
	if blackout != on:
		_cancel_pending()
	blackout = on
	for ch in chunks.values():
		if is_instance_valid(ch):
			(ch as Chunk).set_blackout(on)


func chunk_at(c: Vector2i) -> Chunk:
	if not chunks.has(c) or not is_instance_valid(chunks[c]):
		return null
	return chunks[c] as Chunk


func runtime_state_snapshot() -> ChunkRuntimeState:
	for chunk in chunks.values():
		if is_instance_valid(chunk):
			_capture_chunk_runtime(chunk as Chunk)
	return _runtime_state.copy()


func runtime_state_for_cells(cells: Array[Vector2i]) -> ChunkRuntimeState:
	for at in cells:
		var chunk := chunk_at(at)
		if chunk != null:
			_capture_chunk_runtime(chunk)
	return _runtime_state.subset_for_cells(cells)


func restore_runtime_state(state: ChunkRuntimeState) -> void:
	_runtime_state = state.copy() if state != null else ChunkRuntimeState.new()
	for key in chunks:
		var at: Vector2i = key
		var chunk := chunks[key] as Chunk
		if is_instance_valid(chunk):
			chunk.restore_runtime_state(
				_runtime_state.subset_for_cells([at]))


func restore_runtime_state_for_cells(state: ChunkRuntimeState,
		cells: Array[Vector2i]) -> void:
	if state != null:
		_runtime_state.merge(state)
	for at in cells:
		var chunk := chunk_at(at)
		if chunk != null:
			chunk.restore_runtime_state(
				_runtime_state.subset_for_cells([at]))


func runtime_object_descriptors(cells: Array[Vector2i]) -> Dictionary:
	var out := {}
	for at in cells:
		var chunk := chunk_at(at)
		if chunk != null:
			out.merge(chunk.runtime_object_descriptors(), true)
	return out


func staged_runtime_state() -> ChunkRuntimeState:
	var out := _runtime_state.subset_for_cells(_staged_cells)
	for replacement in _staged_replacements.values():
		if is_instance_valid(replacement):
			out.merge((replacement as Chunk).capture_runtime_state())
	return out


func staged_object_descriptors() -> Dictionary:
	var out := {}
	for replacement in _staged_replacements.values():
		if is_instance_valid(replacement):
			out.merge((replacement as Chunk).runtime_object_descriptors(), true)
	return out


func _capture_chunk_runtime(chunk: Chunk) -> void:
	if chunk != null and is_instance_valid(chunk):
		_runtime_state.merge(chunk.capture_runtime_state())


func set_anomaly(at: Vector2i, kind: int) -> void:
	if at == _pending_cell:
		_cancel_pending()
	anomalies[at] = kind
	if chunks.has(at) and is_instance_valid(chunks[at]):
		(chunks[at] as Chunk).activate_anomaly(kind)
