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
	check(menu._look_select.item_count == 4 and menu._look_select.selected == 2, "expected three camera looks and Camcorder selected")
	menu._select_tab("Video")
	for key in ["vhs_enabled", "vhs_distortion", "film_grain", "crt_enabled", "crt_shader", "video_pipeline"]:
		check(not menu._controls.has(key), "detailed video control leaked into the player menu: " + key)
	check(not is_instance_valid(menu._video_advanced), "developer controls constructed in player settings")
	menu._look_select.item_selected.emit(3)
	check(menu._look_select.selected == 3 and settings.get_value("vhs_enabled")
		and settings.get_value("crt_enabled"), "VHS on TV did not restore both stages")
	settings.set_value("film_grain", 0.23)
	settings.set_value("vhs_distortion", 0.37)
	var custom := settings.values.duplicate(true)
	check(menu._look_select.selected == 0, "adjusted camera look is not marked Custom")
	menu._preset_buttons[3].pressed.emit()
	settings.save_to_disk()
	var restored_world := GameSettings.new(path)
	for key: String in custom:
		if key not in GameSettings.QUALITY_KEYS and key != "quality_preset":
			check(restored_world.get_value(key) == custom[key], "graphics or reload changed camera settings: " + key)
	menu._look_select.item_selected.emit(1)
	check(not settings.get_value("vhs_enabled") and not settings.get_value("crt_enabled")
		and is_zero_approx(settings.get_value("film_grain")), "Clean left recording effects active")
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
	menu._select_tab("Video")
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		await settle()
		var bounds := Rect2(Vector2.ZERO, Vector2(extent))
		check(bounds.encloses(menu._panel.get_global_rect()), "pause panel clips at %s: %s" % [extent, menu._panel.get_global_rect()])
		for button in [menu._resume_button, menu._reset_button, menu._quit_button]:
			check(bounds.encloses(button.get_global_rect()) and button.size.y >= 44, "pause button clips or too short: %s at %s" % [button.text, extent])
		if DisplayServer.get_name() != "headless" and extent == Vector2i(1280, 720):
			menu._scroll.scroll_vertical = 0
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/liminal-video-menu-top.png")
		for control in [menu._preset_buttons[0], menu._look_select, menu._controls["frame_limit"]]:
			control.grab_focus()
			await settle()
			check(menu._scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),
				"video control cannot be reached at %s" % extent)
		if DisplayServer.get_name() != "headless" and extent == Vector2i(1280, 720):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/liminal-video-menu-controls.png")
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
