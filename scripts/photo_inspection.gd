extends Control
## One clipped, independently zoomable print. No source image is modified.
signal view_changed
var image: TextureRect
var zoom := 1.0
var pan := Vector2.ZERO
var caption := "":
	set(value):
		caption = value
		queue_redraw()
var _dragging := false
var _surface: Control

func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_surface = Control.new()
	_surface.clip_contents = true
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(image)
	resized.connect(_layout_image)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_photo(texture: Texture2D) -> void:
	image.texture = texture
	reset_view()

func image_area() -> Rect2:
	return Rect2(Vector2(12, 36), (size - Vector2(24, 48)).max(Vector2.ONE))

func fitted_size() -> Vector2:
	if image == null or image.texture == null: return Vector2.ZERO
	var source := image.texture.get_size()
	var area := image_area().size
	return source * minf(area.x / source.x, area.y / source.y)

func _layout_image() -> void:
	if image == null: return
	_surface.position = image_area().position
	_surface.size = image_area().size
	var extent := fitted_size() * zoom
	var limit := ((extent - image_area().size) * 0.5).max(Vector2.ZERO)
	pan = pan.clamp(-limit, limit)
	image.size = extent
	image.position = image_area().size * 0.5 - extent * 0.5 + pan
	queue_redraw()

func zoom_by(factor: float, at := Vector2.INF) -> void:
	if image.texture == null: return
	var anchor := image_area().get_center() if not at.is_finite() else at
	var next := clampf(zoom * factor, 1.0, 8.0)
	pan = anchor - image_area().get_center() - (anchor - image_area().get_center() - pan) * next / zoom
	zoom = next
	_layout_image()
	view_changed.emit()

func pan_by(delta: Vector2) -> void:
	pan += delta
	_layout_image()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_layout_image()
	view_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			grab_focus()
			zoom_by(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				grab_focus()
				if event.double_click: reset_view()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan_by(event.relative)
		accept_event()
	elif event is InputEventPanGesture:
		grab_focus()
		pan_by(-event.delta * 12.0)
		accept_event()
	elif event is InputEventMagnifyGesture:
		grab_focus()
		zoom_by(event.factor, event.position)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.09, 0.075))
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), VhsOsd.AMBER if has_focus() else Color(0.48, 0.44, 0.35), false, 2)
	draw_string(VhsOsd.FONT, Vector2(12, 24), caption, HORIZONTAL_ALIGNMENT_LEFT, maxf(1, size.x - 24), 22, VhsOsd.INK_DIM)
