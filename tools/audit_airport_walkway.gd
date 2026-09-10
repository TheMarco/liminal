extends SceneTree
## Focused runtime audit for the authored airport moving walkway.

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("AIRPORT_WALKWAY_AUDIT: " + message)

func _init() -> void:
	call_deferred("run")

func _find_last_furnishing(chunk: Node, kind: String, length: float, flow: float) -> Node3D:
	var found: Node3D
	for node in chunk.find_children("*", "Node3D", true, false):
		if String(node.get_meta("atomic_furnishing", "")) == kind \
			and is_equal_approx(float(node.get_meta("walkway_length_m", -1.0)), length) \
			and is_equal_approx(float(node.get_meta("walkway_flow", 99.0)), flow):
			found = node
	return found

func _mesh_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var xform := mesh.transform
		var parent := mesh.get_parent()
		while parent != root:
			if parent is Node3D:
				xform = parent.transform * xform
			parent = parent.get_parent()
		for c in [mesh.get_aabb().position, mesh.get_aabb().end,
			mesh.get_aabb().position + Vector3(mesh.get_aabb().size.x, 0, 0),
			mesh.get_aabb().position + Vector3(0, mesh.get_aabb().size.y, 0),
			mesh.get_aabb().position + Vector3(0, 0, mesh.get_aabb().size.z)]:
			var p: Vector3 = xform * c
			check(p.is_finite(), "%s has non-finite bounds" % mesh.name)
			if not found:
				result = AABB(p, Vector3.ZERO)
				found = true
			else:
				result = result.expand(p)
	return result

func _audit_case(chunk: Chunk, length: float, yaw: float, flow: float) -> void:
	var pivot := _find_last_furnishing(chunk, "airport_travelator", length, flow)
	check(pivot != null, "missing walkway L%.1f yaw%.2f flow%.0f" % [length, yaw, flow])
	if pivot == null:
		return
	var belts := pivot.find_children("WalkwayBelt", "MeshInstance3D", true, false)
	check(belts.size() == 1, "expected one WalkwayBelt, got %d" % belts.size())
	if belts.size() == 1:
		var belt := belts[0] as MeshInstance3D
		check(belt.material_override is ShaderMaterial, "belt lacks ShaderMaterial override")
		check(is_equal_approx(float(belt.get_instance_shader_parameter("speed")), flow * 0.75), "belt speed mismatch")
	check(pivot.find_children("WalkwayGlass", "MeshInstance3D", true, false).size() == 1, "missing WalkwayGlass")
	var bounds := _mesh_bounds(pivot)
	check(bounds.size.x >= length + 1.10 and bounds.size.x <= length + 1.14, "length envelope %s" % bounds.size)
	check(bounds.size.z <= 1.85 and bounds.size.y <= 1.16 and bounds.position.y >= -0.002, "invalid envelope %s" % bounds)
	var group := int(pivot.get_meta("furnishing_group", -1))
	var colliders := []
	for node in chunk.body.get_children():
		if node is CollisionShape3D and int(node.get_meta("furnishing_group", -1)) == group:
			colliders.append(node)
	check(colliders.size() == 5, "expected five bound colliders, got %d" % colliders.size())
	var ramps := 0
	for c in colliders:
		if c.has_meta("walkable_ramp"):
			ramps += 1
	check(ramps == 2, "expected two walkable ramps, got %d" % ramps)
	var travelators := chunk.find_children("*", "Travelator", true, false)
	check(travelators.size() > 0, "missing Travelator area")
	if travelators.size() > 0:
		var tv := travelators[travelators.size() - 1] as Travelator
		var expected := Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
		check(tv.dirv.is_equal_approx(expected), "travel direction mismatch")
		check(is_equal_approx(tv.speed, 0.75), "travel speed mismatch")
		var shape := (tv.get_child(0) as CollisionShape3D).shape as BoxShape3D
		check(shape != null and shape.size.is_equal_approx(Vector3(length - 1.6, 1.6, 1.15)), "travel shape mismatch")

func _physics_case(yaw: float, flow: float) -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var tv := Travelator.new()
	tv.dirv = Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	tv.speed = 0.75
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(8.8, 1.6, 1.15)
	area_shape.shape = area_box
	tv.add_child(area_shape)
	tv.position = Vector3(0, 0.95, 0)
	tv.rotation.y = yaw
	holder.add_child(tv)
	var body := CharacterBody3D.new()
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 0.8
	body_shape.shape = capsule
	body.add_child(body_shape)
	body.position = Vector3(0, 0.8, 0)
	holder.add_child(body)
	await physics_frame
	var start := body.global_position
	for _i in 12:
		await physics_frame
	var delta := body.global_position - start
	var expected := Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	check(delta.dot(expected) > 0.05 and delta.dot(expected) < 0.30,
		"physics carry magnitude mismatch yaw%.2f flow%.0f: %s" % [yaw, flow, delta])
	check(absf(delta.y) < 0.001 and absf(delta.dot(Vector3(expected.z, 0, -expected.x))) < 0.001,
		"physics carry drift yaw%.2f flow%.0f: %s" % [yaw, flow, delta])
	holder.queue_free()
	await process_frame

func run() -> void:
	for length in [6.0, 8.4, 9.0, 9.4, 10.4]:
		for yaw in [0.0, PI / 2.0]:
			for flow in [-1.0, 1.0]:
				var chunk := Chunk.new(WorldGen.level_seed(9137, 4), Vector2i.ZERO, 4)
				chunk._level_builder._travelator(Vector3(6, 0, 6), yaw, flow, 7, length)
				_audit_case(chunk, length, yaw, flow)
				chunk.free()
	for yaw in [0.0, PI / 2.0]:
		for flow in [-1.0, 1.0]:
			await _physics_case(yaw, flow)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("AIRPORT_WALKWAY_AUDIT: failures=%d" % failures)
	quit(1 if failures else 0)
