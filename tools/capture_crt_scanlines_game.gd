extends "res://tools/benchmark_ntscrt_game.gd"
## Actual game scenes through each calibrated CRT, with optional former parameters.
## Run natively with -- --nologo --level=1. Never writes player settings.
const LIBRARY = preload("res://scripts/video_preset_library.gd")
const BRIDGE = preload("res://scripts/video_preset_bridge.gd")
var review_out := "res://build/crt-scanline-review/game"

func run() -> void:
	assert(DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--nologo"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): review_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(review_out)
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
	game.process_mode = Node.PROCESS_MODE_DISABLED
	prepare_school_view()
	settings.apply_quality_preset(2)
	var former := {}
	var selected := "all"
	var paired := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--models="): selected = arg.trim_prefix("--models=")
		if arg == "--paired": paired = true
		if arg.begins_with("--before="):
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--before=")))
			for row in data.samples: former[row.model] = row.parameters
	var report := {"device":RenderingServer.get_video_adapter_name(),"display":str(output.size),"samples":[],
		"method":"Same frozen game/camera, High world settings, real tape/CRT host. 24 warmup (96 with --paired) + 32 measured frames per case. GPU fence/readback included; not gameplay FPS."}
	for index in range(13,20):
		var profile := LIBRARY.make_profile(index)
		profile.quality = 2
		profile.ambient_fault_rate = 0.0
		var model := profile.selected_crt_model()
		if selected != "all" and model not in selected.split(","): continue
		var variants := (["before","after","after","before"] if paired else ["before","after"]) if former.has(model) else ["after"]
		for variant in variants:
			BRIDGE.apply(profile,settings)
			if variant == "before":
				settings.values.crt_shader_parameters[model] = former[model].duplicate(true)
				game._apply_game_settings()
			host.presenter.set_process(false)
			host.presenter._clock = 5.0
			var label: String = model+"-"+variant
			var costs: Array[float] = []
			var calls: Array[float] = []
			var warmup := 96 if paired else 24
			for frame in warmup+32:
				await process_frame
				if is_instance_valid(game._pause_menu): game._close_settings()
				var start := Time.get_ticks_usec()
				RenderingServer.force_draw(false,STEP)
				var capture := output.get_texture().get_image()
				if frame>=warmup:
					costs.append((Time.get_ticks_usec()-start)/1000.0)
					calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
				if frame==warmup+31:
					capture.convert(Image.FORMAT_RGB8)
					if output.use_hdr_2d: capture.linear_to_srgb()
					assert(capture.save_png(review_out.path_join(label+".png"))==OK)
					capture.get_region(Rect2i(output.size/2-Vector2i(256,160),Vector2i(512,320))).save_png(review_out.path_join(label+"-detail.png"))
			assert(host.presenter.last_error.is_empty(),host.presenter.last_error)
			var record := {"case":label,"frame_cost":_stats(costs),"draw_calls":_stats(calls),"warmup":warmup,"world_height":source.size.y*source.scaling_3d_scale,
				"signal":str(host.presenter.effective_signal_size(output.size)),"output_limit":host.presenter.output_height_limit}
			report.samples.append(record)
			FileAccess.open(review_out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("CRT_GAME ",JSON.stringify(record))
	RenderingServer.render_loop_enabled = true
	await teardown_game(game)
	output.queue_free()
	DirAccess.remove_absolute(_profile_path)
	finish("all seven CRTs in an actual game scene")

func prepare_school_view() -> void:
	assert(game.active_level == 6,"Use --level=6 for the School visual reference")
	game.cm.queued.clear()
	var ws := WorldGen.level_seed(game.world_seed,6)
	var cell := Vector2i.ZERO
	var found := false
	for radius in 45:
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var at := Vector2i(x,z)
				if WorldGen.cell_style(ws,at,6)==61 and WorldGen.room_id(ws,at)==at:
					cell = at
					found = true
					break
			if found: break
		if found: break
	assert(found)
	for child in game.cm.get_children():
		if child is Chunk: child.free()
	game.cm.chunks.clear()
	var cells := {}
	for dx in range(-1,3):
		for dz in range(-1,3):
			var at := cell+Vector2i(dx,dz)
			for member in WorldGen.owning_room_members(ws,WorldGen.room_id(ws,at),6): cells[member] = true
	for at in cells: game.cm._build(at)
	var origin := Vector3(cell.x*12.0,0,cell.y*12.0)
	var camera := Camera3D.new()
	camera.fov = 78
	source.add_child(camera)
	camera.look_at_from_position(origin+Vector3(1.35,1.72,2.0),origin+Vector3(8.0,2.25,7.7))
	camera.current = true
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	if is_instance_valid(game._descent_hud): game._descent_hud.visible = false
