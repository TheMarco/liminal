extends SceneTree
## Focused rebinding audit: event matching, held-key resolution, rejection,
## persistence round-trip/corruption fallback, reset, capture cancel/consume.
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func run() -> void:
	var prior_current: Variant = GameSettings.current
	GameSettings.current = null
	_test_defaults()
	_test_rematch()
	_test_held()
	_test_reject()
	_test_persist()
	_test_reset()
	_test_capture()
	GameSettings.current = prior_current
	for failure in failures:
		push_error("KEY_BINDINGS AUDIT FAIL: " + failure)
	print("KEY_BINDINGS AUDIT: %d failure(s); rematch, held, reject, persist, reset, capture" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_defaults() -> void:
	for action in GameInput.ACTIONS:
		check(GameInput.primary(action) == GameInput.DEFAULTS[action],
			"null-current default drift: " + action)
	check(GameInput.matches(key(KEY_E), "interact"), "E stopped matching interact")
	check(GameInput.matches(key(KEY_SPACE), "shutter"), "Space stopped matching shutter")
	check(not GameInput.matches(key(KEY_E, true, true), "interact"), "echo matches")
	check(not GameInput.matches(key(KEY_E, false), "interact"), "release matches")
	check(not GameInput.matches(key(KEY_F), "interact"), "wrong key matches")
	check(not GameInput.matches(InputEventMouseButton.new(), "shutter"), "mouse matches key action")
	check(GameInput.held_keys("forward") == [KEY_W, KEY_UP], "forward held lost arrows")
	check(GameInput.primary_label("shutter") == "SPACE", "shutter label")
	check(GameInput.primary_hint("shutter") == "Space", "shutter hint")
	check(GameInput.movement_label() == "WASD  /  ARROWS", "movement label")
	check(GameInput.movement_compact_label() == "WASD", "movement compact label")

func _test_rematch() -> void:
	var settings := GameSettings.new("/tmp/liminal-bindings-rematch-%d.cfg" % OS.get_process_id())
	check(settings.set_binding("interact", KEY_T).is_empty(), "T rejected for interact")
	check(GameInput.matches(key(KEY_T), "interact", settings), "rebind did not match")
	check(not GameInput.matches(key(KEY_E), "interact", settings), "old primary still active")
	GameSettings.current = settings
	var interactable := Interactable.new()
	interactable.prompt_text = "E — open door"
	check(interactable.get_prompt() == "T — open door", "authored interaction prompt kept old key")
	settings.set_binding("interact", KEY_Y)
	check(interactable.get_prompt() == "Y — open door", "focused interaction prompt did not refresh")
	settings.set_binding("interact", KEY_T)
	interactable.free()
	GameSettings.current = null
	check(settings.set_binding("interact", KEY_T).is_empty(), "same-key rebind errored")
	DirAccess.remove_absolute("/tmp/liminal-bindings-rematch-%d.cfg" % OS.get_process_id())

func _test_held() -> void:
	var settings := GameSettings.new("/tmp/liminal-bindings-held-%d.cfg" % OS.get_process_id())
	check(settings.set_binding("torch", KEY_LEFT).is_empty(), "arrow rebind rejected")
	check(GameInput.held_keys("left", settings) == [KEY_A], "arrow alternative survived assignment")
	check(GameInput.held_keys("torch", settings) == [KEY_LEFT], "torch held wrong")
	check(not GameInput.alternative_active("left", settings), "left alternative still active")
	check(not GameInput.movement_label(settings).ends_with("ARROWS"), "help advertised a reassigned arrow")
	check(GameInput.alternative_active("forward", settings), "forward alternative lost")
	check(GameInput.matches_code(KEY_W, "forward", settings), "matches_code missed")
	check(not GameInput.matches_code(KEY_W, "back", settings), "matches_code false hit")
	DirAccess.remove_absolute("/tmp/liminal-bindings-held-%d.cfg" % OS.get_process_id())

func _test_reject() -> void:
	var settings := GameSettings.new("/tmp/liminal-bindings-reject-%d.cfg" % OS.get_process_id())
	var dup := settings.set_binding("interact", KEY_F)
	check(not dup.is_empty() and dup.contains("TORCH"), "duplicate accepted or vague: " + dup)
	check(settings.get_binding("interact") == KEY_E, "duplicate changed binding")
	for code in [KEY_1, KEY_5, KEY_9, KEY_0, KEY_MINUS, KEY_KP_0, KEY_KP_SUBTRACT,
			KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_ESCAPE, KEY_NONE, -1, 99999999]:
		var error := settings.set_binding("torch", code)
		check(not error.is_empty(), "reserved/invalid accepted: %d" % int(code))
	check(settings.get_binding("torch") == KEY_F, "reserved changed binding")
	check(not settings.set_binding("nope", KEY_T).is_empty(), "unknown action accepted")
	DirAccess.remove_absolute("/tmp/liminal-bindings-reject-%d.cfg" % OS.get_process_id())

func _test_persist() -> void:
	var path := "/tmp/liminal-bindings-persist-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	settings.set_binding("interact", KEY_T)
	settings.set_binding("album", KEY_B)
	check(settings.save_to_disk() == OK, "bindings save failed")
	var raw := ConfigFile.new()
	check(raw.load(path) == OK and int(raw.get_value("bindings", "interact")) == KEY_T,
		"bindings section missing persisted key")
	var roundtrip := GameSettings.new(path)
	check(roundtrip.get_binding("interact") == KEY_T, "interact roundtrip lost")
	check(roundtrip.get_binding("album") == KEY_B, "album roundtrip lost")
	# A valid saved permutation must load independently of action order.
	settings.set_binding("back", KEY_K)
	settings.set_binding("forward", KEY_S)
	check(settings.save_to_disk() == OK, "permuted binding save failed")
	var permutation := GameSettings.new(path)
	check(permutation.get_binding("forward") == KEY_S and permutation.get_binding("back") == KEY_K,
		"saved remap depended on load order")
	var corrupt := ConfigFile.new()
	corrupt.set_value("settings", "sensitivity", 1.0)
	corrupt.set_value("bindings", "interact", "T")
	corrupt.set_value("bindings", "torch", KEY_1)
	corrupt.set_value("bindings", "camera", KEY_T)
	corrupt.set_value("bindings", "shutter", KEY_T)
	corrupt.set_value("bindings", "album", KEY_B)
	check(corrupt.save(path) == OK, "corrupt fixture write failed")
	var recovered := GameSettings.new(path)
	check(recovered.get_binding("interact") == KEY_E, "string binding not defaulted")
	check(recovered.get_binding("torch") == KEY_F, "reserved binding not defaulted")
	check(recovered.get_binding("camera") == KEY_C, "conflicting override did not fall back")
	check(recovered.get_binding("shutter") == KEY_SPACE, "second duplicate kept")
	check(recovered.get_binding("album") == KEY_B, "valid binding dropped")
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "sensitivity", 2.0)
	check(legacy.save(path) == OK, "legacy fixture write failed")
	var older := GameSettings.new(path)
	check(older.get_binding("interact") == KEY_E, "older config lost defaults")
	DirAccess.remove_absolute(path)

func _test_reset() -> void:
	var settings := GameSettings.new("/tmp/liminal-bindings-reset-%d.cfg" % OS.get_process_id())
	settings.set_binding("interact", KEY_T)
	settings.set_value("sensitivity", 2.5)
	settings.reset_defaults()
	check(settings.get_binding("interact") == KEY_E, "reset kept binding")
	check(settings.get_value("sensitivity") == 1.0, "reset kept value")
	settings.set_binding("interact", KEY_T)
	settings.reset_bindings()
	check(settings.get_binding("interact") == KEY_E, "bindings-only reset failed")
	DirAccess.remove_absolute("/tmp/liminal-bindings-reset-%d.cfg" % OS.get_process_id())

func _test_capture() -> void:
	var path := "/tmp/liminal-bindings-capture-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	var menu := PauseMenu.new()
	root.add_child(menu)
	menu.setup(settings)
	menu.open()
	for action in GameInput.ACTIONS:
		var button := menu._binding_buttons.get(action) as Button
		check(is_instance_valid(button) and button.focus_mode == Control.FOCUS_ALL,
			"binding button missing/unfocusable: " + action)
	menu._start_capture("interact")
	check(menu._capturing == "interact", "capture did not start")
	check((menu._binding_buttons["interact"] as Button).text == "PRESS KEY...",
		"capture prompt missing")
	check(menu._capture_key(key(KEY_T, true, true)), "echo not consumed")
	check(menu._capture_key(key(KEY_T, false)), "release not consumed")
	check(settings.get_binding("interact") == KEY_E, "echo/release rebound")
	check(menu._capture_key(key(KEY_F)), "conflict not consumed")
	check(settings.get_binding("interact") == KEY_E, "conflict rebound")
	check(menu._capturing == "interact", "conflict ended capture")
	check(not (menu._binding_status as Label).text.is_empty(), "conflict status silent")
	check(menu._capture_key(key(KEY_ESCAPE)), "cancel not consumed")
	check(menu._capturing.is_empty(), "Escape did not cancel capture")
	check(settings.get_binding("interact") == KEY_E, "cancel rebound")
	menu._start_capture("interact")
	check(menu._capture_key(key(KEY_T)), "key not consumed")
	check(settings.get_binding("interact") == KEY_T, "capture did not rebind")
	check(menu._capturing.is_empty(), "capture did not end")
	check((menu._binding_status as Label).text.is_empty(), "success left stale status")
	check((menu._binding_buttons["interact"] as Button).text == "T", "button label stale")
	settings.reset_defaults()
	check((menu._binding_buttons["interact"] as Button).text == "E", "reset label stale")
	menu.free()
	DirAccess.remove_absolute(path)
