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

	loaded.clear_from_disk()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("intro playback audit: PASS — first view is mandatory; later views can skip")
		quit()
	else:
		quit(1)
