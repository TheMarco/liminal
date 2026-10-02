class_name GameSettings
extends RefCounted

signal changed
signal save_failed(error: Error)
signal saved

static var current: GameSettings

static func flashing_reduced() -> bool:
	return current != null and bool(current.values.get("reduced_flashing", false))

const DEFAULTS: Dictionary = {
	"quality_preset": 1,
	"render_resolution": 1,
	"anti_aliasing": 1,
	"shadow_quality": 1,
	"global_illumination": 0,
	"ambient_occlusion": 1,
	"reflections": 0,
	"volumetric_fog": 0,
	"frame_limit": 60,
	"vsync": true,
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
	"reduced_flashing": false,
	"vhs_enabled": true,
	"crt_enabled": true,
	"crt_curvature": false,
	"hdr_enabled": true,
	"hdr_brightness": 1.0,
}

const BOOLEAN_KEYS := ["vsync", "invert_y", "toggle_sprint", "handheld_camera", "fullscreen",
	"reduced_flashing", "death_hints", "vhs_enabled", "crt_enabled", "crt_curvature",
	"hdr_enabled", "story_subtitles"]

const RANGES: Dictionary = {
	"sensitivity": Vector2(0.2, 3.0),
	"field_of_view": Vector2(60.0, 100.0),
	"head_bob": Vector2(0.0, 1.0),
	"handheld_strength": Vector2(0.0, 1.0),
	"music_volume": Vector2(0.0, 1.0),
	"effects_volume": Vector2(0.0, 1.0),
	"dialogue_volume": Vector2(0.0, 1.0),
	"vhs_distortion": Vector2(0.0, 1.0),
	"film_grain": Vector2(0.0, 1.0),
	"hdr_brightness": Vector2(0.60, 1.40),
}

const BINDINGS_SECTION := "bindings"

## Presets are applied in one transaction so live rendering never sees a
## partially selected mode. Presentation and comfort preferences are separate.
const QUALITY_KEYS := ["render_resolution", "anti_aliasing", "shadow_quality",
	"global_illumination", "ambient_occlusion", "reflections", "volumetric_fog"]
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra", "Custom"]
const QUALITY_PRESETS := [
	[0, 1, 0, 0, 0, 0, 0],
	[1, 1, 1, 0, 1, 0, 0],
	[2, 2, 2, 1, 2, 1, 1],
	[5, 5, 3, 2, 2, 2, 2],
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
}

var values: Dictionary = {}
var bindings: Dictionary = {}
var _path := "user://settings.cfg"

func _init(config_path: String = "user://settings.cfg") -> void:
	_path = config_path
	reset_defaults(false)
	load_from_disk()

func load_from_disk() -> bool:
	var config := ConfigFile.new()
	var err: Error = config.load(_path)
	if err != OK:
		return false
	for key: String in DEFAULTS:
		if not config.has_section_key("settings", key):
			continue
		var raw: Variant = config.get_value("settings", key)
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
	values["quality_preset"] = matching_quality_preset()
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
	var next: Variant = value
	if key in BOOLEAN_KEYS:
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
	values[key] = next
	if key in QUALITY_KEYS:
		values["quality_preset"] = matching_quality_preset()
	changed.emit()

func apply_quality_preset(index: int) -> void:
	if index < 0 or index >= QUALITY_PRESETS.size():
		return
	var dirty := false
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

func reset_defaults(emit_signal: bool = true) -> void:
	values = DEFAULTS.duplicate(true)
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
