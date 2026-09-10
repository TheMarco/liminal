extends "res://tools/lib/audit_base.gd"
## Mall photographic obstruction: generated route, legal camera stances,
## carton collision, delayed resolution, ghost, evidence, disk save and streaming.
## Headless physics contract; rendered capture separately verifies the shutter.
## godot --headless --path . --script tools/audit_photo_obstruction.gd -- \
##   --mode=descent --descent-floor=2 --nologo --seed=21
const SEED := 21

func _layers_ok(node: Node, expected: int) -> bool:
	if node is VisualInstance3D and (node as VisualInstance3D).layers != expected:
		return false
	for child in node.get_children():
		if not _layers_ok(child, expected):
			return false
	return true

func _find_seal(chunk: Chunk, id: String) -> PhotoDoorSeal:
	if chunk != null:
		for seal in chunk.photo_door_seals():
			if seal.photo_id == id:
				return seal
	return null

func _build_rooms(cm: ChunkManager, at: Vector2i, other: Vector2i) -> void:
	for endpoint in [at, other]:
		for member in WorldGen.owning_room_members(cm.world_seed, endpoint, cm.theme):
			if cm.chunk_at(member) == null:
				cm._build(member)

func _ray(player: Player, centre: Vector3, forward: Vector3, depth: float) -> Dictionary:
	return player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(centre - forward * (depth + 0.7),
			centre + forward * (depth + 0.7), 1, [player.get_rid()]))


func _check_imported_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += 1
		expect(node.mesh != null and not node.mesh is PrimitiveMesh, "obstruction contains primitive visuals")
		var source := str(node.get_meta("source_scene", ""))
		expect(source.begins_with("res://") and ResourceLoader.exists(source), "obstruction lacks existing-model provenance")
	for child in node.get_children():
		count += _check_imported_meshes(child)
	return count


func _capsule_blocked(player: Player, centre: Vector3, forward: Vector3, depth: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = ArrivalSafety.RADIUS
	capsule.height = ArrivalSafety.HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, centre - Vector3.UP * 0.35 - forward * (depth + 0.7))
	query.motion = forward * (depth + 0.7) * 2.0
	var motion := player.get_world_3d().direct_space_state.cast_motion(query)
	return not motion.is_empty() and motion[0] < 0.999

func run() -> void:
	_check_planning()
	var game := await boot_game(SEED)
	var route: DescentRoute = game.descent_route
	var topology: DescentTopology = route.topology
	var cm: ChunkManager = game.cm
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	var player: Player = game.player
	game.run.set_process(false)
	game.set_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	cm.set_process(false)
	camera.set_process(false)
	expect(route.floor_idx == 1 and route.theme == 7, "audit must run on floor 2 mall")
	var records := topology.photo_doorways().filter(func(r: Dictionary): return bool(r.get("obstruction", false)))
	expect(not records.is_empty(), "floor 2 did not plan a photographic obstruction")
	if records.is_empty():
		await teardown_game(game)
		finish()
		return
	var record: Dictionary = records[0]
	var id := str(record["id"])
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var other: Vector2i = at + WorldGen.DIRV[dir]
	for state in topology.state_count():
		var parts: Array[Chunk] = []
		var seen := {}
		for endpoint in [at, other]:
			for member in WorldGen.owning_room_members(route.world_seed, endpoint, route.theme):
				if not seen.has(member):
					seen[member] = true
					parts.append(cm._build(member, false, state))
		expect(director._photo_door_approach_clear(record, parts),
			"blackout state %d blocks the obstruction approach" % state)
		if state == 0 and not director._photo_door_approach_clear(record, parts):
			print("BLOCKED OBSTRUCTION ", record)
			var d: Vector2i = WorldGen.DIRV[dir]
			var f := Vector3(d.x, 0.0, d.y)
			var t := float(record["t"])
			var c := Vector3(at.x * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 0 else t),
				Chunk.cell_floor_h(route.world_seed, at, route.theme),
				at.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 2 else t))
			var e := f.abs() * 6.4 + Vector3(absf(f.z), 0.0, absf(f.x)) * 1.45
			for part in parts:
				_report_blocker(part, Transform3D.IDENTITY, AABB(c - e + Vector3.UP * 0.03, e * 2.0 + Vector3.UP * 2.32))
		for part in parts:
			part.free()
	_build_rooms(cm, at, other)
	director._register_photo_doors()
	await physics_frame
	var left := _find_seal(cm.chunk_at(at), id)
	var right := _find_seal(cm.chunk_at(other), id)
	expect(left != null and right != null, "doorway missing one side")
	if left == null or right == null:
		await teardown_game(game)
		finish()
		return
	expect(left.obstruction and right.obstruction, "seals lost obstruction identity")
	for seal in [left, right]:
		expect(seal.barrier.get_child_count() > 0, "obstruction lacks mesh collision")
		expect(_check_imported_meshes(seal.fill) > 0, "obstruction lacks imported meshes")
		for shape in seal.barrier.get_children():
			expect(shape is CollisionShape3D and shape.shape != null
				and (shape.shape is ConvexPolygonShape3D or shape.shape is ConcavePolygonShape3D),
				"obstruction collision is not derived from mesh geometry")
		var descriptor: Dictionary = seal.reveal_descriptor()
		expect(descriptor.get("kind") == "prop", "obstruction must dissolve with a prop ghost")
		var ghost: Node3D = descriptor.get("ghost")
		expect(ghost != null and ghost.get_child_count() > 0, "obstruction lacks carton ghost geometry")
		if ghost != null:
			expect(_check_imported_meshes(ghost) > 0, "reveal ghost lacks imported meshes")
			ghost.free()
	expect(left.preview_ready and right.preview_ready, "door preview lacks a clear approach")
	expect(not topology.photo_door_open(id) and topology.is_wall(at, dir)
		and topology.is_wall(other, DescentTopology.OPPOSITE[dir]), "door graph opened before shot")
	expect(left.barrier.collision_layer == 1 and right.barrier.collision_layer == 1,
		"unphotographed door lost collision")
	expect(_layers_ok(left.fill, PhotoAnomaly.EYE_ONLY_LAYER)
		and _layers_ok(right.fill, PhotoAnomaly.EYE_ONLY_LAYER), "wall is not eye-only")
	var centre := left.to_global(left.centre) + Vector3.UP * 1.3
	var forward := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	var depth := maxf(float(left.get("obstruction_depth")), float(right.get("obstruction_depth")))
	expect(_capsule_blocked(player, centre, forward, depth), "closed obstruction is physically passable")
	var anomaly: PhotoAnomaly
	for sign_value in [-1.0, 1.0]:
		var stance: Vector3 = centre - Vector3.UP * 1.15 + forward * 6.0 * sign_value
		expect(ArrivalSafety.is_clear(player.get_world_3d(), stance, [player.get_rid()])
			and ArrivalSafety.has_floor(player.get_world_3d(), stance, [player.get_rid()]),
			"six-metre camera stance is not legally walkable from side %s" % sign_value)
		player.teleport(stance)
		player.cam.fov = 58.0
		player.cam.look_at(centre)
		camera._raise(true)
		var captured := camera._captured_anomalies()
		var matched: PhotoAnomaly
		for node in captured:
			if node.id == id:
				matched = node
		expect(matched != null, "door cannot be photographed from side %s" % sign_value)
		if sign_value < 0:
			anomaly = matched
		player.cam.rotate_y(PI)
		expect(not camera._captured_anomalies().any(func(a: PhotoAnomaly): return a.id == id),
			"door behind camera qualifies for photograph")
	if anomaly == null:
		await teardown_game(game)
		finish()
		return
	expect(anomaly.type == PhotoAnomaly.Type.OBSTRUCTION, "camera registered the wrong anomaly type")
	# Completing ordinary evidence must never disable useful doorways.
	for spec in director.plan.values():
		if director.requirement_met():
			break
		director.mark_documented(str(spec["id"]))
	expect(director.capturable().has(anomaly), "quota disabled the photographic doorway")
	var distance_before := maxi(route.distance_from_target(at), route.distance_from_target(other))
	var callback := anomaly._doorway_resolve
	expect(director.mark_documented(id), "door photograph did not count as evidence")
	var credited := director.documented_count()
	expect(not director.mark_documented(id) and director.documented_count() == credited,
		"repeat obstruction photo awarded duplicate credit")
	camera._review_callbacks.append(callback)
	expect(topology.is_wall(at, dir) and not left.opened, "door opened behind review card")
	expect(not game._mutation_mode_ready(), "blackout can interrupt doorway photo review")
	game._on_photo_documented(id, director.documented_count(), director.required_count(),
		"THE BOXES WERE NEVER THERE")
	game._on_photo_review_finished()
	game._event_tween.custom_step(2.4)
	expect(game._event_panel.modulate.a < 0.01, "evidence caption obscures the doorway glow")
	game._event_tween.custom_step(0.3)
	expect(game._event_panel.modulate.a > 0.9, "doorway evidence caption never appears")
	game._event_tween.kill()

	# Simulate quit DURING the print: only documented IDs have been saved.
	var path := "/tmp/liminal-photo-obstruction-%d.cfg" % OS.get_process_id()
	var progress := DescentProgress.new(path)
	progress.start_new(SEED)
	progress.record_photo_ids(1, director.documented_ids())
	var saved := DescentProgress.new(path)
	var fresh := DescentRoute.build(route.world_seed, route.theme, route.floor_idx)
	var fresh_topology := DescentTopology.new(route.world_seed, route.theme)
	fresh.set_topology(fresh_topology)
	fresh_topology.plan_floor(fresh)
	expect(fresh_topology.photo_doorways().filter(func(r: Dictionary): return bool(r.get("obstruction", false))) == records, "door plan changed on reload")
	var fresh_director := PhotoDirector.new()
	fresh_director.configure(fresh, 1, null, saved.photo_ids_for_floor(1))
	expect(fresh_topology.photo_door_open(id) and not fresh_topology.is_wall(at, dir),
		"saved photograph did not reconstruct the opening")
	var restored_chunk := Chunk.new(route.world_seed, at, route.theme,
		{"descent": true, "topology": fresh_topology})
	var restored_seal := _find_seal(restored_chunk, id)
	expect(restored_seal != null and restored_seal.opened
		and restored_seal.barrier.collision_layer == 0, "Continue rebuilt a solid wall")
	restored_chunk.free()
	fresh_director.free()
	progress.clear_from_disk()

	# Streaming can retire the photographed node while the print is still up.
	anomaly.free()
	camera._release_review_resolutions()
	await physics_frame
	expect(topology.photo_door_open(id) and left.opened and right.opened,
		"review release did not open both sides after anomaly retirement")
	expect(left.barrier.collision_layer == 0 and right.barrier.collision_layer == 0,
		"opened passage retained collision")
	expect(not left.fill.visible and not right.fill.visible, "opened door retained visual fill")
	for seal in [left, right]:
		for frame in seal.frame:
			expect(_layers_ok(frame, 1), "opened frame is not world-visible")
	expect(_ray(player, centre, forward, depth).is_empty(), "invisible wall remains in doorway")
	# Walk the real player's collision capsule across the threshold.
	player.teleport(centre - Vector3.UP * 1.15 - forward * 0.65)
	var collision := player.move_and_collide(forward * 1.3)
	expect(collision == null, "player capsule cannot cross photographed passage")
	expect(maxi(route.distance_from_target(at), route.distance_from_target(other)) < distance_before,
		"opening did not update useful route guidance")
	var effects := get_nodes_in_group("mutation_reveal_effect")
	expect(not effects.is_empty() and is_equal_approx(MutationRevealEffect.LIFE_SECONDS, 2.5),
		"door did not spawn shared 2.5-second glow")
	for effect in effects:
		expect(effect._ghost != null and effect._ghost.get_child_count() > 0,
			"obstruction reveal lacks the disappeared cartons")
	var reveal_count := effects.size()
	expect(not game._mutation_mode_ready(), "blackout can hide the doorway glow")
	callback.call()
	expect(get_nodes_in_group("mutation_reveal_effect").size() == reveal_count,
		"duplicate resolution replayed glow")
	camera._doorway_reveal_left = 0.0
	expect(game._mutation_mode_ready(), "doorway reveal kept blocking later blackouts")

	# A rebuilt room and every future blackout state preserve the passage.
	for endpoint in [at, other]:
		var old := cm.chunk_at(endpoint)
		cm.chunks.erase(endpoint)
		stop_audio(old)
		old.free()
		cm._build(endpoint)
		var rebuilt := _find_seal(cm.chunk_at(endpoint), id)
		expect(rebuilt != null and rebuilt.opened and rebuilt.barrier.collision_layer == 0,
			"streamed room rebuilt the photographic wall")
	for state in topology.state_count():
		topology.restore_state(state)
		route.refresh_topology()
		expect(not topology.is_wall(at, dir)
			and not topology.is_wall(other, DescentTopology.OPPOSITE[dir]), "blackout closed photo door")
		var delta := topology.state_delta(0, state)
		for change in delta.edges:
			expect(str(change["key"]) != str(record["key"]), "blackout delta claimed photo door")
		var rebuilt := Chunk.new(route.world_seed, at, route.theme,
			{"descent": true, "topology": topology})
		expect(_find_seal(rebuilt, id).opened and rebuilt.runtime_shortcut_blockers(dir) == 0,
			"blackout rebuild obstructed photographic doorway")
		rebuilt.free()
	await teardown_game(game)
	finish("photo obstruction: both-side framing, delayed capsule passage, quota, disk save, streaming, blackout")


func _check_planning() -> void:
	for base_seed in [21, 102, 101, 7, 105]:
		var ws := WorldGen.level_seed(base_seed, 7)
		var route := DescentRoute.build(ws, 7, 1)
		var topology := DescentTopology.new(ws, 7)
		route.set_topology(topology)
		topology.plan_floor(route)
		var hint := route.obstruction_hint
		expect(not hint.is_empty(), "seed %d has no obstruction" % base_seed)
		if hint.is_empty():
			continue
		expect(int(hint["saving"]) >= 4, "seed %d obstruction is not useful" % base_seed)
		expect(DescentRoute.build(ws, 7, 1).obstruction_hint == hint,
			"seed %d obstruction is not deterministic" % base_seed)
		var path := route.path_from_origin()
		expect(not path.is_empty() and path.back() == route.target,
			"seed %d lacks an ordinary route" % base_seed)
		for i in range(1, path.size()):
			var delta: Vector2i = path[i] - path[i - 1]
			var dir := WorldGen.DIRV.find(delta)
			expect(dir >= 0 and not topology.is_wall(path[i - 1], dir),
				"seed %d ordinary route is blocked before taking photo" % base_seed)
		var evidence := PhotoDirector.build_plan(route)
		expect(PhotoDirector.intro_route_evidence_count(route, evidence) >= PhotoDirector.required_for(1, 7),
			"seed %d shortcut strands evidence quota" % base_seed)
		print("OBSTRUCTION PLAN seed=%d saving=%d evidence=%d" % [base_seed, hint["saving"],
			PhotoDirector.intro_route_evidence_count(route, evidence)])


func _report_blocker(node: Node, parent: Transform3D, passage: AABB) -> void:
	if node is PhotoDoorSeal or node is Area3D:
		return
	if node is CollisionObject3D and (node.collision_layer & 1) == 0:
		return
	var transform := parent
	if node is Node3D:
		transform = parent * node.transform
	if node is CollisionShape3D and not node.disabled and node.shape != null:
		var bounds: AABB = transform * node.shape.get_debug_mesh().get_aabb()
		if passage.intersects(bounds):
			print("BLOCKER ", node.get_parent().name, "/", node.name, " bounds=", bounds)
	for child in node.get_children():
		_report_blocker(child, transform, passage)
