extends SceneTree
## Scheduling contract, independent of hardware timing and heavy model assets.

var failures: Array[String] = []

class HeldPath extends GhostLocalPath:
	var starts := 0
	func _begin_search(from: Vector3, target: Vector3, reach: float, partial: bool) -> void:
		starts += 1
		super._begin_search(from, target, reach, partial)
	func _step_search(_clear: Callable, _reachable: Callable) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var blocked := func(_a: Vector3, _b: Vector3) -> bool: return false
	var open := func(_a: Vector3, _b: Vector3) -> bool: return true
	var path := HeldPath.new()
	path.waypoint(Vector3.ZERO, Vector3(10, 0, 0), 0.016, blocked)
	for frame in 120:
		path.waypoint(Vector3.ZERO, Vector3(10, 0, frame * 0.2), 0.016, blocked)
	check(path.starts == 1, "moving target repeatedly discarded an unfinished search")
	path.invalidate()
	check(path._search.is_empty() and path._points.is_empty(), "invalidation kept pending work")

	# A long L-shaped route requires multiple slices. Search checks all physical
	# edges; direct shortcuts that cross the inside of the bend remain forbidden.
	var corridor := func(a: Vector3, b: Vector3) -> bool:
		return (is_zero_approx(a.x) and is_zero_approx(b.x) and minf(a.z, b.z) >= 0.0) \
			or (is_equal_approx(a.z, 20.0) and is_equal_approx(b.z, 20.0) and minf(a.x, b.x) >= 0.0)
	var search := GhostLocalPath.new()
	var slices := 0
	var expanded := 0
	for tick in 300:
		var waypoint := search.waypoint(Vector3.ZERO,
			Vector3(20, 0, 20), 0.016, corridor)
		slices += 1
		if tick == 0:
			check(waypoint != Vector3.ZERO and corridor.call(Vector3.ZERO, waypoint),
				"incremental search parked instead of publishing safe progress")
		if search._search.is_empty():
			break
		var next_expanded: int = search._search.expanded
		check(next_expanded - expanded <= GhostLocalPath.SEARCH_NODES_PER_TICK,
			"search exceeded its per-tick node budget")
		expanded = next_expanded
	check(slices > 1 and search._search.is_empty() and not search._points.is_empty(),
		"incremental search failed to complete the detour")
	if not search._points.is_empty():
		check(corridor.call(Vector3.ZERO, search._points[0]), "detour cut through the bend")

	# The actor moved along its previous path while this replacement was built.
	var rejoin := GhostLocalPath.new()
	rejoin._begin_search(Vector3.ZERO, Vector3(10, 0, 0), 0.0, false)
	for index in range(1, 21):
		rejoin._search.parents[Vector2i(index, 0)] = Vector2i(index - 1, 0)
	rejoin._last_from = Vector3(8, 0, 0)
	rejoin._finish_search(Vector2i(20, 0), false, open)
	check(not rejoin._points.is_empty() and rejoin._points[0].x >= 8.0,
		"replacement path sent the actor back to its obsolete starting point")
	print("navigation budget audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
