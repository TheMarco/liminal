extends SceneTree
## Contract for generated blackout realities. Every state is planned before
## play, remains fully connected, renders reciprocal hard edge changes, keeps
## furniture clear, survives reconstruction, and can return exactly to base.
##
## Run:
##   godot --headless --path . --script tools/audit_descent_mutation_graph.gd
##   godot --headless --path . --script tools/audit_descent_mutation_graph.gd -- --theme=0

const BASE_SEED := 20260807
const OPPOSITE := [1, 0, 3, 2]

var failures: Array[String] = []
var state_total := 0
var opening_total := 0
var closure_total := 0
var door_total := 0
var furniture_total := 0
var slowest_plan_msec := 0
var most_plan_probes := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _run() -> void:
	var selected_theme := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			selected_theme = int(arg.trim_prefix("--theme="))
	var themes: Array[int] = []
	for theme in DescentRun.FIXED_ORDER:
		if selected_theme < 0 or selected_theme == theme:
			themes.append(theme)
	for theme in themes:
		_audit_theme(theme)
	Chunk.clear_runtime_caches()
	SoundBank._c.clear()
	Sfx._c.clear()
	Mats.clear_runtime_caches()
	VhsRitual.clear_runtime_cache()
	await process_frame
	await physics_frame
	await create_timer(0.1).timeout
	for failure in failures:
		print("  FAIL " + failure)
	print("mutation graph audit: %d themes, %d alternate states, %d openings (%d doors), %d closures, %d furniture variants; slowest plan %dms/%d probes" % [
		themes.size(), state_total, opening_total, door_total,
		closure_total, furniture_total, slowest_plan_msec, most_plan_probes])
	if failures.is_empty():
		print("  PASS — generated realities are connected, reversible and reconstructable")
		quit()
	else:
		quit(1)


func _audit_theme(theme: int) -> void:
	var floor_idx := DescentRun.FIXED_ORDER.find(theme)
	var ws := WorldGen.level_seed(BASE_SEED + theme * 7919, theme)
	var route := DescentRoute.build(ws, theme, floor_idx)
	var topology := DescentTopology.new(ws, theme)
	route.set_topology(topology)
	var plan_started := Time.get_ticks_msec()
	topology.plan_floor(route)
	slowest_plan_msec = maxi(slowest_plan_msec,
		Time.get_ticks_msec() - plan_started)
	most_plan_probes = maxi(most_plan_probes, topology.furniture_probe_count())
	route.refresh_topology()
	var states := topology.states()
	_expect(states.size() >= 3,
		"theme %d generated fewer than two alternate realities" % theme)
	var base_path := route.path_from_origin()
	var base_distance := route.distance_from_target(route.origin)
	var saw_closure := false
	var saw_opening := false
	var saw_furniture := false
	for state_id in range(1, states.size()):
		state_total += 1
		topology.restore_state(state_id)
		route.refresh_topology()
		_expect(route.distance_from_target(route.origin) >= 0,
			"theme %d state %d disconnected origin" % [theme, state_id])
		for critical in [route.origin, route.target, route.objective_ritual_cell()]:
			_expect(route.distance_from_target(critical) >= 0,
				"theme %d state %d disconnected critical %s" % [
					theme, state_id, critical])
		for optional in route.optional_vhs_cells():
			_expect(route.distance_from_target(optional) >= 0,
				"theme %d state %d disconnected VCR %s" % [
					theme, state_id, optional])
		var delta := topology.state_delta(0, state_id)
		for change in delta.edges:
			var at: Vector2i = change["cell"]
			var dir := int(change["dir"])
			var other: Vector2i = change["other"]
			var forward := topology.edge_info(at, dir)
			var reverse := topology.edge_info(other, OPPOSITE[dir])
			_expect(bool(forward["wall"]) == bool(reverse["wall"]),
				"theme %d state %d asymmetric edge %s/%d" % [
					theme, state_id, at, dir])
			if bool(forward.get("runtime_seal", false)):
				saw_closure = true
				closure_total += 1
				_audit_edge_geometry(route, topology, at, dir, true)
			else:
				saw_opening = true
				opening_total += 1
				if bool(forward.get("runtime_door", false)):
					door_total += 1
				_audit_edge_geometry(route, topology, at, dir, false)
		for room in delta.rooms:
			saw_furniture = true
			furniture_total += 1
			var chunk := Chunk.new(ws, room, theme, {
				"descent": true,
				"topology": topology,
			})
			_expect(chunk.mutation_furniture_variant > 0,
				"theme %d state %d room %s lost its variant" % [
					theme, state_id, room])
			_expect(chunk.mutation_furniture_changed_groups > 0,
				"theme %d state %d room %s style %d changed no furniture" % [
					theme, state_id, room,
					WorldGen.cell_style(ws, room, theme)])
			_expect(chunk.mutation_furniture_clearance_violations() == 0,
				"theme %d state %d room %s furniture is unsafe" % [
					theme, state_id, room])
			_expect(chunk.doorway_clearance_violations() == 0,
				"theme %d state %d room %s blocks a doorway" % [
					theme, state_id, room])
			chunk.free()
	# At least one hard edge and one furniture reality per generated floor; an
	# opening is expected too because it is the mercy system's escape valve.
	_expect(saw_opening, "theme %d generated no opening reality" % theme)
	_expect(saw_closure, "theme %d generated no hard closure reality" % theme)
	_expect(saw_furniture, "theme %d generated no furniture reality" % theme)
	# The runtime selector must be able to find both an ordinary transition and
	# a genuinely helpful precomputed state somewhere on the explored graph.
	topology.restore_state(0)
	route.refresh_topology()
	var all_visited := {}
	for key in route.scanned_cells():
		all_visited[key] = true
	var probes: Array[Vector2i] = []
	for state_id in range(1, states.size()):
		var state_delta := topology.state_delta(0, state_id)
		var affected := state_delta.cells
		for at in affected:
			for dir in 4:
				var probe: Vector2i = at + WorldGen.DIRV[dir]
				if route.scanned_contains(probe) \
						and not affected.has(probe) and not probes.has(probe):
					probes.append(probe)
	var ordinary: TopologyDelta = topology.find_transition(
		route, probes[0], all_visited, false) if not probes.is_empty() else null
	var helpful: TopologyDelta
	var helpful_from := Vector2i.ZERO
	# At most one BFS per generated state/probe cluster; route construction is
	# already the expensive part of this audit, so avoid a scan-cell-squared
	# search for a witness.
	for from in probes.slice(0, mini(40, probes.size())):
		var before_probe := route.distance_from_target(from)
		for state_id in range(1, states.size()):
			if topology.distance_to_target_for_state(
					route, from, state_id) >= before_probe:
				continue
			helpful = topology.find_transition(route, from, all_visited, true)
			if helpful != null and not helpful.is_empty():
				helpful_from = from
				break
		if helpful != null and not helpful.is_empty():
			break
	_expect(ordinary != null and not ordinary.is_empty(),
		"theme %d selector found no ordinary reality transition" % theme)
	_expect(helpful != null and not helpful.is_empty(),
		"theme %d selector found no mercy reality transition" % theme)
	if helpful != null and not helpful.is_empty():
		var before_help := route.distance_from_target(helpful_from)
		_expect(topology.transition_to(helpful.to_state),
			"theme %d refused selected mercy state" % theme)
		route.refresh_topology()
		_expect(route.distance_from_target(helpful_from) < before_help,
			"theme %d selected mercy state was not helpful" % theme)
	# Exact mutation-back: topology, distance and deterministic route return to
	# the seed-authored state rather than merely remaining traversable.
	topology.restore_state(0)
	route.refresh_topology()
	_expect(route.distance_from_target(route.origin) == base_distance,
		"theme %d base distance changed after reversal" % theme)
	_expect(route.path_from_origin() == base_path,
		"theme %d base route changed after reversal" % theme)


func _audit_edge_geometry(route: DescentRoute, topology: DescentTopology,
		at: Vector2i, dir: int, sealed: bool) -> void:
	var chunk := Chunk.new(route.world_seed, at, route.theme, {
		"descent": true,
		"topology": topology,
	})
	if sealed:
		_expect(chunk.runtime_seal_solids(dir) > 0,
			"theme %d state %d sealed edge %s/%d has no collision" % [
				route.theme, topology.current_state_id(), at, dir])
	else:
		_expect(chunk.runtime_shortcut_blockers(dir) == 0,
			"theme %d state %d opening %s/%d is blocked" % [
				route.theme, topology.current_state_id(), at, dir])
	_expect(chunk.doorway_clearance_violations() == 0,
		"theme %d state %d edge room %s blocks a doorway" % [
			route.theme, topology.current_state_id(), at])
	# A second construction is the streaming contract: no live-node mutation is
	# required to reproduce the current reality.
	var rebuilt := Chunk.new(route.world_seed, at, route.theme, {
		"descent": true,
		"topology": topology,
	})
	if sealed:
		_expect(rebuilt.runtime_seal_solids(dir) > 0,
			"theme %d rebuilt seal vanished at %s/%d" % [route.theme, at, dir])
	else:
		_expect(rebuilt.runtime_shortcut_blockers(dir) == 0,
			"theme %d rebuilt opening blocked at %s/%d" % [route.theme, at, dir])
		if bool(topology.edge_info(at, dir).get("runtime_door", false)):
			_audit_door_rebuild_state(route.theme, at, chunk, rebuilt)
	chunk.free()
	rebuilt.free()


func _audit_door_rebuild_state(theme: int, at: Vector2i,
		first: Chunk, rebuilt: Chunk) -> void:
	var source := _mutation_door(first)
	var restored := _mutation_door(rebuilt)
	_expect(source != null and restored != null,
		"theme %d runtime door missing at %s" % [theme, at])
	if source == null or restored == null:
		return
	source.rotation.y = 1.11
	source.set_meta("open", true)
	source.set_meta("last_open_angle", 1.11)
	rebuilt.restore_rebuild_state(first.capture_rebuild_state())
	_expect(bool(restored.get_meta("open", false)) \
			and is_equal_approx(restored.rotation.y, 1.11),
		"theme %d rebuilt door lost open angle at %s" % [theme, at])
	for body_node in restored.find_children("*", "StaticBody3D", true, false):
		for shape_node in body_node.find_children(
				"*", "CollisionShape3D", true, false):
			_expect((shape_node as CollisionShape3D).disabled,
				"theme %d rebuilt open door retained collision at %s" % [theme, at])
	for hit_node in restored.find_children("*", "Interactable", true, false):
		_expect((hit_node as Interactable).prompt_text == "E — close door",
			"theme %d rebuilt open door lost prompt state at %s" % [theme, at])


func _mutation_door(chunk: Chunk) -> Node3D:
	for node in chunk.find_children("*", "Node3D", true, false):
		var pivot := node as Node3D
		if pivot != null and bool(pivot.get_meta("runtime_mutation_door", false)):
			return pivot
	return null
