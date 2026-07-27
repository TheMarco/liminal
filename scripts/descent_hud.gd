class_name DescentHUD
extends CanvasLayer
## Minimal Descent-only route guidance, and the one instrument the player has.
##
## It is deliberately a worse instrument the deeper you go. On the first two
## floors it names the exact generated doorway. In the middle of the run it
## drops to a bearing — a straight line through walls, which the player has to
## translate into a route themselves. Late it only takes a reading every few
## seconds and holds it. In the Annex there is nothing.
##
## This is what makes the objective take a while to find: the route is longer
## with depth, but the searching is what actually costs time.

const CELL := 12.0
## Seconds between readings once the needle drops to intermittent pings, and
## how long a held reading stays legible.
const PING_INTERVAL := 8.0
const PING_BRIGHT := 1.1

enum Guide { EXACT, BEARING, PING, NONE }

## Indexed by Descent floor. Casino and mall teach the instrument; the office,
## airport and school take the doorways away; the prison and asylum take the
## live reading away; the Annex takes the needle.
const FLOOR_GUIDE := [
	Guide.EXACT, Guide.EXACT,
	Guide.BEARING, Guide.BEARING, Guide.BEARING,
	Guide.PING, Guide.PING,
	Guide.NONE,
]

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
var _ping_left := 0.0
var _held := Vector2.ZERO


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
	# A new floor gets a fresh reading rather than inheriting a stale bearing
	# aimed at the last floor's lift.
	_ping_left = 0.0
	_held = Vector2.ZERO


func guide_mode() -> int:
	if run == null:
		return Guide.EXACT
	var idx := clampi(run.floor_idx, 0, FLOOR_GUIDE.size() - 1)
	return FLOOR_GUIDE[idx]


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
	var mode := guide_mode()
	# The needle is the building's instrument, not the player's. When the power
	# fails it fails with everything else.
	if mode == Guide.NONE or run.blackout:
		_set_guidance_visible(false)
		return

	var cell := Vector2i(
		floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	if not route.contains(cell):
		_set_guidance_visible(false)
		return

	# Standing in the objective room, every mode simply points at the facade —
	# by then the set piece is in front of you and coyness is only annoying.
	var live_mode := Guide.EXACT if cell == route.target else mode
	var destination := _guidance_point(cell, live_mode)
	var delta := destination - player.global_position
	var toward := Vector2(delta.x, delta.z)
	if toward.length_squared() < 0.16:
		_set_guidance_visible(false)
		return
	toward = toward.normalized()

	var freshness := 1.0
	if live_mode == Guide.PING:
		_ping_left -= dt
		if _ping_left <= 0.0 or _held == Vector2.ZERO:
			_ping_left = PING_INTERVAL
			_held = toward
		toward = _held
		# A reading decays as you walk away from where you took it.
		freshness = clampf(_ping_left / PING_INTERVAL, 0.0, 1.0)

	var forward3 := -player.global_transform.basis.z
	var forward := Vector2(forward3.x, forward3.z).normalized()
	var heading := forward.angle_to(toward)

	var viewport_size := Vector2(get_viewport().size)
	var scale := clampf(viewport_size.y / 720.0, 1.0, 1.8)
	var at := Vector2(viewport_size.x * 0.5, 54.0 * scale)
	for item in [_ring, _needle, _outline]:
		item.position = at
		item.scale = Vector2.ONE * scale
	_needle.rotation = heading
	_outline.rotation = heading
	var pulse := 0.72 + sin(_t * 2.1) * 0.08
	if live_mode == Guide.PING:
		# Bright at the moment of the reading, all but gone before the next one.
		pulse *= lerpf(0.22, PING_BRIGHT, freshness * freshness)
	elif live_mode == Guide.BEARING:
		pulse *= 0.86
	_needle.modulate.a = clampf(pulse, 0.0, 1.0)
	_outline.modulate.a = clampf(pulse + 0.12, 0.0, 1.0)
	_ring.modulate.a = clampf(0.4 + freshness * 0.6, 0.0, 1.0)
	_set_guidance_visible(true)


func _guidance_point(cell: Vector2i, mode: int) -> Vector3:
	if cell == route.target:
		var local := Vector3(CELL * 0.5, 0.0, CELL * 0.5)
		match route.target_wall:
			0: local.x = CELL - 0.25
			1: local.x = 0.25
			2: local.z = CELL - 0.25
			_: local.z = 0.25
		return Vector3(float(cell.x) * CELL, 0.0,
			float(cell.y) * CELL) + local

	# A bearing is honest about being a bearing: it aims at the objective room
	# through whatever is in the way, and finding the doors is the player's job.
	if mode != Guide.EXACT:
		return Vector3(float(route.target.x) * CELL + CELL * 0.5, 0.0,
			float(route.target.y) * CELL + CELL * 0.5)

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
