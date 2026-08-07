class_name CrossVideoReview
extends Control
## Fast editorial review surface for the optional Dr. Cross tape pool.
## Objective/elevator chapters never enter this list: it uses the same short-
## form boundary as production. Review decisions are non-destructive and are
## written immediately to a plain-text prune report in the project root.

const DEFAULT_REPORT_PATH := "res://cross_review_prune.txt"
const SOURCES_PATH := "res://videos/tapes/SOURCES.md"
const UI_FONT: Font = preload("res://fonts/VT323-Regular.ttf")

var report_path := DEFAULT_REPORT_PATH

var _paths: Array[String] = []
var _marked := {}
var _sources := {}
var _index := 0
var _video: VideoStreamPlayer
var _aspect: AspectRatioContainer
var _picker: OptionButton
var _position: ProgressBar
var _time: Label
var _identity: Label
var _source: Label
var _review_state: Label
var _report_state: Label
var _pause_button: Button
var _mark_button: Button
var _auto_advance: CheckButton
var _capture_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-screenshot="):
			_capture_path = arg.substr(20)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_sources = _read_sources()
	_paths = VhsTapeLibrary.paths(false)
	_load_report()
	for path in _paths:
		_picker.add_item(path.get_file())
	if _paths.is_empty():
		_identity.text = "NO OPTIONAL RECORDINGS FOUND"
		_review_state.text = "The long objective pool is intentionally excluded."
		set_process(false)
		return
	_show_clip(0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _capture_path.is_empty():
		_capture_review.call_deferred()


func _process(_delta: float) -> void:
	if _video == null or _video.stream == null:
		return
	var length := _video.get_stream_length()
	var position := _video.stream_position
	_position.max_value = maxf(0.01, length)
	_position.value = clampf(position, 0.0, length)
	_time.text = "%s  /  %s" % [_clock(position), _clock(length)]
	_pause_button.text = "PLAY" if _video.paused else "PAUSE"


func review_paths() -> Array[String]:
	return _paths.duplicate()


func marked_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in _paths:
		if _marked.has(path):
			paths.append(path)
	return paths


func _build_ui() -> void:
	var back := ColorRect.new()
	back.color = Color(0.006, 0.007, 0.009)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 34.0
	layout.offset_top = 24.0
	layout.offset_right = -34.0
	layout.offset_bottom = -22.0
	layout.add_theme_constant_override("separation", 9)
	add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	var title := _label("DR. CROSS  /  OPTIONAL VIDEO REVIEW", 29,
		Color(0.94, 0.89, 0.77))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var boundary := _label("LONG OBJECTIVE TAPES EXCLUDED", 17,
		Color(0.66, 0.62, 0.52))
	header.add_child(boundary)
	header.add_child(_button("CLOSE", func(): get_tree().quit(), 100))

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size.y = 380.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.BLACK
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = Color(0.20, 0.20, 0.18)
	frame.add_theme_stylebox_override("panel", frame_style)
	layout.add_child(frame)

	_aspect = AspectRatioContainer.new()
	_aspect.ratio = 4.0 / 3.0
	_aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.add_child(_aspect)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.volume_db = 2.0
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.finished.connect(_on_finished)
	_aspect.add_child(_video)

	var metadata := HBoxContainer.new()
	metadata.add_theme_constant_override("separation", 18)
	layout.add_child(metadata)
	_identity = _label("", 22, Color(0.94, 0.89, 0.77))
	_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metadata.add_child(_identity)
	_review_state = _label("", 20, Color(0.58, 0.74, 0.58))
	metadata.add_child(_review_state)

	_source = _label("", 16, Color(0.56, 0.55, 0.51))
	_source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(_source)

	var timeline := HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 12)
	layout.add_child(timeline)
	_position = ProgressBar.new()
	_position.show_percentage = false
	_position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position.custom_minimum_size.y = 10.0
	timeline.add_child(_position)
	_time = _label("00:00 / 00:00", 16, Color(0.66, 0.64, 0.58))
	_time.custom_minimum_size.x = 120.0
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timeline.add_child(_time)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	layout.add_child(controls)
	controls.add_child(_button("PREVIOUS", func(): _step(-1), 118))
	_pause_button = _button("PAUSE", _toggle_pause, 100)
	controls.add_child(_pause_button)
	controls.add_child(_button("REPLAY", _replay, 100))
	controls.add_child(_button("NEXT", func(): _step(1), 100))
	_mark_button = _button("MARK FOR PRUNING", _toggle_mark, 196)
	controls.add_child(_mark_button)
	controls.add_child(_button("COPY CLIP PATH", _copy_clip_path, 166))

	_picker = OptionButton.new()
	_picker.add_theme_font_override("font", UI_FONT)
	_picker.add_theme_font_size_override("font_size", 18)
	_picker.custom_minimum_size.x = 190.0
	_picker.item_selected.connect(func(index: int): _show_clip(index))
	controls.add_child(_picker)
	_auto_advance = CheckButton.new()
	_auto_advance.text = "AUTO-ADVANCE"
	_auto_advance.button_pressed = true
	_auto_advance.add_theme_font_override("font", UI_FONT)
	_auto_advance.add_theme_font_size_override("font_size", 18)
	controls.add_child(_auto_advance)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	var help := _label(
		"LEFT/RIGHT previous/next   ·   SPACE play/pause   ·   R replay   ·   M mark   ·   ESC close",
		15, Color(0.49, 0.48, 0.44))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(help)
	_report_state = _label("", 15, Color(0.68, 0.64, 0.54))
	footer.add_child(_report_state)
	footer.add_child(_button("COPY REPORT PATH", _copy_report_path, 174))


func _show_clip(index: int) -> void:
	if _paths.is_empty():
		return
	_index = posmod(index, _paths.size())
	var path := _paths[_index]
	var stream := load(path) as VideoStream
	if stream == null:
		_review_state.text = "FAILED TO LOAD"
		_review_state.add_theme_color_override("font_color", Color(0.92, 0.42, 0.35))
		return
	_video.stop()
	_video.stream = stream
	_video.paused = false
	_video.play()
	_picker.select(_index)
	_identity.text = "%02d / %02d    %s" % [
		_index + 1, _paths.size(), path.get_file()]
	_source.text = "SOURCE  /  %s" % str(_sources.get(path, "not recorded"))
	_refresh_mark_state()
	_refresh_aspect.call_deferred(path)


func _refresh_aspect(expected_path: String) -> void:
	if _paths.is_empty() or _paths[_index] != expected_path:
		return
	var texture := _video.get_video_texture()
	if texture == null:
		return
	var size := texture.get_size()
	if size.y > 0:
		_aspect.ratio = float(size.x) / float(size.y)


func _step(offset: int) -> void:
	_show_clip(_index + offset)


func _toggle_pause() -> void:
	if _video.stream == null:
		return
	_video.paused = not _video.paused


func _replay() -> void:
	if _video.stream == null:
		return
	_video.paused = false
	_video.play()


func _toggle_mark() -> void:
	if _paths.is_empty():
		return
	var path := _paths[_index]
	if _marked.has(path):
		_marked.erase(path)
	else:
		_marked[path] = true
	_save_report()
	_refresh_mark_state()


func _refresh_mark_state() -> void:
	if _paths.is_empty():
		return
	var marked := _marked.has(_paths[_index])
	_review_state.text = "MARKED FOR PRUNING" if marked else "KEEP / UNREVIEWED"
	_review_state.add_theme_color_override("font_color",
		Color(0.94, 0.45, 0.34) if marked else Color(0.58, 0.74, 0.58))
	_mark_button.text = "UNMARK  /  KEEP" if marked else "MARK FOR PRUNING"
	_update_report_state()


func _on_finished() -> void:
	if _auto_advance.button_pressed:
		_step(1)


func _copy_clip_path() -> void:
	if not _paths.is_empty():
		DisplayServer.clipboard_set(_paths[_index])


func _copy_report_path() -> void:
	DisplayServer.clipboard_set(ProjectSettings.globalize_path(report_path))


func _load_report() -> void:
	_marked.clear()
	var absolute := ProjectSettings.globalize_path(report_path)
	if not FileAccess.file_exists(absolute):
		_update_report_state()
		return
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		_update_report_state("REPORT COULD NOT BE READ")
		return
	for raw_line in file.get_as_text().split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			_marked[line] = true
	_update_report_state()


func _save_report() -> void:
	var absolute := ProjectSettings.globalize_path(report_path)
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_update_report_state("REPORT WRITE FAILED")
		return
	file.store_line("# Optional Dr. Cross videos marked for pruning")
	file.store_line("# Generated by tools/cross_video_review.tscn")
	file.store_line("# Delete or move these files only after reviewing the list.")
	for path in marked_paths():
		file.store_line(path)
	file.close()
	_update_report_state()


func _update_report_state(override := "") -> void:
	if _report_state == null:
		return
	if not override.is_empty():
		_report_state.text = override
		return
	_report_state.text = "%d MARKED  ·  %s" % [
		marked_paths().size(), report_path.get_file()]


func _read_sources() -> Dictionary:
	var result := {}
	var file := FileAccess.open(SOURCES_PATH, FileAccess.READ)
	if file == null:
		return result
	for raw_line in file.get_as_text().split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("- `") or not line.contains("` — "):
			continue
		var filename := line.get_slice("`", 1)
		if filename.get_extension().to_lower() != "ogv":
			continue
		var description := line.get_slice("` — ", 1) \
			.trim_prefix("`").trim_suffix("`")
		result[VhsTapeLibrary.TAPE_DIR.path_join(filename)] = description
	return result


func _capture_review() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture_path)
	print("saved Cross review screenshot to %s" % _capture_path)
	get_tree().quit()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_LEFT, KEY_A:
			_step(-1)
		KEY_RIGHT, KEY_D:
			_step(1)
		KEY_SPACE:
			_toggle_pause()
		KEY_R:
			_replay()
		KEY_M:
			_toggle_mark()
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _clock(seconds: float) -> String:
	if not is_finite(seconds) or seconds < 0.0:
		return "00:00"
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 38.0)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button
