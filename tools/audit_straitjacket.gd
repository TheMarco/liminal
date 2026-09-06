extends SceneTree
## Verify the imported prop's budget, shared resources and four wall mounts.
## godot --headless --path . --script tools/audit_straitjacket.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("STRAITJACKET_AUDIT: " + message)


func run() -> void:
	check(Chunk.theme_prop_paths(5).has(Chunk.ASY_STRAITJACKET_PATH),
		"Missing asylum preload")
	check(Chunk._prop_preload_paths().has(Chunk.ASY_STRAITJACKET_PATH),
		"Missing startup preload")
	var chunk := Chunk.new(WorldGen.level_seed(4242, 5), Vector2i.ZERO, 5)
	var shared_mesh: Mesh
	var triangles := 0
	for dir in 4:
		var first := chunk.get_child_count()
		chunk._level_builder._asy_straitjacket(dir, 0.075)
		check(chunk.get_child_count() == first + 1, "Missing wall mount")
		if chunk.get_child_count() != first + 1:
			continue
		var mount := chunk.get_child(first) as Node3D
		var meshes := mount.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 1, "Prop must use one mesh")
		check(mount.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Wall decoration added a collider")
		if meshes.size() != 1:
			continue
		var mi := meshes[0] as MeshInstance3D
		check(mi.mesh.get_surface_count() == 1, "Prop must use one material surface")
		if shared_mesh == null:
			shared_mesh = mi.mesh
		else:
			check(shared_mesh == mi.mesh, "Wall copies must share their mesh")
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
			"Baked canvas textures are missing")
		if mat != null and mat.albedo_texture != null:
			check(mat.albedo_texture.get_width() == 1024, "Expected 1K texture atlas")
		var arrays := mi.mesh.surface_get_arrays(0)
		triangles = arrays[Mesh.ARRAY_INDEX].size() / 3
		check(triangles > 0 and triangles <= 5000, "Exceeded 5,000-triangle prop budget")
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != mount:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var bounds := xf * mi.mesh.get_aabb()
		check(bounds.position.z >= -0.001, "Geometry penetrates its mounting wall")
		check(bounds.position.y > 0.85 and bounds.end.y < 2.15,
			"Garment left its intended wall height")
		check(bounds.size.x < 1.05 and bounds.size.z < 0.32,
			"Prop exceeds its wall footprint")
		var outward: Vector3 = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][dir]
		check((mount.basis * Vector3.BACK).dot(outward) > 0.999,
			"Fastenings face the wall on direction %d" % dir)
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("STRAITJACKET_AUDIT: %d triangles, 1 mesh/material, 4 wall directions, failures=%d" % [triangles, failures])
	quit(1 if failures else 0)
