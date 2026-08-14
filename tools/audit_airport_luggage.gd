extends SceneTree
## Verifies that airport luggage uses only the three isolated authored pieces,
## stays floor-centred, retains its hardware materials and exercises several
## deterministic shell/fabric color variants.
## Run: godot --headless --path . --script tools/audit_airport_luggage.gd -- [seeds] [radius]


func _bounds(node: Node, xf: Transform3D, result: Dictionary) -> void:
	var next := xf
	if node is Node3D:
		next = xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var bounds := next * mesh_node.mesh.get_aabb()
		result["bounds"] = bounds if not result["has_bounds"] \
			else (result["bounds"] as AABB).merge(bounds)
		result["has_bounds"] = true
	for child in node.get_children():
		_bounds(child, next, result)


func _inspect(node: Node, report: Dictionary) -> void:
	if node.has_meta("airport_luggage_piece"):
		report["count"] += 1
		var piece := int(node.get_meta("airport_luggage_piece"))
		if piece < 0 or piece >= Chunk.AIRPORT_LUGGAGE_NODES.size():
			report["violations"] += 1
			return
		report["pieces"][piece] = int(report["pieces"].get(piece, 0)) + 1
		var attributed := node.find_child("Sketchfab_Scene", true, false)
		if attributed == null \
				or attributed.get_meta("attributed_asset", "") != Chunk.AIRPORT_LUGGAGE_PATH:
			report["violations"] += 1
			print("FAIL luggage piece %d has no attributed GLB instance" % piece)
		var expected: Array = Chunk.AIRPORT_LUGGAGE_NODES[piece]
		var names: Array[String] = []
		var tinted := 0
		for found in node.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := found as MeshInstance3D
			names.append(String(mesh_node.name))
			for surface in mesh_node.mesh.get_surface_count():
				var source := mesh_node.mesh.surface_get_material(surface)
				var override := mesh_node.get_surface_override_material(surface)
				if source != null \
						and Chunk.AIRPORT_LUGGAGE_BODY_MATERIALS.has(source.resource_name):
					if override == null:
						report["violations"] += 1
					else:
						tinted += 1
						report["colors"][(override as BaseMaterial3D).albedo_color] = true
				elif override != null:
					report["violations"] += 1
					print("FAIL luggage hardware received a material override: %s" \
						% source.resource_name)
		names.sort()
		var sorted_expected: Array = expected.duplicate()
		sorted_expected.sort()
		if names != sorted_expected or tinted == 0:
			report["violations"] += 1
			print("FAIL luggage piece %d meshes=%s expected=%s tints=%d" % [
				piece, names, sorted_expected, tinted])
		var visual := {"has_bounds": false, "bounds": AABB()}
		for child in node.get_children():
			_bounds(child, Transform3D.IDENTITY, visual)
		if not visual["has_bounds"]:
			report["violations"] += 1
		else:
			var bounds: AABB = visual["bounds"]
			if absf(bounds.position.y) > 0.012 \
					or absf(bounds.get_center().x) > 0.012 \
					or absf(bounds.get_center().z) > 0.012:
				report["violations"] += 1
				print("FAIL luggage piece %d is not floor-centred: %s" % [
					piece, bounds])
	if node.has_meta("furnishing_kind") \
			and String(node.get_meta("furnishing_kind")) == "suitcase":
		report["procedural"] += 1
	for child in node.get_children():
		_inspect(child, report)


func _inspect_carousel(chunk: Chunk, pivot: Node3D,
		report: Dictionary) -> void:
	report["carousels"] += 1
	var siding := 0
	var lips := 0
	var slats := 0
	var belts := 0
	for found in pivot.find_children("*", "Node3D", true, false):
		if bool(found.get_meta("airport_carousel_siding", false)):
			siding += 1
		if bool(found.get_meta("airport_carousel_lip", false)):
			lips += 1
		if bool(found.get_meta("airport_carousel_slat", false)):
			slats += 1
		if bool(found.get_meta("airport_carousel_belt", false)):
			belts += 1
	var group := int(pivot.get_meta("furnishing_group", -1))
	var colliders := 0
	for child in chunk.body.get_children():
		if child is CollisionShape3D \
				and int(child.get_meta("furnishing_group", -2)) == group:
			colliders += 1
	if siding != 18 or lips != 18 or slats != 28 \
			or belts != 1 or colliders != 9:
		report["violations"] += 1
		print("FAIL incomplete baggage carousel: siding=%d lips=%d slats=%d belts=%d colliders=%d" % [
			siding, lips, slats, belts, colliders])
	if chunk.doorway_clearance_violations() != 0:
		report["violations"] += 1
		print("FAIL baggage carousel room retains a doorway overlap")


func _inspect_number_totem(pivot: Node3D, report: Dictionary) -> void:
	report["totems"] += 1
	var labels := pivot.find_children(
		"BaggageCarouselNumber", "Label3D", true, false)
	var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
	if labels.size() != 1 or meshes.size() < 2:
		report["violations"] += 1
		print("FAIL incomplete baggage number totem: labels=%d meshes=%d" % [
			labels.size(), meshes.size()])


func _inspect_chute(chunk: Chunk, pivot: Node3D,
		report: Dictionary) -> void:
	report["chutes"] += 1
	var meshes := pivot.find_children("*", "MeshInstance3D", true, false)
	var group := int(pivot.get_meta("furnishing_group", -1))
	var colliders := 0
	for child in chunk.body.get_children():
		if child is CollisionShape3D \
				and int(child.get_meta("furnishing_group", -2)) == group:
			colliders += 1
	if meshes.size() < 3 or colliders != 1:
		report["violations"] += 1
		print("FAIL incomplete baggage chute: meshes=%d colliders=%d" % [
			meshes.size(), colliders])


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 5, 1, 16)
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 3, 12)
	var report := {
		"count": 0,
		"pieces": {},
		"colors": {},
		"procedural": 0,
		"carousels": 0,
		"totems": 0,
		"chutes": 0,
		"violations": 0,
	}
	for si in seed_count:
		var base := WorldGen.h(771901, si * 43, si * 79, 2441) | 1
		var world_seed := WorldGen.level_seed(base, 4)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var chunk := Chunk.new(world_seed, cell, 4)
				_inspect(chunk, report)
				var carousel_count := 0
				for found in chunk.find_children("*", "Node3D", true, false):
					var pivot := found as Node3D
					match str(pivot.get_meta("atomic_furnishing", "")):
						"airport_baggage_carousel":
							carousel_count += 1
							_inspect_carousel(chunk, pivot, report)
						"airport_baggage_number_totem":
							_inspect_number_totem(pivot, report)
						"airport_baggage_chute":
							_inspect_chute(chunk, pivot, report)
				# Chunk generation resolves room splits and portals before
				# deciding whether baggage props are furnished. The marker is
				# the exact intent signal and survives doorway cleanup.
				var expects_carousel := bool(chunk.get_meta(
					"airport_baggage_carousel_expected", false))
				if expects_carousel and carousel_count != 1:
					report["violations"] += 1
					print("FAIL seed=%d baggage room %s size=%d portal=%d retained %d complete carousels" % [
						base, cell, WorldGen.room_size(world_seed, cell),
						WorldGen.portal(world_seed, cell, 4),
						carousel_count])
				chunk.free()
	for piece in Chunk.AIRPORT_LUGGAGE_NODES.size():
		if int(report["pieces"].get(piece, 0)) == 0:
			report["violations"] += 1
			print("FAIL authored luggage piece %d was never exercised" % piece)
	if report["colors"].size() < 4:
		report["violations"] += 1
		print("FAIL only %d luggage color variants were exercised" \
			% report["colors"].size())
	if int(report["procedural"]) != 0:
		report["violations"] += int(report["procedural"])
		print("FAIL found %d legacy procedural suitcase furnishings" \
			% report["procedural"])
	if int(report["totems"]) == 0 or int(report["chutes"]) == 0:
		report["violations"] += 1
		print("FAIL baggage support fixtures were not exercised: totems=%d chutes=%d" % [
			report["totems"], report["chutes"]])
	print("airport luggage audit: %d authored pieces, variants=%s, colors=%d, complete carousels=%d" % [
		report["count"], report["pieces"], report["colors"].size(),
		report["carousels"]])
	print("  supported number totems: %d | atomic feed chutes: %d" % [
		report["totems"], report["chutes"]])
	if int(report["violations"]) == 0:
		print("  PASS — luggage is isolated and every baggage carousel is complete")
	else:
		print("  FAIL — %d luggage violations" % report["violations"])
	quit(0 if int(report["violations"]) == 0 else 1)
