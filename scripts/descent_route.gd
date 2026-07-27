class_name DescentRoute
extends RefCounted
## One deterministic, topology-valid objective route for a Descent floor.
##
## The route is computed once from the same salted seed used by ChunkManager.
## It never changes WorldGen: a reverse BFS from the chosen target records an
## actually open next edge for every scanned cell, so HUD guidance cannot point
## through a wall.
##
## A floor has two authored cells. `origin` is the arrival room — the one the
## player steps out into, backed by a real solid wall so the arrival car is a
## sealed island like the objective. `target` holds the lift down (or, on the
## last floor, the way out). Distances are measured from `origin`, not from
## Vector2i.ZERO, because that is where the player actually starts walking.

## Graph distance from the arrival room to the objective, floor 1 → floor 8.
## The needle degrades with depth (see DescentHUD), so later floors are longer
## in searching as well as in metres.
const MIN_DIST_FIRST := 9
const MIN_DIST_LAST := 16
const MAX_DIST_FIRST := 13
const MAX_DIST_LAST := 22
## How far from the world origin the arrival room is allowed to sit. Cell (0,0)
## is almost never wall-backed — every edge is a guaranteed doorway — so the
## arrival car needs a nearby room that owns a solid wall.
const ARRIVAL_RADIUS := 4
const TARGET_SALT := 1817
const TARGET_WALL_SALT := 1770
const ARRIVAL_SALT := 1904
const ARRIVAL_WALL_SALT := 1911
## A cell no scan can reach, used where `_base_candidate` must exclude nothing.
const NO_CELL := Vector2i(1 << 30, 1 << 30)

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
	2: [WorldGen.ANNEX_QUIET, WorldGen.ANNEX_OPEN, WorldGen.ANNEX_LONG],
	7: [WorldGen.MALL_ATRIUM, WorldGen.MALL_SERVICE,
		WorldGen.MALL_STORE, WorldGen.MALL_KIOSKS],
	8: [WorldGen.PRISON_GUARD, WorldGen.PRISON_CELLS,
		WorldGen.PRISON_VISITATION, WorldGen.PRISON_INDUSTRY],
}

var world_seed := 0
var theme := 0
var floor_idx := 0
var origin := Vector2i.ZERO
var origin_wall := -1
var target := Vector2i.ZERO
var target_wall := -1
var graph_distance := 0
var fallback_tier := 0
var min_dist := MIN_DIST_FIRST
var max_dist := MAX_DIST_FIRST

var _origin_distance := {}
var _next := {}
var _target_distance := {}


static func build(ws: int, floor_theme: int, p_floor_idx := 0) -> DescentRoute:
	var route := DescentRoute.new()
	route.world_seed = ws
	route.theme = floor_theme
	route.floor_idx = p_floor_idx
	route._build()
	return route


## 0.0 on the casino, 1.0 in the Annex. Every depth ramp on the route reads
## from this rather than from the raw index.
static func depth_of(p_floor_idx: int) -> float:
	return clampf(float(p_floor_idx) / float(maxi(1, DescentRun.ORDER.size() - 1)),
		0.0, 1.0)


func next_from(from: Vector2i) -> Vector2i:
	return _next.get(from, from)


func contains(at: Vector2i) -> bool:
	return _target_distance.has(at)


func distance_from_target(at: Vector2i) -> int:
	return int(_target_distance.get(at, -1))


func path_from_origin() -> Array[Vector2i]:
	var path: Array[Vector2i] = [origin]
	var at := origin
	var guard := _next.size() + 1
	while at != target and guard > 0:
		var following: Vector2i = next_from(at)
		if following == at:
			break
		path.append(following)
		at = following
		guard -= 1
	return path


## Straight-line metres along the path. The needle stops naming doorways after
## the first two floors, so this is a floor of the real walk, not the whole of
## it — but it is the number worth tuning against.
func walk_metres() -> float:
	return float(maxi(0, path_from_origin().size() - 1)) * 12.0


func _build() -> void:
	var depth := depth_of(floor_idx)
	min_dist = roundi(lerpf(float(MIN_DIST_FIRST), float(MIN_DIST_LAST), depth))
	max_dist = roundi(lerpf(float(MAX_DIST_FIRST), float(MAX_DIST_LAST), depth))
	_pick_origin()

	# A shortest path of length d never leaves the Chebyshev box of radius d, so
	# scanning to exactly `max_dist` already contains every cell that could be
	# in the band. The scan is the dominant cost of a floor build; slack here is
	# paid for radius-squared.
	var first_radius := max_dist
	var last_radius := max_dist + 14
	var candidates: Array[Vector2i] = []
	for radius in [first_radius, last_radius]:
		_scan(origin, radius)
		# Tiers are evaluated in order and the search stops at the first that
		# yields anything. `_base_candidate` costs seven WorldGen queries, so it
		# is only ever reached by cells that already passed the cheap distance
		# and style filters — the scan is radius-squared and the band is a thin
		# annulus inside it.
		candidates = _collect(min_dist, max_dist, true)
		fallback_tier = 0
		if candidates.is_empty():
			candidates = _collect(4, radius, true)
			fallback_tier = 1
		if candidates.is_empty():
			candidates = _collect(4, radius, false)
			fallback_tier = 2
		if not candidates.is_empty():
			break
	if candidates.is_empty():
		push_error("DescentRoute: no target seed=%d theme=%d" % [world_seed, theme])
		target = origin
		target_wall = WorldGen.anchor_wall(world_seed, target, TARGET_WALL_SALT, theme)
		_build_reverse_map()
		return

	target = _ranked_pick(candidates, TARGET_SALT)
	target_wall = WorldGen.anchor_wall(world_seed, target, TARGET_WALL_SALT, theme)
	graph_distance = int(_origin_distance[target])
	_build_reverse_map()


func _collect(low: int, high: int, styled: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in _origin_distance:
		var c: Vector2i = key
		var dist := int(_origin_distance[c])
		if dist < low or dist > high:
			continue
		if styled and not _style_allowed(c):
			continue
		if not _base_candidate(c, origin):
			continue
		out.append(c)
	return out


## The arrival room. Nearest wall-backed candidate to the world origin, so the
## floor still begins where every existing arrival audit expects it to, and so
## the ride out of the car opens onto a real room rather than a corridor.
func _pick_origin() -> void:
	origin = Vector2i.ZERO
	origin_wall = -1
	_scan(Vector2i.ZERO, ARRIVAL_RADIUS)
	var preferred: Array[Vector2i] = []
	var eligible: Array[Vector2i] = []
	for key in _origin_distance:
		var c: Vector2i = key
		if not _base_candidate(c, NO_CELL):
			continue
		if WorldGen.anchor_wall(world_seed, c, ARRIVAL_WALL_SALT, theme) < 0:
			continue
		if _style_allowed(c):
			preferred.append(c)
		eligible.append(c)
	var pool := preferred if not preferred.is_empty() else eligible
	if pool.is_empty():
		# Nothing wall-backed nearby. The floor still works: main falls back to
		# the ordinary audited arrival and simply builds no car.
		return
	# Nearest first, so the arrival never drifts far from the audited spawn, and
	# a seed hash only breaks ties between equally close rooms.
	var closest := 1 << 30
	for c in pool:
		closest = mini(closest, int(_origin_distance[c]))
	var tied: Array[Vector2i] = []
	for c in pool:
		if int(_origin_distance[c]) == closest:
			tied.append(c)
	origin = _ranked_pick(tied, ARRIVAL_SALT)
	origin_wall = WorldGen.anchor_wall(world_seed, origin, ARRIVAL_WALL_SALT, theme)


func _scan(from: Vector2i, radius: int) -> void:
	_origin_distance.clear()
	var queue: Array[Vector2i] = [from]
	_origin_distance[from] = 0
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var dist := int(_origin_distance[c])
		if dist >= radius:
			continue
		for dir in 4:
			var nb: Vector2i = c + WorldGen.DIRV[dir]
			if maxi(absi(nb.x - from.x), absi(nb.y - from.y)) > radius \
					or _origin_distance.has(nb):
				continue
			# `edge_info(...)["wall"]` is `is_wall` on every return path, but
			# builds a dictionary and a pile of theme-specific geometry to say
			# so. These two BFS loops are the hot path of a floor build.
			if WorldGen.is_wall(world_seed, c, dir, theme):
				continue
			_origin_distance[nb] = dist + 1
			queue.append(nb)


func _base_candidate(c: Vector2i, exclude: Vector2i) -> bool:
	var in_corridor := WorldGen.annex_corridor_axis(world_seed, c) != 0 \
		if theme == 2 else WorldGen.corridor(world_seed, c) != 0
	if c == exclude or in_corridor:
		return false
	var local_root := WorldGen.annex_room_id(world_seed, c) if theme == 2 \
		else WorldGen.room_id(world_seed, c)
	var local_size := WorldGen.annex_room_size(world_seed, local_root) if theme == 2 \
		else WorldGen.room_size(world_seed, local_root)
	if local_root != c:
		return false
	if local_size != 1:
		return false
	if not WorldGen.room_split(world_seed, c, theme).is_empty():
		return false
	if WorldGen.anchor_wall(world_seed, c, TARGET_WALL_SALT, theme) < 0:
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


func _ranked_pick(candidates: Array[Vector2i], salt: int) -> Vector2i:
	var best := candidates[0]
	var best_hash := WorldGen.h(world_seed, best.x, best.y, salt + theme * 31)
	for i in range(1, candidates.size()):
		var c := candidates[i]
		var score := WorldGen.h(world_seed, c.x, c.y, salt + theme * 31)
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
			# `edge_info(...)["wall"]` is `is_wall` on every return path, but
			# builds a dictionary and a pile of theme-specific geometry to say
			# so. These two BFS loops are the hot path of a floor build.
			if WorldGen.is_wall(world_seed, c, dir, theme):
				continue
			_target_distance[nb] = dist + 1
			_next[nb] = c
			queue.append(nb)
