class_name IntroPlaybackState
extends RefCounted
## Machine-local presentation state. This deliberately does not live in the
## Descent checkpoint: starting a new building may replace that checkpoint,
## while permission to skip the intro survives every run.

const SAVE_PATH := "user://intro_playback.cfg"
const SECTION := "intro"
const VERSION := 1

var viewed := false
var _save_path := SAVE_PATH


func _init(custom_save_path := "") -> void:
	if not custom_save_path.is_empty():
		_save_path = custom_save_path
	load_from_disk()


func has_viewed() -> bool:
	return viewed


## Called only when playback reaches the end. Merely starting the movie must
## not unlock Skip, or closing the game halfway through would count as a view.
func mark_viewed() -> Error:
	if viewed:
		return OK
	viewed = true
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", VERSION)
	config.set_value(SECTION, "viewed", true)
	return config.save(_save_path)


func load_from_disk() -> bool:
	viewed = false
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		return false
	if int(config.get_value(SECTION, "version", 0)) != VERSION:
		return false
	viewed = bool(config.get_value(SECTION, "viewed", false))
	return true


## Test helper. Runtime never revokes permission to skip.
func clear_from_disk() -> void:
	var absolute := ProjectSettings.globalize_path(_save_path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	viewed = false
