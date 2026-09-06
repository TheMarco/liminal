extends SceneTree
## Verify outfit selection, mesh reuse, budget and rotated collision coverage.
## godot --headless --path . --script tools/audit_mall_garment_rack.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MALL_RACK_AUDIT: " + message)


func local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


func run() -> void:
	check(Chunk._prop_preload_paths().has(Chunk.MALL_GARMENT_RACK_PATH), "Missing startup preload")
	check(Chunk.theme_prop_paths(7).has(Chunk.MALL_GARMENT_RACK_PATH), "Missing mall preload")
	var ws := WorldGen.level_seed(4242, 7)
	var chunk := Chunk.new(ws, Vector2i.ZERO, 7)
	var seen_meshes := {}
	var style_counts := {}
	var shared_material: Material
	var totals := {}
	for salt in range(7, 15):
		for yaw in [0.0, PI / 2.0, PI, 0.37]:
			var first := chunk.get_child_count()
			var body_first := chunk.body.get_child_count()
			chunk._level_builder._mall_rack(Vector3(6, 0, 6), yaw, salt)
			check(chunk.get_child_count() == first + 1, "Missing rack assembly")
			if chunk.get_child_count() != first + 1:
				continue
			var pivot := chunk.get_child(first) as Node3D
			var style := str(pivot.get_meta("garment_style", ""))
			var expected := "casual" if WorldGen.h(ws, 0, 0, salt) % 2 else "formal"
			check(style == expected, "Outfit selection changed with orientation")
			style_counts[style] = int(style_counts.get(style, 0)) + 1
			check(pivot.get_meta("atomic_furnishing", "") == "mall_garment_rack",
				"Rack is missing its atomic furnishing identity")
			check(chunk.body.get_child_count() == body_first + 1, "Expected one simple collider")
			if chunk.body.get_child_count() != body_first + 1:
				continue
			var collider := chunk.body.get_child(body_first) as CollisionShape3D
			check(collider.get_meta("furnishing_group", -1) == pivot.get_meta("furnishing_group", -2),
				"Visuals and collision do not cull together")
			var shape := collider.shape as BoxShape3D
			check(shape != null, "Expected box collision")
			var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
			check(meshes.size() == 2, "Unused outfit remains in the instance")
			var absent := "ClothesFormal" if style == "casual" else "ClothesCasual"
			check(pivot.find_child(absent, true, false) == null, "Unused outfit was only hidden")
			var total := 0
			for mi: MeshInstance3D in meshes:
				check(mi.mesh.get_surface_count() == 1, "Mesh has extra material surfaces")
				var key := str(mi.name)
				if seen_meshes.has(key):
					check(seen_meshes[key] == mi.mesh, "Repeated racks duplicate mesh resources")
				else:
					seen_meshes[key] = mi.mesh
				var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
				check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
					"Baked textures are missing")
				if shared_material == null:
					shared_material = mat
				else:
					check(mat == shared_material, "Frame and outfits must share one material")
				var arrays := mi.mesh.surface_get_arrays(0)
				total += arrays[Mesh.ARRAY_INDEX].size() / 3
				if shape != null:
					var xf := collider.transform.affine_inverse() * pivot.transform * local_transform(mi, pivot)
					var bounds := xf * mi.mesh.get_aabb()
					check(bounds.position.x >= -shape.size.x / 2.0 - 0.002 and bounds.end.x <= shape.size.x / 2.0 + 0.002,
						"Rack extends outside collision along X")
					check(bounds.position.y >= -shape.size.y / 2.0 - 0.002 and bounds.end.y <= shape.size.y / 2.0 + 0.002,
						"Rack extends outside collision vertically")
					check(bounds.position.z >= -shape.size.z / 2.0 - 0.002 and bounds.end.z <= shape.size.z / 2.0 + 0.002,
						"Rack extends outside collision along Z")
			check(total > 0 and total <= 7000, "Rack exceeded its 7,000-triangle budget")
			totals[style] = total
	check(style_counts.size() == 2, "Did not exercise both clothing arrangements")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("MALL_RACK_AUDIT: triangles=%s, 32 placements, shared mesh/material resources, failures=%d" % [totals, failures])
	quit(1 if failures else 0)
