extends RefCounted
## Opaque, folded kentia leaves and stems are shared geometry. The planter uses
## the same materials and collider as the other mall furnishings.

static func build(scene: ChunkSceneWriter, p: Vector3, yaw: float) -> void:
	var mark := scene.collider_mark()
	var root := scene.furnishing_pivot(p, yaw, "mall_palm_planter")
	scene.model_cylinder(root, Vector3(0, 0.06, 0), 0.30, 0.12, Mats.mall_rose_stone())
	scene.model_cylinder(root, Vector3(0, 0.34, 0), 0.31, 0.50, Mats.mall_ceramic(true))
	scene.model_cylinder(root, Vector3(0, 0.60, 0), 0.27, 0.035, Mats.darkwood())
	var packed := scene.prop_scene(Chunk.MALL_PALM_CROWN_PATH)
	if packed != null:
		var crown := packed.instantiate() as Node3D
		crown.get_node("Rim").material_override = Mats.mall_brass()
		crown.get_node("Stems").material_override = Mats.mall_palm_stem()
		crown.get_node("Spines").material_override = Mats.plant()
		crown.get_node("Leaves").material_override = Mats.mall_palm_leaf()
		root.add_child(crown)
	# The same collision envelope as the former potted plant. Flexible leaves
	# stay above the player's shoulders and never create an invisible barrier.
	scene.collider_cylinder(p + Vector3(0, 0.5, 0), 0.32, 1.0)
	scene.bind_furnishing_colliders(root, mark)
