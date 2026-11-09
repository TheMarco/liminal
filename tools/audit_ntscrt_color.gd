extends "res://tools/lib/audit_base.gd"
## Native colour-management regression: GPU presentation must preserve shadows.
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const PRESENTER = preload("res://scripts/ntscrt_gpu_presenter.gd")

func settle() -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw

func samples() -> Array[Color]:
	var image := root.get_texture().get_image()
	var result: Array[Color] = []
	for index in 4: result.append(image.get_pixel(index * 100 + 50, 50))
	return result

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Colour audit requires the native GPU renderer")
		finish()
		return
	root.size = Vector2i(400, 100)
	for hdr in [false, true]:
		root.use_hdr_2d = hdr
		var host := HOST.new()
		root.add_child(host)
		for index in 4:
			var patch := ColorRect.new()
			var value: float = [0.05, 0.18, 0.5, 0.85][index]
			patch.color = Color(value, value, value)
			patch.position = Vector2(index * 100, 0)
			patch.size = Vector2(100, 100)
			host.source.add_child(patch)
		await settle()
		var reference := samples()
		var presenter := PRESENTER.new()
		presenter.source = host.source
		presenter.preset_name = "none"
		host.add_child(presenter)
		var srgb := PRESENTER._preparation(false)
		srgb.passes[0].format = "R8G8B8A8_SRGB"
		var decode := "vec3 decode_srgb(vec3 v) { return mix(v/12.92,pow((v+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),v)); }\n"
		srgb.passes[0].fragment = str(srgb.passes[0].fragment).replace("void main()", decode + "void main()").replace("vec4(value,1.0)", "vec4(decode_srgb(value),1.0)")
		presenter._presets["srgb_probe"] = srgb
		var floating := PRESENTER._preparation(false)
		floating.passes[0].format = "R16G16B16A16_SFLOAT"
		presenter._presets["float_probe"] = floating
		for name in ["none", "srgb_probe", "float_probe"]:
			presenter.preset_name = name
			await settle()
			var actual := samples()
			for index in reference.size():
				var tolerance := maxf(0.0006, reference[index].r * 0.015) if hdr else 0.006
				expect(absf(actual[index].r - reference[index].r) < tolerance,
					"HDR=%s %s patch %d: %s versus direct %s" % [hdr, name, index, actual[index], reference[index]])
			print("VIDEO_COLOUR hdr=", hdr, " format=", name, " midgrey=", actual[2].r, " reference=", reference[2].r)
		host.queue_free()
		await settle()
	finish("GPU presentation preserves SDR/HDR shadow, midtone and highlight values")
