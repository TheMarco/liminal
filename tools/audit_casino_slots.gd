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


func _init() -> void:
	call_deferred("run")


func run() -> void:
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
					check(world_bounds.position.y >= -0.002 and world_bounds.end.y <= ceiling - .10, "Floor/ceiling penetration")
					var local_bounds := collider.transform.affine_inverse() * world_bounds
					check(local_bounds.position.x >= -shape.size.x / 2.0 - .002 and local_bounds.end.x <= shape.size.x / 2.0 + .002, "Outside collider X")
					check(local_bounds.position.z >= -shape.size.z / 2.0 - .002 and local_bounds.end.z <= shape.size.z / 2.0 + .002, "Outside collider Z")
				check(triangles > 0 and triangles <= 5200, "Cabinet exceeded 5,200 triangles")
				totals[variant] = triangles
	chunk.free()
	var rooms := 0
	var machines := 0
	var kinds := {}
	var sign_rooms := {"single": 0, "merged": 0}
	for si in 4:
		ws = WorldGen.level_seed(WorldGen.h(920713, si * 43, si * 79, 2219) | 1, 0)
		for x in range(-5, 6):
			for z in range(-5, 6):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell or WorldGen.cell_style(ws, cell, 0) != WorldGen.STYLE_SLOTS:
					continue
				var generated := Chunk.new(ws, cell, 0)
				var sign_count := sign_support_checks(generated)
				var room_kind := "single" if generated.room_n == 1 else "merged"
				sign_rooms[room_kind] += sign_count
				check(generated.doorway_clearance_violations() == 0, "Casino doorway blocked")
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
	check(sign_rooms.single > 0 and sign_rooms.merged > 0, "Missing single/merged room sign coverage")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("CASINO_SLOTS: triangles=%s, 16 orientation/ceiling cases, %d rooms, %d cabinets, variants=%s, failures=%d" % [totals, rooms, machines, kinds, failures])
	print("SLOTS wall support: %s" % sign_rooms)
	quit(1 if failures else 0)
