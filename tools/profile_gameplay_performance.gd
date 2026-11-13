extends "res://tools/lib/audit_base.gd"
## Native, normally scheduled frames through the production video host.
## No forced draws or image readbacks inside measured intervals.
## -- --nologo --level=1 --tiers=0,1,2,3 --looks=clean,home,tape
## --frames=240 --warmup=120 --out=res://build/performance-review/baseline-office.json
const HOST = preload("res://scripts/ntscrt_video_host.gd")
var game: Node
var host: Control
var settings: GameSettings
var out := "res://build/performance-review/gameplay.json"
var tiers := PackedStringArray(["0","1","2","3"])
var looks := PackedStringArray(["clean","home","tape"])
var sample_count := 240
var warmup_count := 120
var capture := false
var walk := false
var events := false
var occlusion := false
var hdr := false
var with_tape := false
var frame_events := 0

func run() -> void:
	assert(DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--nologo"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--tiers="): tiers = arg.trim_prefix("--tiers=").split(",")
		if arg.begins_with("--looks="): looks = arg.trim_prefix("--looks=").split(",")
		if arg.begins_with("--frames="): sample_count = maxi(30,int(arg.trim_prefix("--frames=")))
		if arg.begins_with("--warmup="): warmup_count = maxi(30,int(arg.trim_prefix("--warmup=")))
		if arg == "--capture": capture = true
		if arg == "--walk": walk = true
		if arg == "--events": events = true
		if arg == "--occlusion": occlusion = true
		if arg == "--hdr": hdr = true
		if arg == "--with-tape": with_tape = true
	if occlusion: Chunk.occlusion_themes.assign([0,1,2,4,5,6,7,8,9,10,11])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	root.use_hdr_2d = true
	host = HOST.new()
	root.add_child(host)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	assert(not game._progress_enabled)
	if not events:
		# Architecture can add a second world/aftershock mid-case. Isolate the
		# ordinary render cost; --events separately measures live horror events.
		game._director.scripted_hold = true
		for key in ["_events","_architectural_events","_breathing","_native_doorways","_self_return_door"]:
			var controller: Node = game.get(key)
			if is_instance_valid(controller): controller.process_mode = Node.PROCESS_MODE_DISABLED
	var profile_path := "/tmp/liminal-gameplay-profile-%d.cfg"%OS.get_process_id()
	settings = GameSettings.new(profile_path)
	settings.values.fullscreen = true
	settings.values.frame_limit = 0
	settings.values.vsync = false
	settings.values.hdr_enabled = hdr
	settings.values.handheld_camera = false
	settings.values.head_bob = 0.0
	settings.values.film_grain = 0.0
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.frame_post_draw.connect(func(): frame_events += 1)
	# Let initial streaming, GI and window sizing settle before any case.
	await settle(180)
	var origin: Vector3 = game.player.position
	var rotation: Vector3 = game.player.rotation
	var report := {"device":RenderingServer.get_video_adapter_name(),"theme":game.active_level,
		"seed":game.world_seed,"display":str(root.size),"walk":walk,"events":events,"occlusion":occlusion,"samples":[],
		"hdr_requested":hdr,"hdr_active":HdrOutput.is_active(root),"with_tape":with_tape,
		"monitor_note":"Godot Performance TIME_PROCESS/TIME_PHYSICS_PROCESS are periodically updated samples and can contain preceding-case stalls; use wall-clock frame_ms for comparisons, not those monitor averages.",
		"method":"Native fullscreen production host; live simulation and streaming, uncapped/VSync off. HDR state recorded separately. Wall-clock intervals between normally scheduled frame_post_draw events; no forced draws/readbacks in measurement. Camera sweeps one turn per case. Image capture after measurement only.",
		"warmup_frames":warmup_count,"measured_frames":sample_count}
	for look in looks:
		for tier_text in tiers:
			var tier := int(tier_text.get_slice(":",0))
			var variant := tier_text.get_slice(":",1) if ":" in tier_text else "base"
			settings.apply_quality_preset(tier)
			settings.apply_video_look(1 if look == "home" or with_tape else (2 if look == "tape" else 0))
			if look in GameSettings.CRT_SHADER_IDS:
				settings.values.crt_enabled = true
				settings.values.crt_shader = GameSettings.CRT_SHADER_IDS.find(look)
			match variant:
				"shadow2": settings.values.shadow_quality = 2
				"shadow1": settings.values.shadow_quality = 1
				"gi1": settings.values.global_illumination = 1
				"ao1": settings.values.ambient_occlusion = 1
				"fog1": settings.values.volumetric_fog = 1
				"ssr1": settings.values.reflections = 1
				"balanced":
					settings.values.shadow_quality = 2
					settings.values.global_illumination = 1
					settings.values.ambient_occlusion = 1
					settings.values.volumetric_fog = 1
					settings.values.reflections = 1
			game._apply_game_settings()
			GraphicsQuality.apply_global(settings)
			GraphicsQuality.apply_viewport_features(host.source,settings)
			host.source.use_occlusion_culling = game.active_level in Chunk.occlusion_themes and variant != "nocull"
			if variant == "efficient":
				var shadows := int(settings.values.shadow_quality)
				host.source.positional_shadow_atlas_size = [1024,2048,4096,4096][shadows]
				RenderingServer.positional_soft_shadow_filter_set_quality([
					RenderingServer.SHADOW_QUALITY_HARD,RenderingServer.SHADOW_QUALITY_SOFT_LOW,
					RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadows])
				var ao := int(settings.values.ambient_occlusion)
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if ao<2 else RenderingServer.ENV_SSAO_QUALITY_HIGH,true,0.5,2,50.0,100.0)
				RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8 if int(settings.values.global_illumination)<2 else RenderingServer.ENV_SDFGI_RAY_COUNT_16)
				var fog_size := 64 if int(settings.values.volumetric_fog)<2 else 96
				RenderingServer.environment_set_volumetric_fog_volume_size(fog_size,fog_size)
			elif variant == "previous":
				# Pre-review implementation, for paired comparisons after integration.
				var shadows := int(settings.values.shadow_quality)
				host.source.positional_shadow_atlas_size = [1024,2048,4096,8192][shadows]
				var filter: RenderingServer.ShadowQuality = [RenderingServer.SHADOW_QUALITY_HARD,RenderingServer.SHADOW_QUALITY_SOFT_LOW,
					RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,RenderingServer.SHADOW_QUALITY_SOFT_HIGH][shadows]
				RenderingServer.positional_soft_shadow_filter_set_quality(filter)
				RenderingServer.directional_soft_shadow_filter_set_quality(filter)
				var ao := int(settings.values.ambient_occlusion)
				RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW if ao<2 else RenderingServer.ENV_SSAO_QUALITY_HIGH,ao<2,0.5,2,50.0,100.0)
				RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8 if int(settings.values.global_illumination)<2 else RenderingServer.ENV_SDFGI_RAY_COUNT_32)
				var fog_size := 64 if int(settings.values.volumetric_fog)<2 else 128
				RenderingServer.environment_set_volumetric_fog_volume_size(fog_size,fog_size)
			game.player.position = origin
			game.player.rotation = rotation
			game.player.velocity = Vector3.ZERO
			game.player.dev_walk = false
			game.player.set_physics_process(walk)
			await settle(warmup_count)
			var frames: Array[float] = []
			var cpu: Array[float] = []
			var physics: Array[float] = []
			var draws: Array[float] = []
			var shadow_draws: Array[float] = []
			var visible_draws: Array[float] = []
			var primitives: Array[float] = []
			var previous := Time.get_ticks_usec()
			var start_frames := frame_events
			var start_ready: int = host.presenter.ready_frames if is_instance_valid(host.presenter) else 0
			var cells := {}
			var travel := 0.0
			var previous_position: Vector3 = game.player.position
			game.player.dev_walk = walk
			for index in sample_count:
				game.player.rotation.y = rotation.y+TAU*float(index)/sample_count
				await next_frame()
				var now := Time.get_ticks_usec()
				frames.append(float(now-previous)/1000.0)
				previous = now
				var position: Vector3 = game.player.position
				cells[Vector2i(floori(position.x/WorldGen.CELL_SIZE),floori(position.z/WorldGen.CELL_SIZE))] = true
				travel += position.distance_to(previous_position)
				previous_position = position
				cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var viewport_rid: RID = host.source.get_viewport_rid()
				shadow_draws.append(RenderingServer.viewport_get_render_info(viewport_rid,
					RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
				visible_draws.append(RenderingServer.viewport_get_render_info(viewport_rid,
					RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
				primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			game.player.dev_walk = false
			var record := {"look":look,"tier":tier,"variant":variant,"frame_ms":stats(frames),"cpu_process_ms":stats(cpu),
				"physics_ms":stats(physics),"draw_calls":stats(draws),"primitives":stats(primitives),
				"shadow_draw_calls":stats(shadow_draws),"visible_draw_calls":stats(visible_draws),
				"zero_shadow_frames":shadow_draws.count(0.0),
				"world_height":host.source.size.y*host.source.scaling_3d_scale,"source_size":str(host.source.size),
				"rendered_frames":frame_events-start_frames,"resident_chunks":game.cm.chunks.size(),
				"visited_cells":cells.size(),"travel_meters":travel,"end_level":game.active_level,
				"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
				"settings":settings.values.duplicate(true),"frames_ms":frames}
			record["average_fps"] = 1000.0/record.frame_ms.mean
			if is_instance_valid(host.presenter) and host.presenter.visible:
				record["video"] = {"model":host.presenter.preset_name,"signal_size":str(host.presenter.effective_signal_size(root.size)),
					"output_height_limit":host.presenter.output_height_limit,"ready_frames":host.presenter.ready_frames-start_ready,
					"last_cpu_submit_usec":host.presenter.cpu_usec,"last_error":host.presenter.last_error}
				expect(host.presenter.last_error.is_empty(),host.presenter.last_error)
			expect(record.rendered_frames==sample_count,"rendered frame count differs from sampled intervals")
			report.samples.append(record)
			FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("GAMEPLAY_PROFILE theme=",game.active_level," ",look," tier=",tier_text," fps=",record.average_fps,
				" ms=",record.frame_ms," cpu=",record.cpu_process_ms.mean," draws=",record.draw_calls.mean)
			if capture:
				game.player.rotation = rotation
				await settle(30)
				var screenshot := root.get_texture().get_image()
				expect(screenshot.save_png(out.get_basename()+"-"+look+"-"+tier_text+".png")==OK,"capture failed")
	await teardown_game(game)
	if is_instance_valid(host): host.queue_free()
	DirAccess.remove_absolute(profile_path)
	finish("native gameplay performance sample")

func next_frame() -> void:
	if is_instance_valid(game._pause_menu): game._close_settings()
	await process_frame
	await RenderingServer.frame_post_draw

func settle(count: int) -> void:
	for index in count: await next_frame()

func stats(values: Array[float]) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var sum := 0.0
	for value in values: sum += value
	return {"mean":sum/values.size(),"median":ordered[ordered.size()/2],
		"p95":ordered[ceili(ordered.size()*0.95)-1],"p99":ordered[ceili(ordered.size()*0.99)-1],"max":ordered[-1]}
