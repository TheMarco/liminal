class_name PhotoAlbum
extends CanvasLayer
## A paused, run-scoped collection of the player's actual exposures.
signal closed
const Inspection = preload("res://scripts/photo_inspection.gd")
var store: PhotoAlbumStore
var index := 0
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _was_paused := false
var _layout: VBoxContainer
var _image: TextureRect
var _frame: Control
var _paper: Control
var _current_view: Control
var _pinned_view: Control
var _active_view: Control
var _pinned_index := -1
var _pin: Button
var _fit: Button
var _zoom_out: Button
var _zoom_in: Button
var _inspection_help: Label
var _photo_ratio := 1.6
var _detail: Label
var _counter: Label
var _empty: Label
var _previous: Button
var _next: Button
var _strip: HBoxContainer
var _controls: GridContainer
var _save: Button
var _close: Button
var _export_status: Label
var _export_dialog: FileDialog
var _export_open := false
var _export_index := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	var background := ColorRect.new()
	background.color = Color(0.035, 0.031, 0.028, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 12)
	add_child(_layout)
	var heading := HBoxContainer.new()
	_layout.add_child(heading)
	var title := VhsOsd.make_label(36)
	title.text = "PHOTOGRAPHS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_counter = VhsOsd.make_label(24, VhsOsd.INK_DIM)
	heading.add_child(_counter)
	var inspection_controls := HBoxContainer.new()
	inspection_controls.add_theme_constant_override("separation", 8)
	_layout.add_child(inspection_controls)
	_pin = _button("PIN TO COMPARE", _toggle_pin, inspection_controls)
	_zoom_out = _button("−", func(): _active_view.zoom_by(0.8), inspection_controls)
	_fit = _button("FIT", func(): _active_view.reset_view(), inspection_controls)
	_zoom_in = _button("+", func(): _active_view.zoom_by(1.25), inspection_controls)
	for button in [_zoom_out, _fit, _zoom_in]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 48
	# The image's aspect ratio must not set the whole page's minimum height.
	# This flexible area lets controls stay on screen in short/portrait windows.
	_frame = Control.new()
	_frame.custom_minimum_size.y = 80
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(_frame)
	_frame.resized.connect(_fit_photo)
	_current_view = Inspection.new()
	_pinned_view = Inspection.new()
	_frame.add_child(_current_view)
	_frame.add_child(_pinned_view)
	_pinned_view.visible = false
	_paper = _current_view
	_image = _current_view.image
	_active_view = _current_view
	for view in [_current_view, _pinned_view]:
		view.focus_entered.connect(func(): _active_view = view; _sync_inspection_controls())
		view.view_changed.connect(_sync_inspection_controls)
	_empty = VhsOsd.make_label(26, VhsOsd.INK_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	_paper.add_child(_empty)
	_inspection_help = VhsOsd.make_label(20, VhsOsd.INK_DIM)
	_inspection_help.text = "WHEEL / + − ZOOM  ·  DRAG / WASD PAN  ·  0 FIT  ·  TAB SELECTS PHOTO"
	_inspection_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspection_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout.add_child(_inspection_help)
	_detail = VhsOsd.make_label(24)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.y = 48
	_layout.add_child(_detail)
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(_strip)
	_controls = GridContainer.new()
	_controls.add_theme_constant_override("h_separation", 12)
	_controls.add_theme_constant_override("v_separation", 10)
	_layout.add_child(_controls)
	_previous = _button("← PREVIOUS", func(): show_photo(index - 1), _controls)
	_next = _button("NEXT →", func(): show_photo(index + 1), _controls)
	_save = _button("SAVE PHOTOGRAPH", _choose_export_path, _controls)
	_close = _button("CLOSE · P / ESC", dismiss, _controls)
	_export_status = VhsOsd.make_label(22, VhsOsd.INK_DIM)
	_export_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_status.visible = false
	_layout.add_child(_export_status)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_close.call_deferred("grab_focus")

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	VhsOsd.style_button(button, 26)
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := maxf(1.0, minf(viewport_size.x / 1000.0, viewport_size.y / 720.0))
	var safe := VhsOsd.safe_inset(viewport_size)
	var logical_size := (viewport_size - safe * 2.0) / factor
	logical_size.x = minf(logical_size.x, 1120.0)
	_layout.scale = Vector2.ONE * factor
	_layout.position = (viewport_size - logical_size * factor) * 0.5
	_controls.columns = 4 if logical_size.x >= 900.0 else 2
	# Short windows prioritize the photograph; Previous/Next remain available.
	_strip.visible = logical_size.y >= 520.0
	_inspection_help.visible = logical_size.y >= 520.0
	_layout.add_theme_constant_override("separation", 8 if logical_size.y < 520.0 else 12)
	# Keep all five thumbnails within narrow windows without shrinking text.
	for thumbnail: Button in _strip.get_children():
		var width := minf(144.0, (logical_size.x - 24.0) / 5.0)
		var text_width := VhsOsd.FONT.get_string_size(thumbnail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		thumbnail.add_theme_constant_override("icon_max_width", int(width - text_width - 40.0))
		thumbnail.custom_minimum_size.x = width
	# Allow container minimums to catch up after switching rows or thumbnails.
	_layout.set_deferred("size", logical_size)
	_fit_photo.call_deferred()

func _fit_photo() -> void:
	var area := _frame.size
	if _current_view == null: return
	_pinned_view.visible = _pinned_index >= 0
	_current_view.position = Vector2.ZERO
	_current_view.size = area
	if _pinned_index >= 0:
		var stacked := area.y > area.x * 0.9
		var pane := Vector2(area.x, (area.y - 12) * 0.5) if stacked else Vector2((area.x - 12) * 0.5, area.y)
		_pinned_view.position = Vector2.ZERO
		_pinned_view.size = pane
		_current_view.position = Vector2(0, pane.y + 12) if stacked else Vector2(pane.x + 12, 0)
		_current_view.size = pane

func _toggle_pin() -> void:
	if _pinned_index >= 0:
		_pinned_index = -1
		_pinned_view.set_photo(null)
		_active_view = _current_view
	else:
		if _image.texture == null: return
		_pinned_index = index
		_pinned_view.set_photo(_image.texture)
		_pinned_view.caption = "PINNED · PHOTO %02d" % (index + 1)
	_sync_inspection_controls()
	_fit_photo()

func _sync_inspection_controls() -> void:
	if _pin == null or _active_view == null: return
	_pin.text = "UNPIN %02d" % (_pinned_index + 1) if _pinned_index >= 0 else "PIN TO COMPARE"
	_pin.disabled = _pinned_index < 0 and _image.texture == null
	var unavailable: bool = _active_view.image.texture == null
	_zoom_out.disabled = unavailable or _active_view.zoom <= 1.0
	_zoom_in.disabled = unavailable or _active_view.zoom >= 8.0
	_fit.disabled = unavailable
	_fit.text = "FIT" if _active_view.zoom <= 1.0 else "%d%%" % roundi(_active_view.zoom * 100.0)

func open(model: PhotoAlbumStore) -> void:
	store = model
	_mouse_mode = Input.mouse_mode
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_photo(store.entries.size() - 1)

func show_photo(requested: int) -> void:
	index = clampi(requested, 0, maxi(0, store.entries.size() - 1))
	var total := store.entries.size()
	_counter.text = "%02d / %02d" % [index + 1, total] if total > 0 else "NO PHOTOGRAPHS"
	_previous.disabled = index <= 0
	_next.disabled = index >= total - 1
	var image: Image = store.image_at(index) if total > 0 else null
	_save.disabled = image == null
	_current_view.set_photo(ImageTexture.create_from_image(image) if image != null else null)
	_current_view.caption = "PHOTO %02d" % (index + 1) if total > 0 else "PHOTOGRAPH"
	_sync_inspection_controls()
	_photo_ratio = float(image.get_width()) / image.get_height() if image != null else 1.6
	_empty.visible = image == null
	_empty.text = "Your album is empty.\nC raises the camera. Space takes a photograph." \
		if total == 0 else "This photograph could not be loaded."
	_detail.text = "Every photograph you take is kept here."
	if total > 0:
		var entry: Dictionary = store.entries[index]
		_detail.text = "FLOOR %s  ·  %s\n%s" % [str(entry.get("floor", "?")),
			str(entry.get("theme", "")), str(entry.get("caption", ""))]
		if not str(entry.get("flash_status", "")).is_empty():
			_detail.text += "\n" + str(entry["flash_status"])
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	var start := maxi(0, mini(index - 2, total - 5))
	for i in range(start, mini(total, start + 5)):
		var thumb := Button.new()
		thumb.text = "%02d" % (i + 1)
		VhsOsd.style_button(thumb, 22)
		thumb.custom_minimum_size = Vector2(120, 66)
		thumb.expand_icon = true
		thumb.add_theme_constant_override("icon_max_width", 86)
		var thumbnail := store.image_at(i)
		if thumbnail != null:
			thumbnail.resize(112, maxi(1, roundi(112.0 * thumbnail.get_height() / thumbnail.get_width())))
			thumb.icon = ImageTexture.create_from_image(thumbnail)
		thumb.toggle_mode = true
		thumb.button_pressed = i == index
		thumb.pressed.connect(show_photo.bind(i))
		_strip.add_child(thumb)
	_resize()


func _choose_export_path() -> void:
	if _export_open or _save.disabled:
		return
	if _export_dialog == null:
		_export_dialog = FileDialog.new()
		_export_dialog.title = "Save photograph"
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_dialog.use_native_dialog = true
		_export_dialog.filters = PackedStringArray(["*.png ; PNG photograph"])
		_export_dialog.file_selected.connect(_export_selected)
		_export_dialog.canceled.connect(func(): _export_open = false)
		add_child(_export_dialog)
	_export_index = index
	_export_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	_export_dialog.current_file = "It-wants-you-to-stay_F%02d_photo-%03d.png" % [
		int(store.entries[index].get("floor", 1)), index + 1]
	_export_open = true
	_export_dialog.popup_centered_ratio(0.75)


func _export_selected(path: String) -> void:
	_export_open = false
	# FileDialog's save mode has already confirmed replacement, if necessary.
	var error := store.export_photo(_export_index, path, true)
	_export_status.text = "SAVED — %s" % path.get_file() if error == OK \
		else "COULD NOT SAVE PHOTOGRAPH — %s" % error_string(error)
	_export_status.visible = true
	_close.grab_focus()

func _input(event: InputEvent) -> void:
	if _export_open:
		return  # Native save dialog owns its cancel/navigation keys.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				get_viewport().set_input_as_handled()
				_active_view.zoom_by(1.25)
			KEY_MINUS, KEY_KP_SUBTRACT:
				get_viewport().set_input_as_handled()
				_active_view.zoom_by(0.8)
			KEY_0, KEY_KP_0:
				get_viewport().set_input_as_handled()
				_active_view.reset_view()
			KEY_W, KEY_A, KEY_S, KEY_D:
				get_viewport().set_input_as_handled()
				var motion := {KEY_W: Vector2(0, 40), KEY_A: Vector2(40, 0), KEY_S: Vector2(0, -40), KEY_D: Vector2(-40, 0)}
				_active_view.pan_by(motion[event.physical_keycode])
			KEY_P, KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				dismiss()
			KEY_LEFT, KEY_PAGEUP:
				if event.physical_keycode == KEY_LEFT and get_viewport().gui_get_focus_owner() is Button: return
				get_viewport().set_input_as_handled()
				show_photo(index - 1)
			KEY_RIGHT, KEY_PAGEDOWN:
				if event.physical_keycode == KEY_RIGHT and get_viewport().gui_get_focus_owner() is Button: return
				get_viewport().set_input_as_handled()
				show_photo(index + 1)

func dismiss() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	closed.emit()
	queue_free()
