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

signal chunk_built(chunk: Chunk)

var world_seed := 1
var theme := 0
var player: Node3D
var descent := false
var descent_floor_idx := 0
var descent_route: DescentRoute
var blackout := false
var anomalies := {}
## Mirrored from DescentRun so a target or arrival room that streams out and
## back rebuilds in the state the run is actually in.
var descent_arrival_used := false
var descent_lift_called := false
var descent_lift_wait := 0.0
var descent_lift_open := false
var chunks := {}
var queued := {}
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
		config = {
			"descent": true,
			"target": c == descent_route.target,
			"target_wall": descent_route.target_wall,
			"final": descent_floor_idx >= DescentRun.ORDER.size() - 1,
			"floor_idx": descent_floor_idx,
			"anomaly": int(anomalies.get(c, -1)),
			"blackout": blackout,
			"arrival": descent_route.origin_wall >= 0 \
				and c == descent_route.origin,
			"arrival_wall": descent_route.origin_wall,
			"arrival_used": descent_arrival_used,
			"lift_called": descent_lift_called,
			"lift_wait": descent_lift_wait,
			"lift_open": descent_lift_open,
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
