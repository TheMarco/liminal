class_name NativeDoorwayPlan
extends RefCounted
## Seed-stable optional wall sites. Rendering reserves an opening in both
## chunks, but navigation retains the original solid edge until it is visible.

const MAX_DETOUR := 160

var world_seed := 1
var theme := 1
var topology: DescentTopology
var _candidates := {}
var _opened := {}


func configure(seed: int, level: int, resolved_topology: DescentTopology) -> void:
	world_seed = seed
	theme = level
	topology = resolved_topology
	_candidates.clear()
	_opened.clear()


static func canonical(cell: Vector2i, dir: int) -> Dictionary:
	return {"cell": cell + WorldGen.DIRV[dir], "dir": WorldGen.OPP[dir]} \
		if dir == 1 or dir == 3 else {"cell": cell, "dir": dir}


static func edge_key(cell: Vector2i, dir: int) -> String:
	var edge := canonical(cell, dir)
	var root: Vector2i = edge["cell"]
	return "%d:%d:%d" % [root.x, root.y, int(edge["dir"])]


func candidate(cell: Vector2i, dir: int) -> Dictionary:
	var edge := canonical(cell, dir)
	var root: Vector2i = edge["cell"]
	var axis: int = edge["dir"]
	var key := edge_key(root, axis)
	if _candidates.has(key): return _candidates[key]
	var result := _candidate_uncached(root, axis)
	_candidates[key] = result
	return result


func _candidate_uncached(cell: Vector2i, dir: int) -> Dictionary:
	if theme == 3 or dir not in [0, 2]: return {}
	var other: Vector2i = cell + WorldGen.DIRV[dir]
	# Only a formerly solid edge can read as a doorway appearing from nowhere.
	var base := WorldGen.edge_info(world_seed, cell, dir, theme)
	if not bool(base["wall"]) or bool(base["full_open"]): return {}
	if WorldGen.elevator_cell(world_seed, cell, theme) \
			or WorldGen.elevator_cell(world_seed, other, theme): return {}
	# Safe portal-capable walls are already scarce. Prepare all of them; the
	# director, not a second random roll, controls how often one actually moves.
	if WorldGen.room_id(world_seed, cell) == WorldGen.room_id(world_seed, other) \
			and theme != 2: return {}
	if theme == 2 and (WorldGen.annex_corridor_axis(world_seed, cell) != 0 \
			or WorldGen.annex_corridor_axis(world_seed, other) != 0 \
			or WorldGen.annex_room_id(world_seed, cell) \
				== WorldGen.annex_room_id(world_seed, other)): return {}
	if not is_equal_approx(Chunk.cell_floor_h(world_seed, cell, theme),
			Chunk.cell_floor_h(world_seed, other, theme)): return {}
	if absf(Chunk.cell_ceil_h(world_seed, cell, theme)
			- Chunk.cell_ceil_h(world_seed, other, theme)) > 0.03: return {}
	if theme == 9:
		if not Chunk.pool_style_dry(WorldGen.cell_style(world_seed, cell, theme)) \
				or not Chunk.pool_style_dry(WorldGen.cell_style(world_seed, other, theme)) \
				or WorldGen.pool_wall_aperture(world_seed, cell, dir): return {}
	if theme == 4 and (WorldGen.corridor(world_seed, cell) != 0 \
			or WorldGen.corridor(world_seed, other) != 0): return {}
	if theme == 0 and (Chunk.cell_ceil_h(world_seed, cell, theme) > Chunk.H \
			or Chunk.cell_ceil_h(world_seed, other, theme) > Chunk.H): return {}
	if topology != null:
		if not topology.photo_geometry_edge(cell, dir).is_empty(): return {}
		for state_id in topology.state_count():
			var resolved := topology.edge_info_for_state(cell, dir, state_id,
				false)
			if not bool(resolved.get("wall", false)) \
					or bool(resolved.get("runtime_seal", false)) \
					or resolved.has("photo_door_id"): return {}
	var width := 4.2 if theme == 2 else float(base["w"])
	if width < 1.7 or width > 8.5: return {}
	# Closing the new shortcut must not strand the player in an unreachable
	# component. A small existing detour is also what makes the beat surprising.
	var base_path := _alternate_path(cell, other, 0 if topology != null else -1)
	if base_path.is_empty(): return {}
	if topology != null:
		for state_id in range(1, topology.state_count()):
			# Most realities only change one or two edges. The base route already
			# proves this state safe unless one of those changes blocks that route.
			if _path_open_in_state(base_path, state_id): continue
			if _alternate_path(cell, other, state_id).is_empty(): return {}
	return {"wall": false, "full_open": false,
		"t": 6.0 if theme == 2 else float(base["t"]),
		"w": width, "exit_sign": false,
		"runtime_shortcut": true, "native_latent": true}


func _path_open_in_state(path: Array[Vector2i], state_id: int) -> bool:
	for step in range(path.size() - 1):
		var at := path[step]
		var dir := WorldGen.DIRV.find(path[step + 1] - at)
		if dir < 0 or topology.is_wall_for_state(at, dir, state_id): return false
	return true


func _alternate_path(start: Vector2i, goal: Vector2i,
		state_id: int) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var parents := {}
	var index := 0
	while index < queue.size() and index < MAX_DETOUR:
		var at := queue[index]
		index += 1
		for dir in 4:
			var blocked := topology.is_wall_for_state(at, dir, state_id) \
				if state_id >= 0 else \
				WorldGen.is_wall(world_seed, at, dir, theme)
			if blocked: continue
			var next: Vector2i = at + WorldGen.DIRV[dir]
			if next == goal:
				parents[next] = at
				var path: Array[Vector2i] = [goal]
				var cursor := goal
				while cursor != start:
					cursor = parents[cursor]
					path.append(cursor)
				path.reverse()
				return path
			if visited.has(next) or absi(next.x - start.x) > 8 \
					or absi(next.y - start.y) > 8: continue
			visited[next] = true
			parents[next] = at
			queue.append(next)
	return []


func is_open(cell: Vector2i, dir: int) -> bool:
	return _opened.has(edge_key(cell, dir))


func set_open(cell: Vector2i, dir: int, value: bool) -> void:
	var key := edge_key(cell, dir)
	if value: _opened[key] = true
	else: _opened.erase(key)
	if topology != null:
		var site := candidate(cell, dir)
		if not site.is_empty():
			topology.set_native_doorway_open(cell, dir, value,
				float(site["t"]), float(site["w"]))
