extends SceneTree
## Shared structural modules must stay bounded, survive dressing eviction, and
## preserve roof/floor placement at different room heights and orientations.
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func run() -> void:
	for theme in [8,5,7,10]:
		ProceduralDetails.clear_runtime_cache()
		var roof_meshes := {}
		var heights := {}
		var ws := WorldGen.level_seed(1315734997,theme)
		for x in range(-3,4):
			for z in range(-2,3):
				var chunk := Chunk.new(ws,Vector2i(x,z),theme,null,true)
				var builder: RefCounted = chunk._level_builder
				heights[chunk.ceil_h] = true
				match theme:
					8:
						builder._prison_architecture()
						builder._prison_wall_finish(0,12,0,12,0,chunk.ceil_h)
						var roof: Node3D = chunk.get_node("PrisonRoofStructure")
						check(is_equal_approx(roof.position.y,chunk.ceil_h),"Prison roof datum changed")
						check(is_zero_approx(chunk.get_node("PrisonFloorInlays").position.y),"Prison floor inlay moved with roof")
						for mesh in roof.get_children():
							if mesh is MeshInstance3D:
								roof_meshes[mesh.mesh.get_instance_id()] = true
								var bounds: AABB = roof.transform * mesh.mesh.get_aabb()
								check(bounds.position.y >= chunk.ceil_h-0.30,"Prison ceiling arches returned")
					5:
						builder._asy_architecture()
						builder._asy_moulded_wall(Vector3.ZERO,0,7.3,0,chunk.ceil_h)
						check(is_equal_approx(chunk.get_node("AsylumCeilingJoinery").position.y,chunk.ceil_h),"Asylum roof datum changed")
						for mesh in chunk.get_node("AsylumCeilingJoinery").get_children():
							var bounds: AABB = mesh.mesh.get_aabb()
							check(bounds.position.y >= -0.12,"Asylum ceiling arches returned")
						var bed := Node3D.new()
						bed.transform = Transform3D(Basis.from_euler(Vector3(0,0.7,0)).scaled(Vector3(0.73,1.2,1.1)),Vector3(2,0,3))
						chunk.add_child(bed)
						builder._asy_privacy_track(bed,Vector3(4,0,5),PI/2)
						var privacy: Node3D = bed.get_node("WardPrivacyRail")
						for group in privacy.get_children():
							for mesh in group.get_children():
								var bounds: AABB = (bed.transform * privacy.transform * group.transform) * mesh.mesh.get_aabb()
								check(bounds.end.y<=chunk.ceil_h+0.01,"Privacy rail protrudes through ceiling")
								if mesh.get_meta("procedural_detail")=="ward_curtain_template":
									check(absf(bounds.position.y-1.2)<0.001,"Privacy curtain lost its floor clearance")
									check(absf(bounds.end.y-(chunk.ceil_h-0.12))<0.001,"Privacy curtain no longer meets its rail")
					7:
						builder._mall_floor_ceiling()
						for width in [3.3,6.7,12.0]:
							builder._mall_upper_gallery(0,12,6,width)
						var architecture: Node3D = chunk.get_node("MallArchitecture")
						if chunk.style == WorldGen.MALL_SERVICE:
							check(is_equal_approx(architecture.position.y,chunk.ceil_h),"Mall service ceiling datum changed")
						else:
							check(is_zero_approx(architecture.position.y),"Mall floor inlays moved")
							if chunk.style == WorldGen.MALL_ATRIUM and chunk.ceil_h > 5.5:
								check(is_equal_approx(architecture.get_node("MallCeilingModules").position.y,chunk.ceil_h),"Mall skylight datum changed")
							else:
								check(not architecture.has_node("MallCeilingModules"),"Mall grid returned across the ceiling lights")
					10:
						builder._data_center_structure()
						for width in [1.4,3.3,6.7,12.0]:
							builder._data_center_wall_finish(0,12,0,width,0,chunk.ceil_h)
						for node in chunk.find_children("*","MultiMeshInstance3D",true,false):
							check(node.multimesh.instance_count > 0,"Empty data-center batch")
							for i in node.multimesh.instance_count:
								check(node.multimesh.get_instance_transform(i).basis.determinant()>0,"Invalid module scale")
				chunk.free()
		check(heights.size()>2,"Height coverage missing for theme %d" % theme)
		check(ProceduralDetails._floor_templates.size()<=30,"Unbounded structural variants for theme %d" % theme)
		if theme == 8: check(roof_meshes.size()==1,"Prison ceiling services were baked again for a different height")
		var count := ProceduralDetails._floor_templates.size()
		var parent := Node3D.new()
		for i in ProceduralDetails.MAX_CACHED_DESIGNS+1:
			ProceduralDetails.attach(parent,"disposable_%d" % i,func(_d: ProceduralDetails): pass)
		check(ProceduralDetails._floor_templates.size()==count,"Dressing evicted structural modules")
		parent.free()
		print("TEMPLATE_THEME ",theme," heights=",heights.size()," shared=",count)
		await process_frame
	var organic := preload("res://scripts/props/organic_architecture.gd")
	organic.clear_runtime_cache()
	organic.prewarm()
	var prepared: int = organic._structural_cache.size()
	for i in 100:
		var height := 3.17+float(i)*0.08
		for variant in 6:
			organic.canopy(organic.canopy_height(height),variant,false)
			organic.membranes(organic.membrane_height(height),variant,false)
			organic.wall(organic.wall_width(1.1+float(i)*0.11),4.0,variant)
	check(organic._structural_cache.size()==prepared,"Bloom generated new structural meshes after preparation")
	organic.clear_runtime_cache()
	check(organic._structural_cache.is_empty(),"Bloom meshes survive floor teardown")
	Mats.clear_runtime_caches()
	SurfaceWear.prepare_floor()
	for mask_id in 8:
		var material := SurfaceWear._patch_material(SurfaceWear.Motif.SPILL,mask_id,"")
		check(material.get_shader_parameter("stain_mask") != null,"Damp mask missing after preparation")
		check(material.get_shader_parameter("damp_spread") == true,"Damp mask lost spreading")
		check(material == SurfaceWear._patch_material(SurfaceWear.Motif.SPILL,mask_id,""),"Wear material was rebuilt")
	var dry := SurfaceWear._patch_material(SurfaceWear.Motif.SPILL,-1,"")
	check(dry.get_shader_parameter("damp_spread") == false,"Drink spill became a damp stain")
	var authored := SurfaceWear._patch_material(SurfaceWear.Motif.LEAK,-1,"res://textures/annex/wall_seep_01.png")
	check(authored.get_shader_parameter("authored_mask") == true,"Authored Annex mask lost")
	var mall := preload("res://scripts/levels/mall_level_builder.gd")
	mall.prewarm_resources()
	for index in Chunk.MALL_SIGN_FACES.size():
		check(mall._painted_sign_materials[index] != null,"Mall sign missing after preparation")
	for path in Chunk.POSTER_MALL:
		check(Mats._wall_art_textures.has(path),"Mall poster missing after preparation")
	var paths := Chunk.theme_prop_paths(8)
	for model in ["plunger","drain_cleaner","wall_clock","industrial_storage_cart","metal_trash_can","security_camera_01"]:
		check(paths.has("res://models/cc0/%s/%s_1k.gltf" % [model,model]),"Prison manifest omits "+model)
	check(paths.size()<=FloorResourcePreloader.CACHE_LIMIT,"Prison preload manifest exceeds retention capacity")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	check(ProceduralDetails._floor_templates.is_empty(),"Structural modules survive floor teardown")
	check(mall._painted_sign_materials.is_empty(),"Sign materials survive floor teardown")
	print("OVERHAUL_TEMPLATES ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
