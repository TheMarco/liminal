extends "res://tools/lib/audit_base.gd"
## Office and School must use the compact supplied wastebasket without changing
## the larger public cans used by Airport and Mall.


func _model_path(pivot: Node3D) -> String:
	for child in pivot.find_children("*", "Node3D", true, false):
		if child is Node3D and not (child as Node3D).scene_file_path.is_empty():
			return (child as Node3D).scene_file_path
	return ""


func _group_colliders(chunk: Chunk, pivot: Node3D) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	var group := int(pivot.get_meta("furnishing_group", -1))
	for child in chunk.body.get_children():
		if child is CollisionShape3D \
				and int(child.get_meta("furnishing_group", -2)) == group:
			found.append(child)
	return found


func run() -> void:
	var chunk := Chunk.new(120914, Vector2i.ZERO, 1, {}, true)
	for kind in ["office_bin", "school_bin"]:
		var p := Vector3(3.0 if kind == "office_bin" else 7.0, 0, 4.0)
		var pivot: Node3D = chunk._waste_bin(p, 0.37, kind)
		expect(pivot != null, "%s failed to load" % kind)
		if pivot == null:
			continue
		expect(_model_path(pivot) == Chunk.OFFICE_SCHOOL_BIN_PATH,
			"%s did not use supplied model" % kind)
		expect(bool(pivot.get_meta("project_provided_asset", false)),
			"%s lost project-provided provenance" % kind)
		var bounds := visual_bounds(pivot)
		expect(absf(bounds.position.y) <= 0.01,
			"%s is not floor-aligned: %s" % [kind, bounds])
		expect(bounds.size.y >= 0.30 and bounds.size.y <= 0.33,
			"%s changed scale: %s" % [kind, bounds])
		var colliders := _group_colliders(chunk, pivot)
		expect(colliders.size() == 1,
			"%s lacks one grouped collider" % kind)
		if colliders.size() == 1:
			var shape := colliders[0].shape as CylinderShape3D
			expect(shape != null and shape.radius <= 0.14 and shape.height <= 0.32,
				"%s collider is too obstructive" % kind)

	var public_bin: Node3D = chunk._waste_bin(Vector3(10, 0, 4), 0.0,
		"airport_bin")
	expect(public_bin != null and _model_path(public_bin) == Chunk.GARBAGE_BIN_PATH,
		"Airport public bin was replaced outside requested scope")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("Office and School supplied bins: model, scale, floor support, collision and scope")
