extends SceneTree
## Proves that every Descent floor has a deterministic, wall-respecting route
## to a suitable single-cell objective room. This is topology-only and fast
## enough to run over hundreds of world seeds in CI.
## Run: godot --headless --path . --script tools/audit_descent_routes.gd -- [seeds]

const THEMES: Array[int] = DescentRun.ORDER


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
	var shortest := 999
	var longest := 0
	for si in seed_count:
		var base := WorldGen.h(715517, si * 67, si * 113, 2027) | 1
		for theme in THEMES:
			var ws := _level_seed(base, theme)
			var route := DescentRoute.build(ws, theme)
			if verbose:
				print("seed=%d theme=%d target=%s wall=%d distance=%d tier=%d" % [
					base, theme, route.target, route.target_wall,
					route.graph_distance, route.fallback_tier])
			fallback_counts[route.fallback_tier] += 1
			var path := route.path_from_origin()
			var error := _validate(ws, theme, route, path, si < 2)
			if not error.is_empty():
				failures += 1
				if failures <= 20:
					print("FAIL seed=%d theme=%d target=%s tier=%d: %s" % [
						base, theme, route.target, route.fallback_tier, error])
			else:
				shortest = mini(shortest, path.size() - 1)
				longest = maxi(longest, path.size() - 1)

	print("descent route audit: %d seeds × %d floors = %d routes" % [
		seed_count, THEMES.size(), seed_count * THEMES.size()])
	print("  route length: %d..%d edges | fallback tiers: ideal=%d styled=%d generic=%d" % [
		shortest, longest, fallback_counts[0], fallback_counts[1],
		fallback_counts[2]])
	if failures == 0:
		print("  PASS — every route is deterministic, reachable, and crosses only open edges")
	else:
		print("  FAIL — %d invalid routes" % failures)
	quit(0 if failures == 0 else 1)


func _validate(ws: int, theme: int, route: DescentRoute,
		path: Array[Vector2i], check_repeat: bool) -> String:
	if check_repeat:
		var again := DescentRoute.build(ws, theme)
		if again.target != route.target or again.target_wall != route.target_wall:
			return "route is not deterministic"
	if path.is_empty() or path[0] != Vector2i.ZERO:
		return "path does not start at origin"
	if path[-1] != route.target:
		return "path does not reach target"
	if route.graph_distance != path.size() - 1:
		return "stored graph distance disagrees with path"
	if route.target == Vector2i.ZERO or route.target_wall < 0:
		return "invalid objective room"
	if WorldGen.room_id(ws, route.target) != route.target \
			or WorldGen.room_size(ws, route.target) != 1:
		return "target is not a single-cell room"
	if not WorldGen.room_split(ws, route.target, theme).is_empty():
		return "target room is split"
	for i in range(path.size() - 1):
		var delta := path[i + 1] - path[i]
		var dir := WorldGen.DIRV.find(delta)
		if dir < 0:
			return "non-cardinal path step at index %d" % i
		if WorldGen.edge_info(ws, path[i], dir, theme)["wall"]:
			return "path crosses wall at %s dir=%d" % [path[i], dir]
		if route.next_from(path[i]) != path[i + 1]:
			return "next-hop map disagrees at %s" % path[i]
	return ""
