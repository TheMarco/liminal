extends SceneTree
## Validate real builder orientation, floor contact and collision containment.
func _init() -> void:
	call_deferred("run")

func mesh_bounds(node: Node3D, xf: Transform3D, out: Array[AABB]) -> void:
	xf *= node.transform
	if node is MeshInstance3D and node.mesh != null:
		out.append(xf * node.mesh.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			mesh_bounds(child, xf, out)

func run() -> void:
	var stats = JSON.parse_string(FileAccess.get_file_as_string(
		"res://models/authored/vegas_change_machine/mesh_stats.json"))
	assert(stats.triangles <= 3000 and stats.surfaces == 2)
	for dir in 4:
		var chunk := Chunk.new(918273, Vector2i.ZERO, 0)
		var first := chunk.get_child_count()
		var collider_first := chunk.body.get_child_count()
		var plane := Chunk.S - Chunk.T / 2.0 if dir == 0 or dir == 2 else Chunk.T / 2.0
		chunk._level_builder._change_machine(dir, plane)
		var fixture := chunk.get_child(first) as Node3D
		assert(fixture.get_meta("attributed_furnishing") == "casino_change_machine")
		assert(chunk.body.get_child_count() == collider_first + 1)
		var solid := chunk.body.get_child(collider_first) as CollisionShape3D
		var bounds: Array[AABB] = []
		mesh_bounds(fixture, Transform3D.IDENTITY, bounds)
		assert(bounds.size() == 2)
		var inverse := solid.transform.affine_inverse()
		var half: Vector3 = solid.shape.size / 2.0
		for box in bounds:
			assert(box.position.y >= -0.001)
			for i in 8:
				var corner := inverse * box.get_endpoint(i)
				assert(absf(corner.x) <= half.x + .002)
				assert(absf(corner.y) <= half.y + .002)
				assert(absf(corner.z) <= half.z + .002)
			match dir:
				0: assert(box.end.x <= Chunk.S - Chunk.T)
				1: assert(box.position.x >= Chunk.T)
				2: assert(box.end.z <= Chunk.S - Chunk.T)
				3: assert(box.position.z >= Chunk.T)
		chunk.free()
	print("VEGAS_CHANGE_MACHINE PASS: all four walls, grounded, collider contains model, triangle budget respected")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
