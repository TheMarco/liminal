extends "res://tools/capture_level_overhaul.gd"
## Isolated diagnostic changes only. Never writes player settings or production
## lighting. Reuses the capture harness's unique, room-complete neighbourhood.
## godot --path . --script tools/profile_fixture_lighting.gd -- --nologo
## --level=4 --styles=141 --quality=2 --out=res://build/fixture-profile/airport

var profile_modes := PackedStringArray(["baseline", "soft-low", "hard-shadows",
	"atlas-2048", "no-fixture-shadows", "no-gi", "no-volumetric-fog",
	"no-reflections", "baseline-repeat"])
var frame_events := 0
var profile_height := 0

func _init() -> void:
	super()
	reflection_diagnostic = true
	measure = false
	RenderingServer.frame_post_draw.connect(func(): frame_events += 1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-height="):
			profile_height = int(arg.trim_prefix("--profile-height="))
		if arg.begins_with("--profile-modes="):
			profile_modes = arg.trim_prefix("--profile-modes=").split(",")

func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return (float(sorted[(sorted.size()-1)/2])+float(sorted[sorted.size()/2]))*0.5

func diagnose_reflections(chunk: Chunk, style: int) -> void:
	assert(quality >= 0)
	var saved_mode := game.process_mode
	game.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	if is_instance_valid(game._fps_counter): game._fps_counter.set_enabled(false)
	if OS.get_cmdline_user_args().has("--profile-native-size"):
		view.size = DisplayServer.screen_get_size()
	GraphicsQuality.apply_resolution(view,game._settings,false,false)
	if profile_height > 0: view.scaling_3d_scale = minf(1.0,float(profile_height)/view.size.y)
	var env: Environment = game.we.environment
	var env_state := {"sdfgi_enabled":env.sdfgi_enabled,
		"volumetric_fog_enabled":env.volumetric_fog_enabled,"ssr_enabled":env.ssr_enabled}
	var atlas := view.positional_shadow_atlas_size
	var msaa := view.msaa_3d
	var atlas_quadrants: Array[int] = []
	for quadrant in 4: atlas_quadrants.append(view.get_positional_shadow_atlas_quadrant_subdiv(quadrant))
	var world_scale := view.scaling_3d_scale
	var lights := {}
	var counts := {}
	var probes := {}
	var meshes := {}
	var mesh_layers := {}
	var mesh_visibility := {}
	for light: Light3D in game.find_children("*","Light3D",true,false):
		if not light.has_meta("practical_shadow_tier"): continue
		lights[light] = {"shadow_enabled":light.shadow_enabled,"visible":light.visible,
			"light_specular":light.light_specular,"light_size":light.light_size,
			"light_energy":light.light_energy,"light_cull_mask":light.light_cull_mask}
		if light is AreaLight3D: lights[light]["area_range"] = light.area_range
		var source: String = light.get_meta("visible_source","unknown")
		counts[source] = int(counts.get(source,0))+1
	for probe in game.find_children("*","ReflectionProbe",true,false): probes[probe] = probe.visible
	for mesh: GeometryInstance3D in game.find_children("*","GeometryInstance3D",true,false):
		meshes[mesh] = mesh.cast_shadow
		mesh_layers[mesh] = mesh.layers
		mesh_visibility[mesh] = mesh.visible
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var report := {"device":RenderingServer.get_video_adapter_name(),"theme":theme,"style":style,
		"quality":quality,"world_scale":view.scaling_3d_scale,"unique_chunks":game.cm.chunks.size(),
		"output_size":str(view.size),"screen_size":str(DisplayServer.screen_get_size()),
		"fixture_sources":counts,"geometry_instances":meshes.size(),"samples":[],
		"method":"Frozen scene, Clean, selected quality/resolution. Six batches of 30 forced frames with GPU fence; then 60 ordinary frames for CPU/GPU timestamps. Diagnostic effects restored between modes. Not gameplay FPS."}
	for mode in profile_modes:
		GraphicsQuality.apply_global(game._settings)
		view.positional_shadow_atlas_size = atlas
		view.msaa_3d = msaa
		for quadrant in 4: view.set_positional_shadow_atlas_quadrant_subdiv(quadrant,atlas_quadrants[quadrant])
		view.scaling_3d_scale = world_scale
		for key in env_state: env.set(key,env_state[key])
		for light in lights:
			for key in lights[light]: light.set(key,lights[light][key])
		for probe in probes: probe.visible = probes[probe]
		for mesh in meshes: mesh.cast_shadow = meshes[mesh]
		for mesh in mesh_layers: mesh.layers = mesh_layers[mesh]
		for mesh in mesh_visibility: mesh.visible = mesh_visibility[mesh]
		match mode:
			"soft-low": RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			"hard-shadows": RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			"soft-medium": RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			"taa-only": view.msaa_3d = Viewport.MSAA_DISABLED
			"world-1440": view.scaling_3d_scale = minf(1.0,1440.0/view.size.y)
			"atlas-4096": view.positional_shadow_atlas_size = 4096
			"atlas-balanced":
				for quadrant in 4:
					view.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16)
			"pcf-shadows":
				for light in lights: light.light_size = 0.0
			"office-old-softness":
				for light in lights:
					if str(light.get_meta("visible_source","")).begins_with("office_"):
						light.light_size = 0.08
			"office-unbatched":
				for mesh in meshes:
					if mesh.has_meta("office_shadow_original"): mesh.cast_shadow = mesh.get_meta("office_shadow_original")
					if mesh.has_meta("office_shadow_batch"): mesh.visible = false
			"office-legacy-coverage":
				for light in lights:
					if light is AreaLight3D and str(light.get_meta("visible_source","")).begins_with("office_"):
						light.area_range = 8.5
						light.light_cull_mask |= OfficeCeilingGrid.CEILING_RENDER_LAYER
			"office-reach-6.5", "office-optimized":
				for light in lights:
					if light is AreaLight3D and str(light.get_meta("visible_source","")).begins_with("office_"):
						light.area_range = 6.5
			"office-ceiling-mask":
				for mesh in meshes:
					if mesh is MeshInstance3D and mesh.material_override == Mats.office_ceiling():
						mesh.layers = 2
				for light in lights:
					if str(light.get_meta("visible_source","")).begins_with("office_"):
						light.light_cull_mask &= ~2
			"atlas-2048": view.positional_shadow_atlas_size = 2048
			"no-fixture-shadows":
				for light in lights: light.shadow_enabled = false
			"no-fixture-lights":
				for light in lights: light.visible = false
			"no-gi": env.sdfgi_enabled = false
			"no-volumetric-fog": env.volumetric_fog_enabled = false
			"no-reflections":
				env.ssr_enabled = false
				for probe in probes: probe.visible = false
			"no-uplights":
				for light in lights:
					if light.get_meta("fixture_upward",false): light.visible = false
			"short-uplights":
				for light in lights:
					if light.get_meta("fixture_upward",false): light.area_range = minf(light.area_range,3.0)
			"uplights-5m":
				for light in lights:
					if light.get_meta("fixture_upward",false): light.area_range = minf(light.area_range,5.0)
			"uplights-9m":
				for light in lights:
					if light.get_meta("fixture_upward",false): light.area_range = 9.0
			"current-room-only":
				for light in lights:
					var owner: Node = light.get_parent()
					while owner != null and not owner is Chunk: owner = owner.get_parent()
					if owner is Chunk and owner.room_root != chunk.room_root: light.visible = false
			"short-ranges":
				for light in lights:
					if light is AreaLight3D:
						light.area_range = minf(light.area_range,3.0) if light.get_meta("fixture_upward",false) else light.area_range*0.7
			"no-fixture-specular":
				for light in lights: light.light_specular = 0.0
			"no-small-caster-shadows":
				for mesh in meshes:
					var size: Vector3 = mesh.get_aabb().size*mesh.global_basis.get_scale().abs()
					if maxf(size.x,maxf(size.y,size.z)) < 2.0:
						mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"baseline", "baseline-repeat": pass
			_: assert(false,"Unknown mode: "+mode)
		if mode == "office-optimized":
			for mesh in meshes:
				if mesh is MeshInstance3D and mesh.material_override == Mats.office_ceiling():
					mesh.layers = 2
			for light in lights:
				if str(light.get_meta("visible_source","")).begins_with("office_"):
					light.light_cull_mask &= ~2
		await draw(30)
		var batches: Array[float] = []
		var forced_start := frame_events
		for batch in 6:
			var start := Time.get_ticks_usec()
			for frame in 30:
				RenderingServer.force_draw(false,0.0)
			assert(not view.get_texture().get_image().is_empty())
			batches.append((Time.get_ticks_usec()-start)/30000.0)
		assert(frame_events-forced_start >= 180, "Forced benchmark skipped rendering")
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		var intervals: Array[float] = []
		var draw_counts: Array[int] = []
		var primitive_counts: Array[int] = []
		var previous_tick := Time.get_ticks_usec()
		var ordinary_start := frame_events
		for frame in 60:
			await process_frame
			var tick := Time.get_ticks_usec()
			if frame > 0: intervals.append((tick-previous_tick)/1000.0)
			previous_tick = tick
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid()))
			draw_counts.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			primitive_counts.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var record := {"mode":mode,"wall_median_ms":median(batches),"batches_ms":batches,
			"world_scale":view.scaling_3d_scale,"msaa":view.msaa_3d,"atlas_size":view.positional_shadow_atlas_size,
			"render_cpu_median_ms":median(cpu),"render_gpu_median_ms":median(gpu),
			"frame_interval_median_ms":median(intervals),"draw_calls":median(draw_counts),
			"draw_calls_max":draw_counts.max(),"primitives":median(primitive_counts),
			"ordinary_rendered_frames":frame_events-ordinary_start,
			"ordinary_timing_valid":frame_events-ordinary_start >= 59}
		report.samples.append(record)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-%s.png"%[style,mode]))==OK)
		var file := FileAccess.open(output.path_join("room-%d-profile.json"%style),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
		print("FIXTURE_PROFILE ",style," ",JSON.stringify(record))
	for light in lights:
		for key in lights[light]: light.set(key,lights[light][key])
	for probe in probes: probe.visible = probes[probe]
	for mesh in meshes: mesh.cast_shadow = meshes[mesh]
	for mesh in mesh_layers: mesh.layers = mesh_layers[mesh]
	for mesh in mesh_visibility: mesh.visible = mesh_visibility[mesh]
	for key in env_state: env.set(key,env_state[key])
	view.positional_shadow_atlas_size = atlas
	view.msaa_3d = msaa
	for quadrant in 4: view.set_positional_shadow_atlas_quadrant_subdiv(quadrant,atlas_quadrants[quadrant])
	view.scaling_3d_scale = world_scale
	GraphicsQuality.apply_global(game._settings)
	paused = false
	game.process_mode = saved_mode
