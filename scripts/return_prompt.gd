class_name ReturnPrompt
extends CanvasLayer
## Safe, resizable confirmation shared by gameplay and destructive title actions.

signal confirmed
signal cancelled

var descent := false
var heading_text := ""
var warning_text := ""
var _done := false
var _yes: Button
var _no: Button
var _center: CenterContainer
var _column: VBoxContainer
var _heading: Label
var _warning: Label
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 6
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_center.add_child(_column)
	_heading = VhsOsd.make_label(58)
	_heading.text = heading_text if not heading_text.is_empty() else "RETURN TO TITLE?"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_heading)
	_warning = VhsOsd.make_label(31, VhsOsd.INK_DIM)
	_warning.text = warning_text if not warning_text.is_empty() else (
		"YOU CAN CONTINUE FROM YOUR DEEPEST FLOOR" if descent
		else "YOU WILL RETURN TO THE CASINO")
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_warning)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_buttons)
	_yes = _make_button("Y — YES", true)
	_no = _make_button("N / ESC — NO", false)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_no.call_deferred("grab_focus")


func _make_button(text: String, accept: bool) -> Button:
	var button := Button.new()
	button.text = text
	VhsOsd.style_button(button, 30)
	button.pressed.connect(_finish.bind(accept))
	_buttons.add_child(button)
	return button


func _relayout() -> void:
	var size := Vector2(get_viewport().size)
	var safe := VhsOsd.safe_inset(size)
	var scale := maxf(0.65, minf(size.y / 720.0, size.x / 960.0))
	_center.offset_left = safe.x
	_center.offset_right = -safe.x
	_center.offset_top = safe.y
	_center.offset_bottom = -safe.y
	_column.custom_minimum_size.x = minf(size.x - safe.x * 2.0, 1020.0 * scale)
	_column.add_theme_constant_override("separation", roundi(22.0 * scale))
	_heading.add_theme_font_size_override("font_size", maxi(32, roundi(58.0 * scale)))
	_warning.add_theme_font_size_override("font_size", maxi(22, roundi(31.0 * scale)))
	_buttons.add_theme_constant_override("separation", roundi(26.0 * scale))
	for button in [_yes, _no]:
		button.add_theme_font_size_override("font_size", maxi(22, roundi(30.0 * scale)))
		button.custom_minimum_size = Vector2(180.0 * scale, maxf(44.0, 58.0 * scale))


func _finish(accept: bool) -> void:
	if _done:
		return
	_done = true
	get_viewport().set_input_as_handled()
	if accept:
		confirmed.emit()
	else:
		cancelled.emit()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_Y:
		_finish(true)
	elif event.physical_keycode == KEY_N or event.physical_keycode == KEY_ESCAPE:
		_finish(false)


func _unhandled_input(_event: InputEvent) -> void:
	# Focused buttons receive GUI navigation first; nothing else reaches the game.
	get_viewport().set_input_as_handled()
