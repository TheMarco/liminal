class_name EnemyLocalPath
extends GhostLocalPath
## Time-sliced surface search. Unlike the legacy flat grid, nodes retain their
## real elevation and ladders add vertical edges. Room routing remains a hint;
## actual collision decides whether each step exists.
const STEP := 0.25
const LIMIT := 3600
var traversal: EnemyTraversal

func _key(point: Vector3) -> Vector3i:
	# Preserve off-grid passage samples as separate nodes, not rounded back
	# into the wall that made the ordinary grid fail in the first place.
	return Vector3i(roundi(point.x / 0.025), roundi(point.y / 0.05), roundi(point.z / 0.025))

func _begin_search(from: Vector3, target: Vector3, reach: float, partial: bool) -> void:
	_target = target
	var start := _key(from)
	var frontier: Array[Dictionary] = []
	_push(frontier, {"at": start, "score": from.distance_to(target)})
	_search = {"from": from, "target": target, "reach": reach, "partial": partial,
		"frontier": frontier, "costs": {start: 0.0}, "parents": {start: start},
		"positions": {start: from}, "closed": {}, "expanded": 0,
		"start": start, "closest": start, "gap": from.distance_to(target)}

func _step_search(clear: Callable, reachable: Callable) -> void:
	var started := Time.get_ticks_usec()
	var count := 0
	var frontier: Array[Dictionary] = _search.frontier
	var target: Vector3 = _search.target
	while not frontier.is_empty() and int(_search.expanded) < LIMIT:
		if count >= SEARCH_NODES_PER_TICK or (count > 0 and Time.get_ticks_usec() - started >= SEARCH_BUDGET_USEC):
			_publish_search_progress(clear)
			return
		var at: Vector3i = _pop(frontier).at
		if _search.closed.has(at): continue
		_search.closed[at] = true
		_search.expanded += 1
		count += 1
		var point: Vector3 = _search.positions[at]
		if point.distance_to(target) < float(_search.gap) - 0.001:
			_search.closest = at
			_search.gap = point.distance_to(target)
		var in_reach: bool = point.distance_to(target) <= float(_search.reach) \
			and (not reachable.is_valid() or reachable.call(point))
		if at != _search.start and (in_reach or clear.call(point, target)):
			_finish_surface_search(at, not in_reach, clear, true)
			return
		var neighbors: Array[Vector3] = traversal.extra_neighbors(point)
		for offset: Vector2i in NEIGHBOURS:
			var next := traversal.project(point, point + Vector3(offset.x * STEP, 0, offset.y * STEP))
			if next != Vector3.INF: neighbors.append(next)
		for next: Vector3 in neighbors:
			var key := _key(next)
			var cell := _cell(next)
			var start_cell := _cell(_search.from)
			if maxi(absi(cell.x - start_cell.x), absi(cell.y - start_cell.y)) > 1 and cell != _cell(target): continue
			var cost := float(_search.costs[at]) + point.distance_to(next)
			if _search.closed.has(key) or cost >= float(_search.costs.get(key, INF)) or not clear.call(point, next): continue
			_search.positions[key] = next
			_search.costs[key] = cost
			_search.parents[key] = at
			_push(frontier, {"at": key, "score": cost + next.distance_to(target)})
	_finish_surface_search(_search.closest if bool(_search.partial) else _search.start, false, clear)

func _surface_points(at: Vector3i) -> Array[Vector3]:
	var result: Array[Vector3] = []
	while at != _search.start:
		result.push_front(_search.positions[at])
		at = _search.parents[at]
	return result

func _publish_search_progress(clear: Callable) -> void:
	if _search.is_empty(): return
	# The closest proven node advances as each time slice expands. Refresh a
	# partial route even while the actor is following the previous prefix; keeping
	# the first published point forever made host-load timing decide whether a
	# follower repeatedly returned to a doorway jamb.
	var result := _safe_partial(_surface_points(_search.closest))
	var joined := false
	for index in range(result.size() - 1, -1, -1):
		if clear.call(_last_from, result[index]):
			result = result.slice(index)
			joined = true
			break
	if not joined:
		return
	var candidate := _smooth(_last_from, result, clear)
	if not candidate.is_empty():
		_points = candidate

func _safe_partial(points: Array[Vector3]) -> Array[Vector3]:
	# Do not commit to an irreversible drop while still searching for a route
	# back up to the target's deck. A complete path may use it once an exit has
	# actually been found. A target in the basin can be approached immediately.
	if (_search.target as Vector3).y >= (_search.from as Vector3).y - 0.1:
		for index in points.size():
			if points[index].y < (_search.from as Vector3).y - 0.30:
				return points.slice(0, index)
	return points

func _finish_surface_search(at: Vector3i, include_target: bool, clear: Callable, complete := false) -> void:
	var result := _surface_points(at)
	if include_target: result.append(_search.target)
	if not complete: result = _safe_partial(result)
	# Join the most advanced reachable point, never return to the old origin.
	for index in range(result.size() - 1, -1, -1):
		if clear.call(_last_from, result[index]):
			result = result.slice(index)
			break
	_points = _smooth(_last_from, result, clear)
	_retry = RETRY_SECONDS if not result.is_empty() else UNREACHABLE_RETRY_SECONDS
	_search.clear()
