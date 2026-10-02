class_name PauseMenu
extends CanvasLayer

signal resumed
signal return_to_title
signal quit_requested

var settings: GameSettings
var options_only := false
var allow_return_to_title := true
var allow_quit := true

var _overlay: ColorRect
var _layout: Control
var _panel: PanelContainer
var _title: Label
var _controls: Dictionary = {}
var _resume_button: Button
var _reset_button: Button
var _quit_button: Button
var _reset_prompt: ReturnPrompt
var _quit_emitted := false
var _scroll: ScrollContainer
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tabs: GridContainer
var _footer: GridContainer
var _current_tab := "Graphics"
var _preset_buttons: Array[Button] = []
var _quality_status: Label
var _advanced: VBoxContainer
var _advanced_button: Button
var _display_grid: GridContainer
var _hdr_group: VBoxContainer
var _hdr_status: Label
var _binding_buttons: Dictionary = {}
var _binding_status: Label
var _capturing := ""

const SLIDER_KEYS := ["sensitivity", "field_of_view", "head_bob", "handheld_strength",
	"music_volume", "effects_volume", "dialogue_volume", "vhs_distortion",
	"film_grain", "hdr_brightness"]

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
	_quit_emitted = false
	_capturing = ""
	visible = true
	call_deferred("_focus_resume")

func _focus_resume() -> void:
	if is_instance_valid(_resume_button):
		_resume_button.grab_focus()

const TABS := ["Graphics", "Visual Effects", "Controls", "Audio", "Accessibility"]
const CREAM := Color(0.94, 0.90, 0.78)
const GOLD := Color(0.88, 0.72, 0.43)
const MUTED := Color(0.65, 0.66, 0.61)
const OPTION_LABELS := {
	"render_resolution": ["360p", "480p", "720p", "1080p", "1440p", "Native"],
	"anti_aliasing": ["Off", "FXAA", "TAA", "2× MSAA", "4× MSAA", "TAA + 4× MSAA"],
	"shadow_quality": ["Low", "Medium", "High", "Ultra"],
	"global_illumination": ["Off", "Balanced", "High"],
	"ambient_occlusion": ["Off", "Low", "High"],
	"reflections": ["Off", "Low", "High"],
	"volumetric_fog": ["Off", "Low", "High"],
	"frame_limit": ["Unlimited", "30 FPS", "60 FPS", "90 FPS", "120 FPS", "144 FPS"],
}
const QUALITY_NOTES := [
	"For slower GPUs. 360p, simple shadows, direct lighting and distance fog.",
	"Balanced performance. 480p, soft shadows and light contact shading.",
	"Richer lighting. 720p, bounce light, reflections and volumetric fog.",
	"Maximum detail. Native resolution, full lighting and higher-quality shadows. Heavy GPU load.",
	"Custom rendering options. Select a preset to replace these graphics choices.",
]

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.012, 0.013, 0.012, 0.90)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_layout)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	_layout.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("SETTINGS", 38, CREAM)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var state := _label("OPTIONS" if options_only else "GAME PAUSED", 20, MUTED)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(state)
	_tabs = GridContainer.new()
	_tabs.columns = 5
	_tabs.add_theme_constant_override("h_separation", 4)
	_tabs.add_theme_constant_override("v_separation", 4)
	column.add_child(_tabs)
	for tab: String in TABS:
		var button := _button(tab, _tabs)
		button.add_theme_font_size_override("font_size", 22)
		button.toggle_mode = true
		button.pressed.connect(_select_tab.bind(tab))
		_tab_buttons[tab] = button
	var page_host := VBoxContainer.new()
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(page_host)
	for tab: String in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = tab.replace(" ", "")
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.follow_focus = true
		page_host.add_child(scroll)
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 10)
		scroll.add_child(rows)
		_pages[tab] = scroll
		match tab:
			"Graphics": _build_graphics(rows)
			"Visual Effects": _build_effects(rows)
			"Controls": _build_controls(rows)
			"Audio": _build_audio(rows)
			"Accessibility": _build_accessibility(rows)
	column.add_child(HSeparator.new())
	var save_note := _label("APPLIED LIVE · SAVED WHEN YOU CLOSE · ESC TO GO BACK", 18, MUTED)
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(save_note)
	_footer = GridContainer.new()
	_footer.columns = 4
	_footer.add_theme_constant_override("h_separation", 8)
	_footer.add_theme_constant_override("v_separation", 8)
	column.add_child(_footer)
	_resume_button = _button("Back" if options_only else "Resume", _footer)
	_resume_button.pressed.connect(_close_resume)
	_reset_button = _button("Reset defaults", _footer)
	_reset_button.pressed.connect(_ask_reset)
	if not options_only and allow_return_to_title:
		var title_button := _button("Return to title", _footer)
		title_button.pressed.connect(_close_title)
	if not options_only and allow_quit:
		_quit_button = _button("Quit", _footer)
		_quit_button.pressed.connect(_close_quit)
	get_viewport().size_changed.connect(_fit_viewport)
	var window := get_window()
	if window != null and window.has_signal("output_max_linear_value_changed"):
		window.connect("output_max_linear_value_changed",
			func(_value: float) -> void: _refresh_hdr_controls())
	_select_tab(_current_tab)
	_fit_viewport()
	_refresh_controls()

func _label(text: String, font_size: int, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", VhsOsd.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _section(parent: VBoxContainer, text: String, note := "") -> void:
	var heading := _label(text.to_upper(), 22, GOLD)
	heading.custom_minimum_size.y = 30
	parent.add_child(heading)
	if not note.is_empty():
		_note(parent, note)

func _note(parent: VBoxContainer, text: String) -> Label:
	var label := _label(text, 19, MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _build_graphics(rows: VBoxContainer) -> void:
	rows.add_theme_constant_override("separation", 8)
	_section(rows, "Quality preset")
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	rows.add_child(presets)
	for i in 4:
		var button := _button(GameSettings.QUALITY_NAMES[i], presets)
		button.toggle_mode = true
		button.pressed.connect(func(): settings.apply_quality_preset(i))
		_preset_buttons.append(button)
	_quality_status = _note(rows, "")
	_add_option(rows, "render_resolution", "3D resolution", "Limits world resolution; menus stay sharp. Higher values cost more GPU time.")
	_advanced_button = _button("Advanced rendering  +", rows)
	_advanced_button.pressed.connect(func():
		_advanced.visible = not _advanced.visible
		_advanced_button.text = "Advanced rendering  −" if _advanced.visible else "Advanced rendering  +")
	_advanced = VBoxContainer.new()
	_advanced.add_theme_constant_override("separation", 8)
	rows.add_child(_advanced)
	_advanced.visible = false
	_add_option(_advanced, "anti_aliasing", "Anti-aliasing", "Smooths edges. TAA can soften motion; MSAA costs additional GPU memory.")
	_add_option(_advanced, "shadow_quality", "Shadow quality", "Resolution and softness of real-time shadows.")
	_add_option(_advanced, "global_illumination", "Bounce lighting", "Indirect light and colour bleed. Turning this off reduces work when entering new rooms.")
	_add_option(_advanced, "ambient_occlusion", "Contact shading", "Adds depth where surfaces meet.")
	_add_option(_advanced, "reflections", "Screen reflections", "Reflections of visible surfaces; static water reflections remain available.")
	_add_option(_advanced, "volumetric_fog", "Volumetric fog", "Light shafts and lit haze. Distance fog remains in every mode.")
	_section(rows, "Display")
	_display_grid = GridContainer.new()
	_display_grid.add_theme_constant_override("h_separation", 16)
	rows.add_child(_display_grid)
	for entry in [["fullscreen", "FULLSCREEN"], ["vsync", "VERTICAL SYNC"]]:
		var group := VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_display_grid.add_child(group)
		_add_toggle(group, entry[0], entry[1])
	_controls["vsync"].tooltip_text = "Synchronizes frames with the display to prevent tearing."
	_add_option(rows, "frame_limit", "Frame limit", "A cap reduces GPU load, heat and power use. Independent of the quality preset.")
	var calibration := _button("HDR calibration  +", rows)
	calibration.pressed.connect(func():
		_hdr_group.visible = not _hdr_group.visible
		calibration.text = "HDR calibration  −" if _hdr_group.visible else "HDR calibration  +")
	_hdr_group = VBoxContainer.new()
	_hdr_group.add_theme_constant_override("separation", 8)
	rows.add_child(_hdr_group)
	_hdr_group.visible = false
	_add_toggle(_hdr_group, "hdr_enabled", "HDR OUTPUT")
	_controls["hdr_enabled"].tooltip_text = "Uses HDR on supported HDR/XDR displays; other displays use SDR."
	_add_slider(_hdr_group, "hdr_brightness")
	_hdr_status = _note(_hdr_group, "")

func _build_effects(rows: VBoxContainer) -> void:
	_section(rows, "Recorded image", "These choices shape the footage and stay independent of the graphics preset.")
	_add_toggle(rows, "vhs_enabled", "VHS EFFECT")
	_controls["vhs_enabled"].tooltip_text = "Tape smearing, colour separation, signal noise and tracking damage."
	_add_slider(rows, "vhs_distortion")
	_add_slider(rows, "film_grain")
	_controls["film_grain"][0].tooltip_text = "Fine, gently moving film texture. Works independently of VHS and CRT."
	_section(rows, "Tube display")
	_add_toggle(rows, "crt_enabled", "CRT EFFECT")
	_controls["crt_enabled"].tooltip_text = "480p television source, scan beam, phosphor mask, halation and glass falloff."
	_add_toggle(rows, "crt_curvature", "SCREEN CURVATURE")
	_controls["crt_curvature"].tooltip_text = "Bends the image like a curved tube. Off keeps a flat screen."

func _build_controls(rows: VBoxContainer) -> void:
	_section(rows, "Mouse & movement")
	_add_slider(rows, "sensitivity")
	_add_toggle(rows, "invert_y", "INVERT Y LOOK")
	_add_toggle(rows, "toggle_sprint", "TOGGLE SPRINT")
	_add_controls_section(rows)

func _build_audio(rows: VBoxContainer) -> void:
	_section(rows, "Volume", "Balance music, environmental sounds and spoken recordings separately.")
	for key in ["music_volume", "effects_volume", "dialogue_volume"]:
		_add_slider(rows, key)

func _build_accessibility(rows: VBoxContainer) -> void:
	_section(rows, "Camera comfort")
	_add_slider(rows, "field_of_view")
	_add_slider(rows, "head_bob")
	_add_toggle(rows, "handheld_camera", "HANDHELD CAMERA")
	_controls["handheld_camera"].tooltip_text = "Smooth found-footage drift and stronger motion during scares."
	_add_slider(rows, "handheld_strength")
	_section(rows, "Readability & assistance")
	_add_toggle(rows, "reduced_flashing", "REDUCE FLASHING")
	_add_toggle(rows, "story_subtitles", "STORY SUBTITLES")
	_controls["story_subtitles"].tooltip_text = "Spoken recording dialogue, synchronized to playback."
	_add_toggle(rows, "death_hints", "EXPLAIN CAUSE OF DEATH")

func _add_option(parent: VBoxContainer, key: String, title: String, help: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(title, 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(190, 44)
	_style_button(select)
	select.get_popup().add_theme_font_override("font", VhsOsd.FONT)
	select.get_popup().add_theme_font_size_override("font_size", 24)
	select.tooltip_text = help
	for i in OPTION_LABELS[key].size():
		select.add_item(OPTION_LABELS[key][i], GameSettings.ENUM_VALUES[key][i])
	select.item_selected.connect(func(index: int): settings.set_value(key, select.get_item_id(index)))
	row.add_child(select)
	parent.add_child(row)
	_controls[key] = select

func _select_tab(tab: String) -> void:
	_capturing = ""
	_refresh_binding_buttons()
	if is_instance_valid(_binding_status):
		_binding_status.text = ""
	_current_tab = tab
	for name: String in TABS:
		(_pages[name] as ScrollContainer).visible = name == tab
		var button := _tab_buttons[name] as Button
		button.set_pressed_no_signal(name == tab)
	_scroll = _pages[tab]

func _fit_viewport() -> void:
	var extent := get_viewport().get_visible_rect().size
	var ui_scale := maxf(1.0, minf(extent.y / 720.0, extent.x / 1000.0))
	var logical_size := extent / ui_scale
	_layout.scale = Vector2.ONE * ui_scale
	_layout.size = logical_size
	_panel.custom_minimum_size.x = minf(900.0, maxf(300.0, logical_size.x - 48.0))
	var narrow := logical_size.x < 760.0
	_tabs.columns = 3 if narrow else 5
	_footer.columns = 2 if narrow else mini(4, _footer.get_child_count())
	_display_grid.columns = 1 if narrow else 2
	for page: ScrollContainer in _pages.values():
		page.custom_minimum_size.y = maxf(80.0, minf(420.0, logical_size.y - (400.0 if narrow else 250.0)))

func _add_slider(parent: VBoxContainer, key: String) -> void:
	var row := VBoxContainer.new()
	var line := HBoxContainer.new()
	var label := _label("", 24)
	label.text = "MOUSE SENSITIVITY" if key == "sensitivity" \
		else ("VHS EFFECT STRENGTH" if key == "vhs_distortion" \
		else ("FILM GRAIN" if key == "film_grain" \
		else ("HANDHELD STRENGTH" if key == "handheld_strength" \
		else key.replace("_", " ").to_upper())))
	line.add_child(label)
	var value_label := _label("", 24, GOLD)
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

func _add_toggle(parent: VBoxContainer, key: String, text: String) -> void:
	var check := CheckButton.new()
	check.text = text
	check.add_theme_font_override("font", VhsOsd.FONT)
	check.add_theme_font_size_override("font_size", 24)
	check.custom_minimum_size.y = 44
	check.focus_mode = Control.FOCUS_ALL
	if key == "toggle_sprint":
		check.tooltip_text = _sprint_tooltip()
	check.toggled.connect(func(value: bool): settings.set_value(key, value))
	parent.add_child(check)
	_controls[key] = check

func _sprint_tooltip() -> String:
	return "Tap %s to sprint; tap again or stop moving to walk. Pausing and exhaustion reset the toggle." % GameInput.primary_hint("sprint", settings)

func _add_controls_section(parent: VBoxContainer) -> void:
	var heading := _label("KEY BINDINGS", 22, GOLD)
	heading.text = "KEY BINDINGS"
	parent.add_child(heading)
	var note := _label("", 18, MUTED)
	note.text = "ARROWS ALSO WALK · RIGHT CLICK RAISES THE CAMERA · LEFT CLICK TAKES THE PHOTO · ESC IS FIXED"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	for action in GameInput.ACTIONS:
		_add_binding_row(parent, action)
	_binding_status = _label("", 18, Color(0.95, 0.55, 0.45))
	_binding_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_binding_status.custom_minimum_size.y = 26
	parent.add_child(_binding_status)

func _add_binding_row(parent: VBoxContainer, action: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label("", 24)
	label.text = str(GameInput.DISPLAY_NAMES.get(action, action.to_upper()))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_button(button)
	button.pressed.connect(_start_capture.bind(action))
	row.add_child(button)
	parent.add_child(row)
	_binding_buttons[action] = button

func _refresh_binding_buttons() -> void:
	for action in GameInput.ACTIONS:
		var button := _binding_buttons.get(action) as Button
		if not is_instance_valid(button):
			continue
		button.text = "PRESS KEY..." if _capturing == action \
			else GameInput.primary_label(action, settings)

func _start_capture(action: String) -> void:
	if is_instance_valid(_reset_prompt):
		return
	_capturing = action
	_refresh_binding_buttons()
	if is_instance_valid(_binding_status):
		_binding_status.text = "PRESS A KEY FOR %s · ESC CANCELS" % GameInput.DISPLAY_NAMES.get(action, action)
	var button := _binding_buttons.get(action) as Button
	if is_instance_valid(button):
		button.grab_focus()

## True when the event belonged to key capture. Escape cancels; a rejected
## key keeps capturing so the user can pick another free key.
func _capture_key(event: InputEvent) -> bool:
	if _capturing.is_empty():
		return false
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return true
	var code: Key = key.physical_keycode \
		if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_ESCAPE or code == KEY_NONE:
		_capturing = ""
		if is_instance_valid(_binding_status):
			_binding_status.text = "REBIND CANCELLED"
		_refresh_binding_buttons()
		return true
	var error := settings.set_binding(_capturing, code)
	if error.is_empty():
		_capturing = ""
		if is_instance_valid(_binding_status):
			_binding_status.text = ""
	else:
		if is_instance_valid(_binding_status):
			_binding_status.text = error.to_upper()
	_refresh_binding_buttons()
	return true

func _button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	_style_button(button)
	parent.add_child(button)
	return button

func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", VhsOsd.FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", Color(0.06, 0.06, 0.05))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.bg_color = GOLD if state == "pressed" else Color(0.10, 0.10, 0.085)
		style.border_color = GOLD if state != "normal" else Color(0.27, 0.26, 0.21)
		style.set_border_width_all(1)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)

func _ask_reset() -> void:
	if is_instance_valid(_reset_prompt):
		return
	_capturing = ""
	_refresh_binding_buttons()
	_reset_prompt = ReturnPrompt.new()
	_reset_prompt.heading_text = "RESET DEFAULTS?"
	_reset_prompt.warning_text = "ALL SETTINGS WILL RETURN TO THEIR DEFAULT VALUES."
	_reset_prompt.layer = 112
	_reset_prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_prompt.confirmed.connect(func() -> void:
		if is_instance_valid(settings):
			settings.reset_defaults()
		if is_instance_valid(_binding_status):
			_binding_status.text = "DEFAULTS RESTORED"
		_reset_prompt.queue_free()
		_reset_prompt = null
		_reset_button.call_deferred("grab_focus"))
	_reset_prompt.cancelled.connect(func() -> void:
		_reset_prompt.queue_free()
		_reset_prompt = null
		if is_instance_valid(_reset_button):
			_reset_button.call_deferred("grab_focus"))
	add_child(_reset_prompt)
	_reset_prompt.call_deferred("set", "layer", 112)

func _close_quit() -> void:
	if _quit_emitted:
		return
	_quit_emitted = true
	settings.save_to_disk()
	visible = false
	quit_requested.emit()

func _refresh_controls() -> void:
	if not settings:
		return
	for key: String in SLIDER_KEYS:
		var pair: Array = _controls[key]
		var slider: HSlider = pair[0]
		slider.set_value_no_signal(float(settings.get_value(key)))
		(pair[1] as Label).text = _format_value(key, float(settings.get_value(key)))
	for key: String in GameSettings.BOOLEAN_KEYS:
		if not _controls.has(key):
			continue
		(_controls[key] as CheckButton).set_pressed_no_signal(bool(settings.get_value(key)))
	if _controls.has("toggle_sprint"):
		(_controls["toggle_sprint"] as CheckButton).tooltip_text = _sprint_tooltip()
	for key: String in OPTION_LABELS:
		var select := _controls[key] as OptionButton
		select.select(select.get_item_index(int(settings.get_value(key))))
	var crt_enabled := bool(settings.get_value("crt_enabled"))
	var resolution := _controls["render_resolution"] as OptionButton
	resolution.disabled = crt_enabled
	if crt_enabled:
		resolution.select(resolution.get_item_index(1))
		resolution.tooltip_text = "CRT fixes the world source at 480p. Turn CRT off to use your saved %s resolution." % OPTION_LABELS["render_resolution"][int(settings.get_value("render_resolution"))]
	else:
		resolution.tooltip_text = "Limits world resolution; menus stay sharp. Higher values cost more GPU time."
	var preset := int(settings.get_value("quality_preset"))
	for i in _preset_buttons.size():
		_preset_buttons[i].set_pressed_no_signal(preset == i)
	var quality_note: String = QUALITY_NOTES[preset]
	if crt_enabled:
		quality_note = quality_note.replace("480p", "480p CRT").replace("360p", "480p CRT").replace("720p", "480p CRT").replace("Native resolution", "480p CRT")
		if preset == 4:
			quality_note += " CRT source: 480p."
	_quality_status.text = "%s · %s" % [GameSettings.QUALITY_NAMES[preset].to_upper(), quality_note]
	_refresh_binding_buttons()
	if is_instance_valid(_binding_status) and _capturing.is_empty():
		_binding_status.text = ""
	_refresh_video_controls()
	_refresh_motion_controls()
	_refresh_hdr_controls()


func _refresh_video_controls() -> void:
	if not settings or not _controls.has("vhs_distortion"):
		return
	var pair: Array = _controls["vhs_distortion"]
	var slider := pair[0] as HSlider
	var value_label := pair[1] as Label
	slider.editable = bool(settings.get_value("vhs_enabled"))
	slider.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)
	value_label.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)
	var curvature_toggle := _controls["crt_curvature"] as CheckButton
	curvature_toggle.disabled = not bool(settings.get_value("crt_enabled"))


func _refresh_motion_controls() -> void:
	if not settings or not _controls.has("handheld_camera") \
			or not _controls.has("handheld_strength"):
		return
	var pair: Array = _controls["handheld_strength"]
	var slider := pair[0] as HSlider
	var value_label := pair[1] as Label
	slider.editable = bool(settings.get_value("handheld_camera"))
	slider.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)
	value_label.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)


func _refresh_hdr_controls() -> void:
	if not settings or not _controls.has("hdr_enabled") \
			or not _controls.has("hdr_brightness"):
		return
	var supported := HdrOutput.display_server_supported()
	var requested := bool(settings.get_value("hdr_enabled"))
	var toggle := _controls["hdr_enabled"] as CheckButton
	toggle.disabled = not supported
	var pair: Array = _controls["hdr_brightness"]
	var slider := pair[0] as HSlider
	var value_label := pair[1] as Label
	slider.editable = supported and requested
	slider.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)
	value_label.modulate = Color.WHITE if slider.editable else Color(0.55, 0.55, 0.55)
	if is_instance_valid(_hdr_status):
		_hdr_status.text = HdrOutput.status(get_window(), requested)

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

static func is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE \
			or event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"))
	return event.is_action_pressed("ui_cancel")


func _input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_reset_prompt):
		return
	if not _capturing.is_empty():
		if _capture_key(event):
			get_viewport().set_input_as_handled()
		return
	if is_pause_event(event):
		_close_resume()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_instance_valid(_reset_prompt):
		get_viewport().set_input_as_handled()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.045, 0.038, 0.99)
	style.border_color = Color(0.41, 0.38, 0.28)
	style.set_border_width_all(1)
	return style
