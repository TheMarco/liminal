extends SceneTree
## Layout, live resizing and actual viewport input for both confirmation contexts.
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

func run() -> void:
	for mode in [0, 1, 2]:
		var prompt := ReturnPrompt.new()
		prompt.descent = mode != 0
		if mode == 2:
			prompt.heading_text = "REPLACE THIS DESCENT?"
			prompt.warning_text = "YOUR FLOOR 06 CHECKPOINT AND RUN PROGRESS WILL BE REPLACED.\nSTART AGAIN IN A NEW BUILDING?"
		root.add_child(prompt)
		for extent in [Vector2i(640, 480), Vector2i(1280, 720), Vector2i(720, 1280),
				Vector2i(1920, 1080), Vector2i(3840, 2160), Vector2i(640, 480)]:
			root.size = extent
			await settle()
			var safe := VhsOsd.safe_inset(Vector2(extent))
			var bounds := Rect2(safe - Vector2.ONE, Vector2(extent) - safe * 2 + Vector2.ONE * 2)
			for control: Control in [prompt._heading, prompt._warning, prompt._yes, prompt._no]:
				check(bounds.encloses(control.get_global_rect()), "mode %d %s: clipped %s %s" % [mode, extent, control.name, control.get_global_rect()])
			check(prompt._heading.get_global_rect().end.y <= prompt._warning.global_position.y,
				"heading overlaps warning at %s" % extent)
			check(prompt._warning.get_global_rect().end.y <= prompt._yes.global_position.y,
				"warning overlaps buttons at %s" % extent)
			check(prompt._no.size.y >= 44, "click target below 44 px")
		check(prompt._no.has_focus(), "safe No action is not focused by default")
		prompt.free()

	root.size = Vector2i(1280, 720)
	for action in ["Y", "N", "Escape", "default", "keyboard", "click"]:
		var prompt := ReturnPrompt.new()
		root.add_child(prompt)
		await settle()
		var results: Array[bool] = []
		prompt.confirmed.connect(func(): results.append(true))
		prompt.cancelled.connect(func(): results.append(false))
		root.push_input(key(KEY_Y, false))
		root.push_input(key(KEY_Y, true, true))
		check(results.is_empty(), "release/echo submitted modal")
		match action:
			"Y": root.push_input(key(KEY_Y))
			"N": root.push_input(key(KEY_N))
			"Escape": root.push_input(key(KEY_ESCAPE))
			"default":
				root.push_input(key(KEY_ENTER))
				root.push_input(key(KEY_ENTER, false))
			"keyboard":
				root.push_input(key(KEY_TAB))
				root.push_input(key(KEY_TAB, false))
				check(prompt._yes.has_focus(), "Tab did not move keyboard focus")
				root.push_input(key(KEY_ENTER))
				root.push_input(key(KEY_ENTER, false))
			"click":
				for pressed in [true, false]:
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.position = prompt._yes.get_global_rect().get_center()
					click.pressed = pressed
					root.push_input(click)
		root.push_input(key(KEY_Y))
		check(results == [action not in ["N", "Escape", "default"]], "action %s emitted %s" % [action, results])
		prompt.free()
	for failure in failures:
		push_error("RETURN_PROMPT_AUDIT: " + failure)
	print("RETURN_PROMPT_AUDIT: %d failures; 3 contexts, 6 live sizes, keyboard and mouse" % failures.size())
	quit(0 if failures.is_empty() else 1)
