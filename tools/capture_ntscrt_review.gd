extends "res://tools/lib/audit_base.gd"
## Native, repeatable game comparison. Uses a SubViewport for exact 1080p/4K
## even when the desktop is smaller. Never writes the player's settings.
## godot --path . --audio-driver Dummy --script tools/capture_ntscrt_review.gd -- --nologo --level=1
## Add --ntscrt-benchmark for two alternating rounds at each resolution.
## Add --ntscrt-motion for 270 PNG frames at 30 fps (Home/Worn/Bad, 3 s each).
const OUTPUT := "res://build/ntscrt-review"
var game: Node
var view: SubViewport
var settings: GameSettings
var rows: Array[Dictionary] = []

func settle(count := 12) -> void:
	for i in count:
		if is_instance_valid(game) and is_instance_valid(game._pause_menu):
			game._close_settings()
		await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if view.use_hdr_2d:
		image.linear_to_srgb()
	expect(image.save_png(OUTPUT.path_join(label + ".png")) == OK, "cannot save " + label)
	print("NTSCRT_CAPTURE ", label)

func benchmark(label: String, round_index: int) -> void:
	await settle(60)
	var durations: Array[float] = []
	var receiver_ms := 0.0
	var render_cpu := 0.0
	var render_gpu := 0.0
	var previous := Time.get_ticks_usec()
	for i in 180:
		await settle(1)
		var now := Time.get_ticks_usec()
		durations.append((now - previous) / 1000.0)
		previous = now
		var post: PostProcessController = game._post_process
		if post._experimental != null and post._experimental.visible:
			receiver_ms += post._experimental.last_cpu_usec / 1000.0
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid())
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
	var total := 0.0
	for value in durations:
		total += value
	durations.sort()
	var row := {"case": label, "round": round_index, "width": view.size.x, "height": view.size.y,
		"frames": durations.size(), "frame_mean_ms": total / durations.size(),
		"frame_median_ms": durations[durations.size() / 2],
		"frame_p95_ms": durations[int(durations.size() * 0.95)],
		"receiver_cpu_mean_ms": receiver_ms / durations.size(),
		"render_cpu_mean_ms": render_cpu / durations.size(),
		"render_gpu_mean_ms": render_gpu / durations.size() if render_gpu > 0.0 else null,
		"vram_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0}
	rows.append(row)
	print("NTSCRT_GAME_TIMING ", JSON.stringify(row))
	FileAccess.open(OUTPUT.path_join("game-timings.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))

func select_mode(mode: int, quality := 1) -> void:
	settings.apply_ntscrt_preset(1)
	settings.set_value("ntsc_auto_faults", false)
	settings.set_value("ntsc_quality", quality)
	settings.set_value("video_pipeline", mode)
	settings.set_value("vhs_enabled", true)
	settings.set_value("crt_enabled", true)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("NTSCRT visual review requires a GPU renderer")
		finish()
		return
	expect(OS.get_cmdline_user_args().has("--nologo"), "capture requires --nologo to isolate progress")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(640, 360)
	root.title = "Liminal — NTSCRT game review"
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.own_world_3d = true
	view.use_hdr_2d = true
	view.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var preview := TextureRect.new()
	preview.texture = view.get_texture()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(preview)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	await settle(30)
	expect(not game._progress_enabled, "capture must not change campaign progress")
	settings = GameSettings.new("/tmp/liminal-ntscrt-capture-%d.cfg" % OS.get_process_id())
	settings.set_value("hdr_enabled", false)
	settings.set_value("vsync", false)
	settings.set_value("frame_limit", 0)
	settings.set_value("handheld_camera", false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.cm.set_process(false)
	game.set_process(false)
	stop_audio(game)
	var camera := Camera3D.new()
	camera.fov = 77
	view.add_child(camera)
	camera.global_transform = game.player.cam.global_transform
	camera.current = true
	await settle(100)
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	var theme: int = game.active_level
	var prefix := "game-level-%d-" % theme
	select_mode(0)
	await settle(40)
	capture(prefix + "classic")
	for preset in 4:
		settings.set_value("video_pipeline", 1)
		settings.apply_ntscrt_preset(preset)
		settings.set_value("ntsc_auto_faults", false)
		await settle(90)
		capture(prefix + ["clean-transfer", "home-video", "worn-tape", "bad-reception"][preset])
	select_mode(1)
	settings.set_value("crt_enabled", false)
	await settle(40)
	capture(prefix + "signal-only")
	settings.set_value("crt_enabled", true)
	settings.set_value("vhs_enabled", false)
	await settle(40)
	capture(prefix + "crt-only")
	settings.set_value("crt_enabled", false)
	await settle(40)
	capture(prefix + "no-video")
	if OS.get_cmdline_user_args().has("--ntscrt-benchmark"):
		for extent in [Vector2i(1920, 1080), Vector2i(3840, 2160)]:
			view.size = extent
			game._apply_scaling()
			for round_index in 2:
				var modes := [0, 1, 2] if round_index == 0 else [2, 1, 0]
				for mode in modes:
					select_mode(0 if mode == 0 else 1, 0 if mode == 2 else 1)
					await benchmark(["classic", "ntscrt-full", "ntscrt-efficient"][mode], round_index)
			select_mode(1)
			await settle(30)
			capture(prefix + "%dp-full" % extent.y)
	if OS.get_cmdline_user_args().has("--ntscrt-motion"):
		view.size = Vector2i(1280, 720)
		game._apply_scaling()
		Engine.max_fps = 30
		var motion_dir := OUTPUT.path_join("motion")
		DirAccess.make_dir_recursive_absolute(motion_dir)
		var initial_rotation := camera.rotation
		for preset in [1, 2, 3]:
			select_mode(1)
			settings.apply_ntscrt_preset(preset)
			settings.set_value("ntsc_auto_faults", false)
			await settle(12)
			var pipeline = game._post_process._experimental
			pipeline.set_process(false)
			for frame in 90:
				camera.rotation.y = initial_rotation.y + sin(frame / 30.0 * 0.8) * 0.16
				pipeline._process(1.0 / 30.0)
				await settle(1)
				var image := view.get_texture().get_image()
				image.convert(Image.FORMAT_RGB8)
				image.linear_to_srgb()
				image.save_png(motion_dir.path_join("frame-%04d.png" % ((preset - 1) * 90 + frame)))
			pipeline.set_process(true)
			print("NTSCRT_MOTION ", GameSettings.NTSCRT_PRESET_NAMES[preset])
		camera.rotation = initial_rotation
	view.size = Vector2i(1920, 1080)
	select_mode(1)
	game._open_settings(true)
	game._pause_menu._select_tab("Visual Effects")
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	capture(prefix + "settings")
	game._close_settings()
	await teardown_game(game)
	view.free()
	finish("native game captures and requested comparative timings")
