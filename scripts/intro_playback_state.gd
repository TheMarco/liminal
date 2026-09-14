class_name IntroPlaybackState
extends RefCounted
## Machine-local presentation state. This deliberately does not live in the
## Descent checkpoint: starting a new building may replace that checkpoint,
## while permission to skip completed videos survives every run.

const SAVE_PATH := "user://intro_playback.cfg"
const TEST_SAVE_PATH := "user://test_mode_intro_playback.cfg"
## Selected once at launch; every TV and the prologue use the same profile.
## Explicit custom paths used by audits are unaffected.
static var default_save_path := SAVE_PATH
const SECTION := "intro"
const VERSION := 1
class SaveEvents extends RefCounted:
	signal failed(error: Error)
	signal saved

static var save_events := SaveEvents.new()
static var _pending: Array[IntroPlaybackState] = []
var _dirty := false

var viewed := false
## The floor 1 arrival console's camera tutorial: once it has run to the end
## on this machine, later runs may skip it (E counts it as watched).
var tutorial_viewed := false
var completed_videos: Array[String] = []
var _save_path := SAVE_PATH


func _init(custom_save_path := "") -> void:
	_save_path = custom_save_path if not custom_save_path.is_empty() else default_save_path
	load_from_disk()


func has_viewed() -> bool:
	return viewed


## Called only when playback reaches the end. Merely starting the movie must
## not unlock Skip, or closing the game halfway through would count as a view.
func mark_viewed() -> Error:
	if viewed and not _dirty:
		return OK
	viewed = true
	return _persist()


func has_viewed_tutorial() -> bool:
	return tutorial_viewed


func mark_tutorial_viewed() -> Error:
	if tutorial_viewed and not _dirty:
		return OK
	tutorial_viewed = true
	return _persist()


func has_viewed_video(path: String) -> bool:
	return not path.is_empty() and completed_videos.has(path)


func mark_video_viewed(path: String) -> Error:
	if path.is_empty():
		return OK
	if completed_videos.has(path) and not _dirty:
		return OK
	if not completed_videos.has(path):
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
	var error := preload("res://scripts/atomic_config.gd").save_config(config, _save_path)
	_dirty = error != OK
	if _dirty:
		if not _pending.has(self):
			_pending.append(self)
		save_events.failed.emit(error)
	else:
		_pending.erase(self)
		save_events.saved.emit()
	return error


static func retry_pending() -> Error:
	var error := OK
	for state in _pending.duplicate():
		var result: Error = state._persist()
		if result != OK:
			error = result
	return error


static func has_pending() -> bool:
	return not _pending.is_empty()


func load_from_disk() -> bool:
	# A TV can re-open while its previous completion is waiting for disk space.
	# Never discard that in-session completion just because the file is older.
	if _dirty:
		return false
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
	_pending.erase(self)
	_dirty = false
	var absolute := ProjectSettings.globalize_path(_save_path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	viewed = false
	tutorial_viewed = false
	completed_videos.clear()
