class_name PostProcessController
extends Node
## Owns the recording-media overlay and its transient damage/glitch state.
## Gameplay reports pressure and camera hits; it does not manipulate shaders.

enum Mode { CRT, FOUND_FOOTAGE }

var _overlay: ColorRect
var _crt_material: ShaderMaterial
var _found_footage_material: ShaderMaterial
var _mode := Mode.CRT
var _enabled := true
var _signal_corruption := 0.0
var _minor_at := 0.0
var _major_at := 0.0
var _glitch_until := 0.0
var _damage_until := 0.0
var _glitch_active := false
var _glitch_major := false
var _glitch_jitter := 0.006
var _glitch_tracking := 0.18
var _glitch_aberration := 0.0035
var _glitch_noise := 0.10
var _damage_intensity := 0.0


func setup(host: Node, found_footage := false, enabled := true) -> void:
	_mode = Mode.FOUND_FOOTAGE if found_footage else Mode.CRT
	_enabled = enabled
	var layer := CanvasLayer.new()
	layer.layer = 1
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = load("res://shaders/post.gdshader")
	_crt_material.set_shader_parameter("bright_boost", 1.4)
	_found_footage_material = ShaderMaterial.new()
	_found_footage_material.shader = load(
		"res://shaders/found_footage.gdshader")
	_overlay.material = _material_for_mode()
	_overlay.visible = _enabled
	layer.add_child(_overlay)
	host.add_child(layer)
	_schedule_glitches(Time.get_ticks_msec() * 0.001)
	_apply_found_footage_state()


func is_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void:
	_enabled = value
	if _overlay != null:
		_overlay.visible = value


func toggle_enabled() -> bool:
	set_enabled(not _enabled)
	return _enabled


func toggle_mode() -> String:
	if _overlay == null or _crt_material == null \
			or _found_footage_material == null:
		return mode_label()
	_mode = Mode.FOUND_FOOTAGE if _mode == Mode.CRT else Mode.CRT
	_overlay.material = _material_for_mode()
	if _mode == Mode.FOUND_FOOTAGE:
		_schedule_glitches(Time.get_ticks_msec() * 0.001)
		_apply_found_footage_state()
	return mode_label()


func mode_label() -> String:
	return "RECOVERED TAPE" if _mode == Mode.FOUND_FOOTAGE else "480i CRT"


func set_noise(value: float) -> void:
	if _crt_material != null:
		_crt_material.set_shader_parameter("noise_amount", value)


func pulse_noise(high: float, baseline: float, duration: float) -> void:
	set_noise(high)
	var tween := create_tween()
	tween.tween_method(set_noise, high, baseline, duration)


func set_corruption(amount: float) -> void:
	_signal_corruption = clampf(amount, 0.0, 1.0)
	set_noise(1.0 + _signal_corruption * 1.6)
	_apply_found_footage_state()


func damage_hit(intensity := 1.0) -> void:
	_damage_intensity = clampf(intensity, 0.0, 1.0)
	_damage_until = Time.get_ticks_msec() * 0.001 + 0.15
	_apply_found_footage_state()


func update() -> void:
	if _found_footage_material == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	var changed := false
	if _damage_intensity > 0.0 and now >= _damage_until:
		_damage_intensity = 0.0
		changed = true
	if _glitch_active and now >= _glitch_until:
		_glitch_active = false
		changed = true
	if _mode == Mode.FOUND_FOOTAGE and _enabled:
		if _minor_at <= 0.0 or _major_at <= 0.0:
			_schedule_glitches(now)
		if not _glitch_active:
			if now >= _major_at:
				_start_glitch(true, now)
				return
			if now >= _minor_at:
				_start_glitch(false, now)
				return
	if changed:
		_apply_found_footage_state()


func _material_for_mode() -> ShaderMaterial:
	return _found_footage_material if _mode == Mode.FOUND_FOOTAGE \
		else _crt_material


func _schedule_glitches(now: float) -> void:
	_minor_at = now + randf_range(1.5, 5.0)
	_major_at = now + randf_range(10.0, 28.0)
	_glitch_active = false


func _start_glitch(major: bool, now: float) -> void:
	_glitch_active = true
	_glitch_major = major
	if major:
		_glitch_until = now + randf_range(0.12, 0.42)
		_glitch_jitter = randf_range(0.025, 0.05)
		_glitch_tracking = randf_range(0.55, 1.0)
		_glitch_noise = randf_range(0.22, 0.48)
		_glitch_aberration = randf_range(0.012, 0.02)
		_major_at = now + randf_range(10.0, 28.0)
	else:
		_glitch_until = now + randf_range(0.04, 0.16)
		_glitch_jitter = randf_range(0.012, 0.028)
		_glitch_aberration = randf_range(0.006, 0.013)
		_minor_at = now + randf_range(1.5, 5.0)
	_apply_found_footage_state()


func _apply_found_footage_state() -> void:
	if _found_footage_material == null:
		return
	var jitter := lerpf(0.006, 0.032, _signal_corruption)
	var tracking := lerpf(0.18, 0.85, _signal_corruption)
	var noise := lerpf(0.10, 0.42, _signal_corruption)
	var aberration := 0.0035
	var saturation_value := lerpf(0.72, 0.30, _signal_corruption)
	var shake := 0.0015
	var exposure := 0.06
	if _glitch_active:
		jitter = maxf(jitter, _glitch_jitter)
		aberration = maxf(aberration, _glitch_aberration)
		if _glitch_major:
			tracking = maxf(tracking, _glitch_tracking)
			noise = maxf(noise, _glitch_noise)
	if _damage_intensity > 0.0:
		shake = lerpf(0.003, 0.012, _damage_intensity)
		aberration = maxf(aberration,
			lerpf(0.006, 0.018, _damage_intensity))
		exposure = lerpf(0.10, 0.30, _damage_intensity)
	_found_footage_material.set_shader_parameter("horizontal_jitter", jitter)
	_found_footage_material.set_shader_parameter("tracking_damage", tracking)
	_found_footage_material.set_shader_parameter("static_noise", noise)
	_found_footage_material.set_shader_parameter(
		"chromatic_aberration", aberration)
	_found_footage_material.set_shader_parameter("saturation", saturation_value)
	_found_footage_material.set_shader_parameter("camera_shake", shake)
	_found_footage_material.set_shader_parameter("exposure_pumping", exposure)
