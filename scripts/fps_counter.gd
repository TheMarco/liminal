extends "res://scripts/screen_ui.gd"
## Window-resolution diagnostics, outside the recorded picture and CRT effects.
## Count completed draws, not process callbacks: an unfocused window may keep
## updating the game without rendering. Wall time also includes stalls/caps.
const SAMPLE_USEC := 500000
var _label: Label
var _sample_started := 0
var _drawn_frames := 0

func _ready() -> void:
	name = "FPSCounter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	visible = false
	set_process(false)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -232
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = 44
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.025, 0.8)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.92))
	panel.add_child(_label)

func set_enabled(enabled: bool) -> void:
	if visible == enabled:
		return
	visible = enabled
	set_process(enabled)
	if enabled:
		_sample_started = Time.get_ticks_usec()
		_drawn_frames = 0
		_label.text = "FPS · measuring…"
		RenderingServer.frame_post_draw.connect(_count_draw)
	else:
		RenderingServer.frame_post_draw.disconnect(_count_draw)

func _count_draw() -> void:
	_drawn_frames += 1

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := now - _sample_started
	if elapsed < SAMPLE_USEC:
		return
	if _drawn_frames > 0:
		_label.text = "%d FPS · %.1f ms" % [roundi(_drawn_frames * 1000000.0 / elapsed),
			elapsed / (1000.0 * _drawn_frames)]
	else:
		_label.text = "0 FPS · — ms"
	_sample_started = now
	_drawn_frames = 0
