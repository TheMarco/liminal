extends SceneTree
## Deterministic contract for the authored casino route landmarks and the
## numbered-door photograph, including direct streamed Chunk construction.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _landmark_room_indices(route: DescentRoute) -> Dictionary:
	var indexes := {}
	var seen := {}
	var path := route.path_from_origin()
	for i in path.size():
		var room := WorldGen.room_id(route.world_seed, path[i])
		if seen.has(room):
			continue
		seen[room] = true
		indexes[room] = seen.size() - 1
	return indexes


func _chunk_for(route: DescentRoute, room: Vector2i, kind: String) -> Chunk:
	var spec := ChunkBuildSpec.new()
	spec.descent = true
	spec.floor_idx = 0
	spec.base_seed = route.world_seed
	spec.casino_landmark = kind
	return Chunk.new(route.world_seed, room, 0, spec)


func _runtime_landmark_checks(route: DescentRoute, root: Node) -> void:
	for room in route.casino_landmarks:
		var kind := str(route.casino_landmarks[room])
		var chunk := _chunk_for(route, room, kind)
		root.add_child(chunk)
		await physics_frame
		await physics_frame
		_expect(chunk.doorway_clearance_violations() == 0, "landmark obstructs a generated doorway")
		if kind == CasinoLandmarks.LAST_CHANCE:
			var machines := chunk.find_children("*", "Node", true, false)
			var slots := []
			var powered := 0
			for node in machines:
				if node.has_meta("slot_machine"):
					slots.append(node)
					if bool(node.get_meta("powered", false)):
						powered += 1
						_expect(int(node.get_meta("slot_variant", -1)) == 1, "powered cabinet is not the wheel")
			_expect(slots.size() == 8,
				"last chance bank lost its intended density (%d)" % slots.size())
			_expect(powered == 1,
				"last chance chunk did not isolate one powered wheel")
			for node in chunk.find_children("*", "Node", true, false):
				_expect(not node.has_meta("blackjack_table") \
					and not node.has_meta("roulette_table"),
					"last chance chunk contains a table")
		elif kind == CasinoLandmarks.PHONE:
			var plates := chunk.find_children("NumberPlate", "Label3D", true, false)
			var phones := chunk.find_children("RedTelephone", "Node3D", true, false)
			_expect(plates.size() == 1 and plates[0].text == "104",
				"telephone corridor missing its 104 number plate")
			_expect(phones.size() == 1,
				"telephone corridor missing its red telephone")
		else:
			var space := chunk.get_world_3d().direct_space_state
			var height := _floor_ray(space, chunk, Vector2(5, 5.6))
			_expect(absf(height + 0.32) < 0.03, "lounge centre floor must be -0.32, got %.3f" % height)
			_expect(absf(_floor_ray(space, chunk, Vector2(1, 6))) < 0.01, "lounge perimeter is not level with generated doors")
			var last := 0.05
			for step in range(11):
				var x := 3.0 + float(step) * 0.1
				height = _floor_ray(space, chunk, Vector2(x, 6))
				_expect(is_finite(height) and height <= last + 0.02 and absf(height - last) < 0.10,
					"lounge ramp has a gap/step at %.2f (%.3f -> %.3f)" % [x, last, height])
				last = height

		chunk.free()


func _floor_ray(space: PhysicsDirectSpaceState3D, chunk: Chunk, point: Vector2) -> float:
	var origin := chunk.global_position + Vector3(point.x, 0.2, point.y)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 1.2))
	return float(hit.position.y - chunk.global_position.y) if not hit.is_empty() else INF


func _photo_runtime_check(route: DescentRoute, root: Node) -> void:
	var director := PhotoDirector.new()
	root.add_child(director)
	director.configure(route, 0, null, [])
	var room := Vector2i.ZERO
	for at in route.casino_landmarks:
		if route.casino_landmarks[at] == CasinoLandmarks.PHONE:
			room = at
			break
	var chunk := _chunk_for(route, room, CasinoLandmarks.PHONE)
	root.add_child(chunk)
	await process_frame
	director._on_chunk_built(chunk)
	var node = director._live.get(room)
	_expect(node != null and node.type == PhotoAnomaly.Type.NUMBERED_DOOR,
		"numbered-door photo anomaly was not spawned")
	if node != null:
		director.mark_documented(str(node.id))
		node.resolve()
		var plate := chunk.find_child("NumberPlate", true, false) as Label3D
		_expect(plate != null and plate.text == "106",
			"numbered-door resolution did not change the plate to 106")
	await process_frame
	chunk.free()
	var rebuilt := _chunk_for(route, room, CasinoLandmarks.PHONE)
	root.add_child(rebuilt)
	await process_frame
	director._on_chunk_built(rebuilt)
	var restored := rebuilt.find_child("NumberPlate", true, false) as Label3D
	_expect(restored != null and restored.text == "106",
		"documented numbered-door rebuild did not restore 106")
	await process_frame
	rebuilt.free()
	director.free()


func _run() -> void:
	var previous_plan := {}
	var runtime_root := Node.new()
	get_root().add_child(runtime_root)
	var seeds: Array[int] = []
	for i in range(64):
		seeds.append(1001 + i * 7919)
	# Regression: just one eligible non-corridor room on the entire route.
	seeds.append(1333692015)
	for sample in seeds.size():
		var seed := seeds[sample]
		var route := DescentRoute.build(seed, 0, 0)
		var plan := route.casino_landmarks.duplicate(true)
		_expect(plan.size() == 3,
			"seed %d did not receive exactly three casino landmarks" % seed)
		_expect(not plan.has(route.origin) and not plan.has(route.target),
			"seed %d placed a landmark on origin or target" % seed)
		var path := route.path_from_origin()
		var path_set := {}
		for at in path:
			path_set[WorldGen.room_id(route.world_seed, at)] = true
		for room in plan:
			_expect(path_set.has(room),
				"seed %d landmark room left the objective route" % seed)
		var topology := DescentTopology.new(route.world_seed, 0)
		var protected := topology._protected_cells(route)
		for room in plan:
			for member in WorldGen.owning_room_members(route.world_seed, room, 0):
				_expect(not topology._cell_allowed(route, member, protected),
					"seed %d landmark room can be changed by a blackout" % seed)
		var indexes := _landmark_room_indices(route)
		if not plan.is_empty():
			var earliest := path.size()
			for room in plan:
				earliest = mini(earliest, int(indexes.get(room, path.size())))
			_expect(earliest <= 3,
				"seed %d first landmark is later than three room transitions" % seed)
		var repeat := DescentRoute.build(route.world_seed, 0, 0)
		_expect(repeat.casino_landmarks == plan,
			"seed %d landmark plan was not repeatable" % seed)
		route.refresh_topology()
		_expect(route.casino_landmarks == plan,
			"seed %d topology refresh changed landmark plan" % seed)
		var photo := PhotoDirector.build_plan(route)
		var numbered := 0
		for at in photo:
			if int(photo[at]["type"]) == PhotoAnomaly.Type.NUMBERED_DOOR:
				numbered += 1
		_expect(numbered == 1,
			"seed %d did not reserve exactly one numbered-door photo" % seed)
		_expect(photo.size() >= PhotoDirector.required_for(0, 0),
			"seed %d photo plan fell below required count" % seed)
		if sample == 0:
			previous_plan = photo.duplicate(true)
		else:
			_expect(photo.size() == previous_plan.size(),
				"seed %d changed photo plan count" % seed)
			previous_plan = photo.duplicate(true)
		if sample < 12 or seed == 1333692015:
			await _runtime_landmark_checks(route, runtime_root)
			await _photo_runtime_check(route, runtime_root)
	runtime_root.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if failures.is_empty():
		print("casino landmark audit: PASS — 65 seeds, stable route landmarks, numbered photo reserved")
		quit()
	else:
		for failure in failures:
			print("  FAIL " + failure)
		quit(1)
