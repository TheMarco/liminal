class_name GameSettings
extends RefCounted

signal changed

static var current: GameSettings

static func flashing_reduced() -> bool:
	return current != null and bool(current.values.get("reduced_flashing", false))

const DEFAULTS: Dictionary = {
	"sensitivity": 1.0,
	"field_of_view": 77.0,
	"head_bob": 1.0,
	"music_volume": 1.0,
	"effects_volume": 1.0,
	"vhs_distortion": 1.0,
	"reduced_flashing": false,
}

const RANGES: Dictionary = {
	"sensitivity": Vector2(0.2, 3.0),
	"field_of_view": Vector2(60.0, 100.0),
	"head_bob": Vector2(0.0, 1.0),
	"music_volume": Vector2(0.0, 1.0),
	"effects_volume": Vector2(0.0, 1.0),
	"vhs_distortion": Vector2(0.0, 1.0),
}

var values: Dictionary = {}
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
		if key == "reduced_flashing":
			if raw is bool:
				values[key] = raw
			continue
		if raw is float or raw is int:
			var number := float(raw)
			if is_finite(number):
				values[key] = _sanitize(key, number)
	return true

func save_to_disk() -> Error:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("settings", key, values.get(key, DEFAULTS[key]))
	return config.save(_path)

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var next: Variant = value
	if key == "reduced_flashing":
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
	if emit_signal:
		changed.emit()

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func _sanitize(key: String, value: float) -> float:
	var bounds: Vector2 = RANGES[key]
	return clampf(value, bounds.x, bounds.y)
