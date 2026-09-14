class_name DescentIntro
extends CanvasLayer
## Full-screen Descent prologue. A first-ever viewing has no escape hatch;
## later new runs offer a clickable and keyboard-accessible Skip.

signal completed(watched_to_end: bool)
signal pause_requested

const INTRO_STREAM: VideoStream = preload(
	"res://videos/intro/liminal_intro.ogv")
const UI_FONT: Font = preload("res://fonts/VT323-Regular.ttf")

var _skip_allowed := false
var _video: VideoStreamPlayer
var _skip_button: Button
var _pause_button: Button
var _done := false


func _init(skip_allowed := false) -> void:
	_skip_allowed = skip_allowed


func _ready() -> void:
	layer = 10
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A full-screen STOP control prevents clicks outside Skip from reaching any
	# results screen or world UI beneath the movie.
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)

	_video = VideoStreamPlayer.new()
	SoundBank.ensure_dialogue_bus()
	_video.bus = SoundBank.DIALOGUE_BUS
	_video.stream = INTRO_STREAM
	_video.expand = true
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(func(): _finish(true))
	add_child(_video)

	if _skip_allowed:
		_skip_button = Button.new()
		var skip := _skip_button
		skip.name = "SkipIntro"
		skip.text = "E — SKIP INTRO"
		skip.add_theme_font_override("font", UI_FONT)
		skip.add_theme_font_size_override("font_size", 22)
		skip.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		skip.add_theme_color_override("font_hover_color", Color.WHITE)
		skip.anchor_left = 1.0
		skip.anchor_top = 1.0
		skip.anchor_right = 1.0
		skip.anchor_bottom = 1.0
		skip.offset_left = -220.0
		skip.offset_top = -78.0
		skip.offset_right = -30.0
		skip.offset_bottom = -30.0
		skip.focus_mode = Control.FOCUS_ALL
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.01, 0.01, 0.01, 0.72)
		normal.border_width_left = 1
		normal.border_width_top = 1
		normal.border_width_right = 1
		normal.border_width_bottom = 1
		normal.border_color = Color(0.68, 0.64, 0.55, 0.72)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.08, 0.075, 0.06, 0.9)
		hover.border_color = Color(0.92, 0.88, 0.78, 0.95)
		skip.add_theme_stylebox_override("normal", normal)
		skip.add_theme_stylebox_override("hover", hover)
		skip.add_theme_stylebox_override("pressed", hover)
		var focus := hover.duplicate() as StyleBoxFlat
		focus.set_border_width_all(3)
		focus.border_color = Color(1.0, 0.82, 0.35, 1.0)
		skip.add_theme_stylebox_override("focus", focus)
		skip.pressed.connect(func(): _finish(false))
		add_child(skip)
		skip.grab_focus()

	_pause_button = Button.new()
	_pause_button.text = "ESC — PAUSE"
	VhsOsd.style_button(_pause_button, 22)
	_pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(_pause_button)
	get_viewport().size_changed.connect(_layout_skip_button)
	_layout_skip_button()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_video.play()


func _layout_skip_button() -> void:
	var viewport_size := Vector2(get_viewport().size)
	var scale := maxf(0.85, minf(viewport_size.y / 720.0, viewport_size.x / 960.0))
	var inset := VhsOsd.safe_inset(viewport_size)
	var button_size := Vector2(190.0 * scale, maxf(44.0, 48.0 * scale))
	_pause_button.add_theme_font_size_override("font_size", maxi(22, roundi(22.0 * scale)))
	_pause_button.position = Vector2(inset.x, viewport_size.y - inset.y - button_size.y)
	_pause_button.size = button_size
	if not is_instance_valid(_skip_button):
		return
	_skip_button.add_theme_font_size_override("font_size", roundi(22.0 * scale))
	_skip_button.scale = Vector2.ONE
	_skip_button.offset_left = -inset.x - button_size.x
	_skip_button.offset_top = -inset.y - button_size.y
	_skip_button.offset_right = -inset.x
	_skip_button.offset_bottom = -inset.y


func skip_available() -> bool:
	return _skip_allowed


## Consume keyboard input so a key cannot operate the world or a summary below
## the prologue. Only a previously watched intro accepts the Skip shortcuts.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.physical_keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return # GUI focus navigation gets first refusal.
	if key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		pause_requested.emit()
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused in [_pause_button, _skip_button] and key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	get_viewport().set_input_as_handled()
	if not _skip_allowed or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_E:
		_finish(false)


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _finish(watched_to_end: bool) -> void:
	if _done:
		return
	_done = true
	_video.stop()
	completed.emit(watched_to_end)
	queue_free()
