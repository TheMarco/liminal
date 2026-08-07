class_name DescentIntro
extends CanvasLayer
## Full-screen Descent prologue. A first-ever viewing has no escape hatch;
## later new runs still present the film, but add a mouse-clickable Skip.

signal completed(watched_to_end: bool)

const INTRO_STREAM: VideoStream = preload(
	"res://videos/intro/liminal_intro.ogv")
const UI_FONT: Font = preload("res://fonts/VT323-Regular.ttf")

var _skip_allowed := false
var _video: VideoStreamPlayer
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
	_video.stream = INTRO_STREAM
	_video.expand = true
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(func(): _finish(true))
	add_child(_video)

	if _skip_allowed:
		var skip := Button.new()
		skip.name = "SkipIntro"
		skip.text = "SKIP INTRO"
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
		skip.focus_mode = Control.FOCUS_NONE
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
		skip.pressed.connect(func(): _finish(false))
		add_child(skip)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_video.play()


func skip_available() -> bool:
	return _skip_allowed


## Consume keyboard input so a key cannot operate the world or a summary below
## the prologue. Skip intentionally remains a visible mouse-only action.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


func _finish(watched_to_end: bool) -> void:
	if _done:
		return
	_done = true
	_video.stop()
	completed.emit(watched_to_end)
	queue_free()
