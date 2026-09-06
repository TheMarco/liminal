extends "res://tools/capture_pool_water.gd"
## Eight seconds of the actual Player entering, wading, turning and stopping.
## --first-person selects the player's eye; otherwise a fixed surface view.
## --blackout verifies that spray/froth respect the room's lighting state.

var first_person := false
var blackout := false
var measure := false
var jpeg := false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--first-person": first_person = true
		if arg == "--blackout": blackout = true
		if arg == "--measure": measure = true
		if arg == "--jpeg": jpeg = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(output)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_taa = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	if measure: RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	stage = Node3D.new()
	view.add_child(stage)
	env_node = WorldEnvironment.new()
	env_node.environment = EnvBuilder.build(THEME)
	view.add_child(env_node)
	var cell: Vector2i = anchors()[91]
	var ws := WorldGen.level_seed(SEED, THEME)
	var centre: Chunk
	for x in range(cell.x - 2, cell.x + 3):
		for z in range(cell.y - 2, cell.y + 3):
			var chunk := Chunk.new(ws, Vector2i(x, z), THEME)
			chunk.position = Vector3(x * Chunk.S, 0, z * Chunk.S)
			stage.add_child(chunk)
			if Vector2i(x, z) == cell: centre = chunk
	var water: MeshInstance3D
	for node in centre.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("pool_water_surface"): water = node; break
	if water == null:
		printerr("No channel water")
		quit(1)
		return
	var c := water.global_position
	var size: Vector2 = water.mesh.size
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.fov = 70
	camera.position = c + Vector3(-0.7, 1.5, -3.4)
	camera.look_at(c + Vector3(-0.7, 0, 0.1))
	camera.current = true
	await draw(140)
	if blackout:
		for chunk in stage.get_children(): chunk.set_blackout(true)
		env_node.environment.ambient_light_energy = 0.003
		await draw(40)
	var player := Player.new()
	player.world_seed = ws
	player.level_theme = THEME
	player.water_y = Chunk.POOL_WATER_Y
	player.position = c + Vector3(-2.4, Chunk.POOL_DECK_Y - c.y + 0.02, size.y * 0.5 + 0.5)
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.current = true
	player.dev_walk = false
	await physics_frame
	for i in 16:
		await physics_frame
		player._physics_process(1.0 / 60.0)
	player._water_fx.set_process(false)
	var material := Mats.pool_water()
	var original_shader: Shader = material.shader
	var source := original_shader.code
	var shader := Shader.new()
	var marker := source.find("shader_type spatial")
	var line_end := source.find("\n", marker)
	shader.code = (source.substr(0, line_end) + "\nuniform float capture_clock = 0.0;" + source.substr(line_end)).replace("TIME", "capture_clock")
	material.shader = shader
	var first_events := 0
	var entry_frame := -1
	for frame in 240:
		var t := float(frame) / 30.0
		player.dev_walk = t > 0.45 and t < 4.8
		if t > 1.3:
			player.rotation.y = -PI * 0.5 * smoothstep(1.3, 1.8, t)
		for tick in 2:
			await physics_frame
			player._physics_process(1.0 / 60.0)
			player._water_fx.set_process(false)
			player._water_fx.advance(1.0 / 60.0)
			player._water_fx.set_process(false)
		var fx: Node3D = player._water_fx
		if fx.events.size() > first_events:
			first_events = fx.events.size()
			print("EVENT frame=%d position=%s count=%d" % [frame, player.global_position, first_events])
			if entry_frame == -1: entry_frame = frame
		material.set_shader_parameter("capture_clock", 12.0 + t)
		for pair in fx._materials.values(): pair[1].set_shader_parameter("capture_clock", 12.0 + t)
		if first_person:
			camera.global_position = player.global_position + Vector3.UP * Player.CAM_H
			camera.rotation = Vector3(deg_to_rad(-30), player.rotation.y, 0)
		await draw()
		if jpeg:
			view.get_texture().get_image().save_jpg(output + "/frame-%04d.jpg" % frame, 0.96)
		else:
			view.get_texture().get_image().save_png(output + "/frame-%04d.png" % frame)
		if frame == 90 and measure: await compare_cost(fx)
	print("INTERACTION frames=240 entry=%d position=%s active=%d materials=%d" % [entry_frame, player.global_position, player._water_fx.events.size(), player._water_fx._materials.size()])
	material.shader = original_shader
	material.set_shader_parameter("capture_clock", null)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("POOL INTERACTION CAPTURE PASS")
	quit()

func compare_cost(fx: Node3D) -> void:
	# Same camera, lights, scene, residual ripples and frozen interaction age.
	# Alternate order to reduce warm-up bias. This measures this viewport only.
	for enabled in [true, false, false, true]:
		fx.advance(0.0)
		fx.set_process(false)
		if not enabled:
			for pair in fx._materials.values():
				pair[1].set_shader_parameter("fx_count", 0)
				pair[1].set_shader_parameter("fx_body", Vector4.ZERO)
		await draw(16)
		var times: Array[float] = []
		for i in 40:
			await draw()
			times.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
		times.sort()
		print("GPU interaction=%s median_ms=%.3f events=%d surfaces=%d" % [enabled, times[20], fx.events.size(), fx._materials.size()])
		view.get_texture().get_image().save_png(output + ("/disturbed.png" if enabled else "/quiet.png"))
	fx.advance(0.0)
	fx.set_process(false)
