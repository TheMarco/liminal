extends "res://tools/lib/audit_base.gd"
## Production camera framing, delayed collision change, streaming, blackout
## and disk-save contract. No renderer required; capture_photo_doorway.gd
## additionally exercises the actual shutter and captures all visual states.
## godot --headless --path . --script tools/audit_photo_doorways.gd -- \
##   --mode=descent --nologo --realm-visit --seed=7
const SEED := 7

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

func _ray(player: Player, centre: Vector3, forward: Vector3) -> Dictionary:
	return player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(centre - forward * 0.7,
			centre + forward * 0.7, 1, [player.get_rid()]))

func run() -> void:
	var game := await boot_game(SEED)
	var realm: RealmExcursion = game._realm_visit
	expect(is_instance_valid(realm), "realm visit fixture was not prepared")
	if not is_instance_valid(realm):
		await teardown_game(game)
		finish()
		return
	expect(await await_until(func(): return realm.phase == RealmExcursion.Phase.WAITING, 20000),
		"realm preview did not become ready")
	var route: DescentRoute = game.descent_route
	var topology: DescentTopology = route.topology
	var cm: ChunkManager = game.cm
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	var player: Player = game.player
	expect(director.realm_preview_ready, "realm phase settled without photo preview readiness")
	game.run.set_process(false)
	game.set_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	cm.set_process(false)
	camera.set_process(false)
	var records := topology.photo_doorways()
	expect(not records.is_empty(), "seed 7 did not plan a photographic doorway")
	if records.is_empty():
		await teardown_game(game)
		finish()
		return
	var record := records[0]
	expect(bool(record.get("realm", false)), "doorway fixture is not owned by the realm preview")
	var id := str(record["id"])
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var other: Vector2i = at + WorldGen.DIRV[dir]
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
	expect(left.preview_ready and right.preview_ready, "door preview lacks a clear approach")
	expect(not topology.photo_door_open(id) and topology.is_wall(at, dir)
		and topology.is_wall(other, DescentTopology.OPPOSITE[dir]), "door graph opened before shot")
	expect(left.barrier.collision_layer == 1 and right.barrier.collision_layer == 1,
		"unphotographed door lost collision")
	expect(_layers_ok(left.fill, PhotoAnomaly.EYE_ONLY_LAYER)
		and _layers_ok(right.fill, PhotoAnomaly.EYE_ONLY_LAYER), "wall is not eye-only")
	var centre := left.to_global(left.centre) + Vector3.UP * 1.3
	var forward := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	expect(not _ray(player, centre, forward).is_empty(), "closed wall is physically passable")
	var anomaly: PhotoAnomaly
	for sign_value in [-1.0, 1.0]:
		player.cam.global_position = centre + forward * 6.0 * sign_value + Vector3.UP * 0.3
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
	# Completing ordinary evidence must never disable useful doorways.
	for spec in director.plan.values():
		if director.requirement_met():
			break
		director.mark_documented(str(spec["id"]))
	expect(director.capturable().has(anomaly), "quota disabled the photographic doorway")
	var distance_before := maxi(route.distance_from_target(at), route.distance_from_target(other))
	var callback := anomaly._doorway_resolve
	expect(director.mark_documented(id), "door photograph did not count as evidence")
	camera._review_callbacks.append(callback)
	expect(topology.is_wall(at, dir) and not left.opened, "door opened behind review card")
	expect(not game._mutation_mode_ready(), "blackout can interrupt doorway photo review")
	game._on_photo_documented(id, director.documented_count(), director.required_count(),
		"THERE WAS NO DOOR HERE")
	game._on_photo_review_finished()
	game._event_tween.custom_step(2.4)
	expect(game._event_panel.modulate.a < 0.01, "evidence caption obscures the doorway glow")
	game._event_tween.custom_step(0.3)
	expect(game._event_panel.modulate.a > 0.9, "doorway evidence caption never appears")
	game._event_tween.kill()

	# Simulate quit DURING the print: only documented IDs have been saved.
	var path := "/tmp/liminal-photo-door-%d.cfg" % OS.get_process_id()
	var progress := DescentProgress.new(path)
	progress.start_new(SEED)
	progress.record_photo_ids(0, director.documented_ids())
	var saved := DescentProgress.new(path)
	var fresh := DescentRoute.build(route.world_seed, route.theme, route.floor_idx)
	var fresh_topology := DescentTopology.new(route.world_seed, route.theme)
	fresh.set_topology(fresh_topology)
	fresh_topology.plan_floor(fresh)
	expect(fresh_topology.photo_doorways() == records, "door plan changed on reload")
	var fresh_director := PhotoDirector.new()
	fresh_director.configure(fresh, 0, null, saved.photo_ids_for_floor(0))
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
	expect(_ray(player, centre, forward).is_empty(), "invisible wall remains in doorway")
	# Walk the real player's collision capsule across the threshold.
	player.teleport(centre - Vector3.UP * 1.15 - forward * 0.65)
	var collision := player.move_and_collide(forward * 1.3)
	expect(collision == null, "player capsule cannot cross photographed passage")
	expect(maxi(route.distance_from_target(at), route.distance_from_target(other)) < distance_before,
		"opening did not update useful route guidance")
	var effects := get_nodes_in_group("mutation_reveal_effect")
	expect(not effects.is_empty() and is_equal_approx(MutationRevealEffect.LIFE_SECONDS, 2.5),
		"door did not spawn shared 2.5-second glow")
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
	finish("photo door: both-side framing, delayed capsule passage, quota, disk save, streaming, blackout")
