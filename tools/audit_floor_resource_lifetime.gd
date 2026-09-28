extends "res://tools/lib/audit_base.gd"

func run() -> void:
	Chunk.prepare_floor_resources(0)
	var first := Chunk.new(WorldGen.level_seed(240721, 0), Vector2i.ZERO, 0)
	var material := Mats.paint_white()
	var old_mesh := (first.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var old_shape := old_mesh.get_aabb()
	expect(not Mats._c.is_empty(), "fixture did not populate material cache")
	Chunk.prepare_floor_resources(4)
	expect(Mats._c.is_empty() and Chunk._attributed_scenes.is_empty()
		and Chunk._asy_scenes.is_empty() and Chunk._cc0_scenes.is_empty(),
		"previous floor retained shared resources")
	expect(is_instance_valid(old_mesh) and old_mesh.get_aabb() == old_shape,
		"retirement changed a live preview's mesh")
	expect(is_instance_valid(material) and Mats.paint_white() != material,
		"retirement invalidated a live material or reused the retired cache")
	var second := Chunk.new(WorldGen.level_seed(240721, 4), Vector2i.ZERO, 4)
	first.free()
	second.free()
	var keep := ShadowWalkerVisual._model_scene(0)
	var retired := ShadowWalkerVisual._model_scene(9)
	var live_actor := retired.instantiate()
	ShadowWalkerVisual.retain_models([0])
	expect(ShadowWalkerVisual._model_scenes.get(0) == keep,
		"shared actor was unnecessarily retired")
	expect(not ShadowWalkerVisual._model_scenes.has(9), "inactive signature model remained cached")
	expect(is_instance_valid(live_actor) and live_actor.get_child_count() > 0,
		"retirement invalidated an active actor")
	live_actor.free()
	ShadowWalkerVisual.clear_runtime_caches()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("floor resource lifetime")
