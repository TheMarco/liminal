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
	event.physical_keycode = code
	event.pressed = true
	return event


func _run() -> void:
	var title := TitleScreen.new()
	root.add_child(title)
	await process_frame

	var main_text := _page_text(title, TitleScreen.Page.MAIN)
	_expect(_only_page_visible(title, TitleScreen.Page.MAIN),
		"main title is not the sole visible page")
	for choice in ["WANDER", "DESCENT", "INSTRUCTIONS", "ABOUT", "CREDITS"]:
		_expect(main_text.contains(choice),
			"main title is missing %s" % choice)
	_expect(not main_text.contains("WASD"),
		"instructions leaked back onto the main title")

	title._show_instructions()
	var instructions := _page_text(title, TitleScreen.Page.INSTRUCTIONS)
	_expect(_only_page_visible(title, TitleScreen.Page.INSTRUCTIONS),
		"Instructions is not a separate visible page")
	for required in ["WASD", "WANDER", "DESCENT", "FLASHLIGHT"]:
		_expect(instructions.to_upper().contains(required),
			"Instructions is missing %s" % required)

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
			"Matt LeMoine", "carlcapu9", "THIRD_PARTY_ASSETS.md"]:
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
	descent_title.mode_selected.connect(
		func(value: bool): selected.append(value))
	descent_title._select_descent()
	_expect(selected == [true],
		"Descent selection did not emit mode_selected(true)")
	_expect(_only_page_visible(descent_title, TitleScreen.Page.DESCENT),
		"Descent selection did not open its rule briefing")
	descent_title.set_descent_ready()
	_expect(_page_text(descent_title, TitleScreen.Page.DESCENT).contains(
		"PRESS  SPACE  TO  DESCEND"),
		"Descent readiness prompt is missing")
	descent_title.free()

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
