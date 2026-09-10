class_name GhostLocalPath
extends RefCounted
## Short paths through actual furniture collision. The existing room route
## still chooses the door; this search only gets the figure to that waypoint.

const GRID := 0.5
const MAX_EXPANSIONS := 900
const RETRY_SECONDS := 0.6
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

var _points: Array[Vector3] = []
var _target := Vector3.INF
var _last_from := Vector3.INF
var _retry := 0.0


func waypoint(from: Vector3, target: Vector3, dt: float, clear: Callable, reach := 0.0) -> Vector3:
	_retry = maxf(0.0, _retry - dt)
	if _target == Vector3.INF or target.distance_to(_target) > 0.75 \
			or (_last_from != Vector3.INF and from.distance_to(_last_from) > 2.0):
		invalidate()
	_last_from = from
	while not _points.is_empty() and Vector2(from.x - _points[0].x, from.z - _points[0].z).length() < 0.04:
		_points.pop_front()
	if _points.is_empty() and _retry <= 0.0:
		_target = target
		_retry = RETRY_SECONDS
		_points = _find(from, target, clear, reach)
	return _points[0] if not _points.is_empty() else from


func invalidate() -> void:
	_points.clear()
	_retry = 0.0


func _find(from: Vector3, target: Vector3, clear: Callable, reach: float) -> Array[Vector3]:
	if clear.call(from, target):
		return [target]
	var start_cell := _cell(from)
	var goal_cell := _cell(target)
	var frontier: Array[Dictionary] = []
	_push(frontier, {"at": Vector2i.ZERO, "cost": 0.0, "score": from.distance_to(target)})
	var costs := {Vector2i.ZERO: 0.0}
	var parents := {Vector2i.ZERO: Vector2i.ZERO}
	var closed := {}
	var expanded := 0
	while not frontier.is_empty() and expanded < MAX_EXPANSIONS:
		var entry := _pop(frontier)
		var at: Vector2i = entry.at
		if closed.has(at):
			continue
		closed[at] = true
		expanded += 1
		var point := from + Vector3(at.x * GRID, 0, at.y * GRID)
		# Connect to the exact goal (especially the centre of a narrow door),
		# rather than requiring it to fall on the search lattice.
		var in_reach := point.distance_to(target) <= reach
		if at != Vector2i.ZERO and (in_reach or clear.call(point, target)):
			# Players fit closer to a wall than the wider ghost capsule. A
			# reachable point at arm's length is enough to finish that chase.
			var result: Array[Vector3] = []
			if not in_reach:
				result.append(target)
			while at != Vector2i.ZERO:
				result.push_front(from + Vector3(at.x * GRID, 0, at.y * GRID))
				at = parents[at]
			return _smooth(from, result, clear)
		for offset: Vector2i in NEIGHBOURS:
			var next := at + offset
			if closed.has(next):
				continue
			var position := from + Vector3(next.x * GRID, 0, next.y * GRID)
			var cell := _cell(position)
			# Do not invent a shortcut through a different room. Its real open
			# edges and chase lifetime remain the topology router's concern.
			if cell != start_cell and cell != goal_cell:
				continue
			var cost := float(costs[at]) + point.distance_to(position)
			if cost >= float(costs.get(next, INF)) or not clear.call(point, position):
				continue
			costs[next] = cost
			parents[next] = at
			_push(frontier, {"at": next, "cost": cost, "score": cost + position.distance_to(target)})
	return []


func _smooth(from: Vector3, points: Array[Vector3], clear: Callable) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var next := 0
	while next < points.size():
		var farthest := next
		for index in range(points.size() - 1, next, -1):
			if clear.call(from, points[index]):
				farthest = index
				break
		from = points[farthest]
		result.append(from)
		next = farthest + 1
	return result


static func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / WorldGen.CELL_SIZE), floori(point.z / WorldGen.CELL_SIZE))


static func _push(heap: Array[Dictionary], entry: Dictionary) -> void:
	heap.append(entry)
	var index := heap.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if float(heap[parent].score) <= float(entry.score):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry


static func _pop(heap: Array[Dictionary]) -> Dictionary:
	var first := heap[0]
	var last: Dictionary = heap.pop_back()
	if heap.is_empty():
		return first
	var index := 0
	while index * 2 + 1 < heap.size():
		var child := index * 2 + 1
		if child + 1 < heap.size() and float(heap[child + 1].score) < float(heap[child].score):
			child += 1
		if float(last.score) <= float(heap[child].score):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first
