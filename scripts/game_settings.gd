class_name GameSettings
extends RefCounted

signal changed
signal save_failed(error: Error)
signal saved

static var current: GameSettings

static func flashing_reduced() -> bool:
	return current != null and bool(current.values.get("reduced_flashing", false))

## The automatic CRT keeps dark rooms readable on both renderers.
const CRT_AUTOMATIC := 9
const CRT_CALIBRATION = preload("res://scripts/crt_calibration.gd")
const HOME_CRT_PARAMETERS := CRT_CALIBRATION.DEFAULTS

const DEFAULTS: Dictionary = {
	"language": "en",
	"quality_preset": 1,
	"render_resolution": 2,
	"anti_aliasing": 2,
	"shadow_quality": 1,
	"global_illumination": 1,
	"ambient_occlusion": 1,
	"reflections": 1,
	"volumetric_fog": 1,
	"frame_limit": 60,
	"vsync": true,
	"show_fps": false,
	"sensitivity": 1.0,
	"field_of_view": 77.0,
	"head_bob": 1.0,
	"handheld_camera": true,
	"handheld_strength": 0.55,
	"invert_y": false,
	"toggle_sprint": false,
	"fullscreen": false,
	"death_hints": true,
	"story_subtitles": false,
	"music_volume": 1.0,
	"effects_volume": 1.0,
	"dialogue_volume": 1.0,
	"vhs_distortion": 0.5,
	"film_grain": 0.4,
	"video_fault_rate": 0.0,
	"video_fault_strength": 0.5,
	"video_fault_kind": 2,
	"video_color_saturation": 1.0,
	"video_color_temperature": 0.0,
	"video_color_shadow_lift": 0.0,
	"reduced_flashing": false,
	"vhs_enabled": true,
	"crt_enabled": true,
	"crt_curvature": false,
	"hdr_enabled": true,
	"hdr_brightness": 1.0,
	"video_pipeline": 2,
	"video_quality_override": -1,
	"video_auto_resolution": true,
	"crt_shader": CRT_AUTOMATIC,
	"crt_shader_parameters": HOME_CRT_PARAMETERS,
	"ntscrs_settings": {},
	"receiver_settings": {},
	"receiver_enabled": false,
	"receiver_tape_coupling": true,
	"ntscrs_field_history": false,
	"ntscrs_source_resolution": false,
	"ntscrt_downscale_filter": 0,
	"ntscrt_signal_size": 0,
	"ntscrt_signal_width": 720.0,
	"ntscrt_scale_mode": 0,
	"ntsc_decoder": 1,
	"ntsc_tape_speed": 0,
	"ntsc_quality": 1,
	"ntsc_mask_type": 1,
	"ntsc_signal_strength": 1.0,
	"ntsc_tracking": 0.0,
	"ntsc_head_switch": 0.15,
	"ntsc_timebase_jitter": 0.12,
	"ntsc_crinkle": 0.05,
	"ntsc_head_clog": 0.0,
	"ntsc_dropouts": 0.08,
	"ntsc_ghost": 0.04,
	"ntsc_ghost_delay": 2.0,
	"ntsc_hum": 0.0,
	"ntsc_horizontal_hold": 0.0,
	"ntsc_vertical_hold": 0.0,
	"ntsc_afc": 0.5,
	"ntsc_search_speed": 1.0,
	"ntsc_chroma_noise": 0.12,
	"ntsc_chroma_delay": 1.3,
	"ntsc_chroma_bleed": 0.5,
	"ntsc_sharpness": 0.25,
	"ntsc_bloom": 0.18,
	"ntsc_mask_strength": 0.35,
	"ntsc_scanline_strength": 0.55,
	"ntsc_brightness": 1.0,
	"ntsc_saturation": 0.9,
	"ntsc_glass_diffusion": 0.08,
	"ntsc_convergence": 0.2,
	"ntsc_vignette": 0.18,
	"ntsc_auto_exposure": 0.35,
	"ntsc_rf_noise": 0.02,
	"ntsc_black_level": 0.0,
	"ntsc_caption_data": true,
	"ntsc_dropout_compensation": true,
	"ntsc_interlaced": true,
	"ntsc_auto_faults": true,
}

const BOOLEAN_KEYS := ["vsync", "show_fps", "invert_y", "toggle_sprint", "handheld_camera", "fullscreen",
	"reduced_flashing", "death_hints", "vhs_enabled", "crt_enabled", "crt_curvature",
	"hdr_enabled", "story_subtitles", "ntsc_dropout_compensation", "ntsc_interlaced",
	"ntsc_auto_faults", "ntsc_caption_data", "receiver_enabled", "ntscrs_field_history",
	"ntscrs_source_resolution", "video_auto_resolution", "receiver_tape_coupling"]

const RANGES: Dictionary = {
	"ntscrt_signal_width": Vector2(16.0,4096.0),
	"sensitivity": Vector2(0.2, 3.0),
	"field_of_view": Vector2(60.0, 100.0),
	"head_bob": Vector2(0.0, 1.0),
	"handheld_strength": Vector2(0.0, 1.0),
	"music_volume": Vector2(0.0, 1.0),
	"effects_volume": Vector2(0.0, 1.0),
	"dialogue_volume": Vector2(0.0, 1.0),
	"vhs_distortion": Vector2(0.0, 1.0),
	"film_grain": Vector2(0.0, 1.0),
	"video_fault_rate": Vector2(0.0,20.0),
	"video_fault_strength": Vector2(0.0,1.0),
	"video_color_saturation": Vector2(0.0, 1.5),
	"video_color_temperature": Vector2(-1.0, 1.0),
	"video_color_shadow_lift": Vector2(0.0, 0.12),
	"hdr_brightness": Vector2(0.60, 1.40),
	"ntsc_signal_strength": Vector2(0.0, 1.0),
	"ntsc_tracking": Vector2(0.0, 1.0),
	"ntsc_head_switch": Vector2(0.0, 1.0),
	"ntsc_timebase_jitter": Vector2(0.0, 1.0),
	"ntsc_crinkle": Vector2(0.0, 1.0),
	"ntsc_head_clog": Vector2(0.0, 1.0),
	"ntsc_dropouts": Vector2(0.0, 1.0),
	"ntsc_ghost": Vector2(-1.0, 1.0),
	"ntsc_ghost_delay": Vector2(0.2, 12.0),
	"ntsc_hum": Vector2(0.0, 1.0),
	"ntsc_black_level": Vector2(0.0, 1.0),
	"ntsc_horizontal_hold": Vector2(-1.0, 1.0),
	"ntsc_vertical_hold": Vector2(-1.0, 1.0),
	"ntsc_afc": Vector2(0.0, 1.0),
	"ntsc_search_speed": Vector2(1.0, 5.0),
	"ntsc_chroma_noise": Vector2(0.0, 1.0),
	"ntsc_chroma_delay": Vector2(-5.0, 8.0),
	"ntsc_chroma_bleed": Vector2(0.0, 1.0),
	"ntsc_sharpness": Vector2(0.0, 1.0),
	"ntsc_bloom": Vector2(0.0, 1.0),
	"ntsc_mask_strength": Vector2(0.0, 1.0),
	"ntsc_scanline_strength": Vector2(0.0, 1.0),
	"ntsc_brightness": Vector2(0.6, 1.4),
	"ntsc_saturation": Vector2(0.0, 1.5),
	"ntsc_glass_diffusion": Vector2(0.0, 1.0),
	"ntsc_convergence": Vector2(0.0, 1.0),
	"ntsc_vignette": Vector2(0.0, 1.0),
	"ntsc_auto_exposure": Vector2(0.0, 1.0),
	"ntsc_rf_noise": Vector2(0.0, 1.0),
}

const BINDINGS_SECTION := "bindings"

## Presets are applied in one transaction so live rendering never sees a
## partially selected mode. Presentation and comfort preferences are separate.
const QUALITY_KEYS := ["render_resolution", "anti_aliasing", "shadow_quality",
	"global_illumination", "ambient_occlusion", "reflections", "volumetric_fog"]
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra", "Custom"]
const QUALITY_PRESETS := [
	[1, 1, 0, 0, 0, 0, 0],
	[2, 2, 1, 1, 1, 1, 1],
	[3, 2, 2, 1, 2, 1, 1],
	[4, 2, 3, 2, 2, 2, 2],
]
const ENUM_VALUES := {
	"quality_preset": [0, 1, 2, 3, 4],
	"render_resolution": [0, 1, 2, 3, 4, 5],
	"anti_aliasing": [0, 1, 2, 3, 4, 5],
	"shadow_quality": [0, 1, 2, 3],
	"global_illumination": [0, 1, 2],
	"ambient_occlusion": [0, 1, 2],
	"reflections": [0, 1, 2],
	"volumetric_fog": [0, 1, 2],
	"frame_limit": [0, 30, 60, 90, 120, 144],
	"video_pipeline": [0, 1, 2],
	"video_quality_override": [-1, 0, 1, 2, 3],
	"video_fault_kind": [0,1,2,3,4],
	"crt_shader": [0, 1, 2, 3, 4, 5, 6, 7, 8, CRT_AUTOMATIC],
	"ntscrt_downscale_filter": [0,1,2,3,4,5,6],
	"ntscrt_signal_size": [0,1,2],
	"ntscrt_scale_mode": [0,1,2],
	"ntsc_decoder": [0, 1, 2],
	"ntsc_tape_speed": [0, 1, 2],
	"ntsc_quality": [0, 1],
	"ntsc_mask_type": [0, 1, 2],
}

var values: Dictionary = {}
var bindings: Dictionary = {}
var _path := "user://settings.cfg"

func _init(config_path: String = "user://settings.cfg") -> void:
	_path = config_path
	reset_defaults(false)
	values["language"] = Localization.normalize(OS.get_locale())
	if not load_from_disk():
		if values["language"] != "en": values["story_subtitles"] = true
		_apply_first_run_hardware_default()
	Localization.apply(str(values["language"]))

## A new player on integrated graphics should not start on the Medium budget
## (SDFGI, volumetric fog, SSR, SSAO). Only a profile that has never been saved
## is affected; Apple silicon reports "integrated" and keeps the authored default.
func _apply_first_run_hardware_default() -> void:
	if _path != "user://settings.cfg" or DisplayServer.get_name() == "headless" \
			or OS.get_name() == "macOS":
		return
	var adapter := RenderingServer.get_video_adapter_type()
	if adapter == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU \
			or adapter == RenderingDevice.DEVICE_TYPE_CPU:
		apply_quality_preset(0)


func load_from_disk() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load(_path)
	if err != OK:
		return false
	for key: String in DEFAULTS:
		if not config.has_section_key("settings", key):
			continue
		var raw: Variant = config.get_value("settings", key)
		if key == "language":
			if raw is String and raw in Localization.LOCALES: values[key] = raw
			continue
		if key in ["ntscrs_settings","receiver_settings"]:
			values[key] = FULL_SETTINGS.sanitize_ntsc(raw) if key == "ntscrs_settings" else FULL_SETTINGS.sanitize_receiver(raw)
			continue
		if key == "crt_shader_parameters":
			values[key] = _sanitize_crt_parameters(raw)
			continue
		if key in BOOLEAN_KEYS:
			if raw is bool:
				values[key] = raw
			continue
		if ENUM_VALUES.has(key):
			if raw is int and raw in ENUM_VALUES[key]:
				values[key] = raw
			continue
		if raw is float or raw is int:
			var number := float(raw)
			if is_finite(number):
				values[key] = _sanitize(key, number)
	_load_bindings(config)
	var stored_quality := int(values["quality_preset"])
	values["quality_preset"] = matching_quality_preset()
	# A revised preset table must not also change an older profile's tape/TV
	# budget when its unchanged rendering values are now classified as Custom.
	if values["quality_preset"] == 4 and stored_quality in range(4) \
			and int(values["video_quality_override"]) < 0:
		values["video_quality_override"] = stored_quality
	values["crt_shader_parameters"] = CRT_CALIBRATION.upgrade_saved(values["crt_shader_parameters"])
	_upgrade_worn_tape_look()
	_upgrade_home_video_look()
	# Existing profiles predate the language choice. Do not strand a new CJK
	# player with the old English-only caption default on their first launch.
	if not config.has_section_key("settings", "language") and values["language"] != "en":
		values["story_subtitles"] = true
	return true

func _load_bindings(config: ConfigFile) -> void:
	var merged := GameInput.default_bindings()
	for action in GameInput.ACTIONS:
		if not config.has_section_key(BINDINGS_SECTION, action):
			continue
		var raw: Variant = config.get_value(BINDINGS_SECTION, action)
		if raw is bool or not (raw is int):
			continue
		var code: Key = int(raw)
		if GameInput.key_error(code).is_empty():
			merged[action] = int(code)
	# Validate the whole saved map together: legitimate swaps/cycles must not
	# be rejected merely because a later action has not been read yet. Invalid
	# duplicate overrides fall back to defaults; repeat because that fallback
	# may reveal another conflict in a corrupt config.
	for _pass in GameInput.ACTIONS.size():
		var conflicts: Array[String] = []
		for action in GameInput.ACTIONS:
			if int(merged[action]) == int(GameInput.DEFAULTS[action]):
				continue
			for other in GameInput.ACTIONS:
				if other != action and int(merged[action]) == int(merged[other]):
					conflicts.append(action)
					break
		if conflicts.is_empty():
			break
		for action in conflicts:
			merged[action] = GameInput.DEFAULTS[action]
	bindings = merged

func save_to_disk() -> Error:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("settings", key, values.get(key, DEFAULTS[key]))
	for action in GameInput.ACTIONS:
		config.set_value(BINDINGS_SECTION, action,
			int(bindings.get(action, GameInput.DEFAULTS[action])))
	var error := preload("res://scripts/atomic_config.gd").save_config(config, _path)
	if error == OK:
		saved.emit()
	else:
		save_failed.emit(error)
	return error

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	if key == "quality_preset":
		if value is int:
			apply_quality_preset(value)
		return
	if key == "language":
		if not value is String or value not in Localization.LOCALES: return
		if values.get(key) == value: return
		values[key] = value
		if value != "en": values["story_subtitles"] = true
		Localization.apply(value)
		changed.emit()
		return
	var next: Variant = value
	if key in ["ntscrs_settings","receiver_settings"]:
		next = FULL_SETTINGS.sanitize_ntsc(value) if key == "ntscrs_settings" else FULL_SETTINGS.sanitize_receiver(value)
	elif key == "crt_shader_parameters":
		next = _sanitize_crt_parameters(value)
	elif key in BOOLEAN_KEYS:
		if not value is bool:
			return
	elif ENUM_VALUES.has(key):
		if not value is int or not value in ENUM_VALUES[key]:
			return
	else:
		if not (value is float or value is int):
			return
		var number := float(value)
		if not is_finite(number):
			return
		next = _sanitize(key, number)
	if values.get(key) == next:
		return
	var previous_quality := int(values["quality_preset"])
	values[key] = next
	if key in QUALITY_KEYS:
		values["quality_preset"] = matching_quality_preset()
		# Tweaking world resolution/shadows should not unexpectedly swap CRT
		# shaders or their processing budget. A new preset restores Automatic.
		if values["quality_preset"] == 4 and previous_quality in range(4) \
				and int(values["video_quality_override"]) < 0:
			values["video_quality_override"] = previous_quality
	changed.emit()

func apply_quality_preset(index: int) -> void:
	if index < 0 or index >= QUALITY_PRESETS.size():
		return
	var dirty := int(values.get("video_quality_override",-1))>=0
	values["video_quality_override"] = -1
	for i in QUALITY_KEYS.size():
		var key: String = QUALITY_KEYS[i]
		var next: int = QUALITY_PRESETS[index][i]
		dirty = dirty or values.get(key) != next
		values[key] = next
	values["quality_preset"] = index
	if dirty:
		changed.emit()

func matching_quality_preset() -> int:
	for index in QUALITY_PRESETS.size():
		var matches := true
		for i in QUALITY_KEYS.size():
			if values.get(QUALITY_KEYS[i]) != QUALITY_PRESETS[index][i]:
				matches = false
				break
		if matches:
			return index
	return 4

const VIDEO_LOOK_NAMES := ["Clean", "Home video", "Found footage", "Worn tape"]
const VIDEO_LOOK_CAPTIONS := ["No tape effects", "Tape on an old TV", "Subtle tape wear", "Heavy tape damage"]
const VIDEO_LOOK_NOTES := [
	"A clear picture with no tape damage or TV screen effects.",
	"A soft, grainy home movie with the screen lines and glow of an old television.",
	"Soft colour and subtle tape wear, like a recovered camcorder recording.",
	"A damaged recording with more wobble, streaks and colour noise.",
]
const TAPE_LOOK_NAMES := ["Off", "Home video", "Found footage", "Worn tape"]
const TAPE_LOOK_CAPTIONS := ["No tape effects", "Soft and grainy", "Subtle tape wear", "Heavy tape damage"]
const TAPE_LOOK_NOTES := [
	"A clear recording with no tape softness, grain or damage.",
	"A soft, grainy home movie with gentle tape wear.",
	"Soft colour and subtle wear, like a recovered camcorder recording.",
	"A damaged recording with more wobble, streaks and colour noise.",
]
const CRT_LOOK_KEYS := ["ntscrt_scale_mode", "ntsc_mask_type", "ntsc_bloom",
	"ntsc_mask_strength", "ntsc_scanline_strength", "ntsc_brightness",
	"ntsc_glass_diffusion", "ntsc_convergence", "ntsc_vignette"]
const VIDEO_ADJUSTMENTS := ["vhs_distortion"]
## Old presets allowed these independent adjustments. Preserve them when
## upgrading the costly receiver preset; current look matching is stricter.
const LEGACY_VIDEO_ADJUSTMENTS := ["vhs_distortion", "film_grain", "crt_enabled", "crt_curvature"]

## Historical complete recipes remain available for migrations and captures.
## Player selections use tape_look_values(), which leaves the CRT independent.
static func video_look_values(index: int) -> Dictionary:
	if index < 0 or index >= VIDEO_LOOK_NAMES.size():
		return {}
	var result: Dictionary = {}
	for key: String in DEFAULTS:
		if key.begins_with("ntsc") or key.begins_with("receiver_") \
				or key.begins_with("crt_") or key.begins_with("video_color_") or key.begins_with("video_fault_") or key in ["video_pipeline", "vhs_enabled", "vhs_distortion", "film_grain"]:
			result[key] = DEFAULTS[key]
	result["crt_shader_parameters"] = {}
	result["ntscrs_settings"] = FULL_SETTINGS.ntsc_defaults()
	result["receiver_settings"] = FULL_SETTINGS.receiver_defaults()
	match index:
		0:
			result.merge({"video_pipeline": 0, "crt_shader": 0, "vhs_enabled": false, "crt_enabled": false,
				"vhs_distortion": 0.0, "film_grain": 0.0}, true)
		1:
			result.merge({"video_pipeline": 2, "crt_enabled": true, "crt_shader": CRT_AUTOMATIC, "crt_curvature": false}, true)
			result["crt_shader_parameters"] = HOME_CRT_PARAMETERS.duplicate(true)
		2, 3:
			result.merge({"video_pipeline": 2, "crt_enabled": false, "crt_shader": 7,
				"vhs_distortion": 0.35, "film_grain": 0.12}, true)
			if index == 3:
				result.merge({"vhs_distortion": 0.65, "film_grain": 0.2}, true)
				# Reuse the GPU tape passes. Damaged receiver timing is expensive
				# CPU work and belongs in the opt-in developer video lab.
				result["ntscrs_settings"].merge({"vhs_edge_wave": 1.1,
					"tracking_noise_height": 24, "tracking_noise_wave_intensity": 20.0,
					"tracking_noise_noise_intensity": 0.35, "chroma_noise_intensity": 0.14,
					"vhs_chroma_loss": 0.00008, "snow_intensity": 0.0008}, true)
	return result

static func legacy_worn_tape_values() -> Dictionary:
	var result := video_look_values(2)
	result.merge({"receiver_enabled": true, "vhs_distortion": 0.65, "film_grain": 0.2}, true)
	result["receiver_settings"].merge({"timebase_jitter": 0.18,
		"crinkle": 0.08, "tracking": 0.08, "dropouts": 0.12}, true)
	return result

## Upgrade only the exact old preset, retaining its simple adjustments. Custom
## receiver configurations and every unrelated setting remain untouched.
func _upgrade_worn_tape_look() -> void:
	if not _matches_video_values(legacy_worn_tape_values(), {}, LEGACY_VIDEO_ADJUSTMENTS):
		return
	var look := video_look_values(3)
	for key: String in look:
		if key not in LEGACY_VIDEO_ADJUSTMENTS:
			values[key] = look[key]

## Replace only the exact former Home video setup. Deliberate shader/receiver
## edits stay custom, and the player's tape-damage adjustment survives.
static func legacy_home_video_values() -> Dictionary:
	var result := video_look_values(1)
	result["video_pipeline"] = 0
	result["crt_shader"] = 0
	result["crt_shader_parameters"] = {}
	return result

func _upgrade_home_video_look() -> void:
	if not _matches_video_values(legacy_home_video_values()) \
			and not _matches_video_values(legacy_aperture_home_video_values()): return
	var look := video_look_values(1)
	for key: String in look:
		if key not in VIDEO_ADJUSTMENTS: values[key] = look[key]

static func legacy_aperture_home_video_values() -> Dictionary:
	var result := video_look_values(1)
	result["crt_shader"] = 1
	result["crt_shader_parameters"] = {"aperture": HOME_CRT_PARAMETERS.aperture.duplicate()}
	return result

func apply_video_look(index: int) -> void:
	var look := video_look_values(index)
	if look.is_empty():
		return
	values.merge(look, true)
	# An explicit selection also reapplies the look after a launch-only override.
	changed.emit()

static func tape_look_values(index: int) -> Dictionary:
	var look := video_look_values(index)
	for key: String in look.keys():
		if key.begins_with("crt_") or key in CRT_LOOK_KEYS:
			look.erase(key)
	return look

func apply_tape_look(index: int) -> void:
	var look := tape_look_values(index)
	if look.is_empty(): return
	values.merge(look, true)
	changed.emit()

func matching_tape_look(overrides: Dictionary = {}) -> int:
	for index in TAPE_LOOK_NAMES.size():
		if _matches_video_values(tape_look_values(index), overrides):
			return index
	return -1

## The simple screen switch chooses a calibrated renderer automatically.
## It never changes tape settings, damage, grain or the signal pipeline.
func apply_crt_screen(enabled: bool) -> void:
	values["crt_enabled"] = enabled
	if enabled:
		values["crt_shader"] = CRT_AUTOMATIC
		values["crt_shader_parameters"] = HOME_CRT_PARAMETERS.duplicate(true)
		values["crt_curvature"] = false
		values["ntscrt_scale_mode"] = 0
	changed.emit()

func matching_video_look(overrides: Dictionary = {}) -> int:
	for index in VIDEO_LOOK_NAMES.size():
		if _matches_video_values(video_look_values(index), overrides):
			return index
	return -1

func _matches_video_values(look: Dictionary, overrides: Dictionary = {}, adjustments: Array = VIDEO_ADJUSTMENTS) -> bool:
	for key: String in look:
		if key not in adjustments and overrides.get(key, values.get(key)) != look[key]:
			return false
	return true

const NTSCRT_PRESET_NAMES := ["Clean transfer", "Home video", "Worn tape", "Bad reception"]
## Patches over the ntsc_* defaults. "Home video" is the defaults, so its patch
## is empty. Presets never touch video_pipeline, stage toggles or anything else.
const NTSCRT_PRESETS := [
	{
		"ntsc_decoder": 2,
		"ntsc_head_switch": 0.0,
		"ntsc_timebase_jitter": 0.0,
		"ntsc_crinkle": 0.0,
		"ntsc_dropouts": 0.0,
		"ntsc_ghost": 0.0,
		"ntsc_chroma_noise": 0.0,
		"ntsc_rf_noise": 0.0,
		"ntsc_auto_faults": false,
	},
	{},
	{
		"ntsc_tape_speed": 2,
		"ntsc_head_switch": 0.35,
		"ntsc_timebase_jitter": 0.25,
		"ntsc_crinkle": 0.2,
		"ntsc_tracking": 0.12,
		"ntsc_dropouts": 0.3,
		"ntsc_chroma_noise": 0.25,
		"ntsc_chroma_bleed": 0.8,
	},
	{
		"ntsc_signal_strength": 0.35,
		"ntsc_horizontal_hold": 0.12,
		"ntsc_vertical_hold": 0.07,
		"ntsc_ghost": 0.4,
		"ntsc_hum": 0.15,
	},
]

## Reset every ntsc_* key to its default, apply the preset patch, and emit
## exactly one changed signal when anything moved. Nothing outside ntsc_* moves.
func apply_ntscrt_preset(index: int) -> void:
	if index < 0 or index >= NTSCRT_PRESETS.size():
		return
	var patch: Dictionary = NTSCRT_PRESETS[index]
	var dirty := false
	for key: String in DEFAULTS:
		if not key.begins_with("ntsc_"):
			continue
		var next: Variant = patch.get(key, DEFAULTS[key])
		if values.get(key) != next:
			values[key] = next
			dirty = true
	if dirty:
		changed.emit()

func reset_defaults(emit_signal: bool = true) -> void:
	var language: String = str(values.get("language", "en"))
	values = DEFAULTS.duplicate(true)
	values["language"] = language
	if language != "en": values["story_subtitles"] = true
	values["ntscrs_settings"] = FULL_SETTINGS.ntsc_defaults()
	values["receiver_settings"] = FULL_SETTINGS.receiver_defaults()
	bindings = GameInput.default_bindings()
	if emit_signal:
		changed.emit()

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func get_binding(action: String) -> Key:
	if not GameInput.DEFAULTS.has(action):
		return KEY_NONE
	var code: Key = int(bindings.get(action, GameInput.DEFAULTS[action]))
	return code

## "" on success, else a message naming the conflict; failures change nothing.
func set_binding(action: String, code: Key) -> String:
	var error := GameInput.validate(action, code, bindings)
	if not error.is_empty():
		return error
	if int(bindings.get(action, GameInput.DEFAULTS.get(action, KEY_NONE))) \
			== int(code):
		return ""
	bindings[action] = int(code)
	changed.emit()
	return ""

func reset_bindings() -> void:
	bindings = GameInput.default_bindings()
	changed.emit()

func _sanitize(key: String, value: float) -> float:
	var bounds: Vector2 = RANGES[key]
	return clampf(value, bounds.x, bounds.y)

const FULL_SETTINGS = preload("res://scripts/ntscrt_full_settings.gd")
const CRT_SHADER_IDS := ["", "aperture", "easymode", "glow_gauss", "glow_lanczos", "hyllian", "royale", "sim", "native", "auto"]
static var _crt_presets: Dictionary = {}

static func crt_presets() -> Dictionary:
	if _crt_presets.is_empty(): _crt_presets = preload("res://scripts/ntscrt_slang_chain.gd").load_presets()
	return _crt_presets

static func _sanitize_crt_parameters(raw: Variant) -> Dictionary:
	var clean := {}
	if not raw is Dictionary: return clean
	var presets := crt_presets()
	for preset in raw:
		if not presets.has(preset) or not raw[preset] is Dictionary: continue
		var parameters := {}
		for key in raw[preset]:
			if not presets[preset].parameters.has(key): continue
			var value: Variant = raw[preset][key]
			if not (value is float or value is int) or not is_finite(float(value)): continue
			var descriptor: Dictionary = presets[preset].parameters[key]
			parameters[key] = clampf(float(value),float(descriptor.min),float(descriptor.max))
		clean[preset] = parameters
	return clean

func set_crt_parameter(preset: String, key: String, value: float) -> void:
	var next: Dictionary = values.get("crt_shader_parameters",{}).duplicate(true)
	if not next.has(preset): next[preset] = {}
	next[preset][key] = value
	set_value("crt_shader_parameters",next)

func set_video_parameter(engine: String, key: String, value: Variant) -> void:
	if engine not in ["ntscrs","receiver"]: return
	var collection := "ntscrs_settings" if engine == "ntscrs" else "receiver_settings"
	var next: Dictionary = values.get(collection,{}).duplicate(true)
	next[key] = value
	set_value(collection,next)
