extends SceneTree

const GameSettingsType = preload("res://scripts/game_settings.gd")
var failures: Array[String] = []

func _init() -> void:
	var path := "/tmp/liminal-game-settings-%d.cfg" % Time.get_ticks_usec()
	var settings = GameSettingsType.new(path)
	_assert(settings.get_value("sensitivity") == 1.0, "defaults")
	settings.set_value("sensitivity", 2.5)
	settings.set_value("reduced_flashing", true)
	_assert(settings.save_to_disk() == OK, "save")
	var roundtrip = GameSettingsType.new(path)
	_assert(roundtrip.get_value("sensitivity") == 2.5 and roundtrip.get_value("reduced_flashing"), "roundtrip")
	roundtrip.set_value("field_of_view", 999.0)
	_assert(roundtrip.get_value("field_of_view") == 100.0, "clamp")
	roundtrip.set_value("music_volume", INF)
	_assert(roundtrip.get_value("music_volume") == 1.0, "inf rejection")
	roundtrip.set_value("head_bob", NAN)
	_assert(roundtrip.get_value("head_bob") == 1.0, "nan rejection")
	roundtrip.set_value("unknown", 12.0)
	_assert(not roundtrip.values.has("unknown"), "unknown key")
	roundtrip.reset_defaults()
	_assert(roundtrip.get_value("sensitivity") == 1.0 and not roundtrip.get_value("reduced_flashing"), "reset")
	DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("GAME_SETTINGS AUDIT PASS")
	else:
		for failure in failures:
			push_error("GAME_SETTINGS AUDIT FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _assert(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
