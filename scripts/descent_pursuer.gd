class_name DescentPursuer
extends Node3D
## A single persistent figure that follows real open cell edges. It is not a
## physics obstacle: the threat is contact, while its route remains constrained
## by generated topology and doorway centres.

signal caught

const BASE_SPEED := 3.0
const REPATH_TIME := 0.5
const SEARCH_RADIUS := 32

var player: Player
## Held still for the length of a blackout. It cannot be burned, so "stand
## still" and "something unkillable is closing at 3 m/s" left the player no
## legal play between them. DescentRun also refuses to start a blackout while
## one of these is alive; this covers the case where it spawns into one.
var frozen := false
var world_seed := 1
var theme := 0
var speed := BASE_SPEED

var _waypoint := Vector3.ZERO
var _repath_left := 0.0
var _last_distance := INF
var _stuck_time := 0.0
var _caught := false


func _ready() -> void:
	var figure := ShadowFigure.new()
	figure.mode = ShadowFigure.Mode.INERT
	# the tallest of the seven: the thing chasing you should loom
	figure.variant = ShadowFigure.TRAILING
	add_child(figure)
	_repath()


func _physics_process(dt: float) -> void:
	if frozen or _caught or player == null or not player.is_inside_tree():
		return
	if global_position.distance_to(player.global_position) < 0.95:
		_caught = true
		caught.emit()
		return
	_repath_left -= dt
	if _repath_left <= 0.0:
		_repath()
	var flat := _waypoint - global_position
	flat.y = 0.0
	var distance := flat.length()
	if distance > 0.06:
		_move_with_slide(flat.normalized(), minf(speed * dt, distance))
		_snap_floor()
	if distance >= _last_distance - 0.03:
		_stuck_time += dt
	else:
		_stuck_time = 0.0
	_last_distance = distance
	if _stuck_time > 4.0 and not player.cam.is_position_in_frustum(global_position):
		# Route motion is collider-free, but a dense prop may make its silhouette
		# appear stuck. Advance to the already-proven waypoint only off camera.
		global_position = _waypoint
		_stuck_time = 0.0
		_repath()


func _repath() -> void:
	_repath_left = REPATH_TIME
	var start := _cell(global_position)
	var goal := _cell(player.global_position)
	if start == goal:
		_waypoint = player.global_position
		return
	var next := _next_cell(start, goal)
	if next == start:
		# Never fall back to a straight line through walls. Retry the bounded
		# search next tick; an off-screen recovery may advance us meanwhile.
		_waypoint = global_position
		return
	_waypoint = _doorway_waypoint(start, next)


func _next_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var parent := {}
	parent[start] = start
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == goal:
			break
		if maxi(absi(c.x - start.x), absi(c.y - start.y)) >= SEARCH_RADIUS:
			continue
		for dir in 4:
			if WorldGen.edge_info(world_seed, c, dir, theme)["wall"]:
				continue
			var nb: Vector2i = c + WorldGen.DIRV[dir]
			if parent.has(nb):
				continue
			parent[nb] = c
			queue.append(nb)
	if not parent.has(goal):
		return start
	var at := goal
	while parent[at] != start:
		at = parent[at]
	return at


func _doorway_waypoint(from: Vector2i, to: Vector2i) -> Vector3:
	var dir := WorldGen.DIRV.find(to - from)
	if dir < 0:
		return Vector3(float(to.x) * 12.0 + 6.0, 0.0,
			float(to.y) * 12.0 + 6.0)
	var edge: Dictionary = WorldGen.edge_info(world_seed, from, dir, theme)
	var t := float(edge["t"])
	match dir:
		0:
			return Vector3(float(from.x + 1) * 12.0 + 0.25, 0.0,
				float(from.y) * 12.0 + t)
		1:
			return Vector3(float(from.x) * 12.0 - 0.25, 0.0,
				float(from.y) * 12.0 + t)
		2:
			return Vector3(float(from.x) * 12.0 + t, 0.0,
				float(from.y + 1) * 12.0 + 0.25)
		_:
			return Vector3(float(from.x) * 12.0 + t, 0.0,
				float(from.y) * 12.0 - 0.25)


func _snap_floor() -> void:
	var world := get_world_3d()
	if world == null:
		return
	var from := global_position + Vector3(0, 2.4, 0)
	var query := PhysicsRayQueryParameters3D.create(
		from, global_position + Vector3(0, -2.0, 0))
	var hit := world.direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["normal"].y > 0.7:
		global_position.y = hit["position"].y


func _move_with_slide(direction: Vector3, amount: float) -> void:
	var world := get_world_3d()
	if world == null:
		global_position += direction * amount
		return
	var chest := global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(
		chest, chest + direction * maxf(0.65, amount + 0.25))
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += direction * amount
		return
	var normal: Vector3 = hit["normal"]
	normal.y = 0.0
	var slide := direction.slide(normal).normalized()
	if slide.length_squared() < 0.01:
		var left := Vector3(-direction.z, 0, direction.x)
		var right := -left
		slide = left if (global_position + left).distance_to(_waypoint) \
			< (global_position + right).distance_to(_waypoint) else right
	global_position += slide * amount


func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))
