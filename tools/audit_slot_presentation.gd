extends "res://tools/lib/audit_base.gd"
## Low-ceiling Last Chance regression: complete idle art, room/sign clearance,
## shared materials, and compatibility with the genuine blackout power cut.

func _check_bank(chunk: Chunk, first: int, ceiling: float) -> void:
	var highest := -INF
	var sign_bottom := INF
	var cabinets := 0
	var signs := 0
	var active := 0
	var blackout := preload("res://scripts/blackout_surfaces.gd").new()
	for i in range(first, chunk.get_child_count()):
		var node := chunk.get_child(i) as Node3D
		if node == null:
			continue
		if node.has_meta("slot_machine"):
			cabinets += 1
			active += int(node.get_meta("powered"))
			var bounds: AABB = node.transform * visual_bounds(node)
			highest = maxf(highest, bounds.end.y)
			expect(bounds.end.y <= ceiling - Chunk.CASINO_SLOT_SIGN_HEADROOM + 0.002,
				"last-chance cabinet lost ceiling/sign reserve")
			var cabinet := node.get_node("AuthoredCabinet") as Node3D
			expect(cabinet.scale.x <= Chunk.CASINO_SLOT_SCALE, "cabinet exceeds reduced standard scale")
			for mesh: MeshInstance3D in cabinet.find_children("*", "MeshInstance3D", true, false):
				if mesh.name not in [&"Displays", &"PrintedGlass", &"LightGuides"]:
					continue
				var material := mesh.get_active_material(0)
				var off := blackout.off_material(material)
				if mesh.name == &"LightGuides":
					var expected := 1.0 if bool(node.get_meta("powered")) else 0.18
					var value: Variant = material.get_shader_parameter("mains_power")
					expect((value == null and expected == 1.0) or \
						(value != null and is_equal_approx(float(value), expected)), "wrong cabinet light power")
					expect(is_zero_approx(float(off.get_shader_parameter("mains_power"))), "blackout kept light guides on")
					continue
				var source := mesh.mesh.surface_get_material(0) as BaseMaterial3D
				var panel := material as BaseMaterial3D
				expect(panel != null and panel.albedo_texture == source.albedo_texture \
					and panel.emission_texture == source.emission_texture, "standby stripped panel artwork")
				expect(panel.emission_enabled and panel.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
					"panel unlit or transparent")
				var ratio := 1.0 if bool(node.get_meta("powered")) else 0.18
				expect(is_equal_approx(panel.emission_energy_multiplier, source.emission_energy_multiplier * ratio),
					"standby backlight level wrong or source mutated")
				if not bool(node.get_meta("powered")):
					expect(panel == Mats.casino_slot_standby(source), "standby materials not shared")
				expect(not off.emission_enabled and off.albedo_texture == panel.albedo_texture,
					"blackout loses artwork or leaves standby emission on")
		elif node.get_meta("casino_landmark_sign", "") == "LAST CHANCE":
			signs += 1
			var bounds: AABB = node.transform * visual_bounds(node)
			sign_bottom = minf(sign_bottom, bounds.position.y)
			expect(bounds.end.y <= ceiling + 0.001, "sign/support penetrates ceiling")
			expect(node.get_child_count() == 8, "low sign lacks both suspension rods")
	expect(cabinets == 8 and active == 1 and signs == 2, "Last Chance lost its bank or signs")
	expect(sign_bottom - highest >= 0.14, "hanging sign overlaps or crowds slot toppers")
	print("SLOT_PRESENTATION ceiling=%.2f cabinet_top=%.3f sign_bottom=%.3f gap=%.3f" % [
		ceiling, highest, sign_bottom, sign_bottom - highest])


func run() -> void:
	for ceiling in [2.4, 2.7, 2.85, 3.05, 3.2, 4.4, 6.0]:
		var chunk := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
		chunk._build_context._ceiling_height = ceiling
		chunk._build_context._casino_landmark = CasinoLandmarks.LAST_CHANCE
		var first := chunk.get_child_count()
		chunk._level_builder._casino_landmark()
		_check_bank(chunk, first, ceiling)
		chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("seven ceiling heights, 56 cabinets: standby art, headroom, sign clearance and blackout materials")
