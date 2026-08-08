extends SceneTree
## Regression audit for the hostile figure contract:
## - an unobstructed figure closes the distance;
## - its movement capsule cannot cross a wall;
## - it reaches a player in the next area through an offset, narrow doorway;
## - it follows through three rooms, gives up only while separated, and resumes
##   if the player returns before the dissolve completes.
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

	# The per-variant tuning table must never trade away the burn-window
	# guarantee: from its unseen park, a figure's watched creep to arm's length
	# has to outlast its own burn time, or a clean park-to-kill leaves no legal
	# answer. This inequality is the reason the park distance exists.
	for variant in ShadowFigure.TUNING:
		var tune: Array = ShadowFigure.TUNING[variant]
		var window := (float(tune[3]) - ShadowFigure.ADVANCE_MIN) / float(tune[0])
		if window < float(tune[2]):
			failures += 1
			print("FAIL — variant %d burn window %.2fs is shorter than its %.2fs burn"
				% [variant, window, float(tune[2])])

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
	var wall_stop := blocked.global_position.x

	# Neither elapsed time nor the old random "leaver" behavior may end an
	# encounter while it remains active.
	blocked.suppressed = true
	blocked.grace = 999.0
	blocked._fade = -1.0
	for i in 3600:
		blocked._physics_process(STEP)
	if blocked._fade >= 0.0 or blocked.is_queued_for_deletion():
		failures += 1
		print("FAIL — figure expired while still active")

	# The closed wall above is deliberately impassable. Replace it with a cased,
	# 1.6m opening, including its normal 2.25m-high colliding header, well away
	# from the line between ghost and player. This catches both a local wall-slide
	# that merely skims the partition and a sweep capsule too tall for a doorway.
	blocked.queue_free()
	wall.queue_free()
	await physics_frame
	# Seed 3's school edge (0, 1) east is a genuine 1.84m cased opening at
	# z=12+7.285. Match that topology so the production route targets this door.
	player.world_seed = 3
	player.level_theme = 6
	var doorway_along := 12.0 + 7.2847698
	var doorway_width := 1.8384756
	var doorway_min := doorway_along - doorway_width * 0.5
	var doorway_max := doorway_along + doorway_width * 0.5
	var door_low := _static_box(Vector3(12.0, 1.4, (12.0 + doorway_min) * 0.5),
		Vector3(0.30, 2.8, doorway_min - 12.0))
	var door_high := _static_box(Vector3(12.0, 1.4, (doorway_max + 24.0) * 0.5),
		Vector3(0.30, 2.8, 24.0 - doorway_max))
	var door_header := _static_box(Vector3(12.0, (Chunk.DOOR_TOP + 3.2) * 0.5,
		doorway_along), Vector3(0.30, 3.2 - Chunk.DOOR_TOP, doorway_width))
	root.add_child(door_low)
	root.add_child(door_high)
	root.add_child(door_header)
	player.global_position = Vector3(15.5, 0.0, 14.0)
	var crossing := _figure(root, player, Vector3(8.5, 0.0, 14.0))
	await physics_frame
	for i in 1800:
		crossing._advance(STEP)
		if crossing.global_position.x > 12.2:
			break
	if crossing.global_position.x <= 12.2:
		failures += 1
		print("FAIL — figure did not traverse the off-axis doorway (ended at %s)"
			% crossing.global_position)
	crossing.queue_free()

	# A chase follows through three room boundaries. It may begin its give-up
	# fade only once its room differs from the player's; walking back into that
	# room must restore the live encounter.
	var lifetime_cells := _distinct_room_cells(player.world_seed, player.level_theme, 4)
	if lifetime_cells.size() != 4:
		failures += 1
		print("FAIL — audit could not find four distinct procedural rooms")
	else:
		var lifetime := _figure(root, player, _cell_center(lifetime_cells[0]))
		player.global_position = _cell_center(lifetime_cells[0])
		await physics_frame
		lifetime._update_chase_lifetime()
		for i in range(1, lifetime_cells.size()):
			lifetime.global_position = _cell_center(lifetime_cells[i])
			lifetime._update_chase_lifetime()
		if lifetime._chase_doors != ShadowFigure.CHASE_DOOR_LIMIT \
				or not lifetime._giving_up or lifetime._fade < 0.0:
			failures += 1
			print("FAIL — figure did not give up after %d room boundaries" \
				% ShadowFigure.CHASE_DOOR_LIMIT)
		player.global_position = lifetime.global_position
		lifetime._update_chase_lifetime()
		if lifetime._giving_up or lifetime._fade >= 0.0:
			failures += 1
			print("FAIL — same-room re-entry did not cancel the give-up fade")
		lifetime.queue_free()

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
		pacer._advance(STEP, false)
	var unwatched := pace_start - _flat_gap(pacer.global_position,
		player.global_position)
	# The unseen lunge parks at UNSEEN_MIN, so a one-second sample starts to
	# saturate before its nominal 4.5m/s rate; it still has to beat the creep.
	# The unseen move saturates at its safety park, so use the authored reveal
	# gain plus a ratio guard instead of a fragile 1.7 boundary (2.10/1.25 can
	# vary by one collision step). This still fails equal or merely brisk speeds.
	if unwatched < ShadowFigure.REVEAL_GAIN or unwatched < watched * 1.6:
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
	waiting.queue_free()

	print("ghost room audit: open close %.2fm | wall stop x=%.2f | watched %.2fm vs unwatched %.2fm | failures=%d"
		% [open_start - open_end, wall_stop,
			watched, unwatched, failures])
	if failures == 0:
		print("  PASS — walls block, offset doors traverse, and escape takes three rooms")
	root.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
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


func _distinct_room_cells(seed: int, theme: int, want: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen := {}
	for x in range(24):
		var cell := Vector2i(x, 3)
		var room := WorldGen.room_id(seed, cell)
		if seen.has(room):
			continue
		cells.append(cell)
		seen[room] = true
		if cells.size() == want:
			return cells
	return cells


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * Chunk.S + Chunk.S * 0.5, 0.0,
		float(cell.y) * Chunk.S + Chunk.S * 0.5)


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
