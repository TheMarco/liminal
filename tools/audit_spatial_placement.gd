extends SceneTree
## Package 2 placement gate: a real Office floor admits a site, reserves it
## from legacy planning, builds the prepared module through the chunk
## kernel, and runs a witnessed event with live routing intact throughout.
##
## Run:
##   godot --headless --path . --script tools/audit_spatial_placement.gd

const SEARCH_SEEDS := 20
const MIN_ADMITTED_SAMPLES := 3

var failures: Array[String] = []
var _finished: Array = []
var _persisted: Array = []
var _invalidations := 0
var _campaign_body: SpatialTestBody
var _campaign_last_position := Vector3.ZERO
var _occupancy_samples := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _run() -> void:
	var admissions := _find_admissions()
	_expect(admissions.size() >= MIN_ADMITTED_SAMPLES,
		"only %d/%d office seeds admitted sites; need %d samples" % [
			admissions.size(), SEARCH_SEEDS, MIN_ADMITTED_SAMPLES])
	if admissions.is_empty():
		quit(1)
		return
	for sampled in admissions:
		_audit_admitted_phases(sampled["route"], sampled["topology"],
			sampled["spec"])
	var admission: Dictionary = admissions[0]
	var route: DescentRoute = admission["route"]
	var topology: DescentTopology = admission["topology"]
	var spec: SpatialSiteSpec = admission["spec"]
	_audit_reservation(route, topology, spec)
	_audit_legacy_connectivity(route, topology)
	await _audit_live_event(route, topology, spec)
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print(("  PASS - office placement holds (%d/%d seeds admitted; " \
			+ "all three phases globally connected)") % [
			admissions.size(), SEARCH_SEEDS])
		quit()
	else:
		quit(1)


func _find_admissions() -> Array:
	var admissions := []
	for extra in SEARCH_SEEDS:
		var ws := WorldGen.level_seed(900000 + extra * 131, 1)
		var route := DescentRoute.build(ws, 1, 2)
		var topology := DescentTopology.new(ws, 1)
		route.set_topology(topology)
		topology.plan_floor(route)
		if not topology.site_specs.is_empty():
			admissions.append({"route": route, "topology": topology,
				"spec": topology.site_specs[0]})
	return admissions


func _audit_admitted_phases(route: DescentRoute,
		topology: DescentTopology, spec: SpatialSiteSpec) -> void:
	var frame := SpatialSitePlanner.junction_frame(spec)
	var junction: Vector2i = frame["cell"]
	var dirs: Array = frame["dirs"]
	_expect(dirs.size() == 2,
		"sampled site %s must have two aperture dirs" % spec.id)
	if dirs.size() != 2:
		return
	var dir_a := int(dirs[0])
	var dir_b := int(dirs[1])
	_expect(not route.base_is_wall(junction, dir_a),
		"sampled site %s A must replace a base opening" % spec.id)
	_expect(route.base_is_wall(junction, dir_b),
		"sampled site %s B must replace a base wall" % spec.id)
	for phase in [
		{"name": "a_open", "a": true, "b": false},
		{"name": "both_open", "a": true, "b": true},
		{"name": "b_open", "a": false, "b": true},
	]:
		_expect(_phase_reaches_every_scanned_cell(route, topology,
			junction, dir_a, dir_b, bool(phase["a"]), bool(phase["b"])),
			"sampled site %s phase %s must connect every scanned cell" % [
				spec.id, phase["name"]])


func _phase_reaches_every_scanned_cell(route: DescentRoute,
		topology: DescentTopology, junction: Vector2i, dir_a: int,
		dir_b: int, a_open: bool, b_open: bool) -> bool:
	var scanned := {}
	for at in route.scanned_cells():
		scanned[at] = true
	if not scanned.has(route.target):
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
			var open := bool(overrides[key]) if overrides.has(key) else \
				not bool(topology.edge_info_for_state(at, dir,
					topology.current_state_id()).get("wall", true))
			if not open:
				continue
			reached[other] = true
			queue.append(other)
	return reached.size() == scanned.size()


func _audit_reservation(route: DescentRoute, topology: DescentTopology,
		spec: SpatialSiteSpec) -> void:
	_expect(spec.is_valid(), "admitted spec must be valid")
	_expect(spec.cells[0] != route.origin
		and spec.cells[0] != route.target,
		"junction must avoid origin/target")
	for at in spec.cells:
		_expect(topology.site_id_at(at) == spec.id,
			"site cell %s must be reserved" % at)
	route.refresh_topology()
	for state_id in range(1, topology.states().size()):
		var delta := topology.state_delta(0, state_id)
		for change in delta.edges:
			var key := DescentTopology.edge_key(change["cell"],
				int(change["dir"]))
			_expect(not _key_touches_site(topology, spec, key),
				"legacy state %d must not rebuild site edges" % state_id)
		for room in delta.rooms:
			_expect(not spec.cells.has(room),
				"legacy state %d must not rebuild site rooms" % state_id)


func _key_touches_site(topology: DescentTopology, spec: SpatialSiteSpec,
		key: String) -> bool:
	# state_delta already skips site-owned keys; this double-checks that no
	# reported change borders a site cell edge owned by the overlay.
	for at in spec.cells:
		for dir in 4:
			if DescentTopology.edge_key(at, dir) == key \
					and not topology.site_edge(at, dir).is_empty():
				return true
	return false


func _audit_legacy_connectivity(route: DescentRoute,
		topology: DescentTopology) -> void:
	for state_id in range(topology.states().size()):
		topology.restore_state(state_id)
		route.refresh_topology()
		_expect(route.distance_from_target(route.origin) >= 0,
			"legacy state %d disconnected origin" % state_id)
		_expect(route.distance_from_target(route.target) >= 0,
			"legacy state %d disconnected target" % state_id)
		_expect(route.distance_from_target(
			route.objective_ritual_cell()) >= 0,
			"legacy state %d disconnected ritual" % state_id)
	topology.restore_state(0)
	route.refresh_topology()


func _audit_live_event(route: DescentRoute, topology: DescentTopology,
		spec: SpatialSiteSpec) -> void:
	var frame := SpatialSitePlanner.junction_frame(spec)
	var junction: Vector2i = frame["cell"]
	var dirs: Array = frame["dirs"]
	_expect(dirs.size() == 2, "spec must carry two aperture dirs")
	if dirs.size() != 2:
		return
	# Build the footprint chunks in-tree for real collision.
	var chunks: Array = []
	for at in spec.cells:
		var chunk := Chunk.new(route.world_seed, at, route.theme, {
			"descent": true,
			"topology": topology,
		})
		chunk.position = Vector3(at.x * ChunkManager.CELL, 0.0,
			at.y * ChunkManager.CELL)
		root.add_child(chunk)
		chunks.append(chunk)
	await physics_frame
	# Prepared module, not a normal wall: site edges carry the marker and
	# the junction chunk emitted tagged dressing clear of the approaches.
	for key in ["a", "b"]:
		var dir := int(dirs[0] if key == "a" else dirs[1])
		var info := topology.edge_info(junction, dir)
		_expect(str(info.get("spatial_site", "")) == spec.id,
			"aperture %s edge must be site-owned" % key)
	var dressing := _collect_dressing(chunks)
	_expect(dressing.size() >= 5, "junction must emit anchor dressing")
	# Install the site node and director exactly like the campaign.
	topology.set_site_edge(spec.id, junction, int(dirs[0]), true)
	topology.set_site_edge(spec.id, junction, int(dirs[1]), false)
	var floor_root := Node3D.new()
	root.add_child(floor_root)
	var site := MigratingDoorSite.new()
	floor_root.add_child(site)
	var prepared := site.prepare(spec,
		SpatialSiteState.for_spec(spec, "a_open"), {
			"wall_material": Mats.office_wall_variant(
				WorldGen.finish_variant(route.world_seed, junction,
					route.theme)),
			"trim_material": Mats.box_white(),
			"ceiling_h": Chunk.HOFF,
			"pattern_tile_m": 0.8,
		})
	_expect(prepared.ok,
		"campaign site must prepare: " + prepared.reason)
	if not prepared.ok:
		_cleanup_nodes(chunks, floor_root, null, null)
		await process_frame
		return
	for node in dressing:
		_expect(not _overlaps_approaches(site, node),
			"dressing must clear site approaches")
	var director := SpatialMutationDirector.new()
	director.process_physics_priority = 100
	floor_root.add_child(director)
	var horror := HorrorDirector.new()
	var manager := ChunkManager.new()
	director.configure(horror, manager, topology, route)
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	floor_root.add_child(camera)
	director.set_camera(camera)
	_campaign_body = SpatialTestBody.create()
	var occupied_cell: Vector2i = junction + WorldGen.DIRV[int(dirs[0])]
	_campaign_body.position = Vector3(
		occupied_cell.x * ChunkManager.CELL + ChunkManager.CELL * 0.5,
		Chunk.cell_floor_h(route.world_seed, occupied_cell, route.theme) + 0.1,
		occupied_cell.y * ChunkManager.CELL + ChunkManager.CELL * 0.5)
	floor_root.add_child(_campaign_body)
	_campaign_last_position = _campaign_body.global_position
	_occupancy_samples = 0
	var plan := _plan_for(route, topology, spec, junction, int(dirs[0]),
		int(dirs[1]), "a_open", "b_open")
	_expect(plan != null, "campaign plan must build")
	_expect(director.register_door_site(site,
		SpatialSiteState.for_spec(spec, "a_open"),
		Callable(self, "_campaign_occupancy"),
		Callable(self, "_capture_persist"),
		Callable(self, "_capture_invalidated")),
		"campaign site must register")
	await _observe_site_with_camera(director, camera, spec, junction,
		route.world_seed)
	for feature_id in director.site_witness_ids(spec.id):
		_expect(director.tracker.witness_eligible(feature_id),
			"live camera must witness %s" % feature_id)
	director.event_finished.connect(_on_event_finished)
	var started: Dictionary = director.request_event(spec.id, plan)
	_expect(bool(started.get("ok", false)),
		"campaign event must start: %s" % started.get("reason", ""))
	var frames := 0
	var distances_ok := true
	while director.is_active() and frames < 600:
		await physics_frame
		frames += 1
		if frames % 20 == 0:
			route.refresh_topology()
			if route.distance_from_target(route.origin) < 0 \
					or route.distance_from_target(route.target) < 0 \
					or route.distance_from_target(
						route.objective_ritual_cell()) < 0:
				distances_ok = false
	_expect(distances_ok, "routing must hold at every transition phase")
	_expect(_finished == ["completed_b_open"],
		"campaign event must complete, got %s" % str(_finished))
	_expect(frames < 600, "campaign event must finish")
	_expect(_persisted.size() >= 2,
		"event must persist active-safe and settled checkpoints")
	if _persisted.size() >= 2:
		var checkpoint: SpatialSiteState = _persisted[0]
		var settled: SpatialSiteState = _persisted.back()
		_expect(checkpoint.stable_phase == "both_open"
			and not checkpoint.completed,
			"active checkpoint must reconstruct both-open")
		_expect(settled.stable_phase == "b_open" and settled.completed,
			"final checkpoint must record completed b_open")
	_expect(_invalidations >= 2, "routing must invalidate per flip")
	_expect(_occupancy_samples > 0,
		"campaign event must query representative non-empty occupancy")
	_cleanup_nodes(chunks, floor_root, manager, horror)
	_campaign_body = null
	await process_frame
	await physics_frame
	await process_frame


func _observe_site_with_camera(director: SpatialMutationDirector,
		camera: Camera3D, spec: SpatialSiteSpec,
		junction: Vector2i, world_seed: int) -> void:
	var center := Vector3(
		junction.x * ChunkManager.CELL + ChunkManager.CELL * 0.5,
		Chunk.cell_floor_h(world_seed, junction, spec.theme) + 1.6,
		junction.y * ChunkManager.CELL + ChunkManager.CELL * 0.5)
	for feature_id in director.site_witness_ids(spec.id):
		var point: Vector3 = spec.witness_points[feature_id]["position"]
		camera.global_position = center
		camera.look_at(point)
		for _frame in 110:
			await physics_frame


func _cleanup_nodes(chunks: Array, floor_root: Node3D,
		manager: ChunkManager, horror: HorrorDirector) -> void:
	# Stop autoplay sources before their chunks leave the tree. This releases
	# AudioStreamPlayback objects synchronously enough for the leak gate.
	for chunk in chunks:
		_stop_audio_recursive(chunk)
		if is_instance_valid(chunk):
			chunk.queue_free()
	if floor_root != null and is_instance_valid(floor_root):
		floor_root.queue_free()
	if manager != null and is_instance_valid(manager):
		manager.free()
	if horror != null and is_instance_valid(horror):
		horror.free()


func _stop_audio_recursive(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
		(node as AudioStreamPlayer).stream = null
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
		(node as AudioStreamPlayer2D).stream = null
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
		(node as AudioStreamPlayer3D).stream = null
	for child in node.get_children():
		_stop_audio_recursive(child)


func _collect_dressing(chunks: Array) -> Array:
	var out := []
	for chunk in chunks:
		var stack: Array = [chunk]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node.has_meta("site_dressing"):
				out.append(node)
			for child in node.get_children():
				stack.append(child)
	return out


func _overlaps_approaches(site: MigratingDoorSite, node: Node3D) -> bool:
	var box := AABB(node.global_position, Vector3(0.6, 3.0, 0.6))
	box.position -= Vector3(0.3, 0.0, 0.3)
	for aperture in ["a", "b"]:
		if box.intersects(site.passage_box(aperture)):
			return true
		for approach in site.approach_boxes(aperture):
			if box.intersects(approach):
				return true
	return false


func _plan_for(route: DescentRoute, topology: DescentTopology,
		spec: SpatialSiteSpec, junction: Vector2i, dir_a: int,
		dir_b: int, from_phase: String,
		to_phase: String) -> SpatialTransitionPlan:
	var plan := SpatialTransitionPlan.new()
	plan.site_id = spec.id
	plan.expected_revision = topology.revision
	plan.from_phase = from_phase
	plan.to_phase = to_phase
	var key_a := DescentTopology.edge_key(junction, dir_a)
	var key_b := DescentTopology.edge_key(junction, dir_b)
	var cell_na: Vector2i = junction + WorldGen.DIRV[dir_a]
	var cell_nb: Vector2i = junction + WorldGen.DIRV[dir_b]
	var cell_ec := junction
	for dir in 4:
		if dir == dir_a or dir == dir_b:
			continue
		var other: Vector2i = junction + WorldGen.DIRV[dir]
		if route.base_is_wall(junction, dir):
			continue
		if not route.scanned_contains(other):
			continue
		cell_ec = other
		break
	plan.phase_edges = {
		"a_open": {key_a: true, key_b: false},
		"both_open": {key_a: true, key_b: true},
		"b_open": {key_a: false, key_b: true},
	}
	var occupiable := {
		"a_open": [junction, cell_na, cell_ec],
		"both_open": [junction, cell_na, cell_nb, cell_ec],
		"b_open": [junction, cell_nb, cell_ec],
	}
	plan.phase_pairs = {}
	for phase in occupiable.keys():
		var cells: Array = occupiable[phase]
		var pairs := []
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				pairs.append([cells[i], cells[j]])
		plan.phase_pairs[phase] = pairs
	plan.aperture_edges = {
		"a": {"cell": junction, "dir": dir_a},
		"b": {"cell": junction, "dir": dir_b},
	}
	plan.presentation = "lit"
	plan.hold_timeout = 6.0
	return plan if plan.is_valid() else null


func _campaign_occupancy() -> Array:
	if _campaign_body == null or not is_instance_valid(_campaign_body):
		return []
	var current := _campaign_body.global_position
	var sample := {
		"id": "placement_audit_actor",
		"prev": _campaign_last_position,
		"curr": current,
		"radius": Player.BODY_RADIUS,
	}
	_campaign_last_position = current
	_occupancy_samples += 1
	return [sample]


func _capture_persist(state: SpatialSiteState) -> Error:
	var snapshot := SpatialSiteState.from_disk(state.to_disk())
	if snapshot == null:
		return ERR_INVALID_DATA
	_persisted.append(snapshot)
	return OK


func _capture_invalidated() -> void:
	_invalidations += 1


func _on_event_finished(_site_id: String, outcome: String) -> void:
	_finished.append(outcome)
