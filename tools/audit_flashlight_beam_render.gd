extends "res://tools/lib/audit_base.gd"
## Native pixel check: the real torch shaft works without volumetric fog,
## responds to battery dimming and stops at a nearby opaque wall.
const OUT := "res://build/flashlight-beam"
var view: SubViewport
var player: Player
var observer: Camera3D

func box(size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.14, 0.15, 0.17)
	material.roughness = 1.0
	instance.material_override = material
	view.add_child(instance)
	return instance

func capture(label: String) -> Image:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := view.get_texture().get_image()
	expect(picture.save_png(OUT.path_join(label + ".png")) == OK, "could not save " + label)
	return picture

func gain(before: Image, after: Image, region := Rect2i(360, 180, 560, 360)) -> float:
	var sum := 0.0
	var count := 0
	for y in range(region.position.y, region.end.y, 4):
		for x in range(region.position.x, region.end.x, 4):
			sum += after.get_pixel(x, y).get_luminance() - before.get_pixel(x, y).get_luminance()
			count += 1
	return sum / count

func render_stats(viewport: Viewport, beam: MeshInstance3D, enabled: bool) -> Dictionary:
	beam.visible = enabled
	for i in 12:
		await process_frame
	var samples: Array[float] = []
	for i in 30:
		await process_frame
		samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
	samples.sort()
	return {"gpu_ms": samples[samples.size() / 2], "draw_calls": RenderingServer.viewport_get_render_info(
		viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func describe_stats(before: Dictionary, after: Dictionary) -> String:
	var timing := "GPU timing unavailable"
	if before.gpu_ms > 0.0 and after.gpu_ms > 0.0:
		timing = "GPU_ms off=%.3f on=%.3f" % [before.gpu_ms, after.gpu_ms]
	return "draw_calls off=%d on=%d; %s" % [before.draw_calls, after.draw_calls, timing]

func capture_game() -> void:
	if not OS.get_cmdline_user_args().has("--capture-game"):
		return
	root.size = Vector2i(1280, 720)
	var game := await boot_game(43515953)
	var settings := GameSettings.new("/tmp/liminal-beam-%d.cfg" % OS.get_process_id())
	settings.set_value("fullscreen", false)
	settings.set_value("vhs_enabled", false)
	settings.set_value("crt_enabled", true)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	await await_until(func(): return not game._switching, 15000)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.cam.rotation = Vector3.ZERO
	game.player.set_flashlight(true)
	game.cm.set_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for preset in [1, 2]:
		settings.apply_quality_preset(preset)
		for enabled in [false, true]:
			game.player._flash_beam.visible = enabled
			for i in 20:
				await process_frame
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(OUT.path_join("game-%s-%s.png" % [GameSettings.QUALITY_NAMES[preset].to_lower(), "shaft" if enabled else "surface-only"])) == OK,
				"game capture failed")
		var off_stats := await render_stats(root, game.player._flash_beam, false)
		var on_stats := await render_stats(root, game.player._flash_beam, true)
		print("FLASHLIGHT_BEAM_GAME %s level=%d source=480p %s" % [GameSettings.QUALITY_NAMES[preset], game.active_level, describe_stats(off_stats, on_stats)])
	await teardown_game(game)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("flashlight beam pixel check requires a native GPU renderer")
		finish("flashlight beam pixels")
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.title = "Liminal — flashlight beam check"
	Engine.max_fps = 60
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.004, 0.005, 0.007)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.04
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	# Match Low/Medium: do not let true fog disguise a missing shaft.
	environment.environment.volumetric_fog_enabled = false
	view.add_child(environment)
	box(Vector3(8, 0.1, 18), Vector3(0, -0.05, -7))
	box(Vector3(8, 0.1, 18), Vector3(0, 3.5, -7))
	box(Vector3(0.1, 3.5, 18), Vector3(-4, 1.75, -7))
	box(Vector3(0.1, 3.5, 18), Vector3(4, 1.75, -7))
	box(Vector3(8, 3.5, 0.1), Vector3(0, 1.75, -12))
	box(Vector3(0.6, 2.4, 0.6), Vector3(-1.8, 1.2, -5))
	player = Player.new()
	view.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.cam.rotation = Vector3.ZERO
	player.cam.position = Vector3(0, Player.CAM_H, 0)
	player.set_flashlight(true)
	player._flash_beam.visible = false
	var before := await capture("surface-only")
	player._flash_beam.visible = true
	var after := await capture("shaft")
	var full_gain := gain(before, after)
	var centre_gain := gain(before, after, Rect2i(600, 320, 80, 80))
	expect(full_gain > 0.003, "beam is not visible with volumetric fog disabled")
	expect(full_gain < 0.022 and centre_gain < 0.055, "air scattering washes out the central target")
	player._set_flashlight_energy(Player.FLASH_ENERGY * 0.5)
	player._flash_beam.visible = false
	var dim_before := await capture("dim-surface-only")
	player._flash_beam.visible = true
	var dim := await capture("dim-shaft")
	var dim_gain := gain(dim_before, dim)
	expect(dim_gain > 0.0005 and dim_gain < full_gain * 0.8, "shaft does not follow battery dimming")
	player._set_flashlight_energy(Player.FLASH_ENERGY)
	var blocker := box(Vector3(8, 8, 0.05), Vector3(0, Player.CAM_H, -0.18))
	player._flash_beam.visible = false
	var blocked_before := await capture("wall-surface-only")
	player._flash_beam.visible = true
	var blocked := await capture("wall-shaft")
	var blocked_gain := gain(blocked_before, blocked)
	expect(absf(blocked_gain) < 0.002, "beam leaks through the near wall")
	blocker.queue_free()
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	for source in [360, 480, 720]:
		view.scaling_3d_scale = float(source) / 720.0
		var off_stats := await render_stats(view, player._flash_beam, false)
		var on_stats := await render_stats(view, player._flash_beam, true)
		expect(on_stats.draw_calls == off_stats.draw_calls + 1, "shaft added more than one draw call")
		print("FLASHLIGHT_BEAM_RENDER source=%dp %s" % [source, describe_stats(off_stats, on_stats)])
	observer = Camera3D.new()
	view.add_child(observer)
	observer.look_at_from_position(Vector3(3.2, 2.0, 1.5), Vector3(0, 1.3, -5))
	observer.current = true
	await capture("shaft-side")
	player.set_flashlight(false)
	expect(not player._flash_beam.is_visible_in_tree(), "shaft remains visible after the torch is off")
	print("FLASHLIGHT_BEAM_PIXELS full=%.4f centre=%.4f dim=%.4f near_wall=%.4f fog=false" % [full_gain, centre_gain, dim_gain, blocked_gain])
	view.queue_free()
	await process_frame
	await capture_game()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("flashlight beam pixels")
