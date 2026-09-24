extends Node
## A seed-prepared solid wall tears into an actual generated doorway. The
## endpoint assemblies belong to Chunk; this node only owns the transition.

const Surface := preload("res://tools/lib/native_doorway_proof.gd")
const MOVE_SECONDS := Surface.TRANSITION_SECONDS
const OPEN_SECONDS := 5.5
# Prepared walls may be common; the supernatural reveal should not be.
const FIRST_COOLDOWN := Vector2(75.0, 120.0)
const REPEAT_COOLDOWN := Vector2(240.0, 360.0)
const SIGHT_HIT_TOLERANCE := 0.7

signal debug_notice(message: String)

var manager: ChunkManager
var player: Player
var pacing: HorrorDirector
var allowed: Callable
var active: Node3D
var near_chunk: Chunk
var far_chunk: Chunk
var site_cell := Vector2i.ZERO
var near_dir := -1
var elapsed := 0.0
var cooldown := 0.0
var events_started := 0
var debug_controls := false
## Normal gameplay is scheduled with the other architectural effects. Standalone
## previews and focused runtime audits retain the original local timer.
var managed := false
var _is_open := false
var _closing := false
var _audio: Node
var _rng := RandomNumberGenerator.new()
var _used: Dictionary = {}
var _last_attempt_reason := "no prepared wall nearby; explore another room"


func configure(cm: ChunkManager, actor: Player, director: HorrorDirector,
		gate: Callable, debug := false) -> void:
	manager = cm
	player = actor
	pacing = director
	allowed = gate
	debug_controls = debug
	_rng.seed = cm.world_seed ^ 0x646f6f72
	cooldown = INF if debug_controls else _rng.randf_range(
		FIRST_COOLDOWN.x, FIRST_COOLDOWN.y)
	process_physics_priority = -10
	_audio = preload("res://scripts/supernatural_audio.gd").new()
	add_child(_audio)
	if debug_controls: call_deferred("_announce_debug")


func _announce_debug() -> void:
	debug_notice.emit("DOORWAY TEST — face a solid wall 4–15m away; press F6")


func _input(event: InputEvent) -> void:
	if not debug_controls or not (event is InputEventKey) or not event.pressed \
			or event.echo: return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE \
		else event.keycode
	if key != KEY_F6: return
	# Breathing also uses F6, including a disabled-preview notice. A doorway
	# test owns this key for the lifetime of --doorway, across level changes.
	get_viewport().set_input_as_handled()
	if is_instance_valid(active):
		debug_notice.emit("DOORWAY — already transforming")
	elif not allowed.is_valid() or not allowed.call():
		debug_notice.emit("DOORWAY — waiting for a quiet moment")
	elif _try_nearby():
		debug_notice.emit("DOORWAY — hidden wall opening")
	else:
		debug_notice.emit("DOORWAY — " + _last_attempt_reason)


func _process(dt: float) -> void:
	if not is_instance_valid(active): return
	if not _site_resident():
		cancel()
		return
	elapsed += dt
	if not _is_open:
		active.opening = true
		active.pose(minf(1.0, elapsed / MOVE_SECONDS), false)
		if active.phase >= 1.0:
			_is_open = true
			manager.set_native_doorway_open(near_chunk.cell, near_dir, true)
	elif not _closing:
		if elapsed >= MOVE_SECONDS + OPEN_SECONDS and _can_close():
			_closing = true
			elapsed = 0.0
			manager.set_native_doorway_open(near_chunk.cell, near_dir, false)
	elif not _can_close():
		# A player or new threat entering the opening wins over the timer.
		_closing = false
		elapsed = MOVE_SECONDS + OPEN_SECONDS
		active.pose(1.0, false)
		manager.set_native_doorway_open(near_chunk.cell, near_dir, true)
	else:
		active.opening = false
		active.pose(maxf(0.0, 1.0 - elapsed / MOVE_SECONDS), false)
		if active.phase <= 0.0:
			_finish_closed()
			return
	_audio.set_in_view(player.cam.is_position_in_frustum(
		active.global_position + Vector3.UP * 1.2))


func _physics_process(dt: float) -> void:
	if is_instance_valid(active):
		if _site_resident(): active.sync_collision()
		else: cancel()
		return
	if managed: return
	if manager == null or player == null \
			or not allowed.is_valid() or not allowed.call(): return
	cooldown -= dt
	if cooldown > 0.0: return
	if not _try_nearby(): cooldown = 4.0


func try_visible_site() -> bool:
	if is_instance_valid(active) or manager == null or player == null \
			or not allowed.is_valid() or not allowed.call(): return false
	return _try_nearby()


func event_is_open() -> bool:
	return is_instance_valid(active) and _is_open


func _can_close() -> bool:
	return _site_resident() and allowed.is_valid() and allowed.call() \
		and not _player_near(active.global_position)


func _try_nearby() -> bool:
	var here := Vector2i(floori(player.global_position.x / ChunkManager.CELL),
		floori(player.global_position.z / ChunkManager.CELL))
	var candidates: Array[Dictionary] = []
	var prepared_nearby := false
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var cell := here + Vector2i(dx, dz)
			for dir in [0, 2]:
				if debug_controls and manager.native_doorway_plan != null \
					and not manager.native_doorway_plan.candidate(
					cell, dir).is_empty(): prepared_nearby = true
				if _eligible(cell, dir):
					candidates.append({"cell": cell, "dir": dir})
	if candidates.is_empty():
		_last_attempt_reason = "prepared walls in surrounding rooms; move or turn to face one from 4–15m" \
			if prepared_nearby else "no prepared wall nearby; explore another room"
		return false
	var choice: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	return start_event(choice["cell"], int(choice["dir"]))


func _eligible(cell: Vector2i, dir: int) -> bool:
	if dir not in [0, 2] or manager == null or player == null \
			or manager.native_doorway_plan == null: return false
	var other: Vector2i = cell + WorldGen.DIRV[dir]
	var first := manager.chunks.get(cell) as Chunk
	var second := manager.chunks.get(other) as Chunk
	if not _chunk_ready(first, cell) or not _chunk_ready(second, other): return false
	var plan := manager.native_doorway_plan
	var prepared := plan.candidate(cell, dir)
	if prepared.is_empty() or plan.is_open(cell, dir): return false
	var site := first.native_doorway_site(dir)
	var opposite := second.native_doorway_site(WorldGen.OPP[dir])
	if site.is_empty() or site.get("closed_nodes", []).is_empty() \
			or (opposite.is_empty() and not bool(site["single_owner"])): return false
	if not opposite.is_empty() and (not is_equal_approx(float(site["t"]),
			float(opposite["t"])) or not is_equal_approx(float(site["w"]),
			float(opposite["w"]))): return false
	if not is_equal_approx(float(site["floor"]), second._floor_h()): return false
	var key := NativeDoorwayPlan.edge_key(cell, dir)
	if _used.has(key) and not debug_controls: return false
	var centre := _site_centre(cell, dir, float(site["t"]),
		float(site["floor"]))
	var distance := player.global_position.distance_to(centre)
	if distance < 3.5 or distance > 15.0: return false
	if not player.cam.is_position_in_frustum(centre + Vector3.UP * 1.2): return false
	if not _wall_in_sight(centre, first, second): return false
	return first.doorway_clearance_violations() == 0 \
		and second.doorway_clearance_violations() == 0


func _wall_in_sight(centre: Vector3, first: Chunk, second: Chunk) -> bool:
	# A frustum check alone can select a prepared wall behind another room.
	# The first solid hit must be this doorway's own closed wall, near its
	# centre. Stop at the wall plane so its collision proves the visible face.
	var aim := centre + Vector3.UP * 1.2
	var ray := PhysicsRayQueryParameters3D.create(
		player.cam.global_position, aim)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return false
	return (hit["collider"] == first.body or hit["collider"] == second.body) \
		and (hit["position"] as Vector3).distance_to(aim) <= SIGHT_HIT_TOLERANCE


func start_event(cell: Vector2i, dir: int) -> bool:
	if is_instance_valid(active) or not _eligible(cell, dir) or not allowed.call():
		return false
	if pacing != null and not pacing.try_start_visual(
			MOVE_SECONDS * 2.0 + OPEN_SECONDS + 1.0, HorrorDirector.ARCHITECTURE_RECOVERY):
		_last_attempt_reason = "waiting for a quiet moment"
		return false
	near_chunk = manager.chunks[cell]
	far_chunk = manager.chunks[cell + WorldGen.DIRV[dir]]
	site_cell = cell
	near_dir = dir
	var site: Dictionary = near_chunk.native_doorway_site(dir)
	var surface := Surface.new()
	surface.magic_enabled = false
	surface.soft_deformation = true
	surface.position = _site_centre(cell, dir, float(site["t"]),
		float(site["floor"]))
	surface.rotation.y = PI / 2.0 if dir == 0 else 0.0
	get_parent().add_child(surface)
	surface.setup(near_chunk, far_chunk, dir, 0.0,
		float(site["w"]), float(site["t"]))
	active = surface
	elapsed = 0.0
	_is_open = false
	_closing = false
	_used[NativeDoorwayPlan.edge_key(cell, dir)] = true
	events_started += 1
	_audio.begin_event()
	return true


func _site_centre(cell: Vector2i, dir: int, along: float,
		floor_y: float) -> Vector3:
	return Vector3(float(cell.x + 1) * ChunkManager.CELL, floor_y,
		float(cell.y) * ChunkManager.CELL + along) if dir == 0 else \
		Vector3(float(cell.x) * ChunkManager.CELL + along, floor_y,
		float(cell.y + 1) * ChunkManager.CELL)


func _player_near(centre: Vector3) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(near_chunk):
		return false
	var site := near_chunk.native_doorway_site(near_dir)
	if site.is_empty(): return false
	var offset := player.global_position - centre
	var along := absf(offset.z) if near_dir == 0 else absf(offset.x)
	var across := absf(offset.x) if near_dir == 0 else absf(offset.z)
	return absf(offset.y) < 2.5 and across < 2.8 \
		and along < float(site["w"]) * 0.5 + 1.8


func _chunk_ready(chunk: Chunk, cell: Vector2i) -> bool:
	return is_instance_valid(chunk) and chunk.is_inside_tree() \
		and not chunk.is_queued_for_deletion() and manager.chunks.get(cell) == chunk


func _site_resident() -> bool:
	if not is_instance_valid(near_chunk) or not is_instance_valid(far_chunk):
		return false
	return _chunk_ready(near_chunk, near_chunk.cell) \
		and _chunk_ready(far_chunk, far_chunk.cell)


func _finish_closed() -> void:
	if _site_resident():
		active.pose(0.0)
		manager.set_native_doorway_open(near_chunk.cell, near_dir, false)
	active.queue_free()
	active = null
	near_chunk = null
	far_chunk = null
	near_dir = -1
	_audio.end_event()
	cooldown = INF if debug_controls else _rng.randf_range(
		REPEAT_COOLDOWN.x, REPEAT_COOLDOWN.y)


func cancel() -> void:
	if not is_instance_valid(active): return
	# An interrupted preparation never produced the promised doorway. Leave
	# this wall available for a later safe sighting on the same floor.
	if not _is_open:
		_used.erase(NativeDoorwayPlan.edge_key(site_cell, near_dir))
	if _site_resident():
		# Streaming or a mode transition may interrupt the beat. Preserve an
		# already usable passage; otherwise restore the original full wall.
		active.pose(1.0 if _is_open else 0.0)
	else:
		if is_instance_valid(near_chunk):
			near_chunk.show_native_doorway(near_dir, _is_open)
		if is_instance_valid(far_chunk):
			far_chunk.show_native_doorway(WorldGen.OPP[near_dir], _is_open)
	if is_instance_valid(manager):
		manager.set_native_doorway_open(site_cell, near_dir, _is_open)
	active.queue_free()
	active = null
	near_chunk = null
	far_chunk = null
	near_dir = -1
	_audio.end_event()
	cooldown = INF if debug_controls else _rng.randf_range(
		REPEAT_COOLDOWN.x, REPEAT_COOLDOWN.y)


func _exit_tree() -> void:
	cancel()
