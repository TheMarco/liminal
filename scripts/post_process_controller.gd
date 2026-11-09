class_name PostProcessController
extends Node
## Owns two independent presentation stages and transient VHS damage/glitches.
## The VHS stage degrades the recorded signal; the optional CRT stage displays
## that result (or the clean game image) on an emulated tube.

enum GlitchKind { TRACKING, COLOR_UNLOCK, DROPOUT, RF_STATIC, SYNC_SLIP }

var _overlay: ColorRect
var _scene_copy: BackBufferCopy
var _tube_display: Control
var _found_footage_material: ShaderMaterial
var _grain_copy: BackBufferCopy
var _grain_overlay: ColorRect
var _grain_intensity := 0.0
var _color_adjusted := false
var _vhs_enabled := true
var _crt_enabled := true
var _crt_curvature_enabled := false
var _video_pipeline := 0
var _experimental: Control
var _experiment_settings: Dictionary = {}
var _video_host: Control
var _noise_multiplier := 1.0
var _entity_position := Vector2(0.5, 0.5)
var _entity_radius := 0.0
var _entity_amount := 0.0
## Visual captures and transition tests sometimes need to suppress the complete
## presentation temporarily. This gate never changes either saved preference.
var _presentation_enabled := true
## Ritual playback requires a processed signal even when normal gameplay VHS
## is disabled. The active pipeline still owns the final scene/HUD processing.
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
var _glitch_encounter := false
var _glitch_sequence := ""
var _encounter_left := 0.0
var _encounter_duration := 0.0
var _damage_intensity := 0.0
## Nearness of the closest hostile figure, seen or not, 0..1. Fast attack,
## slow release: the footage breaks before the cause is in frame and takes
## seconds to settle after it is gone. Drives the tape material only — the
## owner keeps the clean tube clean.
var _presence := 0.0
var _presence_target := 0.0
var _burst_until := 0.0

const _COMFORT_META := "_comfort_raw_uniforms"
const _COMFORT_FIELDS := [
	"noise_level", "noise_amount", "interference_amount", "aberation_amount",
	"jitter_amount", "wobble_amount", "tear_amount", "ghost_amount",
	"flicker_amount", "head_switch_amount", "dropout_amount", "entity_amt",
	"field_amount", "line_noise", "chroma_noise", "chroma_delay",
	"chroma_misalignment", "rgb_split_px", "signal_loss", "tracking_error",
	"chroma_loss", "vertical_slip", "rf_noise", "sync_error", "tape_speckle",
	"roll_line_amount"
]
const _REDUCED_FIELDS := [
	"flicker_amount", "signal_loss", "rf_noise", "dropout_amount",
	"tracking_error", "vertical_slip", "sync_error", "head_switch_amount",
	"field_amount"
]
static var _comfort_materials: Array[WeakRef] = []

const PRESENCE_ATTACK := 4.0    # per second toward a higher target
const PRESENCE_RELEASE := 0.35  # per second toward a lower target
const BURST_SECONDS := 0.11     # ~2-3 frames of catastrophic loss
const POST_SHADER := preload("res://shaders/post.gdshader")
const CRT_DISPLAY_SHADER := preload("res://shaders/crt_display.gdshader")
const FILM_GRAIN_SHADER := preload("res://shaders/film_grain.gdshader")
const FOUND_FOOTAGE_RESOLUTION := Vector2(720.0, 480.0)
## 240 visible rows at the ritual TV's physical tube aspect.
const TV_TAPE_RESOLUTION := Vector2(344.0, 240.0)
## The recording passes' CanvasLayer. Everything drawn below it in the game
## frame is recorded; the Descent intro's movie draws at this layer, earlier.
const RECORDING_LAYER := 3


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
	material.set_shader_parameter("noise_level", 0.016)
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
	_register_comfort_material(material)
	return material


## Extra wear belongs to the player's live feed. In-world recordings retain
## the existing factory preset and never receive these extra disturbances.
static func make_live_found_footage_material() -> ShaderMaterial:
	var material := make_found_footage_material()
	_set_signal(material, "noise_level", 0.020)
	_set_signal(material, "line_noise", 0.005)
	_set_signal(material, "dropout_amount", 0.22)
	_set_signal(material, "head_switch_amount", 0.5)
	_set_signal(material, "tape_speckle", 0.12)
	# Colour trails the brightness edge, with a gentle mismatch between its
	# two components. The shader lets existing corruption/presence widen it.
	_set_signal(material, "chroma_delay", 2.4)
	_set_signal(material, "chroma_misalignment", 0.65)
	_set_signal(material, "rgb_split_px", 2.0)
	return material


static func _comfort_state() -> Dictionary:
	var strength := 0.5
	var reduced := false
	if GameSettings.current != null:
		strength = clampf(float(GameSettings.current.values.get("vhs_distortion", 0.5)), 0.0, 1.0)
		reduced = bool(GameSettings.current.values.get("reduced_flashing", false))
	return {"strength": strength, "reduced": reduced}


static func _scaled_signal(key: String, value: float) -> float:
	var state := _comfort_state()
	var result := value * float(state.strength)
	if key == "noise_level" or key == "noise_amount" or key == "tape_speckle":
		result = minf(result, value * (0.2 if state.reduced else 1.0))
	if state.reduced and key in _REDUCED_FIELDS:
		result = 0.0
	return result


static func _register_comfort_material(material: ShaderMaterial) -> void:
	var raw := {}
	for key in _COMFORT_FIELDS:
		var value = material.get_shader_parameter(key)
		if value != null and (value is float or value is int):
			raw[key] = float(value)
	material.set_meta(_COMFORT_META, raw)
	_comfort_materials.append(weakref(material))
	_apply_comfort_material(material, raw)


static func _apply_comfort_material(material: ShaderMaterial, raw: Dictionary) -> void:
	for key in raw:
		material.set_shader_parameter(key, _scaled_signal(key, float(raw[key])))


static func _set_signal(material: ShaderMaterial, key: String, value: float) -> void:
	if material == null:
		return
	var raw: Dictionary = material.get_meta(_COMFORT_META, {})
	raw[key] = value
	material.set_meta(_COMFORT_META, raw)
	material.set_shader_parameter(key, _scaled_signal(key, value))


static func refresh_comfort() -> void:
	var alive: Array[WeakRef] = []
	for reference in _comfort_materials:
		var material = reference.get_ref()
		if material != null and is_instance_valid(material):
			alive.append(reference)
			_apply_comfort_material(material, material.get_meta(_COMFORT_META, {}))
	_comfort_materials = alive


## Second pass: copy the decoded tape signal before reconstructing the tube.
## Final full-screen display pass; decoded TV footage must not add its own copy.
static func add_crt_display_pass(parent: Node,
		signal_resolution := FOUND_FOOTAGE_RESOLUTION,
		curvature_enabled := true) -> Control:
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
	material.set_shader_parameter("curvature_enabled", curvature_enabled)
	face.material = material
	display.add_child(face)
	parent.add_child(display)
	return display


func setup(host: Node, vhs_enabled := true, crt_enabled := true,
		curvature_enabled := false) -> void:
	_vhs_enabled = vhs_enabled
	_crt_enabled = crt_enabled
	_crt_curvature_enabled = curvature_enabled
	_video_host = host.get_meta("ntscrt_video_host") if host.has_meta("ntscrt_video_host") else null
	var layer := CanvasLayer.new()
	# Record the world and gameplay HUD (layer 2), but keep modal screens
	# (layers 4+) crisp even on the direct-render compatibility path.
	layer.layer = RECORDING_LAYER
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# VHS is the signal stage. CRT is a separate display stage below, so either
	# one can be enabled without silently enabling the other.
	_found_footage_material = make_live_found_footage_material()
	_overlay.material = _found_footage_material
	layer.add_child(_overlay)
	# Grain belongs to the recorded image. The optional CRT displays that
	# image afterward, softening its fine texture like the rest of the signal.
	# Its own screen copy keeps it available when VHS is off.
	_grain_copy = BackBufferCopy.new()
	_grain_copy.name = "FilmGrainCopy"
	_grain_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(_grain_copy)
	_grain_overlay = ColorRect.new()
	_grain_overlay.name = "FilmGrain"
	_grain_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grain_material := ShaderMaterial.new()
	grain_material.shader = FILM_GRAIN_SHADER
	_grain_overlay.material = grain_material
	layer.add_child(_grain_overlay)
	_tube_display = add_crt_display_pass(layer, FOUND_FOOTAGE_RESOLUTION,
		_crt_curvature_enabled)
	host.add_child(layer)
	_sync_visible()
	_schedule_glitches(Time.get_ticks_msec() * 0.001)
	_apply_found_footage_state()


## Refresh the world and HUD after perception effects, before recording passes.
## Installed by Main for perception beats, including normal non-debug gameplay.
func ensure_scene_copy() -> void:
	if _scene_copy != null:
		return
	_scene_copy = BackBufferCopy.new()
	_scene_copy.name = "WorldAndHudCopy"
	_scene_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_overlay.get_parent().add_child(_scene_copy)
	_overlay.get_parent().move_child(_scene_copy, 0)
	_sync_visible()


func is_vhs_enabled() -> bool:
	return _vhs_enabled


func is_crt_enabled() -> bool:
	return _crt_enabled


func is_curvature_enabled() -> bool:
	return _crt_curvature_enabled


func set_curvature_enabled(enabled: bool) -> void:
	_crt_curvature_enabled = enabled
	if _tube_display != null:
		var face := _tube_display.get_node("Display") as ColorRect
		(face.material as ShaderMaterial).set_shader_parameter("curvature_enabled", enabled)
	_sync_experimental()


## Select an independent implementation of the same signal/display choices.
## Built lazily, so Classic never allocates the experimental atlas/controller.
func set_video_pipeline(mode: int, settings: Dictionary) -> void:
	_video_pipeline = clampi(mode, 0, 2)
	_experiment_settings = settings.duplicate()
	var saturation := float(settings.get("video_color_saturation",1.0))
	var temperature := float(settings.get("video_color_temperature",0.0))
	var shadow_lift := float(settings.get("video_color_shadow_lift",0.0))
	_color_adjusted = not is_equal_approx(saturation,1.0) or not is_zero_approx(temperature) or shadow_lift>0.0
	if _grain_overlay!=null:
		var material := _grain_overlay.material as ShaderMaterial
		material.set_shader_parameter("color_saturation",saturation)
		material.set_shader_parameter("color_temperature",temperature)
		material.set_shader_parameter("color_shadow_lift",shadow_lift)
		material.set_shader_parameter("linear_source",_grain_overlay.get_viewport().use_hdr_2d)
	if _video_pipeline == 1 and _experimental == null and _overlay != null:
		_experimental = preload("res://scripts/ntscrt_pipeline.gd").new()
		_experimental.visible = false
		_overlay.get_parent().add_child(_experimental)
	_sync_visible()


func _sync_experimental() -> void:
	if _experimental == null:
		return
	_experimental.configure(_experiment_settings, _vhs_enabled or _tape_hold,
		_crt_enabled and not _tube_in_host(), _crt_curvature_enabled)
	_experimental.visible = _video_pipeline == 1 and _presentation_enabled \
		and (_vhs_enabled or _tape_hold or (_crt_enabled and not _tube_in_host()))


func set_effects(vhs_enabled: bool, crt_enabled: bool) -> void:
	_vhs_enabled = vhs_enabled
	_crt_enabled = crt_enabled
	_sync_visible()


func set_film_grain_intensity(value: float) -> void:
	_grain_intensity = clampf(value, 0.0, 1.0)
	if _grain_overlay != null:
		(_grain_overlay.material as ShaderMaterial).set_shader_parameter(
			"intensity", _grain_intensity)
	_sync_visible()


## Compatibility gate for capture tools and cinematic transitions. Player-facing
## code must use set_effects() so VHS and CRT remain independently configurable.
func set_enabled(enabled: bool) -> void:
	_presentation_enabled = enabled
	_sync_visible()


func is_enabled() -> bool:
	return _presentation_enabled and (_vhs_enabled or _crt_enabled or _tape_hold
		or _grain_intensity > 0.0 or _color_adjusted or bool(_experiment_settings.get("receiver_enabled",false)))


func set_tape_playback(on: bool) -> void:
	# A ritual recording remains a VHS signal even when the ordinary gameplay
	# effect is disabled. CRT remains the player's independent display choice.
	_tape_hold = on
	_sync_visible()


func _sync_visible() -> void:
	var show_vhs := _presentation_enabled and (_vhs_enabled or _tape_hold)
	var show_crt := _presentation_enabled and _crt_enabled
	var show_grain := _presentation_enabled and (_grain_intensity > 0.0 or _color_adjusted)
	if _scene_copy != null:
		_scene_copy.visible = (show_vhs or show_crt) and _video_pipeline == 0
	if _overlay != null:
		_overlay.visible = show_vhs and _video_pipeline == 0
	if _tube_display != null:
		_tube_display.visible = show_crt and _video_pipeline != 1 and not _tube_in_host()
	if _grain_copy != null:
		_grain_copy.visible = show_grain
	if _grain_overlay != null:
		_grain_overlay.visible = show_grain
	_sync_experimental()
	if _video_host != null:
		_video_host.configure_video(_experiment_settings,_video_pipeline,show_vhs,show_crt,_presentation_enabled,_crt_curvature_enabled)

func _using_slang() -> bool:
	return is_instance_valid(_video_host) and _presentation_enabled and _crt_enabled and GraphicsQuality.crt_model(_experiment_settings) in range(1,8)

func _gpu_signal_needed() -> bool:
	return is_instance_valid(_video_host) and _presentation_enabled and ((_video_pipeline == 2 and (_vhs_enabled or _tape_hold)) or bool(_experiment_settings.get("receiver_enabled",false)))

func _tube_in_host() -> bool:
	return _using_slang() or _gpu_signal_needed() or (is_instance_valid(_video_host) and _crt_enabled and int(_experiment_settings.get("crt_shader",0)) == 8)


func set_noise(value: float) -> void:
	_noise_multiplier = value
	if _found_footage_material != null:
		_set_signal(_found_footage_material, "noise_amount", value)


func pulse_noise(high: float, baseline: float, duration: float) -> void:
	set_noise(high)
	var tween := create_tween()
	tween.tween_method(set_noise, high, baseline, duration)


func set_corruption(amount: float) -> void:
	_signal_corruption = clampf(amount, 0.0, 1.0)
	set_noise(1.0 + _signal_corruption * 1.6)
	_apply_found_footage_state()


## Screen-space interference halo around the nearest visible figure. Fed
## every frame from main. VHS stage only: CRT-only output stays clean.
func set_entity_halo(pos: Vector2, radius: float, amount: float) -> void:
	_entity_position = pos
	_entity_radius = radius
	_entity_amount = clampf(amount, 0.0, 1.0)
	if _found_footage_material == null:
		return
	_found_footage_material.set_shader_parameter("entity_pos", pos)
	_found_footage_material.set_shader_parameter("entity_radius", radius)
	_set_signal(_found_footage_material, "entity_amt", clampf(amount, 0.0, 1.0))


## The diegetic danger indicator: how near the nearest hostile figure is,
## 0 (none within range) to 1 (at arm's length), visible or not.
func set_presence(amount: float) -> void:
	_presence_target = clampf(amount, 0.0, 1.0)


## A figure just entered the world: two or three frames of catastrophic
## loss, then whatever presence says.
func glitch_burst() -> void:
	_burst_until = Time.get_ticks_msec() * 0.001 + BURST_SECONDS
	_apply_found_footage_state()


## A short tracking/sync failure leads the hostile's visible manifestation.
func enemy_appearance_warning(seconds: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_start_glitch(true, now)
	_glitch_encounter = true
	_glitch_sequence = "glitch_pop" if _video_pipeline == 2 else ""
	_glitch_kind = GlitchKind.TRACKING if randf() < 0.5 else GlitchKind.SYNC_SLIP
	_glitch_strength = 1.0
	_encounter_duration = maxf(seconds, 0.1) + 0.08
	_encounter_left = _encounter_duration
	_glitch_until = now + _encounter_duration
	_apply_found_footage_state()


func _video_fault(now: float) -> Dictionary:
	if not (_vhs_enabled or _tape_hold): return {}
	if now < _burst_until:
		return {"kind":GlitchKind.SYNC_SLIP,"amount":1.0,"phase":0.2,"origin":0.5}
	if not _glitch_active or (not _glitch_encounter and not bool(_experiment_settings.get("ntsc_auto_faults",true))): return {}
	var phase := clampf((now-_glitch_started)/maxf(0.001,_glitch_until-_glitch_started),0.0,1.0)
	return {"kind":_glitch_kind,"amount":_glitch_strength*glitch_envelope(phase),"phase":phase,"origin":_glitch_origin,
		"sequence":_glitch_sequence,"sequence_strength":_glitch_strength if phase<1.0 else 0.0}


func damage_hit(intensity := 1.0) -> void:
	_damage_intensity = clampf(intensity, 0.0, 1.0)
	_damage_until = Time.get_ticks_msec() * 0.001 + 0.15
	_apply_found_footage_state()


func update() -> void:
	if _found_footage_material == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	if _glitch_active and (_glitch_encounter or not _glitch_sequence.is_empty()):
		# Authored cues follow gameplay time: pause holds both the animation
		# and the hostile's manifestation delay.
		_glitch_started = now - (_encounter_duration - _encounter_left)
		_glitch_until = now + _encounter_left
		_encounter_left = maxf(0.0, _encounter_left - get_process_delta_time())
	var fault := _video_fault(now)
	if _experimental != null and _video_pipeline == 1:
		_experimental.set_game_state(maxf(_signal_corruption,float(fault.get("amount",0.0))), _presence, _damage_intensity,
			now < _burst_until, _noise_multiplier, _entity_position, _entity_radius, _entity_amount)
	if _video_host != null and _gpu_signal_needed():
		var stress := clampf(maxf(maxf(_signal_corruption*0.6,_presence*0.7),maxf(_damage_intensity,1.0 if now < _burst_until else 0.0)),0.0,1.0)
		_video_host.set_game_state(stress,_entity_position,_entity_radius,_entity_amount,fault)
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
	if _vhs_enabled or _tape_hold:
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


func _schedule_glitches(now: float) -> void:
	# More event variety and tape wear in the live feed, with quiet intervals
	# between faults so the underlying CRT image remains readable.
	_minor_at = now + randf_range(5.0, 11.0)
	_major_at = now + randf_range(28.0, 55.0)
	_glitch_active = false


func _start_glitch(major: bool, now: float) -> void:
	_glitch_active = true
	_glitch_encounter = false
	_glitch_sequence = "two_blips" if major and _video_pipeline == 2 else ""
	_glitch_major = major
	_glitch_started = now
	_glitch_kind = randi_range(0, GlitchKind.SYNC_SLIP) as GlitchKind
	_glitch_origin = randf_range(0.15, 0.82)
	_glitch_strength = randf_range(0.65, 0.9) if major else randf_range(0.24, 0.48)
	_glitch_until = now + (randf_range(0.18, 0.45) if major else randf_range(0.08, 0.20))
	if not _glitch_sequence.is_empty():
		_encounter_duration = 1.1
		_encounter_left = _encounter_duration
		_glitch_until = now + _encounter_duration
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
	var noise := lerpf(0.020, 0.065, _signal_corruption)
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
	var speckle := lerpf(0.12, 0.50, _signal_corruption)
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
	_set_signal(_found_footage_material, "interference_amount", interference)
	_set_signal(_found_footage_material, "noise_level", noise)
	_set_signal(_found_footage_material, "aberation_amount", aberration)
	_set_signal(_found_footage_material, "jitter_amount", jitter)
	_set_signal(_found_footage_material, "wobble_amount", wobble)
	_set_signal(_found_footage_material, "tear_amount", tear)
	_set_signal(_found_footage_material, "dropout_amount", dropout)
	_found_footage_material.set_shader_parameter("saturation", saturation)
	_set_signal(_found_footage_material, "flicker_amount", flicker)
	_set_signal(_found_footage_material, "signal_loss", loss)
	_set_signal(_found_footage_material, "tracking_error", tracking)
	_found_footage_material.set_shader_parameter("tracking_y", tracking_pos)
	_set_signal(_found_footage_material, "chroma_loss", color_loss)
	_set_signal(_found_footage_material, "vertical_slip", slip)
	_set_signal(_found_footage_material, "rf_noise", rf_static)
	_set_signal(_found_footage_material, "sync_error", sync)
	_set_signal(_found_footage_material, "tape_speckle", speckle)
