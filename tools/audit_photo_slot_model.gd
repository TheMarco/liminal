extends "res://tools/lib/audit_base.gd"
## Casino evidence must use the same current cabinet as ordinary furnishings.

func models(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in node.get_children():
		if child is Node3D and not child.scene_file_path.is_empty():
			expect(child.scene_file_path == Chunk.CASINO_SLOT_PATHS[0],
				"Unexpected casino anomaly model: " + child.scene_file_path)
			result.append(child)
		else:
			result.append_array(models(child))
	return result


func run() -> void:
	await _check_live_landing_collision()
	expect(Chunk.BLEED_PROPS[0][0] == Chunk.CASINO_SLOT_PATHS[0], "Casino bleed uses retired slot")
	var cases := 0
	var types := [PhotoAnomaly.Type.PLACEMENT, PhotoAnomaly.Type.DUPLICATE,
		PhotoAnomaly.Type.GIANT, PhotoAnomaly.Type.RING, PhotoAnomaly.Type.TURNED,
		PhotoAnomaly.Type.MISSING]
	for seed in [1, 21, 1175477015]:
		var ws := WorldGen.level_seed(seed, 0)
		for cell in [Vector2i.ZERO, Vector2i(-2, 3), Vector2i(41, 52)]:
			for kind in types:
				var anomaly := PhotoAnomaly.new()
				anomaly.configure("slot-test", kind, cell, ws, 0, 0, 6.0)
				var instances := models(anomaly)
				var count := 5 if kind == PhotoAnomaly.Type.RING else (
					2 if kind in [PhotoAnomaly.Type.DUPLICATE, PhotoAnomaly.Type.TURNED] else 1)
				expect(instances.size() == count, "Model missing or duplicated for type %s" % kind)
				if kind == PhotoAnomaly.Type.GIANT:
					var bounds := visual_bounds(anomaly)
					expect(bounds.end.y <= Chunk.cell_ceil_h(ws, cell, 0) - 0.24,
						"Replacement giant penetrates ceiling")
				if kind == PhotoAnomaly.Type.DUPLICATE and instances.size() == 2:
					var a := instances[0].get_parent() as Node3D
					var b := instances[1].get_parent() as Node3D
					# Measure the resized cabinets in their shared orientation, not
					# the retired full-scale spacing or diagonal world-space AABBs.
					var bounds_a := visual_bounds(a)
					var bounds_b: AABB = a.transform.affine_inverse() * b.transform * visual_bounds(b)
					expect(not bounds_a.grow(0.045).intersects(bounds_b.grow(0.045)),
						"Duplicate cabinets overlap or lack their 9cm gap")
				if kind == PhotoAnomaly.Type.PLACEMENT:
					var pivot := anomaly._placement_pivot
					expect(anomaly.find_children("*", "StaticBody3D", true, false).is_empty(),
						"ceiling-only cabinet blocks walking before landing")
					var floor_y := Chunk.cell_floor_h(ws, cell, 0)
					expect(anomaly._placement_rest_y >= floor_y and anomaly._placement_rest_y < floor_y + 0.02,
						"Cabinet landing origin does not match floor")
					var before := pivot.position.y
					anomaly.resolve(true)
					expect(pivot.position.y < before and is_equal_approx(pivot.position.y, anomaly._placement_rest_y),
						"Documented cabinet did not drop to floor")
					expect(models(anomaly).size() == 2, "Dropped cabinet lost modern lens/eye copies")
					var bodies := anomaly.find_children("*", "StaticBody3D", true, false)
					expect(bodies.size() == 1 and pivot.has_node("LandedCollision"),
						"landed eye-visible cabinet has no collision or lens copy gained collision")
					expect(anomaly.occlusion_excludes().size() == 1,
						"landed cabinet blocks the anomaly's own photo rays")
				anomaly.free()
				cases += 1
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("%d modern casino evidence cases, ceiling cap, duplicate spacing and restored drops" % cases)


func _check_live_landing_collision() -> void:
	var anomaly := PhotoAnomaly.new()
	anomaly.configure("live-slot-landing", PhotoAnomaly.Type.PLACEMENT,
		Vector2i.ZERO, WorldGen.level_seed(21, 0), 0, 0, 6.0)
	root.add_child(anomaly)
	var pivot := anomaly._placement_pivot
	anomaly.resolve()
	expect(await await_until(func(): return pivot.has_node("LandedCollision"), 2000),
		"animated cabinet landed without enabling collision")
	await create_timer(0.2).timeout
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS
	capsule.height = Player.BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	var forward := pivot.global_basis.z.normalized()
	forward.y = 0.0
	forward = forward.normalized()
	query.transform.origin = pivot.global_position + forward * 3.0 + Vector3.UP * 0.9
	query.motion = -forward * 6.0
	expect(root.world_3d.direct_space_state.cast_motion(query)[0] < 0.5,
		"player capsule walks through the landed photographed cabinet")
	var lens := anomaly.get_node("DocumentedCeilingPose")
	expect(lens.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"camera-only ceiling memory gained invisible collision")
	await teardown_game(anomaly)
