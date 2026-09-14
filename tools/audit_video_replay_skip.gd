extends SceneTree
## Isolated completion history and E controls; Escape belongs to Main's pause.
const TEST_PATH := "/tmp/liminal_audit_video_replay.cfg"
var failures: Array[String] = []

class TestRitual extends VhsRitual:
	func _ready() -> void:
		set_process(false)
	func _present_idle() -> void:
		pass

class Listener extends Node:
	var finishes := 0
	var watching := false
	func descent_setup_tape_finished(_key: String, _objective: bool) -> void:
		finishes += 1
	func descent_intro_tape_finished(_key: String) -> void:
		finishes += 1
	func descent_tape_watch(on: bool) -> void:
		watching = on

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func press(ritual: VhsRitual, code: Key = KEY_E) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	ritual._unhandled_input(event)

func start(ritual: VhsRitual, identity: String) -> void:
	ritual._playback_identity = identity
	ritual._playing = true
	ritual._begin_watch(null)

func _run() -> void:
	var state := IntroPlaybackState.new(TEST_PATH)
	state.clear_from_disk()
	var legacy := ConfigFile.new()
	legacy.set_value("intro", "version", 1)
	legacy.set_value("intro", "viewed", true)
	legacy.set_value("intro", "tutorial_viewed", true)
	legacy.save(TEST_PATH)
	state.load_from_disk()
	check(state.has_viewed() and state.has_viewed_tutorial()
		and state.completed_videos.is_empty(), "legacy config lost intro permissions")
	state.clear_from_disk()
	var stale := IntroPlaybackState.new(TEST_PATH)
	check(state.mark_video_viewed("known.ogv") == OK, "video completion save failed")
	stale.mark_tutorial_viewed()
	state.load_from_disk()
	check(state.has_viewed_video("known.ogv"), "stale intro save erased video history")
	check(state.has_viewed_tutorial(), "video history erased legacy tutorial completion")
	state.clear_from_disk()
	var listener := Listener.new()
	root.add_child(listener)
	listener.add_to_group("descent_listener")
	var ritual := TestRitual.new()
	ritual._playback_state = state
	root.add_child(ritual)
	start(ritual, "first.ogv")
	check(not ritual._skip_available(), "unwatched recording allowed skip")
	var hint_panel := ritual._watch_hint.get_node("Backing") as PanelContainer
	var hint_label := hint_panel.get_node("Controls") as Label
	check(ritual._watch_hint.layer > 100, "playback controls blurred by CRT post processing")
	check(hint_label.get_theme_font_size("font_size") == 28, "playback controls too small")
	check(hint_label.text == "E — STOP AND REWIND  ·  ESC — PAUSE", "first-watch control wording changed")
	check((hint_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 0.9,
		"playback controls missing contrast backing")
	var hint_bounds := Rect2(hint_panel.position, hint_panel.size * hint_panel.scale)
	check(root.get_visible_rect().encloses(hint_bounds), "playback controls extend beyond viewport")
	press(ritual, KEY_ESCAPE)
	check(ritual._playing, "ritual consumed Escape instead of leaving it for pause")
	press(ritual)
	check(not ritual._playing and not ritual._done, "ordinary first watch did not abort")
	check(not state.has_viewed_video("first.ogv"), "abort unlocked skip")
	check(ritual._watch_hint == null and not listener.watching, "abort left hint or passive state")
	ritual.intro = true
	start(ritual, "tutorial.ogv")
	press(ritual)
	check(ritual._playing and ritual._watch_hint == null, "first tutorial could be skipped")
	ritual._on_video_finished()
	check(IntroPlaybackState.new(TEST_PATH).has_viewed_video("tutorial.ogv"), "natural finish not persisted")
	check(listener.finishes == 1, "first completion callback missing")
	start(ritual, "tutorial.ogv")
	check(ritual._skip_available() and ritual._watch_hint != null, "replay skip hint missing")
	press(ritual, KEY_E)
	check(not ritual._playing and listener.finishes == 1, "replay duplicated completion reward")
	check(ritual._watch_hint == null, "skip left hint visible")
	ritual.free()
	var new_set := TestRitual.new()
	new_set._playback_state = IntroPlaybackState.new(TEST_PATH)
	root.add_child(new_set)
	start(new_set, "tutorial.ogv")
	check(new_set._skip_available(), "same footage on another set not skippable")
	press(new_set)
	check(new_set._done and listener.finishes == 2, "known footage did not complete new objective")
	new_set._done = false
	new_set.already_watched = true
	start(new_set, "legacy.ogv")
	press(new_set)
	check(not IntroPlaybackState.new(TEST_PATH).has_viewed_video("legacy.ogv"), "legacy skip falsely marked natural completion")
	new_set.free()
	listener.free()
	state.clear_from_disk()
	await process_frame
	for failure in failures:
		print("FAIL: " + failure)
	print("video replay skip audit: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
