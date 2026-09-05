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
var _labels: Array[Array] = []
var _column: VBoxContainer
var _gap: Control


func _ready() -> void:
	layer = 4
	var back := ColorRect.new()
	back.color = Color(0.003, 0.003, 0.003, 0.0)
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
	details.text = "%02d:%02d   ·   %d rule break%s" % [
		minutes, seconds, violations, "" if violations == 1 else "s"]
	_style(details, 34, Color(0.68, 0.65, 0.58))
	col.add_child(details)
	var seed_label := Label.new()
	seed_label.text = "seed %d" % world_seed
	_style(seed_label, 26, Color(0.42, 0.41, 0.39))
	col.add_child(seed_label)
	var gap := Control.new()
	_gap = gap
	gap.custom_minimum_size.y = 36
	col.add_child(gap)
	var prompt := Label.new()
	prompt.text = "SPACE  CONTINUE FLOOR %02d     R  RESTART RUN\nN  NEW DESCENT     ESC  TITLE" % [
		continue_floor_idx + 1]
	_style(prompt, 34, Color(0.84, 0.78, 0.64))
	col.add_child(prompt)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	var tw := create_tween()
	tw.tween_property(back, "color:a", 0.98, 0.65)
	tw.tween_property(col, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _accept_input = true)


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
	for entry in _labels:
		var label: Label = entry[0]
		label.add_theme_font_size_override("font_size", roundi(float(entry[1]) * scale))
		label.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(2.0 * scale)))
		label.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(2.0 * scale)))
		label.add_theme_constant_override("outline_size", maxi(1, roundi(scale)))


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
