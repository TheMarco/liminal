class_name DescentRoute
extends RefCounted
## One deterministic, topology-valid objective route for a Descent floor.
##
## The route is computed once from the same salted seed used by ChunkManager.
## It never changes WorldGen: a reverse BFS from the chosen target records an
## actually open next edge for every scanned cell, so HUD guidance cannot point
## through a wall.

const MIN_DIST := 7
const IDEAL_MAX_DIST := 12
const FIRST_RADIUS := 16
const MAX_RADIUS := 28
const TARGET_SALT := 1817
const TARGET_WALL_SALT := 1770

const ELEV_STYLES := {
	0: [WorldGen.STYLE_EMPTY, WorldGen.STYLE_LOUNGE,
		WorldGen.STYLE_PILLARS, WorldGen.STYLE_GRAND],
	1: [WorldGen.OFFICE_EMPTY, WorldGen.OFFICE_STORAGE,
		WorldGen.OFFICE_BREAK, WorldGen.OFFICE_CUBICLES],
	4: [WorldGen.AIR_HALL, WorldGen.AIR_CONCOURSE,
		WorldGen.AIR_BAGGAGE],
	6: [WorldGen.SCH_GYM, WorldGen.SCH_CAFETERIA,
		WorldGen.SCH_LIBRARY, WorldGen.SCH_ADMIN],
	5: [WorldGen.ASY_OFFICE, WorldGen.ASY_WARD,
		WorldGen.ASY_DAYROOM],
	2: [WorldGen.SEWER_DRY],
	7: [WorldGen.MALL_ATRIUM, WorldGen.MALL_SERVICE,
		WorldGen.MALL_STORE, WorldGen.MALL_KIOSKS],
	8: [WorldGen.PRISON_GUARD, WorldGen.PRISON_CELLS,
		WorldGen.PRISON_VISITATION, WorldGen.PRISON_INDUSTRY],
}

var world_seed := 0
var theme := 0
var target := Vector2i.ZERO
var target_wall := -1
var graph_distance := 0
var fallback_tier := 0

var _origin_distance := {}
var _next := {}
var _target_distance := {}


static func build(ws: int, floor_theme: int) -> DescentRoute:
	var route := DescentRoute.new()
	route.world_seed = ws
	route.theme = floor_theme
	route._build()
	return route


func next_from(from: Vector2i) -> Vector2i:
	return _next.get(from, from)


func contains(at: Vector2i) -> bool:
	return _target_distance.has(at)


func distance_from_target(at: Vector2i) -> int:
	return int(_target_distance.get(at, -1))


func path_from_origin() -> Array[Vector2i]:
	var path: Array[Vector2i] = [Vector2i.ZERO]
	var at := Vector2i.ZERO
	var guard := _next.size() + 1
	while at != target and guard > 0:
		var following: Vector2i = next_from(at)
		if following == at:
			break
		path.append(following)
		at = following
		guard -= 1
	return path


func _build() -> void:
	var candidates: Array[Vector2i] = []
	for radius in [FIRST_RADIUS, MAX_RADIUS]:
		_scan_from_origin(radius)
		var preferred: Array[Vector2i] = []
		var eligible: Array[Vector2i] = []
		var fallback: Array[Vector2i] = []
		for key in _origin_distance:
			var c: Vector2i = key
			var dist := int(_origin_distance[c])
			if dist < 4 or not _base_candidate(c):
				continue
			var preferred_style := _style_allowed(c)
			if preferred_style and dist >= MIN_DIST and dist <= IDEAL_MAX_DIST:
				preferred.append(c)
			if preferred_style:
				eligible.append(c)
			# Sewer water geometry is never a safe fallback for a walk-in exit.
			if theme != 2 or WorldGen.cell_style(world_seed, c, theme) == WorldGen.SEWER_DRY:
				fallback.append(c)
		candidates = preferred
		fallback_tier = 0
		if candidates.is_empty():
			candidates = eligible
			fallback_tier = 1
		if candidates.is_empty():
			candidates = fallback
			fallback_tier = 2
		if not candidates.is_empty():
			break
	if candidates.is_empty():
		push_error("DescentRoute: no target seed=%d theme=%d" % [world_seed, theme])
		target = Vector2i.ZERO
		target_wall = WorldGen.anchor_wall(world_seed, target, TARGET_WALL_SALT)
		_build_reverse_map()
		return

	target = _ranked_pick(candidates)
	target_wall = WorldGen.anchor_wall(world_seed, target, TARGET_WALL_SALT)
	graph_distance = int(_origin_distance[target])
	_build_reverse_map()


func _scan_from_origin(radius: int) -> void:
	_origin_distance.clear()
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	_origin_distance[Vector2i.ZERO] = 0
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var dist := int(_origin_distance[c])
		if dist >= radius:
			continue
		for dir in 4:
			var nb: Vector2i = c + WorldGen.DIRV[dir]
			if maxi(absi(nb.x), absi(nb.y)) > radius or _origin_distance.has(nb):
				continue
			if WorldGen.edge_info(world_seed, c, dir, theme)["wall"]:
				continue
			_origin_distance[nb] = dist + 1
			queue.append(nb)


func _base_candidate(c: Vector2i) -> bool:
	if c == Vector2i.ZERO or WorldGen.corridor(world_seed, c) != 0:
		return false
	if WorldGen.room_id(world_seed, c) != c:
		return false
	if WorldGen.room_size(world_seed, c) != 1:
		return false
	if not WorldGen.room_split(world_seed, c, theme).is_empty():
		return false
	if WorldGen.anchor_wall(world_seed, c, TARGET_WALL_SALT) < 0:
		return false
	# Avoid changing the meaning of a cell Wander already selected as one of its
	# own landmarks. Descent suppresses those systems, but a distinct target is
	# easier to audit and keeps the two modes' generation contracts separate.
	if WorldGen.portal(world_seed, c, theme) >= 0:
		return false
	if WorldGen.elevator_cell(world_seed, c, theme):
		return false
	return true


func _style_allowed(c: Vector2i) -> bool:
	var styles: Array = ELEV_STYLES.get(theme, [])
	return styles.has(WorldGen.cell_style(world_seed, c, theme))


func _ranked_pick(candidates: Array[Vector2i]) -> Vector2i:
	var best := candidates[0]
	var best_hash := WorldGen.h(world_seed, best.x, best.y,
		TARGET_SALT + theme * 31)
	for i in range(1, candidates.size()):
		var c := candidates[i]
		var score := WorldGen.h(world_seed, c.x, c.y,
			TARGET_SALT + theme * 31)
		if score < best_hash or (score == best_hash and (
				c.x < best.x or (c.x == best.x and c.y < best.y))):
			best = c
			best_hash = score
	return best


func _build_reverse_map() -> void:
	_next.clear()
	_target_distance.clear()
	var queue: Array[Vector2i] = [target]
	_target_distance[target] = 0
	_next[target] = target
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var dist := int(_target_distance[c])
		for dir in 4:
			var nb: Vector2i = c + WorldGen.DIRV[dir]
			if not _origin_distance.has(nb) or _target_distance.has(nb):
				continue
			if WorldGen.edge_info(world_seed, c, dir, theme)["wall"]:
				continue
			_target_distance[nb] = dist + 1
			_next[nb] = c
			queue.append(nb)
