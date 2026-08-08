class_name DescentTopology
extends RefCounted
## Floor-scoped reality resolver layered over deterministic WorldGen geometry.
##
## WorldGen remains pure so seeds and Wander never change.  Descent generates a
## small graph of complete, prevalidated realities when the floor route is
## created.  A blackout may move between those realities, but it never invents
## geometry at runtime.  Rendering, collision, guidance, streaming and hostile
## routing all query this one resolver.

const SHORTCUT_WIDTH := 3.2
const DOOR_WIDTH := 1.8
const SHORTCUT_CENTRE := 6.0
const MUTATION_STATE_TARGET := 7 # base reality plus six alternatives
## Bump whenever candidate generation or state meaning changes. Saves resolve a
## stable signature inside this generation instead of trusting numeric order.
const GENERATION_VERSION := 2
const MUTATION_SEARCH_RADIUS := 3
## Match the resident streaming radius: a blackout may not spend work on a
## change outside the rooms currently present around the player.
const MUTATION_REVEAL_RADIUS := 3
const OPPOSITE := [1, 0, 3, 2]

var world_seed := 1
var theme := 0

## Compatibility overlay used by focused tools and old callers.  Generated
## blackout realities live in `_states`; this manual layer remains useful for
## isolated geometry probes and is applied only when a state has no opinion.
var _shortcuts := {}

## State 0 is always the seed-authored base.  Every later state is a complete
## snapshot, never a delta from the previous state, which makes arbitrary
## transitions and exact mutation-back safe.
var _states: Array[TopologyState] = []
var _current_state := 0
var _previous_state := -1
var _visited_states := {0: true}
var _planned := false
var _furniture_probe_cache := {}
var _furniture_probe_count := 0
var _cell_allowed_cache := {}
var _room_members_cache := {}
var _mutation_cell_safe_cache := {}
static var _plan_cache := {}


func _init(p_world_seed := 1, p_theme := 0) -> void:
	world_seed = p_world_seed
	theme = p_theme
	_reset_states()


## Mirrors WorldGen's canonical shared-edge convention without exposing its
## private hash helper: east/west share axis 0, south/north share axis 1.
static func canonical_edge(cell: Vector2i, dir: int) -> Dictionary:
	match dir:
		0:
			return {"cell": cell, "axis": 0}
		1:
			return {"cell": cell + Vector2i(-1, 0), "axis": 0}
		2:
			return {"cell": cell, "axis": 1}
		3:
			return {"cell": cell + Vector2i(0, -1), "axis": 1}
	return {"cell": cell, "axis": 0}


static func edge_key(cell: Vector2i, dir: int) -> String:
	var edge := canonical_edge(cell, dir)
	var root: Vector2i = edge["cell"]
	return "%d:%d:%d" % [root.x, root.y, int(edge["axis"])]


static func edge_dir(edge: Dictionary) -> int:
	return 0 if int(edge.get("axis", 0)) == 0 else 2


func _reset_states() -> void:
	_states = [TopologyState.new()]
	_current_state = 0
	_previous_state = -1
	_visited_states = {0: true}
	_furniture_probe_cache.clear()
	_furniture_probe_count = 0
	_cell_allowed_cache.clear()
	_room_members_cache.clear()
	_mutation_cell_safe_cache.clear()
	_planned = false


## Generate every reality up front. Candidate closures are admitted only when
## the exact edge-cut proof shows that the removed edge's endpoints still
## connect in the completed state. Because the seed graph is connected and the
## state only adds edges plus this closure, that proves every originally
## reachable cell remains connected wherever the player later sees the change.
func plan_floor(route: DescentRoute) -> void:
	_reset_states()
	if route == null or route.world_seed != world_seed or route.theme != theme:
		return
	var cache_key := "%d:%d:%d:%d:%d:%d" % [GENERATION_VERSION,
		world_seed, theme, route.floor_idx, route.origin.x * 4099 + route.origin.y,
		route.target.x * 4099 + route.target.y]
	if _plan_cache.has(cache_key):
		for cached in _plan_cache[cache_key]:
			_states.append(TopologyState.from_dictionary(cached))
		_states.pop_front() # replace the reset base with the cached base
		_planned = true
		return
	var path := route.path_from_origin()
	if path.size() < 8:
		_planned = true
		return
	var protected := _protected_cells(route)
	var signatures := {_state_signature(_states[0]): true}
	var wanted := MUTATION_STATE_TARGET - 1
	for slot in wanted:
		var path_idx := clampi(roundi(float(slot + 1) \
			/ float(wanted + 1) * float(path.size() - 1)), 2, path.size() - 3)
		var centre: Vector2i = path[path_idx]
		var edges := {}
		var opening := _pick_opening(route, centre, protected, slot)
		if not opening.is_empty():
			edges[str(opening["key"])] = opening
		# Half the realities carry a hard closure. The alternating opening-only
		# states preserve strong precomputed mercy routes instead of letting an
		# unrelated closure cancel the shortcut they were generated to provide.
		if posmod(slot, 2) == 1:
			var closure := _pick_safe_closure(
				route, centre, protected, slot, edges)
			if not closure.is_empty():
				edges[str(closure["key"])] = closure
		var rooms := {}
		var furniture_variant := 1 + posmod(slot, 3)
		var room := _pick_furniture_room(
			route, centre, protected, slot, furniture_variant)
		if room != Vector2i(1 << 30, 1 << 30):
			rooms[room] = furniture_variant
		# A topology state should carry architecture whenever the seed offers a
		# safe candidate.  Furniture-only fallback states are still worthwhile
		# on unusually tree-like local layouts where no edge can toggle.
		if edges.is_empty() and rooms.is_empty():
			continue
		if not _state_reaches_all(route, edges):
			continue
		var state := TopologyState.new(_states.size(),
			"reality_%02d" % _states.size(), edges, rooms)
		var signature := _state_signature(state)
		if signatures.has(signature):
			continue
		signatures[signature] = true
		_states.append(state)
	_planned = true
	_plan_cache[cache_key] = states()
	# A run needs at most eleven entries. Keep a little headroom for restarting
	# or profiling without allowing an endless seed cache in development tools.
	if _plan_cache.size() > 24:
		_plan_cache.erase(_plan_cache.keys()[0])


func is_planned() -> bool:
	return _planned


func furniture_probe_count() -> int:
	return _furniture_probe_count


func state_count() -> int:
	return _states.size()


func current_state_id() -> int:
	return _current_state


func state_history() -> Array[int]:
	var out: Array[int] = []
	for value in _visited_states.keys():
		out.append(int(value))
	out.sort()
	return out


func state_signature(state_id: int = -1) -> String:
	var idx := _current_state if state_id < 0 else state_id
	if idx < 0 or idx >= _states.size():
		return ""
	return _state_signature(_states[idx])


func state_id_for_signature(signature: String) -> int:
	if signature.is_empty():
		return 0
	for idx in _states.size():
		if _state_signature(_states[idx]) == signature:
			return idx
	return -1


## Restore persisted identities without ever reinterpreting an old numeric id.
## An unknown current signature falls back to base; unknown history is ignored.
func restore_signatures(current_signature: String,
		visited_signatures: Array[String] = []) -> bool:
	var state_id := state_id_for_signature(current_signature)
	if state_id < 0:
		restore_state(0)
		return false
	var visited: Array[int] = []
	for signature in visited_signatures:
		var visited_id := state_id_for_signature(signature)
		if visited_id >= 0 and not visited.has(visited_id):
			visited.append(visited_id)
	restore_state(state_id, visited)
	return true


func states() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for state in _states:
		out.append(state.to_dictionary())
	return out


func restore_state(state_id: int, visited: Array[int] = []) -> void:
	_current_state = clampi(state_id, 0, maxi(0, _states.size() - 1))
	_previous_state = -1
	_visited_states = {0: true, _current_state: true}
	for value in visited:
		var idx := int(value)
		if idx >= 0 and idx < _states.size():
			_visited_states[idx] = true


func transition_to(state_id: int) -> bool:
	if state_id < 0 or state_id >= _states.size() or state_id == _current_state:
		return false
	_previous_state = _current_state
	_current_state = state_id
	_visited_states[state_id] = true
	return true


func furniture_variant(room_root: Vector2i) -> int:
	var rooms: Dictionary = _states[_current_state].rooms
	return int(rooms.get(room_root, 0))


func furniture_variant_for_state(room_root: Vector2i, state_id: int) -> int:
	if state_id < 0 or state_id >= _states.size():
		return furniture_variant(room_root)
	var rooms: Dictionary = _states[state_id].rooms
	return int(rooms.get(room_root, 0))


func has_shortcut(cell: Vector2i, dir: int) -> bool:
	var key := edge_key(cell, dir)
	var override := _current_edges().get(key, {}) as Dictionary
	if not override.is_empty():
		return str(override.get("kind", "")) != "wall"
	return _shortcuts.has(key)


func add_shortcut(cell: Vector2i, dir: int) -> bool:
	if dir < 0 or dir >= 4 or has_shortcut(cell, dir) \
			or not WorldGen.is_wall(world_seed, cell, dir, theme):
		return false
	var edge := canonical_edge(cell, dir)
	var key := edge_key(cell, dir)
	_shortcuts[key] = _opening_record(edge, false)
	return true


func edge_info(cell: Vector2i, dir: int) -> Dictionary:
	return _edge_info_with(_current_edges(), cell, dir)


func edge_info_for_state(cell: Vector2i, dir: int, state_id: int) -> Dictionary:
	if state_id < 0 or state_id >= _states.size():
		return WorldGen.edge_info(world_seed, cell, dir, theme)
	return _edge_info_with(_states[state_id].edges, cell, dir)


func is_wall(cell: Vector2i, dir: int) -> bool:
	var key := edge_key(cell, dir)
	var record: Dictionary = _current_edges().get(key, {})
	if record.is_empty():
		record = _shortcuts.get(key, {})
	if record.is_empty():
		return WorldGen.is_wall(world_seed, cell, dir, theme)
	return str(record.get("kind", "open")) == "wall"


func shortcut_count() -> int:
	var count := _shortcuts.size()
	for value in _current_edges().values():
		if str((value as Dictionary).get("kind", "")) != "wall":
			count += 1
	return count


func shortcuts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value in _shortcuts.values():
		out.append((value as Dictionary).duplicate())
	for value in _current_edges().values():
		var record := value as Dictionary
		if str(record.get("kind", "")) != "wall":
			out.append(record.duplicate())
	return out


func state_delta(from_state: int, to_state: int) -> TopologyDelta:
	if from_state < 0 or from_state >= _states.size() \
			or to_state < 0 or to_state >= _states.size():
		return null
	var before_edges: Dictionary = _states[from_state].edges
	var after_edges: Dictionary = _states[to_state].edges
	var edge_keys := {}
	for key in before_edges:
		edge_keys[key] = true
	for key in after_edges:
		edge_keys[key] = true
	var changed_edges: Array[Dictionary] = []
	var cells := {}
	for key in edge_keys:
		var before: Dictionary = before_edges.get(key, {})
		var after: Dictionary = after_edges.get(key, {})
		if _record_signature(before) == _record_signature(after):
			continue
		var record := after if not after.is_empty() else _base_record_from_key(str(key))
		var edge_cell: Vector2i = record["cell"]
		var dir := edge_dir(record)
		var other: Vector2i = edge_cell + WorldGen.DIRV[dir]
		changed_edges.append({
			"key": str(key),
			"cell": edge_cell,
			"dir": dir,
			"other": other,
			"before": before.duplicate(true),
			"after": after.duplicate(true),
		})
		cells[edge_cell] = true
		cells[other] = true
	var before_rooms: Dictionary = _states[from_state].rooms
	var after_rooms: Dictionary = _states[to_state].rooms
	var room_keys := {}
	for key in before_rooms:
		room_keys[key] = true
	for key in after_rooms:
		room_keys[key] = true
	var changed_rooms: Array[Vector2i] = []
	for key in room_keys:
		var room: Vector2i = key
		if int(before_rooms.get(room, 0)) == int(after_rooms.get(room, 0)):
			continue
		changed_rooms.append(room)
		cells[room] = true
	var changed_cells: Array[Vector2i] = []
	for value in cells.keys():
		changed_cells.append(value as Vector2i)
	return TopologyDelta.new(from_state, to_state, changed_edges,
		changed_rooms, changed_cells)


## Select an already-generated reality whose visible delta is close to a room
## the player has visited.  A mercy transition must shorten the live route;
## ordinary transitions prefer an unvisited reality and avoid immediate
## ping-pong, but previously visited states remain eligible so architecture can
## eventually mutate back exactly.
func find_transition(route: DescentRoute, from: Vector2i,
		visited: Dictionary, require_help: bool) -> TopologyDelta:
	if not _planned or _states.size() <= 1 or route == null \
			or not route.contains(from):
		return null
	var before := route.distance_from_target(from)
	var candidates: Array[TopologyDelta] = []
	for state_id in _states.size():
		if state_id == _current_state:
			continue
		var delta := state_delta(_current_state, state_id)
		if delta == null or delta.is_empty():
			continue
		var nearest := 1 << 20
		var visible := false
		var touches_player := false
		for at in delta.cells:
			if at == from:
				touches_player = true
			var span := (at - from).abs()
			nearest = mini(nearest, maxi(span.x, span.y))
			if visited.has(at):
				visible = true
		if touches_player or nearest > MUTATION_REVEAL_RADIUS or not visible:
			continue
		var after := distance_to_target_for_state(route, from, state_id)
		if after < 0 or (require_help and after >= before):
			continue
		var saving := before - after
		var unvisited_bonus := 300.0 if not _visited_states.has(state_id) else 0.0
		var previous_penalty := 180.0 if state_id == _previous_state else 0.0
		var tie := float(WorldGen.h(world_seed, state_id, from.x,
			from.y + theme * 101)) / 2147483647.0
		var score := unvisited_bonus - float(nearest) * 100.0 \
			- previous_penalty + float(saving) * (30.0 if require_help else 3.0) \
			- tie
		delta.distance_before = before
		delta.distance_after = after
		delta.saving = saving
		delta.assistance = require_help
		delta.nearest = nearest
		delta.score = score
		candidates.append(delta)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: TopologyDelta, b: TopologyDelta):
		return a.score > b.score)
	return candidates[0]


func distance_to_target_for_state(route: DescentRoute, from: Vector2i,
		state_id: int) -> int:
	if route == null or not route.scanned_contains(from):
		return -1
	var distance := {route.target: 0}
	var queue: Array[Vector2i] = [route.target]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		if at == from:
			return int(distance[at])
		for dir in 4:
			var state_edges: Dictionary = _states[state_id].edges \
				if state_id >= 0 and state_id < _states.size() else {}
			if _is_wall_for_route(route, state_edges, at, dir):
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if distance.has(other) or not route.scanned_contains(other):
				continue
			distance[other] = int(distance[at]) + 1
			queue.append(other)
	return -1


func _current_edges() -> Dictionary:
	return _states[_current_state].edges


func _edge_info_with(edges: Dictionary, cell: Vector2i, dir: int) -> Dictionary:
	var key := edge_key(cell, dir)
	var record: Dictionary = edges.get(key, {})
	if record.is_empty():
		record = _shortcuts.get(key, {})
	if record.is_empty():
		return WorldGen.edge_info(world_seed, cell, dir, theme)
	if str(record.get("kind", "open")) == "wall":
		return {
			"wall": true,
			"full_open": false,
			"t": SHORTCUT_CENTRE,
			"w": 0.0,
			"exit_sign": false,
			"runtime_seal": true,
			"mutation_state": _current_state,
		}
	return {
		"wall": false,
		"full_open": false,
		"t": float(record.get("t", SHORTCUT_CENTRE)),
		"w": float(record.get("w", SHORTCUT_WIDTH)),
		"exit_sign": false,
		"runtime_shortcut": true,
		"runtime_door": bool(record.get("door", false)),
		"mutation_state": _current_state,
	}


func _opening_record(edge: Dictionary, door: bool) -> Dictionary:
	var root: Vector2i = edge["cell"]
	var axis := int(edge["axis"])
	return {
		"key": "%d:%d:%d" % [root.x, root.y, axis],
		"cell": root,
		"axis": axis,
		"kind": "open",
		"door": door,
		"t": SHORTCUT_CENTRE,
		"w": DOOR_WIDTH if door else SHORTCUT_WIDTH,
	}


func _closure_record(edge: Dictionary) -> Dictionary:
	var root: Vector2i = edge["cell"]
	var axis := int(edge["axis"])
	return {
		"key": "%d:%d:%d" % [root.x, root.y, axis],
		"cell": root,
		"axis": axis,
		"kind": "wall",
	}


func _base_record_from_key(key: String) -> Dictionary:
	var parts := key.split(":")
	var root := Vector2i(int(parts[0]), int(parts[1]))
	return {
		"key": key,
		"cell": root,
		"axis": int(parts[2]),
		"kind": "base",
	}


func _protected_cells(route: DescentRoute) -> Dictionary:
	var protected := {
		route.origin: true,
		route.target: true,
		route.objective_ritual_cell(): true,
	}
	for at in route.optional_vhs_cells():
		protected[at] = true
	return protected


func _cell_allowed(route: DescentRoute, at: Vector2i,
		protected: Dictionary) -> bool:
	if _cell_allowed_cache.has(at):
		return bool(_cell_allowed_cache[at])
	if not route.scanned_contains(at):
		_cell_allowed_cache[at] = false
		return false
	# Rebuilding one member rebuilds the furnishing owner for the complete room.
	# Protect the whole owning room whenever any member contains mandatory or
	# stateful content, not merely the edge endpoint selected by the planner.
	for member in _owning_room_members(at):
		if protected.has(member) \
				or WorldGen.portal(world_seed, member, theme) >= 0 \
				or WorldGen.elevator_cell(world_seed, member, theme) \
				or (posmod(member.x, 3) == 1 and posmod(member.y, 3) == 1):
			_cell_allowed_cache[at] = false
			return false
	_cell_allowed_cache[at] = true
	return true


func _owning_room_members(at: Vector2i) -> Array[Vector2i]:
	if _room_members_cache.has(at):
		return (_room_members_cache[at] as Array).duplicate()
	var out := WorldGen.owning_room_members(world_seed, at, theme)
	_room_members_cache[at] = out.duplicate()
	return out


func _mutation_cell_safe(route: DescentRoute, at: Vector2i,
		protected: Dictionary, optional_cells: Array[Vector2i]) -> bool:
	if _mutation_cell_safe_cache.has(at):
		return bool(_mutation_cell_safe_cache[at])
	var safe := _cell_allowed(route, at, protected) \
		and route._blackout_cell_ok(at, Vector2i(1 << 30, 1 << 30),
			optional_cells, true, true)
	_mutation_cell_safe_cache[at] = safe
	return safe


func _nearby_cells(route: DescentRoute, centre: Vector2i,
		protected: Dictionary, radius := MUTATION_SEARCH_RADIUS) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var at := centre + Vector2i(dx, dz)
			if _cell_allowed(route, at, protected):
				out.append(at)
	out.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := maxi(absi(a.x - centre.x), absi(a.y - centre.y))
		var db := maxi(absi(b.x - centre.x), absi(b.y - centre.y))
		if da != db:
			return da < db
		return WorldGen.h(world_seed, a.x, a.y, 8039) \
			< WorldGen.h(world_seed, b.x, b.y, 8039))
	return out


func _pick_opening(route: DescentRoute, centre: Vector2i,
		protected: Dictionary, slot: int) -> Dictionary:
	var options: Array[Dictionary] = []
	var seen := {}
	var optional_cells := route.optional_vhs_cells()
	for at in _nearby_cells(
			route, centre, protected, MUTATION_SEARCH_RADIUS + 2):
		for dir in 4:
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if not _mutation_cell_safe(route, at, protected, optional_cells) \
					or not _mutation_cell_safe(
						route, other, protected, optional_cells) \
					or not WorldGen.is_wall(world_seed, at, dir, theme) \
					or not is_equal_approx(Chunk.cell_floor_h(world_seed, at, theme),
						Chunk.cell_floor_h(world_seed, other, theme)):
				continue
			var edge := canonical_edge(at, dir)
			var key := edge_key(at, dir)
			if seen.has(key):
				continue
			seen[key] = true
			var record := _opening_record(edge, posmod(slot, 2) == 1)
			var canonical_dir := edge_dir(record)
			var root: Vector2i = record["cell"]
			var far: Vector2i = root + WorldGen.DIRV[canonical_dir]
			record["gain"] = absi(route.distance_from_target(root) \
				- route.distance_from_target(far)) - 1
			options.append(record)
	if options.is_empty():
		return {}
	options.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("gain", 0)) != int(b.get("gain", 0)):
			return int(a.get("gain", 0)) > int(b.get("gain", 0))
		return WorldGen.h(world_seed, int((a["cell"] as Vector2i).x),
			int((a["cell"] as Vector2i).y), 8111 + slot * 97 + int(a["axis"])) \
			< WorldGen.h(world_seed, int((b["cell"] as Vector2i).x),
				int((b["cell"] as Vector2i).y), 8111 + slot * 97 + int(b["axis"])))
	return options[0]


func _pick_safe_closure(route: DescentRoute, centre: Vector2i,
		protected: Dictionary, slot: int, existing: Dictionary) -> Dictionary:
	var options: Array[Dictionary] = []
	var seen := {}
	var optional_cells := route.optional_vhs_cells()
	for at in _nearby_cells(route, centre, protected, MUTATION_SEARCH_RADIUS + 1):
		for dir in 4:
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if not _mutation_cell_safe(route, at, protected, optional_cells) \
					or not _mutation_cell_safe(route, other, protected, optional_cells) \
					or not is_equal_approx(Chunk.cell_floor_h(world_seed, at, theme),
						Chunk.cell_floor_h(world_seed, other, theme)):
				continue
			var base := WorldGen.edge_info(world_seed, at, dir, theme)
			if bool(base["wall"]) or bool(base["full_open"]):
				continue
			var edge := canonical_edge(at, dir)
			var key := edge_key(at, dir)
			if seen.has(key) or existing.has(key):
				continue
			seen[key] = true
			options.append(_closure_record(edge))
	options.sort_custom(func(a: Dictionary, b: Dictionary):
		return WorldGen.h(world_seed, int((a["cell"] as Vector2i).x),
			int((a["cell"] as Vector2i).y), 8231 + slot * 113 + int(a["axis"])) \
			< WorldGen.h(world_seed, int((b["cell"] as Vector2i).x),
				int((b["cell"] as Vector2i).y), 8231 + slot * 113 + int(b["axis"])))
	for closure in options:
		var proposed := existing.duplicate(true)
		proposed[str(closure["key"])] = closure
		if _state_reaches_all(route, proposed):
			return closure
	return {}


func _pick_furniture_room(route: DescentRoute, centre: Vector2i,
		protected: Dictionary, slot: int, variant: int) -> Vector2i:
	var sentinel := Vector2i(1 << 30, 1 << 30)
	var options: Array[Vector2i] = []
	var seen := {}
	for at in _nearby_cells(route, centre, protected):
		var corridor := WorldGen.annex_corridor_axis(world_seed, at) != 0 \
			if theme == 2 else WorldGen.corridor(world_seed, at) != 0
		if corridor:
			continue
		var root := WorldGen.annex_room_id(world_seed, at) if theme == 2 \
			else WorldGen.room_id(world_seed, at)
		if seen.has(root) or protected.has(root) \
				or not _cell_allowed(route, root, protected):
			continue
		seen[root] = true
		options.append(root)
	if options.is_empty():
		return sentinel
	options.sort_custom(func(a: Vector2i, b: Vector2i):
		var ap := _furniture_style_priority(
			WorldGen.cell_style(world_seed, a, theme))
		var bp := _furniture_style_priority(
			WorldGen.cell_style(world_seed, b, theme))
		if ap != bp:
			return ap < bp
		return WorldGen.h(world_seed, a.x, a.y, 8353 + slot * 127) \
			< WorldGen.h(world_seed, b.x, b.y, 8353 + slot * 127))
	# The pure supported-style model excludes layouts whose doorway cull may
	# consume every movable group. Real reconstruction remains audit-covered.
	for room in options:
		if _furniture_variant_is_viable(room, variant):
			return room
	return sentinel


func _furniture_variant_is_viable(room: Vector2i, variant: int) -> bool:
	# Builders opt their floor-supported, atomic furniture into one shared
	# clearance contract. The supported-style table is the pure planning model;
	# the mutation graph audit reconstructs every selected state as a real Chunk
	# and remains the geometry backstop without blocking production floor setup.
	return variant > 0 and _furniture_style_priority(
		WorldGen.cell_style(world_seed, room, theme)) <= 1


## Pure furniture-capability model shared by planning. Priority 0 layouts have
## reliably movable atomic groups; priority 1 are sparse fallbacks.
func _furniture_style_priority(style: int) -> int:
	if style in [
		WorldGen.STYLE_SLOTS,
		WorldGen.OFFICE_BOARDROOM,
		WorldGen.ANNEX_OPEN,
		WorldGen.AIR_GATE, WorldGen.AIR_BAGGAGE, WorldGen.AIR_FOODCOURT,
		WorldGen.ASY_DAYROOM, WorldGen.ASY_CHAPEL,
		WorldGen.SCH_CLASSROOM, WorldGen.SCH_CAFETERIA,
		WorldGen.SCH_LIBRARY, WorldGen.SCH_LAB,
		WorldGen.MALL_STORE, WorldGen.MALL_FOODCOURT,
		WorldGen.MALL_KIOSKS, WorldGen.MALL_CINEMA,
		WorldGen.PRISON_CELLS, WorldGen.PRISON_MESS,
		WorldGen.PRISON_GUARD,
		WorldGen.PRISON_VISITATION,
		WorldGen.POOL_SOLARIUM,
		WorldGen.BRUTAL_SERVICE, WorldGen.BLOOM_CLASSROOM,
	]:
		return 0
	if style in [
		WorldGen.STYLE_PILLARS, WorldGen.STYLE_GRAND,
		WorldGen.STYLE_BALLROOM, WorldGen.OFFICE_STORAGE,
		WorldGen.ANNEX_QUIET, WorldGen.AIR_CHECKIN,
		WorldGen.ASY_HYDRO, WorldGen.SCH_AUDITORIUM,
		WorldGen.MALL_ATRIUM, WorldGen.PRISON_ROTUNDA,
		WorldGen.POOL_DECK, WorldGen.POOL_ALCOVE,
		WorldGen.BLOOM_INCUBATOR, WorldGen.BLOOM_COMMONS,
	]:
		return 1
	return 10


func _state_reaches_all(route: DescentRoute, edges: Dictionary) -> bool:
	# The seed-authored route graph is connected and a generated reality only
	# adds openings plus (currently) one hard closure. Adding an edge cannot
	# disconnect the graph. Removing an edge preserves global connectivity iff
	# that edge's two endpoints remain connected after removal. Checking the
	# cut endpoints is therefore an exact proof, while avoiding a full-map flood
	# for every candidate and every completed state.
	for value in edges.values():
		var closure := value as Dictionary
		if str(closure.get("kind", "")) != "wall":
			continue
		var start: Vector2i = closure["cell"]
		var dir := edge_dir(closure)
		var target: Vector2i = start + WorldGen.DIRV[dir]
		if not _state_connects(route, edges, start, target):
			return false
	return true


func _state_connects(route: DescentRoute, edges: Dictionary,
		start: Vector2i, target: Vector2i) -> bool:
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for dir in 4:
			if _is_wall_for_route(route, edges, at, dir):
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if other == target:
				return true
			if reached.has(other) or not route.scanned_contains(other):
				continue
			reached[other] = true
			queue.append(other)
	return false


func _is_wall_with(edges: Dictionary, cell: Vector2i, dir: int) -> bool:
	var key := edge_key(cell, dir)
	var record: Dictionary = edges.get(key, {})
	if record.is_empty():
		record = _shortcuts.get(key, {})
	if record.is_empty():
		return WorldGen.is_wall(world_seed, cell, dir, theme)
	return str(record.get("kind", "open")) == "wall"


func _is_wall_for_route(route: DescentRoute, edges: Dictionary,
		cell: Vector2i, dir: int) -> bool:
	var key := edge_key(cell, dir)
	var record: Dictionary = edges.get(key, {})
	if record.is_empty():
		record = _shortcuts.get(key, {})
	if record.is_empty():
		return route.base_is_wall(cell, dir)
	return str(record.get("kind", "open")) == "wall"


func _state_signature(state: TopologyState) -> String:
	var parts: Array[String] = []
	var edges: Dictionary = state.edges
	var edge_keys: Array = edges.keys()
	edge_keys.sort()
	for key in edge_keys:
		parts.append("e:%s:%s" % [key, _record_signature(edges[key])])
	var rooms: Dictionary = state.rooms
	var room_keys: Array = rooms.keys()
	room_keys.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	for room in room_keys:
		parts.append("r:%d:%d:%d" % [room.x, room.y, int(rooms[room])])
	return "|".join(parts)


func _record_signature(record: Dictionary) -> String:
	if record.is_empty():
		return "base"
	return "%s:%d" % [str(record.get("kind", "open")),
		1 if bool(record.get("door", false)) else 0]
