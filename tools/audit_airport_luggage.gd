extends SceneTree
const MOTION := preload("res://scripts/airport_carousel_motion.gd")
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
	var shells := 0
	var belts := 0
	var feed_vertices := 0
	var backing_vertices := 0
	var side_screen_vertices := 0
	var room_min := Vector2(INF, INF)
	var room_max := Vector2(-INF, -INF)
	for member in chunk._room_members():
		var origin := Vector2(member - chunk.cell) * WorldGen.CELL_SIZE
		room_min = room_min.min(origin)
		room_max = room_max.max(origin + Vector2.ONE * WorldGen.CELL_SIZE)
	for found in pivot.find_children("*", "MeshInstance3D", true, false):
		if found.name == "airport_carousel_Body":
			shells += 1
			# Independent of the doorway-cull depth: a single-cell baggage room
			# must retain a generous walking aisle around the physical shell.
			var footprint: AABB = pivot.transform * found.mesh.get_aabb()
			if footprint.position.z < room_min.y + 2.4 or footprint.end.z > room_max.y - 2.4 \
					or footprint.position.x < room_min.x + 2.4 or footprint.end.x > room_max.x - 2.4:
				report["violations"] += 1
				print("FAIL carousel does not leave 2.4m circulation aisles: %s" % footprint)
			for surface in found.mesh.get_surface_count():
				for vertex: Vector3 in found.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					if absf(vertex.x) < 0.34 and vertex.z < -0.8 - MOTION.END_SHIFT and vertex.y > 0.55 + MOTION.FIXTURE_LIFT:
						feed_vertices += 1
					if absf(vertex.x) < 0.30 and vertex.z > 1.17 + MOTION.END_SHIFT and vertex.z < 1.36 + MOTION.END_SHIFT and vertex.y > 0.60 + MOTION.FIXTURE_LIFT:
						backing_vertices += 1
		if found.name == "PrintedGraphics":
			for surface in found.mesh.get_surface_count():
				var arrays: Array = found.mesh.surface_get_arrays(surface)
				for vi in arrays[Mesh.ARRAY_VERTEX].size():
					var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][vi]
					var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][vi]
					if absf(vertex.x - 0.031) < 0.001 and vertex.y > 1.05 + MOTION.FIXTURE_LIFT and normal.x > 0.99:
						side_screen_vertices += 1
		if bool(found.get_meta("airport_carousel_belt", false)):
			belts += 1
			var bounds: AABB = found.mesh.get_aabb()
			if not is_equal_approx(bounds.position.y, 0.665) \
					or bounds.size.x < 2.80 or bounds.size.z < 6.80:
				report["violations"] += 1
				print("FAIL carousel belt is not full-size: %s" % bounds)
	var group := int(pivot.get_meta("furnishing_group", -1))
	var colliders := 0
	for child in chunk.body.get_children():
		if child is CollisionShape3D \
				and int(child.get_meta("furnishing_group", -2)) == group:
			colliders += 1
	if shells != 1 or belts != 1 or colliders != 6 or feed_vertices < 20 or backing_vertices < 20 or side_screen_vertices < 4:
		report["violations"] += 1
		print("FAIL incomplete authored carousel: shells=%d belts=%d colliders=%d feed_vertices=%d backing=%d side_screen=%d" % [
			shells, belts, colliders, feed_vertices, backing_vertices, side_screen_vertices])
	else:
		report["chutes"] += 1
	_inspect_number_totem(pivot, report)
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
	print("  supported number totems: %d | integrated feed hoods: %d" % [
		report["totems"], report["chutes"]])
	if int(report["violations"]) == 0:
		print("  PASS — luggage is isolated and every baggage carousel is complete")
	else:
		print("  FAIL — %d luggage violations" % report["violations"])
	quit(0 if int(report["violations"]) == 0 else 1)
