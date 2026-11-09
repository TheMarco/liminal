extends SceneTree
## Compare scanline workgroup sizes without modifying production code.
## Each invocation still owns one serial IIR-filtered row. Stage barriers stay.
const OUT := "res://build/performance-review/ntsc-row-groups"
var variants := {}
var done := false
var failures: Array[String] = []

func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var script := FileAccess.get_file_as_string("res://scripts/ntscrs_gpu.gd")
	var shader := FileAccess.get_file_as_string("res://shaders/ntscrs_gpu/pipeline.glsl")
	assert("local_size_x=1," in shader and "dispatch(list, _extent.y, 1, 1)" in script)
	for width in [1,8,16,32,64]:
		var shader_path := OUT.path_join("group-%d.glsl"%width)
		FileAccess.open(shader_path,FileAccess.WRITE).store_string(shader.replace("local_size_x=1,","local_size_x=%d,"%width))
		var source := script.replace("class_name NtscrsGpu\n","").replace("res://shaders/ntscrs_gpu/pipeline.glsl",shader_path)
		source = source.replace("dispatch(list, _extent.y, 1, 1)","dispatch(list, ceili(float(_extent.y)/%d.0), 1, 1)"%width)
		var candidate := GDScript.new()
		candidate.source_code = source
		assert(candidate.reload()==OK)
		variants[width] = candidate
	RenderingServer.call_on_render_thread(_render)
	while not done: await process_frame
	for message in failures: printerr(message)
	print("NTSC_ROW_GROUPS ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _render() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		failures.append("Native RenderingDevice required")
		done = true
		return
	var report := {"device":RenderingServer.get_video_adapter_name(),"fidelity":[],"performance":[],
		"method":"Same serial-per-row math; workgroup size only. Compare exact RGBA bytes for 8 consecutive frames including field history. Timed batches include 30 submissions and a single GPU readback fence; not whole-game FPS."}
	for extent in [Vector2i(7,3),Vector2i(127,65),Vector2i(720,480)]:
		var pixels := PackedByteArray()
		pixels.resize(extent.x*extent.y*4)
		for index in extent.x*extent.y:
			pixels[index*4] = (index*17)%256
			pixels[index*4+1] = (index*37)%256
			pixels[index*4+2] = (index*67)%256
			pixels[index*4+3] = 255
		var format := RDTextureFormat.new()
		format.width = extent.x
		format.height = extent.y
		format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		var input := rd.texture_create(format,RDTextureView.new(),[pixels])
		var processors := {}
		for width in variants:
			var gpu: RefCounted = variants[width].new()
			if not gpu.setup(rd,extent):
				failures.append(gpu.error)
				gpu.dispose()
				continue
			processors[width] = gpu
		for field in [0,1,2,3,4,5]:
			var settings := {"use_field":field,"field_history":true,"random_seed":123,"tracking_noise":true,
				"tracking_noise_height":8.0,"vhs_edge_wave":1.1,"vhs_chroma_loss":0.001,"chroma_delay_vertical":2.0}
			for frame in 8:
				var reference := PackedByteArray()
				for width in processors:
					var gpu: RefCounted = processors[width]
					var output: RID = gpu.render(input,frame,settings)
					var actual := rd.texture_get_data(output,0)
					if width==1:
						reference = actual
					elif actual != reference:
						failures.append("Pixel mismatch: %s group=%d field=%d frame=%d"%[extent,width,field,frame])
			report.fidelity.append({"extent":str(extent),"field":field,"frames":8,"groups":[8,16,32,64],"equal":failures.is_empty()})
		if extent == Vector2i(720,480):
			for width in [1,8,16,32,64,64,32,16,8,1]:
				var gpu: RefCounted = processors[width]
				for frame in 10: gpu.render(input,frame,{})
				rd.texture_get_data(gpu.output,0)
				var start := Time.get_ticks_usec()
				for frame in 30: gpu.render(input,frame+10,{})
				rd.texture_get_data(gpu.output,0)
				var cost := float(Time.get_ticks_usec()-start)/30000.0
				report.performance.append({"group":width,"ms_per_frame":cost})
				print("NTSC_GROUP ",width," ",cost," ms/frame")
		for gpu in processors.values(): gpu.dispose()
		rd.free_rid(input)
		FileAccess.open(OUT.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	report["failures"] = failures
	FileAccess.open(OUT.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	done = true
