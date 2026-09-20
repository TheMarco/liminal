extends SceneTree
## Focused contract for live doorway changes: every ordinary navigation cache
## is discarded immediately, without cancelling an authored ladder/slide move.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL — ", message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ShadowFigures.new()
	var figure := ShadowFigure.new()
	var slide := PoolSlide.new()
	root.add_child(manager)
	manager.add_child(figure)
	manager.add_child(slide)
	manager._figs.append(figure)

	figure._direct_route_left = 0.4
	figure._direct_route_clear = true
	figure._route_left = 0.4
	figure._route_from = Vector2i(1, 2)
	figure._route_goal = Vector2i(3, 4)
	figure._route_next = Vector2i(2, 2)
	figure._route_waypoint = Vector3(24, 0, 30)
	figure._local_path._points.assign([Vector3(3, 0, 4)])
	figure._local_path._target = Vector3(8, 0, 9)
	figure._local_path._retry = 0.5
	figure._local_path._search = {"in_flight": true}
	figure._blocked_time = 0.3
	figure._recovery_direction = Vector3.RIGHT
	figure._recovery_left = 0.4
	figure._avoid_direction = Vector3.LEFT
	figure._avoid_left = 0.2
	figure._door_attempt_left = 0.8

	# These fields are the in-flight traversal token and must survive unchanged.
	figure._vertical_target = Vector3(4, 2, 5)
	figure._vertical_ignored = RID()
	figure._ladder_landing = Vector3(5, 2, 5)
	figure._ladder_top = Vector3(4, 2, 5)
	figure._ladder_facing = Vector3.FORWARD
	figure._ladder_phase = 2
	figure._pool_slide = slide
	figure._slide_distance = 3.25
	figure._slide_speed = 4.5
	figure._slide_rearm = 0.6

	manager.invalidate_navigation_for_topology_change()

	check(figure._direct_route_left == 0.0 and not figure._direct_route_clear,
		"direct-route clearance cache survived topology invalidation")
	check(figure._route_left == 0.0 and figure._route_from == ShadowFigure.NO_ROOM
		and figure._route_goal == ShadowFigure.NO_ROOM
		and figure._route_next == ShadowFigure.NO_ROOM
		and figure._route_waypoint == Vector3.INF,
		"room route or doorway waypoint survived topology invalidation")
	check(figure._local_path._points.is_empty()
		and figure._local_path._target == Vector3.INF
		and figure._local_path._retry == 0.0
		and figure._local_path._search.is_empty(),
		"time-sliced local path survived topology invalidation")
	check(figure._blocked_time == 0.0
		and figure._recovery_direction == Vector3.ZERO
		and figure._recovery_left == 0.0
		and figure._avoid_direction == Vector3.ZERO
		and figure._avoid_left == 0.0
		and figure._door_attempt_left == 0.0,
		"blocked/recovery steering survived topology invalidation")
	check(figure._vertical_target == Vector3(4, 2, 5)
		and figure._ladder_landing == Vector3(5, 2, 5)
		and figure._ladder_top == Vector3(4, 2, 5)
		and figure._ladder_facing == Vector3.FORWARD
		and figure._ladder_phase == 2,
		"ladder traversal was cancelled by topology invalidation")
	check(figure._pool_slide == slide
		and figure._slide_distance == 3.25
		and figure._slide_speed == 4.5
		and figure._slide_rearm == 0.6,
		"slide traversal was cancelled by topology invalidation")

	manager.free()
	await process_frame
	print("enemy topology invalidation audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
