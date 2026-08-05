extends SceneTree
## Proves that every Descent floor has a deterministic, wall-respecting route
## from a wall-backed arrival room to a suitable single-cell objective room.
## This is topology-only and fast enough to run over hundreds of world seeds
## in CI.
## Run: godot --headless --path . --script tools/audit_descent_routes.gd -- [seeds]

## Metres per cell edge, and the Descent walking speed (sprint is disabled), so
## the audit can report the number the pacing is actually tuned against.
const EDGE_M := 12.0
const WALK_SPEED := 3.4


func _init() -> void:
	call_deferred("_run")


func _level_seed(base: int, theme: int) -> int:
	return WorldGen.level_seed(base, theme)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if not args.is_empty() else 200
	seed_count = clampi(seed_count, 1, 2000)
	var verbose := args.has("--verbose")
	var failures := 0
	var fallback_counts := [0, 0, 0]
	var no_arrival := 0
	var shortest := 999
	var longest := 0
	var per_floor_edges := []
	for _i in DescentRun.FLOOR_COUNT:
		per_floor_edges.append(0)
	var run_edge_total := 0
	for si in seed_count:
		var base := WorldGen.h(715517, si * 67, si * 113, 2027) | 1
		# The macro-order is authored; seeds still vary every floor's route and
		# geometry, which is what this audit enumerates.
		var order := DescentRun.order_for(base)
		for floor_idx in order.size():
			var theme: int = order[floor_idx]
			var ws := _level_seed(base, theme)
			var route := DescentRoute.build(ws, theme, floor_idx)
			if verbose:
				print("seed=%d floor=%d theme=%d origin=%s/%d target=%s/%d distance=%d band=%d-%d tier=%d" % [
					base, floor_idx + 1, theme, route.origin, route.origin_wall,
					route.target, route.target_wall, route.graph_distance,
					route.min_dist, route.max_dist, route.fallback_tier])
			fallback_counts[route.fallback_tier] += 1
			if route.origin_wall < 0:
				no_arrival += 1
			var path := route.path_from_origin()
			var error := _validate(ws, theme, route, path, si < 2, floor_idx)
			if not error.is_empty():
				failures += 1
				if failures <= 20:
					print("FAIL seed=%d floor=%d theme=%d target=%s tier=%d: %s" % [
						base, floor_idx + 1, theme, route.target,
						route.fallback_tier, error])
			else:
				var edges := path.size() - 1
				shortest = mini(shortest, edges)
				longest = maxi(longest, edges)
				per_floor_edges[floor_idx] += edges
				run_edge_total += edges

	print("descent route audit: %d seeds × %d floors = %d routes" % [
		seed_count, DescentRun.FLOOR_COUNT, seed_count * DescentRun.FLOOR_COUNT])
	print("  route length: %d..%d edges | fallback tiers: ideal=%d styled=%d generic=%d" % [
		shortest, longest, fallback_counts[0], fallback_counts[1],
		fallback_counts[2]])
	print("  arrival rooms: %d of %d floors had no wall-backed car (plain arrival)" % [
		no_arrival, seed_count * DescentRun.FLOOR_COUNT])
	# Walking is the whole of a Descent floor's traversal budget, so state it.
	# Calling and riding the lift are on top of these walking numbers; the HUD
	# now names the exact route exit from every room on every floor.
	for floor_idx in DescentRun.FLOOR_COUNT:
		var mean := float(per_floor_edges[floor_idx]) / float(maxi(1, seed_count))
		print("    floor %d mean %5.1f edges  %6.0fm  ~%4.0fs walking" % [
			floor_idx + 1, mean, mean * EDGE_M,
			mean * EDGE_M / WALK_SPEED])
	var run_mean := float(run_edge_total) / float(maxi(1, seed_count))
	var lift_total := 0.0
	for floor_idx in DescentRun.FLOOR_COUNT - 1:
		lift_total += DescentRun.lift_wait_for(floor_idx)
	print("  full run: ~%.0f edges, %.0fm, ~%.1f min walking + ~%.1f min lift waits = ~%.1f min floor" % [
		run_mean, run_mean * EDGE_M, run_mean * EDGE_M / WALK_SPEED / 60.0,
		lift_total / 60.0,
		(run_mean * EDGE_M / WALK_SPEED + lift_total) / 60.0])
	if failures == 0:
		print("  PASS — every route is deterministic, reachable, and crosses only open edges")
	else:
		print("  FAIL — %d invalid routes" % failures)
	quit(0 if failures == 0 else 1)


func _validate(ws: int, theme: int, route: DescentRoute,
		path: Array[Vector2i], check_repeat: bool, floor_idx: int) -> String:
	if check_repeat:
		var again := DescentRoute.build(ws, theme, floor_idx)
		if again.target != route.target or again.target_wall != route.target_wall \
				or again.origin != route.origin \
				or again.origin_wall != route.origin_wall:
			return "route is not deterministic"
	if path.is_empty() or path[0] != route.origin:
		return "path does not start at the arrival room"
	if path[-1] != route.target:
		return "path does not reach target"
	if route.graph_distance != path.size() - 1:
		return "stored graph distance disagrees with path"
	if route.target == route.origin:
		return "objective is the arrival room"
	if route.target == Vector2i.ZERO or route.target_wall < 0:
		return "invalid objective room"
	var target_root := WorldGen.annex_room_id(ws, route.target) \
			if theme == 2 else WorldGen.room_id(ws, route.target)
	var target_size := WorldGen.annex_room_size(ws, route.target) \
			if theme == 2 else WorldGen.room_size(ws, route.target)
	if target_root != route.target or target_size != 1:
		return "target is not a single-cell room"
	if not WorldGen.room_split(ws, route.target, theme).is_empty():
		return "target room is split"
	# The arrival car is a sealed island against a real wall, and the player is
	# teleported inside it, so its room has to satisfy the same contract.
	if route.origin_wall >= 0:
		var origin_root := WorldGen.annex_room_id(ws, route.origin) \
				if theme == 2 else WorldGen.room_id(ws, route.origin)
		var origin_size := WorldGen.annex_room_size(ws, route.origin) \
				if theme == 2 else WorldGen.room_size(ws, route.origin)
		if origin_root != route.origin or origin_size != 1:
			return "arrival is not a single-cell room"
		if not WorldGen.room_split(ws, route.origin, theme).is_empty():
			return "arrival room is split"
		var origin_is_corridor := WorldGen.annex_corridor_axis(ws, route.origin) != 0 \
				if theme == 2 else WorldGen.corridor(ws, route.origin) != 0
		if origin_is_corridor:
			return "arrival room is a corridor"
		if not WorldGen.is_wall(ws, route.origin, route.origin_wall, theme):
			return "arrival car is not backed by a solid wall"
		var reach := _reachable_from_world_origin(ws, theme, route.origin)
		if reach < 0:
			return "arrival room is unreachable from the world origin"
		if reach > DescentRoute.ARRIVAL_RADIUS:
			return "arrival room is %d cells from the world origin" % reach
	# A depth-scaled band is the whole point of the length ramp; only a
	# documented fallback tier is allowed outside it.
	if route.fallback_tier == 0:
		if route.graph_distance < route.min_dist \
				or route.graph_distance > route.max_dist:
			return "ideal-tier distance %d outside band %d-%d" % [
				route.graph_distance, route.min_dist, route.max_dist]
	for i in range(path.size() - 1):
		var delta := path[i + 1] - path[i]
		var dir := WorldGen.DIRV.find(delta)
		if dir < 0:
			return "non-cardinal path step at index %d" % i
		if WorldGen.edge_info(ws, path[i], dir, theme)["wall"]:
			return "path crosses wall at %s dir=%d" % [path[i], dir]
		if route.next_from(path[i]) != path[i + 1]:
			return "next-hop map disagrees at %s" % path[i]
		var room_exit := route.next_room_exit(path[i])
		if room_exit.is_empty():
			return "room-aware guide has no exit from %s" % path[i]
		var exit_cell: Vector2i = room_exit["cell"]
		var exit_next: Vector2i = room_exit["next"]
		var exit_dir := int(room_exit["dir"])
		var start_root := WorldGen.annex_room_id(ws, path[i]) if theme == 2 \
			else WorldGen.room_id(ws, path[i])
		var source_root := WorldGen.annex_room_id(ws, exit_cell) if theme == 2 \
			else WorldGen.room_id(ws, exit_cell)
		var next_root := WorldGen.annex_room_id(ws, exit_next) if theme == 2 \
			else WorldGen.room_id(ws, exit_next)
		if source_root != start_root or next_root == start_root:
			return "guide points at internal room seam from %s" % path[i]
		if WorldGen.edge_info(ws, exit_cell, exit_dir, theme)["wall"]:
			return "guide points at wall from %s" % path[i]
	return ""


func _reachable_from_world_origin(ws: int, theme: int, goal: Vector2i) -> int:
	var dist := {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := int(dist[c])
		if c == goal:
			return d
		if d >= DescentRoute.ARRIVAL_RADIUS:
			continue
		for dir in 4:
			var nb: Vector2i = c + WorldGen.DIRV[dir]
			if dist.has(nb) or WorldGen.edge_info(ws, c, dir, theme)["wall"]:
				continue
			dist[nb] = d + 1
			queue.append(nb)
	return -1
