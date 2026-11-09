extends SceneTree
## Native GPU fixture runner. Readback is confined to this offline audit.
## godot --path . --script tools/audit_ntscrs_gpu.gd --quit-after 120 -- WIDTH HEIGHT FRAME SETTINGS INPUT OUTPUT
var _done := false
var _status := 0
var _message := ""

func _initialize() -> void:
	RenderingServer.call_on_render_thread(_run)

func _process(_delta: float) -> bool:
	if _done:
		print(_message)
		quit(_status)
	return false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--roundtrip"):
		_status = 0 if _roundtrip_check(RenderingServer.get_rendering_device()) else 1
		_done = true
		return
	if args.has("--history"):
		_status = 0 if _history_check(RenderingServer.get_rendering_device()) else 1
		_done = true
		return
	if args.has("--suite"):
		_suite()
		return
	var extent := Vector2i(16, 12)
	var frame := 0
	var settings: Dictionary = {}
	var input_data := PackedByteArray()
	var output_path := "/tmp/ntscrs-gpu.rgba"
	if args.size() >= 6:
		extent = Vector2i(int(args[0]), int(args[1]))
		frame = int(args[2])
		settings = JSON.parse_string(FileAccess.get_file_as_string(args[3]))
		input_data = FileAccess.get_file_as_bytes(args[4])
		output_path = args[5]
	else:
		input_data.resize(extent.x * extent.y * 4)
		for y in extent.y:
			for x in extent.x:
				var i := (y * extent.x + x) * 4
				input_data[i] = (x * 17) % 256
				input_data[i+1] = (y * 23) % 256
				input_data[i+2] = ((x+y) * 13) % 256
				input_data[i+3] = 255
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_fail("Native RenderingDevice required (do not use --headless)")
		return
	var gpu = load("res://scripts/ntscrs_gpu.gd").new()
	if not gpu.setup(rd, extent):
		_fail(gpu.error)
		gpu.dispose()
		return
	var format := RDTextureFormat.new()
	format.width = extent.x
	format.height = extent.y
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var input := rd.texture_create(format, RDTextureView.new(), [input_data])
	var output: RID = gpu.render(input, frame, settings)
	# The blocking readback is deliberate and exists only in the test harness.
	var data := rd.texture_get_data(output, 0)
	if args.size() >= 7:
		var yiq_file := FileAccess.open(args[6], FileAccess.WRITE)
		yiq_file.store_buffer(rd.buffer_get_data(gpu._planes[0]))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_buffer(data)
	_message = "NTSC_RS_GPU_OK bytes=%d output=%s" % [data.size(), output_path]
	gpu.dispose()
	rd.free_rid(input)
	_done = true

func _fail(message: String) -> void:
	_message = "NTSC_RS_GPU_FAIL " + message
	_status = 1
	_done = true

func _suite() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/ntscrt/ntscrs_gpu_coverage.json"))
	var destination := ProjectSettings.globalize_path("res://build/ntscrt-reference/gpu-audit")
	DirAccess.make_dir_recursive_absolute(destination)
	var binary := ProjectSettings.globalize_path("res://build/ntscrt-reference/target/release/ntscrt-reference")
	if not FileAccess.file_exists(binary):
		_fail("Build pinned reference with tools/ntscrt/build_reference.sh first")
		return
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		_fail("Native Metal/Vulkan RenderingDevice required")
		return
	var results: Array = []
	for case: Dictionary in manifest.cases:
		var extent := Vector2i(int(case.width), int(case.height))
		var frame := int(case.frame)
		var settings: Dictionary = {} if case.get("use_current_defaults", false) else manifest.base_settings.duplicate(true)
		settings.merge(case.settings, true)
		var stem: String = destination.path_join(case.name)
		var pixels := PackedByteArray()
		pixels.resize(extent.x * extent.y * 4)
		for y in extent.y:
			for x in extent.x:
				var i := (y * extent.x + x) * 4
				pixels[i] = (x * 17 + y * 3) % 256
				pixels[i+1] = (y * 23 + x * 7) % 256
				pixels[i+2] = ((x+y) * 13) % 256
				pixels[i+3] = 255
		FileAccess.open(stem + ".input.rgba", FileAccess.WRITE).store_buffer(pixels)
		FileAccess.open(stem + ".json", FileAccess.WRITE).store_string(JSON.stringify(settings))
		var args := PackedStringArray(["process", str(extent.x), str(extent.y), str(frame), stem + ".json", stem + ".input.rgba", stem + ".reference.rgba"])
		var reference_log: Array = []
		if OS.execute(binary, args, reference_log, true) != 0:
			_fail("Reference failed for %s: %s" % [case.name, reference_log])
			return
		var gpu = load("res://scripts/ntscrs_gpu.gd").new()
		if not gpu.setup(rd, extent):
			_fail(gpu.error)
			gpu.dispose()
			return
		var format := RDTextureFormat.new()
		format.width = extent.x
		format.height = extent.y
		format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		var input := rd.texture_create(format, RDTextureView.new(), [pixels])
		var output: RID = gpu.render(input, frame, settings)
		var actual := rd.texture_get_data(output, 0)
		var expected := FileAccess.get_file_as_bytes(stem + ".reference.rgba")
		FileAccess.open(stem + ".gpu.rgba", FileAccess.WRITE).store_buffer(actual)
		var max_error := 0
		var sum_error := 0
		var different := 0
		for i in expected.size():
			var difference := absi(int(expected[i]) - int(actual[i]))
			max_error = maxi(max_error, difference)
			sum_error += difference
			different += int(difference != 0)
		var result := {"case": case.name, "max_error_u8": max_error, "mean_rgb_error_u8": float(sum_error) / (extent.x * extent.y * 3), "different_channels": different}
		results.append(result)
		print(JSON.stringify(result))
		gpu.dispose()
		rd.free_rid(input)
		if max_error > int(case.get("max_error_u8", 1)):
			_status = 1
	if not _roundtrip_check(rd):
		_status = 1
	if not _history_check(rd):
		_status = 1
	FileAccess.open(destination.path_join("results.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	_message = "NTSC_RS_GPU_SUITE_%s cases=%d results=%s" % ["OK" if _status == 0 else "FAIL", results.size(), destination.path_join("results.json")]
	_done = true

func _history_check(rd: RenderingDevice) -> bool:
	var extent := Vector2i(8, 6)
	var gpu = load("res://scripts/ntscrs_gpu.gd").new()
	var bob = load("res://scripts/ntscrs_gpu.gd").new()
	if not gpu.setup(rd, extent) or not bob.setup(rd, extent):
		return false
	var inputs: Array[RID] = []
	for color in [Color.RED, Color.BLUE, Color.GREEN]:
		var image := Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
		image.fill(color)
		var format := RDTextureFormat.new()
		format.width = extent.x
		format.height = extent.y
		format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		inputs.append(rd.texture_create(format, RDTextureView.new(), [image.get_data()]))
	var settings := {"use_field": 0, "field_history": true}
	var stable: RID = gpu.render(inputs[0], 0, settings)
	var previous := rd.texture_get_data(stable, 0)
	var valid := true
	for index in [1, 2]:
		var actual := rd.texture_get_data(gpu.render(inputs[index], 1, settings), 0)
		var baseline := rd.texture_get_data(bob.render(inputs[index], 1, {"use_field": 0}), 0)
		valid = valid and gpu.output == stable
		for y in extent.y:
			for x in extent.x * 4:
				var offset := y * extent.x * 4 + x
				var expected := previous[offset] if y % 2 == 1 else baseline[offset]
				valid = valid and actual[offset] == expected
	# Rewinding invalidates history, restoring canonical Bob immediately.
	var rewind := rd.texture_get_data(gpu.render(inputs[2], 0, settings), 0)
	var rewind_bob := rd.texture_get_data(bob.render(inputs[2], 0, {"use_field": 0}), 0)
	valid = valid and rewind == rewind_bob
	gpu.dispose()
	bob.dispose()
	for input in inputs:
		rd.free_rid(input)
	print("NTSC_RS_GPU_HISTORY_%s stable_rid advancing repeating rewinding" % ("OK" if valid else "FAIL"))
	return valid

func _roundtrip_check(rd: RenderingDevice) -> bool:
	var extent := Vector2i(17, 7)
	var pixels := PackedByteArray()
	for y in extent.y:
		for x in extent.x:
			pixels.append_array(PackedByteArray([(x*17+y*3)%256, (x*7+y*23)%256, ((x+y)*13)%256, 255]))
	var gpu = load("res://scripts/ntscrs_gpu.gd").new()
	if not gpu.setup(rd, extent):
		return false
	var format := RDTextureFormat.new()
	format.width = extent.x
	format.height = extent.y
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	var input := rd.texture_create(format, RDTextureView.new(), [pixels])
	gpu.render(input, 0, {"use_field": 3})
	# Offline-only invocation of encode/decode without the intervening effects.
	var push := PackedByteArray()
	push.resize(32)
	push.encode_s32(0, extent.x)
	push.encode_s32(4, extent.y)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, gpu._pipeline)
	rd.compute_list_bind_uniform_set(list, gpu._sets[0], 0)
	rd.compute_list_set_push_constant(list, push, push.size())
	rd.compute_list_dispatch(list, extent.y, 1, 1)
	rd.compute_list_add_barrier(list)
	push.encode_s32(12, 8)
	rd.compute_list_bind_uniform_set(list, gpu._sets[1], 0)
	rd.compute_list_set_push_constant(list, push, push.size())
	rd.compute_list_dispatch(list, extent.y, 1, 1)
	rd.compute_list_end()
	var actual := rd.texture_get_data(gpu.output, 0)
	var stem := ProjectSettings.globalize_path("res://build/ntscrt-reference/gpu-audit/roundtrip")
	DirAccess.make_dir_recursive_absolute(stem.get_base_dir())
	FileAccess.open(stem + ".rgba", FileAccess.WRITE).store_buffer(pixels)
	FileAccess.open(stem + ".json", FileAccess.WRITE).store_string('{"use_field":3}')
	var output: Array = []
	var code := OS.execute(ProjectSettings.globalize_path("res://build/ntscrt-reference/target/release/ntscrt-reference"), PackedStringArray(["roundtrip",str(extent.x),str(extent.y),"0",stem+".json",stem+".rgba",stem+".reference.rgba"]),output,true)
	var expected := FileAccess.get_file_as_bytes(stem+".reference.rgba")
	var maximum := 0
	for i in mini(actual.size(), expected.size()):
		maximum = maxi(maximum,absi(int(actual[i])-int(expected[i])))
	var valid := code == 0 and expected.size() == actual.size() and maximum <= 1
	gpu.dispose()
	rd.free_rid(input)
	print("NTSC_RS_GPU_ROUNDTRIP_%s max_error_u8=%d" % ["OK" if valid else "FAIL",maximum])
	return valid
