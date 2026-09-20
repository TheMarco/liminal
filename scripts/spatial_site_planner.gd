class_name SpatialSitePlanner
extends RefCounted
## Pure, bounded, deterministic site placement. No scene construction, no actor
## queries. Office only, one migrating-door site per floor: a junction cell
## with two adjacent site apertures and an ordinary open entrance.
##
## cells[0] is always the junction. The site's apertures sit on the
## junction's walls; witness and dressing math derives from that.

const PLANNER_VERSION := 3
const OFFICE_THEME := 1
const MAX_CANDIDATES := 40
const SALTS := 4
const MAX_ROOM_MEMBERS := 9
const FAR_CELL := Vector2i(1 << 30, 1 << 30)

## The wall clock is read as a landmark together with the fixed pillar edge
## around it.  The physical face alone is too small to satisfy the global
## useful-view thresholds from the site's intended junction composition.
const ANCHOR_WITNESS_EXTENTS := Vector2(0.55, 0.55)

## Adjacent (perpendicular) direction pairs for the two apertures.
const APERTURE_PAIRS := [
	[0, 2], [0, 3], [1, 2], [1, 3],
]


static func plan_sites(route: DescentRoute,
		reservations: Dictionary) -> Array[SpatialSiteSpec]:
	var out: Array[SpatialSiteSpec] = []
	if route == null or route.theme != OFFICE_THEME:
		return out
	var path := route.path_from_origin()
	var candidates: Array[Vector2i] = []
	for i in range(0, path.size(), 2):
		if candidates.size() >= MAX_CANDIDATES:
			break
		candidates.append(path[i])
	for salt in SALTS:
		var ordered := _salted_order(candidates, salt)
		for junction in ordered:
			var spec := _try_junction(route, junction, reservations,
				true)
			if spec != null:
				out.append(spec)
				return out
	for salt in SALTS:
		var ordered := _salted_order(candidates, salt)
		for junction in ordered:
			var spec := _try_junction(route, junction, reservations,
				false)
			if spec != null:
				out.append(spec)
				return out
	return out


static func _salted_order(candidates: Array[Vector2i],
		salt: int) -> Array[Vector2i]:
	if candidates.is_empty():
		return candidates
	var shift := posmod(salt * 7, candidates.size())
	var out: Array[Vector2i] = []
	for i in candidates.size():
		out.append(candidates[(i + shift) % candidates.size()])
	return out


static func _try_junction(route: DescentRoute, junction: Vector2i,
		reservations: Dictionary, single_cell: bool) -> SpatialSiteSpec:
	var seed := route.world_seed
	var theme := route.theme
	if WorldGen.corridor(seed, junction) != 0:
		return null
	var members := WorldGen.owning_room_members(seed, junction, theme)
	var is_single := members.size() == 1 and members[0] == junction
	if single_cell and not is_single:
		return null
	if members.size() > MAX_ROOM_MEMBERS:
		return null
	if not route._blackout_cell_ok(junction, FAR_CELL, [], false, true):
		return null
	for pair in APERTURE_PAIRS:
		var dir_a: int = pair[0]
		var dir_b: int = pair[1]
		# The installed a_open layout must be identical to the ordinary generated
		# route: A replaces an existing opening and B replaces an existing wall.
		# Otherwise merely admitting a site can silently reroute the floor before
		# the player has witnessed an event.
		if route.base_is_wall(junction, dir_a) \
				or not route.base_is_wall(junction, dir_b):
			continue
		var cell_a: Vector2i = junction + WorldGen.DIRV[dir_a]
		var cell_b: Vector2i = junction + WorldGen.DIRV[dir_b]
		if not _neighbour_ok(route, reservations, cell_a):
			continue
		if not _neighbour_ok(route, reservations, cell_b):
			continue
		var entrance := _entrance_dir(route, junction, dir_a, dir_b)
		if entrance < 0:
			continue
		var floor_h := Chunk.cell_floor_h(seed, junction, theme)
		if Chunk.cell_floor_h(seed, cell_a, theme) != floor_h:
			continue
		if Chunk.cell_floor_h(seed, cell_b, theme) != floor_h:
			continue
		var cells: Array[Vector2i] = [junction]
		for member in members:
			if member != junction and not cells.has(member):
				cells.append(member)
		for extra in [cell_a, cell_b]:
			if not cells.has(extra):
				cells.append(extra)
		for at in cells:
			if reservations.has(at):
				return null
			if route.topology != null \
					and route.topology.photo_edge_near(at):
				return null
		# Prove the complete scanned floor, not just the three local junction
		# cells. Any scanned cell can contain the player, a pursuer, evidence, or
		# an objective when A retires, so every stable/intermediate phase must
		# still reach the floor target.
		if not _all_phases_connected(route, junction, dir_a, dir_b):
			continue
		return _make_spec(route, junction, dir_a, dir_b, cells, floor_h)
	return null


static func _all_phases_connected(route: DescentRoute, junction: Vector2i,
		dir_a: int, dir_b: int) -> bool:
	var scanned := {}
	for at in route.scanned_cells():
		scanned[at] = true
	for phase in [
			{"a": true, "b": false},
			{"a": true, "b": true},
			{"a": false, "b": true},
	]:
		if not _phase_connects_scanned(route, junction, dir_a, dir_b,
				bool(phase["a"]), bool(phase["b"]), scanned):
			return false
	return true


static func _phase_connects_scanned(route: DescentRoute, junction: Vector2i,
		dir_a: int, dir_b: int, a_open: bool, b_open: bool,
		scanned: Dictionary) -> bool:
	if route == null or not scanned.has(route.target):
		return false
	var overrides := {
		DescentTopology.edge_key(junction, dir_a): a_open,
		DescentTopology.edge_key(junction, dir_b): b_open,
	}
	var reached := {route.target: true}
	var queue: Array[Vector2i] = [route.target]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for dir in 4:
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if reached.has(other) or not scanned.has(other):
				continue
			var key := DescentTopology.edge_key(at, dir)
			var open := bool(overrides[key]) if overrides.has(key) \
				else not bool(route.edge_info(at, dir).get("wall", true))
			if not open:
				continue
			reached[other] = true
			queue.append(other)
	return reached.size() == scanned.size()


static func _neighbour_ok(route: DescentRoute, reservations: Dictionary,
		at: Vector2i) -> bool:
	if not route.scanned_contains(at) or reservations.has(at):
		return false
	return bool(route._blackout_cell_ok(at, FAR_CELL, [], true, true))


static func _entrance_dir(route: DescentRoute, junction: Vector2i,
		dir_a: int, dir_b: int) -> int:
	for dir in 4:
		if dir == dir_a or dir == dir_b:
			continue
		if route.base_is_wall(junction, dir):
			continue
		var other: Vector2i = junction + WorldGen.DIRV[dir]
		if route.scanned_contains(other):
			return dir
	return -1


static func _make_spec(route: DescentRoute, junction: Vector2i,
		dir_a: int, dir_b: int, cells: Array[Vector2i],
		floor_h: float) -> SpatialSiteSpec:
	var origin := Vector3(junction.x * WorldGen.CELL_SIZE, floor_h,
		junction.y * WorldGen.CELL_SIZE)
	var end_a := _endpoint(origin, dir_a, floor_h)
	var end_b := _endpoint(origin, dir_b, floor_h)
	var anchor_face := anchor_clock_face_spot(origin, dir_a, dir_b, floor_h)
	var spec_id := "floor:%d/site:door:%d:%d:0" % [route.floor_idx,
		junction.x, junction.y]
	return SpatialSiteSpec.make_door(
		spec_id, route.theme, PLANNER_VERSION, cells,
		[spec_id + ":clock"],
		{"a": end_a, "b": end_b},
		["a_open", "both_open", "b_open"],
		[_swept_for(end_a, dir_a), _swept_for(end_b, dir_b)],
		{
			"opening_a": {"position": _witness_spot(end_a),
				"extents": Vector2(1.6, 1.35)},
			"wall_b": {"position": _witness_spot(end_b),
				"extents": Vector2(1.6, 1.35)},
			"anchor_clock": {"position": anchor_face,
				"extents": ANCHOR_WITNESS_EXTENTS},
		},
		["exit"])


## Aperture frame: origin at the edge midpoint (floor level), +Z facing
## into the junction, X running along the wall.
static func _endpoint(cell_origin: Vector3, dir: int,
		_floor_h: float) -> Transform3D:
	var mid := cell_origin + Vector3(6.0, 0.0, 6.0)
	match dir:
		0:
			mid += Vector3(6.0, 0.0, 0.0)
		1:
			mid += Vector3(-6.0, 0.0, 0.0)
		2:
			mid += Vector3(0.0, 0.0, 6.0)
		_:
			mid += Vector3(0.0, 0.0, -6.0)
	var inward := Vector3(-WorldGen.DIRV[dir].x, 0.0,
		-WorldGen.DIRV[dir].y)
	var yaw := atan2(inward.x, inward.z)
	return Transform3D(Basis(Vector3(0, 1, 0), yaw), mid)


static func _witness_spot(endpoint: Transform3D) -> Vector3:
	return endpoint.origin + endpoint.basis.z * 0.5 + Vector3(0, 1.4, 0)


## Anchor corner of the junction cell, away from both aperture midpoints.
static func anchor_spot(cell_origin: Vector3, dir_a: int, dir_b: int,
		floor_h: float) -> Vector3:
	var mid_a := _endpoint(cell_origin, dir_a, floor_h).origin
	var mid_b := _endpoint(cell_origin, dir_b, floor_h).origin
	var best := cell_origin + Vector3(1.0, 0.0, 1.0)
	var best_score := -1.0
	for corner in [Vector3(1.0, 0.0, 1.0), Vector3(11.0, 0.0, 1.0),
			Vector3(1.0, 0.0, 11.0), Vector3(11.0, 0.0, 11.0)]:
		var spot: Vector3 = cell_origin + corner
		spot.y = floor_h
		var score: float = spot.distance_to(mid_a) \
			+ spot.distance_to(mid_b)
		if score > best_score:
			best_score = score
			best = spot
	return best


## Visible point on the fixed clock face, just outside the pillar collider.
## Witness rays target architecture the player can actually see rather than
## terminating inside the anchor's solid volume.
static func anchor_clock_face_spot(cell_origin: Vector3, dir_a: int,
		dir_b: int, floor_h: float) -> Vector3:
	var anchor := anchor_spot(cell_origin, dir_a, dir_b, floor_h)
	var to_center := cell_origin + Vector3(6.0, 0.0, 6.0) - anchor
	to_center.y = 0.0
	if to_center.length_squared() < 0.0001:
		return anchor + Vector3(0, 1.9, 0)
	var face_x := absf(to_center.x) >= absf(to_center.z)
	var facing := Vector3(signf(to_center.x), 0, 0) if face_x \
		else Vector3(0, 0, signf(to_center.z))
	return anchor + facing * 0.36 + Vector3(0, 1.9, 0)


static func _swept_for(endpoint: Transform3D, dir: int) -> AABB:
	var center: Vector3 = endpoint.origin + Vector3(0, 1.5, 0)
	if dir < 2:
		return AABB(center + Vector3(-0.75, -2.0, -4.0),
			Vector3(1.5, 4.0, 8.0))
	return AABB(center + Vector3(-4.0, -2.0, -0.75),
		Vector3(8.0, 4.0, 1.5))


## Junction frame for builders: origin cell plus aperture dirs derived
## from the spec endpoints (cells[0] is always the junction; room members
## are not aperture dirs).
static func junction_frame(spec: SpatialSiteSpec) -> Dictionary:
	var out := {"cell": Vector2i.ZERO, "dirs": []}
	if spec == null or spec.cells.is_empty():
		return out
	var junction: Vector2i = spec.cells[0]
	out["cell"] = junction
	if not spec.endpoints.has("a") or not spec.endpoints.has("b"):
		return out
	var origin := Vector3(junction.x * WorldGen.CELL_SIZE, 0.0,
		junction.y * WorldGen.CELL_SIZE)
	var dirs: Array = []
	for key in ["a", "b"]:
		var local: Vector3 = (spec.endpoints[key] as Transform3D).origin \
			- origin
		dirs.append(_edge_dir_for(local))
	out["dirs"] = dirs
	return out


static func _edge_dir_for(local: Vector3) -> int:
	var dx := local.x - 6.0
	var dz := local.z - 6.0
	if absf(dx) > absf(dz):
		return 0 if dx > 0.0 else 1
	return 2 if dz > 0.0 else 3
