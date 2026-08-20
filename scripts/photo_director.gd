class_name PhotoDirector
extends Node
## Owns the floor's evidence: which cells carry an anomaly, which have been
## documented, and whether the tape will accept the floor as proven.
##
## The plan is a pure function of (seed, theme, floor): REQUIRED cells picked
## along the guided route's spine so the requirement can always be met without
## leaving it, plus EXTRA cells scattered off-route so runs do not rhyme.
## Spawning is streaming-driven — `chunk_built` fires for fresh builds and for
## post-blackout rebuilds alike, and the anomaly node rides the chunk's
## lifetime. Documented IDs live here and persist through death via
## DescentProgress; a photograph taken is a photograph kept.

signal documented_changed(count: int, required: int)

## Floor 1-3 wants 3 photographs, 4-6 wants 4, 7+ wants 5 — deeper floors
## are 2.5x longer, so a flat count shrank to a footnote (owner,
## 2026-08-20). Prop-less themes (airport, prison, Monolith, Bloom) stay
## at 3: their anomalies are wall-writing only and qualifying cells are
## scarcer. REQUIRED survives as the floor-1 base the audits anchor on.
const REQUIRED := 3


static func required_for(p_floor_idx: int, p_theme: int) -> int:
	if not PhotoAnomaly.PROP_THEMES.has(p_theme):
		return REQUIRED
	var extra := 0
	if p_floor_idx >= 3:
		extra += 1
	if p_floor_idx >= 6:
		extra += 1
	return REQUIRED + extra


## The route spine carries MORE valid anomalies than the tape demands (need
## 3, walk past 5; need 4, past 7; need 5, past 8), so "n-1 of n, where is
## the last one" cannot strand a floor on route (owner, 2026-08-20). The
## gate itself never changes.
static func spine_count_for(p_floor_idx: int, p_theme: int) -> int:
	var required := required_for(p_floor_idx, p_theme)
	return required + (2 if required <= 3 else 3)
## Extras are the coverage: the route spine is one path through an open maze
## and nothing forces the player across it, so the off-route pool must be
## dense enough that ANY walk to the lift passes evidence (raised 3 -> 9
## on 2026-08-19 after a full floor produced zero encounters).
const EXTRA := 12
## Path fractions for the guaranteed on-route anomalies, the optional-VHS
## pattern: spaced through the walk, never at the doors.
## Path fractions for the guaranteed on-route anomalies: evenly spread
## through the walk, never at the doors, count matching required_for.
static func route_fractions(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append((float(i) + 1.0) / (float(count) + 1.0))
	return out

var world_seed := 0
var theme := 0
var floor_idx := 0
var route: DescentRoute
var debug_visible := false
var plan: Dictionary = {}   # Vector2i -> {id, type, wall_dir, wall_along, required}
var _documented: Dictionary = {}  # id -> true
var _live: Dictionary = {}        # Vector2i -> PhotoAnomaly
var _live_bleed: Dictionary = {}  # Vector2i -> PhotoAnomaly (BLEED marks)


func configure(p_route: DescentRoute, p_floor_idx: int, cm: ChunkManager,
		known_ids: Array) -> void:
	route = p_route
	world_seed = route.world_seed
	theme = route.theme
	floor_idx = p_floor_idx
	plan = build_plan(route)
	_documented.clear()
	_live.clear()
	_live_bleed.clear()
	for known in known_ids:
		_documented[str(known)] = true
	if cm != null and not cm.chunk_built.is_connected(_on_chunk_built):
		cm.chunk_built.connect(_on_chunk_built)
	documented_changed.emit(documented_count(), required_count())


## Pure planning, shared with the audit. Guarantees REQUIRED valid cells on
## the route spine; the extras come from the scanned neighbourhood off it.
static func build_plan(p_route: DescentRoute) -> Dictionary:
	var out: Dictionary = {}
	var path := p_route.path_from_origin()
	if path.size() < 4:
		return out
	var reserved := {p_route.origin: true, p_route.target: true}
	# The three on-route anomalies are three DIFFERENT types wherever the
	# cells allow it — a floor of three identical hangings reads as one idea
	# repeated (playtest, 2026-08-19).
	var used_types := {}
	var slot := 0
	var spine := spine_count_for(p_route.floor_idx, p_route.theme)
	for fraction in route_fractions(spine):
		var idx := clampi(int(float(path.size()) * float(fraction)),
			1, path.size() - 2)
		var placed := false
		for step in path.size():
			var at: Vector2i = path[(idx + step) % path.size()]
			if reserved.has(at) or out.has(at):
				continue
			var spec := _spec_for(p_route, at, true, used_types, slot)
			if spec.is_empty():
				continue
			used_types[int(spec["type"])] = true
			out[at] = spec
			placed = true
			break
		slot += 1
		if not placed:
			return {}
	var extras := 0
	var scanned := p_route.scanned_cells()
	var start := WorldGen.h(p_route.world_seed, p_route.floor_idx,
		scanned.size(), 9301) % maxi(1, scanned.size())
	for step in scanned.size():
		if extras >= EXTRA:
			break
		var at: Vector2i = scanned[(start + step) % scanned.size()]
		if reserved.has(at) or out.has(at) or p_route.is_path_cell(at):
			continue
		var spec := _spec_for(p_route, at, false, {}, -1)
		if spec.is_empty():
			continue
		out[at] = spec
		extras += 1
	return out


## The types this cell can host. Props are the floor's own signature object;
## themes without a portable prop plan WRITING only, and WRITING needs a
## qualifying wall.
static func _eligible_types(p_route: DescentRoute, at: Vector2i) -> Array:
	var out: Array = []
	if PhotoAnomaly.PROP_THEMES.has(p_route.theme):
		out = [PhotoAnomaly.Type.PLACEMENT, PhotoAnomaly.Type.DUPLICATE,
			PhotoAnomaly.Type.GIANT, PhotoAnomaly.Type.RING,
			PhotoAnomaly.Type.MISSING]
	if not PhotoAnomaly.writing_spot_for(p_route, at).is_empty():
		out.append(PhotoAnomaly.Type.WRITING)
		out.append(PhotoAnomaly.Type.PRINT)
		out.append(PhotoAnomaly.Type.PORTAL)
	return out


## `used_types`/`slot` steer required picks away from repeats: the choice is
## a hash over (seed, floor, slot) into the cell's unused eligible types,
## falling back to any eligible one. Extras pass {} and -1 for the plain
## per-cell hash.
static func _spec_for(p_route: DescentRoute, at: Vector2i, required: bool,
		used_types: Dictionary, slot: int) -> Dictionary:
	var eligible := _eligible_types(p_route, at)
	if eligible.is_empty():
		return {}
	var pool: Array = []
	if required:
		# The wall writings are the feature's voice and the rarest type by
		# eligibility, so the trio claims one greedily the first time a
		# route cell offers a wall (owner: floors showed only prop
		# anomalies, 2026-08-19).
		if not used_types.has(PhotoAnomaly.Type.WRITING) \
				and eligible.has(PhotoAnomaly.Type.WRITING):
			pool = [PhotoAnomaly.Type.WRITING]
		else:
			for t in eligible:
				if not used_types.has(int(t)):
					pool.append(t)
	else:
		# Extras: double-weight WRITING so the endless neighbourhood keeps
		# a voice too.
		pool = eligible.duplicate()
		if eligible.has(PhotoAnomaly.Type.WRITING):
			pool.append(PhotoAnomaly.Type.WRITING)
	if pool.is_empty():
		pool = eligible
	# Neighbouring cells' raw hashes correlate modulo small pool sizes
	# (a floor once planned seven MISSINGs), so the pick runs through r01.
	var roll := WorldGen.r01(p_route.world_seed, at.x, at.y, 9311) \
		if slot < 0 else WorldGen.r01(p_route.world_seed,
			p_route.floor_idx, slot + 977, 9311)
	var type: int = int(pool[mini(int(roll * float(pool.size())),
		pool.size() - 1)])
	var spot := PhotoAnomaly.writing_spot_for(p_route, at)
	return {
		"id": "cell:%d:%d" % [at.x, at.y],
		"type": type,
		"wall_dir": int(spot.get("dir", -1)),
		"wall_along": float(spot.get("along", WorldGen.CELL_SIZE * 0.5)),
		"required": required,
	}


## World position of the nearest undocumented planned anomaly (streamed in
## or not — the plan is enough), or Vector3.INF when everything is shot.
## Feeds the post-refusal EVIDENCE counter.
func nearest_undocumented(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for at in plan:
		if _documented.has(str(plan[at]["id"])):
			continue
		var world := Vector3(
			(float(at.x) + 0.5) * WorldGen.CELL_SIZE, 0.0,
			(float(at.y) + 0.5) * WorldGen.CELL_SIZE)
		var d := Vector2(world.x - from.x, world.z - from.z).length()
		if d < best_d:
			best_d = d
			best = world
	return best


func requirement_met() -> bool:
	return documented_count() >= required_count()


func documented_count() -> int:
	return _documented.size()


func required_count() -> int:
	return required_for(floor_idx, theme)


func documented_ids() -> Array:
	return _documented.keys()


## Live, still-undocumented anomalies for the camera to test against. Bleed
## marks join the pool until their one floor credit is spent — the theme
## bleeding up through the building is itself something wrong, and it is
## guaranteed to occur near the lift where the planned pool may not reach.
func capturable() -> Array[PhotoAnomaly]:
	var out: Array[PhotoAnomaly] = []
	# The hunt ends at the requirement: once the tape is satisfied the
	# detector goes quiet and no further anomaly pings, focuses or counts
	# (owner rule 2026-08-19). The undocumented ones stay in the world as
	# set dressing for whoever notices.
	if requirement_met():
		return out
	_collect_capturable(_live, out)
	# Bleed marks: one counted credit per floor while the hunt is open, but
	# ANY bleed item may serve as the LAST photograph (owner rule
	# 2026-08-19) — the lift area is thick with them, so the floor is
	# always completable there.
	if not bleed_credit_used() or documented_count() == required_count() - 1:
		_collect_capturable(_live_bleed, out)
	return out


## The typed assignment is the trap: chunks stream out and free their
## anomalies, and assigning a freed instance to a typed var is itself a
## runtime error that aborts the scan — which silenced the entire detector
## for the rest of the floor (2026-08-19). Validate BEFORE typing, and prune
## the dead entries so the dictionaries cannot rot.
func _collect_capturable(pool: Dictionary, out: Array[PhotoAnomaly]) -> void:
	var dead: Array = []
	for at in pool:
		var raw: Variant = pool[at]
		if not is_instance_valid(raw):
			dead.append(at)
			continue
		var node := raw as PhotoAnomaly
		if node == null or not node.is_inside_tree():
			continue
		if _documented.has(node.id):
			continue
		out.append(node)
	for at in dead:
		pool.erase(at)


## One counted bleed photograph per floor: the category is evidence once.
func bleed_credit_used() -> bool:
	for doc_id in _documented:
		if str(doc_id).begins_with("bleed:"):
			return true
	return false


## Returns true when the id was new — the caller's cue for feedback and the
## post-photo danger roll.
func mark_documented(anomaly_id: String) -> bool:
	if _documented.has(anomaly_id):
		return false
	_documented[anomaly_id] = true
	documented_changed.emit(documented_count(), required_count())
	return true


func _on_chunk_built(chunk: Chunk) -> void:
	_register_bleed_props(chunk)
	if not plan.has(chunk.cell):
		return
	var spec: Dictionary = plan[chunk.cell]
	# Target and arrival rooms never carry evidence; the plan already avoids
	# them, and the arrival flag guards a respawned arrival reality too.
	if chunk.descent_target or chunk.descent_arrival:
		return
	# A documented anomaly stays resolved: a rebuilt cell returns to normal
	# instead of resurrecting the wrongness the photograph settled.
	if _documented.has(str(spec["id"])):
		return
	var wall_dir := int(spec["wall_dir"])
	var wall_along := float(spec["wall_along"])
	# A blackout mutation may have opened the planned wall since planning;
	# re-resolve against the current topology and fall back to the plan.
	if int(spec["type"]) in [PhotoAnomaly.Type.WRITING,
			PhotoAnomaly.Type.PRINT, PhotoAnomaly.Type.PORTAL] \
			and route != null:
		var spot := PhotoAnomaly.writing_spot_for(route, chunk.cell)
		if not spot.is_empty():
			wall_dir = int(spot["dir"])
			wall_along = float(spot["along"])
	var node := PhotoAnomaly.new()
	node.debug_visible = debug_visible
	# The tear looks into the next floor's air; past the end it looks out.
	var order: Array = DescentRun.FIXED_ORDER
	var order_pos := order.find(theme)
	node.next_theme = int(order[order_pos + 1]) \
		if order_pos >= 0 and order_pos + 1 < order.size() else -1
	if debug_visible:
		print("photo anomaly spawn %s type %d wall %d along %.1f" % [
			str(spec["id"]), int(spec["type"]), wall_dir, wall_along])
	# Parent first: the spot search inside configure() asks the chunk's
	# collision bookkeeping for clearance.
	chunk.add_child(node)
	node.configure(str(spec["id"]), int(spec["type"]), chunk.cell,
		world_seed, theme, wall_dir, wall_along)
	_live[chunk.cell] = node


## Any bleed prop the dressing placed in this cell becomes a photographable
## mark (id per cell, so a rebuilt cell cannot mint a fresh credit).
func _register_bleed_props(chunk: Chunk) -> void:
	if chunk.descent_target or chunk.descent_arrival:
		return
	if _live_bleed.has(chunk.cell) \
			and is_instance_valid(_live_bleed[chunk.cell]) \
			and (_live_bleed[chunk.cell] as Node).is_inside_tree():
		return
	var points: Array[Vector3] = []
	for child in chunk.get_children():
		if child is Node3D and child.has_meta("bleed_prop"):
			points.append((child as Node3D).position + Vector3(0, 0.9, 0))
	if points.is_empty():
		return
	var node := PhotoAnomaly.new()
	node.configure_bleed("bleed:%d:%d" % [chunk.cell.x, chunk.cell.y],
		chunk.cell, points)
	chunk.add_child(node)
	_live_bleed[chunk.cell] = node
