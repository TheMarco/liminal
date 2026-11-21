extends "res://tools/lib/audit_base.gd"
## Live scene + HUD -> completed GPU texture -> original CRT chain.
const PRESENTER = preload("res://scripts/ntscrt_gpu_presenter.gd")
const HOST = preload("res://scripts/ntscrt_video_host.gd")
var game: Node
var view: SubViewport
var presenter: TextureRect
var host: Control

func settle(frames: int) -> void:
	for frame in frames:
		if is_instance_valid(game) and is_instance_valid(game._pause_menu): game._close_settings()
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Original CRT game review requires a native GPU renderer")
		finish()
		return
	expect(OS.get_cmdline_user_args().has("--nologo"),"Use --nologo to avoid changing campaign progress")
	root.size = Vector2i(1280,720)
	root.title = "Liminal — original CRT shader review"
	host = HOST.new()
	root.add_child(host)
	view = host.source
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	expect(not game._progress_enabled,"Review must not save campaign progress")
	var settings := GameSettings.new("/tmp/liminal-slang-review-%d.cfg" % OS.get_process_id())
	settings.set_value("hdr_enabled",false)
	settings.set_value("vsync",false)
	settings.set_value("frame_limit",0)
	settings.set_value("handheld_camera",false)
	settings.set_value("crt_enabled",true)
	settings.set_value("crt_shader",1)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	await settle(30)
	Engine.max_fps = 60
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
	presenter = host.presenter
	presenter.profile_gpu_passes = true
	await settle(40)
	DirAccess.make_dir_recursive_absolute("res://build/ntscrt-review/slang-game")
	var modes := [1] if OS.get_cmdline_user_args().has("--quick") else [0,1]
	if OS.get_cmdline_user_args().has("--full"): modes = [2]
	var models := ["sim"] if OS.get_cmdline_user_args().has("--quick") else ["aperture","easymode","glow_gauss","glow_lanczos","hyllian","royale","sim"]
	for signal_mode in modes:
		settings.set_value("video_pipeline",signal_mode)
		settings.set_value("receiver_enabled",signal_mode == 2)
		settings.set_value("ntsc_auto_faults",false)
		for name in models:
			settings.set_value("crt_shader",GameSettings.CRT_SHADER_IDS.find(name))
			await settle(45)
			expect(presenter.last_error.is_empty(),presenter.last_error)
			expect(game._post_process._using_slang(),"Original CRT must own the tube stage")
			expect(not game._post_process._tube_display.visible,"Classic CRT must not stack with original CRT")
			var image := root.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			if root.use_hdr_2d: image.linear_to_srgb()
			image.save_png("res://build/ntscrt-review/slang-game/%s-%s.png" % [["classic","experimental","full"][signal_mode],name])
			print("SLANG_GAME ",signal_mode,"/",name," frames=",presenter.ready_frames," cpu_submit_us=",presenter.cpu_usec)
	print("SLANG_GPU_TIMESTAMP_SAMPLE ",JSON.stringify(presenter.timestamp_samples.back() if not presenter.timestamp_samples.is_empty() else {}))
	print("SLANG_MENU opening")
	var capture_looks := OS.get_cmdline_user_args().has("--looks")
	game.opts.video_lab = not capture_looks
	game._open_settings(true)
	print("SLANG_MENU opened")
	game._pause_menu._select_tab("Visual Effects")
	expect(game._pause_menu.custom_viewport == root,"Settings should render above the processed source")
	if not capture_looks:
		expect(game._pause_menu._crt_parameter_controls.size() == 20,"Crtsim original parameters should be available in the developer lab")
	settings.set_crt_parameter("sim","Tuning_Persistence_R",0.73)
	print("SLANG_MENU parameter set")
	expect(is_equal_approx(float(settings.get_value("crt_shader_parameters")["sim"]["Tuning_Persistence_R"]),0.73),"Original parameter setting must persist")
	if OS.get_cmdline_user_args().has("--looks"):
		var panel: PauseMenu = game._pause_menu
		expect(not is_instance_valid(panel._video_advanced), "player menu must omit the video lab")
		for index in [0,8,9,14]:
			panel._look_select.item_selected.emit(index+1)
			panel.visible = false
			for frame in 12: await process_frame
			await RenderingServer.frame_post_draw
			expect(presenter.last_error.is_empty(), presenter.last_error)
			expect(panel._look_select.selected == index+1, "look selection did not reach the live game")
			_save_review_image("look-%d" % index)
		panel.visible = true
		panel._look_select.item_selected.emit(9)
	for frame in 4: await process_frame
	print("SLANG_MENU frames drawn")
	await RenderingServer.frame_post_draw
	var menu := root.get_texture().get_image()
	menu.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: menu.linear_to_srgb()
	menu.save_png("res://build/ntscrt-review/slang-game/settings.png")
	if OS.get_cmdline_user_args().has("--looks"):
		var panel: PauseMenu = game._pause_menu
		var page := panel._pages["Visual Effects"] as ScrollContainer
		expect(not page.get_v_scroll_bar().visible, "simple effects should fit at 1280x720 without scrolling")
		expect(not panel._controls.has("crt_enabled"), "player presets must own the TV treatment")
		root.size = Vector2i(640, 600)
		for frame in 6: await process_frame
		await RenderingServer.frame_post_draw
		expect(panel._look_select.get_global_rect().end.x <= root.size.x, "complete-look selector clips in narrow layout")
		_save_review_image("settings-narrow")
	game._close_settings()
	print("SLANG_MENU closed")
	settings.set_value("crt_shader",0)
	settings.set_value("vhs_enabled",false)
	settings.set_value("receiver_enabled",false)
	await settle(4)
	expect(not presenter.visible,"Default tube must bypass original CRT rendering")
	expect(game._post_process._tube_display.visible == (settings.get_value("video_pipeline") != 1),"Default Classic tube must work with full signal disabled")
	settings.set_value("video_pipeline",0)
	expect(game._post_process._tube_display.visible,"Default Classic CRT must return")
	await teardown_game(game)
	print("SLANG_TEARDOWN complete")
	finish("original CRT chains with Classic and experimental video signals")

func _save_review_image(name: String) -> void:
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: image.linear_to_srgb()
	image.save_png("res://build/ntscrt-review/slang-game/%s.png" % name)
