class_name GhostLocalPath
extends RefCounted
## Short paths through actual furniture collision. The existing room route
## still chooses the door; this search only gets the figure to that waypoint.

const GRID := 0.5
const MAX_EXPANSIONS := 900
const RETRY_SECONDS := 0.6
## Physics runs on the main thread. Never spend a whole 900-node search in a
## single tick (three shore-bound walkers previously stalled it for ~90ms).
const SEARCH_BUDGET_USEC := 650
const SEARCH_NODES_PER_TICK := 24
# A moving player or newly streamed neighbouring chunk can make a failed route
# valid almost immediately. Multi-second silence here presented as frozen AI.
const UNREACHABLE_RETRY_SECONDS := 0.65
const SHORTCUT_LOOKAHEAD := 8
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]

var _points: Array[Vector3] = []
var _target := Vector3.INF
var _last_from := Vector3.INF
var _retry := 0.0
var _search := {}


func waypoint(from: Vector3, target: Vector3, dt: float, clear: Callable,
		reach := 0.0, reachable := Callable(), allow_partial := false) -> Vector3:
	_retry = maxf(0.0, _retry - dt)
	if _last_from != Vector3.INF and from.distance_to(_last_from) > 2.0:
		invalidate()
	# Finish a short in-flight search despite player motion. Repeatedly
	# starting it over can starve navigation for a running target. Keep following
	# the previous safe route while calculating its replacement.
	var changed := _search.is_empty() and (_target == Vector3.INF \
		or target.distance_to(_target) > 0.75)
	if changed:
		_search.clear()
		_target = target
		_retry = 0.0
	_last_from = from
	while not _points.is_empty() and from.distance_to(_points[0]) < 0.04:
		_points.pop_front()
	# Re-test the next segment as the actor approaches a corner. The original
	# path was smoothed only from its old starting point, so it otherwise held
	# the exact corner until arrival and then changed direction abruptly. Once
	# the capsule has a clear diagonal to the following point, release that
	# corner early and let continuous steering describe a natural arc.
	for index in range(mini(_points.size() - 1, SHORTCUT_LOOKAHEAD), 0, -1):
		if clear.call(from, _points[index]):
			_points = _points.slice(index)
			break
	# A moving target must not leave a completed one-point route at the player's
	# old position until it has moved another 75cm.
	if _search.is_empty() and _retry <= 0.0 and (changed or _points.size() <= 1):
		if clear.call(from, target):
			_target = target
			_retry = RETRY_SECONDS
			_points.assign([target])
		elif changed or _points.is_empty():
			_begin_search(from, target, reach, allow_partial)
	if not _search.is_empty():
		_step_search(clear, reachable)
	return _points[0] if not _points.is_empty() else from


func invalidate() -> void:
	_points.clear()
	_search.clear()
	_target = Vector3.INF
	_retry = 0.0


func _begin_search(from: Vector3, target: Vector3, reach: float, partial: bool) -> void:
	_target = target
	var frontier: Array[Dictionary] = []
	_push(frontier, {"at": Vector2i.ZERO, "score": from.distance_to(target)})
	_search = {"from": from, "target": target, "reach": reach, "partial": partial,
		"frontier": frontier, "costs": {Vector2i.ZERO: 0.0},
		"parents": {Vector2i.ZERO: Vector2i.ZERO}, "closed": {}, "expanded": 0,
		"start_cell": _cell(from), "goal_cell": _cell(target),
		"closest": Vector2i.ZERO, "gap": from.distance_to(target)}


func _step_search(clear: Callable, reachable: Callable) -> void:
	var started := Time.get_ticks_usec()
	var frontier: Array[Dictionary] = _search.frontier
	var from: Vector3 = _search.from
	var target: Vector3 = _search.target
	var count := 0
	while not frontier.is_empty() and int(_search.expanded) < MAX_EXPANSIONS:
		if count >= SEARCH_NODES_PER_TICK or (count > 0 \
				and Time.get_ticks_usec() - started >= SEARCH_BUDGET_USEC):
			_publish_search_progress(clear)
			return
		var at: Vector2i = _pop(frontier).at
		if _search.closed.has(at):
			continue
		_search.closed[at] = true
		_search.expanded += 1
		count += 1
		var point := from + Vector3(at.x * GRID, 0, at.y * GRID)
		# Keep the best proven-reachable frontier even for an ordinary search.
		# It gives a newly blocked walker somewhere safe to advance while the
		# remaining slices compute the complete detour.
		if point.distance_to(target) < float(_search.gap) - 0.001:
			_search.closest = at
			_search.gap = point.distance_to(target)
		var in_reach: bool = point.distance_to(target) <= float(_search.reach) \
			and (not reachable.is_valid() or reachable.call(point))
		if at != Vector2i.ZERO and (in_reach or clear.call(point, target)):
			_finish_search(at, not in_reach, clear)
			return
		for offset: Vector2i in NEIGHBOURS:
			var next := at + offset
			if _search.closed.has(next):
				continue
			var position := from + Vector3(next.x * GRID, 0, next.y * GRID)
			var cell := _cell(position)
			var start_cell: Vector2i = _search.start_cell
			if maxi(absi(cell.x - start_cell.x), absi(cell.y - start_cell.y)) > 1 \
					and cell != _search.goal_cell:
				continue
			var cost := float(_search.costs[at]) + point.distance_to(position)
			if cost >= float(_search.costs.get(next, INF)) or not clear.call(point, position):
				continue
			_search.costs[next] = cost
			_search.parents[next] = at
			_push(frontier, {"at": next, "score": cost + position.distance_to(target)})
	_finish_search(_search.closest if bool(_search.partial) else Vector2i.ZERO, false, clear)


func _publish_search_progress(clear: Callable) -> void:
	if not _points.is_empty() or _search.is_empty():
		return
	var at: Vector2i = _search.closest
	if at == Vector2i.ZERO:
		return
	var result: Array[Vector3] = []
	var origin: Vector3 = _search.from
	while at != Vector2i.ZERO:
		result.push_front(origin + Vector3(at.x * GRID, 0, at.y * GRID))
		at = _search.parents[at]
	_points = _smooth(_last_from, result, clear)


func _finish_search(at: Vector2i, include_target: bool, clear: Callable) -> void:
	var result: Array[Vector3] = []
	if include_target:
		result.append(_search.target)
	var from: Vector3 = _search.from
	while at != Vector2i.ZERO:
		result.push_front(from + Vector3(at.x * GRID, 0, at.y * GRID))
		at = _search.parents[at]
	# A replacement is computed while following the previous route. Join near
	# the actor's current position, not back at the search's obsolete origin.
	if not result.is_empty():
		var nearest := 0
		for index in result.size():
			if _last_from.distance_squared_to(result[index]) < _last_from.distance_squared_to(result[nearest]):
				nearest = index
		for index in range(mini(nearest + SHORTCUT_LOOKAHEAD, result.size() - 1), nearest - 1, -1):
			if clear.call(_last_from, result[index]):
				result = result.slice(index)
				break
	_points = _smooth(_last_from, result, clear)
	_retry = RETRY_SECONDS if not result.is_empty() else UNREACHABLE_RETRY_SECONDS
	_search.clear()


func _find(from: Vector3, target: Vector3, clear: Callable, reach: float,
		reachable := Callable(), allow_partial := false) -> Array[Vector3]:
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
	var closest := Vector2i.ZERO
	var closest_gap := from.distance_to(target)
	while not frontier.is_empty() and expanded < MAX_EXPANSIONS:
		var entry := _pop(frontier)
		var at: Vector2i = entry.at
		if closed.has(at):
			continue
		closed[at] = true
		expanded += 1
		var point := from + Vector3(at.x * GRID, 0, at.y * GRID)
		if allow_partial and point.distance_to(target) < closest_gap - 0.001:
			closest = at
			closest_gap = point.distance_to(target)
		# Connect to the exact goal (especially the centre of a narrow door),
		# rather than requiring it to fall on the search lattice.
		var in_reach: bool = point.distance_to(target) <= reach \
			and (not reachable.is_valid() or reachable.call(point))
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
			# Physical collision remains authoritative. Permit a one-cell skirt
			# around a merged room; restricting this to exactly two lattice cells
			# rejected valid detours around furniture straddling cell boundaries.
			if maxi(absi(cell.x - start_cell.x), absi(cell.y - start_cell.y)) > 1 \
					and cell != goal_cell:
				continue
			var cost := float(costs[at]) + point.distance_to(position)
			if cost >= float(costs.get(next, INF)) or not clear.call(point, position):
				continue
			costs[next] = cost
			parents[next] = at
			_push(frontier, {"at": next, "cost": cost, "score": cost + position.distance_to(target)})
	# In Poolrooms a target can be standing in a basin we may never enter.
	# Every parent edge passed the same dry-ground sweep as ordinary movement;
	# approach the nearest reachable shore without adding the wet target itself.
	if allow_partial and closest != Vector2i.ZERO:
		var result: Array[Vector3] = []
		var at := closest
		while at != Vector2i.ZERO:
			result.push_front(from + Vector3(at.x * GRID, 0, at.y * GRID))
			at = parents[at]
		return _smooth(from, result, clear)
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
