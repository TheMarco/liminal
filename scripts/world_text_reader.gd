extends "res://scripts/screen_ui.gd"
## Read baked-in artwork without requiring English or altering a photo target.
## The source camera remains the gameplay camera even when this layer draws in
## the outer, full-resolution viewport.

var camera: Camera3D
var allowed: Callable
var exclude: Array[RID] = []
var _label: Label
var _panel: PanelContainer
var _elapsed := 0.0

func _ready() -> void:
	layer = 108
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.015, 0.015, 0.015, 0.88)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	visible = false

func _physics_process(delta: float) -> void:
	if Localization.current_locale() == "en" or not is_instance_valid(camera) \
			or (allowed.is_valid() and not allowed.call()):
		visible = false
		return
	_elapsed += delta
	if _elapsed < 0.1: return
	_elapsed = 0.0
	var closest: Node3D
	var best := 0.98
	var eye := camera.global_position
	for candidate: Node3D in get_tree().get_nodes_in_group("localized_inscriptions"):
		if not candidate.is_visible_in_tree(): continue
		var target := candidate.global_position
		var offset := target - eye
		if offset.length_squared() > 64.0 or offset.length_squared() < 0.01: continue
		var normal: Vector3 = (candidate.global_basis * Vector3(candidate.get_meta("face_normal"))).normalized()
		if normal.dot(-offset.normalized()) <= 0.1: continue
		var score := -camera.global_basis.z.dot(offset.normalized())
		if score <= best: continue
		# End just in front of the inscription; its mounting wall must not
		# occlude it, but a wall or prop between the reader and sign must.
		var ray := PhysicsRayQueryParameters3D.create(eye, target + normal * 0.08)
		ray.exclude = exclude
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = score
		closest = candidate
	visible = closest != null
	if not visible: return
	_label.text = str(closest.get_meta("inscription"))
	var extent := get_viewport().get_visible_rect().size
	var factor := clampf(minf(extent.x / 1280.0, extent.y / 720.0), 0.6, 3.0)
	_label.add_theme_font_size_override("font_size", roundi(26.0 * factor))
	_panel.custom_minimum_size.x = minf(extent.x - 32.0, 920.0 * factor)
	_panel.size.x = _panel.custom_minimum_size.x
	_panel.reset_size()
	var box_size := _panel.get_combined_minimum_size()
	_panel.position = Vector2((extent.x - box_size.x) * 0.5, extent.y * 0.73 - box_size.y)
