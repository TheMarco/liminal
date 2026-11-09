extends "res://scripts/screen_ui.gd"
## CJK strokes do not survive the lowest tape resolutions. Mirror HUD Labels
## at window resolution, retaining their source layout, visibility and fades.
## The source text remains intact for saves, gameplay and live translation.

var source_viewport: Viewport
var allowed: Callable
var _copies: Dictionary = {}
var _source_ink: Dictionary = {}

func _ready() -> void:
	layer = 104
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if Localization.current_locale() == "en" or not is_instance_valid(source_viewport) \
			or source_viewport == _canvas_viewport(self):
		_restore()
		visible = false
		return
	visible = not allowed.is_valid() or allowed.call()
	if not visible: return
	var factor := _canvas_viewport(self).get_visible_rect().size / source_viewport.get_visible_rect().size
	for original: Label in get_tree().get_nodes_in_group("readable_game_text"):
		if _canvas_viewport(original) != source_viewport: continue
		if not _copies.has(original):
			var copy := original.duplicate(0) as Label
			copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			copy.add_theme_constant_override("outline_size", 0)
			copy.add_theme_constant_override("shadow_outline_size", 0)
			copy.add_theme_constant_override("shadow_offset_x", 2)
			copy.add_theme_constant_override("shadow_offset_y", 2)
			add_child(copy)
			_copies[original] = copy
			_source_ink[original] = original.self_modulate
			original.self_modulate.a = 0
	for original in _copies.keys():
		var copy: Label = _copies[original]
		if not is_instance_valid(original):
			copy.queue_free()
			_copies.erase(original)
			_source_ink.erase(original)
			continue
		copy.visible = _is_drawn(original)
		if not copy.visible: continue
		copy.text = original.text
		copy.size = original.size
		copy.position = original.get_global_rect().position * factor
		copy.scale = original.get_global_transform().get_scale() * factor
		copy.add_theme_font_size_override("font_size", original.get_theme_font_size("font_size"))
		copy.add_theme_color_override("font_color", original.get_theme_color("font_color"))
		var ink: Color = _source_ink[original]
		var ancestor: Node = original
		while ancestor is CanvasItem:
			ink *= ancestor.modulate
			ancestor = ancestor.get_parent()
		copy.modulate = ink

func _restore() -> void:
	for original in _copies:
		if is_instance_valid(original): original.self_modulate = _source_ink[original]
		_copies[original].queue_free()
	_copies.clear()
	_source_ink.clear()

func _exit_tree() -> void:
	_restore()

func _canvas_viewport(node: Node) -> Viewport:
	# Node.get_viewport follows scene ownership, whereas CanvasLayer can draw
	# in another viewport. Respect that distinction for albums and dialogs too.
	while node != null:
		if node is CanvasLayer and node.custom_viewport is Viewport:
			return node.custom_viewport
		if node is Viewport: return node
		node = node.get_parent()
	return get_viewport()

func _is_drawn(node: CanvasItem) -> bool:
	if not node.is_visible_in_tree(): return false
	var ancestor: Node = node.get_parent()
	while ancestor != null and not ancestor is Viewport:
		if ancestor is CanvasLayer and not ancestor.visible: return false
		ancestor = ancestor.get_parent()
	return true
