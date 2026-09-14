extends SceneTree
## Persistence and first-view Skip contract for the Descent intro. Uses an
## isolated temporary file and never reads or alters the player's real state.
## Run: godot --headless --path . --script tools/audit_intro_playback.gd

const TEST_PATH := "/tmp/liminal_audit_intro_playback.cfg"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _run() -> void:
	var state := IntroPlaybackState.new(TEST_PATH)
	state.clear_from_disk()
	_expect(not state.has_viewed(), "cleared intro state was already viewed")

	var first := DescentIntro.new(state.has_viewed())
	_expect(not first.skip_available(), "first-ever intro allowed skipping")
	root.add_child(first)
	await process_frame
	_expect(first.get_node_or_null("SkipIntro") == null,
		"first-ever intro rendered a Skip control")
	_expect(first._video.is_playing(), "intro stream did not begin playback")
	var first_results: Array[bool] = []
	var pauses: Array[bool] = []
	first.pause_requested.connect(func(): pauses.append(true))
	first.completed.connect(func(watched: bool): first_results.append(watched))
	for code in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_E]:
		first._input(_key(code))
	_expect(pauses == [true], "Escape did not request pause on mandatory intro")
	_expect(first_results.is_empty() and first._video.is_playing(), "first intro accepted keyboard skip")
	_expect(first._video.bus == SoundBank.DIALOGUE_BUS, "intro bypasses dialogue volume")
	first.free()

	_expect(state.mark_viewed() == OK, "viewed state failed to save")
	var loaded := IntroPlaybackState.new(TEST_PATH)
	_expect(loaded.has_viewed(), "viewed state did not survive relaunch")
	var later := DescentIntro.new(loaded.has_viewed())
	_expect(later.skip_available(), "later intro did not offer Skip")
	root.add_child(later)
	await process_frame
	_expect(later.get_node_or_null("SkipIntro") != null,
		"later intro did not render its clickable Skip control")
	later.free()
	for code in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_NONE]:
		var replay := DescentIntro.new(true)
		root.add_child(replay)
		await process_frame
		var results: Array[bool] = []
		replay.completed.connect(func(watched: bool): results.append(watched))
		_expect(replay._skip_button.has_focus(), "Skip has no keyboard focus")
		replay._input(_key(KEY_ESCAPE, false))
		replay._input(_key(KEY_ESCAPE, true, true))
		_expect(results.is_empty(), "release/echo skipped replay")
		if code == KEY_NONE:
			replay._skip_button.pressed.emit()
		else:
			root.push_input(_key(code))
			root.push_input(_key(code, false))
		replay._input(_key(KEY_E))
		_expect(results == [false], "replay skip emitted incorrectly: %s" % code)
		await process_frame

	loaded.clear_from_disk()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("intro playback audit: PASS — first view is mandatory; later views can skip")
		quit()
	else:
		quit(1)
