extends SceneTree

const AtomicConfig = preload("res://scripts/atomic_config.gd")

var root_path := "/tmp/liminal_atomic_audit_%d" % OS.get_process_id()
var failures: Array[String] = []

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	_test_descent()
	_test_atomic()
	_test_intro()
	_test_settings()
	print("atomic persistence audit: %d failure(s)" % failures.size())
	for failure in failures: push_error(failure)
	for path in ["descent.cfg", "descent.cfg.bak", "settings.cfg", "intro/state.cfg", "intro/video.cfg"]:
		DirAccess.remove_absolute(root_path + "/" + path)
	DirAccess.remove_absolute(root_path + "/intro")
	DirAccess.remove_absolute(root_path + "/video")
	DirAccess.remove_absolute(root_path)
	quit(1 if failures.size() > 0 else 0)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _test_descent() -> void:
	var path := root_path + "/descent.cfg"
	var progress := DescentProgress.new(path)
	progress.start_new(12345)
	check(progress.save_to_disk() == OK, "descent initial save")
	progress.deepest_floor = 3
	check(progress.save_to_disk() == OK, "descent second save")
	check(FileAccess.file_exists(path + ".bak"), "descent backup created")
	var corrupt := ConfigFile.new()
	corrupt.set_value("descent", "version", 999)
	corrupt.set_value("descent", "run_seed", -1)
	check(corrupt.save(path) == OK, "descent corrupt live write")
	var recovered := DescentProgress.new(path)
	check(recovered.load_from_disk(), "descent backup recovery")
	check(recovered.run_seed == 12345, "descent recovered seed")
	var backup_before := FileAccess.get_file_as_bytes(path + ".bak")
	recovered.deepest_floor = 4
	check(recovered.save_to_disk() == OK, "descent post-recovery save")
	check(FileAccess.get_file_as_bytes(path + ".bak") == backup_before, "corrupt live did not rotate backup")

func _test_atomic() -> void:
	var config := ConfigFile.new()
	config.set_value("x", "y", 1)
	var missing := root_path + "/missing/subdir/file.cfg"
	check(AtomicConfig.save_config(config, missing) != OK, "atomic missing directory fails")
	check(not FileAccess.file_exists(missing + ".tmp.%d" % OS.get_process_id()), "atomic temp cleaned")

func _test_intro() -> void:
	var dir := root_path + "/intro"
	var path := dir + "/state.cfg"
	var state := IntroPlaybackState.new(path)
	check(state.mark_viewed() != OK, "intro missing dir fails")
	check(state.mark_viewed() != OK, "intro repeated dirty mark fails")
	check(state.load_from_disk() == false and state.has_viewed(), "intro dirty load preserves flag")
	DirAccess.make_dir_recursive_absolute(dir)
	check(IntroPlaybackState.retry_pending() == OK, "intro retry succeeds")
	check(not IntroPlaybackState.has_pending(), "intro pending clears")
	var fresh := IntroPlaybackState.new(path)
	check(fresh.has_viewed(), "intro persisted viewed")
	var video := IntroPlaybackState.new(root_path + "/video/state.cfg")
	check(video.mark_video_viewed("clip") != OK, "video missing directory did not fail")
	check(not video.load_from_disk() and video.has_viewed_video("clip"), "dirty video flag lost on load")
	video._save_path = dir + "/video.cfg"
	check(IntroPlaybackState.retry_pending() == OK, "pending video retry failed")
	check(IntroPlaybackState.new(video._save_path).has_viewed_video("clip"), "video retry not persisted")
	check(not IntroPlaybackState.has_pending(), "video still pending after retry")

func _test_settings() -> void:
	var path := root_path + "/settings.cfg"
	var settings := GameSettings.new(path)
	settings.set_value("fullscreen", true)
	check(settings.save_to_disk() == OK, "fullscreen save")
	var loaded := GameSettings.new(path)
	check(bool(loaded.get_value("fullscreen")), "fullscreen load")
