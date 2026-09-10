class_name IntroPlaybackState
extends RefCounted
## Machine-local presentation state. This deliberately does not live in the
## Descent checkpoint: starting a new building may replace that checkpoint,
## while permission to skip completed videos survives every run.

const SAVE_PATH := "user://intro_playback.cfg"
const SECTION := "intro"
const VERSION := 1

var viewed := false
## The floor 1 arrival console's camera tutorial: once it has run to the end
## on this machine, later runs may skip it (E/Esc counts it as watched).
var tutorial_viewed := false
var completed_videos: Array[String] = []
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
	return _persist()


func has_viewed_tutorial() -> bool:
	return tutorial_viewed


func mark_tutorial_viewed() -> Error:
	if tutorial_viewed:
		return OK
	tutorial_viewed = true
	return _persist()


func has_viewed_video(path: String) -> bool:
	return not path.is_empty() and completed_videos.has(path)


func mark_video_viewed(path: String) -> Error:
	if path.is_empty() or completed_videos.has(path):
		return OK
	completed_videos.append(path)
	return _persist()


func _persist() -> Error:
	var config := ConfigFile.new()
	# Multiple televisions and the main intro controller may hold separate
	# instances. Completion is monotonic: never overwrite another one's view.
	if config.load(_save_path) == OK \
			and int(config.get_value(SECTION, "version", 0)) == VERSION:
		viewed = viewed or bool(config.get_value(SECTION, "viewed", false))
		tutorial_viewed = tutorial_viewed or bool(
			config.get_value(SECTION, "tutorial_viewed", false))
		for path in config.get_value(SECTION, "completed_videos", []):
			if path is String and not completed_videos.has(path):
				completed_videos.append(path)
	config.set_value(SECTION, "version", VERSION)
	config.set_value(SECTION, "viewed", viewed)
	config.set_value(SECTION, "tutorial_viewed", tutorial_viewed)
	config.set_value(SECTION, "completed_videos", completed_videos)
	return config.save(_save_path)


func load_from_disk() -> bool:
	viewed = false
	tutorial_viewed = false
	completed_videos.clear()
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		return false
	if int(config.get_value(SECTION, "version", 0)) != VERSION:
		return false
	viewed = bool(config.get_value(SECTION, "viewed", false))
	tutorial_viewed = bool(config.get_value(SECTION, "tutorial_viewed", false))
	for path in config.get_value(SECTION, "completed_videos", []):
		if path is String and not path.is_empty():
			completed_videos.append(path)
	return true


## Test helper. Runtime never revokes permission to skip.
func clear_from_disk() -> void:
	var absolute := ProjectSettings.globalize_path(_save_path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	viewed = false
	tutorial_viewed = false
	completed_videos.clear()
