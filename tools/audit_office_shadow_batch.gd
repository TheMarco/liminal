extends "res://tools/lib/audit_base.gd"
const BATCH = preload("res://scripts/office_shadow_batch.gd")

func world_faces(model: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for part in model.find_children("*","MeshInstance3D",true,false):
		for vertex in part.mesh.get_faces(): result.append(part.global_transform*vertex)
	return result

func run() -> void:
	for path in BATCH.PATHS:
		var cached: Mesh
		for placement in 2:
			var model := (load(path) as PackedScene).instantiate() as Node3D
			root.add_child(model)
			model.position = Vector3(3,1,-7)*placement
			model.rotation.y = 0.73*placement
			model.scale = Vector3(1.2,0.8,1.6) if placement else Vector3.ONE
			var before := world_faces(model)
			var materials := {}
			for part in model.find_children("*","MeshInstance3D",true,false):
				var surfaces := []
				for i in part.mesh.get_surface_count(): surfaces.append(part.get_active_material(i))
				materials[part] = surfaces
			var proxy := BATCH.install(model,path)
			expect(proxy != null,"eligible model failed to batch: "+path)
			if proxy != null:
				var after := proxy.mesh.get_faces()
				expect(after.size()==before.size(),"shadow triangle count changed")
				for i in mini(before.size(),after.size()):
					if before[i].distance_to(proxy.global_transform*after[i])>0.0001:
						fail("shadow vertex moved: "+path)
						break
				expect(proxy.mesh.get_surface_count()==1,"shadow parts were not combined")
				expect(proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					and proxy.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"proxy renders twice")
				if placement: expect(proxy.mesh==cached,"fitted instances did not share cached geometry")
				else: cached = proxy.mesh
				for part in materials:
					expect(part.visible and part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
						"visible part hidden or duplicate shadow retained")
					for i in materials[part].size():
						expect(part.get_active_material(i)==materials[part][i],"visible material changed")
			model.free()
	# A source with a transparent or special material must retain its own shadows.
	var path: String = BATCH.PATHS[0]
	var special := (load(path) as PackedScene).instantiate() as Node3D
	var part: MeshInstance3D = special.find_children("*","MeshInstance3D",true,false)[0]
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part.material_override = glass
	expect(BATCH.install(special,path)==null,"transparent surface was batched")
	expect(part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"fallback changed caster")
	special.free()
	BATCH.clear_cache()
	finish("Office shadow batching: exact transformed triangles, cached placements, materials and fallback")
