class_name StorySubtitles
extends CanvasLayer
## Dialogue captions use the movie's playback clock, so pause, rewind and
## replay cannot drift. The overlay is crisp above the VHS/CRT passes.

const TRACK_PATH := "res://subtitles/en.json"
static var _tracks: Dictionary = {}
static var _loaded := false

var _video: VideoStreamPlayer
var _track: Array = []
var _panel: PanelContainer
var _label: Label


static func tracks() -> Dictionary:
	if not _loaded:
		_loaded = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH))
		if data is Dictionary:
			_tracks = data
	return _tracks


static func caption_at(track: Array, seconds: float) -> String:
	for cue: Dictionary in track:
		if seconds < float(cue["start"]):
			break
		if seconds < float(cue["end"]):
			return str(cue["text"])
	return ""


func attach(video: VideoStreamPlayer) -> void:
	_video = video
	_track = tracks().get(video.stream.resource_path, []) if video.stream != null else []
	_update_caption()


func _ready() -> void:
	layer = 109
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.015, 0.015, 0.015, 0.88)
	backing.content_margin_left = 18.0
	backing.content_margin_right = 18.0
	backing.content_margin_top = 10.0
	backing.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", backing)
	add_child(_panel)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_label)
	get_viewport().size_changed.connect(_layout)
	if GameSettings.current != null:
		GameSettings.current.changed.connect(_update_caption)
	_layout()
	_update_caption()


func _process(_delta: float) -> void:
	_update_caption()


func _update_caption() -> void:
	if not is_instance_valid(_label):
		return
	var enabled := GameSettings.current != null \
		and bool(GameSettings.current.get_value("story_subtitles"))
	var text := ""
	if enabled and is_instance_valid(_video) and _video.is_playing():
		text = caption_at(_track, _video.stream_position)
	visible = not text.is_empty()
	if text != _label.text:
		_label.text = text
		_layout.call_deferred()


func _layout() -> void:
	if not is_instance_valid(_panel):
		return
	var extent := get_viewport().get_visible_rect().size
	var factor := clampf(minf(extent.x / 1280.0, extent.y / 720.0), 0.6, 3.0)
	_label.add_theme_font_size_override("font_size", roundi(28.0 * factor))
	_panel.reset_size()
	var size := _panel.get_combined_minimum_size()
	_panel.position = Vector2((extent.x - size.x) * 0.5, extent.y - 116.0 * factor - size.y)
