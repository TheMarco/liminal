class_name ReturnPrompt
extends CanvasLayer
## Keyboard-only confirmation shown by Q during either playable mode.

signal confirmed
signal cancelled

var descent := false
var _done := false


func _ready() -> void:
	layer = 6
	# OSD idiom: unclamped HUD scale and stroked phosphor text, sized to be
	# read THROUGH the tube — the old 1.8-clamped panel was illegible on
	# large displays in CRT mode (2026-08-19).
	var scale := VhsOsd.hud_scale(Vector2(get_viewport().size))
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", roundi(26.0 * scale))
	center.add_child(col)

	var heading := VhsOsd.make_label(roundi(64.0 * scale))
	heading.text = "RETURN TO TITLE?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(heading)

	var warning := VhsOsd.make_label(roundi(34.0 * scale), VhsOsd.INK_DIM)
	warning.text = "YOU CAN CONTINUE FROM YOUR DEEPEST FLOOR" if descent \
		else "YOU WILL RETURN TO THE CASINO"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(warning)

	var answer := VhsOsd.make_label(roundi(44.0 * scale))
	answer.text = "Y — YES        N — NO"
	answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(answer)


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
