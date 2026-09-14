extends SceneTree
## Rebuilt wall payphone: budget, wall plane, bank placement and collision.
## godot --headless --path . --script tools/audit_mall_payphone.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("MALL_PAYPHONE: " + message)


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
	var path := Chunk.MALL_PAYPHONE_PATH
	check(ResourceLoader.exists(path), "missing supplied payphone GLB")
	check(Chunk._prop_preload_paths().has(path), "missing startup preload")
	check(Chunk.theme_prop_paths(7).has(path), "missing mall preload")
	for other_theme in [0, 1, 2, 4, 5, 6, 8, 9, 10, 11]:
		check(not Chunk.theme_prop_paths(other_theme).has(path),
			"payphone leaked into theme %d preload" % other_theme)

	var packed := load(path) as PackedScene
	check(packed != null, "payphone GLB failed to load")
	if packed == null:
		quit(1)
		return
	var source := packed.instantiate() as Node3D
	var bounds := visual_bounds(source)
	check(bounds.position.is_equal_approx(Vector3(-0.137556, -0.123692, -0.0001)),
		"imported wall plane or origin changed: %s" % bounds)
	check(bounds.size.is_equal_approx(Vector3(0.255056, 0.763692, 0.377794)),
		"imported dimensions changed: %s" % bounds)
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "payphone must remain one mesh")
	var triangles := 0
	var surfaces := 0
	for mesh_instance: MeshInstance3D in meshes:
		surfaces += mesh_instance.mesh.get_surface_count()
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(triangles > 0 and triangles <= 5000,
		"payphone exceeds 5,000-triangle budget: %d" % triangles)
	check(surfaces == 1, "payphone must retain one material surface")
	source.free()

	var banks := 0
	for dir in 4:
		var test_seed := 4242 + dir
		var chunk := Chunk.new(WorldGen.level_seed(test_seed, 7), Vector2i.ZERO, 7)
		while chunk._level_builder.ctx.random01(40 + dir) < 0.52:
			chunk.free()
			test_seed += 4
			chunk = Chunk.new(WorldGen.level_seed(test_seed, 7), Vector2i.ZERO, 7)
		var first := chunk.get_child_count()
		var body_first := chunk.body.get_child_count()
		chunk._level_builder._mall_payphone_bank(dir, 1)
		check(chunk.get_child_count() == first + 1,
			"bank must add one visual root on wall %d" % dir)
		check(chunk.body.get_child_count() == body_first + 1,
			"bank must add one collider on wall %d" % dir)
		if chunk.get_child_count() != first + 1 \
				or chunk.body.get_child_count() != body_first + 1:
			chunk.free()
			continue
		var bank := chunk.get_child(first) as Node3D
		check(bank.get_child_count() == 1, "mall wall must carry one phone, not a bank, on wall %d" % dir)
		check(is_equal_approx(float(bank.get_meta("mall_payphone_span", 0.0)), 1.45),
			"phones remain crowded on wall %d" % dir)
		var fixture_roll: float = chunk._level_builder.ctx.random01(40 + dir)
		if fixture_roll < 0.96:
			var poster_along: float = lerpf(3.3, 8.7,
				chunk._level_builder.ctx.random01(1610 + dir))
			check(absf(float(bank.get_meta("mall_payphone_along", 0.0)) - poster_along) >= 2.7,
				"phone bank can overlap poster on wall %d" % dir)
		var collider := chunk.body.get_child(body_first) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		check(shape != null and shape.size.is_equal_approx(Vector3(0.32, 0.80, 0.40)),
			"bank collider does not match rebuilt phones")
		for phone in bank.get_children():
			var model := phone as Node3D
			check(model.get_meta("authored_model", "") == "payphone",
				"mall fixture audit metadata changed")
			check(model.get_meta("attributed_asset", "") == path,
				"old mall payphone model survived replacement")
			check(model.position.y + 0.30 < Player.CAM_H,
				"handset focal area is not below player eye level")
			for mesh_instance: MeshInstance3D in model.find_children(
					"*", "MeshInstance3D", true, false):
				var world_bounds := local_transform(mesh_instance, chunk) \
					* mesh_instance.mesh.get_aabb()
				var collider_space := collider.transform.affine_inverse() * world_bounds
				var half := shape.size * 0.5
				for corner in 8:
					var point := collider_space.get_endpoint(corner)
					check(absf(point.x) <= half.x + 0.002
						and absf(point.y) <= half.y + 0.002
						and absf(point.z) <= half.z + 0.002,
						"phone escapes bank collider on wall %d" % dir)
		banks += 1
		chunk.free()

	# A wall-length storefront must reject the bank rather than share geometry.
	var blocked_seed := 5000
	var blocked := Chunk.new(WorldGen.level_seed(blocked_seed, 7), Vector2i.ZERO, 7)
	while blocked._level_builder.ctx.random01(40) >= 0.52:
		blocked.free()
		blocked_seed += 1
		blocked = Chunk.new(WorldGen.level_seed(blocked_seed, 7), Vector2i.ZERO, 7)
	var blocked_children := blocked.get_child_count()
	var blocked_colliders := blocked.body.get_child_count()
	check(not blocked._level_builder._mall_payphone_bank(0, 1),
		"storefront wall accepted a phone bank")
	check(blocked.get_child_count() == blocked_children
		and blocked.body.get_child_count() == blocked_colliders,
		"rejected phone bank left partial geometry")
	blocked.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("MALL_PAYPHONE: %s banks=%d triangles=%d surfaces=%d failures=%d" % [
		"PASS" if failures == 0 else "FAIL", banks, triangles, surfaces, failures])
	quit(1 if failures else 0)
