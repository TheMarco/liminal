extends SceneTree
## Verifies that school laboratories use the authored island and randomized
## individual glassware, while asylum scatter isolates supported authored pieces.
## Run: godot --headless --path . --script tools/audit_chemistry_props.gd -- [seeds] [radius]


func _bounds(node: Node, parent_transform: Transform3D,
		result: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			var bounds := transform * mesh_node.mesh.get_aabb()
			result["bounds"] = bounds if not result["has_bounds"] \
				else (result["bounds"] as AABB).merge(bounds)
			result["has_bounds"] = true
	for child in node.get_children():
		_bounds(child, transform, result)


func _matching_colliders(chunk: Chunk, pivot: Node3D) -> Array[CollisionShape3D]:
	var matches: Array[CollisionShape3D] = []
	var group := int(pivot.get_meta("furnishing_group", -1))
	for child in chunk.body.get_children():
		var collider := child as CollisionShape3D
		if collider != null \
				and int(collider.get_meta("furnishing_group", -2)) == group:
			matches.append(collider)
	return matches


func _inspect_glass(pivot: Node3D, report: Dictionary) -> void:
	report["glass"] += 1
	var context := String(pivot.get_meta("chemistry_context", ""))
	report["contexts"][context] = int(report["contexts"].get(context, 0)) + 1
	var variant := int(pivot.get_meta("chemistry_variant", -99))
	var support := pivot.get_parent() as Node3D
	if support == null or not support.has_meta("atomic_furnishing") \
			or not support.has_meta("chemistry_surface_y") \
			or not bool(pivot.get_meta("surface_supported", false)):
		report["violations"] += 1
		print("FAIL unsupported chemistry glassware context=%s" % context)
	else:
		var surface_y := float(support.get_meta("chemistry_surface_y"))
		if absf(pivot.position.y - surface_y) > 0.006:
			report["violations"] += 1
			print("FAIL glassware bottom %.4f differs from %s surface %.4f" % [
				pivot.position.y, support.get_meta("atomic_furnishing"),
				surface_y])
	var authored := pivot.find_child("Sketchfab_Scene", true, false) as Node3D
	if authored == null \
			or authored.get_meta("attributed_asset", "") != \
				Chunk.CHEMISTRY_GLASSWARE_PATH \
			or authored.get_meta("authored_model", "") != \
				"chemistry_glassware":
		report["violations"] += 1
		print("FAIL chemistry glassware has no attributed source instance")
		return
	if authored.scale.distance_to(
			Vector3.ONE * Chunk.CHEMISTRY_GLASSWARE_SCALE) > 0.0001:
		report["violations"] += 1
		print("FAIL chemistry glassware scale is %s" % authored.scale)
	var visual := {"has_bounds": false, "bounds": AABB()}
	_bounds(authored, Transform3D.IDENTITY, visual)
	if not visual["has_bounds"]:
		report["violations"] += 1
	else:
		var bounds: AABB = visual["bounds"]
		if absf(bounds.position.y) > 0.006 \
				or absf(bounds.get_center().x) > 0.006 \
				or absf(bounds.get_center().z) > 0.006:
			report["violations"] += 1
			print("FAIL chemistry glassware is not bottom-centred: %s" % bounds)
	var source_root := authored.find_child("GLTF_SceneRootNode", true, false)
	if source_root == null:
		report["violations"] += 1
		return
	var names: Array[String] = []
	for child in source_root.get_children():
		names.append(String(child.name))
	names.sort()
	if variant < 0:
		report["violations"] += 1
		print("FAIL staged full chemistry set remains in context=%s pieces=%d" % [
			context, names.size()])
	else:
		if variant >= Chunk.CHEMISTRY_GLASSWARE_VARIANTS.size():
			report["violations"] += 1
			return
		var expected: Array = \
			Chunk.CHEMISTRY_GLASSWARE_VARIANTS[variant].duplicate()
		expected.sort()
		if names != expected:
			report["violations"] += 1
			print("FAIL glassware variant %d pieces=%s expected=%s context=%s" % [
				variant, names, expected, context])
		report["variants"][variant] = \
			int(report["variants"].get(variant, 0)) + 1
	if context == "school_lab":
		var slot := int(pivot.get_meta("school_counter_slot", -1))
		if slot < 0 or slot >= Chunk.SCH_CHEMISTRY_COUNTER_POINTS.size():
			report["violations"] += 1
			print("FAIL school glassware has no verified counter slot")
		else:
			var expected_point: Vector3 = \
				Chunk.SCH_CHEMISTRY_COUNTER_POINTS[slot]
			var horizontal_error := Vector2(
				pivot.position.x - expected_point.x,
				pivot.position.z - expected_point.z).length()
			if horizontal_error > 0.075:
				report["violations"] += 1
				print("FAIL school glassware drifted off counter slot %d: %s" \
					% [slot, pivot.position])
	for found in authored.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var mat := mesh_node.mesh.surface_get_material(surface) \
				as BaseMaterial3D
			if mat != null and mat.resource_name == "vidrio" \
					and (mat.metallic > 0.05 \
						or mat.albedo_color.a < 0.30):
				report["violations"] += 1
				print("FAIL glass material remains metallic/invisible")
				return


func _inspect_school_table(chunk: Chunk, pivot: Node3D,
		report: Dictionary) -> void:
	report["tables"] += 1
	var authored := pivot.find_child("Sketchfab_Scene", true, false) as Node3D
	if authored == null \
			or authored.get_meta("attributed_asset", "") != \
				Chunk.SCH_CHEMISTRY_TABLE_PATH \
			or authored.get_meta("authored_model", "") != \
				"school_chemistry_table":
		report["violations"] += 1
		print("FAIL school chemistry table has no attributed source instance")
		return
	var visual := {"has_bounds": false, "bounds": AABB()}
	_bounds(authored, Transform3D.IDENTITY, visual)
	if not visual["has_bounds"]:
		report["violations"] += 1
	else:
		var bounds: AABB = visual["bounds"]
		var expected_size := Vector3(6.211466, 1.632539, 5.366695) \
			* Chunk.SCH_CHEMISTRY_TABLE_SCALE
		if absf(bounds.position.y) > 0.006 \
				or absf(bounds.get_center().x) > 0.006 \
				or absf(bounds.get_center().z) > 0.006 \
				or bounds.size.distance_to(expected_size) > 0.015:
			report["violations"] += 1
			print("FAIL school chemistry table bounds=%s expected=%s" % [
				bounds, expected_size])
	var glass_count := 0
	for found in pivot.find_children("*", "Node3D", true, false):
		if found.get_meta("chemistry_context", "") == "school_lab":
			glass_count += 1
	if glass_count < 3 or glass_count > 6:
		report["violations"] += 1
		print("FAIL school chemistry table owns %d individual glassware pieces" \
			% glass_count)
	var colliders := _matching_colliders(chunk, pivot)
	if colliders.size() != 1 \
			or not colliders[0].shape is BoxShape3D \
			or (colliders[0].shape as BoxShape3D).size.distance_to(
				Vector3(4.46, 0.88, 3.86)) > 0.005:
		report["violations"] += 1
		print("FAIL school chemistry table collider count/size")
	for found in authored.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			var mat := mesh_node.mesh.surface_get_material(surface) \
				as BaseMaterial3D
			if mat != null \
					and mat.resource_name == \
						"Procedual_Marble_Granite_Black_Galaxy" \
					and (mat.metallic > 0.05 or mat.roughness < 0.25):
				report["violations"] += 1
				print("FAIL chemistry table granite remains mirror-like")


func _inspect_chunk(chunk: Chunk, report: Dictionary) -> int:
	var local_tables := 0
	for found in chunk.find_children("*", "Node3D", true, false):
		var node := found as Node3D
		if node.get_meta("attributed_furnishing", "") == \
				"school_chemistry_table":
			local_tables += 1
			_inspect_school_table(chunk, node, report)
		if node.get_meta("attributed_furnishing", "") == \
				"chemistry_glassware":
			_inspect_glass(node, report)
	return local_tables


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 8, 1, 24)
	var radius := clampi(int(args[1]) if args.size() > 1 else 8, 4, 14)
	var report := {
		"labs": 0,
		"tables": 0,
		"glass": 0,
		"contexts": {},
		"variants": {},
		"violations": 0,
	}
	for seed_index in seed_count:
		var base := WorldGen.h(903271, seed_index * 43,
			seed_index * 89, 2861) | 1
		for theme in [5, 6]:
			var world_seed := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var cell := Vector2i(x, z)
					if WorldGen.room_id(world_seed, cell) != cell \
							or not WorldGen.room_split(
								world_seed, cell, theme).is_empty():
						continue
					var style := WorldGen.cell_style(world_seed, cell, theme)
					var wanted: bool = theme == 6 and style == WorldGen.SCH_LAB \
						or theme == 5 and (style == WorldGen.ASY_TREATMENT \
							or style == WorldGen.ASY_DAYROOM)
					if not wanted:
						continue
					var chunk := Chunk.new(world_seed, cell, theme)
					var local_tables := _inspect_chunk(chunk, report)
					if theme == 6:
						report["labs"] += 1
						var expected := 2 \
							if WorldGen.room_size(world_seed, cell) > 1 else 1
						# A merged room asks for two islands, but doorway
						# clearance may remove the one crossing an approach
						# lane. It must still retain at least one complete lab.
						if local_tables < 1 or local_tables > expected:
							report["violations"] += 1
							print("FAIL school lab %s emitted %d tables; allowed 1..%d" \
								% [cell, local_tables, expected])
					var support_bad := \
						chunk.atomic_furnishing_support_violations()
					var doorway_bad := chunk.doorway_clearance_violations()
					report["violations"] += support_bad + doorway_bad
					if support_bad + doorway_bad > 0:
						print("FAIL chemistry room %s theme=%d support=%d doorway=%d" \
							% [cell, theme, support_bad, doorway_bad])
					chunk.free()
	for context in ["school_lab", "asylum_treatment", "asylum_dayroom"]:
		if int(report["contexts"].get(context, 0)) == 0:
			report["violations"] += 1
			print("FAIL chemistry context was never exercised: %s" % context)
	for variant in Chunk.CHEMISTRY_GLASSWARE_VARIANTS.size():
		if int(report["variants"].get(variant, 0)) == 0:
			report["violations"] += 1
			print("FAIL asylum glassware variant was never exercised: %d" \
				% variant)
	if int(report["labs"]) == 0:
		report["violations"] += 1
		print("FAIL no school laboratory was generated")
	print("chemistry prop audit: labs=%d tables=%d glass=%d contexts=%s variants=%s" % [
		report["labs"], report["tables"], report["glass"],
		report["contexts"], report["variants"]])
	if int(report["violations"]) == 0:
		print("  PASS — chemistry assets are authored, scaled and surface-supported")
	else:
		print("  FAIL — %d chemistry fixture violations" % report["violations"])
	quit(0 if int(report["violations"]) == 0 else 1)
