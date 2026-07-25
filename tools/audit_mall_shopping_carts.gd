extends SceneTree
## Ensures every mall shopping cart uses the attributed GLB, keeps its authored
## three-mesh assembly floor-centred, and owns one matching gameplay collider.
## Run: godot --headless --path . --script tools/audit_mall_shopping_carts.gd -- [seeds] [radius]


func _bounds(node: Node, parent_transform: Transform3D,
		result: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var bounds := transform * mesh_node.mesh.get_aabb()
		result["bounds"] = bounds if not result["has_bounds"] \
			else (result["bounds"] as AABB).merge(bounds)
		result["has_bounds"] = true
	for child in node.get_children():
		_bounds(child, transform, result)


func _inspect_cart(chunk: Chunk, pivot: Node3D, report: Dictionary) -> void:
	report["count"] += 1
	if bool(pivot.get_meta("mall_cart_loaded", false)):
		report["loaded"] += 1
	if pivot.get_meta("attributed_furnishing", "") != "mall_shopping_cart":
		report["violations"] += 1
		print("FAIL shopping cart pivot is not marked as attributed")
	var authored := pivot.find_child("Sketchfab_Scene", true, false) as Node3D
	if authored == null \
			or authored.get_meta("attributed_asset", "") != Chunk.MALL_SHOPPING_CART_PATH:
		report["violations"] += 1
		print("FAIL shopping cart has no attributed source scene")
		return
	var mesh_names: Array[String] = []
	for found in authored.find_children("*", "MeshInstance3D", true, false):
		mesh_names.append(String(found.name))
	mesh_names.sort()
	if mesh_names != ["Object_4", "Object_5", "Object_6"]:
		report["violations"] += 1
		print("FAIL shopping cart source meshes are incomplete: %s" % [mesh_names])
	var visual := {"has_bounds": false, "bounds": AABB()}
	_bounds(authored, Transform3D.IDENTITY, visual)
	if not visual["has_bounds"]:
		report["violations"] += 1
	else:
		var bounds: AABB = visual["bounds"]
		if absf(bounds.position.y) > 0.008 \
				or absf(bounds.get_center().x) > 0.008 \
				or absf(bounds.get_center().z) > 0.008 \
				or absf(bounds.size.y - 1.008) > 0.025:
			report["violations"] += 1
			print("FAIL shopping cart is not floor-centred/scaled: %s" % bounds)
	var group := int(pivot.get_meta("furnishing_group", -1))
	var matching := 0
	for child in chunk.body.get_children():
		var collider := child as CollisionShape3D
		if collider == null or int(collider.get_meta("furnishing_group", -2)) != group:
			continue
		var box := collider.shape as BoxShape3D
		if box == null:
			continue
		matching += 1
		if box.size.distance_to(Vector3(0.68, 1.02, 1.05)) > 0.005:
			report["violations"] += 1
			print("FAIL shopping cart collider size is %s" % box.size)
	if matching != 1:
		report["violations"] += 1
		print("FAIL shopping cart owns %d colliders" % matching)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 5, 1, 16)
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 3, 12)
	var report := {"count": 0, "loaded": 0, "violations": 0}
	for seed_index in seed_count:
		var base := WorldGen.h(811903, seed_index * 47,
			seed_index * 83, 2473) | 1
		var world_seed := WorldGen.level_seed(base, 7)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var chunk := Chunk.new(world_seed, Vector2i(x, z), 7)
				for found in chunk.find_children("*", "Node3D", true, false):
					var pivot := found as Node3D
					if pivot.get_meta("enrichment_prop", "") == "shopping_cart":
						_inspect_cart(chunk, pivot, report)
				chunk.free()
	if int(report["count"]) == 0:
		report["violations"] += 1
		print("FAIL mall scan never exercised a shopping-cart placement")
	if int(report["loaded"]) == 0:
		report["violations"] += 1
		print("FAIL mall scan never exercised a loaded shopping cart")
	print("mall shopping-cart audit: %d authored carts (%d loaded)" % [
		report["count"], report["loaded"]])
	if int(report["violations"]) == 0:
		print("  PASS — every mall cart is authored, floor-centred and collidable")
	else:
		print("  FAIL — %d shopping-cart violations" % report["violations"])
	quit(0 if int(report["violations"]) == 0 else 1)
