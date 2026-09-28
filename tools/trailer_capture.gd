extends SceneTree
## Trailer-only director. Renders production scenes and actors into isolated QA sessions.
## godot --path . --fixed-fps 30 --audio-driver Dummy --script tools/trailer_capture.gd -- --nologo --test-mode --shot=casino --frames=90
var game: Node3D
var view: SubViewport
var cam: Camera3D
var shot := "casino"
var frames := 90
var width := 1920
var height := 1080
var output := "res://build/promo-trailer-v6/raw"
var base_eye := Vector3.ZERO
var target := Vector3.ZERO
var motion := Vector3.ZERO
var room_cell := Vector2i.ZERO
var figure: ShadowFigure
var effect: Node
var tv: VhsRitual
var probe := false
var target_initial := Vector3.ZERO
var burn_logged := false
var death_started := false
var visit: RealmExcursion
var traversal := false
var traversal_start := Vector3.ZERO
var traversal_length := 0.0
var camera_yaw_offset := 0.0
var turn_yaw_start := 0.0
var turn_sign := 1.0
var walk_predictions: Array[Vector3] = []
var trajectory: Array[Dictionary] = []
var portal_entered_frame := -1
var portal_last_phase := -1
var portal_waypoints: Array[Vector3] = []
var flooded_root := Vector2i.ZERO
const STYLES := {"casino": 2, "office": 12, "annex": 24, "pool": 97, "school": 61, "server": 101,
	"casino_kill":5,"office_kill":11,"annex_kill":24,"school_kill":60,"server_kill":100,"death":24,
	"annex_run":24,"school_run":60,"pool_hero":97,
	"casino_traverse":2,"office_traverse":12,"annex_traverse":24,
	"school_traverse":60,"server_traverse":101,"pool_girl":97}

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--probe": probe = true
		if arg == "--small": width = 960; height = 540
	call_deferred("run")

func draw(count := 1) -> void:
	for i in count:
		await process_frame
		if is_instance_valid(game):
			if is_instance_valid(game._pause_menu):
				# queue_free is deferred: hide immediately so focus changes cannot
				# leak one frame of the Escape menu into the recording.
				game._pause_menu.visible = false
				game._close_settings()
			game.player.set_process(false)
			game.player.set_physics_process(false)
			quiet_hud()
		RenderingServer.force_draw(false, 1.0 / 30.0)

func quiet_hud() -> void:
	game._osd_layer.visible = false
	game._descent_hud.visible = false
	game._hint.visible = false
	game._event_panel.visible = false
	if is_instance_valid(tv) and is_instance_valid(tv._watch_hint): tv._watch_hint.visible = false

func set_eye(eye: Vector3, look: Vector3) -> void:
	game.player.global_position = eye - Vector3.UP * Player.CAM_H
	cam.global_position = eye
	cam.look_at(look)
	cam.current = true

func load_cell(cell: Vector2i) -> void:
	room_cell = cell
	game.cm.stream_focus = Vector3(cell.x * 12 + 6, 1.5, cell.y * 12 + 6)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			game.cm._build(cell + Vector2i(dx, dz))
	await draw(8)

func find_style(style: int) -> Vector2i:
	var ws: int = game.cm.world_seed
	for radius in 35:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var at := Vector2i(x, z)
				if WorldGen.cell_style(ws, at, game.active_level) == style and WorldGen.room_id(ws, at) == at:
					return at
	return Vector2i.ZERO

func setup_room() -> void:
	await load_cell(find_style(STYLES.get(shot, 2)))
	var chunk: Chunk = game.cm.chunk_at(room_cell)
	var origin := chunk.global_position
	var floor_h := chunk._floor_h()
	base_eye = origin + Vector3(2.2, floor_h + Player.CAM_H, 9.4)
	target = origin + Vector3(7.0, floor_h + 1.45, 4.0)
	motion = Vector3(2.0, 0, -2.0)
	var axis: int = WorldGen.annex_corridor_axis(game.cm.world_seed, room_cell) if game.active_level == 2 else WorldGen.corridor(game.cm.world_seed, room_cell)
	if axis != 0:
		base_eye = origin + Vector3(1.0 if axis == 1 else 6.0, floor_h + Player.CAM_H, 6.0 if axis == 1 else 10.8)
		motion = Vector3(6.5, 0, 0) if axis == 1 else Vector3(0, 0, -6.5)
		target = base_eye + motion * 3.0
	if shot == "pool":
		base_eye = origin + Vector3(2.0, Player.CAM_H, 10.0)
		target = origin + Vector3(12, 0.8, 12)
		motion = Vector3(2, 0, 0)
	if shot.ends_with("run"):
		motion = motion.normalized() * 16.0
		target = base_eye + motion.normalized() * 40.0
	if shot == "pool_hero":
		for node in chunk.find_children("*", "MeshInstance3D", true, false):
			if not node.has_meta("pool_water_surface"): continue
			var water: Vector3 = node.global_position
			var extent: Vector2 = node.get_meta("pool_water_size")
			base_eye = Vector3(water.x + extent.x * 0.30, Chunk.POOL_DECK_Y + Player.CAM_H, water.z + extent.y * 0.5 + 0.7)
			target = water + Vector3(0, 0.2, -extent.y * 0.25)
			motion = Vector3(-1.7, 0, 0)
			break
	set_eye(base_eye, target)
	print("TRAILER_ROOM ", shot, " theme=", game.active_level, " cell=", room_cell, " eye=", base_eye, " target=", target)

func setup_monster() -> void:
	var forward := (target - base_eye).normalized()
	forward.y = 0
	forward = forward.normalized()
	motion = -forward * 1.0
	figure = ShadowFigure.new()
	figure.player = game.player
	# The production spawn table is authoritative. Casino and server rooms
	# use the dark roster; signature creatures stay in their assigned levels.
	figure.walker_model_index = ShadowFigures.THEME_WALKER.get(game.active_level,
		ShadowFigures.DARK_ROSTER[game.active_level % ShadowFigures.DARK_ROSTER.size()])
	assert(figure.walker_model_index == ShadowFigures.THEME_WALKER.get(game.active_level, -1)
		or (not ShadowFigures.THEME_WALKER.has(game.active_level) and figure.walker_model_index in ShadowFigures.DARK_ROSTER))
	var distance := 6.2 if shot == "pool_girl" else (2.7 if shot == "death" else 3.8)
	figure.position = base_eye + forward * distance - Vector3.UP * Player.CAM_H
	figure.suppressed = true
	game.add_child(figure)
	figure.set_physics_process(false)
	figure._walker.appear(0.0)
	figure._walker.set_manifestation(1.0)
	figure._walker.face_world_position(base_eye, 1.0)
	target = figure.global_position + Vector3.UP * (0.8 if figure.walker_model_index == 9 else 1.22)
	target_initial = target
	set_eye(base_eye, target)
	cam.fov = 76
	game.player.set_flashlight(false)
	print("TRAILER_ENEMY theme=", game.active_level, " model=", figure.walker_model_index,
		" asset=", ShadowWalkerVisual.MODEL_PATHS[figure.walker_model_index])

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [game.player.get_rid()])
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func walk_yaw(seconds: float, initial: float, direction: float) -> float:
	# One deliberate mouse turn, with acceleration and deceleration like a hand.
	var timing: Vector2 = {"school_traverse":Vector2(0.5, 1.5),
		"server_traverse":Vector2(0.9, 1.65), "annex_traverse":Vector2(1.05, 2.15),
		"pool_grand":Vector2(2.70, 3.85)}.get(shot, Vector2(0.72, 1.92))
	return initial + direction * PI * 0.5 * smoothstep(timing.x, timing.y, seconds)

func predict_walk(at: Vector3, initial: float, direction: float) -> Array[Vector3]:
	var result: Array[Vector3] = [at]
	var flat := Vector3.ZERO
	for frame in maxi(frames, 135):
		var yaw := walk_yaw(float(frame) / 30.0, initial, direction)
		var wish := Vector3(-sin(yaw), 0, -cos(yaw)) * Player.WALK_SPEED
		if shot == "pool_grand" and frame >= 81: wish = Vector3.ZERO
		flat = flat.lerp(wish, Player.ACCEL / 30.0)
		at += flat / 30.0
		result.append(at)
	return result

func walk_clear(points: Array[Vector3], explain := false) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS + 0.10
	capsule.height = Player.BODY_HEIGHT - 0.10
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	var space := game.get_world_3d().direct_space_state
	for i in range(0, points.size() - 1, 3):
		var a := points[i]
		var b := points[mini(i + 3, points.size() - 1)]
		var ground := ray(a + Vector3.UP * 0.2, a - Vector3.UP * 0.20)
		if ground.is_empty() or absf(ground.position.y - a.y) > 0.10:
			if explain: print("PATH_BLOCK support at=", a, " ground=", ground)
			return false
		query.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * 0.91)
		var overlaps := space.intersect_shape(query, 1)
		if not overlaps.is_empty():
			if explain: print("PATH_BLOCK overlap at=", a, " collider=", overlaps[0].collider.name)
			return false
		query.motion = b - a
		if float(space.cast_motion(query)[0]) < 0.999:
			if explain: print("PATH_BLOCK travel at=", a, " to=", b)
			return false
	return true

func setup_traversal() -> void:
	for dx in range(-2, 3):
		for dz in range(-2, 3): game.cm._build(room_cell + Vector2i(dx, dz))
	await draw(6)
	var racks: Array[Vector3] = []
	if shot == "server_traverse":
		for node in game.cm.find_children("*", "Node3D", true, false):
			if node.has_meta("data_center_rack"): racks.append(node.global_position + Vector3.UP)
	var origin := Vector3(room_cell.x * 12, 0, room_cell.y * 12)
	var floor_h: float = game.cm.chunk_at(room_cell)._floor_h()
	var best := -INF
	for x in [0.85, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 11.15]:
		for z in [0.85, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 11.15]:
			var start := origin + Vector3(x, floor_h + 0.01, z)
			for angle in 8:
				for direction in [-1.0, 1.0]:
					if shot in ["school_traverse", "annex_traverse"] and direction > 0.0: continue
					var yaw := angle * PI / 4.0
					var points := predict_walk(start, yaw, direction)
					if shot == "annex_flood":
						var end_local := points[-1] - Vector3(flooded_root.x * 12, 0, flooded_root.y * 12)
						if minf(minf(end_local.x, 36-end_local.x), minf(end_local.z, 36-end_local.z)) < 9.0: continue
					if not walk_clear(points): continue
					var score := 0.0
					for frame in [12, 54, 96]:
						var eye := points[frame] + Vector3.UP * Player.CAM_H
						var y := walk_yaw(frame / 30.0, yaw, direction)
						var forward := Vector3(-sin(y), 0, -cos(y))
						var hit := ray(eye, eye + forward * 24.0)
						score += 24.0 if hit.is_empty() else eye.distance_to(hit.position)
						for rack in racks:
							var delta := rack - eye
							if delta.length() > 12 or delta.normalized().dot(forward) < 0.55: continue
							hit = ray(eye, rack)
							if hit.is_empty() or eye.distance_to(hit.position) > delta.length() - 1.2: score += 10.0
					if score > best:
						best = score; walk_predictions = points; turn_yaw_start = yaw; turn_sign = direction
	assert(not walk_predictions.is_empty(), "No clear turning route in generated architecture")
	start_walk(walk_predictions[0], Vector3(-sin(turn_yaw_start), 0, -cos(turn_yaw_start)))
	print("TRAILER_TURN_PLAN start=", walk_predictions[0], " yaw=", rad_to_deg(turn_yaw_start), " turn=", turn_sign * 90, " end=", walk_predictions[-1])

func start_walk(at: Vector3, forward: Vector3) -> void:
	traversal = true
	game.player.teleport(at)
	game.player.rotation.y = atan2(-forward.x, -forward.z)
	game.player._pitch = 0.0
	game.player.head_bob_strength = 1.0
	game.player.handheld_camera_enabled = true
	game.player.handheld_camera_strength = 0.55
	game.player._cam_y = Player.CAM_H
	game.player.base_fov = 84.0
	game.player.dev_walk = false
	for i in 8: game.player._physics_process(1.0 / 30.0)
	game.player._prev_pos = game.player.global_position
	game.player._curr_pos = game.player.global_position
	game.player._process(1.0 / 30.0)
	traversal_start = game.player.global_position
	cam.current = true

func setup_pool() -> void:
	if shot == "pool_floaties":
		# A generated room already covered by the game's float-physics audit.
		await load_cell(Vector2i(-2, 2))
		var flamingo: Node3D
		for room: Chunk in game.cm.chunks.values():
			for node in room.find_children("*", "RigidBody3D", true, false):
				if node.has_meta("pool_flamingo_float"): flamingo = node; break
			if flamingo != null: break
		assert(flamingo != null, "Known generated flamingo room missing")
		target = flamingo.global_position + Vector3.UP * 0.6
		base_eye = target + Vector3(-3.1, 1.0, 2.7)
		base_eye.y = Chunk.POOL_DECK_Y + Player.CAM_H
		motion = Vector3(1.5, 0, -0.8)
		set_eye(base_eye, target)
		print("TRAILER_FLOAT flamingo at=", flamingo.global_position)
		return
	var root_cell := Vector2i(1 << 30, 1 << 30)
	for radius in 30:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var c := Vector2i(x, z)
				if WorldGen.room_id(game.cm.world_seed, c) == c and WorldGen.pool_grand_cistern(game.cm.world_seed, c):
					root_cell = c; break
			if root_cell.x != 1 << 30: break
		if root_cell.x != 1 << 30: break
	assert(root_cell.x != 1 << 30, "No grand Cistern")
	await load_cell(root_cell)
	for dx in range(-1, 3):
		for dz in range(-1, 3): game.cm._build(root_cell + Vector2i(dx, dz))
	await draw(8)
	var origin := Vector3(root_cell.x * 12, 0, root_cell.y * 12)
	var floats: Array[Node3D] = []
	for dx in 2:
		for dz in 2:
			var chunk: Chunk = game.cm.chunk_at(root_cell + Vector2i(dx, dz))
			for node in chunk.find_children("*", "RigidBody3D", true, false):
				if node.is_in_group("pool_pushable_floats"):
					floats.append(node)
					print("TRAILER_FLOAT ", node.name, " at=", node.global_position, " metadata=", node.get_meta_list())
	assert(floats.size() >= 4, "Grand pool floaties missing")
	base_eye = origin + Vector3(2.25, Chunk.POOL_DECK_Y + Player.CAM_H, 18.5)
	target = origin + Vector3(15.0, 0.55, 7.0)
	motion = Vector3(0, 0, -8.0)
	if shot == "pool_grand":
		# Follow the clear outer deck, then stop and turn into the grand hall.
		# Corner piers block a continuous quarter-circle, so respect the room.
		turn_yaw_start = 0.0
		turn_sign = -1.0
		walk_predictions = predict_walk(origin + Vector3(0.75, Chunk.POOL_DECK_Y + 0.01, 18.5), turn_yaw_start, turn_sign)
		assert(walk_clear(walk_predictions, true), "Grand-pool approach is obstructed")
		start_walk(walk_predictions[0], Vector3.FORWARD)
		camera_yaw_offset = deg_to_rad(-40.0)
		print("TRAILER_TURN_PLAN pool start=", walk_predictions[0], " end=", walk_predictions[-1])
	elif shot == "pool_girl":
		base_eye = origin + Vector3(2.25, Chunk.POOL_DECK_Y + Player.CAM_H, 17.5)
		target = base_eye + Vector3(0, 0, -10)
		motion = Vector3(0, 0, 1.0)
	if not traversal: set_eye(base_eye, target)
	print("TRAILER_POOL root=", root_cell, " floats=", floats.size())

func setup_flooded_annex() -> void:
	var root_cell := Vector2i(1 << 30, 1 << 30)
	for radius in 60:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var cell := Vector2i(x, z)
				if WorldGen.cell_style(game.cm.world_seed, cell, 2) == WorldGen.ANNEX_FLOODED_HALL and WorldGen.annex_room_id(game.cm.world_seed, cell) == cell:
					root_cell = cell; break
			if root_cell.x != 1 << 30: break
		if root_cell.x != 1 << 30: break
	assert(root_cell.x != 1 << 30, "No flooded Annex hall found")
	flooded_root = root_cell
	await load_cell(root_cell + Vector2i(1, 1))
	var water_count := 0
	var pillar_count := 0
	for dx in 3:
		for dz in 3:
			var chunk: Chunk = game.cm.chunk_at(root_cell + Vector2i(dx, dz))
			for node in chunk.find_children("*", "Node3D", true, false):
				if node.has_meta("annex_flood_water"): water_count += 1
				if node.has_meta("annex_flood_pillar"): pillar_count += 1
	assert(water_count == 9 and pillar_count == 81, "Flooded hall is incomplete")
	await setup_traversal()
	game.player._pitch = -0.07
	print("TRAILER_FLOODED_HALL root=", root_cell, " water_surfaces=", water_count, " pillars=", pillar_count)

func setup_wave() -> void:
	var placement = preload("res://scripts/hallway_wave_placement.gd")
	var excluded: Array[Vector2i] = []
	var layout: Dictionary = placement.find(game.cm.world_seed, game.active_level, 0, excluded)
	var room: Chunk
	while not layout.is_empty():
		await load_cell(layout.cell)
		room = game.cm.chunk_at(layout.cell)
		if not placement.eligible(room).is_empty(): break
		excluded.append(layout.cell)
		layout = placement.find(game.cm.world_seed, game.active_level, 0, excluded)
	assert(not layout.is_empty(), "No production wave corridor")
	var frame_basis := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT) if layout.axis == 1 else Basis.IDENTITY
	base_eye = room.global_position + Vector3(6, room._floor_h(), 6) + frame_basis * Vector3(-0.20, 1.6, -5.0)
	target = room.global_position + Vector3(6, room._floor_h(), 6) + frame_basis * Vector3(0, 1.6, 4.0)
	motion = frame_basis * Vector3(0.15, 0, 1.1)
	set_eye(base_eye, target)
	game.player.set_flashlight(true)
	effect = preload("res://scripts/hallway_wave_surface.gd").new()
	room.add_child(effect)
	assert(await effect.setup(room, layout.axis, layout.width, layout.height), "Wave setup failed")
	print("TRAILER_EFFECT wave cell=", layout.cell)

func setup_breath() -> void:
	var placement = preload("res://scripts/environment_breath_placement.gd")
	for room: Chunk in game.cm.chunks.values():
		var choices: Array = placement.candidates(room)
		for choice: Dictionary in choices:
			var focus: Vector3 = room.to_global(choice.center)
			var normal: Vector3 = room.global_basis * choice.face.normal
			base_eye = focus + normal * 4.0 + choice.face.u * 1.0
			base_eye.y = room.global_position.y + room._floor_h() + Player.CAM_H
			target = focus
			set_eye(base_eye, target)
			await draw(2)
			if not placement.visible(choice, room, cam): continue
			effect = preload("res://scripts/environment_breath_surface.gd").new()
			room.add_child(effect)
			assert(effect.setup(choice, "breath"), "Breath setup failed")
			motion = choice.face.u * -0.7
			game.player.set_flashlight(true)
			print("TRAILER_EFFECT breath cell=", room.cell)
			return
	assert(false, "No visible breathing wall")

func setup_door() -> void:
	var director: Node = game._native_doorways
	director.allowed = func(): return true
	director.pacing = null
	for radius in 22:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				for side in [0, 2]:
					var at := Vector2i(x, z)
					var info: Dictionary = game.cm.native_doorway_plan.candidate(at, side)
					if info.is_empty(): continue
					await load_cell(at)
					var centre: Vector3 = director._site_centre(at, side, info.t, Chunk.cell_floor_h(game.cm.world_seed, at, game.active_level))
					var normal := Vector3(WorldGen.DIRV[side].x, 0, WorldGen.DIRV[side].y)
					base_eye = centre - normal * 5.8 + Vector3.UP * Player.CAM_H
					target = centre + Vector3.UP * 1.25
					motion = normal * 0.7
					set_eye(base_eye, target)
					await draw(2)
					if director.start_event(at, side):
						effect = director.active
						print("TRAILER_EFFECT door cell=", at, " side=", side)
						return
	assert(false, "No prepared native doorway")

func setup_portal() -> void:
	# Keep the native transition fade visible while the ordinary HUD is hidden.
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 2
	game.add_child(fade_layer)
	game._fade.reparent(fade_layer)
	game._fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visit = game._realm_visit
	assert(visit != null)
	await load_cell(visit._record.cell)
	base_eye = visit.source_centre - visit.source_forward * 5.6 + Vector3.UP * Player.CAM_H
	target = visit.source_centre + Vector3.UP * 1.3
	motion = visit.source_forward * 1.0
	set_eye(base_eye, target)
	game.cm.stream_focus = game.player.global_position
	for i in 1600:
		if visit.phase == RealmExcursion.Phase.WAITING and is_instance_valid(visit.window): break
		await draw()
	assert(is_instance_valid(visit.window), "Realm preview not ready")
	game.run.resume_rules(0.0)
	game.run.arrival_grace = 0.0
	game._photo_camera.set_process(false)
	game._photo_camera._raise(true)
	cam.fov = 65
	start_walk(base_eye - Vector3.UP * Player.CAM_H, visit.source_forward)
	traversal = false
	await draw(12)
	print("TRAILER_EFFECT portal destination=", visit.destination_theme)

func setup_cross() -> void:
	tv = VhsRitual.new()
	tv.objective = false
	tv.setup_key = "promo-cross"
	tv.pinned_tape = "res://videos/tapes/short_beginning_00.ogv" if shot == "cross_warning" else "res://videos/tapes/short_beginning_02.ogv"
	game.add_child(tv)
	tv.position = game.player.position - cam.global_basis.z * 2.0
	await draw(1)
	tv._on_activated(game.player)
	await draw(20)
	# Keep the same native tape player and clock. Present its decoded texture
	# edge to edge below the game's VHS pass for the trailer's interview cuts.
	if shot == "cross_stay": tv._video.stream_position = 22.2
	var screen_layer := CanvasLayer.new()
	screen_layer.layer = 90
	game.add_child(screen_layer)
	var screen := TextureRect.new()
	screen.texture = tv._video.get_video_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._post_process.ensure_scene_copy()
	print("TRAILER_EFFECT cross ", tv.pinned_tape)

func pose_portal(frame: int) -> void:
	if frame == 30:
		await game._photo_camera._take_photo()
	if frame == 56:
		game._photo_camera._pending_risk = false
		game._photo_camera._review_left = 0.01
		game._photo_camera._process(0.02)
		game._photo_camera._lower()
		print("TRAILER_PORTAL_OPEN frame=", frame, " open=", visit.seal.opened)
	if visit.phase != portal_last_phase:
		print("TRAILER_PORTAL_PHASE frame=", frame, " phase=", RealmExcursion.Phase.keys()[visit.phase], " position=", game.player.global_position)
		portal_last_phase = visit.phase
	if visit.phase == RealmExcursion.Phase.VISITING and portal_entered_frame < 0:
		portal_entered_frame = frame
		visit.threats.passive = true
		visit.threats.set_physics_process(false)
		visit.pocket.set_process(false)
		var cell := Vector2i(floori(visit.destination_position.x / 12.0), floori(visit.destination_position.z / 12.0))
		var forward := Vector3(-sin(visit.destination_yaw), 0, -cos(visit.destination_yaw))
		var side := 0 if forward.x > 0.5 else (1 if forward.x < -0.5 else (2 if forward.z > 0.5 else 3))
		var info := WorldGen.edge_info(visit.pocket.world_seed, cell, side, visit.destination_theme)
		var centre := Vector3(cell.x * 12, 0, cell.y * 12)
		centre += Vector3(12.0 if side == 0 else 0.0, 0, float(info.t)) if side < 2 else Vector3(float(info.t), 0, 12.0 if side == 2 else 0.0)
		portal_waypoints = [centre - forward * 1.5, centre + forward * 2.7]
		print("TRAILER_PORTAL_ROUTE edge=", info, " waypoints=", portal_waypoints)
		print("TRAILER_PORTAL_CROSSED frame=", frame, " destination=", game.player.level_theme)
	if visit.phase == RealmExcursion.Phase.VISITING and not portal_waypoints.is_empty():
		var delta: Vector3 = portal_waypoints[0] - game.player.global_position
		delta.y = 0.0
		if delta.length() < 0.55 and portal_waypoints.size() > 1:
			portal_waypoints.pop_front()
			delta = portal_waypoints[0] - game.player.global_position
			delta.y = 0.0
		var wanted_yaw := atan2(-delta.x, -delta.z)
		var yaw_delta := clampf(wrapf(wanted_yaw - game.player.rotation.y, -PI, PI), -0.085, 0.085)
		game.player._apply_mouse_look(Vector2(-yaw_delta / (Player.SENS * game.player.sensitivity_multiplier), 0))
	game.player.dev_walk = frame >= 65 and visit.phase in [RealmExcursion.Phase.WAITING, RealmExcursion.Phase.VISITING]
	if visit.phase in [RealmExcursion.Phase.WAITING, RealmExcursion.Phase.VISITING]:
		game.player._physics_process(1.0 / 30.0)
	game.player._prev_pos = game.player.global_position
	game.player._curr_pos = game.player.global_position
	game.player._process(1.0 / 30.0)
	trajectory.append({"frame":frame,"phase":RealmExcursion.Phase.keys()[visit.phase],
		"theme":game.player.level_theme,"position":[cam.global_position.x,cam.global_position.y,cam.global_position.z],
		"body":[game.player.global_position.x,game.player.global_position.y,game.player.global_position.z],
		"seal_open":visit.seal.opened})

func pose(frame: int) -> void:
	var t := float(frame) / maxf(1.0, frames - 1.0)
	var seconds := float(frame) / 30.0
	if shot == "portal":
		await pose_portal(frame)
		return
	if traversal:
		game.player.dev_walk = not (shot == "pool_grand" and frame >= 81)
		var yaw := walk_yaw(seconds, turn_yaw_start, turn_sign)
		var yaw_delta := wrapf(yaw - game.player.rotation.y, -PI, PI)
		# Use the production mouse-look handler so the handheld spring responds.
		game.player._apply_mouse_look(Vector2(-yaw_delta / (Player.SENS * game.player.sensitivity_multiplier), 0))
		game.player._physics_process(1.0 / 30.0)
		# Render the current fixed tick; live-frame interpolation is unnecessary
		# in an offline 30 fps capture and can otherwise duplicate alternating poses.
		game.player._prev_pos = game.player.global_position
		game.player._curr_pos = game.player.global_position
		game.player._process(1.0 / 30.0)
		var look_offset := camera_yaw_offset * (1.0 - smoothstep(0.5, 1.8, seconds))
		if shot == "pool_grand": look_offset = camera_yaw_offset * (1.0 - smoothstep(2.7, 3.85, seconds))
		cam.rotation.y += look_offset
		trajectory.append({"frame":frame,"position":[cam.global_position.x,cam.global_position.y,cam.global_position.z],
			"body":[game.player.global_position.x,game.player.global_position.y,game.player.global_position.z],
			"rotation":[cam.rotation.x,cam.rotation.y,cam.rotation.z], "speed":Vector2(game.player.velocity.x,game.player.velocity.z).length(),
			"planned_error":Vector2(game.player.global_position.x-walk_predictions[frame+1].x,game.player.global_position.z-walk_predictions[frame+1].z).length()})
		return
	var eye := base_eye + motion * t
	if shot.ends_with("run"):
		set_eye(eye, eye + motion.normalized() * 10)
		return
	if shot.begins_with("cross_"): return
	if shot == "death":
		if not death_started:
			set_eye(base_eye, target)
			effect = preload("res://scripts/caught_sequence.gd").new()
			view.add_child(effect)
			effect.begin(game.player, figure)
			effect.set_process(false)
			death_started = true
		figure._animate(1.0/30.0, false)
		effect._sample(seconds)
		return
	if shot.ends_with("kill") or shot == "pool_girl":
		set_eye(eye, target_initial)
		if is_instance_valid(figure):
			if frame == 12: figure.suppressed = false
			if frame == 28 and shot.ends_with("kill"): game.player.set_flashlight(true)
			if figure._fade < 0: target_initial = figure.global_position + Vector3.UP * (0.8 if figure.walker_model_index == 9 else 1.22)
			figure._physics_process(1.0/30.0)
			if figure._burn_disintegration_started and not burn_logged:
				print("TRAILER_KILL_CONFIRMED ", shot, " frame=", frame)
				burn_logged = true
		return
	set_eye(eye, target + motion * t * 0.35)
	if shot == "wave": effect.pose(0.15 + t * 0.72)
	if shot == "breath": effect.pose(preload("res://scripts/environment_breath_profile.gd").weights("breath", t))
	if shot == "doors":
		var amount := clampf(seconds / 0.9, 0, 1) if seconds < 2.4 else clampf(1.0 - (seconds - 2.4) / 0.9, 0, 1)
		effect.opening = seconds < 2.4
		effect.pose(amount, false)
		effect.advance_magic(1.0/30.0)

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--test-mode"))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view = SubViewport.new()
	view.size = Vector2i(width, height)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_taa = true
	view.positional_shadow_atlas_size = 4096
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	await draw(45)
	if paused: paused = false
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.player.head_bob_strength = 1.0
	game.player.handheld_camera_enabled = true
	game.set_process_unhandled_input(false)
	game.cm.set_process(false)
	game._set_presence(game.Presence.SILENT)
	if game.run != null: game.run.set_process(false); game.run.set_physics_process(false)
	if is_instance_valid(game._architectural_events): game._architectural_events.set_physics_process(false)
	game._breathing.set_physics_process(false)
	game._native_doorways.set_process(false)
	game._native_doorways.set_physics_process(false)
	game._post_process.set_effects(true, false)
	view.scaling_3d_scale = 480.0 / float(height)
	cam = game.player.cam
	cam.fov = 84.0
	await setup_room()
	if shot.ends_with("traverse"): await setup_traversal()
	if shot == "annex_flood": await setup_flooded_annex()
	if shot in ["pool_grand", "pool_floaties", "pool_girl"]: await setup_pool()
	if shot.ends_with("kill") or shot in ["death", "pool_girl"]: await setup_monster()
	if shot == "wave": await setup_wave()
	if shot == "breath": await setup_breath()
	if shot == "doors": await setup_door()
	if shot == "portal": await setup_portal()
	if shot.begins_with("cross_"): await setup_cross()
	quiet_hud()
	await draw(35)
	var dir := output.path_join(shot)
	DirAccess.make_dir_recursive_absolute(dir)
	for frame in frames:
		await pose(frame)
		quiet_hud()
		await draw()
		assert(game._post_process.is_vhs_enabled() and not game._post_process.is_crt_enabled(), "Trailer requires VHS on / CRT off")
		assert(view.get_texture().get_image().save_jpg(dir.path_join("frame-%04d.jpg" % frame), 0.97) == OK)
		if frame % 30 == 0: print("TRAILER_FRAME ", shot, " ", frame, "/", frames)
		if tv != null and frame % 30 == 0: print("TRAILER_CROSS_SYNC ", frame, " ", tv._video.stream_position)
	print("TRAILER_DONE ", shot, " frames=", frames)
	if traversal:
		var travelled: float = game.player.global_position.distance_to(traversal_start)
		print("TRAILER_WALK_DISTANCE ", travelled)
		var file := FileAccess.open(dir.path_join("trajectory.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(trajectory))
		if frames > 90: assert(travelled > 6.0, "Traversal blocked too early")
	if shot == "portal":
		var file := FileAccess.open(dir.path_join("trajectory.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(trajectory))
		if frames > 150: assert(portal_entered_frame > 0 and portal_entered_frame < frames - 45, "Portal crossing and destination walk were not captured")
	if shot.ends_with("kill"): assert(burn_logged, "Monster kill was not captured")
	quit()
