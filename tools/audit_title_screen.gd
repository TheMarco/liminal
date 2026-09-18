extends SceneTree
## Verifies that the title remains a menu, information lives on separate pages,
## attribution is present, and the two original mode-selection signals survive.
## Run: godot --headless --path . --script tools/audit_title_screen.gd

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	print("FAIL — %s" % message)


func _page_text(title: TitleScreen, page: int) -> String:
	var root := title._pages.get(page) as Control
	if root == null:
		return ""
	var lines: Array[String] = []
	for found in root.find_children("*", "", true, false):
		if found is Label or found is Button:
			lines.append(str(found.text))
	return "\n".join(lines)


func _only_page_visible(title: TitleScreen, page: int) -> bool:
	for key in title._pages:
		var control := title._pages[key] as Control
		if control.visible != (int(key) == page):
			return false
	return true


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _tap(code: Key) -> void:
	root.push_input(_key(code))
	var release := _key(code)
	release.pressed = false
	root.push_input(release)


func _find_button(title: TitleScreen, text: String) -> Button:
	for button in title._pages[TitleScreen.Page.MAIN].find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var title := TitleScreen.new()
	root.add_child(title)
	await process_frame
	_expect(title.layer > 100,
		"title typography is still underneath the gameplay post-process")

	var main_text := _page_text(title, TitleScreen.Page.MAIN)
	_expect(_only_page_visible(title, TitleScreen.Page.MAIN),
		"main title is not the sole visible page")
	for choice in ["WANDER", "DESCENT", "SETTINGS", "INSTRUCTIONS", "ABOUT",
			"CREDITS", "QUIT"]:
		_expect(main_text.contains(choice),
			"main title is missing %s" % choice)
	_expect(not main_text.contains("VHS EFFECT") and not main_text.contains("CRT EFFECT"),
		"video-effect switches still occupy the title screen")
	_expect(title._background.texture.get_width() == 1672
		and title._background.texture.get_height() == 941,
		"title is not using the supplied 1672x941 artwork")
	var main_buttons: Array[Node] = title._pages[TitleScreen.Page.MAIN].find_children(
		"*", "Button", true, false)
	_expect(main_buttons.size() == 7,
		"plain title does not contain exactly seven menu options")
	var previous_y := -INF
	var column_x := INF
	for button in main_buttons:
		var menu_button := button as Button
		if column_x == INF:
			column_x = menu_button.global_position.x
		_expect(absf(menu_button.global_position.x - column_x) <= 2.0,
			"title options are not aligned in one column")
		_expect(menu_button.global_position.y > previous_y,
			"title options are not stacked vertically")
		previous_y = menu_button.global_position.y
	_expect(title._main_dock.global_position.x < 640.0
		and title._main_dock.global_position.y > 250.0,
		"main menu is not positioned beneath the upper-left logo")
	_expect(title._main_dock.global_position.y + title._main_dock.size.y <= 721.0,
		"main menu overflows the bottom of the title screen")
	_expect(not main_text.contains("WASD"),
		"instructions leaked back onto the main title")
	for removed in ["SPACE  ", "ENTER  ", "R  ", "N  ", "S  ", "I  ", "A  ", "C  "]:
		_expect(not main_text.contains(removed), "title retained shortcut prefix %s" % removed)
	var shortcut_actions: Array[String] = []
	title.settings_requested.connect(func(): shortcut_actions.append("settings"))
	title.mode_selected.connect(func(_mode: bool): shortcut_actions.append("mode"))
	for code in [KEY_R, KEY_N, KEY_S, KEY_I, KEY_A, KEY_C]:
		_tap(code)
		_expect(title._current_page == TitleScreen.Page.MAIN and shortcut_actions.is_empty(),
			"removed letter shortcut still activated an action: %s" % code)
	# Without focus, Space only selects a visible control; it no longer starts Wander.
	_tap(KEY_SPACE)
	_expect(shortcut_actions.is_empty() and title._primary_button.has_focus(),
		"unfocused Space unexpectedly launched a mode")

	title._show_instructions()
	var instructions := _page_text(title, TitleScreen.Page.INSTRUCTIONS)
	_expect(_only_page_visible(title, TitleScreen.Page.INSTRUCTIONS),
		"Instructions is not a separate visible page")
	for required in ["WASD", "WANDER", "DESCENT", "FLASHLIGHT"]:
		_expect(instructions.to_upper().contains(required),
			"Instructions is missing %s" % required)
	_expect(not instructions.contains("B  ") and not instructions.contains("V  "),
		"Instructions still advertise a gameplay video-filter hotkey")

	title._show_about()
	var about := _page_text(title, TitleScreen.Page.ABOUT)
	_expect(_only_page_visible(title, TitleScreen.Page.ABOUT),
		"About is not a separate visible page")
	for required in ["MARCO VAN HYLCKAMA VLIEG",
			"AI & DESIGN GAME STUDIOS", "CREDITS", "3D MODEL"]:
		_expect(about.to_upper().contains(required),
			"About is missing %s" % required)

	title._show_credits()
	var credits := _page_text(title, TitleScreen.Page.CREDITS)
	_expect(_only_page_visible(title, TitleScreen.Page.CREDITS),
		"Credits is not a separate visible page")
	for required in ["3D MODEL CREATORS", "Jawahar Yokesh",
			"Matt LeMoine", "carlcapu9", "FlevasGR", "JamieDTran",
			"EntropyNine", "Khoa Nguyen", "Lora",
			"wpanayides", "JmPrsh153", "Network manager",
			"THIRD_PARTY_ASSETS.md"]:
		_expect(credits.contains(required),
			"Credits is missing %s" % required)

	title._input(_key(KEY_ESCAPE))
	_expect(_only_page_visible(title, TitleScreen.Page.MAIN),
		"Escape does not return an information page to the title")
	title.free()

	var descent_title := TitleScreen.new()
	root.add_child(descent_title)
	await process_frame
	var selected: Array[bool] = []
	var entries: Array[int] = []
	descent_title.mode_selected.connect(
		func(value: bool): selected.append(value))
	descent_title.descent_requested.connect(
		func(value: int): entries.append(value))
	descent_title._select_descent()
	_expect(selected == [true],
		"Descent selection did not emit mode_selected(true)")
	_expect(entries == [TitleScreen.DescentEntry.NEW],
		"first Descent did not request a new building")
	_expect(_only_page_visible(descent_title, TitleScreen.Page.DESCENT),
		"Descent selection did not open its rule briefing")
	var descent_start := descent_title._descent_start_button as Button
	_expect(descent_start != null and descent_start.disabled, "Descent start was not disabled while loading")
	var starts: Array[bool] = []
	descent_title.started.connect(func(value: bool): starts.append(value))
	descent_start.pressed.emit()
	_tap(KEY_SPACE)
	_expect(starts.is_empty(), "loading rule screen allowed the game to start")
	descent_title.set_descent_ready()
	_expect(descent_start != null and not descent_start.disabled and descent_start.text == "DESCEND", "Descent readiness did not enable DESCEND")
	await process_frame
	_expect(descent_start.has_focus(), "ready Descend button did not receive keyboard focus")
	_tap(KEY_SPACE)
	descent_start.pressed.emit()
	_expect(starts == [true], "ready Descend button did not start exactly once")
	await create_timer(0.6).timeout

	var continue_title := TitleScreen.new()
	continue_title.configure_descent_progress(true, 6, "the asylum")
	root.add_child(continue_title)
	await process_frame
	var progress_text := _page_text(continue_title, TitleScreen.Page.MAIN)
	for required in ["CONTINUE", "FLOOR 07", "ASYLUM", "RESTART DESCENT",
			"NEW DESCENT"]:
		_expect(progress_text.contains(required),
			"saved-run title is missing %s" % required)
	var continue_entries: Array[int] = []
	continue_title.descent_requested.connect(
		func(value: int): continue_entries.append(value))
	var continue_button := continue_title._primary_button as Button
	_expect(continue_button != null and continue_button.text == "CONTINUE F07", "saved-run primary button is not CONTINUE F07")
	continue_button.grab_focus()
	_tap(KEY_ENTER)
	_expect(continue_entries == [TitleScreen.DescentEntry.CONTINUE],
		"Enter did not select Continue for a saved run")
	continue_title.set_descent_ready()
	var continue_start := continue_title._descent_start_button as Button
	_expect(continue_start != null and not continue_start.disabled and continue_start.text == "CONTINUE", "Continue readiness did not enable CONTINUE")
	continue_title.free()

	for request in [[KEY_R, TitleScreen.DescentEntry.RESTART],
			[KEY_N, TitleScreen.DescentEntry.NEW]]:
		var action_title := TitleScreen.new()
		action_title.configure_descent_progress(true, 6, "the asylum")
		root.add_child(action_title)
		await process_frame
		var action_entries: Array[int] = []
		action_title.descent_requested.connect(
			func(value: int): action_entries.append(value))
		root.push_input(_key(request[0]))
		_expect(not is_instance_valid(action_title._entry_confirmation), "removed letter shortcut opened confirmation")
		var action_label := "RESTART DESCENT" if request[1] == TitleScreen.DescentEntry.RESTART else "NEW DESCENT"
		var action_button := _find_button(action_title, action_label)
		_expect(action_button != null, "saved-run action button missing")
		action_button.grab_focus()
		_tap(KEY_ENTER)
		_expect(action_entries.is_empty() and not action_title._descent_selected,
			"destructive action prepared a run before confirmation")
		_expect(is_instance_valid(action_title._entry_confirmation),
			"destructive action has no confirmation")
		if is_instance_valid(action_title._entry_confirmation):
			var expected_copy := "NEW BUILDING" if request[1] == TitleScreen.DescentEntry.NEW else "FLOOR 01"
			_expect(action_title._entry_confirmation.warning_text.contains(expected_copy),
				"confirmation does not distinguish restart from new building")
			root.push_input(_key(KEY_ESCAPE))
		await process_frame
		_expect(action_entries.is_empty() and not action_title._descent_selected
			and action_title._current_page == TitleScreen.Page.MAIN,
			"cancel changed checkpoint entry or left main menu")
		action_button.pressed.emit()
		if is_instance_valid(action_title._entry_confirmation):
			var dialog := action_title._entry_confirmation
			dialog._yes.pressed.emit()
			dialog._yes.pressed.emit()
		_expect(action_entries == [request[1]],
			"confirmed action did not request exactly one saved-run entry")
		action_title.free()

	var wander_title := TitleScreen.new()
	root.add_child(wander_title)
	await process_frame
	var wander_selected: Array[bool] = []
	var wander_started: Array[bool] = []
	wander_title.mode_selected.connect(
		func(value: bool): wander_selected.append(value))
	wander_title.started.connect(
		func(value: bool): wander_started.append(value))
	wander_title._select_wander()
	_expect(wander_selected == [false],
		"Wander selection did not emit mode_selected(false)")
	_expect(wander_started == [false],
		"Wander selection did not emit started(false)")
	await create_timer(0.6).timeout

	if failures == 0:
		print("title screen audit: PASS — menu, Instructions, About, Credits and Descent are distinct")
	else:
		print("title screen audit: FAIL — %d violations" % failures)
	quit(0 if failures == 0 else 1)
