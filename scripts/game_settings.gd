class_name GameSettings
extends RefCounted

signal changed
signal save_failed(error: Error)
signal saved

static var current: GameSettings

static func flashing_reduced() -> bool:
	return current != null and bool(current.values.get("reduced_flashing", false))

const DEFAULTS: Dictionary = {
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

const BOOLEAN_KEYS := ["invert_y", "toggle_sprint", "handheld_camera", "fullscreen",
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
		if raw is float or raw is int:
			var number := float(raw)
			if is_finite(number):
				values[key] = _sanitize(key, number)
	_load_bindings(config)
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
	var next: Variant = value
	if key in BOOLEAN_KEYS:
		if not value is bool:
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
	changed.emit()

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
