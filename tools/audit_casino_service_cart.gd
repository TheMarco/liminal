extends SceneTree
## Imported room-service trolley, placement, resource budget and collision.
## godot --headless --path . --script tools/audit_casino_service_cart.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CASINO_SERVICE_CART: " + message)


func local_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node3D = node
	while current != ancestor:
		transform = current.transform * transform
		current = current.get_parent() as Node3D
	return transform


func visual_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for mesh_instance: MeshInstance3D in root.find_children(
			"*", "MeshInstance3D", true, false):
		var actual := local_transform(mesh_instance, root) * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(actual) if found else actual
		found = true
	return bounds


func run() -> void:
	var path := Chunk.CASINO_SERVICE_CART_PATH
	check(ResourceLoader.exists(path), "missing imported GLB")
	check(Chunk._prop_preload_paths().has(path), "missing startup preload")
	check(Chunk.theme_prop_paths(0).has(path), "missing Vegas preload")

	var packed := load(path) as PackedScene
	check(packed != null, "GLB failed to load")
	if packed == null:
		quit(1)
		return
	var source := packed.instantiate() as Node3D
	var source_bounds := visual_bounds(source)
	check(source_bounds.position.is_equal_approx(Vector3(-0.5878, 0.0004, -0.2580)),
		"imported origin or floor alignment changed: %s" % source_bounds)
	check(source_bounds.size.is_equal_approx(Vector3(1.0168, 1.1926, 0.5180)),
		"imported dimensions changed: %s" % source_bounds)
	var triangles := 0
	var surfaces := 0
	for mesh_instance: MeshInstance3D in source.find_children(
			"*", "MeshInstance3D", true, false):
		surfaces += mesh_instance.mesh.get_surface_count()
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(triangles > 0 and triangles <= 6000,
		"trolley exceeds 6,000-triangle budget: %d" % triangles)
	check(surfaces <= 12, "unexpected material/surface count: %d" % surfaces)
	source.free()

	var chunk := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
	var first := chunk.get_child_count()
	var body_first := chunk.body.get_child_count()
	var at := Vector3(6, 0, 6)
	chunk._level_builder._casino_service_cart(at, 7)
	check(chunk.get_child_count() == first + 1,
		"service cart must be one atomic furnishing")
	check(chunk.body.get_child_count() == body_first + 1,
		"service cart must own one conservative collider")
	if chunk.get_child_count() == first + 1:
		var pivot := chunk.get_child(first) as Node3D
		check(pivot.get_meta("attributed_furnishing", "") == "casino_service_cart",
			"procedural cart survived replacement")
		check(pivot.position.is_equal_approx(at), "placement anchor moved")
		var instance := pivot.get_child(0) as Node3D
		check(instance != null and instance.get_meta("attributed_asset", "") == path,
			"furnishing does not contain the supplied GLB")
		var placed_bounds := visual_bounds(pivot)
		check(absf(placed_bounds.position.y) <= 0.001,
			"trolley is not floor aligned: %s" % placed_bounds)
		check(absf(placed_bounds.get_center().x) <= 0.001
			and absf(placed_bounds.get_center().z) <= 0.001,
			"trolley footprint is not centred: %s" % placed_bounds)
		if chunk.body.get_child_count() == body_first + 1:
			var collider := chunk.body.get_child(body_first) as CollisionShape3D
			var shape := collider.shape as BoxShape3D
			check(shape != null and shape.size.is_equal_approx(Vector3(1.08, 0.84, 0.6)),
				"legacy gameplay collider changed")
			check(collider.get_meta("furnishing_group", -1) ==
				pivot.get_meta("furnishing_group", -2),
				"collider and visual will not cull together")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("CASINO_SERVICE_CART: %s triangles=%d surfaces=%d failures=%d" % [
		"PASS" if failures == 0 else "FAIL", triangles, surfaces, failures])
	quit(1 if failures else 0)
