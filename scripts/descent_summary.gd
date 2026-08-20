class_name DescentSummary
extends CanvasLayer

signal continue_run
signal restart_run
signal new_run
signal leave

var won := false
var floor_idx := 0
var floor_display := ""
var elapsed := 0.0
var violations := 0
var world_seed := 1
var continue_floor_idx := 0
var _accept_input := false


func _ready() -> void:
	layer = 4
	var back := ColorRect.new()
	back.color = Color(0.003, 0.003, 0.003, 0.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.modulate.a = 0.0
	add_child(col)
	var floor_label := Label.new()
	floor_label.text = "OUT" if won else "CAUGHT — FLOOR %d — %s" % [
		floor_idx + 1, floor_display.to_upper()]
	_style(floor_label, 38, Color(0.92, 0.86, 0.72))
	col.add_child(floor_label)
	var details := Label.new()
	var minutes := floori(elapsed / 60.0)
	var seconds := floori(elapsed) % 60
	details.text = "%02d:%02d   ·   %d rule break%s" % [
		minutes, seconds, violations, "" if violations == 1 else "s"]
	_style(details, 22, Color(0.68, 0.65, 0.58))
	col.add_child(details)
	var seed_label := Label.new()
	seed_label.text = "seed %d" % world_seed
	_style(seed_label, 16, Color(0.42, 0.41, 0.39))
	col.add_child(seed_label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36
	col.add_child(gap)
	var prompt := Label.new()
	prompt.text = "SPACE  CONTINUE FLOOR %02d     R  RESTART RUN     N  NEW DESCENT     ESC  TITLE" % [
		continue_floor_idx + 1]
	_style(prompt, 18, Color(0.84, 0.78, 0.64))
	col.add_child(prompt)
	var tw := create_tween()
	tw.tween_property(back, "color:a", 0.98, 0.65)
	tw.tween_property(col, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _accept_input = true)


func _style(label: Label, base_size: int, color: Color) -> void:
	var scale := clampf(float(get_viewport().size.y) / 720.0, 0.75, 2.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(float(base_size) * scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", roundi(2.0 * scale))
	label.add_theme_constant_override("shadow_offset_y", roundi(2.0 * scale))
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", roundi(scale))


func _input(event: InputEvent) -> void:
	if not _accept_input or not event is InputEventKey \
			or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_SPACE:
		_accept_input = false
		get_viewport().set_input_as_handled()
		continue_run.emit()
	elif event.physical_keycode == KEY_R:
		_accept_input = false
		get_viewport().set_input_as_handled()
		restart_run.emit()
	elif event.physical_keycode == KEY_N:
		_accept_input = false
		get_viewport().set_input_as_handled()
		new_run.emit()
	elif event.physical_keycode == KEY_ESCAPE:
		_accept_input = false
		get_viewport().set_input_as_handled()
		leave.emit()
