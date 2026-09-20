extends "res://tools/lib/audit_base.gd"
## New-run discovery from normal arrival, using actual streaming, detector,
## collision and viewfinder framing rather than a hand-positioned anomaly.

func run() -> void:
	var game := await boot_game(21)
	var route: DescentRoute = game.descent_route
	var cm: ChunkManager = game.cm
	var player: Player = game.player
	var camera: PhotoCamera = game._photo_camera
	var director: PhotoDirector = game._photo_director
	var record := route.topology.intro_photo_door()
	expect(not record.is_empty(), "new run lacks its introductory doorway")
	if record.is_empty():
		await teardown_game(game)
		finish()
		return
	var id := str(record["id"])
	# Before the photograph, every generated blackout furnishing variant must
	# preserve the standing/framing lanes as well as the closed-wall contract.
	var near: Vector2i = record["cell"]
	var far: Vector2i = near + WorldGen.DIRV[DescentTopology.edge_dir(record)]
	for state in route.topology.state_count():
		var parts: Array[Chunk] = []
		var seen := {}
		for endpoint in [near, far]:
			for member in WorldGen.owning_room_members(route.world_seed, endpoint, 0):
				if not seen.has(member):
					seen[member] = true
					parts.append(cm._build(member, false, state))
		expect(director._photo_door_approach_clear(record, parts),
			"blackout state %d obstructs first-door discovery" % state)
		for part in parts:
			part.free()
	var path := route.path_from_origin()
	var index := int(record["approach_path_index"])
	var approach: Vector2i = record["approach_cell"]
	expect(index <= 8 and int(record["approach_room_steps"]) <= 4,
		"introductory doorway is too late")
	var first_seen := {}
	for i in path.size():
		var room := WorldGen.room_id(route.world_seed, path[i])
		if not first_seen.has(room):
			first_seen[room] = i
	for tape in route.optional_vhs_cells():
		expect(int(first_seen[WorldGen.room_id(route.world_seed, tape)]) > index,
			"recording precedes introductory doorway")
	for at in route.casino_landmarks:
		expect(not route.is_intro_door_room(at), "landmark claimed discovery room")
	for at in director.plan:
		expect(not route.is_intro_door_room(at), "ordinary evidence competes inside discovery room")
	# Simulate the resident neighbourhood at each room reached on the normal
	# route. Do not force-load the doorway's far room separately.
	for i in index + 1:
		for at in cm._room_complete_cells(path[i]):
			if cm.chunk_at(at) == null:
				cm._build(at)
		director._register_photo_doors()
	# Realm previews are intentionally lazy. Bring the player to the streamed
	# approach cell first, then wait for the real preview lifecycle to settle.
	var floor_y := Chunk.cell_floor_h(cm.world_seed, approach, game.active_level)
	player.teleport(Vector3((float(approach.x) + 0.5) * WorldGen.CELL_SIZE,
		floor_y, (float(approach.y) + 0.5) * WorldGen.CELL_SIZE))
	var preview_deadline := Time.get_ticks_msec() + 15000
	while not director.realm_preview_ready and Time.get_ticks_msec() < preview_deadline:
		await physics_frame
	expect(director.realm_preview_ready, "realm phase did not settle after approach streaming")
	if not director.realm_preview_ready:
		await teardown_game(game)
		finish()
		return
	game.run.set_process(false)
	game.set_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	cm.set_process(false)
	camera.set_process(false)
	await physics_frame
	var doorway: PhotoAnomaly
	for node in director.capturable():
		if node.id == id and node.cell == record["approach_cell"]:
			doorway = node
	expect(doorway != null, "normal route streaming did not expose introductory doorway")
	if doorway == null:
		await teardown_game(game)
		finish()
		return
	var chunk := cm.chunk_at(approach)
	var seal: PhotoDoorSeal
	for item in chunk.photo_door_seals():
		if item.photo_id == id:
			seal = item
	var forward := Vector3(WorldGen.DIRV[seal.dir].x, 0, WorldGen.DIRV[seal.dir].y)
	var target := seal.to_global(seal.centre) + Vector3.UP * 1.3
	var found := false
	# Search actual standing positions in the approach room; a photograph from
	# inside a slot machine must never count as a discovery test.
	for depth in [5.8, 5.0, 6.5, 4.5]:
		for offset in [0.0, -0.6, 0.6, -1.2, 1.2]:
			var pos: Vector3 = target - Vector3.UP * 1.15 - forward * depth \
				+ Vector3(-forward.z, 0, forward.x) * offset
			if not ArrivalSafety.is_clear(player.get_world_3d(), pos, [player.get_rid()]) \
					or not ArrivalSafety.has_floor(player.get_world_3d(), pos, [player.get_rid()]):
				continue
			player.teleport(pos)
			player.cam.look_at(target)
			player.cam.fov = 58.0
			camera._raise(true)
			if camera._captured_anomalies().has(doorway):
				found = true
				break
		if found:
			break
	expect(found, "no legal standing position can frame the introductory doorway")
	if found:
		var proximity := camera._scan_proximity()
		expect(proximity.y > 0.14, "existing line-of-sight detector does not cue discovery")
		expect(camera._aim_warmth() > 0.5, "existing focus feedback does not lead into the doorway")
		camera._lower()
		expect(not seal.opened and seal.barrier.collision_layer == 1,
			"looking through the camera opened the doorway without a photograph")
	print("INTRO DISCOVERY seed=%d path_edges=%d room_steps=%d saving=%d" % [
		game.world_seed, index, record["approach_room_steps"], record["saving"]])
	await teardown_game(game)
	finish("first doorway: early route, recordings, streaming, legal stance, detector and focus")
