class_name RealmExcursion
extends Node3D
## A procedural, once-per-floor visit. The source floor is retained unchanged.
## An isolated real 3D world supplies the doorway preview; its geometry moves
## into the main world for the excursion. Only the player crosses worlds.

enum Phase { PREPARING, WAITING, ENTERING, VISITING, CAUGHT, RETURNING, SPENT, FAILED }
const DURATION := 30.0
const ORIENTATION_SECONDS := 5.0
const COLLAPSE_SECONDS := 5.0
const WIREFRAME_COLLAPSE_SECONDS := 2.5
const REASSEMBLY_SECONDS := 1.3
const WINDOW_SHADER := preload("res://shaders/realm_window.gdshader")
const CAUGHT_SEQUENCE := preload("res://scripts/caught_sequence.gd")
const PREVIEW_BUILD_BUDGET_USEC := 2000
## The small doorway view doesn't need the full gameplay streaming radius.
## Normal streaming expands this neighbourhood after the player enters it.
const PREVIEW_LOAD_R := 2

# Preview jobs wait on owner signals so teardown can wake and cancel them
# while this instance still exists, before SceneTree emits another frame.
signal _preview_frame
signal _preview_physics_frame
var _preview_cancelled := false


var phase := Phase.PREPARING
var elapsed := 0.0
var total_spawned := 0
var destination_theme := 7
var destination_floor := 1
var game: Node3D
var seal: PhotoDoorSeal
var preview: SubViewport
var preview_camera: Camera3D
var pocket: ChunkManager
var threats: ShadowFigures
var window: MeshInstance3D
var source_centre := Vector3.ZERO
var source_forward := Vector3.ZERO
var destination_position := Vector3.ZERO
var destination_yaw := 0.0
var return_position := Vector3.ZERO
var return_yaw := 0.0
var _rotation := Basis.IDENTITY
var _previous_side := -1.0
var _next_spawn := ORIENTATION_SECONDS
var _source: Dictionary = {}
var _camera_run: DescentRun
var _camera_director: PhotoDirector
var _destination_ambience: Ambience
# Both visual versions implement configure/set_progress/set_hold/finish.
var _collapse_effect: Node3D
var collapse_style := "wireframe"
var _rebuild_effect: RealmWireframeCollapse
var _preview_environment: WorldEnvironment
var _prompt_hold := false
var bounty: RealmFlashBounty
var bounty_captured := false
var bounty_id := ""
var source_floor := 0
var _record: Dictionary = {}
var _source_cm: ChunkManager
var _building := false
var _preview_chunk: Chunk
var _preview_resources: Array[Resource] = []
var _preview_resource_pending := ""
var _preview_resources_ready := false
var _bind_left := 0.0
var _discovery_started := false
var _last_discovery_cell := Vector2i(1 << 30, 1 << 30)
var _entrance_hum: AudioStreamPlayer3D
var _door_leak: RealmDoorLeak
var _prize: Dictionary = {}
var _caught_sequence: CanvasLayer


func _ready() -> void:
	get_tree().process_frame.connect(_preview_frame.emit)
	get_tree().physics_frame.connect(_preview_physics_frame.emit)


func collapse_seconds() -> float:
	return COLLAPSE_SECONDS if collapse_style == "fracture" else WIREFRAME_COLLAPSE_SECONDS


func is_away() -> bool:
	return phase in [Phase.ENTERING, Phase.VISITING, Phase.CAUGHT, Phase.RETURNING]


func allows_perception_effect() -> bool:
	return phase == Phase.VISITING and not _prompt_hold \
		and elapsed < DURATION - collapse_seconds()


func sync_flash_hud() -> void:
	var visiting := phase == Phase.VISITING
	game._descent_hud.flash_bounty = bounty if visiting else null
	game._descent_hud.set_active(visiting and not _prompt_hold and not game._photo_camera._raised)


func set_prompt_hold(on: bool) -> void:
	if phase != Phase.VISITING:
		return
	_prompt_hold = on
	sync_flash_hud()
	threats.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	_camera_run.suspended = on
	game.player.set_physics_process(not on and bool(_source["player_physics"]))
	if is_instance_valid(_collapse_effect):
		_collapse_effect.set_hold(on)
	if is_instance_valid(bounty):
		bounty.set_hold(on)


func prepare(owner_game: Node3D) -> void:
	game = owner_game
	collapse_style = CliOptions.parse().realm_collapse_style
	if game.run == null or game.run.is_last_floor():
		phase = Phase.SPENT
		return
	source_floor = game.run.floor_idx
	_record = game.descent_route.topology.realm_door()
	_source_cm = game.cm
	if _record.is_empty():
		_fail("No realm doorway reserved")
		return
	var at: Vector2i = _record["cell"]
	var dir := DescentTopology.edge_dir(_record)
	var along := float(_record["t"])
	source_centre = Vector3(at.x * 12.0 + (12.0 if dir == 0 else along),
		Chunk.cell_floor_h(_source_cm.world_seed, at, game.active_level),
		at.y * 12.0 + (12.0 if dir == 2 else along))
	if _record.get("approach_cell", at) != at:
		dir = [1, 0, 3, 2][dir]
	var direction: Vector2i = WorldGen.DIRV[dir]
	source_forward = Vector3(direction.x, 0, direction.y)
	return_position = source_centre - source_forward * 4.5 + Vector3.UP * 0.15
	return_yaw = atan2(-source_forward.x, -source_forward.z)
	destination_floor = source_floor + 1
	destination_theme = DescentRun.FIXED_ORDER[destination_floor]
	game._photo_director.realm_destination = str(DescentRun.THEME_NAMES[destination_theme])
	game._photo_director.realm_preview_ready = false
	game._photo_director._register_photo_doors()
	_preload_preview_resources()
	# Build only when the player approaches. The controller and reserved edge
	# survive streaming; no distant source rooms are force-loaded.
	if game.opts.realm_visit:
		_build_preview()


func _preload_preview_resources() -> void:
	# Start disk decoding while the player is still at the floor arrival.
	# Keep the next realm's requests separate from source-floor streaming.
	var paths := Chunk.theme_prop_paths(destination_theme)
	if destination_theme == 1:
		# These textures belong to the procedural office ceiling, so they are
		# not dependencies of any imported furnishing in theme_prop_paths.
		for suffix in ["0.jpg", "1.png", "2.png"]:
			paths.append("res://models/cc_by/ceiling_tiles_texture/ceiling_tiles_texture_" + suffix)
	for path in paths:
		if ResourceLoader.has_cached(path):
			_preview_resources.append(ResourceLoader.get_cached_ref(path))
			continue
		if ResourceLoader.load_threaded_request(path) != OK:
			continue
		_preview_resource_pending = path
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await _preview_frame
			if _preview_cancelled:
				return
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path)
			if resource != null:
				_preview_resources.append(resource)
		_preview_resource_pending = ""
	_preview_resources_ready = true


func _build_preview() -> void:
	if _building or _preview_cancelled:
		return
	_building = true
	while not _preview_resources_ready:
		await _preview_frame
		if _preview_cancelled:
			return
	preview = SubViewport.new()
	preview.name = "NextRealmPreview"
	preview.own_world_3d = true
	# Keep emissive highlights above SDR white when this live view is composited
	# into an HDR main window.
	preview.use_hdr_2d = true
	preview.size = Vector2i(960, 600)
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(preview)
	_preview_environment = WorldEnvironment.new()
	_preview_environment.environment = game._build_env(destination_theme)
	preview.add_child(_preview_environment)
	pocket = ChunkManager.new()
	pocket.world_seed = WorldGen.level_seed(game.world_seed, destination_theme)
	pocket.theme = destination_theme
	pocket.chunk_built.connect(_configure_interactions)
	preview.add_child(pocket)
	pocket.set_process(false)
	# Reuse normal streaming's staged builder. A whole furnished chunk can
	# monopolize a frame; yield between stages while the player approaches.
	var cells := pocket._room_complete_cells(Vector2i.ZERO, PREVIEW_LOAD_R)
	for cell in cells:
		_preview_chunk = Chunk.new(pocket.world_seed, cell, destination_theme,
			pocket._build_spec(cell), true)
		_preview_chunk.position = Vector3(cell.x * 12.0, 0.0, cell.y * 12.0)
		var complete := false
		while not complete:
			var started := Time.get_ticks_usec()
			while true:
				complete = _preview_chunk.build_next_stage()
				if complete or Time.get_ticks_usec() - started >= PREVIEW_BUILD_BUDGET_USEC:
					break
			if complete:
				pocket._install_chunk(cell, _preview_chunk)
				_preview_chunk = null
			if game.opts.chunktime:
				var ms := (Time.get_ticks_usec() - started) / 1000.0
				if ms > 4.0:
					print("realm build slice %s %.1fms" % [cell, ms])
			await _preview_frame
			if _preview_cancelled:
				return
	await _preview_physics_frame
	if _preview_cancelled:
		return
	var placement_started := Time.get_ticks_usec()
	var found_destination := await _choose_destination()
	if _preview_cancelled:
		return
	if not found_destination:
		_fail("No clear next-realm landing and preview approach")
		return
	if game.opts.chunktime:
		print("realm destination placement %.1fms elapsed across frames" % ((Time.get_ticks_usec() - placement_started) / 1000.0))
	var prize := _prize
	if not prize.is_empty():
		bounty_id = "realm-flash:%d:%d" % [game.world_seed, game.run.floor_idx]
		bounty = RealmFlashBounty.new()
		pocket.add_child(bounty)
		bounty.build(prize, bounty_id, destination_theme)
		bounty.photographed.connect(func():
			bounty_captured = true
			game._photo_album_store.set_flash_status(bounty_id, "RETURN ALIVE TO KEEP THE FLASH"))
		_configure_interactions(bounty)
		print("REALM BOUNTY READY: %s; walk %.1fm; approach %s" % [bounty.subject, bounty.walk_distance, bounty.approach])
	preview_camera = Camera3D.new()
	preview_camera.near = 0.05
	preview_camera.far = 70.0
	preview.add_child(preview_camera)
	preview_camera.current = true
	var source_yaw := atan2(-source_forward.x, -source_forward.z)
	_rotation = Basis(Vector3.UP, destination_yaw - source_yaw)
	phase = Phase.WAITING
	game._photo_director.realm_preview_ready = true
	game._photo_director._register_photo_doors()
	_refresh_binding()
	print("REALM VISIT READY: %s -> %s; C, Space, then walk through" % [
		DescentRun.THEME_NAMES[game.active_level], DescentRun.THEME_NAMES[destination_theme]])


func _refresh_binding() -> void:
	if not is_instance_valid(_source_cm) or not _source_cm.is_inside_tree():
		return
	if not is_instance_valid(seal) or not seal.is_inside_tree():
		seal = null
		var at: Vector2i = _record.get("approach_cell", _record["cell"])
		var chunk := _source_cm.chunk_at(at)
		if chunk == null:
			return
		for candidate in chunk.photo_door_seals():
			if candidate.photo_id == str(_record["id"]):
				seal = candidate
				_previous_side = (game.player.global_position - source_centre).dot(source_forward)
				break
	if not is_instance_valid(seal) or not (seal.preview_ready or seal.opened):
		return
	if not is_instance_valid(window):
		_attach_window()
	# Reapply labels to subjects rebuilt by streaming or a blackout.
	for anomaly in game._photo_director._live_doors.values():
		if is_instance_valid(anomaly) and anomaly.id == seal.photo_id:
			var owner_chunk := anomaly.get_parent() as Chunk
			for owner_seal in owner_chunk.photo_door_seals():
				if owner_seal.photo_id == seal.photo_id:
					anomaly.configure_realm_destination(str(DescentRun.THEME_NAMES[destination_theme]), owner_seal)


func _attach_window() -> void:
	window = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(seal.width - 0.03, seal.height - 0.03)
	window.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = WINDOW_SHADER
	material.set_shader_parameter("realm_view", preview.get_texture())
	window.material_override = material
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.add_child(window)
	window.global_position = source_centre - source_forward * 0.035 + Vector3.UP * seal.height * 0.5
	window.look_at(window.global_position - source_forward)
	window.layers = PhotoAnomaly.PHOTO_LAYER
	if not is_instance_valid(_door_leak):
		_door_leak = RealmDoorLeak.new()
		add_child(_door_leak)
		_door_leak.configure(source_centre, source_forward, game.world_seed)
	if not is_instance_valid(_entrance_hum):
		_entrance_hum = AudioStreamPlayer3D.new()
		_entrance_hum.stream = SoundBank.portal_hum()
		_entrance_hum.bus = SoundBank.GAME_BUS
		_entrance_hum.volume_db = -12.0
		_entrance_hum.pitch_scale = 0.7
		_entrance_hum.unit_size = 6.0
		_entrance_hum.max_distance = 18.0
		add_child(_entrance_hum)
		_entrance_hum.global_position = source_centre - source_forward * 0.55 + Vector3.UP * 1.3
		_entrance_hum.play()
		_entrance_hum.stream_paused = true


func _entrance_in_room() -> bool:
	return ShadowFigure.room_for(game.player, game.player.global_position) \
		== ShadowFigure.room_for(game.player, return_position)


func _leak_in_view() -> bool:
	var camera: Camera3D = game.player.cam
	var point := _door_leak.global_position
	if (point - camera.global_position).dot(-camera.global_basis.z) <= 0.0 \
			or not camera.is_position_in_frustum(point):
		return false
	return _leak_line_of_sight()


func _leak_line_of_sight() -> bool:
	var camera: Camera3D = game.player.cam
	var point := _door_leak.global_position
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point,
		1, [game.player.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _choose_destination() -> bool:
	var world := preview.find_world_3d()
	var candidates: Array = pocket.chunks.keys()
	# Prefer the destination's own public spaces, using its existing builders.
	var styles: Array = DescentRoute.ELEV_STYLES.get(destination_theme, [])
	if destination_theme == 7:
		styles = [WorldGen.MALL_ATRIUM, WorldGen.MALL_CINEMA,
			WorldGen.MALL_FOODCOURT, WorldGen.MALL_KIOSKS, WorldGen.MALL_CORRIDOR,
			WorldGen.MALL_ANCHOR, WorldGen.MALL_STORE, WorldGen.MALL_SERVICE]
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ar := posmod(styles.find(WorldGen.cell_style(pocket.world_seed, a, destination_theme)), styles.size() + 1)
		var br := posmod(styles.find(WorldGen.cell_style(pocket.world_seed, b, destination_theme)), styles.size() + 1)
		return a.length_squared() < b.length_squared() if ar == br else ar < br)
	for cell: Vector2i in candidates:
		var desired := Vector3(cell.x * 12.0 + 6.0,
			Chunk.cell_floor_h(pocket.world_seed, cell, destination_theme) + 0.15, cell.y * 12.0 + 6.0)
		var safe := ArrivalSafety.find_safe(world, desired, cell)
		if safe == Vector3.INF:
			continue
		for fwd in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
			var behind: Vector3 = safe - fwd * 5.8
			if not ArrivalSafety.is_clear(world, behind) or not ArrivalSafety.has_floor(world, behind):
				continue
			var q := PhysicsRayQueryParameters3D.create(behind + Vector3.UP * 1.5, safe + Vector3.UP * 1.5, 1)
			if not world.direct_space_state.intersect_ray(q).is_empty():
				continue
			var prize := await RealmFlashBounty.choose(pocket, safe, fwd,
				_preview_frame, func() -> bool: return _preview_cancelled)
			if _preview_cancelled:
				return false
			if prize.is_empty():
				continue
			_prize = prize
			destination_position = safe
			destination_yaw = atan2(-fwd.x, -fwd.z)
			return true
	return false


func _configure_interactions(node: Node) -> void:
	# The pocket is isolated from source-floor progression. Preserve only real,
	# healthy charging stations for the duration of the visit.
	if node is Interactable:
		var station := node.get_parent() as ChargingStation
		(node as Interactable).enabled = phase == Phase.VISITING \
			and station != null and not station.broken
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stream_paused = phase != Phase.VISITING
	for child in node.get_children():
		_configure_interactions(child)


func _process(dt: float) -> void:
	if game == null:
		return
	if phase == Phase.PREPARING:
		if not _building and game.player.global_position.distance_to(source_centre) < 42.0:
			_build_preview()
		return
	if phase == Phase.WAITING:
		_bind_left -= dt
		if _bind_left <= 0.0:
			_bind_left = 0.2
			_refresh_binding()
		if not is_instance_valid(seal) or not seal.is_inside_tree() or not is_instance_valid(window):
			preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
			if is_instance_valid(_entrance_hum):
				_entrance_hum.stream_paused = true
			if is_instance_valid(_door_leak):
				_door_leak.finish()
			return
		var player: Player = game.player
		var offset := player.global_position - source_centre
		var side := offset.dot(source_forward)
		window.layers = 1 if seal.opened else PhotoAnomaly.PHOTO_LAYER
		var nearby := offset.length() < 18.0
		# The sealed wall completely hides this world from the eye. Rendering
		# it there was paying for a second scene throughout every approach.
		var show_preview: bool = nearby and (seal.opened or game._photo_camera._raised)
		preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show_preview else SubViewport.UPDATE_DISABLED
		if show_preview:
			var vp := game.get_viewport()
			var view_size: Vector2i = vp.get_visible_rect().size
			# Match the source world's 3D pixel density, including CRT scaling;
			# retain the existing cap when playing with the CRT switched off.
			var scale := minf(vp.scaling_3d_scale, 1280.0 / maxf(1.0, view_size.x))
			var target_size := Vector2i(maxi(1, roundi(view_size.x * scale)), maxi(1, roundi(view_size.y * scale)))
			if preview.size != target_size:
				preview.size = target_size
			preview_camera.global_transform = Transform3D(_rotation * player.cam.global_basis,
				destination_position + _rotation * (player.cam.global_position - source_centre))
			preview_camera.fov = player.cam.fov
		var held: bool = game.run.suspended or game.run.watching or game.run.blackout
		# The signal invites the player to turn. It can be heard in the room,
		# or through a clear opening on approach, before the wall is in view.
		# Arrival grace already permits walking and camera use; do not hide it
		# during the safest opportunity to discover an early entrance.
		var cue_nearby: bool = nearby and side < 0.0 and not held and not game.run.ended \
			and (_entrance_in_room() or _leak_line_of_sight())
		if is_instance_valid(_entrance_hum):
			_entrance_hum.stream_paused = not cue_nearby
		var looking: bool = cue_nearby and not game._photo_camera._raised and _leak_in_view()
		if _door_leak.update_cue(dt, cue_nearby and not seal.opened and not game._photo_camera._raised, held):
			print("REALM WALL LEAK: floor %d; %.1fm; pulse %d; in_view %s" % [source_floor + 1, offset.length(), _door_leak.pulses, looking])
		if looking and _door_leak.visible and not _discovery_started and not held:
			_discovery_started = true
			game._figures.hold_new_spawns(4.5)
			print("REALM DISCOVERY SEEN: floor %d; %.1fm" % [source_floor + 1, offset.length()])
		if nearby:
			var cell := Vector2i(floori(player.global_position.x / 12.0), floori(player.global_position.z / 12.0))
			if cell != _last_discovery_cell:
				_last_discovery_cell = cell
				print("REALM DISCOVERY APPROACH: cell %s; %.1fm; eligible %s; in_view %s; camera %s; grace %.1f" % [cell, offset.length(), cue_nearby, looking, game._photo_camera._raised, game.run.arrival_grace])
		if seal.opened and _previous_side < 0.0 and side >= 0.0 \
				and absf(offset.dot(source_forward.cross(Vector3.UP))) < seal.width * 0.5 \
				and absf(offset.y) < 1.0 and not game.run.blackout \
				and game._photo_camera._review_left <= 0.0:
			enter()
		_previous_side = side
	elif phase == Phase.VISITING:
		if _prompt_hold:
			return
		elapsed += dt
		if elapsed >= DURATION:
			collapse()
			return
		if elapsed >= _next_spawn:
			var cap := 1 if elapsed < 12.0 else (2 if elapsed < 21.0 else 3)
			if threats.active_figures().size() < cap and threats.try_realm_encounter(total_spawned == 0):
				total_spawned += 1
				_next_spawn = elapsed + (5.0 if elapsed < 15.0 else 3.5)
			else:
				_next_spawn = elapsed + 0.75
		var collapse_duration := collapse_seconds()
		var collapse_amount := clampf((elapsed - (DURATION - collapse_duration)) / collapse_duration, 0.0, 1.0)
		_collapse_effect.set_progress(collapse_amount)
		game.player.set_rumble(collapse_amount * collapse_amount * (0.14 if GameSettings.flashing_reduced() else 0.55))
		game._post_process.set_corruption(maxf(game.run.threat(), collapse_amount * 0.65))
		# Once the room is visibly breaking apart, attacks must not kill the
		# player behind the opaque final breakup. Earlier combat is unchanged.
		if collapse_amount >= _collapse_effect.PROTECTED_FINISH:
			threats.passive = true
		if collapse_amount > 0.0:
			game.ambience.stream_paused = false
			game.ambience.volume_db = lerpf(-60.0, float(_source["ambient_db"]), collapse_amount)
		if game.player.global_position.y < -4.0:
			collapse() # streamed-floor failure must never strand a visitor


func enter() -> void:
	if phase != Phase.WAITING or not seal.opened or game.run.blackout \
			or game.run.suspended or game.run.watching or game._switching:
		return
	# Save a real standing point in front of the entry, not the last pixel
	# before crossing the threshold. The source world is retained unchanged.
	var exclude: Array[RID] = [game.player.get_rid()]
	var cell := Vector2i(floori(return_position.x / 12.0), floori(return_position.z / 12.0))
	var safe := ArrivalSafety.find_safe(game.get_world_3d(), return_position, cell, exclude)
	if safe == Vector3.INF:
		_fail("Return landing is obstructed")
		return
	return_position = safe
	phase = Phase.ENTERING
	if is_instance_valid(_door_leak):
		_door_leak.finish()
	if is_instance_valid(_entrance_hum):
		_entrance_hum.stop()
	game._consume_realm_visit(source_floor)
	# A source-floor charging session must end before its world is detached;
	# accumulated charge remains on the player.
	game.player.stop_charging()
	_source = {"root": game.level_root, "env": game.we.environment,
		"camera_director": game._photo_camera.director, "camera_run": game._photo_camera.run,
		"camera_events": game._photo_camera.events,
		"camera_figures": game._photo_camera.figures, "heart_figures": game._heart.figures,
		"run_physics": game.run.is_physics_processing(), "player_physics": game.player.is_physics_processing(),
		"player_seed": game.player.world_seed, "player_theme": game.player.level_theme,
		"water": game.player.water_y, "pitch": game.player._pitch,
		"ambient_db": game.ambience.volume_db, "events_process": game._events.is_processing()}
	game._switching = true
	game.run.suspend_rules()
	game.run.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_input(false)
	game.player.set_process_unhandled_input(false)
	game._photo_camera._lower()
	game._photo_camera.enabled = false
	game._set_presence(game.Presence.SILENT)
	game._figures.despawn(false)
	game._events.set_process(false)
	game._descent_hud.set_active(false)
	await _fade_to(1.0, 0.16)
	preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Removing the source removes its physics, audio, and streaming together.
	game.remove_child(game.level_root)
	pocket.reparent(game)
	pocket.player = game.player
	pocket.stream_focus = destination_position
	pocket.set_process(true)
	game.we.environment = _preview_environment.environment
	game.player.world_seed = pocket.world_seed
	game.player.level_theme = destination_theme
	game.player.water_y = game._water_level_for(destination_theme)
	game.ambience.stream_paused = true
	if is_instance_valid(game._bleed_bed):
		game._bleed_bed.stream_paused = true
	_destination_ambience = Ambience.new(destination_theme)
	add_child(_destination_ambience)
	game._switch_music(destination_theme)
	_camera_run = DescentRun.new()
	_camera_run.floor_idx = destination_floor
	_camera_run.suspended = false
	_camera_director = PhotoDirector.new()
	_camera_director.floor_idx = destination_floor
	_camera_director.theme = destination_theme
	add_child(_camera_director)
	if is_instance_valid(bounty):
		_camera_director._live[bounty.cell] = bounty
	game._photo_camera.run = _camera_run
	game._photo_camera.director = _camera_director
	game._photo_camera.events = null
	threats = ShadowFigures.new()
	threats.player = game.player
	threats.floor_idx = destination_floor
	threats.completed_levels = source_floor
	threats.chunk_manager = pocket
	# This is the one authored combat space whose pressure curve deliberately
	# escalates from one pursuer to three. Ordinary floors stay single-stalker.
	threats.allow_reinforcements = true
	threats.directed_only = true
	threats.suspended = true
	game.add_child(threats)
	threats.reached_player.connect(func(): collapse(true))
	threats.burned_away.connect(func():
		game.player.add_flashlight_charge(game.BURN_REFUND)
		game._heart.bump(Heartbeat.BUMP_BURNED))
	threats.seen_by_player.connect(func(): game._heart.bump(Heartbeat.BUMP_SEEN))
	threats.spawned.connect(func(): game._post_process.glitch_burst())
	threats.approach_starting.connect(game._reality_aftershock.before_approach)
	game._photo_camera.figures = threats
	game._heart.figures = threats
	game._heart.suspended = false
	_collapse_effect = RealmCollapseEffect.new() if collapse_style == "fracture" else RealmWireframeCollapse.new()
	add_child(_collapse_effect)
	_collapse_effect.configure(game.player, game.world_seed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.player.teleport(destination_position)
	game.player.rotation.y = destination_yaw
	game.player._pitch = 0.0
	await _fade_to(0.0, 0.35)
	phase = Phase.VISITING
	sync_flash_hud()
	_configure_interactions(pocket)
	game._switching = false
	game.player.set_physics_process(bool(_source["player_physics"]))
	game.player.set_process_input(true)
	game.player.set_process_unhandled_input(true)
	game._photo_camera.enabled = true
	threats.suspended = false
	game._show_event_message("PHOTOGRAPH THE BOLT (C + SPACE) — SURVIVE TO KEEP ITS FLASH" \
		if is_instance_valid(bounty) else "THIS PLACE IS NOT HOLDING", false, 5.0)
	print("REALM VISIT ENTERED: 30 seconds; source floor unchanged")


func collapse(caught := false) -> void:
	# A realm catch is a failed excursion, not a fatal source-floor catch. Play
	# the existing first-person caught beat while the pocket world and the exact
	# attacker still exist; only its black frame may hand off to the return.
	if caught and phase == Phase.VISITING:
		await _present_caught_in_realm()
		return
	if phase != Phase.VISITING and not (caught and phase == Phase.CAUGHT):
		return
	phase = Phase.RETURNING
	sync_flash_hud()
	# Clear any pocket charging session before tearing down its station.
	game.player.stop_charging()
	game._switching = true
	threats.suspended = true
	threats.passive = true
	threats.despawn()
	game.player.set_physics_process(false)
	game.player.set_process_input(false)
	game.player.set_process_unhandled_input(false)
	# Complete an in-flight shutter before changing its world or metadata.
	# No new photos are accepted while leaving; review can't extend the visit.
	game._photo_camera.enabled = false
	while game._photo_camera._capturing:
		await get_tree().process_frame
	game._photo_camera.finish_for_transition()
	if not caught and elapsed >= DURATION - collapse_seconds():
		_collapse_effect.set_progress(1.0)
	var completed_collapse := not caught and elapsed >= DURATION
	await _fade_to(1.0, 0.12 if completed_collapse else 0.25)
	game.player.set_rumble(0.0)
	_collapse_effect.finish()
	pocket.set_process(false)
	game.remove_child(pocket)
	pocket.queue_free()
	game.remove_child(threats)
	threats.queue_free()
	_destination_ambience.queue_free()
	# Until teleport completes, the player is still at the destination coordinates.
	# Pin source streaming before reattachment so it cannot unload the return
	# room while its physics is settling.
	game.cm.stream_focus = return_position
	game.add_child(_source["root"])
	game.we.environment = _source["env"]
	game.player.world_seed = int(_source["player_seed"])
	game.player.level_theme = int(_source["player_theme"])
	game.player.water_y = float(_source["water"])
	game._photo_camera.director = _source["camera_director"]
	game._photo_camera.run = _source["camera_run"]
	game._photo_camera.figures = _source["camera_figures"]
	game._photo_camera.events = _source["camera_events"]
	game._heart.figures = _source["heart_figures"]
	_camera_director.queue_free()
	_camera_run.free()
	_camera_run = null
	window.visible = false
	game.ambience.volume_db = float(_source["ambient_db"])
	game.ambience.stream_paused = false
	if is_instance_valid(game._bleed_bed):
		game._bleed_bed.stream_paused = false
	game._switch_music(game.active_level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.player.teleport(return_position)
	game.player.rotation.y = return_yaw
	game.player._pitch = 0.0
	game.player.cam.rotation.x = 0.0
	game._post_process.set_corruption(game.run.threat())
	# The caught sequence's curtain is opaque here and the ordinary transition
	# fade is opaque behind it. Remove the former before revealing the retained
	# source so no destination frame, source frame, or camera pose can flash.
	if caught and is_instance_valid(_caught_sequence):
		_caught_sequence.queue_free()
		_caught_sequence = null
		await get_tree().process_frame
	if completed_collapse and collapse_style == "wireframe":
		await _reassemble_source()
	else:
		await _fade_to(0.0, 0.22 if completed_collapse else 0.65)
	# Source rules, interactions, and event scheduling stay suspended until
	# the last solid surface has reconstructed around the returned player.
	game._events.set_process(bool(_source["events_process"]))
	phase = Phase.SPENT
	_preview_resources.clear()
	game.run.set_physics_process(bool(_source["run_physics"]))
	game.run.resume_rules(5.0)
	game.run._update_passive()
	game._set_presence(game.Presence.DESCENT)
	game._on_descent_passive(game.run.rules_force_passive())
	game._descent_hud.set_active(true)
	game._switching = false
	game._photo_camera.enabled = true
	game.player.set_process_input(true)
	game.player.set_process_unhandled_input(true)
	game.player.set_physics_process(bool(_source["player_physics"]))
	print("REALM VISIT RETURNED: elapsed %.2f, spawns %d, caught %s" % [elapsed, total_spawned, caught])
	if caught:
		if bounty_captured:
			game._photo_album_store.set_flash_status(bounty_id, "FLASH LOST — DID NOT RETURN ALIVE")
		game._show_event_message("THE DOOR CLOSES — THE FLASH IS LOST" \
			if bounty_captured else "THE DOOR CLOSES — ONE CHANCE", false, 4.0)
	else:
		if completed_collapse and bounty_captured and game.award_emergency_flash(bounty_id):
			game._show_event_message("FLASH STORED — IT WILL KILL THE ATTACKER THAT CATCHES YOU", false, 5.0)
		else:
			if bounty_captured:
				game._photo_album_store.set_flash_status(bounty_id, "FLASH ALREADY STORED" if game.player.emergency_flash_held else "FLASH LOST — LEFT TOO SOON")
			game._show_event_message("ONLY THIS ROOM REMAINS", false, 4.0)


func _present_caught_in_realm() -> void:
	if phase != Phase.VISITING:
		return
	phase = Phase.CAUGHT
	sync_flash_hud()
	game._play_player_death()
	threats.suspended = true
	threats.passive = true
	for figure in threats.active_figures():
		figure.set_physics_process(false)
	_caught_sequence = CAUGHT_SEQUENCE.new()
	add_child(_caught_sequence)
	_caught_sequence.begin(game.player, threats.catching_figure,
		threats.catch_presentation)
	# Match normal Descent death handling: a shutter already in flight owns its
	# render until it has produced the photograph, but cannot hide the catch.
	_caught_sequence.set_process(false)
	while game._photo_camera._capturing:
		await get_tree().process_frame
	game._photo_camera.finish_for_transition()
	_caught_sequence.set_process(true)
	await _caught_sequence.finished
	if phase != Phase.CAUGHT:
		return
	# Restore the realm camera before its world is detached. The black curtain
	# remains, and collapse immediately freezes input again before its first wait.
	_caught_sequence.restore()
	await collapse(true)


func _reassemble_source() -> void:
	# The retained original scene is already attached and the player is at a
	# supported return point. Install its own effect while the fade is opaque;
	# no unmodified source frame can flash between destruction and assembly.
	_rebuild_effect = RealmWireframeCollapse.new()
	add_child(_rebuild_effect)
	_rebuild_effect.configure(game.player, game.world_seed, true)
	_rebuild_effect.set_progress(1.0)
	await get_tree().process_frame
	await _fade_to(0.0, 0.08)
	var rebuild := create_tween()
	rebuild.tween_method(_rebuild_effect.set_progress, 1.0, 0.0, REASSEMBLY_SECONDS)
	await rebuild.finished
	_rebuild_effect.finish()
	_rebuild_effect = null


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(game._fade, "color:a", alpha, seconds)
	await tween.finished


func _fail(reason: String) -> void:
	phase = Phase.FAILED
	if is_instance_valid(_door_leak):
		_door_leak.finish()
	if is_instance_valid(_entrance_hum):
		_entrance_hum.stop()
	push_warning("Realm visit: " + reason)
	if is_instance_valid(window):
		window.visible = false


func _exit_tree() -> void:
	_preview_cancelled = true
	if get_tree().process_frame.is_connected(_preview_frame.emit):
		get_tree().process_frame.disconnect(_preview_frame.emit)
	if get_tree().physics_frame.is_connected(_preview_physics_frame.emit):
		get_tree().physics_frame.disconnect(_preview_physics_frame.emit)
	_preview_frame.emit()
	_preview_physics_frame.emit()
	if is_instance_valid(_caught_sequence):
		_caught_sequence.restore()
	if not _preview_resource_pending.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_preview_resource_pending)
		if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
			ResourceLoader.load_threaded_get(_preview_resource_pending)
		_preview_resource_pending = ""
	_preview_resources.clear()
	# A quit/retry can interrupt construction before this off-tree chunk has
	# been installed in the preview world.
	if is_instance_valid(_preview_chunk):
		_preview_chunk.free()
		_preview_chunk = null
	if is_instance_valid(window):
		window.queue_free()
	# Detached source nodes aren't otherwise owned by the scene on quit.
	if _source.has("root") and is_instance_valid(_source["root"]) \
			and (_source["root"] as Node).get_parent() == null:
		(_source["root"] as Node).free()
	if is_instance_valid(_camera_run):
		_camera_run.free()
