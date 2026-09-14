extends CanvasLayer
## Non-modal: saving can fail inside transitions that must not be interrupted.
## Each category stays visible until that store successfully saves again.
var _messages: Dictionary = {}
var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.045, 0.025, 0.97)
	style.border_color = VhsOsd.AMBER
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_label = VhsOsd.make_label(24, VhsOsd.AMBER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_label)
	get_viewport().size_changed.connect(_relayout)
	_refresh()

func report_failure(category: String, error: Error) -> void:
	if _messages.get(category, OK) != error:
		push_warning("%s could not be saved: %s" % [category, error_string(error)])
	_messages[category] = error
	_refresh()

func clear_failure(category: String) -> void:
	_messages.erase(category)
	_refresh()

func _refresh() -> void:
	visible = not _messages.is_empty()
	var lines: Array[String] = []
	if _messages.has("Progress"):
		lines.append("PROGRESS NOT SAVED — CHECK DISK/PERMISSIONS")
	if _messages.has("Settings"):
		lines.append("SETTINGS NOT SAVED — THIS SESSION ONLY")
	if _messages.has("Photograph"):
		lines.append("PHOTO NOT SAVED — CHECK DISK/PERMISSIONS")
	if _messages.has("Recordings"):
		lines.append("WATCH HISTORY NOT SAVED — WILL RETRY")
	_label.text = "\n".join(lines)
	_relayout()

func _relayout() -> void:
	var extent := Vector2(get_viewport().size)
	var scale := maxf(1.0, minf(extent.x / 960.0, extent.y / 720.0))
	var safe := VhsOsd.safe_inset(extent)
	_label.add_theme_font_size_override("font_size", roundi(24.0 * scale))
	_panel.position = Vector2(safe.x, maxf(8.0, safe.y * 0.25))
	_panel.size = Vector2(extent.x - safe.x * 2.0, 0.0)
	# Wrapped text updates its minimum height after container layout settles.
	_panel.set_deferred("size", Vector2(extent.x - safe.x * 2.0, 0.0))
