class_name PauseMenu
extends CanvasLayer

signal resumed
signal return_to_title

var settings: GameSettings
var options_only := false

var _overlay: ColorRect
var _layout: Control
var _panel: PanelContainer
var _title: Label
var _controls: Dictionary = {}
var _resume_button: Button
var _scroll: ScrollContainer

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false

func setup(model: GameSettings, only_options: bool = false) -> void:
	settings = model
	options_only = only_options
	_build_ui()
	settings.changed.connect(_refresh_controls)

func open() -> void:
	visible = true
	call_deferred("_focus_resume")

func _focus_resume() -> void:
	if is_instance_valid(_resume_button):
		_resume_button.grab_focus()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.015, 0.01, 0.01, 0.78)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	# Lay out in logical pixels, then scale the entire menu together. A fixed
	# 560px panel was microscopic in the native Retina-sized game viewport.
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_layout)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	_layout.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(0, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = VhsOsd.make_label(40, Color(0.95, 0.92, 0.78))
	_title.text = "SETTINGS" if options_only else "PAUSED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for key: String in ["sensitivity", "field_of_view", "head_bob", "music_volume", "effects_volume", "vhs_distortion"]:
		_add_slider(rows, key)
	var check := CheckButton.new()
	check.text = "REDUCE FLASHING"
	check.add_theme_font_override("font", VhsOsd.FONT)
	check.add_theme_font_size_override("font_size", 24)
	check.custom_minimum_size.y = 38
	check.focus_mode = Control.FOCUS_ALL
	check.toggled.connect(func(v: bool) -> void: settings.set_value("reduced_flashing", v))
	rows.add_child(check)
	_controls["reduced_flashing"] = check
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.custom_minimum_size = Vector2(0, 48)
	column.add_child(buttons)
	_resume_button = _button("Resume" if not options_only else "Back", buttons)
	_resume_button.pressed.connect(_close_resume)
	var reset := _button("Reset defaults", buttons)
	reset.pressed.connect(func() -> void: settings.reset_defaults())
	if not options_only:
		var title_button := _button("Return to title", buttons)
		title_button.pressed.connect(_close_title)
	get_viewport().size_changed.connect(_fit_viewport)
	_scroll = scroll
	_fit_viewport()
	_refresh_controls()

func _fit_viewport() -> void:
	var extent := get_viewport().get_visible_rect().size
	# Match the game's 720p HUD datum. Width limits scaling in narrow windows;
	# low-resolution windows retain readable text and scroll the settings rows.
	var ui_scale := maxf(1.0, minf(extent.y / 720.0, extent.x / 900.0))
	var logical_size := extent / ui_scale
	_layout.scale = Vector2.ONE * ui_scale
	_layout.size = logical_size
	_panel.custom_minimum_size.x = minf(600.0, maxf(320.0, logical_size.x - 48.0))
	_scroll.custom_minimum_size.y = minf(480.0, maxf(120.0, logical_size.y - 220.0))

func _add_slider(parent: VBoxContainer, key: String) -> void:
	var row := VBoxContainer.new()
	var line := HBoxContainer.new()
	var label := VhsOsd.make_label(24)
	label.text = "MOUSE SENSITIVITY" if key == "sensitivity" else key.replace("_", " ").to_upper()
	line.add_child(label)
	var value_label := VhsOsd.make_label(24, Color(0.9, 0.75, 0.42))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(value_label)
	row.add_child(line)
	var slider := HSlider.new()
	slider.custom_minimum_size.y = 30
	var bounds: Vector2 = GameSettings.RANGES[key]
	slider.min_value = bounds.x
	slider.max_value = bounds.y
	slider.step = 0.01
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(v: float) -> void:
		settings.set_value(key, v)
		value_label.text = _format_value(key, v))
	row.add_child(slider)
	parent.add_child(row)
	_controls[key] = [slider, value_label]

func _button(text: String, parent: HBoxContainer) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", VhsOsd.FONT)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button

func _refresh_controls() -> void:
	if not settings:
		return
	for key: String in ["sensitivity", "field_of_view", "head_bob", "music_volume", "effects_volume", "vhs_distortion"]:
		var pair: Array = _controls[key]
		var slider: HSlider = pair[0]
		slider.set_value_no_signal(float(settings.get_value(key)))
		(pair[1] as Label).text = _format_value(key, float(settings.get_value(key)))
	(_controls["reduced_flashing"] as CheckButton).set_pressed_no_signal(bool(settings.get_value("reduced_flashing")))

func _format_value(key: String, value: float) -> String:
	if key == "field_of_view":
		return "%d°" % roundi(value)
	return "%.2f" % value if key == "sensitivity" else "%d%%" % roundi(value * 100.0)

func _close_resume() -> void:
	settings.save_to_disk()
	visible = false
	resumed.emit()

func _close_title() -> void:
	settings.save_to_disk()
	visible = false
	return_to_title.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_resume()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.04, 0.98)
	style.border_color = Color(0.55, 0.40, 0.24, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
