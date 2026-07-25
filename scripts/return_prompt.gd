class_name ReturnPrompt
extends CanvasLayer
## Keyboard-only confirmation shown by Q during either playable mode.

signal confirmed
signal cancelled

var descent := false
var _done := false


func _ready() -> void:
	layer = 6
	var scale := clampf(float(get_viewport().size.y) / 720.0, 1.0, 1.8)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 210) * scale
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.012, 0.96)
	style.border_color = Color(0.76, 0.52, 0.25, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(roundi(7.0 * scale))
	style.content_margin_left = 42.0 * scale
	style.content_margin_right = 42.0 * scale
	style.content_margin_top = 30.0 * scale
	style.content_margin_bottom = 30.0 * scale
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", roundi(18.0 * scale))
	panel.add_child(col)

	var heading := Label.new()
	heading.text = "RETURN TO TITLE?"
	_style(heading, 34, Color(1.0, 0.82, 0.56))
	col.add_child(heading)

	var warning := Label.new()
	warning.text = "CURRENT DESCENT WILL END" if descent \
		else "YOU WILL RETURN TO THE CASINO"
	_style(warning, 18, Color(0.58, 0.54, 0.47))
	col.add_child(warning)

	var answer := Label.new()
	answer.text = "Y  —  YES                 N  —  NO"
	_style(answer, 22, Color(0.90, 0.84, 0.73))
	col.add_child(answer)


func _style(label: Label, base_size: int, color: Color) -> void:
	var scale := clampf(float(get_viewport().size.y) / 720.0, 1.0, 1.8)
	var terminal_font: Font = load("res://fonts/VT323-Regular.ttf")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", terminal_font)
	label.add_theme_font_size_override("font_size",
		roundi(float(base_size) * scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", roundi(2.0 * scale))


func _input(event: InputEvent) -> void:
	if _done or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_Y:
		_done = true
		get_viewport().set_input_as_handled()
		confirmed.emit()
	elif event.physical_keycode == KEY_N \
			or event.physical_keycode == KEY_ESCAPE:
		_done = true
		get_viewport().set_input_as_handled()
		cancelled.emit()
