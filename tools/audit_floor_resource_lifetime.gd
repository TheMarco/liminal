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
	expect(FloorResourcePreloader.cached_scene(Chunk.GARBAGE_BIN_PATH) != null,
		"airport bin was not ready for streaming")
	first.free()
	second.free()
	for theme in [1, 6]:
		Chunk.prepare_floor_resources(theme)
		expect(FloorResourcePreloader.cached_scene(Chunk.OFFICE_SCHOOL_BIN_PATH) != null,
			"floor %d did not prepare its indoor wastebasket" % theme)
		if theme == 6:
			expect(FloorResourcePreloader.cached_scene(Chunk.OFFICE_TERMINAL_PATH) != null,
				"school admin office would synchronously load its terminal")
			_expect_cc0_ready("school", ["office_notepads"])
			_expect_prepared_chair()
	Chunk.prepare_floor_resources(2)
	_expect_cc0_ready("annex", ["sofa_03", "drawer_cabinet", "ArmChair_01",
		"Ottoman_01", "CoffeeTable_01", "coffee_table_round_01", "television_02"])
	Chunk.prepare_floor_resources(7)
	expect(FloorResourcePreloader.cached_scene(Chunk.GARBAGE_BIN_PATH) != null,
		"mall bin was not ready for streaming")
	_expect_cc0_ready("mall", ["CashRegister_01", "hand_truck", "metal_trash_can",
		"industrial_storage_cart"])
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


func _expect_prepared_chair() -> void:
	for suffix in ["Base_Color", "Normal", "Roughness", "Metallic"]:
		var path := "res://models/cc0/office_chair/Office_Chair_%s.png" % suffix
		expect(ResourceLoader.has_cached(path),
			"the first school desk chair would load its %s map during play" % suffix)
	var scene := FloorResourcePreloader.cached_scene(Chunk.OFFICE_CHAIR_PATH)
	if scene == null:
		fail("the school desk chair was not prepared")
		return
	var chair := scene.instantiate()
	var meshes := chair.find_children("*", "MeshInstance3D", true, false)
	expect(not meshes.is_empty(), "the prepared desk chair has no mesh")
	for mesh: MeshInstance3D in meshes:
		var mat := mesh.material_override as StandardMaterial3D
		expect(mat != null and mat.albedo_texture != null and mat.normal_enabled
			and mat.normal_texture != null and mat.roughness_texture != null
			and mat.metallic_texture != null, "the prepared desk chair lost its fitted material")
	chair.free()


func _expect_cc0_ready(floor_name: String, models: Array[String]) -> void:
	for model in models:
		var path := "res://models/cc0/%s/%s_1k.gltf" % [model, model]
		expect(FloorResourcePreloader.cached_scene(path) != null,
			"%s room construction would synchronously load %s" % [floor_name, model])
