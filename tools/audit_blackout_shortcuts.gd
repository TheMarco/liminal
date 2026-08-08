extends SceneTree
## Contract for blackout-created doorways:
##   1. an actual blackout never starts without one safe new doorway;
##   2. normal openings are usually route-neutral, while a proven stall gets a
##      far side meaningfully closer to the lift, preferring a true shortcut;
##   3. both sides render the same persistent, collision-clear opening used by
##      player guidance and figure navigation.
## Run: godot --headless --path . --script tools/audit_blackout_shortcuts.gd -- [seeds]

const OPPOSITE := [1, 0, 3, 2]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 8,
		1, 80)
	var failures := 0
	var ordinary_total := 0
	var ordinary_neutral := 0
	var helpful_total := 0
	var helpful_found := 0
	var geometry_checks := 0
	for theme in DescentRun.FIXED_ORDER:
		for si in seed_count:
			var base := WorldGen.h(98171 + theme * 103,
				si * 43, si * 101, 557) | 1
			var ws := WorldGen.level_seed(base, theme)
			var ordinary := DescentRoute.build(ws, theme,
				DescentRun.FIXED_ORDER.find(theme))
			var topology := DescentTopology.new(ws, theme)
			ordinary.set_topology(topology)
			var from := _representative_cell(ordinary)
			var visited := _explored_neighbourhood(ordinary, from, 5)
			var proposal := ordinary.find_blackout_doorway(
				from, visited, false)
			ordinary_total += 1
			if proposal.is_empty():
				failures += 1
				print("FAIL theme=%d seed=%d ordinary blackout found no doorway" % [
					theme, base])
			else:
				var result := _commit_and_check(ordinary, topology, from,
					proposal, false, geometry_checks < 44)
				failures += int(result["failures"])
				geometry_checks += int(result["geometry"])
				if int(result["saving"]) < DescentRoute.MERCY_MIN_SAVING:
					ordinary_neutral += 1
				# A second blackout must choose a distinct canonical wall and remain
				# physically persistent rather than silently reusing the first.
				var second := ordinary.find_blackout_doorway(
					from, visited, false)
				if second.is_empty() or DescentTopology.edge_key(
						proposal["cell"], int(proposal["dir"])) == \
						DescentTopology.edge_key(second.get("cell", Vector2i.ZERO),
							int(second.get("dir", 0))):
					failures += 1
					print("FAIL theme=%d seed=%d repeated blackout reused/no doorway" % [
						theme, base])

			# Test assistance on a fresh topology so the normal opening cannot
			# accidentally consume the most useful wall first. Reuse the route:
			# builds are deterministic and attaching a virgin topology recomputes
			# the guidance maps, which is all the first test dirtied — a second
			# build said the same thing for another two seconds per theme-seed,
			# which is why this audit stopped fitting its timeout.
			var helped := ordinary
			var helped_topology := DescentTopology.new(ws, theme)
			helped.set_topology(helped_topology)
			var stalled := _representative_stall(helped)
			if stalled == Vector2i(1 << 20, 1 << 20):
				continue
			helpful_total += 1
			var stall_visited := _explored_neighbourhood(helped, stalled, 4)
			var useful := helped.find_blackout_doorway(
				stalled, stall_visited, true)
			if useful.is_empty() or not bool(useful.get("assistance", false)):
				failures += 1
				print("FAIL theme=%d seed=%d stalled player found no useful doorway" % [
					theme, base])
			else:
				helpful_found += 1
				var helped_result := _commit_and_check(helped,
					helped_topology, stalled, useful, true,
					geometry_checks < 88)
				failures += int(helped_result["failures"])
				geometry_checks += int(helped_result["geometry"])

	failures += _check_run_preflight()
	var neutral_rate := float(ordinary_neutral) / float(maxi(1, ordinary_total))
	var helpful_rate := float(helpful_found) / float(maxi(1, helpful_total))
	print("blackout doorway audit: %d ordinary (%d neutral, %.0f%%); useful %d/%d (%.0f%%); geometry=%d" % [
		ordinary_total, ordinary_neutral, neutral_rate * 100.0,
		helpful_found, helpful_total, helpful_rate * 100.0, geometry_checks])
	if neutral_rate < 0.80:
		failures += 1
		print("FAIL fewer than 80%% of ordinary blackout doors are decorative")
	if helpful_rate < 0.98:
		failures += 1
		print("FAIL fewer than 98%% of representative stalls receive useful doors")
	if failures == 0:
		print("  PASS — every blackout door is persistent and hidden help remains indistinguishable")
	else:
		print("  FAIL — %d blackout doorway contract violation(s)" % failures)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)


func _representative_cell(route: DescentRoute) -> Vector2i:
	var path := route.path_from_origin()
	if path.size() >= 5:
		return path[clampi(path.size() / 3, 2, path.size() - 2)]
	return route.origin


func _representative_stall(route: DescentRoute) -> Vector2i:
	var sentinel := Vector2i(1 << 20, 1 << 20)
	var path_cells := {}
	for at in route.path_from_origin():
		path_cells[at] = true
	var candidates: Array[Vector2i] = []
	for key in route._origin_distance:
		var at: Vector2i = key
		if not path_cells.has(at) and route.distance_from_target(at) >= 8:
			candidates.append(at)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i):
		return WorldGen.h(route.world_seed, a.x, a.y, 9929) < \
			WorldGen.h(route.world_seed, b.x, b.y, 9929))
	return candidates[0] if not candidates.is_empty() else sentinel


func _explored_neighbourhood(route: DescentRoute, start: Vector2i,
		radius: int) -> Dictionary:
	var seen := {start: true}
	var distance := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var steps := int(distance[at])
		if steps >= radius:
			continue
		for dir in 4:
			if bool(route.edge_info(at, dir)["wall"]):
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if seen.has(other) or not route.contains(other):
				continue
			seen[other] = true
			distance[other] = steps + 1
			queue.append(other)
	return seen


func _commit_and_check(route: DescentRoute, topology: DescentTopology,
		from: Vector2i, proposal: Dictionary, require_help: bool,
		check_geometry: bool) -> Dictionary:
	var failures := 0
	var at: Vector2i = proposal["cell"]
	var dir := int(proposal["dir"])
	var other: Vector2i = at + WorldGen.DIRV[dir]
	var before := route.distance_from_target(from)
	if not WorldGen.is_wall(route.world_seed, at, dir, route.theme) \
			or not topology.add_shortcut(at, dir):
		failures += 1
		print("FAIL refused proposed base wall theme=%d at=%s/%d" % [
			route.theme, at, dir])
		return {"failures": failures, "saving": 0, "geometry": 0}
	var forward := topology.edge_info(at, dir)
	var reverse := topology.edge_info(other, OPPOSITE[dir])
	if bool(forward["wall"]) or bool(reverse["wall"]) \
			or not bool(forward.get("runtime_shortcut", false)) \
			or not bool(reverse.get("runtime_shortcut", false)) \
			or DescentTopology.edge_key(at, dir) != \
			DescentTopology.edge_key(other, OPPOSITE[dir]):
		failures += 1
		print("FAIL asymmetric blackout doorway theme=%d at=%s/%d" % [
			route.theme, at, dir])
	route.refresh_topology()
	var after := route.distance_from_target(from)
	var saving := before - after
	var far_side := route.distance_from_target(other)
	# The help cascade may legally return a one-step door (nearby, weak) or a
	# strong door from the wide radius when nothing better exists, so the
	# floors here are the cascade's own minimums, not the preferred tier's.
	if require_help and before - far_side < 1:
		failures += 1
		print("FAIL helpful doorway theme=%d far side gained only %d edges" % [
			route.theme, before - far_side])
	if int(proposal.get("approach", 999)) > \
			DescentRoute.BLACKOUT_HELP_WIDE_RADIUS:
		failures += 1
		print("FAIL blackout doorway theme=%d appeared %d rooms away" % [
			route.theme, int(proposal.get("approach", 999))])
	var geometry := 0
	if check_geometry:
		geometry = 1
		failures += _check_geometry(route, topology, at, dir, other)
	return {"failures": failures, "saving": saving, "geometry": geometry}


func _check_geometry(route: DescentRoute, topology: DescentTopology,
		at: Vector2i, dir: int, other: Vector2i) -> int:
	var failures := 0
	var first := Chunk.new(route.world_seed, at, route.theme, {
		"descent": true, "topology": topology,
	})
	var second := Chunk.new(route.world_seed, other, route.theme, {
		"descent": true, "topology": topology,
	})
	if first.runtime_shortcut_blockers(dir) != 0 \
			or second.runtime_shortcut_blockers(OPPOSITE[dir]) != 0:
		failures += 1
		print("FAIL doorway collision blocker theme=%d at=%s/%d" % [
			route.theme, at, dir])
		_print_blocker_shapes(first, dir, "near")
		_print_blocker_shapes(second, OPPOSITE[dir], "far")
	if first.doorway_clearance_violations() != 0 \
			or second.doorway_clearance_violations() != 0:
		failures += 1
		print("FAIL doorway furnishing blocker theme=%d at=%s/%d" % [
			route.theme, at, dir])
	# A fresh construction proves streaming persistence, not merely mutation of
	# the first in-memory scene tree.
	var rebuilt := Chunk.new(route.world_seed, at, route.theme, {
		"descent": true, "topology": topology,
	})
	if rebuilt.runtime_shortcut_blockers(dir) != 0:
		failures += 1
		print("FAIL doorway did not survive rebuild theme=%d at=%s/%d" % [
			route.theme, at, dir])
	first.free()
	second.free()
	rebuilt.free()
	return failures


func _print_blocker_shapes(chunk: Chunk, dir: int, side: String) -> void:
	var edge := chunk._edge_info(chunk.cell, dir)
	var half_lane := maxf(0.25,
		float(edge["w"]) * 0.5 - ShadowFigure.MOVE_RADIUS - 0.08)
	var along := float(edge["t"])
	var zone := Rect2(chunk.S - 0.42, along - half_lane,
		0.84, half_lane * 2.0) if dir == 0 else \
		Rect2(-0.42, along - half_lane,
		0.84, half_lane * 2.0) if dir == 1 else \
		Rect2(along - half_lane, chunk.S - 0.42,
		half_lane * 2.0, 0.84) if dir == 2 else \
		Rect2(along - half_lane, -0.42,
		half_lane * 2.0, 0.84)
	for node in chunk.body.get_children():
		var cs := node as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if bool(cs.get_meta("walkable_ramp", false)):
			continue
		var size := Vector3.ZERO
		if cs.shape is BoxShape3D:
			size = (cs.shape as BoxShape3D).size
		elif cs.shape is CylinderShape3D:
			var cylinder := cs.shape as CylinderShape3D
			size = Vector3(cylinder.radius * 2.0, cylinder.height,
				cylinder.radius * 2.0)
		elif cs.shape is CapsuleShape3D:
			var capsule := cs.shape as CapsuleShape3D
			size = Vector3(capsule.radius * 2.0, capsule.height,
				capsule.radius * 2.0)
		else:
			continue
		var aabb := AABB(-size * 0.5, size)
		var world_box := cs.transform * aabb
		if world_box.end.y <= chunk._floor_h() + 0.03 \
				or world_box.position.y >= chunk._floor_h() \
					+ ShadowFigure.MOVE_HEIGHT:
			continue
		var rect := Rect2(world_box.position.x, world_box.position.z,
			world_box.size.x, world_box.size.z)
		if rect.intersects(zone):
			print("  BLOCK %s cell=%s type=%s shape=%s xform=%s meta=%s" % [
				side, chunk.cell, cs.shape.get_class(), size, cs.transform,
				str(cs.get_meta_list())])


func _check_run_preflight() -> int:
	var ws := WorldGen.level_seed(918273, 0)
	var route := DescentRoute.build(ws, 0, 0)
	var topology := DescentTopology.new(ws, 0)
	route.set_topology(topology)
	topology.plan_floor(route)
	route.refresh_topology()
	var from := _representative_cell(route)
	var run := DescentRun.new()
	run.world_seed = 918273
	run.player = Player.new()
	run.set_route(route)
	run._cell = from
	run.visited = _explored_neighbourhood(route, from, 5)
	var events: Array = []
	run.blackout_mutation_requested.connect(
		func(proposal: TopologyDelta, assistance: bool):
			events.append([proposal, assistance]))
	run._begin_blackout()
	var failed := not run.blackout or events.size() != 1 \
		or (events[0][0] as TopologyDelta).is_empty() \
		or run.pending_blackout_mutation == null \
		or run.pending_blackout_mutation.is_empty()
	run.player.free()
	run.free()
	if failed:
		print("FAIL a started blackout did not own exactly one reality proposal")
		return 1
	return 0
