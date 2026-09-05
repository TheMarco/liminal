class_name PostProcessController
extends Node
## Owns the recording-media overlay and its transient damage/glitch state.
## Gameplay reports pressure and camera hits; it does not manipulate shaders.

enum Mode { CRT, FOUND_FOOTAGE }
enum GlitchKind { TRACKING, COLOR_UNLOCK, DROPOUT, RF_STATIC, SYNC_SLIP }

var _overlay: ColorRect
var _tube_display: Control
var _crt_material: ShaderMaterial
var _found_footage_material: ShaderMaterial
var _mode := Mode.CRT
var _enabled := true
## While a ritual tape owns the camera, the main full-screen pass steps aside.
## Playback has its own high-resolution, TV-glass-only instance of the shared
## recovered-footage material.
var _tape_hold := false
var _signal_corruption := 0.0
var _minor_at := 0.0
var _major_at := 0.0
var _glitch_until := 0.0
var _damage_until := 0.0
var _glitch_active := false
var _glitch_major := false
var _glitch_started := 0.0
var _glitch_kind := GlitchKind.TRACKING
var _glitch_strength := 0.0
var _glitch_origin := 0.6
var _damage_intensity := 0.0
## Nearness of the closest hostile figure, seen or not, 0..1. Fast attack,
## slow release: the footage breaks before the cause is in frame and takes
## seconds to settle after it is gone. Drives the tape material only — the
## owner keeps the clean tube clean.
var _presence := 0.0
var _presence_target := 0.0
var _burst_until := 0.0

const PRESENCE_ATTACK := 4.0    # per second toward a higher target
const PRESENCE_RELEASE := 0.35  # per second toward a lower target
const BURST_SECONDS := 0.11     # ~2-3 frames of catastrophic loss
const POST_SHADER := preload("res://shaders/post.gdshader")
const CRT_DISPLAY_SHADER := preload("res://shaders/crt_display.gdshader")
const FOUND_FOOTAGE_RESOLUTION := Vector2(720.0, 480.0)
## 240 visible rows at the ritual TV's physical tube aspect.
const TV_TAPE_RESOLUTION := Vector2(344.0, 240.0)


## Base signal preset used by the in-world televisions. The live feed builds
## on this through make_live_found_footage_material(), so added player-camera
## wear can be tuned without changing the recordings displayed on those TVs.
static func make_found_footage_material(
		signal_resolution := FOUND_FOOTAGE_RESOLUTION) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = POST_SHADER
	material.set_shader_parameter("tape_signal", true)
	# With the auto-iris as the main level control, this modest fixed boost keeps
	# dark rooms readable without double-exposing bright interiors.
	material.set_shader_parameter("bright_boost", 1.38)
	material.set_shader_parameter("resolution", signal_resolution)
	material.set_shader_parameter("noise_level", 0.026)
	material.set_shader_parameter("interference_amount", 0.035)
	material.set_shader_parameter("aberation_amount", 0.10)
	material.set_shader_parameter("jitter_amount", 0.035)
	material.set_shader_parameter("wobble_amount", 0.07)
	material.set_shader_parameter("tear_amount", 0.12)
	material.set_shader_parameter("ghost_amount", 0.16)
	material.set_shader_parameter("flicker_amount", 0.12)
	material.set_shader_parameter("saturation", 0.86)
	material.set_shader_parameter("contrast", 1.0)
	material.set_shader_parameter("black_crush", 0.002)
	material.set_shader_parameter("head_switch_amount", 0.38)
	material.set_shader_parameter("dropout_amount", 0.12)
	material.set_shader_parameter("dv_blur", 0.7)
	material.set_shader_parameter("dv_chroma_blur", 0.86)
	material.set_shader_parameter("highlight_rolloff", 1.0)
	material.set_shader_parameter("highlight_knee", 0.78)
	material.set_shader_parameter("auto_exposure", 0.85)
	material.set_shader_parameter("ae_target", 0.21)
	material.set_shader_parameter("signal_fps", 29.97)
	material.set_shader_parameter("chroma_delay", 1.3)
	material.set_shader_parameter("black_lift", 0.007)
	material.set_shader_parameter("field_amount", 0.35)
	material.set_shader_parameter("line_noise", 0.006)
	material.set_shader_parameter("chroma_noise", 0.45)
	material.set_shader_parameter("color_balance", Vector3(1.015, 1.0, 0.985))
	return material


## Extra wear belongs to the player's live feed. In-world recordings retain
## the existing factory preset and never receive these extra disturbances.
static func make_live_found_footage_material() -> ShaderMaterial:
	var material := make_found_footage_material()
	material.set_shader_parameter("noise_level", 0.038)
	material.set_shader_parameter("line_noise", 0.009)
	material.set_shader_parameter("dropout_amount", 0.22)
	material.set_shader_parameter("head_switch_amount", 0.5)
	material.set_shader_parameter("tape_speckle", 0.22)
	# Colour trails the brightness edge, with a gentle mismatch between its
	# two components. The shader lets existing corruption/presence widen it.
	material.set_shader_parameter("chroma_delay", 2.4)
	material.set_shader_parameter("chroma_misalignment", 0.65)
	material.set_shader_parameter("rgb_split_px", 2.0)
	return material


## Second pass: copy the decoded tape signal before reconstructing the tube.
## Both gameplay and in-world recordings use the same ordered pair of passes.
static func add_crt_display_pass(parent: Node,
		signal_resolution := FOUND_FOOTAGE_RESOLUTION) -> Control:
	var display := Control.new()
	display.name = "CRTDisplayPass"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var copy := BackBufferCopy.new()
	copy.name = "TapeSignalCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	display.add_child(copy)
	var face := ColorRect.new()
	face.name = "Display"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = CRT_DISPLAY_SHADER
	material.set_shader_parameter("signal_resolution", signal_resolution)
	face.material = material
	display.add_child(face)
	parent.add_child(display)
	return display


func setup(host: Node, found_footage := false, enabled := true) -> void:
	_mode = Mode.FOUND_FOOTAGE if found_footage else Mode.CRT
	_enabled = enabled
	var layer := CanvasLayer.new()
	# Above every UI layer (HUD 2, title 3): the tube is the last thing the
	# signal passes through, so the OSD and menus are part of the recording.
	layer.layer = 100
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Shared presentation shader, with a separate analog signal path for tape.
	# The clean CRT retains its original beam and raster response.
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = POST_SHADER
	_crt_material.set_shader_parameter("bright_boost", 1.4)
	_found_footage_material = make_live_found_footage_material()
	_overlay.material = _material_for_mode()
	_overlay.visible = _enabled and not _tape_hold
	layer.add_child(_overlay)
	_tube_display = add_crt_display_pass(layer)
	host.add_child(layer)
	_sync_visible()
	_schedule_glitches(Time.get_ticks_msec() * 0.001)
	_apply_found_footage_state()


func is_enabled() -> bool:
	return _enabled


func set_enabled(value: bool) -> void:
	_enabled = value
	_sync_visible()


func set_tape_playback(on: bool) -> void:
	_tape_hold = on
	_sync_visible()


func _sync_visible() -> void:
	if _overlay != null:
		_overlay.visible = _enabled and not _tape_hold
	if _tube_display != null:
		_tube_display.visible = _enabled and not _tape_hold and _mode == Mode.FOUND_FOOTAGE


func toggle_enabled() -> bool:
	set_enabled(not _enabled)
	return _enabled


func toggle_mode() -> String:
	if _overlay == null or _crt_material == null \
			or _found_footage_material == null:
		return mode_label()
	_mode = Mode.FOUND_FOOTAGE if _mode == Mode.CRT else Mode.CRT
	_overlay.material = _material_for_mode()
	_sync_visible()
	if _mode == Mode.FOUND_FOOTAGE:
		_schedule_glitches(Time.get_ticks_msec() * 0.001)
		_apply_found_footage_state()
	return mode_label()


func is_found_footage() -> bool:
	return _mode == Mode.FOUND_FOOTAGE


func mode_label() -> String:
	return "RECOVERED TAPE" if _mode == Mode.FOUND_FOOTAGE else "CRT"


func set_noise(value: float) -> void:
	for material in [_crt_material, _found_footage_material]:
		if material != null:
			material.set_shader_parameter("noise_amount", value)


func pulse_noise(high: float, baseline: float, duration: float) -> void:
	set_noise(high)
	var tween := create_tween()
	tween.tween_method(set_noise, high, baseline, duration)


func set_corruption(amount: float) -> void:
	_signal_corruption = clampf(amount, 0.0, 1.0)
	set_noise(1.0 + _signal_corruption * 1.6)
	_apply_found_footage_state()


## Screen-space interference halo around the nearest visible figure. Fed
## every frame from main. Found-footage mode only: the owner cut it from the
## CRT mode on sight (2026-08-16) — the clean tube stays clean.
func set_entity_halo(pos: Vector2, radius: float, amount: float) -> void:
	if _found_footage_material == null:
		return
	_found_footage_material.set_shader_parameter("entity_pos", pos)
	_found_footage_material.set_shader_parameter("entity_radius", radius)
	_found_footage_material.set_shader_parameter("entity_amt",
		clampf(amount, 0.0, 1.0))


## The diegetic danger indicator: how near the nearest hostile figure is,
## 0 (none within range) to 1 (at arm's length), visible or not.
func set_presence(amount: float) -> void:
	_presence_target = clampf(amount, 0.0, 1.0)


## A figure just entered the world: two or three frames of catastrophic
## loss, then whatever presence says.
func glitch_burst() -> void:
	_burst_until = Time.get_ticks_msec() * 0.001 + BURST_SECONDS
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
	if _burst_until > 0.0 and now >= _burst_until:
		_burst_until = 0.0
		changed = true
	if _presence != _presence_target:
		var dt := get_process_delta_time()
		var rate := PRESENCE_ATTACK if _presence_target > _presence \
			else PRESENCE_RELEASE
		_presence = move_toward(_presence, _presence_target, rate * dt)
		changed = true
	if _glitch_active and now >= _glitch_until:
		_glitch_active = false
		changed = true
	if _glitch_active:
		changed = true
	if _mode == Mode.FOUND_FOOTAGE and _enabled and not _tape_hold:
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
	# More event variety and tape wear in the live feed, with quiet intervals
	# between faults so the underlying CRT image remains readable.
	_minor_at = now + randf_range(5.0, 11.0)
	_major_at = now + randf_range(28.0, 55.0)
	_glitch_active = false


func _start_glitch(major: bool, now: float) -> void:
	_glitch_active = true
	_glitch_major = major
	_glitch_started = now
	_glitch_kind = randi_range(0, GlitchKind.SYNC_SLIP) as GlitchKind
	_glitch_origin = randf_range(0.15, 0.82)
	_glitch_strength = randf_range(0.65, 0.9) if major else randf_range(0.24, 0.48)
	_glitch_until = now + (randf_range(0.18, 0.45) if major else randf_range(0.08, 0.20))
	if major:
		_major_at = now + randf_range(28.0, 55.0)
	# A major event also buys a quiet interval instead of immediately releasing
	# an overdue minor glitch. Keep the colour fringe continuous between events.
	_minor_at = now + randf_range(5.0, 11.0)
	_apply_found_footage_state()


## Short attack, decaying recovery: tape transport settles after a disturbance.
## Kept pure so deterministic QA can exercise attack/recovery without waiting.
static func glitch_envelope(progress: float) -> float:
	return smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.25, 1.0, progress))


func _apply_found_footage_state() -> void:
	if _found_footage_material == null:
		return
	var interference := lerpf(0.035, 0.32, _signal_corruption)
	var noise := lerpf(0.038, 0.085, _signal_corruption)
	var aberration := lerpf(0.10, 0.65, _signal_corruption)
	var jitter := lerpf(0.035, 0.28, _signal_corruption)
	var wobble := lerpf(0.07, 0.4, _signal_corruption)
	var tear := lerpf(0.12, 0.5, _signal_corruption)
	var dropout := lerpf(0.22, 0.7, _signal_corruption)
	var saturation := lerpf(0.86, 0.62, _signal_corruption)
	var flicker := 0.12
	var loss := 0.0
	var tracking := 0.0
	var tracking_pos := 0.6
	var color_loss := 0.0
	var slip := 0.0
	var rf_static := 0.0
	var sync := 0.0
	var speckle := lerpf(0.22, 0.65, _signal_corruption)
	# Preserve the diegetic threat cue while keeping silhouettes readable.
	if _presence > 0.0:
		var near := clampf(_presence / 0.6, 0.0, 1.0)
		var very := clampf((_presence - 0.6) / 0.4, 0.0, 1.0)
		aberration = maxf(aberration, lerpf(aberration, 0.45, near))
		wobble = maxf(wobble, lerpf(wobble, 0.3, near))
		interference = maxf(interference, lerpf(interference, 0.25, near))
		flicker = lerpf(0.12, 0.65, near)
		tear = maxf(tear, lerpf(tear, 0.4, very))
		noise = maxf(noise, lerpf(noise, 0.045, very))
		loss = very * 0.12
	if _glitch_active:
		var now := Time.get_ticks_msec() * 0.001
		var phase := clampf((now - _glitch_started)
			/ maxf(_glitch_until - _glitch_started, 0.001), 0.0, 1.0)
		var strength := glitch_envelope(phase) * _glitch_strength
		tracking_pos = clampf(_glitch_origin + phase * 0.14, 0.0, 1.0)
		match _glitch_kind:
			GlitchKind.TRACKING:
				tracking = strength
				tracking_pos = clampf(_glitch_origin + phase * 0.14, 0.0, 1.0)
				if _glitch_major:
					slip = sin(phase * TAU) * strength * 0.65
			GlitchKind.COLOR_UNLOCK:
				color_loss = strength
				aberration += strength * 0.3
			GlitchKind.DROPOUT:
				dropout = maxf(dropout, strength)
				tracking = strength * 0.25
				tracking_pos = _glitch_origin
				speckle = maxf(speckle, strength)
			GlitchKind.RF_STATIC:
				rf_static = strength
				color_loss = strength * 0.4
				speckle = maxf(speckle, strength)
			GlitchKind.SYNC_SLIP:
				sync = strength
				slip = sin(phase * TAU * 1.5) * strength
				tracking = strength * 0.45
				rf_static = strength * 0.35
	if _burst_until > 0.0:
		tracking = 1.0
		tracking_pos = 0.5
		jitter = 0.8
		noise = 0.12
		color_loss = 0.7
		loss = 0.85
	if _damage_intensity > 0.0:
		tracking = maxf(tracking, 0.65 * _damage_intensity)
		noise = maxf(noise, lerpf(0.05, 0.10, _damage_intensity))
		jitter = maxf(jitter, 0.5)
		wobble = maxf(wobble, 0.5)
	_found_footage_material.set_shader_parameter("interference_amount", interference)
	_found_footage_material.set_shader_parameter("noise_level", noise)
	_found_footage_material.set_shader_parameter("aberation_amount", aberration)
	_found_footage_material.set_shader_parameter("jitter_amount", jitter)
	_found_footage_material.set_shader_parameter("wobble_amount", wobble)
	_found_footage_material.set_shader_parameter("tear_amount", tear)
	_found_footage_material.set_shader_parameter("dropout_amount", dropout)
	_found_footage_material.set_shader_parameter("saturation", saturation)
	_found_footage_material.set_shader_parameter("flicker_amount", flicker)
	_found_footage_material.set_shader_parameter("signal_loss", loss)
	_found_footage_material.set_shader_parameter("tracking_error", tracking)
	_found_footage_material.set_shader_parameter("tracking_y", tracking_pos)
	_found_footage_material.set_shader_parameter("chroma_loss", color_loss)
	_found_footage_material.set_shader_parameter("vertical_slip", slip)
	_found_footage_material.set_shader_parameter("rf_noise", rf_static)
	_found_footage_material.set_shader_parameter("sync_error", sync)
	_found_footage_material.set_shader_parameter("tape_speckle", speckle)
