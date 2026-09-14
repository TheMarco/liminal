extends SceneTree
## Actual input, initial fade gates and live resizing; no player saves.
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func settle() -> void:
	for frame in 6:
		await process_frame

func make_summary(cause := DescentRun.DeathCause.UNKNOWN, is_won := false, hint := true) -> DescentSummary:
	var summary := DescentSummary.new()
	summary.floor_idx = 9
	summary.floor_display = "THE DATA CENTER"
	summary.continue_floor_idx = 9
	summary.death_cause = cause
	summary.won = is_won
	summary.show_death_hint = hint
	root.add_child(summary)
	return summary

func finish_fade() -> void:
	# Advance the actual tween, including its input-unlock callback.
	for tween in get_processed_tweens():
		tween.custom_step(2.0)
	await settle()

func click(button: Button) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event)

func run() -> void:
	var run_state := DescentRun.new()
	run_state.finish(false, DescentRun.DeathCause.BLACKOUT_MOVEMENT)
	run_state.finish(false, DescentRun.DeathCause.FIGURE)
	check(run_state.death_cause == DescentRun.DeathCause.BLACKOUT_MOVEMENT, "a later callback overwrote the actual death cause")
	run_state.free()
	run_state = DescentRun.new()
	run_state.finish(true, DescentRun.DeathCause.FIGURE)
	check(run_state.death_cause == DescentRun.DeathCause.UNKNOWN, "a winning run retained a death cause")
	run_state.free()
	var summary := make_summary()
	await settle()
	check(summary._cause_hint == null, "unknown death cause showed explanation")
	# Both authored loss causes expose their static guidance; non-loss states do not.
	for cause in [DescentRun.DeathCause.FIGURE, DescentRun.DeathCause.BLACKOUT_MOVEMENT]:
		summary.free()
		summary = make_summary(cause)
		await settle()
		check(is_instance_valid(summary._cause_hint) and not summary._cause_hint.text.is_empty(),
			"known death cause did not show explanation")
		check(summary._cause_hint.text == DescentRun.death_explanation(cause),
			"known death cause explanation text drifted")
		for extent in [Vector2i(640, 480), Vector2i(720, 1280)]:
			root.size = extent
			await settle()
			var safe := VhsOsd.safe_inset(Vector2(extent))
			var bounds := Rect2(safe - Vector2.ONE, Vector2(extent) - safe * 2 + Vector2.ONE * 2)
			check(bounds.encloses(summary._cause_hint.get_global_rect()), "cause hint clips at %s" % extent)
		summary.free()
		root.size = Vector2i(1280, 720)
		summary = make_summary(DescentRun.DeathCause.FIGURE, true)
		await settle()
		check(summary._cause_hint == null, "win summary showed death explanation")
		summary.free()
		summary = make_summary(DescentRun.DeathCause.FIGURE, false, false)
	await settle()
	check(summary._cause_hint == null, "death explanation option did not hide hint")
	summary.free()
	summary = make_summary()
	check(not summary._accept_input and summary._button_list[0].disabled, "initial input gate missing")
	root.push_input(key(KEY_R))
	summary._button_list[1].pressed.emit()
	check(not summary._prompt_open, "input before fade opened confirmation")
	await finish_fade()
	check(summary._accept_input and summary._button_list[0].has_focus(), "fade did not enable and focus Continue")
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(1280, 720),
			Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		await settle()
		var safe := VhsOsd.safe_inset(Vector2(extent))
		var bounds := Rect2(safe - Vector2.ONE, Vector2(extent) - safe * 2 + Vector2.ONE * 2)
		for button in summary._button_list:
			check(bounds.encloses(button.get_global_rect()), "button clips at %s: %s" % [extent, button.get_global_rect()])
			check(button.size.y >= 44 and button.get_theme_font_size("font_size") >= 20, "button is too small")
		for entry in summary._labels:
			var label: Label = entry[0]
			check(bounds.encloses(label.get_global_rect()), "summary label clips at %s" % extent)
	summary.free()
	root.size = Vector2i(1280, 720)
	for index in [1, 2]:
		for method in ["key", "button", "mouse"]:
			summary = make_summary()
			await finish_fade()
			var actions: Array[String] = []
			summary.restart_run.connect(func(): actions.append("restart"))
			summary.new_run.connect(func(): actions.append("new"))
			if method == "key":
				root.push_input(key(KEY_R if index == 1 else KEY_N))
			elif method == "mouse":
				click(summary._button_list[index])
			else:
				summary._button_list[index].pressed.emit()
			await settle()
			check(actions.is_empty() and is_instance_valid(summary._active_prompt), "destructive action bypassed confirmation")
			if is_instance_valid(summary._active_prompt):
				check(summary._active_prompt.layer == 112 and summary._active_prompt._no.has_focus(), "confirmation layer/default focus wrong")
				var wording := "FLOOR 01" if index == 1 else "NEW BUILDING"
				check(summary._active_prompt.warning_text.contains(wording), "wrong confirmation wording")
				root.push_input(key(KEY_ESCAPE))
			await settle()
			check(actions.is_empty() and summary._button_list[index].has_focus(), "cancel did not restore safe summary")
			summary._button_list[index].pressed.emit()
			await settle()
			root.push_input(key(KEY_Y))
			root.push_input(key(KEY_Y))
			summary._button_list[index].pressed.emit()
			check(actions == ["restart" if index == 1 else "new"], "confirmed action emitted incorrectly")
			check(not summary._accept_input and summary._button_list[0].disabled, "committed summary remained active")
			summary.free()
	for action in ["continue_mouse", "continue_enter", "title_escape", "title_button", "tab_cancel"]:
		summary = make_summary()
		await finish_fade()
		var actions: Array[String] = []
		summary.continue_run.connect(func(): actions.append("continue"))
		summary.leave.connect(func(): actions.append("title"))
		match action:
			"continue_mouse": click(summary._button_list[0])
			"continue_enter":
				root.push_input(key(KEY_ENTER))
				root.push_input(key(KEY_ENTER, false))
			"title_escape": root.push_input(key(KEY_ESCAPE))
			"title_button": click(summary._button_list[3])
			"tab_cancel":
				root.push_input(key(KEY_TAB))
				root.push_input(key(KEY_TAB, false))
				check(summary._button_list[1].has_focus(), "Tab did not focus Restart")
				root.push_input(key(KEY_ENTER))
				root.push_input(key(KEY_ENTER, false))
				await settle()
				check(is_instance_valid(summary._active_prompt), "Enter did not open focused Restart")
				root.push_input(key(KEY_ENTER))
				root.push_input(key(KEY_ENTER, false))
				await settle()
				check(not summary._prompt_open and actions.is_empty(), "default No failed on Enter")
		if action != "tab_cancel":
			check(actions == ["continue" if action.begins_with("continue") else "title"], "mouse/keyboard action failed: " + action)
		summary.free()
	for failure in failures:
		push_error("DESCENT_SUMMARY_AUDIT: " + failure)
	print("DESCENT_SUMMARY_AUDIT: %d failures; fade gates, live bounds, confirmation, mouse and keyboard" % failures.size())
	quit(0 if failures.is_empty() else 1)
