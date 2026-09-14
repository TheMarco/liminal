extends "res://tools/lib/audit_base.gd"
## Full-room admission for the inverse photographic passage on every floor.
## -- --seed=21 --states=7. --allow-missing reports omitted sites for seed sweeps.

func run() -> void:
	var seeds: Array[int] = [21]
	var state_limit := 7
	var floor_filter := -1
	var planning_only := false
	var allow_missing := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seeds = [int(arg.trim_prefix("--seed="))]
		elif arg.begins_with("--states="):
			state_limit = clampi(int(arg.trim_prefix("--states=")), 1, 7)
		elif arg.begins_with("--floor="):
			floor_filter = int(arg.trim_prefix("--floor=")) - 1
		elif arg == "--planning-only":
			planning_only = true
		elif arg == "--allow-missing":
			allow_missing = true
	var checked := 0
	var missing := 0
	for requested_seed in seeds:
		var seed := FirstDoorStart.select_seed(requested_seed)
		expect(seed > 0, "requested seed %d failed new-run admission" % requested_seed)
		print("ADMISSION requested=%d actual=%d" % [requested_seed, seed])
		if seed <= 0:
			continue
		var order := DescentRun.order_for(seed)
		for floor_idx in order.size():
			if floor_filter >= 0 and floor_filter != floor_idx:
				continue
			var theme: int = order[floor_idx]
			var ws := WorldGen.level_seed(seed, theme)
			var label := "seed=%d floor=%d theme=%d" % [seed, floor_idx + 1, theme]
			var route := DescentRoute.build(ws, theme, floor_idx)
			var base_path := route.path_from_origin()
			var topology := DescentTopology.new(ws, theme)
			route.set_topology(topology)
			topology.plan_floor(route)
			var records := topology.photo_doorways().filter(func(r: Dictionary): return bool(r.get("obstruction", false)))
			if not allow_missing:
				expect(not records.is_empty(), label + " has no obstruction")
			expect(route.path_from_origin() == base_path, label + " ordinary route changed before photograph")
			if floor_idx == 0:
				expect(not topology.intro_photo_door().is_empty(), label + " lost introductory doorway")
			if records.is_empty():
				missing += 1
				print("SKIP " if allow_missing else "MISSING ", label, " no obstruction plan")
				continue
			expect(not base_path.is_empty() and base_path.back() == route.target, label + " has no ordinary route")
			for i in range(1, base_path.size()):
				var delta: Vector2i = base_path[i] - base_path[i - 1]
				var dir := WorldGen.DIRV.find(delta)
				expect(dir >= 0 and not topology.is_wall(base_path[i - 1], dir), label + " ordinary route blocked")
			var evidence := PhotoDirector.build_plan(route)
			var available := PhotoDirector.intro_route_evidence_count(route, evidence)
			expect(available >= PhotoDirector.required_for(floor_idx, theme), label + " shortcut strands evidence quota")
			if planning_only:
				print("PLAN %s evidence=%d/%d" % [label, available, PhotoDirector.required_for(floor_idx, theme)])
				continue
			var cm := ChunkManager.new()
			cm.world_seed = ws
			cm.theme = theme
			cm.descent = true
			cm.descent_floor_idx = floor_idx
			cm.descent_base_seed = seed
			cm.descent_route = route
			cm.descent_topology = topology
			var director := PhotoDirector.new()
			director.world_seed = ws
			director.theme = theme
			for record: Dictionary in records:
				var at: Vector2i = record["cell"]
				var other: Vector2i = at + WorldGen.DIRV[DescentTopology.edge_dir(record)]
				expect(int(record["saving"]) >= 4, label + " obstruction lacks useful shortcut")
				var clear_states := 0
				for state in mini(state_limit, topology.state_count()):
					var parts: Array[Chunk] = []
					var seen := {}
					for endpoint in [at, other]:
						for member in WorldGen.owning_room_members(ws, endpoint, theme):
							if not seen.has(member):
								seen[member] = true
								parts.append(cm._build(member, false, state))
					var clear := director._photo_door_approach_clear(record, parts)
					expect(clear, "%s state=%d obstructed approach at %s" % [label, state, at])
					if clear:
						clear_states += 1
					elif state == 0:
						_report_blockers(record, parts, ws, theme)
					await _check_imported_passage(record, parts, label + " state=%d" % state, ws, theme)
					for part in parts:
						stop_audio(part)
						part.free()
					checked += 1
				print("OBSTRUCTION %s cell=%s clear_states=%d/%d" % [label, at, clear_states, mini(state_limit, topology.state_count())])
			director.free()
			cm.free()
			await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("all-floor photographic obstruction: %d full-room state checks, %d missing plans" % [checked, missing])


func _check_imported_passage(record: Dictionary, parts: Array[Chunk], label: String, ws: int, theme: int) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	get_root().add_child(viewport)
	var container := Node3D.new()
	viewport.add_child(container)
	var seals: Array[PhotoDoorSeal] = []
	var depth := 0.0
	for part in parts:
		container.add_child(part)
		for seal in part.photo_door_seals():
			if seal.photo_id != str(record["id"]):
				continue
			seals.append(seal)
			depth = maxf(depth, float(seal.get("obstruction_depth")))
			expect(_imported_mesh_count(seal.fill, label + " fill") > 0, label + " lacks imported obstruction meshes")
			expect(seal.barrier.get_child_count() > 0, label + " lacks obstruction collision")
			for shape in seal.barrier.get_children():
				expect(shape is CollisionShape3D and shape.shape != null
					and (shape.shape is ConvexPolygonShape3D or shape.shape is ConcavePolygonShape3D),
					label + " obstruction collision is not derived from mesh geometry")
			var ghost := PhotoObstruction.ghost(seal.fill)
			expect(_imported_mesh_count(ghost, label + " ghost") > 0, label + " lacks imported reveal meshes")
			ghost.free()
	await physics_frame
	await physics_frame
	expect(seals.size() == 2, label + " does not have both obstruction endpoints")
	expect(depth > 0.0 and depth < 6.0, label + " invalid obstruction depth %f" % depth)
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var d: Vector2i = WorldGen.DIRV[dir]
	var forward := Vector3(d.x, 0.0, d.y)
	var tangent := Vector3(absf(forward.z), 0.0, absf(forward.x))
	var t := float(record["t"])
	var centre := Vector3(at.x * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 0 else t),
		Chunk.cell_floor_h(ws, at, theme), at.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 2 else t))
	for sign_value in [-1.0, 1.0]:
		var stance: Vector3 = centre + forward * 6.0 * sign_value + Vector3.UP * 0.15
		expect(ArrivalSafety.is_clear(container.get_world_3d(), stance)
			and ArrivalSafety.has_floor(container.get_world_3d(), stance),
			"%s six-metre stance is not walkable on side %s" % [label, sign_value])
	if not seals.is_empty():
		var extent: float = seals[0].width * 0.5 - ArrivalSafety.RADIUS - 0.04
		var samples := maxi(2, ceili(extent * 2.0 / 0.2))
		var space := container.get_world_3d().direct_space_state
		var capsule := CapsuleShape3D.new()
		capsule.radius = ArrivalSafety.RADIUS
		capsule.height = ArrivalSafety.HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.motion = forward * (depth + 0.7) * 2.0
		for open in [false, true]:
			if open:
				for seal in seals:
					seal.open()
				await physics_frame
				await physics_frame
			for i in range(samples + 1):
				var lateral := lerpf(-extent, extent, float(i) / float(samples))
				query.transform = Transform3D(Basis.IDENTITY, centre + tangent * lateral
					- forward * (depth + 0.7) + Vector3.UP * (ArrivalSafety.HEIGHT * 0.5 + 0.05))
				var motion := space.cast_motion(query)
				expect(not motion.is_empty(), label + " capsule sweep returned no fractions")
				if motion.is_empty():
					continue
				expect(motion[0] >= 0.999 if open else motion[0] < 0.999,
					"%s capsule lane %.2f is %s" % [label, lateral,
					"blocked after photograph" if open else "passable before photograph"])
	for part in parts:
		container.remove_child(part)
	viewport.free()


func _imported_mesh_count(node: Node, label: String) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += 1
		expect(node.mesh != null and not node.mesh is PrimitiveMesh, label + " contains a primitive visual mesh")
		var source := str(node.get_meta("source_scene", ""))
		expect(source.begins_with("res://") and ResourceLoader.exists(source), label + " mesh lacks existing-model provenance")
	for child in node.get_children():
		count += _imported_mesh_count(child, label)
	return count


func _report_blockers(record: Dictionary, parts: Array[Chunk], ws: int, theme: int) -> void:
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var d: Vector2i = WorldGen.DIRV[dir]
	var forward := Vector3(d.x, 0.0, d.y)
	var t := float(record["t"])
	var centre := Vector3(at.x * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 0 else t),
		Chunk.cell_floor_h(ws, at, theme), at.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE if dir == 2 else t))
	var extent := forward.abs() * 6.4 + Vector3(absf(forward.z), 0.0, absf(forward.x)) * 1.45
	var passage := AABB(centre - extent + Vector3.UP * 0.03, extent * 2.0 + Vector3.UP * 2.32)
	var blockers: Array[String] = []
	for part in parts:
		_walk_blockers(part, Transform3D.IDENTITY, passage, str(part.cell), blockers)
	for blocker in blockers.slice(0, 6):
		print("BLOCKER ", blocker)


func _walk_blockers(node: Node, parent: Transform3D, passage: AABB, path: String, out: Array[String]) -> void:
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
			out.append("%s/%s bounds=%s" % [path, node.name, bounds])
	for child in node.get_children():
		_walk_blockers(child, transform, passage, path + "/" + str(node.name), out)
