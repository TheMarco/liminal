extends SceneTree
## Reports how much of Pool Rooms reads as one uninterrupted space.  Structural
## rooms intentionally keep their shared interior, so this audit focuses on
## boundaries between separate rooms: walls, cased openings, and fully missing
## walls.  It also measures the connected regions made only from fully open
## edges, which is the useful proxy for "this room feels enormous."
##
## Run:
##   godot --headless --path . --script tools/audit_pool_scale.gd -- [seeds]

const SCAN_R := 14


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 12, 1, 32)
	var wall_edges := 0
	var cased_edges := 0
	var open_edges := 0
	var same_room_edges := 0
	var separate_room_edges := 0
	var root_room_sizes: Array[int] = []
	var open_region_sizes: Array[int] = []
	var largest_per_seed: Array[int] = []
	for si in seed_count:
		var base := WorldGen.h(9311, si * 47, si * 83, 409) | 1
		var ws := WorldGen.level_seed(base, 9)
		var cells := _scan_cells()
		var roots := {}
		for cell in cells:
			var root := WorldGen.room_id(ws, cell)
			if not roots.has(root):
				roots[root] = true
				root_room_sizes.append(WorldGen.room_size(ws, root))
			for dir in [0, 2]:
				var other: Vector2i = cell + WorldGen.DIRV[dir]
				if not _inside(other):
					continue
				if WorldGen.room_id(ws, cell) == WorldGen.room_id(ws, other):
					same_room_edges += 1
					continue
				separate_room_edges += 1
				var info := WorldGen.edge_info(ws, cell, dir, 9)
				if bool(info["wall"]):
					wall_edges += 1
				elif bool(info["full_open"]):
					open_edges += 1
				else:
					cased_edges += 1
		var regions := _full_open_regions(ws, cells)
		open_region_sizes.append_array(regions)
		largest_per_seed.append(regions.max() if not regions.is_empty() else 0)

	root_room_sizes.sort()
	open_region_sizes.sort()
	largest_per_seed.sort()
	var boundary_total := wall_edges + cased_edges + open_edges
	print("pool scale audit: %d seeds | %d-cell square per seed" % [
		seed_count, SCAN_R * 2 + 1])
	print(("  separate-room boundaries: %d wall (%.1f%%), " +
		"%d cased (%.1f%%), %d fully open (%.1f%%)") % [
			wall_edges, _pct(wall_edges, boundary_total),
			cased_edges, _pct(cased_edges, boundary_total),
			open_edges, _pct(open_edges, boundary_total)])
	print("  same-room interior edges: %d (left structurally untouched)" % \
		same_room_edges)
	print("  structural room cells: median %d | p90 %d | max %d" % [
		_percentile(root_room_sizes, 0.50),
		_percentile(root_room_sizes, 0.90),
		root_room_sizes.max() if not root_room_sizes.is_empty() else 0])
	print("  fully-open region cells: median %d | p90 %d | p95 %d | max %d" % [
		_percentile(open_region_sizes, 0.50),
		_percentile(open_region_sizes, 0.90),
		_percentile(open_region_sizes, 0.95),
		open_region_sizes.max() if not open_region_sizes.is_empty() else 0])
	print("  largest region per seed: median %d | p90 %d | max %d" % [
		_percentile(largest_per_seed, 0.50),
		_percentile(largest_per_seed, 0.90),
		largest_per_seed.max() if not largest_per_seed.is_empty() else 0])
	if separate_room_edges == 0 or cased_edges == 0:
		push_error("pool scale audit is inert: no separate-room cased boundaries")
		quit(1)
		return
	var open_pct := _pct(open_edges, boundary_total)
	var region_p95 := _percentile(open_region_sizes, 0.95)
	var largest_p90 := _percentile(largest_per_seed, 0.90)
	if open_pct > 18.0 or region_p95 > 5 or largest_p90 > 90:
		push_error(("Pool Rooms have regressed to oversized uninterrupted spaces " +
			"(open %.1f%%, region p95 %d, largest-seed p90 %d)") % [
				open_pct, region_p95, largest_p90])
		quit(1)
		return
	print("  PASS — Pool Rooms remain compact with occasional larger halls")
	quit()


func _scan_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-SCAN_R, SCAN_R + 1):
		for z in range(-SCAN_R, SCAN_R + 1):
			result.append(Vector2i(x, z))
	return result


func _inside(cell: Vector2i) -> bool:
	return absi(cell.x) <= SCAN_R and absi(cell.y) <= SCAN_R


func _full_open_regions(ws: int, cells: Array[Vector2i]) -> Array[int]:
	var unvisited := {}
	for cell in cells:
		unvisited[cell] = true
	var sizes: Array[int] = []
	while not unvisited.is_empty():
		var start: Vector2i = unvisited.keys()[0]
		unvisited.erase(start)
		var queue: Array[Vector2i] = [start]
		var size := 0
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			size += 1
			for dir in 4:
				var other: Vector2i = cell + WorldGen.DIRV[dir]
				if not _inside(other) or not unvisited.has(other):
					continue
				var info := WorldGen.edge_info(ws, cell, dir, 9)
				if not bool(info["full_open"]):
					continue
				unvisited.erase(other)
				queue.append(other)
		sizes.append(size)
	return sizes


func _percentile(values: Array[int], p: float) -> int:
	if values.is_empty():
		return 0
	var index := clampi(int(ceil(p * values.size())) - 1, 0, values.size() - 1)
	return values[index]


func _pct(value: int, total: int) -> float:
	return 0.0 if total == 0 else float(value) * 100.0 / float(total)
