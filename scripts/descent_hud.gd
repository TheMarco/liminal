class_name DescentHUD
extends CanvasLayer
## Minimal Descent-only route guidance. The needle points at the next real
## doorway, not straight through geometry toward the final lift.

const CELL := 12.0

var player: Player
var route: DescentRoute
var run: DescentRun
var world_seed := 1
var theme := 0

var _active := false
var _ring: Line2D
var _needle: Polygon2D
var _outline: Line2D
var _t := 0.0


func _ready() -> void:
	layer = 2

	_ring = Line2D.new()
	_ring.width = 1.2
	_ring.default_color = Color(0.92, 0.67, 0.30, 0.18)
	_ring.closed = true
	var circle := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		circle.append(Vector2(cos(a), sin(a)) * 19.0)
	_ring.points = circle
	add_child(_ring)

	var shape := PackedVector2Array([
		Vector2(-3.6, 13.0),
		Vector2(-3.6, -2.0),
		Vector2(-9.0, -2.0),
		Vector2(0.0, -15.0),
		Vector2(9.0, -2.0),
		Vector2(3.6, -2.0),
		Vector2(3.6, 13.0),
	])
	_needle = Polygon2D.new()
	_needle.polygon = shape
	_needle.color = Color(1.0, 0.62, 0.18, 0.78)
	add_child(_needle)

	_outline = Line2D.new()
	_outline.points = shape
	_outline.closed = true
	_outline.width = 1.4
	_outline.default_color = Color(0.05, 0.025, 0.01, 0.82)
	add_child(_outline)
	_set_guidance_visible(false)


func configure(p_player: Player, p_route: DescentRoute, p_run: DescentRun,
		p_world_seed: int, p_theme: int) -> void:
	player = p_player
	route = p_route
	run = p_run
	world_seed = p_world_seed
	theme = p_theme


func set_active(value: bool) -> void:
	_active = value
	if not value:
		_set_guidance_visible(false)


func _process(dt: float) -> void:
	_t += dt
	if not _active or not is_instance_valid(player) or route == null \
			or not is_instance_valid(run) or run.suspended or run.ended:
		_set_guidance_visible(false)
		return

	var cell := Vector2i(
		floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	if not route.contains(cell):
		_set_guidance_visible(false)
		return
	var destination := _guidance_point(cell)
	var delta := destination - player.global_position
	var toward := Vector2(delta.x, delta.z)
	if toward.length_squared() < 0.16:
		_set_guidance_visible(false)
		return
	var forward3 := -player.global_transform.basis.z
	var forward := Vector2(forward3.x, forward3.z).normalized()
	var heading := forward.angle_to(toward.normalized())

	var viewport_size := Vector2(get_viewport().size)
	var scale := clampf(viewport_size.y / 720.0, 1.0, 1.8)
	var at := Vector2(viewport_size.x * 0.5, 54.0 * scale)
	for item in [_ring, _needle, _outline]:
		item.position = at
		item.scale = Vector2.ONE * scale
	_needle.rotation = heading
	_outline.rotation = heading
	var pulse := 0.72 + sin(_t * 2.1) * 0.08
	_needle.modulate.a = pulse
	_outline.modulate.a = minf(1.0, pulse + 0.12)
	_set_guidance_visible(true)


func _guidance_point(cell: Vector2i) -> Vector3:
	if cell == route.target:
		var local := Vector3(CELL * 0.5, 0.0, CELL * 0.5)
		match route.target_wall:
			0: local.x = CELL - 0.25
			1: local.x = 0.25
			2: local.z = CELL - 0.25
			_: local.z = 0.25
		return Vector3(float(cell.x) * CELL, 0.0,
			float(cell.y) * CELL) + local

	var next := route.next_from(cell)
	var dir := WorldGen.DIRV.find(next - cell)
	if dir < 0:
		return Vector3(float(route.target.x) * CELL + CELL * 0.5, 0.0,
			float(route.target.y) * CELL + CELL * 0.5)
	var edge: Dictionary = WorldGen.edge_info(world_seed, cell, dir, theme)
	var t := float(edge["t"])
	var local := Vector3.ZERO
	match dir:
		0: local = Vector3(CELL - 0.10, 0.0, t)
		1: local = Vector3(0.10, 0.0, t)
		2: local = Vector3(t, 0.0, CELL - 0.10)
		_: local = Vector3(t, 0.0, 0.10)
	return Vector3(float(cell.x) * CELL, 0.0,
		float(cell.y) * CELL) + local


func _set_guidance_visible(value: bool) -> void:
	if _ring != null:
		_ring.visible = value
	if _needle != null:
		_needle.visible = value
	if _outline != null:
		_outline.visible = value
