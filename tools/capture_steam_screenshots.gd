extends "res://tools/trailer_capture.gd"
## Steam stills: unmodified production Main, its native HUD and VHS pass.
## Only the camera, existing actors and sampling time are directed. No compositing.
## --test-mode keeps campaign and album persistence isolated from the real profile.

var sample_frames: Array[int] = [0, 42, 84, 118]
var records: Array[Dictionary] = []
var slot_cabinet: Node3D
var gate_glass: Node3D
const CUSTOM_STYLES := {"airport": WorldGen.AIR_CONCOURSE, "airport_gate": WorldGen.AIR_GATE,
	"school_gym": WorldGen.SCH_GYM, "prison": WorldGen.PRISON_CELLBLOCK,
	"bloom": WorldGen.BLOOM_HEART}

func quiet_hud() -> void:
	# Override the trailer's deliberate removal of overlays. Respect the game's
	# own hide/show rules while looking through its camera or reviewing a photo.
	if is_instance_valid(game):
		game._sync_osd_visible()
		if is_instance_valid(game._descent_hud): game._descent_hud.visible = true
		if is_instance_valid(game._hint) and "TEST MODE" in game._hint.text:
			# Build the normal production help line. This synchronous UI-only
			# method does not change the QA session's persistence isolation.
			var isolated: bool = game.opts.test_mode
			game.opts.test_mode = false
			game._set_mode_hint()
			game.opts.test_mode = isolated

func setup_slots() -> void:
	for at in game.descent_route.casino_landmarks:
		if game.descent_route.casino_landmarks[at] != CasinoLandmarks.LAST_CHANCE: continue
		await load_cell(at)
		var chunk: Chunk = game.cm.chunk_at(at)
		for node in chunk.get_children():
			if node.has_meta("powered") and node.get_meta("powered"):
				slot_cabinet = node
		break
	assert(slot_cabinet != null)
	target = slot_cabinet.global_position + Vector3.UP * 1.2
	base_eye = target + slot_cabinet.global_basis.z * 4.3 + slot_cabinet.global_basis.x * -1.0
	base_eye.y = slot_cabinet.global_position.y + Player.CAM_H
	motion = slot_cabinet.global_basis.x * 1.5
	cam.fov = 74
	set_eye(base_eye, target)

func setup_custom_room() -> void:
	await load_cell(find_style(CUSTOM_STYLES[shot]))
	var chunk: Chunk = game.cm.chunk_at(room_cell)
	var span := float(chunk.room_n) * WorldGen.CELL_SIZE
	for dx in range(-1, chunk.room_n + 1):
		for dz in range(-1, chunk.room_n + 1):
			game.cm._build(chunk.room_root + Vector2i(dx, dz))
	await draw(16)
	var floor_y := chunk._floor_h()
	var origin := Vector3(chunk.room_root.x * WorldGen.CELL_SIZE, floor_y,
		chunk.room_root.y * WorldGen.CELL_SIZE)
	base_eye = origin + Vector3(1.8, Player.CAM_H, span - 2.0)
	target = origin + Vector3(span * 0.63, 1.5, span * 0.3)
	motion = Vector3.ZERO
	cam.fov = 82
	set_eye(base_eye, target)
	if shot == "airport_gate":
		gate_glass = find_loaded_gate_window()
		# Some gate layouts have no solid apron wall; select an actual window
		# in a generated gate instead of fabricating one for the screenshot.
		for radius in 20:
			if gate_glass != null: break
			for x in range(-radius, radius + 1):
				if gate_glass != null: break
				for z in range(-radius, radius + 1):
					if maxi(absi(x), absi(z)) != radius: continue
					var at := Vector2i(x, z)
					if WorldGen.cell_style(game.cm.world_seed, at, game.active_level) != WorldGen.AIR_GATE: continue
					await load_cell(at)
					gate_glass = find_loaded_gate_window()
					if gate_glass != null: break
		assert(gate_glass != null, "Selected airport gate has no window")
	print("STEAM_CUSTOM_ROOM ", shot, " cell=", room_cell, " span=", span)

func find_loaded_gate_window() -> Node3D:
	for room: Chunk in game.cm.chunks.values():
		for node in room.find_children("*", "Node3D", true, false):
			if node.has_meta("airport_barrier_glass"): return node
	return null

func custom_pose(index: int) -> void:
	var chunk: Chunk = game.cm.chunk_at(room_cell)
	var span := float(chunk.room_n) * WorldGen.CELL_SIZE
	var origin := Vector3(chunk.room_root.x * WorldGen.CELL_SIZE, chunk._floor_h(),
		chunk.room_root.y * WorldGen.CELL_SIZE)
	var positions := [Vector3(1.8, Player.CAM_H, span - 2.0),
		Vector3(span - 1.8, Player.CAM_H, span - 2.0),
		Vector3(1.8, Player.CAM_H, 2.0)]
	var targets := [Vector3(span * .63, 1.5, span * .3),
		Vector3(span * .37, 1.5, span * .3), Vector3(span * .63, 1.5, span * .7)]
	base_eye = origin + positions[index % positions.size()]
	target = origin + targets[index % targets.size()]
	if shot == "prison":
		var ax := WorldGen.r01(game.cm.world_seed, chunk.room_root.x, chunk.room_root.y, 1840) < 0.5
		var eyes := [Vector3(1.2, Player.CAM_H, 6.0), Vector3(10.8, Player.CAM_H, 6.0), Vector3(2.4, Player.CAM_H, 5.2)]
		var looks := [Vector3(10.8, 1.4, 6.0), Vector3(1.2, 1.4, 6.0), Vector3(9.5, 1.4, 6.8)]
		var p: Vector3 = eyes[index]
		var q: Vector3 = looks[index]
		if not ax:
			p = Vector3(p.z, p.y, p.x)
			q = Vector3(q.z, q.y, q.x)
		base_eye = origin + p
		target = origin + q
		cam.fov = 78
	if shot == "airport_gate":
		var across := gate_glass.global_basis.x.normalized()
		var toward := gate_glass.global_basis.z.normalized()
		base_eye = gate_glass.global_position - toward * 7.4 + across * [0.0, -4.7, 4.7][index]
		base_eye.y = origin.y + Player.CAM_H
		target = gate_glass.global_position + toward * 1.0
		target.y = origin.y + 1.8
		cam.fov = 78
	set_eye(base_eye, target)
	await draw(22)

func take_still(frame: int) -> void:
	assert(game._post_process.is_vhs_enabled())
	assert(not game._post_process.is_crt_enabled())
	var dir := output.path_join(shot)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("frame-%04d.png" % frame)
	var screenshot := view.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(path) == OK)
	records.append({"file":path, "shot":shot, "frame":frame,
		"seed":game.world_seed, "theme":game.active_level,
		"width":1920, "height":1080, "vhs":true, "crt":false,
		"native_osd_visible":game._osd_layer.visible,
		"native_descent_hud_visible":game._descent_hud.visible,
		"photo_camera_raised":game._photo_camera._raised,
		"position":[cam.global_position.x,cam.global_position.y,cam.global_position.z],
		"fov":cam.fov, "renderer":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name()})
	print("STEAM_STILL ", path, " VHS=on CRT=off native_osd=", game._osd_layer.visible)

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--test-mode"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			sample_frames.clear()
			for value in arg.trim_prefix("--samples=").split(","): sample_frames.append(int(value))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
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
	view.scaling_3d_scale = 480.0 / 1080.0
	cam = game.player.cam
	cam.fov = 84.0
	if CUSTOM_STYLES.has(shot):
		await setup_custom_room()
	else:
		await setup_room()
		if shot == "casino_slots": await setup_slots()
		if shot.ends_with("traverse"): await setup_traversal()
		if shot == "annex_flood": await setup_flooded_annex()
		if shot in ["pool_grand", "pool_floaties", "pool_girl"]: await setup_pool()
		if shot.ends_with("kill") or shot == "pool_girl": await setup_monster()
		if shot == "wave": await setup_wave()
		if shot == "portal": await setup_portal()
	# Let initial arrival text and transient scene loading settle naturally.
	await draw(185)
	if CUSTOM_STYLES.has(shot):
		for index in 3:
			await custom_pose(index)
			take_still(index)
	else:
		for frame in frames:
			await pose(frame)
			await draw()
			if frame in sample_frames: take_still(frame)
	var dir := output.path_join(shot)
	FileAccess.open(dir.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	assert(records.size() > 0)
	print("STEAM_CAPTURE_DONE ", shot, " stills=", records.size())
	quit()
