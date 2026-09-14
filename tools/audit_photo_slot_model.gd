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
					expect(a.position.distance_to(b.position) >= 0.94, "Duplicate cabinets overlap")
				if kind == PhotoAnomaly.Type.PLACEMENT:
					var pivot := anomaly._placement_pivot
					var floor_y := Chunk.cell_floor_h(ws, cell, 0)
					expect(anomaly._placement_rest_y >= floor_y and anomaly._placement_rest_y < floor_y + 0.02,
						"Cabinet landing origin does not match floor")
					var before := pivot.position.y
					anomaly.resolve(true)
					expect(pivot.position.y < before and is_equal_approx(pivot.position.y, anomaly._placement_rest_y),
						"Documented cabinet did not drop to floor")
					expect(models(anomaly).size() == 2, "Dropped cabinet lost modern lens/eye copies")
				anomaly.free()
				cases += 1
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("%d modern casino evidence cases, ceiling cap, duplicate spacing and restored drops" % cases)
