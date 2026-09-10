class_name PhotoAlbum
extends CanvasLayer
## A paused, run-scoped collection of the player's actual exposures.
signal closed
var store: PhotoAlbumStore
var index := 0
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _was_paused := false
var _layout: VBoxContainer
var _image: TextureRect
var _frame: AspectRatioContainer
var _detail: Label
var _counter: Label
var _empty: Label
var _previous: Button
var _next: Button
var _strip: HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	var background := ColorRect.new()
	background.color = Color(0.035, 0.031, 0.028, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 14)
	add_child(_layout)
	var heading := HBoxContainer.new()
	_layout.add_child(heading)
	var title := Label.new()
	title.text = "PHOTOGRAPHS"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_counter = Label.new()
	heading.add_child(_counter)
	_frame = AspectRatioContainer.new()
	_frame.ratio = 1.6
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(_frame)
	var paper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.88, 0.86, 0.80)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	paper.add_theme_stylebox_override("panel", style)
	_frame.add_child(paper)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.add_child(_image)
	_empty = Label.new()
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.add_theme_color_override("font_color", Color(0.18, 0.16, 0.14))
	_empty.add_theme_font_size_override("font_size", 22)
	paper.add_child(_empty)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.y = 48
	_layout.add_child(_detail)
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(_strip)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 18)
	_layout.add_child(controls)
	_previous = _button("← PREVIOUS", func(): show_photo(index - 1), controls)
	_button("CLOSE  ·  P / ESC", dismiss, controls)
	_next = _button("NEXT →", func(): show_photo(index + 1), controls)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 42)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _resize() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1280.0, viewport_size.y / 800.0)
	_layout.scale = Vector2.ONE * factor
	_layout.size = Vector2(1120, 700)
	_layout.position = (viewport_size - _layout.size * factor) * 0.5

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
	_image.texture = ImageTexture.create_from_image(image) if image != null else null
	_frame.ratio = float(image.get_width()) / image.get_height() if image != null else 1.6
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_P, KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				dismiss()
			KEY_LEFT, KEY_PAGEUP:
				get_viewport().set_input_as_handled()
				show_photo(index - 1)
			KEY_RIGHT, KEY_PAGEDOWN:
				get_viewport().set_input_as_handled()
				show_photo(index + 1)

func dismiss() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	closed.emit()
	queue_free()
