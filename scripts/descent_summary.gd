class_name DescentSummary
extends CanvasLayer

signal continue_run
signal restart_run
signal new_run
signal leave

var won := false
var from_black := false
var floor_idx := 0
var floor_display := ""
var elapsed := 0.0
var death_cause := DescentRun.DeathCause.UNKNOWN
var show_death_hint := true
var _cause_hint: Label
var world_seed := 1
var continue_floor_idx := 0
var _accept_input := false
var _labels: Array[Array] = []
var _column: VBoxContainer
var _gap: Control
var _buttons: GridContainer
var _button_list: Array[Button] = []
var _prompt_open := false
var _trigger_button: Button
var _active_prompt: ReturnPrompt


func _ready() -> void:
	layer = 4
	var back := ColorRect.new()
	back.color = Color(0.003, 0.003, 0.003, 0.98 if from_black else 0.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var col := VBoxContainer.new()
	_column = col
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.modulate.a = 0.0
	add_child(col)
	var floor_label := Label.new()
	floor_label.text = "OUT" if won else "CAUGHT — FLOOR %d — %s" % [
		floor_idx + 1, floor_display.to_upper()]
	_style(floor_label, 56, Color(0.92, 0.86, 0.72))
	col.add_child(floor_label)
	var details := Label.new()
	var minutes := floori(elapsed / 60.0)
	var seconds := floori(elapsed) % 60
	details.text = "%02d:%02d" % [minutes, seconds]
	_style(details, 34, Color(0.68, 0.65, 0.58))
	col.add_child(details)
	var explanation := DescentRun.death_explanation(death_cause)
	if not won and show_death_hint and not explanation.is_empty():
		_cause_hint = Label.new()
		_cause_hint.text = explanation
		_style(_cause_hint, 26, Color(0.78, 0.72, 0.61))
		col.add_child(_cause_hint)
	var seed_label := Label.new()
	seed_label.text = "seed %d" % world_seed
	_style(seed_label, 26, Color(0.42, 0.41, 0.39))
	col.add_child(seed_label)
	var gap := Control.new()
	_gap = gap
	gap.custom_minimum_size.y = 36
	col.add_child(gap)
	_buttons = GridContainer.new()
	_buttons.columns = 2
	_buttons.add_theme_constant_override("h_separation", 18)
	_buttons.add_theme_constant_override("v_separation", 12)
	col.add_child(_buttons)
	_add_button("SPACE — CONTINUE F%02d" % (continue_floor_idx + 1), "continue")
	_add_button("R — RESTART RUN", "restart")
	_add_button("N — NEW DESCENT", "new")
	_add_button("ESC — TITLE", "title")
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	var tw := create_tween()
	tw.tween_property(back, "color:a", 0.98, 0.65)
	tw.tween_property(col, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func():
		_accept_input = true
		for button in _button_list:
			button.disabled = false
		if _button_list.size() > 0:
			_button_list[0].grab_focus()
	)


func _add_button(text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VhsOsd.style_button(button, 30)
	button.pressed.connect(_button_action.bind(action, button))
	_button_list.append(button)
	_buttons.add_child(button)


func _style(label: Label, base_size: int, color: Color) -> void:
	_labels.append([label, base_size])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", VhsOsd.FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_color_override("font_outline_color", color)


func _relayout() -> void:
	var viewport := Vector2(get_viewport().size)
	var scale := clampf(minf(viewport.x / 1280.0, viewport.y / 720.0), 0.55, 3.0)
	var safe := VhsOsd.safe_inset(viewport)
	_column.offset_left = safe.x
	_column.offset_right = -safe.x
	_column.offset_top = safe.y
	_column.offset_bottom = -safe.y
	_column.add_theme_constant_override("separation", roundi(16.0 * scale))
	_gap.custom_minimum_size.y = 36.0 * scale
	_buttons.custom_minimum_size.x = minf(900.0 * scale, viewport.x - safe.x * 2.0)
	for button in _button_list:
		button.add_theme_font_size_override("font_size", maxi(20, roundi(30.0 * scale)))
		button.custom_minimum_size = Vector2(maxf(44.0, 300.0 * scale), maxf(44.0, 64.0 * scale))
	for entry in _labels:
		var label: Label = entry[0]
		label.add_theme_font_size_override("font_size", roundi(float(entry[1]) * scale))
		label.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(2.0 * scale)))
		label.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(2.0 * scale)))
		label.add_theme_constant_override("outline_size", maxi(1, roundi(scale)))


func _input(event: InputEvent) -> void:
	if _prompt_open:
		return
	if not _accept_input or not event is InputEventKey \
			or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		_button_action("continue", _button_list[0])
	elif event.physical_keycode == KEY_R:
		_button_action("restart", _button_list[1])
	elif event.physical_keycode == KEY_N:
		_button_action("new", _button_list[2])
	elif event.physical_keycode == KEY_ESCAPE:
		_button_action("title", _button_list[3])


func _button_action(action: String, source: Button) -> void:
	if not _accept_input or _prompt_open:
		return
	get_viewport().set_input_as_handled()
	if action == "continue":
		_accept_input = false
		_disable_buttons()
		continue_run.emit()
	elif action == "title":
		_accept_input = false
		_disable_buttons()
		leave.emit()
	else:
		_prompt_open = true
		_trigger_button = source
		_disable_buttons()
		var prompt := ReturnPrompt.new()
		prompt.descent = true
		prompt.heading_text = "RESTART RUN?" if action == "restart" else "NEW DESCENT?"
		prompt.warning_text = ("START AGAIN FROM FLOOR 01?\nYOUR CURRENT CHECKPOINT AND RUN PROGRESS WILL BE REPLACED." if action == "restart"
			else "START AGAIN IN A NEW BUILDING?\nYOUR CURRENT CHECKPOINT AND RUN PROGRESS WILL BE REPLACED.")
		prompt.confirmed.connect(_confirm_destructive.bind(action, prompt))
		prompt.cancelled.connect(_cancel_destructive.bind(prompt))
		prompt.ready.connect(func(): prompt.layer = 112)
		add_child(prompt)
		_active_prompt = prompt


func _disable_buttons() -> void:
	for button in _button_list:
		button.disabled = true


func _confirm_destructive(action: String, prompt: ReturnPrompt) -> void:
	_accept_input = false
	prompt.queue_free()
	_active_prompt = null
	if action == "restart":
		restart_run.emit()
	else:
		new_run.emit()


func _cancel_destructive(prompt: ReturnPrompt) -> void:
	prompt.queue_free()
	_active_prompt = null
	_prompt_open = false
	_accept_input = true
	for button in _button_list:
		button.disabled = false
	if is_instance_valid(_trigger_button):
		_trigger_button.call_deferred("grab_focus")
