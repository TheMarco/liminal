extends "res://tools/capture_level_overhaul.gd"
## Controlled preset review. One forced draw per engine tick; GPU fence and
## readback included. Game simulation frozen, camera moves, not gameplay FPS.
## godot --path . --script tools/profile_graphics_presets.gd -- --nologo
## --level=1 --styles=12 --quality=3 --out=res://build/graphics-preset-review/office
const OLD_PRESETS := [[0,1,0,0,0,0,0],[1,1,1,0,1,0,0],[2,2,2,1,2,1,1],[5,5,3,2,2,2,2]]
const CANDIDATES := [[1,1,0,0,0,0,0],[2,2,1,1,1,1,1],[3,2,2,1,2,1,1],[4,2,3,2,2,2,2]]
var review_modes := PackedStringArray(["old-0","candidate-0","old-1","candidate-1","old-2","candidate-2","old-3","candidate-3"])

func _init() -> void:
	super()
	reflection_diagnostic = true
	measure = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modes="): review_modes = arg.trim_prefix("--modes=").split(",")

func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return (float(sorted[(sorted.size()-1)/2])+float(sorted[sorted.size()/2]))*0.5

func diagnose_reflections(_chunk: Chunk, style: int) -> void:
	assert(quality >= 0)
	var saved_mode := game.process_mode
	var saved_loop := RenderingServer.render_loop_enabled
	game._settings.apply_video_look(0)
	game._settings.values.frame_limit = 0
	game._settings.values.vsync = false
	game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	RenderingServer.render_loop_enabled = false
	view.size = DisplayServer.screen_get_size()
	var camera := view.get_camera_3d()
	var original := camera.global_transform
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var lights := {}
	for light in game.find_children("*","Light3D",true,false):
		if light.has_meta("practical_shadow_tier"): lights[light] = light.visible
	var report := {"samples":[],"theme":theme,"style":style,"output_size":str(view.size),
		"device":RenderingServer.get_video_adapter_name(),"fixture_count":lights.size(),
		"method":"Per-engine-tick forced draw with frozen game simulation, moving camera, Clean. 30 warmup + 48 measured frames; per-frame GPU fence/readback included. Not gameplay FPS."}
	for mode in review_modes:
		var tier := int(mode.get_slice("-",1))
		var values: Array
		if mode.begins_with("old-"): values = OLD_PRESETS[tier]
		elif mode.begins_with("candidate-"): values = CANDIDATES[tier]
		elif mode == "ultra-msaa":
			tier = 3
			values = OLD_PRESETS[3].duplicate()
			values[0] = 4
		elif mode == "medium-no-gi":
			tier = 1
			values = CANDIDATES[1].duplicate()
			values[3] = 0
		elif mode.begins_with("current-"): values = GameSettings.QUALITY_PRESETS[tier]
		else: assert(false,"unknown review mode")
		for i in GameSettings.QUALITY_KEYS.size(): game._settings.values[GameSettings.QUALITY_KEYS[i]] = values[i]
		game._settings.values.quality_preset = tier
		game._apply_game_settings()
		GraphicsQuality.apply_viewport(view,game._settings)
		game._post_process.set_enabled(false)
		if is_instance_valid(game._fps_counter): game._fps_counter.set_enabled(false)
		for light in lights:
			assert(light.visible == lights[light] and light.shadow_enabled and light.shadow_opacity == 1.0,
				"preset lost a fixture or its occlusion")
		var costs: Array = []
		var calls: Array = []
		for frame in 78:
			await process_frame
			var phase := TAU*float(maxi(0,frame-30))/48.0
			camera.global_transform = original
			camera.global_position += original.basis.x*0.2*sin(phase)
			camera.force_update_transform()
			RenderingServer.camera_set_transform(camera.get_camera_rid(),camera.global_transform)
			var start := Time.get_ticks_usec()
			RenderingServer.force_draw(false,0.0)
			var capture := view.get_texture().get_image()
			var elapsed := (Time.get_ticks_usec()-start)/1000.0
			assert(not capture.is_empty())
			if frame >= 30:
				costs.append(elapsed)
				calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			if frame == 30: assert(capture.save_png(output.path_join("room-%d-%s.png"%[style,mode])) == OK)
		var record := {"mode":mode,"values":values,"world_height":view.scaling_3d_scale*view.size.y,
			"median_ms":median(costs),"draw_calls":median(calls),"frames_ms":costs,
			"msaa":view.msaa_3d,"taa":view.use_taa,"shadow_atlas":view.positional_shadow_atlas_size}
		report.samples.append(record)
		var file := FileAccess.open(output.path_join("room-%d-profile.json"%style),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
		print("PRESET_PROFILE ",style," ",mode," height=",record.world_height," ms=",record.median_ms)
	camera.global_transform = original
	RenderingServer.render_loop_enabled = saved_loop
	game.process_mode = saved_mode
	paused = false
