extends Node
## One reversible architectural beat at a time. No topology or saved-state edits.
signal debug_notice(message: String)
const Placement := preload("res://scripts/environment_breath_placement.gd")
const Profile := preload("res://scripts/environment_breath_profile.gd")
const Surface := preload("res://scripts/environment_breath_surface.gd")
const WavePlacement := preload("res://scripts/hallway_wave_placement.gd")
const WaveProfile := preload("res://scripts/hallway_wave_profile.gd")
const WaveSurface := preload("res://scripts/hallway_wave_surface.gd")

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
var _wave_started := false
var _prepare_elapsed := 0.0
var _audio: Node
var _audio_started := false
var _visibility_left := 0.0
var _wave_preview_mode := false
var _preview_hint_shown := false
var _wave_wait := 0.0

func configure(cm: ChunkManager, actor: Player, director: HorrorDirector, gate: Callable, debug := false, request_wave := false) -> void:
	manager = cm
	player = actor
	pacing = director
	allowed = gate
	debug_controls = debug
	_rng.seed = cm.world_seed ^ 0x62726561
	cooldown = _rng.randf_range(35.0, 55.0)
	# Install matching collision before the player's move_and_slide tick.
	process_physics_priority = -10
	_audio = preload("res://scripts/supernatural_audio.gd").new()
	add_child(_audio)
	_wave_preview_mode = request_wave
	if request_wave: cooldown = INF # Wait for the viewer, not a one-shot launch timer.

func _physics_process(dt: float) -> void:
	if not is_instance_valid(manager) or not is_instance_valid(player):
		cancel()
		return
	if not allowed.is_valid() or not allowed.call():
		cancel("stopped by gameplay safety gate; press F6 again when ready")
		cooldown = maxf(cooldown, 15.0)
		return
	if _wave_preview_mode and not _preview_hint_shown:
		_preview_hint_shown = true
		debug_notice.emit("HALLWAY WAVE TEST — press F6 (Fn+F6 on Mac) to play")
		print("Hallway wave test ready: waiting for F6")
	if is_instance_valid(active):
		if not is_instance_valid(active_chunk) or not active_chunk.is_inside_tree() or active_chunk.is_queued_for_deletion() or manager.chunks.get(active_chunk.cell) != active_chunk or not actor_clear():
			cancel("stopped: room changed, hostile nearby or too close to the side wall")
			return
		if not active.prepared:
			_prepare_elapsed += dt
			if _prepare_elapsed > 45.0:
				cancel("preparation timed out; press F6 to retry")
				return
			var begin := Time.get_ticks_usec()
			active.prepare_step()
			var cost := (Time.get_ticks_usec() - begin) / 1000.0
			last_setup_ms += cost
			max_prepare_step_ms = maxf(max_prepare_step_ms, cost)
			if active.failed:
				cancel("skipped: " + active.failure if kind == "wave" else "preparation failed")
			return
		if kind == "wave" and not _wave_started:
			# Preparation may take seconds. Reserve quiet time for the actual
			# motion, not a lease that expires while still building its meshes.
			if pacing != null and not pacing.try_start_visual(WaveProfile.DURATION+1.0):
				if _wave_preview_mode and _wave_wait < 30.0:
					if _wave_wait == 0.0:
						debug_notice.emit("HALLWAY WAVE — prepared; waiting for a quiet moment")
						print("Hallway wave prepared: waiting for quiet pacing")
					_wave_wait += dt
					return
				cancel("quiet pacing blocked the wave; press F6 to retry")
				return
			_wave_started = true
			if debug_controls:
				debug_notice.emit("HALLWAY WAVE — PLAYING NOW; walk through it")
				print("Hallway wave PLAYING: ", active_chunk.cell)
		if not _audio_started:
			_audio.begin_event()
			_audio_started = true
		elapsed += dt
		var duration := WaveProfile.DURATION if kind == "wave" else Profile.duration(kind)
		if elapsed >= duration:
			cancel("finished — press F6 to replay" if _wave_preview_mode else "finished")
			return
		if kind == "wave": active.pose(elapsed / duration)
		else: active.pose(Profile.weights(kind, elapsed / duration))
		_visibility_left -= dt
		if _visibility_left <= 0.0:
			_audio.set_in_view(_effect_in_view())
			_visibility_left = 0.1
		_collision_left -= dt
		if _collision_left <= 0.0:
			var begin := Time.get_ticks_usec()
			active.sync_collision()
			last_collision_ms = (Time.get_ticks_usec() - begin) / 1000.0
			collision_updates += 1
			_collision_left = 0.0 if kind == "wave" else 1.0 / 15.0
		return
	active = null
	cooldown -= dt
	if cooldown > 0: return
	if _scan_cells.is_empty():
		kind = _debug_kind
		if kind.is_empty():
			var roll := _rng.randf() if events_started >= 2 else 1.0
			kind = "wave" if roll < 0.18 else ("ceiling" if roll < 0.38 else ("travel" if roll < 0.60 else "breath"))
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
		var options: Array = []
		if kind == "wave":
			var layout := WavePlacement.eligible(chunk)
			if not layout.is_empty(): options.append(layout)
		else: options = Placement.candidates(chunk, kind)
		for candidate in options:
			if kind == "wave":
				var center := chunk.to_global(Vector3(6, chunk._floor_h()+1.4, 6))
				if not player.cam.is_position_in_frustum(center) and not chunk.cell == Vector2i(floori(player.global_position.x/12), floori(player.global_position.z/12)): continue
				if start_event(chunk, candidate, kind): return
				continue
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
		if kind == "wave": hint = "enter a straight hallway; moving walkways, water and special rooms are excluded"
		debug_notice.emit("BREATHING %s — waiting; %s and stay still" % [kind.to_upper(), hint])

func start_event(chunk: Chunk, candidate: Dictionary, shape_kind := "breath") -> bool:
	if is_instance_valid(active) or not is_instance_valid(chunk): return false
	if not allowed.is_valid() or not allowed.call(): return false
	selection = candidate
	active_chunk = chunk
	# actor_clear needs the requested kind before inspecting its selection.
	var previous_kind := kind
	kind = shape_kind
	if not actor_clear():
		kind = previous_kind
		return false
	if shape_kind == "wave" and WavePlacement.eligible(chunk).is_empty(): return false
	if shape_kind != "wave" and pacing != null and not pacing.try_start_visual(Profile.duration(shape_kind) + 1.0): return false
	var effect: Node3D = WaveSurface.new() if shape_kind == "wave" else Surface.new()
	chunk.add_child(effect)
	if shape_kind == "wave": effect.begin_setup(chunk, candidate.axis, candidate.width, candidate.height)
	else: effect.begin_setup(candidate, shape_kind)
	last_setup_ms = 0.0
	max_prepare_step_ms = 0.0
	active = effect
	kind = shape_kind
	elapsed = 0.0
	_prepare_elapsed = 0.0
	_wave_started = false
	_wave_wait = 0.0
	_audio_started = false
	_visibility_left = 0.0
	_collision_left = 0.0
	events_started += 1
	if shape_kind != "wave": _last_mesh_id = candidate.face.mesh.get_instance_id()
	_scan_cells.clear()
	var requested := not _debug_kind.is_empty()
	_debug_kind = ""
	cooldown = INF if _wave_preview_mode else _rng.randf_range(65.0, 115.0)
	if debug_controls:
		print("Architecture preparing: %s / %s" % [kind, chunk.cell])
		if requested: debug_notice.emit("HALLWAY WAVE — preparing native room" if kind == "wave" else "BREATHING %s — starting" % kind.to_upper())
	return true

func actor_clear() -> bool:
	if selection.is_empty() or not is_instance_valid(active_chunk): return false
	if kind == "wave":
		if not is_instance_valid(player) or WavePlacement.eligible(active_chunk).is_empty(): return false
		var local := active_chunk.to_local(player.global_position)
		if Vector2(local.x-6, local.z-6).length() > 24.0: return false
		# Walking the moving floor is supported. Approaching a narrowing wall
		# or any hostile entering the room withdraws the inward-only warp.
		var across := local.z-6 if int(selection.axis) == 1 else local.x-6
		if local.x > 0 and local.x < 12 and local.z > 0 and local.z < 12 and absf(across) > float(selection.width)/2-0.8: return false
		for actor in get_tree().get_nodes_in_group(&"hostile_shadow_figure"):
			if actor is Node3D and actor.global_position.distance_to(active_chunk.to_global(Vector3(6,1,6))) < 20.0: return false
		return true
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

func cancel(reason := "") -> void:
	if is_instance_valid(active) and kind == "wave" and debug_controls and not reason.is_empty():
		debug_notice.emit("HALLWAY WAVE — " + reason)
		print("Hallway wave: ", reason)
	if is_instance_valid(_audio): _audio.end_event()
	_audio_started = false
	if is_instance_valid(active):
		active.restore()
		active.queue_free()
	active = null
	active_chunk = null
	selection = {}
	_wave_started = false
	_scan_cells.clear()

func perception_weight() -> float:
	# Share the visibility attack/release with the sound layer, including its
	# tail after cancellation. Master/Game volume does not affect this value.
	return smoothstep(0.0, 1.0, _audio.gain) if is_instance_valid(_audio) else 0.0

func _effect_in_view() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(active_chunk): return false
	var points: Array[Vector3] = []
	if kind == "wave":
		var z := lerpf(-6.0-WaveProfile.BAND, 6.0+WaveProfile.BAND, elapsed/WaveProfile.DURATION)
		if absf(z) > 6.0: return false
		for p in [Vector3(0, 0.5, z), Vector3(0, float(selection.height)-0.5, z), Vector3(-float(selection.width)*0.4, 1.4, z), Vector3(float(selection.width)*0.4, 1.4, z)]:
			points.append(active_chunk.to_global(active.frame*p))
	else:
		points.append(active_chunk.to_global(selection.center+selection.face.normal*(float(selection.depth)+0.1)))
	for point in points:
		if not player.cam.is_position_in_frustum(point): continue
		var ray := PhysicsRayQueryParameters3D.create(player.cam.global_position, point)
		ray.exclude = [player.get_rid()]
		if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return true
	return false

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
	_debug_kind = "wave" if _wave_preview_mode else ["breath", "travel", "ceiling", "wave"][_debug_index % 4]
	_debug_index += 1
	cooldown = 0.0
	print("Breathing preview requested: ", _debug_kind)
	debug_notice.emit("BREATHING %s — searching for a safe visible surface" % _debug_kind.to_upper())
