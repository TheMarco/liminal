extends SceneTree
## Static/runtime contract for true display HDR. A headless runner cannot own an
## HDR monitor, but it can prove that the 4.7 API, framebuffer, renderer,
## tonemappers and final presentation shader are all HDR-safe. The clean path
## may use display headroom; the CRT path intentionally emulates an SDR tube.

var failures: Array[String] = []


func _init() -> void:
	if not HdrOutput.engine_supported():
		failures.append("audit is not running on Godot 4.7+")
	_check(bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)),
		"root HDR 2D framebuffer is disabled")
	_check(ProjectSettings.get_setting("rendering/rendering_device/driver.windows", "") == "d3d12",
		"Windows HDR does not use D3D12")
	var features: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features", PackedStringArray())
	_check("4.7" in features and "Forward Plus" in features,
		"project is not marked as Godot 4.7 Forward+")

	for theme in WorldGen.THEMES:
		var environment := EnvBuilder.build(int(theme))
		_check(environment.tonemap_mode == Environment.TONE_MAPPER_AGX,
			"theme %s is not using the HDR-compatible AgX tonemapper" % theme)
		_check(not environment.adjustment_enabled,
			"theme %s enables SDR-only color correction" % theme)
		_check(not environment.glow_enabled \
				or environment.glow_blend_mode != Environment.GLOW_BLEND_MODE_SOFTLIGHT,
			"theme %s uses SDR-only soft-light glow" % theme)

	var shader_source := FileAccess.get_file_as_string(
		"res://shaders/crt_display.gdshader")
	_check("sdr_tube_shoulder" in shader_source,
		"CRT final pass has no HDR-safe highlight shoulder")
	_check("clamp(display * aperture, vec3(0.0), vec3(1.0))" in shader_source,
		"CRT final pass can exceed SDR tube white")
	_check("filter_linear_mipmap" in shader_source and "2.35" in shader_source,
		"CRT diffusion is not using the reduced-cost mip path")
	_check("for (int i = -1; i <= 1; i++)" in shader_source,
		"CRT beam still uses the redundant fourth scan-row sample")
	_check(HdrOutput.request(get_root(), false),
		"Godot 4.7 HDR Window API is unavailable")
	if DisplayServer.get_name() == "headless":
		_check(not HdrOutput.display_server_supported(),
			"headless display server falsely advertises HDR output")
		_check(not HdrOutput.is_active(get_root()),
			"headless window falsely reports active HDR")

	for failure in failures:
		push_error("HDR OUTPUT AUDIT FAIL: " + failure)
	if failures.is_empty():
		print("HDR OUTPUT AUDIT PASS — 4.7 API, HDR framebuffer, D3D12, AgX and SDR-safe CRT")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
