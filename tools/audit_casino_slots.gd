extends SceneTree
## Authored slot budget, shared resources, display materials and floor/ceiling
## collision coverage, followed by seeded real-room layout/culling checks.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CASINO_SLOTS: " + message)


func local_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current := node
	while current != ancestor:
		xf = current.transform * xf
		current = current.get_parent() as Node3D
	return xf


func sign_support_checks(chunk: Chunk) -> int:
	var signs := 0
	for label in chunk.find_children("*", "Label3D", true, false):
		if label.text != "S L O T S":
			continue
		signs += 1
		var xf := local_transform(label, chunk)
		for other in chunk.find_children("*", "Label3D", true, false):
			var neon := false
			for entry in Chunk.CASINO_NEON:
				neon = neon or other.text == entry[0]
			if not neon:
				continue
			var relative: Vector3 = xf.affine_inverse() * local_transform(other, chunk).origin
			check(not (absf(relative.x) < 1.5 and absf(relative.y) < 0.5 and absf(relative.z) < 0.15),
				"Overlapping casino signs: seed=%d cell=%s text=%s" % [chunk.wseed, chunk.cell, other.text])
		# Probe behind both ends of the letters and their lower neon tube.
		# Actual wall collision must support the complete sign, even when the
		# room's cabinets have been shifted away from the furnishing anchor.
		for x in [-0.9, 0.0, 0.9]:
			for y in [0.0, -0.32]:
				var point := xf * Vector3(x, y, -0.10)
				var supported := false
				for collider in chunk.body.get_children():
					if not collider is CollisionShape3D or not collider.shape is BoxShape3D:
						continue
					var local: Vector3 = collider.transform.affine_inverse() * point
					var half: Vector3 = collider.shape.size * 0.5
					if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
						supported = true
						break
				check(supported, "Floating SLOTS sign: seed=%d cell=%s room=%d point=%s" % [
					chunk.wseed, chunk.cell, chunk.room_n, point])
	return signs


func no_detached_header_checks(chunk: Chunk) -> void:
	for node in chunk.find_children("*", "Node3D", true, false):
		check(not node.has_meta("slot_bank_header_fixture"),
			"Detached slot-bank header geometry returned")
		check(str(node.get_meta("visible_source", "")) != "slot_bank_header_rail",
			"Detached slot-bank header light returned")


func sign_art_checks(chunk: Chunk) -> void:
	for label in chunk.find_children("*", "Label3D", true, false):
		if label.text != "S L O T S": continue
		var sign_xf := local_transform(label, chunk)
		# Reserve the lettering and its underline in the wall plane. Label3D
		# bounds can still be empty while streamed construction is off-tree.
		var sign_rect := Rect2(-1.2, -0.36, 2.4, 0.72)
		for mount in chunk.get_children():
			if not mount.has_meta("wall_art_mount"): continue
			var relative: Transform3D = sign_xf.affine_inverse() * mount.transform
			if absf(relative.origin.z) > 0.3 or absf(relative.basis.z.z) < 0.99: continue
			var size: Vector2 = mount.get_meta("wall_art_size")
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for x in [-0.5, 0.5]:
				for y in [-0.5, 0.5]:
					var p := relative * Vector3(x * size.x, y * size.y, 0)
					lo = lo.min(Vector2(p.x, p.y))
					hi = hi.max(Vector2(p.x, p.y))
			check(not sign_rect.intersects(Rect2(lo, hi - lo)),
				"SLOTS overlaps painting: seed=%d cell=%s art=%s" % [chunk.wseed, chunk.cell, mount.position])


func stool_collision_checks(chunk: Chunk) -> int:
	var seats: Array[CollisionShape3D] = []
	var count := 0
	for node in chunk.get_children():
		if str(node.get_meta("attributed_furnishing", "")) != "casino_slot_stool":
			continue
		count += 1
		var group := int(node.get_meta("furnishing_group", -1))
		check(group >= 0, "Stool has no atomic collision group")
		if group < 0: continue
		var shapes := 0
		for collider in chunk.body.get_children():
			if int(collider.get_meta("furnishing_group", -2)) != group: continue
			shapes += 1
			check(collider.shape is CylinderShape3D, "Stool must have a round collision footprint")
			if collider.shape is CylinderShape3D: seats.append(collider)
			check(Vector2(collider.position.x, collider.position.z).distance_to(
				Vector2(node.position.x, node.position.z)) < 0.001,
				"Stool collider detached from visible seat")
		check(shapes == 1, "Visible stool has %d colliders" % shapes)
	for i in seats.size():
		for j in range(i + 1, seats.size()):
			var separation := Vector2(seats[i].position.x, seats[i].position.z).distance_to(
				Vector2(seats[j].position.x, seats[j].position.z))
			var gap: float = separation - seats[i].shape.radius - seats[j].shape.radius
			check(gap >= Player.BODY_RADIUS * 2.0 + 0.025,
				"Stool gap too narrow for player: %.3fm, seed=%d cell=%s" % [gap, chunk.wseed, chunk.cell])
	check(chunk.atomic_furnishing_support_violations() == 0,
		"Casino furnishing lost its support or left orphan collision")
	return count


func stool_walk_checks() -> void:
	var chunk := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
	# Outside the generated room: exercise the real imported stool and physics
	# without unrelated walls/furniture blocking the player's sweep.
	for i in 2:
		chunk._level_builder._slot_stool(Vector3(50.0 + 1.32 * i, 0, 50.0), 0.25 * i)
	root.add_child(chunk)
	await physics_frame
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS
	capsule.height = Player.BODY_HEIGHT
	query.shape = capsule
	query.collision_mask = 1
	query.margin = 0.001
	query.motion = Vector3(0, 0, 4)
	var space := root.world_3d.direct_space_state
	for x in [50.0, 51.32]:
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, Player.BODY_HEIGHT * 0.5 + 0.01, 48))
		var sweep := space.cast_motion(query)
		check(sweep[0] < 0.5, "Player capsule can walk through slot stool")
	query.transform.origin.x = 50.66
	check(space.cast_motion(query)[0] > 0.99, "Player cannot pass between neighbouring stools")
	chunk.free()


func streamed_sign_checks() -> void:
	# This generated room had overlapping SLOTS and BUFFET before the fix.
	var layouts: Array = []
	for sliced in [false, true]:
		var chunk := Chunk.new(756105833, Vector2i(4, -4), 0, null, sliced)
		if sliced:
			while not chunk.build_next_slice(): pass
		check(sign_support_checks(chunk) == 1, "reproducing room lost its SLOTS sign")
		sign_art_checks(chunk)
		var layout: Array[String] = []
		for label in chunk.find_children("*", "Label3D", true, false):
			layout.append(str(label.text) + str(local_transform(label, chunk)))
		layout.sort()
		layouts.append(layout)
		chunk.free()
	check(layouts[0] == layouts[1], "sliced construction changed casino sign placement")
	# Production streaming assigns the world offset BEFORE the decoration pass.
	# This room placed a painting over SLOTS only with that construction order.
	for sliced in [false, true]:
		var cell := Vector2i(-5, -4)
		var chunk := Chunk.new(651258107, cell, 0, null, sliced)
		chunk.position = Vector3(cell.x * WorldGen.CELL_SIZE, 0, cell.y * WorldGen.CELL_SIZE)
		if sliced:
			while not chunk.build_next_slice(): pass
		sign_art_checks(chunk)
		check(sign_support_checks(chunk) > 0, "painting overlap fixture lost its sign")
		var moved_bounds := chunk._wall_mount_blockers()
		chunk.position = Vector3.ZERO
		check(moved_bounds == chunk._wall_mount_blockers(), "wall fixture bounds depend on chunk position")
		chunk.free()


func _init() -> void:
	call_deferred("run")


func run() -> void:
	await stool_walk_checks()
	var ws := WorldGen.level_seed(4242, 0)
	var chunk := Chunk.new(ws, Vector2i.ZERO, 0)
	var shared := {}
	var totals := {}
	for variant in 4:
		var path := Chunk.CASINO_SLOT_PATHS[variant]
		check(Chunk._prop_preload_paths().has(path), "Missing startup preload")
		check(Chunk.theme_prop_paths(0).has(path), "Missing casino preload")
		for ceiling in [2.4, 3.2]:
			chunk._build_context._ceiling_height = ceiling
			for facing in [-1.0, 1.0]:
				var first := chunk.get_child_count()
				var b0 := chunk.body.get_child_count()
				chunk._level_builder._authored_slot_machine(6.0, 6.0, facing, 0, variant)
				var pivot := chunk.get_child(first) as Node3D
				check(pivot.get_meta("authored_asset", "") == path, "Authored model fell back")
				check(pivot.get_meta("slot_variant", -1) == variant, "Wrong variant")
				check(pivot.get_meta("atomic_furnishing", "") == "casino_slot", "Missing atomic culling")
				var collider := chunk.body.get_child(b0) as CollisionShape3D
				check(collider.get_meta("furnishing_group", -1) == pivot.get_meta("furnishing_group", -2), "Orphan cabinet collider")
				var shape := collider.shape as BoxShape3D
				var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
				check(meshes.size() == (5 if variant < 2 else 4), "Unexpected merged mesh count")
				var triangles := 0
				for mi: MeshInstance3D in meshes:
					check(mi.mesh.get_surface_count() == 1, "Extra material surfaces")
					var key := str(variant) + str(mi.name)
					if shared.has(key):
						check(shared[key] == mi.mesh, "Repeated cabinets duplicate geometry")
					else:
						shared[key] = mi.mesh
					var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
					check(mat != null, "Missing standard glTF material")
					if mi.name == "Displays":
						check(mat.albedo_texture != null and mat.emission_texture != null and mat.emission_enabled, "Unlit or untextured screens")
						check(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Screens should be opaque")
					var arrays := mi.mesh.surface_get_arrays(0)
					if mi.name == "Displays" or mi.name == "PrintedGlass":
						for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
							check(normal.z > 0.8, "Display faces away from the player")
					triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
					var xf := pivot.transform * local_transform(mi, pivot)
					var world_bounds := xf * mi.mesh.get_aabb()
					check(world_bounds.position.y >= -0.002 and world_bounds.end.y <= ceiling - Chunk.CASINO_SLOT_HEADROOM + .002, "Floor/ceiling clearance")
					var local_bounds := collider.transform.affine_inverse() * world_bounds
					check(local_bounds.position.x >= -shape.size.x / 2.0 - .002 and local_bounds.end.x <= shape.size.x / 2.0 + .002, "Outside collider X")
					check(local_bounds.position.z >= -shape.size.z / 2.0 - .002 and local_bounds.end.z <= shape.size.z / 2.0 + .002, "Outside collider Z")
				check(triangles > 0 and triangles <= 5200, "Cabinet exceeded 5,200 triangles")
				totals[variant] = triangles
	chunk.free()
	var rooms := 0
	var machines := 0
	var stools := 0
	var kinds := {}
	var sign_rooms := {"single": 0, "merged": 0}
	var fixture_probe := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
	fixture_probe._level_builder._slots()
	no_detached_header_checks(fixture_probe)
	fixture_probe.free()
	for si in 4:
		ws = WorldGen.level_seed(WorldGen.h(920713, si * 43, si * 79, 2219) | 1, 0)
		for x in range(-5, 6):
			for z in range(-5, 6):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell or WorldGen.cell_style(ws, cell, 0) != WorldGen.STYLE_SLOTS:
					continue
				var generated := Chunk.new(ws, cell, 0)
				var sign_count := sign_support_checks(generated)
				sign_art_checks(generated)
				var room_kind := "single" if generated.room_n == 1 else "merged"
				sign_rooms[room_kind] += sign_count
				check(generated.doorway_clearance_violations() == 0, "Casino doorway blocked")
				stools += stool_collision_checks(generated)
				check(generated.slot_back_violations() == 0 and generated.slot_front_violations() == 0, "Missing cabinet volume")
				for node in generated.get_children():
					if node.has_meta("slot_machine"):
						var kind := int(node.get_meta("slot_variant", -1))
						check(kind >= 0, "Legacy cabinet survived replacement")
						kinds[kind] = int(kinds.get(kind, 0)) + 1
						machines += 1
				rooms += 1
				generated.free()
	check(rooms > 0 and machines > 0 and kinds.size() == 4, "Missing generated cabinet variety")
	check(stools > 0, "Missing generated stool collision coverage")
	check(sign_rooms.single > 0 and sign_rooms.merged > 0, "Missing single/merged room sign coverage")
	streamed_sign_checks()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("CASINO_SLOTS: triangles=%s, 16 orientation/ceiling cases, %d rooms, %d cabinets, variants=%s, failures=%d" % [totals, rooms, machines, kinds, failures])
	print("SLOTS wall support: %s" % sign_rooms)
	quit(1 if failures else 0)
