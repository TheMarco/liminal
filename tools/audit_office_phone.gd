extends SceneTree
## Supplied vintage desk phone: asset budget, floor origin and Office placement.
## godot --headless --path . --script tools/audit_office_phone.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("OFFICE_PHONE: " + message)


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
	var path := Chunk.OFFICE_PHONE_PATH
	check(ResourceLoader.exists(path), "missing supplied phone GLB")
	check(Chunk._prop_preload_paths().has(path), "missing startup preload")
	check(Chunk.theme_prop_paths(1).has(path), "missing Office preload")
	for other_theme in [0, 2, 4, 5, 6, 7, 8, 9, 10, 11]:
		check(not Chunk.theme_prop_paths(other_theme).has(path),
			"phone leaked into theme %d preload" % other_theme)

	var packed := load(path) as PackedScene
	check(packed != null, "phone GLB failed to load")
	if packed == null:
		quit(1)
		return
	var source := packed.instantiate() as Node3D
	var bounds := visual_bounds(source)
	check(bounds.position.is_equal_approx(Vector3(-0.216606, 0.0, -0.1290)),
		"imported origin changed: %s" % bounds)
	check(bounds.size.is_equal_approx(Vector3(0.353606, 0.1650, 0.2500)),
		"imported dimensions changed: %s" % bounds)
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "phone must remain one mesh")
	var triangles := 0
	var surfaces := 0
	for mesh_instance: MeshInstance3D in meshes:
		surfaces += mesh_instance.mesh.get_surface_count()
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(triangles > 0 and triangles <= 5000,
		"phone exceeds 5,000-triangle budget: %d" % triangles)
	check(surfaces == 1, "phone must retain one material surface")
	source.free()

	var chunk := Chunk.new(WorldGen.level_seed(4242, 1), Vector2i.ZERO, 1)
	var workstation := Node3D.new()
	chunk.add_child(workstation)
	var body_before := chunk.body.get_child_count()
	for qi in 64:
		chunk._level_builder._office_desk_phone(
			workstation, Vector3(6, 0, 6), 0.0, qi)
		if workstation.get_child_count() > 0:
			break
	check(workstation.get_child_count() == 1, "builder never placed a phone")
	check(chunk.body.get_child_count() == body_before,
		"desk phone unexpectedly created standalone collision")
	if workstation.get_child_count() == 1:
		var pivot := workstation.get_child(0) as Node3D
		check(pivot.get_meta("attributed_furnishing", "") == "office_phone",
			"Office phone metadata changed")
		var instance := pivot.get_child(0) as Node3D
		check(instance != null and instance.get_meta("attributed_asset", "") == path,
			"Office phone still uses the former model")
		var placed_bounds := visual_bounds(pivot)
		check(absf(placed_bounds.position.y) <= 0.0001,
			"phone does not sit on its tabletop origin: %s" % placed_bounds)
		check(absf(placed_bounds.get_center().x) <= 0.0001
			and absf(placed_bounds.get_center().z) <= 0.0001,
			"phone footprint is not centred: %s" % placed_bounds)
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("OFFICE_PHONE: %s triangles=%d surfaces=%d failures=%d" % [
		"PASS" if failures == 0 else "FAIL", triangles, surfaces, failures])
	quit(1 if failures else 0)
