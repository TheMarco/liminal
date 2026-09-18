extends SceneTree
## Real viewport input and live layout, with an isolated settings file.
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)

func settle() -> void:
	for frame in 6: await process_frame

func focus_action(title: TitleScreen, text: String) -> void:
	for button in title._pages[TitleScreen.Page.MAIN].find_children("*", "Button", true, false):
		if button.text == text:
			button.grab_focus()
			return
	check(false, "missing title action: " + text)

func run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var path := "/tmp/liminal-menu-audit-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	settings.set_value("sensitivity", 1.73)
	var menu := PauseMenu.new()
	root.add_child(menu)
	menu.setup(settings)
	menu.open()
	paused = true
	await settle()
	check(menu._controls.has("vhs_enabled") and menu._controls.has("crt_enabled"),
		"gameplay settings do not expose separate VHS and CRT toggles")
	check((menu._controls["vhs_enabled"] as CheckButton).button_pressed
		and (menu._controls["crt_enabled"] as CheckButton).button_pressed,
		"gameplay settings do not present the restored VHS + CRT defaults")
	var settings_labels := ""
	for label in menu.find_children("*", "Label", true, false):
		settings_labels += (label as Label).text + "\n"
	check(settings_labels.contains("VHS EFFECT STRENGTH"),
		"settings still use the old VHS distortion label")
	var resumes: Array[bool] = []
	var quits: Array[bool] = []
	menu.resumed.connect(func(): resumes.append(true))
	menu.quit_requested.connect(func(): quits.append(true))
	menu._reset_button.grab_focus()
	tap(KEY_ENTER)
	await settle()
	check(is_instance_valid(menu._reset_prompt) and menu._reset_prompt.layer > menu.layer, "reset confirmation missing or underneath menu")
	tap(KEY_ESCAPE)
	await settle()
	check(not is_instance_valid(menu._reset_prompt) and menu.visible and resumes.is_empty(), "cancel reset closed pause menu")
	check(is_equal_approx(settings.get_value("sensitivity"), 1.73), "cancel reset changed settings")
	check(menu._reset_button.has_focus(), "cancel reset lost keyboard focus")
	tap(KEY_ENTER)
	await settle()
	tap(KEY_Y)
	await settle()
	check(is_equal_approx(settings.get_value("sensitivity"), GameSettings.DEFAULTS.sensitivity), "confirm reset did not restore defaults")
	check(menu._reset_button.has_focus(), "confirm reset lost keyboard focus")
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		await settle()
		var bounds := Rect2(Vector2.ZERO, Vector2(extent))
		check(bounds.encloses(menu._panel.get_global_rect()), "pause panel clips at %s: %s" % [extent, menu._panel.get_global_rect()])
		for button in [menu._resume_button, menu._reset_button, menu._quit_button]:
			check(bounds.encloses(button.get_global_rect()) and button.size.y >= 44, "pause button clips or too short: %s at %s" % [button.text, extent])
		if DisplayServer.get_name() != "headless" and extent == Vector2i(640, 480):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/liminal-round3-pause-proof.png")
	menu._quit_button.grab_focus()
	tap(KEY_ENTER)
	menu._close_quit()
	check(quits == [true], "quit did not emit exactly once")
	menu.open()
	menu._close_quit()
	check(quits.size() == 2, "reopened menu could not request quit again")
	menu.free()
	paused = false
	for saved in [false, true]:
		var title := TitleScreen.new()
		title.configure_descent_progress(saved, 6, "the asylum")
		root.add_child(title)
		await settle()
		for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(3840, 2160), Vector2i(640, 480)]:
			root.size = extent
			await settle()
			for button in title._pages[TitleScreen.Page.MAIN].find_children("*", "Button", true, false):
				check(Rect2(Vector2.ZERO, Vector2(extent)).encloses(button.get_global_rect()), "title button clips: %s at %s" % [button.text, extent])
			if DisplayServer.get_name() != "headless" and extent == Vector2i(1280, 720) and saved:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/liminal-round3-title-proof.png")
		tap(KEY_TAB)
		await settle()
		var focused := root.gui_get_focus_owner() as Button
		check(focused != null and focused == title._primary_button, "Tab does not initially focus primary Descent control")
		tap(KEY_C)
		await settle()
		check(title._current_page == TitleScreen.Page.MAIN, "letter shortcut unexpectedly changed title page")
		focus_action(title, "CREDITS")
		tap(KEY_ENTER)
		await settle()
		check(title._current_page == TitleScreen.Page.CREDITS and root.gui_get_focus_owner().is_visible_in_tree(), "Credits button did not open page with visible focus")
		tap(KEY_ESCAPE)
		await settle()
		check(title._current_page == TitleScreen.Page.MAIN, "Escape did not return to main")
		if saved:
			tap(KEY_N)
			await settle()
			check(title._current_page == TitleScreen.Page.MAIN and not is_instance_valid(title._entry_confirmation), "letter shortcut unexpectedly opened new run")
			focus_action(title, "NEW DESCENT")
			tap(KEY_ENTER)
			await settle()
			check(is_instance_valid(title._entry_confirmation), "New Descent button bypassed confirmation")
			tap(KEY_ESCAPE)
			await settle()
			check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "cancel new run lost title keyboard focus")
			title._focus_page_control(TitleScreen.Page.MAIN)
		var selected: Array[int] = []
		title.descent_requested.connect(func(entry: int): selected.append(entry))
		title._primary_button.grab_focus()
		tap(KEY_ENTER)
		check(selected == [TitleScreen.DescentEntry.CONTINUE if saved else TitleScreen.DescentEntry.NEW], "focused Descent did not activate through GUI")
		title.free()
	DirAccess.remove_absolute(path)
	for failure in failures: push_error(failure)
	print("round3 menu audit: %d failures; reset, keyboard navigation, quit, five live sizes" % failures.size())
	quit(0 if failures.is_empty() else 1)
