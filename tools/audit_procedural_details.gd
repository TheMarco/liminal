extends SceneTree
## Verify material batching, cache reuse and transformed primitive geometry.


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var first := Node3D.new()
	var second := Node3D.new()
	var steel := StandardMaterial3D.new()
	var dark := StandardMaterial3D.new()
	ProceduralDetails.attach(first, "audit", func(d: ProceduralDetails):
		d.box(Vector3.ZERO, Vector3.ONE, steel, 0.02)
		d.box(Vector3(1, 0, 0), Vector3.ONE * 0.2, steel)
		d.tube(Vector3(0, 0, 0), Vector3(0, 0, 2), 0.05, steel)
		d.ring(Vector3(0, 1, 0), 0.3, 0.02, dark, Vector3.FORWARD))
	ProceduralDetails.attach(second, "audit", func(_d: ProceduralDetails):
		assert(false, "A cached design should not rebuild"))
	assert(first.get_child_count() == 2, "One draw per material")
	assert(second.get_child_count() == 2, "Cached design lost a material")
	for i in 2:
		var a := first.get_child(i) as MeshInstance3D
		var b := second.get_child(i) as MeshInstance3D
		assert(a.mesh == b.mesh, "Repeated designs must share meshes")
		assert(a.mesh.get_surface_count() == 1)
		var arrays := a.mesh.surface_get_arrays(0)
		assert(arrays[Mesh.ARRAY_VERTEX].size() > 0)
		assert(arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size())
	var bounds: AABB = first.get_child(0).mesh.get_aabb()
	assert(bounds.end.x > 1.09 and bounds.end.z > 1.99,
		"Primitive transforms were lost during batching")
	assert(first.find_children("*", "CollisionObject3D", true, false).is_empty())
	_audit_surface_wear_exclusion(steel)
	first.free()
	second.free()
	ProceduralDetails.clear_runtime_cache()
	await process_frame
	print("procedural details: PASS (batching, transforms, cache reuse, SurfaceWear exclusion)")
	quit()


## Batched trim can span the empty space between its parts, so its combined
## AABB must never replace the bounds of the original furnishing mesh used by
## SurfaceWear. Exercise the scanner directly with a real ChunkBuildContext so
## the fixture follows the same prop-discovery path as a generated chunk.
func _audit_surface_wear_exclusion(material: Material) -> void:
	var wear_was_enabled := SurfaceWear.enabled
	SurfaceWear.enabled = false
	var chunk := Chunk.new(WorldGen.level_seed(4242, 1), Vector2i.ZERO, 1)
	var prop := Node3D.new()
	prop.position = Vector3(2.0, 0.0, 3.0)
	prop.set_meta("surface_wear_prop", "procedural_detail_audit")
	chunk.add_child(prop)
	var original := MeshInstance3D.new()
	var original_mesh := BoxMesh.new()
	original_mesh.size = Vector3(0.8, 1.2, 0.6)
	original.mesh = original_mesh
	original.material_override = material
	original.position = Vector3(0.15, 0.6, -0.10)
	prop.add_child(original)

	var before := SurfaceWear.new()
	before.host = chunk
	before.ctx = chunk._build_context
	before._scan(prop, Transform3D.IDENTITY, -1)
	assert(before.props.size() == 1 and before.props[0].meshes.size() == 1,
		"Original furnishing mesh was not eligible for SurfaceWear")
	var before_entry: Dictionary = before.props[0].meshes[0]
	var before_bounds: AABB = before_entry.transform * original.mesh.get_aabb()

	ProceduralDetails.attach(prop, "audit_surface_wear_exclusion", func(d: ProceduralDetails):
		d.box(Vector3(-3, 2, 0), Vector3(0.1, 0.1, 0.1), material)
		d.box(Vector3(3, 2, 0), Vector3(0.1, 0.1, 0.1), material))
	var detail_meshes := prop.find_children("*", "MeshInstance3D", true, false)
	assert(detail_meshes.size() == 2,
		"SurfaceWear fixture did not contain the expected original and detail meshes")
	assert(detail_meshes.any(func(mesh: MeshInstance3D):
		return mesh.has_meta("procedural_detail")),
		"SurfaceWear fixture did not contain a tagged procedural detail mesh")
	var spanning_detail: MeshInstance3D
	for mesh: MeshInstance3D in detail_meshes:
		if mesh.has_meta("procedural_detail"):
			spanning_detail = mesh
			break
	assert(spanning_detail.mesh.get_aabb().size.x > before_bounds.size.x * 5.0,
		"SurfaceWear fixture detail does not exercise the combined-AABB regression")

	var after := SurfaceWear.new()
	after.host = chunk
	after.ctx = chunk._build_context
	after._scan(prop, Transform3D.IDENTITY, -1)
	assert(after.props.size() == 1 and after.props[0].meshes.size() == 1,
		"Procedural detail mesh entered SurfaceWear furnishing candidates")
	var after_entry: Dictionary = after.props[0].meshes[0]
	var after_bounds: AABB = after_entry.transform * original.mesh.get_aabb()
	assert(after_entry.mesh == original,
		"Procedural detail displaced the original SurfaceWear mesh candidate")
	assert(after_entry.transform.is_equal_approx(before_entry.transform),
		"Procedural detail changed the original SurfaceWear mesh transform")
	assert(after_bounds.is_equal_approx(before_bounds),
		"Procedural detail changed the original SurfaceWear furnishing bounds")
	chunk.free()
	SurfaceWear.enabled = wear_was_enabled
