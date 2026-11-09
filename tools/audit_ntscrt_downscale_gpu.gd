extends SceneTree
## Native audit: independent double-precision CPU oracle; readback only here.
## godot --path . --script tools/audit_ntscrt_downscale_gpu.gd --quit-after 1800
## Add -- --original-metal to compile and check the untouched sibling Swift kernels.
## CPU weights/accumulation use double; support coordinates retain source f32.
## nearestAA has a hard nonzero support cutoff: native compiler reassociation
## may include one extra boundary tap (observed 4-byte oracle error, reproduced
## byte-for-byte by the original Metal kernels).
const GPU = preload("res://scripts/ntscrt_downscale_gpu.gd")
const METHODS := ["nearest", "nearestAA", "bilinear", "bicubic", "lanczos", "area"]
var _done := false
var _status := 0

func _initialize() -> void:
	RenderingServer.call_on_render_thread(_run)

func _process(_delta: float) -> bool:
	if _done:
		quit(_status)
	return false

func _run() -> void:
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		print("DOWNSCALE_GPU_FAIL native RenderingDevice required")
		_status = 1
		_done = true
		return
	var original_binary := ""
	if OS.get_cmdline_user_args().has("--original-metal"):
		original_binary = _prepare_original_reference()
		if original_binary.is_empty():
			_status = 1
			_done = true
			return
	var dimensions := [
		[Vector2i(17, 13), Vector2i(7, 5)],
		[Vector2i(19, 11), Vector2i(3, 2)],
		[Vector2i(8, 6), Vector2i(4, 3)],
		[Vector2i(1, 1), Vector2i(1, 1)],
		[Vector2i(1, 9), Vector2i(7, 2)],
		[Vector2i(9, 1), Vector2i(2, 7)],
		[Vector2i(3, 2), Vector2i(11, 7)],
		[Vector2i(9, 7), Vector2i(9, 7)],
		[Vector2i(31, 23), Vector2i(1, 1)]]
	var results: Array = []
	var worst := 0
	var original_worst := 0
	for pair in dimensions:
		var source_size: Vector2i = pair[0]
		var target_size: Vector2i = pair[1]
		var gpu = GPU.new()
		if not gpu.setup(rd, source_size, target_size):
			print("DOWNSCALE_GPU_FAIL " + gpu.error)
			_status = 1
			_done = true
			gpu.dispose()
			return
		var stable: RID = gpu.output
		for pattern in ["ramp", "impulse", "constant"]:
			var source := _fixture(source_size, pattern)
			var format := RDTextureFormat.new()
			format.width = source_size.x
			format.height = source_size.y
			format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
			# Deliberately sampler-only: runtime must not require storage input.
			format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
			var input := rd.texture_create(format, RDTextureView.new(), [source])
			for method in 6:
				var expected := _reference(source, source_size, target_size, method)
				var output: RID = gpu.render(input, method)
				var actual := rd.texture_get_data(output, 0)
				var fixture_dir := ProjectSettings.globalize_path("res://build/ntscrt-reference/downscale-fixtures")
				DirAccess.make_dir_recursive_absolute(fixture_dir)
				var fixture_name := "%dx%d-%dx%d-%s-%d" % [source_size.x,source_size.y,target_size.x,target_size.y,pattern,method]
				FileAccess.open(fixture_dir.path_join(fixture_name + ".input"),FileAccess.WRITE).store_buffer(source)
				FileAccess.open(fixture_dir.path_join(fixture_name + ".gpu"),FileAccess.WRITE).store_buffer(actual)
				var maximum := 0
				var total := 0
				if output != stable or actual.size() != expected.size():
					maximum = 256
				else:
					for i in expected.size():
						var difference := absi(int(expected[i]) - int(actual[i]))
						maximum = maxi(maximum, difference)
						total += difference
				var result := {"source":str(source_size),"target":str(target_size),"pattern":pattern,"method":METHODS[method],"max_error_u8":maximum,"mean_error_u8":float(total)/expected.size()}
				if not original_binary.is_empty():
					var original_log: Array = []
					var stem := fixture_dir.path_join(fixture_name)
					var args := PackedStringArray([str(source_size.x),str(source_size.y),str(target_size.x),str(target_size.y),str(method),stem+".input",stem+".metal"])
					var original_maximum := 0
					if OS.execute(original_binary,args,original_log,true) != 0:
						original_maximum = 256
					else:
						var original := FileAccess.get_file_as_bytes(stem+".metal")
						if original.size() != actual.size():
							original_maximum = 256
						else:
							for i in original.size():
								original_maximum = maxi(original_maximum,absi(int(original[i])-int(actual[i])))
					result["original_metal_max_error_u8"] = original_maximum
					original_worst = maxi(original_worst,original_maximum)
					if original_maximum > 1:
						print("DOWNSCALE_ORIGINAL_FAIL " + JSON.stringify(result))
						_status = 1
				results.append(result)
				worst = maxi(worst, maximum)
				# All ordinary rounding <=1. Truncated Gaussian support may
				# differ at exact boundaries; original Metal validates that case.
				var tolerance := 4 if method == 1 else 1
				if maximum > tolerance:
					print("DOWNSCALE_CASE_FAIL " + JSON.stringify(result))
					_status = 1
			rd.free_rid(input)
		gpu.dispose()
	var path := ProjectSettings.globalize_path("res://build/ntscrt-reference/downscale-gpu-results.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("DOWNSCALE_GPU_%s cases=%d maximum_error_u8=%d results=%s" % ["OK" if _status == 0 else "FAIL", results.size(), worst, path])
	if not original_binary.is_empty():
		print("DOWNSCALE_ORIGINAL_METAL maximum_error_u8=%d" % original_worst)
	_done = true

static func _fixture(extent: Vector2i, pattern: String) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(extent.x * extent.y * 4)
	for y in extent.y:
		for x in extent.x:
			var offset := (y * extent.x + x) * 4
			var rgba: Array
			if pattern == "constant":
				rgba = [19, 101, 237, 173]
			elif pattern == "impulse":
				rgba = [255 if x == extent.x / 2 and y == extent.y / 2 else 0,
					255 if x == 0 and y == 0 else 0,
					255 if x == extent.x - 1 and y == extent.y - 1 else 0, 255]
			else:
				rgba = [(x*17+y*3)%256, (y*23+x*7)%256, ((x+y)*13)%256, (x*11+y*29)%256]
			for channel in 4:
				result[offset+channel] = rgba[channel]
	return result

static func _reference(source: PackedByteArray, input_size: Vector2i, output_size: Vector2i, method: int) -> PackedByteArray:
	if method in [0, 5]:
		var result := PackedByteArray()
		result.resize(output_size.x * output_size.y * 4)
		for y in output_size.y:
			for x in output_size.x:
				for channel in 4:
					var value := 0.0
					if method == 0:
						# Exact rational pixel-center indexing, independent of GPU UVs.
						var sx := mini(input_size.x-1, ((2*x+1)*input_size.x)/(2*output_size.x))
						var sy := mini(input_size.y-1, ((2*y+1)*input_size.y)/(2*output_size.y))
						value = source[(sy*input_size.x+sx)*4+channel]
					else:
						# Integrate overlap using integer coordinates on the common
						# source/destination lattice, avoiding float boundary errors.
						for sy in input_size.y:
							var wy := maxi(0, mini((y+1)*input_size.y,(sy+1)*output_size.y)-maxi(y*input_size.y,sy*output_size.y))
							for sx in input_size.x:
								var wx := maxi(0, mini((x+1)*input_size.x,(sx+1)*output_size.x)-maxi(x*input_size.x,sx*output_size.x))
								value += float(wx*wy)*source[(sy*input_size.x+sx)*4+channel]
						value /= float(input_size.x*input_size.y)
					result[(y*output_size.x+x)*4+channel] = clampi(roundi(value), 0, 255)
		return result
	# Quantize to RGBA8 after horizontal filtering, matching the source's
	# texture-format scratch; keeping an unquantized intermediate is wrong.
	var intermediate := _axis(source, input_size, output_size.x, method, false)
	return _axis(intermediate, Vector2i(output_size.x,input_size.y), output_size.y, method, true)

static func _axis(source: PackedByteArray, extent: Vector2i, count: int, method: int, vertical: bool) -> PackedByteArray:
	var input_count := extent.y if vertical else extent.x
	var destination := Vector2i(extent.x,count) if vertical else Vector2i(count,extent.y)
	var ratio := _f32(float(input_count)/count)
	var scale := maxf(1.0,ratio)
	var radius := 2 if method == 3 else 3 if method == 4 else 1
	var result := PackedByteArray()
	result.resize(destination.x*destination.y*4)
	for y in destination.y:
		for x in destination.x:
			var center := _f32(_f32(_f32(((y if vertical else x)+0.5)*input_count)/count)-0.5)
			var first := ceili(_f32(center-_f32(radius*scale)))
			var last := floori(_f32(center+_f32(radius*scale)))
			var coefficients := PackedFloat64Array()
			var total := 0.0
			for i in range(first,last+1):
				var coefficient := _kernel(_f32(_f32(i-center)/scale),method)
				coefficients.append(coefficient)
				total += coefficient
			for channel in 4:
				var value := 0.0
				for i in range(first,last+1):
					var at := clampi(i,0,input_count-1)
					var sx := x if vertical else at
					var sy := at if vertical else y
					value += source[(sy*extent.x+sx)*4+channel]*coefficients[i-first]
				result[(y*destination.x+x)*4+channel] = clampi(roundi(value/maxf(total,1e-6)),0,255)
	return result

static func _kernel(t: float, method: int) -> float:
	var x := absf(t)
	match method:
		1: return exp(-4.0816*x*x)
		2: return maxf(0.0,1.0-x)
		3:
			# Algebraically reduced Mitchell-Netravali B=C=1/3.
			if x < 1.0:
				return (7*x*x*x-12*x*x+16.0/3.0)/6.0
			if x < 2.0:
				return (-7.0/3.0*x*x*x+12*x*x-20*x+32.0/3.0)/6.0
			return 0.0
		4:
			if x >= 3.0: return 0.0
			return _sinc(x)*_sinc(x/3.0)
	return 0.0

static func _sinc(x: float) -> float:
	return 1.0 if absf(x) < 1e-6 else sin(PI*x)/(PI*x)

static func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]


static func _prepare_original_reference() -> String:
	var source := ProjectSettings.globalize_path("res://../NTSCRT/Sources/CrtCore/Downscaler.swift")
	if not FileAccess.file_exists(source):
		print("DOWNSCALE_REFERENCE_FAIL sibling NTSCRT/Downscaler.swift is unavailable")
		return ""
	var folder := ProjectSettings.globalize_path("res://build/ntscrt-reference/downscale-original-metal")
	DirAccess.make_dir_recursive_absolute(folder)
	var harness := folder.path_join("main.swift")
	FileAccess.open(harness, FileAccess.WRITE).store_string(ORIGINAL_METAL_HARNESS)
	var binary := folder.path_join("downscale-original")
	var output: Array = []
	var result := OS.execute("/usr/bin/swiftc",PackedStringArray(["-module-cache-path",folder.path_join("module-cache"),source,harness,"-o",binary]),output,true)
	if result != 0:
		print("DOWNSCALE_REFERENCE_FAIL " + str(output))
		return ""
	return binary

const ORIGINAL_METAL_HARNESS := """
import Foundation
import Metal
let a = CommandLine.arguments
let sw = Int(a[1])!, sh = Int(a[2])!, dw = Int(a[3])!, dh = Int(a[4])!, method = Int(a[5])!
let input = try Data(contentsOf: URL(fileURLWithPath:a[6]))
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
func texture(_ w: Int, _ h: Int) -> MTLTexture {
 let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:w,height:h,mipmapped:false)
 d.storageMode = .shared; d.usage = [.shaderRead,.shaderWrite]
 return device.makeTexture(descriptor:d)!
}
let src=texture(sw,sh), dst=texture(dw,dh)
input.withUnsafeBytes { p in src.replace(region:MTLRegionMake2D(0,0,sw,sh),mipmapLevel:0,withBytes:p.baseAddress!,bytesPerRow:sw*4) }
let scaler=try Downscaler(device:device)
let cb=queue.makeCommandBuffer()!
let methods:[DownscaleMethod]=[.nearest,.nearestAA,.bilinear,.bicubic,.lanczos,.area]
scaler.encode(into:cb,source:src,destination:dst,method:methods[method]);cb.commit();cb.waitUntilCompleted()
var bytes=[UInt8](repeating:0,count:dw*dh*4)
bytes.withUnsafeMutableBytes { p in dst.getBytes(p.baseAddress!,bytesPerRow:dw*4,from:MTLRegionMake2D(0,0,dw,dh),mipmapLevel:0) }
try Data(bytes).write(to:URL(fileURLWithPath:a[7]))
"""
