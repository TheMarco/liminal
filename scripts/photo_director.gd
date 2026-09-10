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
## 2026-08-20). Anomaly-prop-less themes (airport, prison, Data Center, Bloom) stay
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
var realm_preview_ready := true
var realm_destination := ""
var plan: Dictionary = {}   # Vector2i -> {id, type, wall_dir, wall_along, required}
var _documented: Dictionary = {}  # id -> true
var _live: Dictionary = {}        # Vector2i -> PhotoAnomaly
var _live_bleed: Dictionary = {}  # Vector2i -> PhotoAnomaly (BLEED marks)
var _live_doors: Dictionary = {}  # edge id + side -> PhotoAnomaly
var _chunk_manager: ChunkManager
var _door_ready_cache: Dictionary = {}


func configure(p_route: DescentRoute, p_floor_idx: int, cm: ChunkManager,
		known_ids: Array) -> void:
	route = p_route
	world_seed = route.world_seed
	theme = route.theme
	floor_idx = p_floor_idx
	realm_preview_ready = true
	realm_destination = ""
	plan = build_plan(route)
	_documented.clear()
	_live.clear()
	_live_bleed.clear()
	_live_doors.clear()
	_door_ready_cache.clear()
	_chunk_manager = cm
	for known in known_ids:
		_documented[str(known)] = true
		if route.topology != null:
			route.topology.open_photo_door(str(known))
	# A saved photograph is also the durable source of the opening. This runs
	# before warm_up, including after death or a quit while reviewing the print.
	if route.topology != null:
		route.refresh_topology()
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
	# cells allow it — a floor of three identical ceiling pieces reads as one
	# idea repeated (playtest, 2026-08-19).
	var used_types := {}
	var slot := 0
	var spine := spine_count_for(p_route.floor_idx, p_route.theme)
	for at in p_route.casino_landmarks:
		if p_route.casino_landmarks[at] == CasinoLandmarks.PHONE:
			out[at] = {"id": "casino_number:%d:%d" % [at.x, at.y],
				"type": PhotoAnomaly.Type.NUMBERED_DOOR, "wall_dir": -1,
				"wall_along": 6.0, "required": true}
			spine -= 1
			break
	for fraction in route_fractions(spine):
		var idx := clampi(int(float(path.size()) * float(fraction)),
			1, path.size() - 2)
		var placed := false
		for step in path.size():
			var at: Vector2i = path[(idx + step) % path.size()]
			if reserved.has(at) or out.has(at) or p_route.is_intro_door_room(at):
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
	var before_supplement := out.size()
	_add_intro_route_evidence(p_route, out, reserved)
	var extras := out.size() - before_supplement
	var scanned := p_route.scanned_cells()
	var start := WorldGen.h(p_route.world_seed, p_route.floor_idx,
		scanned.size(), 9301) % maxi(1, scanned.size())
	for step in scanned.size():
		if extras >= EXTRA:
			break
		var at: Vector2i = scanned[(start + step) % scanned.size()]
		if reserved.has(at) or out.has(at) or p_route.is_path_cell(at) \
				or p_route.is_intro_door_room(at):
			continue
		var spec := _spec_for(p_route, at, false, {}, -1)
		if spec.is_empty():
			continue
		out[at] = spec
		extras += 1
	return out


## Taking the first shortcut must not require returning to the skipped maze
## solely to fill the photo quota. Spend part of the existing extra pool on
## the shortened route; the doorway itself supplies one photograph.
static func _add_intro_route_evidence(p_route: DescentRoute, out: Dictionary,
		reserved: Dictionary) -> void:
	if p_route.photo_discovery_hint().is_empty():
		return
	var path := p_route.path_after_intro_door()
	var count := intro_route_evidence_count(p_route, out)
	for at in path:
		if count >= required_for(p_route.floor_idx, p_route.theme):
			return
		if reserved.has(at) or out.has(at) or p_route.is_intro_door_room(at):
			continue
		var spec := _spec_for(p_route, at, false, {}, -1)
		if not spec.is_empty():
			out[at] = spec
			count += 1


static func intro_route_evidence_count(p_route: DescentRoute, evidence: Dictionary) -> int:
	var rooms := {}
	var path := p_route.path_after_intro_door()
	var crossed := {}
	var opening_keys := {}
	for hint in [p_route.intro_door_hint, p_route.obstruction_hint]:
		if not hint.is_empty():
			opening_keys[str(hint["key"])] = true
	for idx in path.size():
		var at := path[idx]
		var room := WorldGen.annex_room_id(p_route.world_seed, at) if p_route.theme == 2 else WorldGen.room_id(p_route.world_seed, at)
		rooms[room] = true
		if idx > 0:
			var dir := WorldGen.DIRV.find(at - path[idx - 1])
			var key := DescentTopology.edge_key(path[idx - 1], dir)
			if opening_keys.has(key):
				crossed[key] = true
	var count := crossed.size()
	for at: Vector2i in evidence:
		var room := WorldGen.annex_room_id(p_route.world_seed, at) if p_route.theme == 2 else WorldGen.room_id(p_route.world_seed, at)
		if rooms.has(room):
			count += 1
	return count



## The types this cell can host. Props are the floor's own signature object;
## themes without a portable prop plan WRITING only, and WRITING needs a
## qualifying wall.
static func _eligible_types(p_route: DescentRoute, at: Vector2i) -> Array:
	var out: Array = []
	if PhotoAnomaly.PROP_THEMES.has(p_route.theme):
		out = [PhotoAnomaly.Type.PLACEMENT, PhotoAnomaly.Type.DUPLICATE,
			PhotoAnomaly.Type.RING, PhotoAnomaly.Type.TURNED]
		# GIANT, RING and MISSING all need a large clear floor footprint that
		# only exists after authored furniture has built. GIANT and MISSING add
		# colliders, so they remain authored-only; RING is non-blocking and its
		# runtime builder safely becomes a ceiling placement when the full circle
		# cannot be proven, and TURNED (whose eye copy blocks like real
		# furniture) does the same when no clear floor spot proves out.
		# The plan otherwise uses validated wall pieces.
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
		var world := _anomaly_world_hint(at, plan[at])
		var d := Vector2(world.x - from.x, world.z - from.z).length()
		if d < best_d:
			best_d = d
			best = world
	return best


## The standable point the EVIDENCE counter steers to. The cell centre was
## good enough for props but cruel for wall types: they register only from
## the side they face, so a writing on the far side of a wall read as "2m"
## while the photographable face was a corridor loop away — the counter
## lied exactly when it existed to be merciful (owner report 2026-08-21).
## Wall types steer to a point in front of their face; a live node's true
## spot and facing win over the plan's estimate.
func _anomaly_world_hint(at: Vector2i, spec: Dictionary) -> Vector3:
	var raw: Variant = _live.get(at)
	if is_instance_valid(raw) and (raw as Node).is_inside_tree():
		var node := raw as PhotoAnomaly
		if node != null:
			var pts := node.photo_points()
			if not pts.is_empty():
				return pts[0] + node.facing_normal() * 1.2
	var half := WorldGen.CELL_SIZE * 0.5
	var base := Vector3(float(at.x) * WorldGen.CELL_SIZE, 0.0,
		float(at.y) * WorldGen.CELL_SIZE)
	var wall_dir := int(spec.get("wall_dir", -1))
	if wall_dir >= 0 and int(spec["type"]) in [PhotoAnomaly.Type.WRITING,
			PhotoAnomaly.Type.PRINT, PhotoAnomaly.Type.PORTAL]:
		# Same wall-plane math as the writing builder, pulled 1.2m into the
		# room on the side the piece faces.
		var dirv: Vector2i = WorldGen.DIRV[wall_dir]
		var dirv3 := Vector3(float(dirv.x), 0.0, float(dirv.y))
		var along := float(spec.get("wall_along", half))
		var plane := half + signf(dirv3.x + dirv3.z) * (half - 0.45)
		var local := Vector3(plane, 0.0, along) if dirv3.x != 0.0 \
			else Vector3(along, 0.0, plane)
		return base + local - dirv3 * 1.2
	return base + Vector3(half, 0.0, half)


func requirement_met() -> bool:
	return documented_count() >= required_count()


func documented_count() -> int:
	return _documented.size()


func required_count() -> int:
	return required_for(floor_idx, theme)


func documented_ids() -> Array:
	return _documented.keys()


## New discoveries remain active after the progression minimum. The early
## bleed-credit rule prevents one cluster from replacing the initial hunt;
## after the minimum, every distinct discovery can be documented.
func capturable() -> Array[PhotoAnomaly]:
	var out: Array[PhotoAnomaly] = []
	_collect_capturable(_live_doors, out)
	_collect_capturable(_live, out)
	if requirement_met() or not bleed_credit_used() \
			or documented_count() == required_count() - 1:
		_collect_capturable(_live_bleed, out)
	return out


## Caption candidates include previously documented evidence. They use the
## same framing/occlusion checks as rewards, but never change credit or focus.
func album_subjects() -> Array[PhotoAnomaly]:
	var out: Array[PhotoAnomaly] = []
	for pool in [_live, _live_bleed, _live_doors]:
		for raw: Variant in pool.values():
			if is_instance_valid(raw) and raw is PhotoAnomaly and raw.is_inside_tree():
				out.append(raw)
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
	_register_photo_doors()
	_register_bleed_props(chunk)
	if not plan.has(chunk.cell):
		return
	var spec: Dictionary = plan[chunk.cell]
	# Target and arrival rooms never carry evidence; the plan already avoids
	# them, and the arrival flag guards a respawned arrival reality too.
	if chunk.descent_target or chunk.descent_arrival:
		return
	if int(spec["type"]) == PhotoAnomaly.Type.NUMBERED_DOOR:
		for plate in chunk.find_children("NumberPlate", "Label3D", true, false):
			if not plate.has_meta("casino_number_plate"):
				continue
			var number := PhotoAnomaly.new()
			chunk.add_child(number)
			number.configure_numbered_door(str(spec["id"]), chunk.cell, plate)
			if _documented.has(number.id):
				number.resolve(true)
			_live[chunk.cell] = number
			return
		push_error("Numbered photo door missing in landmark %s" % chunk.cell)
		return
	# Documented anomalies remain visible when rooms stream back in.
	var wall_dir := int(spec["wall_dir"])
	var wall_along := float(spec["wall_along"])
	var spawn_type := int(spec["type"])
	# A blackout mutation may have opened the planned wall since planning;
	# re-resolve against the current topology and the furniture that actually
	# built. Prop themes can fall back to a non-blocking ceiling anomaly if a
	# mutation or authored set claims every wall position.
	if int(spec["type"]) in [PhotoAnomaly.Type.WRITING,
			PhotoAnomaly.Type.PRINT, PhotoAnomaly.Type.PORTAL] \
			and route != null:
		var spot := PhotoAnomaly.writing_spot_for_chunk(route, chunk.cell, chunk)
		if not spot.is_empty():
			wall_dir = int(spot["dir"])
			wall_along = float(spot["along"])
		else:
			# Every theme has a universal compact ceiling-photo fallback. This is
			# the final invariant: authored geometry may veto a wall, never the
			# evidence objective itself.
			spawn_type = PhotoAnomaly.Type.PLACEMENT
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
	node.configure(str(spec["id"]), spawn_type, chunk.cell,
		world_seed, theme, wall_dir, wall_along)
	_live[chunk.cell] = node
	if _documented.has(node.id):
		node.resolve(true)


func _register_photo_doors() -> void:
	if route == null or route.topology == null or not is_instance_valid(_chunk_manager):
		return
	for record in route.topology.photo_doorways():
		var at: Vector2i = record["cell"]
		var dir := DescentTopology.edge_dir(record)
		var other: Vector2i = at + WorldGen.DIRV[dir]
		var id := str(record["id"])
		var opened := route.topology.photo_door_open(id)
		var complete := true
		var chunks: Array[Chunk] = []
		var instances := PackedInt64Array()
		for endpoint in [at, other]:
			for member in WorldGen.owning_room_members(world_seed, endpoint, theme):
				var part := _chunk_manager.chunk_at(member)
				if part == null:
					complete = false
				elif not chunks.has(part):
					chunks.append(part)
					instances.append(part.get_instance_id())
		var ready := false
		if complete and not opened:
			var cached: Dictionary = _door_ready_cache.get(id, {})
			if cached.get("instances", PackedInt64Array()) == instances:
				ready = bool(cached["ready"])
			else:
				ready = _photo_door_approach_clear(record, chunks)
				_door_ready_cache[id] = {"instances": instances, "ready": ready}
		if bool(record.get("realm", false)) and not realm_preview_ready:
			ready = false
		for endpoint in [at, other]:
			var chunk := _chunk_manager.chunk_at(endpoint)
			if chunk == null:
				continue
			for seal in chunk.photo_door_seals():
				if seal.photo_id != id:
					continue
				if opened:
					seal.open()
					continue
				seal.set_preview_ready(ready)
				var live_key := "%s:%s" % [id, endpoint]
				if not ready or _documented.has(id):
					if _live_doors.has(live_key) and is_instance_valid(_live_doors[live_key]):
						(_live_doors[live_key] as Node).queue_free()
					_live_doors.erase(live_key)
					continue
				if _live_doors.has(live_key) and is_instance_valid(_live_doors[live_key]):
					continue
				var anomaly := PhotoAnomaly.new()
				chunk.add_child(anomaly)
				anomaly.configure_doorway(seal, endpoint,
					_resolve_photo_door.bind(id, endpoint, route))
				if bool(record.get("realm", false)) and not realm_destination.is_empty():
					anomaly.configure_realm_destination(realm_destination, seal)
				_live_doors[live_key] = anomaly


## A second structural barrier or authored prop can veto a candidate. Only
## expose the lens opening when both complete rooms prove a capsule-wide lane.
## The normal evidence plan is untouched, so a rejected site cannot gate a floor.
func _photo_door_approach_clear(record: Dictionary, chunks: Array[Chunk]) -> bool:
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var d: Vector2i = WorldGen.DIRV[dir]
	var forward := Vector3(d.x, 0.0, d.y)
	var along := float(record["t"])
	var centre := Vector3(at.x * WorldGen.CELL_SIZE \
		+ (WorldGen.CELL_SIZE if dir == 0 else along),
		Chunk.cell_floor_h(world_seed, at, theme),
		at.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 2 else along))
	var intro := bool(record.get("intro", false)) or bool(record.get("obstruction", false)) or bool(record.get("realm", false))
	var extent := forward.abs() * (6.4 if intro else 2.92) \
		+ Vector3(absf(forward.z), 0.0, absf(forward.x)) * (1.45 if intro else 0.72)
	var passage := AABB(centre - extent + Vector3.UP * 0.03,
		extent * 2.0 + Vector3.UP * (2.32 if intro else 1.77))
	for chunk in chunks:
		if _photo_passage_obstructed(chunk, Transform3D.IDENTITY, passage):
			return false
	return true


## Check the whole swept lane, including nested imported solids and convex
## shapes. Point samples against only Chunk.body can miss a thin partition or
## a collider parented under a prop. Conservative world bounds fail closed.
func _photo_passage_obstructed(node: Node, parent: Transform3D, passage: AABB) -> bool:
	if node is PhotoDoorSeal or node is Area3D:
		return false
	if node is CollisionObject3D and ((node as CollisionObject3D).collision_layer & 1) == 0:
		return false
	var transform := parent
	if node is Node3D:
		transform = parent * (node as Node3D).transform
	if node is CollisionShape3D:
		var shape := node as CollisionShape3D
		if not shape.disabled and shape.shape != null:
			var bounds := transform * shape.shape.get_debug_mesh().get_aabb()
			if passage.intersects(bounds):
				return true
	for child in node.get_children():
		if _photo_passage_obstructed(child, transform, passage):
			return true
	return false


func _resolve_photo_door(id: String, witness_cell: Vector2i,
		expected_route: DescentRoute) -> void:
	if route == null or route != expected_route or route.topology == null \
			or not _documented.has(id) \
			or not is_instance_valid(_chunk_manager) \
			or not route.topology.open_photo_door(id):
		return
	# Every live half opens in this same frame. Pending or unloaded chunks
	# reconcile against the same resolver when installed; no rebuild is needed.
	_register_photo_doors()
	route.refresh_topology()
	var witness := _chunk_manager.chunk_at(witness_cell)
	if witness == null:
		return
	for seal in witness.photo_door_seals():
		if seal.photo_id != id:
			continue
		var effect := MutationRevealEffect.new()
		_chunk_manager.add_child(effect)
		effect.configure(seal.reveal_descriptor())
		break


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
