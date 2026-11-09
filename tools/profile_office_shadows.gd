extends "res://tools/capture_level_overhaul.gd"
## Office furniture A/B with one rendered frame per engine tick. Native output,
## 1440p world rendering, Clean, no writes to the player's settings.
## godot --path . --script tools/profile_office_shadows.gd -- --nologo
## --level=1 --styles=12 --quality=3 --out=res://build/office-shadow-profile
var profile_modes := PackedStringArray(["office-unbatched", "baseline", "office-unbatched", "baseline"])

func _init() -> void:
	super()
	reflection_diagnostic = true
	measure = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-modes="):
			profile_modes = arg.trim_prefix("--profile-modes=").split(",")
	for mode in profile_modes: assert(mode in ["office-unbatched", "baseline"])

func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return (float(sorted[(sorted.size()-1)/2])+float(sorted[sorted.size()/2]))*0.5


func diagnose_reflections(chunk: Chunk, style: int) -> void:
	assert(theme == 1 and style == 12 and quality >= 0)
	var saved_mode := game.process_mode
	var saved_loop := RenderingServer.render_loop_enabled
	game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	RenderingServer.render_loop_enabled = false
	if is_instance_valid(game._fps_counter): game._fps_counter.set_enabled(false)
	view.size = DisplayServer.screen_get_size()
	GraphicsQuality.apply_resolution(view,game._settings,false,false)
	view.scaling_3d_scale = minf(1.0,1440.0/view.size.y)
	var originals: Array = []
	var proxies: Array = []
	for mesh in game.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("office_shadow_original"): originals.append(mesh)
		if mesh.has_meta("office_shadow_batch"): proxies.append(mesh)
	assert(not proxies.is_empty())
	var camera := view.get_camera_3d()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var origin := Vector3(chunk.cell.x*12.0,0,chunk.cell.y*12.0)
	var report := {"samples":[],"output_size":str(view.size),"world_scale":view.scaling_3d_scale,
		"device":RenderingServer.get_video_adapter_name(),"quality":quality,"shadow_batches":proxies.size(),"original_parts":originals.size(),
		"method":"One forced render per engine tick, automatic rendering disabled, moving camera. Per-frame CPU/GPU fence and full-resolution readback included; 24 warmup frames, then 90 measured. Frozen gameplay simulation, not gameplay FPS."}
	for sample_index in profile_modes.size():
		var mode := profile_modes[sample_index]
		var enabled := mode != "office-unbatched"
		for proxy in proxies: proxy.visible = enabled
		for part in originals:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else part.get_meta("office_shadow_original")
		var costs: Array = []
		var calls: Array = []
		var triangles: Array = []
		for frame in 114:
			await process_frame
			var phase := TAU*float(maxi(0,frame-24))/90.0
			camera.look_at_from_position(origin+Vector3(3+2*sin(phase),1.72,2),origin+Vector3(8,1.65,7.7))
			camera.force_update_transform()
			RenderingServer.camera_set_transform(camera.get_camera_rid(),camera.global_transform)
			var start := Time.get_ticks_usec()
			RenderingServer.force_draw(false,0.0)
			var capture := view.get_texture().get_image()
			var elapsed := (Time.get_ticks_usec()-start)/1000.0
			assert(not capture.is_empty())
			if frame >= 24:
				costs.append(elapsed)
				calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
				triangles.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			if frame in [24,46,68,90]: capture.save_png(output.path_join("%d-%s-%d.png"%[sample_index,mode,frame]))
		var record := {"mode":mode,"median_ms":median(costs),"draw_calls_median":median(calls),"primitives_median":median(triangles),"frames_ms":costs}
		report.samples.append(record)
		var file := FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
		print("STEPPED_PROFILE ",mode," median_ms=",median(costs)," draws=",median(calls))
	for proxy in proxies: proxy.visible = true
	for part in originals: part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	RenderingServer.render_loop_enabled = saved_loop
	game.process_mode = saved_mode
	paused = false
