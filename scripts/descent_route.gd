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

## Graph distance from the arrival room to the objective, first → last floor.
## The needle degrades with depth (see DescentHUD), so later floors are longer
## in searching as well as in metres.
## Roughly doubled 2026-08-03: a needle-guided 16-edge walk was a one-minute
## floor. With the needle gated behind discovery these bands put the lift
## genuinely out in the building.
const MIN_DIST_FIRST := 26
const MIN_DIST_LAST := 40
const MAX_DIST_FIRST := 34
const MAX_DIST_LAST := 52
## Early floors are teaching floors (2026-08-19: with the photo hunt layered
## on, a 26-34 edge floor 1 played "obnoxiously hard"): floors 1-3 shorten
## toward these caps, floor 4+ runs the authored band untouched — the
## airport audit depends on floor 4's route crossing baggage claim.
const EARLY_SHORTEN := [0.62, 0.78, 0.9]
## How far from the world origin the arrival room is allowed to sit. Cell (0,0)
## is almost never wall-backed — every edge is a guaranteed doorway — so the
## arrival car needs a nearby room that owns a solid wall.
const ARRIVAL_RADIUS := 4
const TARGET_SALT := 1817
const TARGET_WALL_SALT := 1770
const ARRIVAL_SALT := 1904
const ARRIVAL_WALL_SALT := 1911
## At the route's typical ~500m length this yields two or three optional sets,
## matching the same roughly one-per-200m density used by the endless world.
const OPTIONAL_VHS_METRES := 200.0
const OPTIONAL_VHS_MIN := 2
const OPTIONAL_VHS_MAX := 3
const OPTIONAL_VHS_SALT := 7331
## Optional recordings are discoveries, not navigation tests. Put the first
## one early enough to teach the powered-CRT cue and the second around
## mid-route, before end-of-floor pressure takes over.
const OPTIONAL_VHS_PROGRESS_2 := [0.22, 0.55]
const OPTIONAL_VHS_PROGRESS_3 := [0.18, 0.43, 0.68]
## An assistance doorway must remove a meaningful piece of the maze, not merely turn
## one corner into another. Two graph edges are 24 nominal metres: enough to
## break a frustrating loop without teleporting the player through the floor.
const MERCY_MIN_SAVING := 2
const MERCY_SEARCH_RADIUS := 4
## The help cascade's last resort: how far out the assistance search may look
## once nothing within the normal radius offers any real progress.
const BLACKOUT_HELP_WIDE_RADIUS := 7
## Keep assistance inside the same small neighbourhood as decorative changes.
## A mathematically excellent door twenty rooms away is not a visible blackout
## change and cannot guide anybody. If this radius has no useful safe wall, the
## run postpones the blackout and tries again after the player moves.
const BLACKOUT_HELP_SEARCH_RADIUS := 4
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
	9: [WorldGen.POOL_DECK, WorldGen.POOL_ALCOVE,
		WorldGen.POOL_GALLERY, WorldGen.POOL_SOLARIUM],
	10: [WorldGen.BRUTAL_HALL, WorldGen.BRUTAL_GALLERY,
		WorldGen.BRUTAL_ATRIUM, WorldGen.BRUTAL_SERVICE],
	11: [WorldGen.BLOOM_COMMONS, WorldGen.BLOOM_CLASSROOM,
		WorldGen.BLOOM_ATRIUM, WorldGen.BLOOM_GYM],
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
var topology: DescentTopology

var _origin_distance := {}
var _next := {}
var _target_distance := {}
var _optional_vhs_ready := false
var _optional_vhs: Array[Vector2i] = []
var _path_cells := {}
var _ritual_cell := Vector2i(1 << 30, 1 << 30)
var _base_wall_cache := {}

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
	return clampf(float(p_floor_idx) / float(DescentRun.FLOOR_COUNT - 1),
		0.0, 1.0)


func next_from(from: Vector2i) -> Vector2i:
	return _next.get(from, from)


## The immediate BFS hop can be an invisible seam inside a merged room. Follow
## the route until it actually leaves the room and return that boundary, whose
## `edge_info.t` is the exact opening rendered by Chunk.
func next_room_exit(from: Vector2i) -> Dictionary:
	if from == target or not contains(from):
		return {}
	var root := WorldGen.annex_room_id(world_seed, from) if theme == 2 \
		else WorldGen.room_id(world_seed, from)
	var at := from
	var guard := _next.size() + 1
	while guard > 0:
		var following := next_from(at)
		if following == at:
			return {}
		var dir := WorldGen.DIRV.find(following - at)
		if dir < 0:
			return {}
		var next_root := WorldGen.annex_room_id(world_seed, following) \
			if theme == 2 else WorldGen.room_id(world_seed, following)
		if next_root != root:
			return {"cell": at, "dir": dir, "next": following}
		at = following
		guard -= 1
	return {}


## The objective altar and lift always share the target room. Separating them
## taught the player to follow lift guidance past a mandatory tape and then
## search backward without a marker. Variation belongs in optional recordings;
## the required end-of-floor interaction must be unmistakable.
func objective_ritual_cell() -> Vector2i:
	if _ritual_cell.x != (1 << 30):
		return _ritual_cell
	_ritual_cell = target
	return _ritual_cell


func contains(at: Vector2i) -> bool:
	return _target_distance.has(at)


func distance_from_target(at: Vector2i) -> int:
	return int(_target_distance.get(at, -1))


## Runtime topology is attached only after the deterministic target has been
## selected. Adding a supernatural opening then rebuilds guidance without ever
## changing the seed-authored base world.
func set_topology(value: DescentTopology) -> void:
	topology = value
	if not _origin_distance.is_empty() and target != origin:
		_build_reverse_map()


func refresh_topology() -> void:
	if not _origin_distance.is_empty():
		_build_reverse_map()


func edge_info(at: Vector2i, dir: int) -> Dictionary:
	if topology != null:
		return topology.edge_info(at, dir)
	return WorldGen.edge_info(world_seed, at, dir, theme)


func is_wall(at: Vector2i, dir: int) -> bool:
	return topology.is_wall(at, dir) if topology != null else \
		base_is_wall(at, dir)


func base_is_wall(at: Vector2i, dir: int) -> bool:
	var key := DescentTopology.edge_key(at, dir)
	if not _base_wall_cache.has(key):
		_base_wall_cache[key] = WorldGen.is_wall(world_seed, at, dir, theme)
	return bool(_base_wall_cache[key])


func scanned_contains(at: Vector2i) -> bool:
	return _origin_distance.has(at)


func scanned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for value in _origin_distance.keys():
		out.append(value as Vector2i)
	return out


## Every blackout opens the same kind of impossible, persistent doorway. The
## selector is deliberately opaque to presentation: normally it prefers a
## nearby connection that does not materially shorten the route; after genuine
## navigation stall it searches the explored side much farther for a useful
## connection. The player sees and hears exactly the same event either way.
func find_blackout_doorway(from: Vector2i, visited: Dictionary,
		require_help: bool) -> Dictionary:
	if not require_help:
		return _blackout_doorway_pass(from, visited, false,
			MERCY_SEARCH_RADIUS, MERCY_MIN_SAVING)
	# The help cascade. Some layouts simply have no wall within easy reach
	# whose far side saves two full steps; before this existed the search
	# came back empty there and a proven stall got nothing at all. Prefer the
	# strong nearby door, then a weaker nearby door (one step closer is still
	# guidance), then a strong door from farther out — nearness already
	# dominates the scoring, so the later tiers only ever act where the first
	# would have failed.
	for attempt: Array in [
			[BLACKOUT_HELP_SEARCH_RADIUS, MERCY_MIN_SAVING],
			[BLACKOUT_HELP_SEARCH_RADIUS, 1],
			[BLACKOUT_HELP_WIDE_RADIUS, MERCY_MIN_SAVING]]:
		var found := _blackout_doorway_pass(from, visited, true,
			int(attempt[0]), int(attempt[1]))
		if not found.is_empty():
			return found
	return {}


func _blackout_doorway_pass(from: Vector2i, visited: Dictionary,
		require_help: bool, radius: int, min_saving: int) -> Dictionary:
	if topology == null or not contains(from):
		return {}
	var old_distance := distance_from_target(from)
	if old_distance < 0:
		return {}
	var nearby := _runtime_distances(from, radius)
	var optional_cells := optional_vhs_cells()
	var best_helpful := {}
	var best_helpful_score := -INF
	var best_shortcut := {}
	var best_shortcut_score := -INF
	var best_decorative := {}
	var best_decorative_score := -INF
	var best_any := {}
	var best_any_score := -INF
	for key in nearby:
		var at: Vector2i = key
		var was_visited := visited.has(at)
		if (not require_help and not was_visited) \
				or not _blackout_cell_ok(at, from, optional_cells, true, true):
			continue
		var approach := int(nearby[at])
		for dir in 4:
			if not WorldGen.is_wall(world_seed, at, dir, theme) \
					or topology.has_shortcut(at, dir):
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if not _blackout_cell_ok(other, from, optional_cells, true):
				continue
			if not is_equal_approx(Chunk.cell_floor_h(world_seed, at, theme),
					Chunk.cell_floor_h(world_seed, other, theme)):
				continue
			var other_distance := distance_from_target(other)
			if other_distance < 0:
				continue
			var new_distance := approach + 1 + other_distance
			# Adding an edge can never make the current shortest route worse. A
			# proposed path longer than the existing one is therefore a true
			# decorative connection with zero actual saving.
			var saving := maxi(0, old_distance - new_distance)
			var destination_gain := old_distance - other_distance
			var tie := float(WorldGen.h(world_seed, at.x, at.y,
				2909 + dir * 17 + topology.shortcut_count() * 131)) \
				/ 2147483647.0
			var candidate := {
				"cell": at,
				"dir": dir,
				"other": other,
				"saving": saving,
				"old_distance": old_distance,
				"new_distance": new_distance,
				"approach": approach,
				"destination_gain": destination_gain,
			}
			# Nearness dominates once a doorway meets the help threshold. It
			# should be discoverable, not a theoretically excellent opening a
			# dozen rooms away.
			var helpful_score := -float(approach) * 100.0 \
				+ float(saving) * 8.0 - tie
			if was_visited:
				helpful_score += 240.0
			if destination_gain >= min_saving \
					and helpful_score > best_helpful_score:
				best_helpful_score = helpful_score
				best_helpful = candidate
			# A true current-position shortcut is stronger than guidance alone.
			# Prefer it whenever available, but do not make it the only form of
			# help a one-edge topology change is allowed to provide.
			if saving >= min_saving \
					and helpful_score > best_shortcut_score:
				best_shortcut_score = helpful_score
				best_shortcut = candidate
			var decorative_score := -float(approach) * 100.0 \
				- float(saving) * 20.0 - tie
			if saving < MERCY_MIN_SAVING \
					and decorative_score > best_decorative_score:
				best_decorative_score = decorative_score
				best_decorative = candidate
			var any_score := -float(approach) * 100.0 \
				+ float(saving) * 4.0 - tie
			if any_score > best_any_score:
				best_any_score = any_score
				best_any = candidate
	if require_help and not best_shortcut.is_empty():
		best_shortcut["assistance"] = true
		return best_shortcut
	if require_help and not best_helpful.is_empty():
		best_helpful["assistance"] = true
		return best_helpful
	if require_help:
		return {}
	if not require_help and not best_decorative.is_empty():
		best_decorative["assistance"] = false
		return best_decorative
	# Exhaustion should postpone a blackout only when there is literally no
	# safe wall left. A normal opening may incidentally help a little; that
	# uncertainty is part of why the player can never identify mercy for sure.
	if not best_any.is_empty():
		best_any["assistance"] = false
	return best_any


func _runtime_distances(from: Vector2i, radius: int) -> Dictionary:
	var distances := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var distance := int(distances[at])
		if distance >= radius:
			continue
		for dir in 4:
			if bool(edge_info(at, dir)["wall"]):
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if distances.has(other) or not _origin_distance.has(other):
				continue
			distances[other] = distance + 1
			queue.append(other)
	return distances


func _blackout_cell_ok(at: Vector2i, player_cell: Vector2i,
		optional_cells: Array[Vector2i], allow_corridor := false,
		allow_player := false) -> bool:
	if (at == player_cell and not allow_player) or at == origin or at == target \
			or optional_cells.has(at) or not _origin_distance.has(at):
		return false
	var corridor := WorldGen.annex_corridor_axis(world_seed, at) != 0 \
		if theme == 2 else WorldGen.corridor(world_seed, at) != 0
	if corridor:
		if not allow_corridor:
			return false
	else:
		if theme == 2:
			var annex_root := WorldGen.annex_room_id(world_seed, at)
			if not allow_corridor and (annex_root != at \
					or WorldGen.annex_room_size(world_seed, annex_root) != 1):
				return false
		else:
			var root := WorldGen.room_id(world_seed, at)
			if not WorldGen.room_split(world_seed, root, theme).is_empty():
				return false
			if not allow_corridor and (root != at \
					or WorldGen.room_size(world_seed, root) != 1):
				return false
	if WorldGen.portal(world_seed, at, theme) >= 0 \
			or WorldGen.elevator_cell(world_seed, at, theme):
		return false
	# Ordinary charging stations are placed on this lattice after the furniture
	# cull. Leave their cells alone until station placement itself becomes
	# doorway-aware.
	return not (posmod(at.x, 3) == 1 and posmod(at.y, 3) == 1)


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


func optional_vhs_cells() -> Array[Vector2i]:
	_build_optional_vhs_cells()
	return _optional_vhs.duplicate()


func is_path_cell(at: Vector2i) -> bool:
	_build_optional_vhs_cells()
	return _path_cells.has(at)


func _build_optional_vhs_cells() -> void:
	if _optional_vhs_ready:
		return
	_optional_vhs_ready = true
	var path := path_from_origin()
	for c in path:
		_path_cells[c] = true
	if path.size() < 10:
		return
	var wanted := clampi(roundi(walk_metres() / OPTIONAL_VHS_METRES),
		OPTIONAL_VHS_MIN, OPTIONAL_VHS_MAX)
	var preferred := _optional_vhs_candidates(path, true)
	var candidates := preferred
	if candidates.size() < wanted:
		candidates = _optional_vhs_candidates(path, false)
	for slot in wanted:
		if candidates.is_empty():
			break
		var authored_progress := OPTIONAL_VHS_PROGRESS_3 \
			if wanted >= 3 else OPTIONAL_VHS_PROGRESS_2
		var desired: float = authored_progress[mini(slot,
			authored_progress.size() - 1)]
		var best_idx := 0
		var best_score := INF
		for i in candidates.size():
			var entry: Dictionary = candidates[i]
			var progress := float(entry["path_idx"]) / float(path.size() - 1)
			var tie := float(WorldGen.h(world_seed, entry["cell"].x,
				entry["cell"].y, OPTIONAL_VHS_SALT + slot)) / 2147483647.0
			var score := absf(progress - desired) + tie * 0.001
			if score < best_score:
				best_score = score
				best_idx = i
		var chosen: Dictionary = candidates.pop_at(best_idx)
		_optional_vhs.append(chosen["cell"])


func _optional_vhs_candidates(path: Array[Vector2i], dry_pool_only: bool) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen_rooms := {}
	for idx in range(4, path.size() - 4):
		var c := path[idx]
		# The remote objective altar owns its cell outright; an optional set
		# sharing the room would put two televisions in one frame.
		if c == objective_ritual_cell():
			continue
		var room := WorldGen.annex_room_id(world_seed, c) if theme == 2 \
			else WorldGen.room_id(world_seed, c)
		if seen_rooms.has(room):
			continue
		seen_rooms[room] = true
		if theme == 9 and dry_pool_only \
				and not Chunk.pool_style_dry(WorldGen.cell_style(world_seed, c, theme)):
			continue
		var has_wall := false
		for dir in 4:
			if WorldGen.edge_info(world_seed, c, dir, theme)["wall"]:
				has_wall = true
				break
		if not has_wall:
			continue
		out.append({"cell": c, "path_idx": idx})
	return out


## Straight-line metres along the path. The needle stops naming doorways after
## the first two floors, so this is a floor of the real walk, not the whole of
## it — but it is the number worth tuning against.
func walk_metres() -> float:
	return float(maxi(0, path_from_origin().size() - 1)) * WorldGen.CELL_SIZE


func _build() -> void:
	var depth := depth_of(floor_idx)
	var shorten := float(EARLY_SHORTEN[floor_idx]) \
		if floor_idx < EARLY_SHORTEN.size() else 1.0
	min_dist = roundi(lerpf(float(MIN_DIST_FIRST), float(MIN_DIST_LAST),
		depth) * shorten)
	max_dist = roundi(lerpf(float(MAX_DIST_FIRST), float(MAX_DIST_LAST),
		depth) * shorten)
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
			if is_wall(c, dir):
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
	# The dry Poolrooms deck is 1.42m above the basin. The car is planted on
	# that datum, so low single-height rooms need extra absolute headroom.
	if theme == 9 and WorldGen.room_height(world_seed, c, theme) < 4.45:
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
			if is_wall(c, dir):
				continue
			_target_distance[nb] = dist + 1
			_next[nb] = c
			queue.append(nb)
	if _target_distance.has(origin):
		graph_distance = int(_target_distance[origin])
