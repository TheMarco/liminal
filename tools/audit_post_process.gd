extends SceneTree
## Headless state audit for the found-footage post-process controller.

const CONTROLLER := preload("res://scripts/post_process_controller.gd")

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func approx(value: Variant, expected: Variant, tolerance := 0.0001) -> bool:
	return typeof(value) == typeof(expected) and absf(float(value) - float(expected)) <= tolerance

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var controller := CONTROLLER.new()
	host.add_child(controller)
	controller.setup(host, true, true)
	var full_material: ShaderMaterial = controller._found_footage_material
	expect(controller._tube_display != null and controller._tube_display.visible, "initial tape tube display is hidden")
	expect(controller._tube_display.get_child_count() == 2, "tube display pass has wrong child count")
	var tube_copy: BackBufferCopy = controller._tube_display.get_child(0)
	var tube_face: ColorRect = controller._tube_display.get_child(1)
	expect(tube_copy.name == "TapeSignalCopy" and tube_face.name == "Display", "tube pass ordering or names are wrong")
	expect(tube_copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "tube copy is not viewport mode")
	expect((tube_face.material as ShaderMaterial).shader == CONTROLLER.CRT_DISPLAY_SHADER, "tube display shader mismatch")
	expect(full_material.get_shader_parameter("tape_signal") == true, "full-screen tape_signal is not true")
	expect(full_material.get_shader_parameter("resolution") == CONTROLLER.FOUND_FOOTAGE_RESOLUTION, "full-screen resolution mismatch")
	var tv_material := CONTROLLER.make_found_footage_material(CONTROLLER.TV_TAPE_RESOLUTION)
	expect(tv_material.get_shader_parameter("tape_signal") == true, "TV tape_signal is not true")
	expect(tv_material.get_shader_parameter("resolution") == CONTROLLER.TV_TAPE_RESOLUTION, "TV resolution mismatch")

	var clean_noise = controller._crt_material.get_shader_parameter("noise_level")
	expect(controller.toggle_mode() == "CRT", "initial tape mode did not toggle to CRT")
	expect(not controller._tube_display.visible, "CRT mode did not hide tube display")
	controller._apply_found_footage_state()
	expect(controller._crt_material.get_shader_parameter("noise_level") == clean_noise, "clean CRT received tape noise state")
	expect(controller._crt_material.get_shader_parameter("tape_signal") != true, "clean CRT tape_signal is enabled")
	expect(controller.toggle_mode() == "RECOVERED TAPE", "toggle_mode did not enter tape mode")
	expect(controller._tube_display.visible, "tape mode did not show tube display")
	expect(controller.toggle_mode() == "CRT", "toggle_mode did not return to CRT")
	expect(controller.toggle_mode() == "RECOVERED TAPE", "toggle_mode did not restore tape mode")
	controller.set_enabled(false)
	expect(not controller._overlay.visible, "disabled overlay remains visible")
	expect(not controller._tube_display.visible, "disabled tube display remains visible")
	controller.set_enabled(true)
	expect(controller._overlay.visible, "enabled overlay remains hidden")
	expect(controller._tube_display.visible, "enabled tape tube remains hidden")
	controller.set_tape_playback(true)
	expect(not controller._overlay.visible, "tape playback did not hide overlay")
	expect(not controller._tube_display.visible, "tape playback did not hide tube display")
	controller.set_tape_playback(false)
	expect(controller._overlay.visible, "tape playback release did not show overlay")
	expect(controller._tube_display.visible, "tape playback release did not show tube display")
	var tv_parent := Control.new()
	host.add_child(tv_parent)
	var tv_display := CONTROLLER.add_crt_display_pass(tv_parent, CONTROLLER.TV_TAPE_RESOLUTION)
	expect(tv_display.get_child(0) is BackBufferCopy and tv_display.get_child(1) is ColorRect, "TV pass child types/order mismatch")
	expect((tv_display.get_child(0) as BackBufferCopy).copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "TV copy is not viewport mode")
	var tv_face_material := (tv_display.get_child(1) as ColorRect).material as ShaderMaterial
	expect(tv_face_material.shader == CONTROLLER.CRT_DISPLAY_SHADER, "TV display shader mismatch")
	expect(tv_face_material.get_shader_parameter("signal_resolution") == CONTROLLER.TV_TAPE_RESOLUTION, "TV display resolution mismatch")
	expect(CONTROLLER.TV_TAPE_RESOLUTION == Vector2(344.0, 240.0), "TV tape resolution changed")
	var tv_baseline := {
		"noise_level": tv_material.get_shader_parameter("noise_level"),
		"line_noise": tv_material.get_shader_parameter("line_noise"),
		"dropout_amount": tv_material.get_shader_parameter("dropout_amount"),
		"head_switch_amount": tv_material.get_shader_parameter("head_switch_amount"),
		"tape_speckle": tv_material.get_shader_parameter("tape_speckle"),
		"rf_noise": tv_material.get_shader_parameter("rf_noise"),
		"sync_error": tv_material.get_shader_parameter("sync_error")
	}

	for p in [0.0, 0.12, 0.5, 1.0]:
		var envelope := CONTROLLER.glitch_envelope(p)
		expect(envelope == 0.0 if p == 0.0 or p == 1.0 else envelope > 0.0, "bad glitch envelope at %s" % p)
	expect(CONTROLLER.glitch_envelope(0.12) > CONTROLLER.glitch_envelope(0.5), "glitch envelope does not decay")

	controller._mode = CONTROLLER.Mode.FOUND_FOOTAGE
	controller._overlay.material = full_material
	var baseline_dropout := float(full_material.get_shader_parameter("dropout_amount"))
	var glitch_parameters := {
		CONTROLLER.GlitchKind.TRACKING: "tracking_error",
		CONTROLLER.GlitchKind.COLOR_UNLOCK: "chroma_loss",
		CONTROLLER.GlitchKind.DROPOUT: "dropout_amount",
		CONTROLLER.GlitchKind.RF_STATIC: "rf_noise",
		CONTROLLER.GlitchKind.SYNC_SLIP: "sync_error",
	}
	for kind in glitch_parameters:
		controller._glitch_active = true
		controller._glitch_major = true
		controller._glitch_strength = 0.8
		controller._glitch_origin = 0.5
		controller._glitch_started = Time.get_ticks_msec() * 0.001 - 0.05
		controller._glitch_until = Time.get_ticks_msec() * 0.001 + 0.20
		controller._glitch_kind = kind
		controller._apply_found_footage_state()
		var param: String = glitch_parameters[kind]
		var baseline := baseline_dropout if kind == CONTROLLER.GlitchKind.DROPOUT else 0.0
		expect(float(full_material.get_shader_parameter(param)) > baseline, "glitch kind %s did not increase %s" % [kind, param])
	controller._glitch_active = false
	controller._apply_found_footage_state()
	expect(approx(full_material.get_shader_parameter("tracking_error"), 0.0), "tracking did not reset")
	expect(approx(full_material.get_shader_parameter("chroma_loss"), 0.0), "chroma loss did not reset")
	expect(approx(full_material.get_shader_parameter("vertical_slip"), 0.0), "vertical slip did not reset")
	expect(approx(full_material.get_shader_parameter("rf_noise"), 0.0), "RF noise did not reset")
	expect(approx(full_material.get_shader_parameter("sync_error"), 0.0), "sync error did not reset")

	for key in tv_baseline:
		expect(tv_material.get_shader_parameter(key) == tv_baseline[key], "TV parameter changed: %s" % key)

	controller.glitch_burst()
	expect(float(full_material.get_shader_parameter("signal_loss")) > 0.0, "burst did not apply loss")
	controller._burst_until = 0.0
	controller._apply_found_footage_state()
	expect(approx(full_material.get_shader_parameter("signal_loss"), 0.0), "burst loss did not reset")
	controller.damage_hit()
	expect(float(full_material.get_shader_parameter("tracking_error")) > 0.0, "damage did not apply tracking")
	controller._damage_until = Time.get_ticks_msec() * 0.001 - 1.0
	controller.update()
	expect(approx(full_material.get_shader_parameter("tracking_error"), 0.0), "expired damage did not clear")
	controller.set_corruption(99.0)
	expect(approx(controller._signal_corruption, 1.0), "corruption did not clamp high")
	controller.set_corruption(-1.0)
	expect(approx(controller._signal_corruption, 0.0), "corruption did not clamp low")
	controller._mode = CONTROLLER.Mode.CRT
	controller._apply_found_footage_state()
	expect(controller._crt_material.get_shader_parameter("tape_signal") != true, "corruption altered clean CRT tape signal")
	expect(controller._crt_material.get_shader_parameter("noise_level") == clean_noise, "tape events altered clean CRT noise")

	var now := Time.get_ticks_msec() * 0.001
	controller._start_glitch(true, now)
	expect(controller._minor_at - now >= 5.0 and controller._minor_at - now <= 11.0, "major minor schedule out of bounds")
	expect(controller._major_at - now >= 28.0 and controller._major_at - now <= 55.0, "major schedule out of bounds")
	expect(controller._glitch_until - now >= 0.18 and controller._glitch_until - now <= 0.45, "major glitch duration out of bounds")
	controller._start_glitch(false, now)
	expect(controller._minor_at - now >= 5.0 and controller._minor_at - now <= 11.0, "minor reschedule out of bounds")
	expect(controller._glitch_until - now >= 0.08 and controller._glitch_until - now <= 0.20, "minor glitch duration out of bounds")

	host.free()
	if failures.is_empty():
		print("audit_post_process: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("audit_post_process: FAIL (%d)" % failures.size())
		quit(1)
