extends "res://tools/lib/audit_base.gd"
## Native final-presentation check. Uniform gray columns isolate raster contrast;
## averaging consecutive frames also catches scanlines erased by field alternation.
const PRESENTER = preload("res://scripts/ntscrt_gpu_presenter.gd")
const LIBRARY = preload("res://scripts/video_preset_library.gd")
var output: SubViewport
var source: SubViewport
var presenter: TextureRect
var report := {"samples":[]}
var out := "res://build/crt-scanline-review/baseline"
var selected := "royale"
var tiers := PackedStringArray(["2"])
var patch: Dictionary = {}
var verify := false
var display := Vector2i(3456,2234)

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Native GPU required")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--models="): selected = arg.trim_prefix("--models=")
		if arg.begins_with("--tiers="): tiers = arg.trim_prefix("--tiers=").split(",")
		if arg.begins_with("--patch="): patch = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--patch=")))
		if arg == "--verify": verify = true
		if arg == "--window": display = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(640,360)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	output = SubViewport.new()
	output.size = display
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	source = SubViewport.new()
	source.size = Vector2i(720,480)
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(source)
	for i in 4:
		var rect := ColorRect.new()
		rect.position = Vector2(180*i,0)
		rect.size = Vector2(180,480)
		var level: float = [0.08,0.25,0.5,0.75][i]
		rect.color = Color(level,level,level,1)
		source.add_child(rect)
	presenter = PRESENTER.new()
	presenter.source = source
	output.add_child(presenter)
	report["method"] = "Actual GPU presenter and final linear scaling; 24 warmup + 8 measured frames. Four gray columns (8/25/50/75%); row contrast after temporal averaging. Render/fence/readback timings are not gameplay FPS."
	report["display"] = str(display)
	report["device"] = RenderingServer.get_video_adapter_name()
	RenderingServer.render_loop_enabled = false
	for index in range(13,20):
		var profile := LIBRARY.make_profile(index)
		var model := profile.selected_crt_model()
		if selected != "all" and model not in selected.split(","): continue
		for tier_text in tiers:
			var tier := int(tier_text)
			presenter.preset_name = model
			presenter.parameters = profile.active_crt_parameters()
			presenter.parameters.merge(patch.get(model,{}),true)
			presenter.signal_extent = NtscrtProfile.SIGNAL_SIZES[tier]
			presenter.output_height_limit = NtscrtProfile.OUTPUT_HEIGHTS[tier]
			var rows: Array = []
			var raster: Array = []
			for i in 4:
				var column := PackedFloat64Array()
				column.resize(192)
				rows.append(column)
				var pixels := PackedFloat64Array()
				pixels.resize(192*32)
				raster.append(pixels)
			var costs: Array = []
			var first_contrast: Array = []
			for frame in 32:
				await process_frame
				var start := Time.get_ticks_usec()
				RenderingServer.force_draw(false,1.0/60.0)
				var capture := output.get_texture().get_image()
				if frame < 24: continue
				costs.append((Time.get_ticks_usec()-start)/1000.0)
				for i in 4:
					var current := PackedFloat64Array()
					for y in 192:
						var sum := 0.0
						for x in 32:
							var c := capture.get_pixel(display.x*(2*i+1)/8+x-16,display.y/2+y-96)
							var value := c.r*0.2126+c.g*0.7152+c.b*0.0722
							sum += value
							raster[i][y*32+x] += value/8.0
						current.append(sum/32.0)
						rows[i][y] += sum/(32.0*8.0)
					if frame == 24: first_contrast.append(stats(current))
				if frame == 24:
					capture.save_png(out.path_join("%s-%d.png"%[model,tier]))
					capture.get_region(Rect2i(display/2-Vector2i(256,160),Vector2i(512,320))).save_png(out.path_join("%s-%d-detail.png"%[model,tier]))
			expect(presenter.last_error.is_empty(),presenter.last_error)
			var patches: Array = []
			for column in rows: patches.append(stats(column))
			# Crtsim has a staggered slot mask: averaging across columns erases
			# its raster. Measure each column vertically, then average contrast.
			var slot_contrast: Array = []
			for pixels in raster:
				var contrast := 0.0
				for x in 32:
					var column := PackedFloat64Array()
					for y in 192: column.append(pixels[y*32+x])
					contrast += stats(column).contrast/32.0
				slot_contrast.append(contrast)
			costs.sort()
			var signal_size: Vector2i = presenter.effective_signal_size(display)
			var record := {"model":model,"tier":tier,"signal":str(signal_size),
				"output":str(presenter.render_target_size(display,signal_size)),"slot_contrast":slot_contrast,
				"parameters":presenter.parameters,"single_frame":first_contrast,"averaged_frames":patches,
				"median_ms":costs[costs.size()/2]}
			report.samples.append(record)
			FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("CRT_RASTER ",model," tier=",tier," avg=",patches," ms=",record.median_ms)
			if verify:
				var contrast: Array = slot_contrast if model == "sim" else [patches[0].contrast,patches[1].contrast,patches[2].contrast]
				# Royale's restored interlaced raster intentionally softens when
				# averaged over fields. Strong stationary bars are not its target.
				if model != "royale":
					expect(contrast[1]>0.035 and contrast[2]>0.035,"Raster disappeared: %s/%d"%[model,tier])
				expect(contrast[1]<0.55 and contrast[2]<0.55,"Black beam bands: %s/%d"%[model,tier])
				expect(patches[0].mean>0.015 and patches[2].mean>patches[1].mean+0.05,"Lost dark-room tonal detail: %s/%d"%[model,tier])
				expect(patches[3].mean<0.9,"CRT calibration washed out highlights: %s/%d"%[model,tier])
	RenderingServer.render_loop_enabled = true
	output.queue_free()
	source.queue_free()
	await process_frame
	finish("CRT raster contrast and shadow readability at final presentation size")

func stats(rows: PackedFloat64Array) -> Dictionary:
	var sorted := rows.duplicate()
	sorted.sort()
	var lo := sorted[sorted.size()/20]
	var hi := sorted[sorted.size()*19/20]
	var mean := 0.0
	for value in rows: mean += value/rows.size()
	return {"contrast":(hi-lo)/maxf(0.0001,hi+lo),"mean":mean}
