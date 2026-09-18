extends SceneTree
## Regression audit for the hostile figure contract:
## - an unobstructed figure closes the distance;
## - its movement capsule cannot cross a wall;
## - it reaches a player in the next area through an offset, narrow doorway;
## - it follows through three rooms, then retires only when safely separated;
## - unseen pursuit eases down rather than parking at a fixed distance;
## - completed levels apply the same subtle speed multiplier to both modes.
##
## Run: godot --headless --path . --script tools/audit_ghost_room_contract.gd

const STEP := 1.0 / 60.0


class BrokenRoomRouteFigure:
	extends ShadowFigure

	func _next_route_cell(start: Vector2i, _goal: Vector2i) -> Vector2i:
		return start


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var floor_body := _static_box(Vector3(18.0, -0.10, 6.0),
		Vector3(48.0, 0.20, 48.0))
	root.add_child(floor_body)
	var player := Player.new()
	root.add_child(player)
	player.world_seed = WorldGen.level_seed(72931, 4)
	player.level_theme = 4
	player.position = Vector3(8.0, 0.0, 3.0)
	await process_frame
	await physics_frame
	player.set_process(false)
	player.set_physics_process(false)

	var failures := 0

	# Baseline near-approach distances still provide a full watched burn window.
	# Later floors accelerate the approach; the lit-torch ward remains intact.
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

	# A transiently disconnected/stale room graph used to return the actor's
	# own position forever. Physical navigation must still make progress toward
	# the player while the high-level route retries.
	player.global_position = Vector3(30.0, 0.0, 3.0)
	var broken_route := BrokenRoomRouteFigure.new()
	broken_route.player = player
	broken_route.variant = ShadowFigure.DROWNED
	broken_route.grace = 0.0
	broken_route.position = Vector3(2.0, 0.0, 3.0)
	root.add_child(broken_route)
	broken_route.set_process(false)
	broken_route.set_physics_process(false)
	await physics_frame
	var broken_start := broken_route.global_position
	for i in 180:
		broken_route._advance(STEP, true)
	if broken_route.global_position.distance_to(broken_start) < 2.0:
		failures += 1
		print("FAIL — missing room hop froze physical pursuit")
	var streamed := broken_route.streaming_cells()
	if streamed.size() < 9 \
			or not streamed.has(ShadowFigure._cell_for(broken_route.global_position)
			+ Vector2i(1, 1)):
		failures += 1
		print("FAIL — hostile streaming omitted the local detour footprint")
	broken_route.queue_free()

	# Finite obstacles must be navigable without letting the movement capsule
	# clip through them. Freeze automatic processing so these checks are driven
	# entirely by the fixed-step advance below; keep the torch visible so the
	# warding state cannot be mistaken for a close-range seizure.
	player.set_process(false)
	player.set_physics_process(false)
	player.flashlight.visible = true
	var box := _static_box(Vector3(6.0, 1.4, 6.0), Vector3(5.0, 2.8, 4.0))
	root.add_child(box)
	player.global_position = Vector3(10.0, 0.0, 6.0)
	var finite := _figure(root, player, Vector3(2.0, 0.0, 6.0))
	finite.set_process(false)
	finite.set_physics_process(false)
	await physics_frame
	var finite_penetrated := false
	for i in 1800:
		finite._advance(STEP, true)
		if not _capsule_clear(player, finite.global_position):
			finite_penetrated = true
			break
	var finite_reach := _flat_gap(finite.global_position, player.global_position)
	if finite_reach > 1.1 or finite_penetrated:
		failures += 1
		print("FAIL — finite box route ended %.2fm away (penetrated=%s)" % [finite_reach, finite_penetrated])
		print("finite route diagnostic: position=%s points=%s pending=%s blocked=%.3f" % [
			finite.position, finite._local_path._points, finite._local_path._search.size(), finite._blocked_time])
	finite.queue_free()
	box.queue_free()
	await physics_frame

	# A U opening facing away from the player requires an initial detour away
	# from the direct line before the figure can round an arm.
	var back_wall := _static_box(Vector3(6.5, 1.4, 6.0), Vector3(0.4, 2.8, 4.0))
	var arm_low := _static_box(Vector3(5.0, 1.4, 4.0), Vector3(3.4, 2.8, 0.4))
	var arm_high := _static_box(Vector3(5.0, 1.4, 8.0), Vector3(3.4, 2.8, 0.4))
	root.add_child(back_wall)
	root.add_child(arm_low)
	root.add_child(arm_high)
	player.global_position = Vector3(10.0, 0.0, 6.0)
	var u_open := _figure(root, player, Vector3(5.5, 0.0, 6.0))
	u_open.set_process(false)
	u_open.set_physics_process(false)
	await physics_frame
	var u_penetrated := false
	var u_away := false
	for i in 1800:
		u_open._advance(STEP, true)
		if u_open.global_position.x < 3.3 - ShadowFigure.MOVE_RADIUS:
			u_away = true
		if not _capsule_clear(player, u_open.global_position):
			u_penetrated = true
			break
	var u_reach := _flat_gap(u_open.global_position, player.global_position)
	if u_reach > 1.1 or u_penetrated or not u_away:
		failures += 1
		print("FAIL — away-facing U route ended %.2fm away (detour=%s penetrated=%s)" % [u_reach, u_away, u_penetrated])
	u_open.queue_free()

	# The skinned walkers must pass the same route with their curved, forward-
	# only steering. Even while a route slice or recovery turn is pending, the
	# visible walk cycle may not freeze at range.
	var walker_u := _walker_figure(root, player, Vector3(5.5, 0.0, 6.0))
	await process_frame
	await physics_frame
	var walker_penetrated := false
	var walker_frozen_frames := 0
	var walker_max_frozen := 0
	for i in 1800:
		var before := walker_u.global_position
		walker_u._advance(STEP, true)
		walker_u._walker.animate(STEP, true)
		var far := _flat_gap(walker_u.global_position,
			player.global_position) > ShadowFigure.ADVANCE_MIN + 0.15
		if far and before.distance_squared_to(walker_u.global_position) < 0.0000001 \
				and walker_u._walker._movement_ratio < 0.05:
			walker_frozen_frames += 1
			walker_max_frozen = maxi(walker_max_frozen, walker_frozen_frames)
		else:
			walker_frozen_frames = 0
		if not _capsule_clear(player, walker_u.global_position):
			walker_penetrated = true
			break
		if not far:
			break
	var walker_reach := _flat_gap(walker_u.global_position,
		player.global_position)
	if walker_reach > 1.2 or walker_penetrated or walker_max_frozen > 6:
		failures += 1
		print("FAIL — 3D walker U pursuit reach=%.2f penetrated=%s frozen=%d" % [
			walker_reach, walker_penetrated, walker_max_frozen])
	walker_u.queue_free()
	back_wall.queue_free()
	arm_low.queue_free()
	arm_high.queue_free()
	await physics_frame
	# The player's narrower body can stand closer to a wall. Failure to fit
	# the ghost at that exact target must not stop its approach at arm's length.
	var wall_near_player := _static_box(Vector3(10.7, 1.4, 6.0), Vector3(0.4, 2.8, 6.0))
	root.add_child(wall_near_player)
	player.global_position = Vector3(10.15, 0.0, 6.0)
	var near_wall := _figure(root, player, Vector3(2.0, 0.0, 6.0))
	await physics_frame
	for i in 900:
		near_wall._advance(STEP)
	if _flat_gap(near_wall.global_position, player.global_position) > 1.1:
		failures += 1
		print("FAIL — player beside wall made ghost stop at %s" % near_wall.global_position)
	near_wall.queue_free()
	wall_near_player.queue_free()
	await physics_frame

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
	# Match the procedural opening rather than an old baked-in offset: the
	# production router and the physical fixture must target the same doorway.
	player.world_seed = 3
	player.level_theme = 6
	var door_info := WorldGen.edge_info(player.world_seed, Vector2i(0, 1), 0, player.level_theme)
	var doorway_along := 12.0 + float(door_info.t)
	var doorway_width := float(door_info.w)
	var chase_z := 22.0 if float(door_info.t) < 6.0 else 14.0
	if door_info.wall or door_info.full_open or absf(doorway_along - chase_z) < 2.0:
		failures += 1
		print("FAIL — offset doorway fixture no longer exercises a narrow off-axis opening")
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
	player.global_position = Vector3(15.5, 0.0, chase_z)
	var crossing := _figure(root, player, Vector3(8.5, 0.0, chase_z))
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

	# Restore the encounter lifetime from before the 3D roster: three crossed
	# room boundaries begin retirement only while the player remains elsewhere.
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
		if lifetime._chase_doors != 3 or lifetime._fade < 0.0 \
				or not lifetime._giving_up:
			failures += 1
			print("FAIL — figure did not retire after %d room boundaries" % 3)
		player.global_position = lifetime.global_position
		lifetime._update_chase_lifetime()
		if lifetime._fade >= 0.0 or lifetime._giving_up:
			failures += 1
			print("FAIL — same-room re-entry did not restore the active chase")
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
	# Unseen pursuit eases toward creep as it closes, but never parks at a
	# fixed distance. Keep the original watched/unwatched tension assertion.
	if unwatched < ShadowFigure.REVEAL_GAIN or unwatched < watched * 1.6:
		failures += 1
		print("FAIL — a second unwatched gained %.2fm against %.2fm watched"
			% [unwatched, watched])
	pacer.queue_free()

	# A close unseen target must still advance; the old safety park made this
	# case wait forever just outside arm's length.
	var no_park := _figure(root, player, Vector3(5.0, 0.0, 3.0))
	await process_frame
	var no_park_start := no_park.global_position
	for i in 60:
		no_park._advance(STEP, false)
	var no_park_gain := _flat_gap(no_park_start, no_park.global_position)
	if no_park_gain <= 0.8:
		failures += 1
		print("FAIL — close unseen figure parked after only %.2fm" % no_park_gain)
	no_park.queue_free()

	# Campaign progression scales observed and unseen pursuit equally by 3% per
	# completed level, so movement and animation can stay in lockstep.
	var progression := _figure(root, player, Vector3(2.0, 0.0, 3.0))
	var base_seen := progression.pursuit_speed(true, 10.0)
	var base_unseen := progression.pursuit_speed(false, 20.0)
	for completed in range(1, 11):
		progression.completed_levels = completed
		var expected := 1.0 + 0.03 * float(completed)
		var seen_ratio := progression.pursuit_speed(true, 10.0) / base_seen
		var unseen_ratio := progression.pursuit_speed(false, 20.0) / base_unseen
		if not is_equal_approx(seen_ratio, expected) \
				or not is_equal_approx(unseen_ratio, expected):
			failures += 1
			print("FAIL — level %d speed multiplier seen=%.4f unseen=%.4f expected=%.4f" \
				% [completed, seen_ratio, unseen_ratio, expected])
	progression.queue_free()

	# A world-placed anomaly may arrive in a cell the player has already left,
	# but it must hunt immediately. A visible figure can never park itself behind
	# an invisible generated-room boundary.
	player.global_position = Vector3(30.0, 0.0, 14.0)
	await process_frame
	await physics_frame
	var world_placed := ShadowFigure.new()
	world_placed.player = player
	world_placed.variant = ShadowFigure.GAOLER
	world_placed.grace = 0.0
	world_placed.position = Vector3(4.0, 0.0, 14.0)
	root.add_child(world_placed)
	await process_frame
	await physics_frame
	var placed_start := world_placed.global_position
	for i in 120:
		world_placed._physics_process(STEP)
	if placed_start.distance_to(world_placed.global_position) < 0.5 \
			or world_placed._fade >= 0.0:
		failures += 1
		print("FAIL — world-placed figure waited for the player's room boundary")
	world_placed.queue_free()

	print("ghost room audit: open close %.2fm | finite reach %.2fm | U reach %.2fm detour=%s | wall stop x=%.2f | watched %.2fm vs unwatched %.2fm | failures=%d"
		% [open_start - open_end, finite_reach, u_reach, u_away,
			wall_stop, watched, unwatched, failures])
	if failures == 0:
		print("  PASS — walls block, doors traverse, and pursuit retires at its room budget")
	root.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)


func _figure(root: Node3D, player: Player, at: Vector3) -> ShadowFigure:
	var f := ShadowFigure.new()
	f.player = player
	f.variant = ShadowFigure.DROWNED
	f.grace = 0.0
	f.position = at
	root.add_child(f)
	f.set_process(false)
	f.set_physics_process(false)
	return f


func _walker_figure(root: Node3D, player: Player, at: Vector3) -> ShadowFigure:
	var f := ShadowFigure.new()
	f.player = player
	f.variant = ShadowFigure.DROWNED
	f.use_walker_prototype = true
	f.walker_model_index = 0
	f.grace = 0.0
	f.position = at
	root.add_child(f)
	f.set_process(false)
	f.set_physics_process(false)
	f._walker.appear(0.0)
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


func _capsule_clear(player: Player, ground: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = ShadowFigure.MOVE_RADIUS
	shape.height = ShadowFigure.MOVE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,
		ground + Vector3(0.0, ShadowFigure.MOVE_HEIGHT * 0.5 + 0.04, 0.0))
	query.exclude = [player.get_rid()]
	query.collision_mask = 1
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
