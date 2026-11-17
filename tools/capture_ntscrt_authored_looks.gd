extends "res://tools/lib/audit_base.gd"
## Dark-scene review of the integrated CRT and original ambient animation.
## godot --path . --script tools/capture_ntscrt_authored_looks.gd -- --nologo --level=0
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const OUT := "res://build/ntscrt-review/authored-looks/"
var game: Node
var output_path := OUT

func settle(count: int) -> void:
	for frame in count:
		if is_instance_valid(game._pause_menu): game._close_settings()
		await process_frame
	await RenderingServer.frame_post_draw

func shot(label: String) -> void:
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: image.linear_to_srgb()
	image.save_png(output_path+label+".png")

func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU and --nologo")
		finish()
		return
	root.size = Vector2i(1280,720)
	var quality := -1
	var crt_comparison := OS.get_cmdline_user_args().has("--crt-comparison")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = clampi(int(argument.get_slice("=",1)),0,3)
		if argument.begins_with("--output-height="):
			var height := int(argument.get_slice("=",1))
			root.size = Vector2i(roundi(height*16.0/9.0),height)
	if quality>=0: output_path += "quality-%d/" % quality
	if crt_comparison:
		output_path = OUT+"crt-comparison/quality-%d/" % quality
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--level="): output_path += "level-%s/" % argument.get_slice("=",1)
	var host := HOST.new()
	root.add_child(host)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	var settings := GameSettings.new("/tmp/liminal-authored-review-%d.cfg" % OS.get_process_id())
	if quality>=0: settings.apply_quality_preset(quality)
	settings.set_value("handheld_camera",false)
	settings.set_value("ntsc_auto_faults",false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	expect(not game._progress_enabled,"Review must not save campaign progress")
	Engine.max_fps = 60
	await settle(60)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.cm.set_process(false)
	game._figures.set_physics_process(false)
	stop_audio(game)
	var camera := Camera3D.new()
	camera.fov = 77
	host.source.add_child(camera)
	camera.global_transform = game.player.cam.global_transform
	camera.current = true
	DirAccess.make_dir_recursive_absolute(output_path)
	if crt_comparison:
		settings.apply_video_look(1)
		settings.set_value("ntsc_auto_faults",false)
		host.presenter.set_process(false)
		host.presenter._clock = 10.0
		for model in [1,6]:
			settings.set_value("crt_shader",model)
			# Stock Royale stays a reference even after the preset is calibrated.
			if model==6: settings.set_value("crt_shader_parameters",{"aperture":GameSettings.HOME_CRT_PARAMETERS.aperture})
			await settle(30)
			expect(host.presenter.last_error.is_empty(),host.presenter.last_error)
			shot("home-"+GameSettings.CRT_SHADER_IDS[model])
			print("CRT_COMPARISON model=",host.presenter.preset_name," params=",host.presenter.parameters,
				" signal=",host.presenter.signal_extent," output_limit=",host.presenter.output_height_limit)
		settings.set_value("crt_shader_parameters",GameSettings.HOME_CRT_PARAMETERS)
		await settle(30)
		shot("home-royale-calibrated")
		settings.set_value("crt_enabled",false)
		# Keep the same 480-line world for the tape-only brightness reference.
		host.source.scaling_3d_scale = minf(1.0,480.0/host.source.size.y)
		await settle(30)
		shot("tape-reference")
		await teardown_game(game)
		finish("Home video Aperture/Royale visual comparison")
		return
	for index in [0,1,3]:
		settings.apply_video_look(index)
		settings.set_value("ntsc_auto_faults",false)
		await settle(30)
		expect(host.presenter.last_error.is_empty(),host.presenter.last_error)
		if quality>=0 and index!=0:
			expect(host.presenter.signal_extent==GraphicsQuality.VIDEO_SIGNAL_SIZES[quality],"look did not use the selected quality's signal size")
			print("VIDEO_QUALITY_CAPTURE ",quality," look=",index," signal=",host.presenter.signal_extent,
				" output_limit=",host.presenter.output_height_limit," world_height=",host.source.size.y*host.source.scaling_3d_scale)
		shot("home-"+host.presenter.preset_name if index==1 else ["clean","unused","unused","worn"][index])
		if index==1:
			var legacy := GameSettings.legacy_home_video_values()
			for key in legacy: settings.set_value(key,legacy[key])
			await settle(30)
			shot("home-before")
	host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,{"sequence":"two_blips","sequence_strength":1.0,"phase":0.752,"amount":0.7,"kind":0})
	await settle(3)
	shot("two-blips")
	expect(not host.presenter.receiver_enabled,"Authored look enabled the expensive receiver")
	await teardown_game(game)
	finish("dark-scene Home video and ambient animation review")
