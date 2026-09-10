extends SceneTree
## Authored desk geometry, staff orientation and atomic collider registration.
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("GATE_DESK_AUDIT: " + message)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	check(Chunk.theme_prop_paths(4).has(Chunk.AIRPORT_GATE_DESK_PATH), "Missing airport prefetch")
	check(Chunk._prop_preload_paths().has(Chunk.AIRPORT_GATE_DESK_PATH), "Missing global prefetch")
	for orientation in 4:
		var chunk := Chunk.new(WorldGen.level_seed(4242, 4), Vector2i.ZERO, 4)
		var first := chunk.get_child_count()
		var yaw := orientation * PI / 2.0
		chunk._level_builder._air_gate_desk(Vector3(6, 0, 6), yaw, "B12")
		var pivot: Node3D
		for i in range(first, chunk.get_child_count()):
			var node := chunk.get_child(i)
			if String(node.get_meta("atomic_furnishing", "")) == "airport_gate_desk": pivot = node
		check(pivot != null, "Gate desk not registered as one furnishing")
		if pivot == null:
			chunk.free()
			continue
		var screens := pivot.find_child("GateDeskScreens", true, false) as MeshInstance3D
		check(screens != null, "Missing staff displays")
		if screens != null:
			var arrays := screens.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_INDEX].size() == 12, "Expected two screen quads")
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				check(normal.dot(Vector3.BACK) > 0.99, "Screen faces passengers instead of staff")
		var group := int(pivot.get_meta("furnishing_group"))
		var colliders := 0
		for node in chunk.body.get_children():
			if node is CollisionShape3D and int(node.get_meta("furnishing_group", -1)) == group:
				colliders += 1
				var local: Vector3 = pivot.transform.affine_inverse() * node.position
				check(absf(local.x) < 1.25 and absf(local.z) < 0.65,
					"A rotated desk collider left the model footprint")
		check(colliders == 9, "Desk visual and collider group are incomplete")
		chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("GATE_DESK_AUDIT: failures=%d" % failures)
	quit(1 if failures else 0)
