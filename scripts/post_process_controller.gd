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
var _glitch_jitter := 0.006
var _glitch_tracking := 0.18
var _glitch_aberration := 0.0035
var _glitch_noise := 0.10
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
const FOUND_FOOTAGE_RESOLUTION := Vector2(640.0, 360.0)
## 240 visible rows at the ritual TV's physical tube aspect.
const TV_TAPE_RESOLUTION := Vector2(344.0, 240.0)


## One source of truth for recovered-footage rendering. Full-screen gameplay
## and the television's private video viewport both request this material, so
## tuning the tape look can no longer leave the two playback paths out of sync.
static func make_found_footage_material(
		signal_resolution := FOUND_FOOTAGE_RESOLUTION) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = POST_SHADER
	# With the auto-iris as the main level control, this modest fixed boost keeps
	# dark rooms readable without double-exposing bright interiors.
	material.set_shader_parameter("bright_boost", 1.38)
	material.set_shader_parameter("resolution", signal_resolution)
	material.set_shader_parameter("noise_level", 0.018)
	material.set_shader_parameter("interference_amount", 0.06)
	material.set_shader_parameter("aberation_amount", 0.12)
	material.set_shader_parameter("roll_line_amount", 0.08)
	material.set_shader_parameter("roll_speed", 2.0)
	material.set_shader_parameter("grille_amount", 0.03)
	material.set_shader_parameter("scan_line_strength", -8.0)
	material.set_shader_parameter("pixel_strength", -1.5)
	material.set_shader_parameter("warp_amount", 0.13)
	material.set_shader_parameter("vignette_amount", 0.6)
	material.set_shader_parameter("vignette_intensity", 0.5)
	material.set_shader_parameter("tube_edge_feather", 0.018)
	material.set_shader_parameter("jitter_amount", 0.05)
	material.set_shader_parameter("jitter_speed", 9.0)
	material.set_shader_parameter("wobble_amount", 0.06)
	material.set_shader_parameter("tear_amount", 0.05)
	material.set_shader_parameter("ghost_amount", 0.2)
	material.set_shader_parameter("flicker_amount", 0.15)
	material.set_shader_parameter("saturation", 0.78)
	material.set_shader_parameter("contrast", 1.0)
	material.set_shader_parameter("black_crush", 0.004)
	material.set_shader_parameter("head_switch_amount", 0.25)
	material.set_shader_parameter("dropout_amount", 0.1)
	material.set_shader_parameter("scan_line_amount", 1.0)
	material.set_shader_parameter("dv_blur", 0.5)
	material.set_shader_parameter("dv_chroma_blur", 0.8)
	material.set_shader_parameter("highlight_rolloff", 1.0)
	material.set_shader_parameter("highlight_knee", 0.78)
	material.set_shader_parameter("auto_exposure", 1.0)
	material.set_shader_parameter("ae_target", 0.21)
	material.set_shader_parameter("signal_fps", 29.97)
	material.set_shader_parameter("chroma_delay", 0.8)
	material.set_shader_parameter("overscan", 0.03)
	material.set_shader_parameter("black_lift", 0.01)
	material.set_shader_parameter("field_amount", 0.7)
	material.set_shader_parameter("line_noise", 0.012)
	material.set_shader_parameter("chroma_noise", 0.5)
	material.set_shader_parameter("bloom_amount", 0.35)
	material.set_shader_parameter("bloom_threshold", 0.72)
	material.set_shader_parameter("color_balance", Vector3(1.03, 1.0, 0.96))
	return material


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
	# One shader, two characters: the clean tube runs its defaults, the
	# recovered tape runs the same glass driven far past spec — coarser
	# grid, soft beam, heavy interference, wandering chroma, a tape-speed
	# roll. The gritty dials are the baseline the glitch machinery rides on.
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = POST_SHADER
	_crt_material.set_shader_parameter("bright_boost", 1.4)
	_found_footage_material = make_found_footage_material()
	_overlay.material = _material_for_mode()
	_overlay.visible = _enabled and not _tape_hold
	layer.add_child(_overlay)
	host.add_child(layer)
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
	# Glitches are EVENTS: at the old 1.5-5s minor cadence the picture never
	# sat still and the owner called it "way too much" (2026-08-19).
	_minor_at = now + randf_range(9.0, 22.0)
	_major_at = now + randf_range(45.0, 90.0)
	_glitch_active = false


func _start_glitch(major: bool, now: float) -> void:
	_glitch_active = true
	_glitch_major = major
	if major:
		_glitch_until = now + randf_range(0.12, 0.42)
		_glitch_jitter = randf_range(0.85, 1.0)
		_glitch_tracking = randf_range(0.6, 1.0)
		_glitch_noise = randf_range(0.16, 0.28)
		_glitch_aberration = randf_range(0.95, 1.0)
		_major_at = now + randf_range(45.0, 90.0)
	else:
		_glitch_until = now + randf_range(0.04, 0.16)
		_glitch_jitter = randf_range(0.4, 0.6)
		_glitch_aberration = randf_range(0.85, 0.95)
		_minor_at = now + randf_range(9.0, 22.0)
	_apply_found_footage_state()


## The tape's live state, in the shared shader's dials: interference for
## jitter, roll for tracking damage, noise_level for static, aberation for
## chroma splits. Corruption raises the resting grime; glitches spike it.
func _apply_found_footage_state() -> void:
	if _found_footage_material == null:
		return
	var interference := lerpf(0.06, 0.45, _signal_corruption)
	var roll := lerpf(0.08, 0.4, _signal_corruption)
	var noise := lerpf(0.018, 0.07, _signal_corruption)
	var aberration := lerpf(0.12, 0.7, _signal_corruption)
	var jitter := lerpf(0.05, 0.4, _signal_corruption)
	var wobble := lerpf(0.06, 0.45, _signal_corruption)
	var tear := lerpf(0.05, 0.4, _signal_corruption)
	var dropout := lerpf(0.1, 0.5, _signal_corruption)
	var saturation := lerpf(0.78, 0.55, _signal_corruption)
	var flicker := 0.15
	var loss := 0.0
	# Presence ladder. The tape WHISPERS danger — the player must still be
	# able to see the figure to survive the watched creep, so the ladder
	# tops out well short of obscuring (owner: "way too much", 2026-08-19).
	# Near (0..0.6): a little chroma and iris unrest. Very near (0.6..1):
	# some tracking unrest and a thin band of loss.
	if _presence > 0.0:
		var near := clampf(_presence / 0.6, 0.0, 1.0)
		var very := clampf((_presence - 0.6) / 0.4, 0.0, 1.0)
		aberration = maxf(aberration, lerpf(aberration, 0.45, near))
		wobble = maxf(wobble, lerpf(wobble, 0.3, near))
		interference = maxf(interference, lerpf(interference, 0.25, near))
		flicker = lerpf(0.15, 0.8, near)
		tear = maxf(tear, lerpf(tear, 0.4, very))
		jitter = maxf(jitter, lerpf(jitter, 0.35, very))
		noise = maxf(noise, lerpf(noise, 0.045, very))
		loss = very * 0.12
	if _burst_until > 0.0:
		interference = 1.0
		tear = 1.0
		jitter = 1.0
		noise = 0.2
		aberration = 1.0
		loss = 1.0
	if _glitch_active:
		interference = maxf(interference, _glitch_jitter)
		aberration = maxf(aberration, _glitch_aberration)
		jitter = 1.0
		if _glitch_major:
			roll = maxf(roll, _glitch_tracking)
			noise = maxf(noise, _glitch_noise)
			wobble = 1.0
			tear = 1.0
			dropout = 1.0
	if _damage_intensity > 0.0:
		aberration = 1.0
		noise = maxf(noise, lerpf(0.12, 0.26, _damage_intensity))
		jitter = 1.0
		wobble = 1.0
	_found_footage_material.set_shader_parameter(
		"interference_amount", interference)
	_found_footage_material.set_shader_parameter("roll_line_amount", roll)
	_found_footage_material.set_shader_parameter("noise_level", noise)
	_found_footage_material.set_shader_parameter(
		"aberation_amount", aberration)
	_found_footage_material.set_shader_parameter("jitter_amount", jitter)
	_found_footage_material.set_shader_parameter("wobble_amount", wobble)
	_found_footage_material.set_shader_parameter("tear_amount", tear)
	_found_footage_material.set_shader_parameter("dropout_amount", dropout)
	_found_footage_material.set_shader_parameter("saturation", saturation)
	_found_footage_material.set_shader_parameter("flicker_amount", flicker)
	_found_footage_material.set_shader_parameter("signal_loss", loss)
