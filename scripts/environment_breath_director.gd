extends Node
## One reversible architectural beat at a time. No topology or saved-state edits.
signal debug_notice(message: String)
const Placement := preload("res://scripts/environment_breath_placement.gd")
const Profile := preload("res://scripts/environment_breath_profile.gd")
const Surface := preload("res://scripts/environment_breath_surface.gd")

var manager: ChunkManager
var player: Player
var pacing: HorrorDirector
var allowed: Callable
var debug_controls := false
var active: Node3D
var active_chunk: Chunk
var selection: Dictionary = {}
var kind := "breath"
var elapsed := 0.0
var cooldown := 40.0
var events_started := 0
var collision_updates := 0
var last_setup_ms := 0.0
var last_collision_ms := 0.0
var max_prepare_step_ms := 0.0
var _collision_left := 0.0
var _scan_cells: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()
var _debug_kind := ""
var _debug_index := 0
var _last_mesh_id := 0

func configure(cm: ChunkManager, actor: Player, director: HorrorDirector, gate: Callable, debug := false) -> void:
	manager = cm
	player = actor
	pacing = director
	allowed = gate
	debug_controls = debug
	_rng.seed = cm.world_seed ^ 0x62726561
	cooldown = _rng.randf_range(35.0, 55.0)

func _physics_process(dt: float) -> void:
	if not is_instance_valid(manager) or not is_instance_valid(player):
		cancel()
		return
	if not allowed.is_valid() or not allowed.call():
		cancel()
		cooldown = maxf(cooldown, 15.0)
		return
	if is_instance_valid(active):
		if not is_instance_valid(active_chunk) or not active_chunk.is_inside_tree() or active_chunk.is_queued_for_deletion() or not actor_clear():
			cancel()
			return
		if not active.prepared:
			var begin := Time.get_ticks_usec()
			active.prepare_step()
			var cost := (Time.get_ticks_usec() - begin) / 1000.0
			last_setup_ms += cost
			max_prepare_step_ms = maxf(max_prepare_step_ms, cost)
			if active.failed: cancel()
			return
		elapsed += dt
		var duration := Profile.duration(kind)
		if elapsed >= duration:
			cancel()
			return
		active.pose(Profile.weights(kind, elapsed / duration))
		_collision_left -= dt
		if _collision_left <= 0.0:
			var begin := Time.get_ticks_usec()
			active.sync_collision()
			last_collision_ms = (Time.get_ticks_usec() - begin) / 1000.0
			collision_updates += 1
			_collision_left = 1.0 / 15.0
		return
	active = null
	cooldown -= dt
	if cooldown > 0: return
	if _scan_cells.is_empty():
		kind = _debug_kind
		if kind.is_empty():
			var roll := _rng.randf() if events_started >= 2 else 1.0
			kind = "ceiling" if roll < 0.20 else ("travel" if roll < 0.42 else "breath")
		var here := Vector2i(floori(player.global_position.x / ChunkManager.CELL), floori(player.global_position.z / ChunkManager.CELL))
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if manager.chunks.has(here + offset): _scan_cells.append(here + offset)
	if _scan_cells.is_empty():
		cooldown = 6.0
		if not _debug_kind.is_empty(): debug_notice.emit("BREATHING — waiting for nearby rooms to load")
		return
	# A bounded room search, never every resident room or every frame.
	var cell: Vector2i = _scan_cells.pop_front()
	var chunk: Chunk = manager.chunks.get(cell)
	if is_instance_valid(chunk) and not chunk.is_queued_for_deletion():
		for candidate in Placement.candidates(chunk, kind):
			if candidate.face.mesh.get_instance_id() == _last_mesh_id and _debug_kind.is_empty(): continue
			if not Placement.visible(candidate, chunk, player.cam): continue
			candidate.depth = _rng.randf_range(0.20, 0.35)
			candidate.size *= Vector2(_rng.randf_range(0.80, 1.0), _rng.randf_range(0.85, 1.0))
			selection = candidate
			active_chunk = chunk
			if actor_clear() and start_event(chunk, candidate, kind): return
	cooldown = 1.0 if not _scan_cells.is_empty() else 8.0
	if _scan_cells.is_empty() and not _debug_kind.is_empty():
		var hint := "look up at a clear ceiling" if kind == "ceiling" else "face a clear wall from 4–6 metres away"
		debug_notice.emit("BREATHING %s — waiting; %s and stay still" % [kind.to_upper(), hint])

func start_event(chunk: Chunk, candidate: Dictionary, shape_kind := "breath") -> bool:
	if is_instance_valid(active) or not is_instance_valid(chunk): return false
	if not allowed.is_valid() or not allowed.call(): return false
	selection = candidate
	active_chunk = chunk
	if not actor_clear(): return false
	if pacing != null and not pacing.try_start_visual(Profile.duration(shape_kind) + 1.0): return false
	var effect := Surface.new()
	chunk.add_child(effect)
	effect.begin_setup(candidate, shape_kind)
	last_setup_ms = 0.0
	max_prepare_step_ms = 0.0
	active = effect
	kind = shape_kind
	elapsed = 0.0
	_collision_left = 0.0
	events_started += 1
	_last_mesh_id = candidate.face.mesh.get_instance_id()
	_scan_cells.clear()
	var requested := not _debug_kind.is_empty()
	_debug_kind = ""
	cooldown = _rng.randf_range(65.0, 115.0)
	if debug_controls:
		print("Breathing surface: %s / %s" % [kind, chunk.cell])
		if requested: debug_notice.emit("BREATHING %s — starting" % kind.to_upper())
	return true

func actor_clear() -> bool:
	if selection.is_empty() or not is_instance_valid(active_chunk): return false
	var face: SurfaceWear.Face = selection.face
	var frame := active_chunk.global_transform * Transform3D(Basis(face.u, face.v, face.normal), selection.center)
	var inverse := frame.affine_inverse()
	var size: Vector2 = selection.size
	var actors: Array[Node] = [player]
	actors.append_array(get_tree().get_nodes_in_group(&"hostile_shadow_figure"))
	for actor in actors:
		if not is_instance_valid(actor) or not actor is Node3D: continue
		var position: Vector3 = actor.global_position
		var velocity := Vector3.ZERO
		if actor is CharacterBody3D: velocity = actor.velocity
		elif actor is ShadowFigure: velocity = actor.ground_velocity
		# Reserve the actor's swept body for the next half-second. Any close
		# approach withdraws the entire bulge before it can push or trap them.
		var a: Vector3 = inverse * (position + Vector3.UP * 0.9)
		var b: Vector3 = inverse * (position + velocity * 0.5 + Vector3.UP * 0.9)
		var region := AABB(Vector3(-size.x/2-0.65, -size.y/2-1.1, -0.65), Vector3(size.x+1.3, size.y+2.2, 1.85))
		if face.normal.y < -0.98:
			# On a ceiling, body height extends along the surface NORMAL, not
			# its in-plane v axis. Reserve standing/swept headroom accordingly.
			region = AABB(Vector3(-size.x/2-0.65, -size.y/2-0.65, -1.1), Vector3(size.x+1.3, size.y+1.3, float(selection.depth)+2.4))
		if region.has_point(a) or region.has_point(b) or region.intersects_segment(a, b) != null: return false
	return true

func cancel() -> void:
	if is_instance_valid(active):
		active.restore()
		active.queue_free()
	active = null
	active_chunk = null
	selection = {}
	_scan_cells.clear()

func _exit_tree() -> void:
	cancel()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode != KEY_F6 and event.keycode != KEY_F6: return
	if get_tree().paused: return
	get_viewport().set_input_as_handled()
	if not debug_controls:
		debug_notice.emit("BREATHING PREVIEW OFF — restart with --breathing")
		return
	if not allowed.is_valid() or not allowed.call():
		debug_notice.emit("BREATHING — blocked by current gameplay state; close camera/menus and wait")
		return
	cancel()
	_debug_kind = ["breath", "travel", "ceiling"][_debug_index % 3]
	_debug_index += 1
	cooldown = 0.0
	print("Breathing preview requested: ", _debug_kind)
	debug_notice.emit("BREATHING %s — searching for a safe visible surface" % _debug_kind.to_upper())
