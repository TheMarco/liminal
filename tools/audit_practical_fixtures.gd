extends "res://tools/lib/audit_base.gd"
## The emitter contract is geometric, not just a source-name tag. Exercise
## real generated rooms, dead fittings, flicker and power restoration.

func run() -> void:
	var checked := 0
	var flickering := 0
	var dead := 0
	for theme in [0,2,4,5,6,7,8,10,11]:
		var ws := WorldGen.level_seed(240721,theme)
		var samples := {}
		var dead_salt: int = {0:8,2:8,4:8,5:8,6:8,7:1600,8:1800,10:2120,11:3300}[theme]
		var flicker_salt: int = {0:9,2:9,4:9,5:9,6:9,7:1601,8:1801,10:2121,11:3301}[theme]
		for x in range(-12,13):
			for z in range(-12,13):
				var at := Vector2i(x,z)
				var style := WorldGen.cell_style(ws,at,theme)
				if not samples.has(style): samples[style] = at
				if theme==2:
					if WorldGen.annex_light_gap(ws,at): samples["gap"] = at
					elif WorldGen.annex_dim_zone(ws,at): samples["dim"] = at
				if theme in [4,7] and Chunk.cell_ceil_h(ws,at,theme)>5.5 and not samples.has(-style):
					samples[-style] = at
				if at != Vector2i.ZERO and WorldGen.r01(ws,x,z,dead_salt) < 0.01:
					samples["dead"] = at
				elif at != Vector2i.ZERO and WorldGen.r01(ws,x,z,flicker_salt) < 0.1:
					samples["flicker"] = at
		for key in samples:
			var chunk := Chunk.new(ws,samples[key],theme)
			root.add_child(chunk)
			var fixtures := 0
			var live_lenses := 0
			var shafts := 0
			var lamps: Array[Light3D] = []
			var skylights: Array[Light3D] = []
			for node in chunk.find_children("*","Node3D",true,false):
				if node.has_meta("practical_fixture"):
					fixtures += 1
					for lens in node.get_children():
						if not lens is MeshInstance3D: continue
						var mat = lens.get_active_material(0)
						if mat is StandardMaterial3D and mat.emission_enabled and mat.emission_energy_multiplier>0:
							live_lenses += 1
				if node.get_meta("airport_ceiling_fixture","") == "light": fixtures += 1
				if node.has_meta("airport_grand_ceiling"): fixtures += 16
				if not node is Light3D or not node.has_meta("fixture_emitter"): continue
				var light = node
				if light is SpotLight3D: shafts += 1
				lamps.append(light)
				if light.get_meta("visible_source","") == "mall_laylight": skylights.append(light)
				var emitter := light.get_node_or_null(light.get_meta("fixture_emitter")) as MeshInstance3D
				expect(emitter != null,"fixture lost its visible emitter")
				if emitter == null: continue
				var relative: Transform3D = light.get_parent().global_transform.affine_inverse()*emitter.global_transform
				var bounds: AABB = relative*emitter.get_aabb()
				var upward: bool = light.get_meta("fixture_upward",false)
				if light.get_meta("visible_source","") == "airport_grand_coffer":
					_check_coffer_face(light,emitter,relative)
					# Each source is a real rim segment in a shared batched mesh.
					var size := Vector3(light.area_size.x,0,light.area_size.y)
					bounds = AABB(light.get_meta("fixture_face")-size*0.5,size)
				var face := bounds.get_center()
				face.y = bounds.end.y if upward else bounds.position.y
				var expected := face+Vector3.UP*(0.015 if upward else -0.03)
				if light is OmniLight3D:
					expect(light.get_meta("fixture_volume",false),"omnidirectional light has no glowing volume")
					expected = bounds.get_center()
				expect(light.position.distance_to(expected)<0.001,"theme %d style %d %s: light %s displaced from face %s"%[theme,chunk.style,light.get_meta("visible_source"),light.position,expected])
				if not light is OmniLight3D:
					expect((-light.basis.z).dot(Vector3.UP if upward else Vector3.DOWN)>0.999,"fixture shines through its opaque back")
				if light is AreaLight3D:
					expect(light.area_size.distance_to(Vector2(bounds.size.x,bounds.size.z))<0.001,"theme %d %s: highlight %s differs from lens %s"%[theme,light.get_meta("visible_source"),light.area_size,bounds.size])
				var material := emitter.get_active_material(0) as StandardMaterial3D
				expect(material != null and material.emission_enabled and material.emission_energy_multiplier>0.0,"powered lens is dark")
				expect(light.light_specular>0.0,"fixture no longer reflects on glossy surfaces")
				var energy: float = light.light_energy
				GraphicsQuality.apply_practical_light(light,{"shadow_quality":0})
				expect(light.shadow_enabled and light.light_energy==energy,"Low allows fixture light through walls")
				expect(light.shadow_opacity==1.0 and light.distance_fade_shadow>=light.distance_fade_begin,"fixture blocker fades before its light")
				GraphicsQuality.apply_practical_light(light,{"shadow_quality":3})
				expect(light.shadow_enabled,"Ultra allows fixture light through walls")
				if upward:
					var ceiling: float = 3.2 if theme==11 and chunk.style==WorldGen.BLOOM_PASSAGE else chunk.ceil_h
					expect(chunk.to_local(light.global_position).y<ceiling-0.2,"upper diffuser is buried in the ceiling")
					expect(light.area_range>ceiling-chunk.to_local(light.global_position).y+0.5,
						"upper diffuser cuts off before spreading across its ceiling")
				else:
					var reach: float = light.omni_range if light is OmniLight3D else (light.spot_range if light is SpotLight3D else light.area_range)
					expect(reach>chunk.to_local(light.global_position).y+0.5,"ceiling fitting cuts off before reaching the floor")
				expect(energy>0.0,"live fitting has no output")
				checked += 1
			expect(fixtures>0 or theme==10 or (theme==2 and chunk.get_meta("annex_light_gap",false)),"room has no authored practical fittings")
			if lamps.is_empty(): dead += 1
			elif theme in [0,10]:
				expect(lamps.size()==live_lenses+shafts,"illuminated lens has no matching source")
			else: expect(lamps.size()==fixtures*(1 if theme in [2,4] else 2)+skylights.size(),"live fitting is missing an emitting face")
			for node in chunk.get_children():
				if not node is BloomFixtureFlicker: continue
				flickering += 1
				node.set_process(false)
				var controlled := lamps.size()-skylights.size()
				if theme==0 and chunk.style==WorldGen.STYLE_HALLWAY: controlled=1
				if theme==10:
					controlled=0
					for lamp in lamps:
						if lamp.get_meta("visible_source") in ["central_brutalist_luminaire","brutal_fluorescent_upper"]: controlled+=1
				expect(node.lights.size()==controlled,"ballast ignores some fixture sources")
				# Force an ordinary dropout and require both faces to follow it.
				var before := {}
				for light in lamps: before[light] = light.light_energy
				node._target = 0.2
				node._t = 1.0
				node._process(0.02)
				for light in lamps:
					if light not in node.lights:
						expect(light.light_energy==before[light],"ballast alters a different fitting")
						continue
					expect(light.light_energy>0.0 and light.light_energy<before[light],"ballast dropout does not dim both faces")
			var state := {}
			for light in lamps: state[light] = [light.visible,light.light_energy]
			chunk.set_blackout(true)
			for light in lamps:
				expect(not light.visible,"blackout leaves a diffuser illuminating the room")
				var mesh := light.get_node(light.get_meta("fixture_emitter")) as MeshInstance3D
				var mat := mesh.get_active_material(0) as StandardMaterial3D
				expect(mat != null and not mat.emission_enabled,"blackout leaves a lens glowing")
			chunk.set_blackout(false)
			for light in lamps:
				expect(light.visible==state[light][0] and light.light_energy==state[light][1],"power restoration changes the fixture state")
			chunk.free()
	expect(checked>0 and flickering>0 and dead>0,"fixture coverage lacks live, flickering or dead fittings")
	print("PRACTICAL_FIXTURES checked=%d flickering_rooms=%d dead_rooms=%d" % [checked,flickering,dead])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("visible practical fixtures")


func _check_coffer_face(light: AreaLight3D, lens: MeshInstance3D, relative: Transform3D) -> void:
	var triangles := lens.mesh.get_faces()
	var centre: Vector3 = light.get_meta("fixture_face")
	# Check centre and corners against actual emissive triangles. The whole
	# ceiling's AABB would also contain dark insets and cannot prove alignment.
	for offset in [Vector2.ZERO,Vector2(-0.499,-0.499),Vector2(0.499,-0.499),Vector2(-0.499,0.499),Vector2(0.499,0.499)]:
		var point := centre+Vector3(offset.x*light.area_size.x,0,offset.y*light.area_size.y)
		var covered := false
		for i in range(0,triangles.size(),3):
			if Geometry3D.ray_intersects_triangle(point+Vector3.UP*0.1,Vector3.DOWN,
					relative*triangles[i],relative*triangles[i+1],relative*triangles[i+2]) != null:
				covered = true
				break
		expect(covered,"coffer source emits from a dark or missing piece of ceiling")
