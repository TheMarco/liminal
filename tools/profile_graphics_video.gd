extends "res://tools/benchmark_ntscrt_game.gd"
## Short real-host check of every graphics tier with Home video and Worn tape.
## Run natively with -- --nologo --level=1. Never writes player settings.
const REVIEW_OUT := "res://build/graphics-preset-review/video"

func run() -> void:
	assert(DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--nologo"))
	DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
	root.size = Vector2i(640,360)
	root.use_hdr_2d = true
	output = SubViewport.new()
	output.size = DisplayServer.screen_get_size()
	output.use_hdr_2d = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	host = HOST.new()
	output.add_child(host)
	source = host.source
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = SEED
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	host.attach(game)
	assert(not game._progress_enabled)
	_profile_path = "/tmp/liminal-graphics-video-%d.cfg"%OS.get_process_id()
	settings = GameSettings.new(_profile_path)
	settings.values.frame_limit = 0
	settings.values.vsync = false
	settings.values.hdr_enabled = false
	settings.values.handheld_camera = false
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	RenderingServer.render_loop_enabled = false
	for i in 45:
		await process_frame
		if is_instance_valid(game._pause_menu): game._close_settings()
		RenderingServer.force_draw(false,STEP)
	game.cm.set_process(false)
	game.cm._cancel_pending()
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.set_process(false)
	stop_audio(game)
	quality_ladder = true
	var report := {"device":RenderingServer.get_video_adapter_name(),"display":str(output.size),"samples":[],
		"method":"Real video host, one forced draw per engine tick, GPU fence/readback each frame, 24 warmup and 32 measured. Fixed camera/gameplay; not gameplay FPS."}
	for look in [1,3]:
		for tier in range(4):
			var label: String = ("home-" if look==1 else "worn-")+GameSettings.QUALITY_NAMES[tier].to_lower()
			var config := _case(label,2,true,look==1,false,GameSettings.CRT_AUTOMATIC if look==1 else 7)
			config["look"] = look
			config["graphics_quality"] = tier
			assert(apply_case(config))
			var costs: Array[float] = []
			var ready := _ready_frames()
			for frame in 56:
				await process_frame
				if is_instance_valid(game._pause_menu): game._close_settings()
				var start := Time.get_ticks_usec()
				RenderingServer.force_draw(false,STEP)
				var capture := output.get_texture().get_image()
				var elapsed := (Time.get_ticks_usec()-start)/1000.0
				assert(not capture.is_empty())
				if frame>=24: costs.append(elapsed)
				if frame==55: assert(capture.save_png(REVIEW_OUT.path_join(label+".png"))==OK)
			assert(host.presenter.last_error.is_empty(),host.presenter.last_error)
			assert(_ready_frames()-ready>=54,"video presenter missed rendered frames")
			var record := {"case":label,"frame_cost":_stats(costs),"world_height":source.size.y*source.scaling_3d_scale,
				"signal":str(host.presenter.signal_extent),"output_limit":host.presenter.output_height_limit,
				"crt_model":host.presenter.preset_name,"ready_frames":_ready_frames()-ready}
			report.samples.append(record)
			FileAccess.open(REVIEW_OUT.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("VIDEO_PRESET ",JSON.stringify(record))
	RenderingServer.render_loop_enabled = true
	await teardown_game(game)
	output.queue_free()
	DirAccess.remove_absolute(_profile_path)
	finish("all graphics tiers through real Home video and Worn tape presentation")
