extends SceneTree
## Regression audit for the hostile figure contract:
## - an unobstructed figure closes the distance;
## - its complete silhouette capsule cannot cross a wall;
## - it never expires while the player remains in its room;
## - entering another room is the one non-combat escape.
##
## Run: godot --headless --path . --script tools/audit_ghost_room_contract.gd

const STEP := 1.0 / 60.0


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var floor_body := _static_box(Vector3(18.0, -0.10, 6.0),
		Vector3(48.0, 0.20, 24.0))
	root.add_child(floor_body)
	var player := Player.new()
	root.add_child(player)
	player.world_seed = WorldGen.level_seed(72931, 4)
	player.level_theme = 4
	player.position = Vector3(8.0, 0.0, 3.0)
	await process_frame
	await physics_frame

	var failures := 0
	var open_fig := _figure(root, player, Vector3(2.0, 0.0, 3.0))
	await process_frame
	var open_start := _flat_gap(open_fig.global_position, player.global_position)
	for i in 120:
		open_fig._advance(STEP)
	var open_end := _flat_gap(open_fig.global_position, player.global_position)
	if open_start - open_end < 2.2:
		failures += 1
		print("FAIL — unobstructed figure closed only %.2fm in two seconds"
			% (open_start - open_end))
	open_fig.queue_free()

	# This wall spans the full width of cell (0, 0), so there is deliberately
	# no legal path around it without leaving the encounter room.
	var wall := _static_box(Vector3(6.0, 1.4, 6.0),
		Vector3(0.30, 2.8, 11.9))
	root.add_child(wall)
	player.global_position = Vector3(9.5, 0.0, 6.0)
	var blocked := _figure(root, player, Vector3(2.5, 0.0, 6.0))
	await process_frame
	await physics_frame
	for i in 900:
		blocked._advance(STEP)
		if blocked.global_position.x > 6.0 - 0.15 - ShadowFigure.MOVE_RADIUS + 0.02:
			failures += 1
			print("FAIL — figure silhouette entered wall at %s"
				% blocked.global_position)
			break

	# Neither elapsed time nor the old random "leaver" behavior may end an
	# encounter while the player remains in the same procedural room.
	blocked.suppressed = true
	blocked.grace = 999.0
	blocked._fade = -1.0
	for i in 3600:
		blocked._physics_process(STEP)
	if blocked._fade >= 0.0 or blocked.is_queued_for_deletion():
		failures += 1
		print("FAIL — figure expired while player remained in the room")

	# Two cells away cannot belong to the same one- or two-cell room.
	player.global_position.x = 30.0
	blocked._physics_process(0.1)
	if blocked._fade < 0.0:
		failures += 1
		print("FAIL — figure persisted after player entered another room")

	# The weeping-angel split. Taking your eyes off one has to cost real ground,
	# not a slightly brisker walk — that difference is the whole mechanic. This
	# runs at z=14, clear of the blocking wall placed above.
	player.global_position = Vector3(8.0, 0.0, 14.0)
	await process_frame
	var pacer := _figure(root, player, Vector3(2.0, 0.0, 14.0))
	await process_frame
	var pace_start := _flat_gap(pacer.global_position, player.global_position)
	for i in 60:
		pacer._advance(STEP)
	var watched := pace_start - _flat_gap(pacer.global_position,
		player.global_position)
	pacer.global_position = Vector3(2.0, 0.0, 14.0)
	await process_frame
	for i in 60:
		pacer._advance(STEP, ShadowFigure.UNSEEN_SPD)
	var unwatched := pace_start - _flat_gap(pacer.global_position,
		player.global_position)
	if unwatched < watched * 2.5:
		failures += 1
		print("FAIL — a second unwatched gained %.2fm against %.2fm watched"
			% [unwatched, watched])
	pacer.queue_free()

	# The waiting anomaly. It is placed in a cell the player has already left,
	# so it must hold its room untouched until they come back — and then be an
	# ordinary figure. Built as INERT it was the one thing in the building that
	# could be neither burned nor escaped, because it never did anything.
	player.global_position = Vector3(30.0, 0.0, 14.0)
	await process_frame
	await physics_frame
	var waiting := ShadowFigure.new()
	waiting.player = player
	waiting.variant = ShadowFigure.GAOLER
	waiting.mode = ShadowFigure.Mode.WAITING
	waiting.position = Vector3(4.0, 0.0, 14.0)
	root.add_child(waiting)
	await process_frame
	await physics_frame
	var parked := waiting.global_position
	for i in 120:
		waiting._physics_process(STEP)
	if waiting.mode != ShadowFigure.Mode.WAITING \
			or parked.distance_to(waiting.global_position) > 0.01 \
			or waiting._fade >= 0.0:
		failures += 1
		print("FAIL — waiting figure did not hold its room while the player was away")
	player.global_position = Vector3(8.0, 0.0, 14.0)
	for i in 5:
		waiting._physics_process(STEP)
	if waiting.mode != ShadowFigure.Mode.AMBIENT:
		failures += 1
		print("FAIL — waiting figure stayed dormant with the player in its room")
	waiting.grace = 0.0
	# An Array is the mutable box a lambda needs; a captured bool never returns.
	var reached := [false]
	waiting.reached_player.connect(func(): reached[0] = true)
	for i in 900:
		waiting._physics_process(STEP)
	if not reached[0]:
		failures += 1
		print("FAIL — promoted waiting figure never reached the player")
	waiting.queue_free()

	print("ghost room audit: open close %.2fm | wall stop x=%.2f | watched %.2fm vs unwatched %.2fm | failures=%d"
		% [open_start - open_end, blocked.global_position.x,
			watched, unwatched, failures])
	if failures == 0:
		print("  PASS — figures persist per-room and reserve their full silhouette")
	quit(0 if failures == 0 else 1)


func _figure(root: Node3D, player: Player, at: Vector3) -> ShadowFigure:
	var f := ShadowFigure.new()
	f.player = player
	f.variant = ShadowFigure.DROWNED
	f.grace = 0.0
	f.origin_room = ShadowFigure.room_for(player, player.global_position)
	f.position = at
	root.add_child(f)
	return f


func _static_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
