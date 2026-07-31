extends SceneTree
## Pool Rooms basin-shape contract. Rounded corner decks are occasional
## Basin-only variants; wet chunks must not contain pier geometry.
##
## Run: godot --headless --path . \
##   --script tools/audit_pool_basins.gd -- [seeds]

const THEME := 9
const SCAN_R := 9
const MAX_BASINS_PER_SEED := 16
const EPS := 0.035


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 16, 4, 32)
	var failures: Array[String] = []
	var basin_count := 0
	var rounded_corner_count := 0
	var connected_non_channel_count := 0
	for si in seed_count:
		var base := WorldGen.h(9321, si * 43, si * 71, 449) | 1
		var ws := WorldGen.level_seed(base, THEME)
		var built_this_seed := 0
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				if built_this_seed >= MAX_BASINS_PER_SEED:
					break
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				if style not in [WorldGen.POOL_BASIN, WorldGen.POOL_CHANNEL,
						WorldGen.POOL_STAIRS, WorldGen.POOL_CISTERN]:
					continue
				var chunk := Chunk.new(ws, cell, THEME)
				if style == WorldGen.POOL_BASIN:
					basin_count += 1
				built_this_seed += 1
				_check_water_layout(chunk, failures, si, cell, style)
				var water_nodes := _meshes_with_meta(chunk, "pool_water_surface")
				if style != WorldGen.POOL_CHANNEL and not water_nodes.is_empty() \
						and bool(water_nodes[0].get_meta("pool_water_connected", false)):
					connected_non_channel_count += 1
				_check_ladder_volume(chunk, failures, si, cell, style)
				_check_coping_flush(chunk, failures, si, cell)
				_check_wet_space_piers(chunk, failures, si, cell, style)
				_check_jacuzzis(chunk, failures, si, cell)
				if style != WorldGen.POOL_BASIN:
					chunk.free()
					continue
				var corners := _meshes_with_meta(
					chunk, "pool_rounded_basin_corner")
				var corner_coping := _meshes_with_meta(
					chunk, "pool_rounded_basin_corner_coping")
				var corner_colliders := _shapes_with_meta(
					chunk, "pool_rounded_basin_corner_collider")
				if corners.size() > 1:
					failures.append(
						"seed %d cell %s: built %d rounded basin corners" % [
							si, cell, corners.size()])
				if corners.size() == 1:
					rounded_corner_count += 1
					_check_corner(
						ws, cell, corners[0], corner_coping,
						corner_colliders, failures, si)
				elif not corner_coping.is_empty() \
						or not corner_colliders.is_empty():
					failures.append(
						"seed %d cell %s: orphan corner coping/collision" % [
							si, cell])
				chunk.free()
			if built_this_seed >= MAX_BASINS_PER_SEED:
				break
	print(("pool basin audit: %d seeds | %d Basin chunks | %d rounded corners") % [
			seed_count, basin_count, rounded_corner_count])
	if rounded_corner_count == 0:
		failures.append("no rounded basin corner was generated")
	if rounded_corner_count >= basin_count:
		failures.append("rounded variants are universal instead of occasional")
	if connected_non_channel_count == 0:
		failures.append("no connected non-Channel wet basin was generated")
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print("  PASS — rounded Basin corners are occasional and structurally aligned")
	quit()


func _check_corner(ws: int, cell: Vector2i, deck: MeshInstance3D,
		coping: Array[MeshInstance3D], colliders: Array[CollisionShape3D],
		failures: Array[String], si: int) -> void:
	if coping.is_empty():
		failures.append(
			"seed %d cell %s: corner has no coping slabs" % [si, cell])
	else:
		var claimed_count := int(
			coping[0].get_meta("pool_coping_slab_count", -1))
		var indices: Array[int] = []
		for slab in coping:
			indices.append(int(
				slab.get_meta("pool_coping_slab_index", -1)))
		indices.sort()
		var expected_indices: Array[int] = []
		for i in coping.size():
			expected_indices.append(i)
		if claimed_count != coping.size() \
				or indices != expected_indices:
			failures.append(
				"seed %d cell %s: corner coping slab sequence is incomplete" % [
					si, cell])
	if colliders.size() != Chunk.POOL_CORNER_SEGMENTS:
		failures.append(
			"seed %d cell %s: corner has %d colliders, expected %d" % [
				si, cell, colliders.size(), Chunk.POOL_CORNER_SEGMENTS])
	var radius := float(deck.get_meta("pool_rounded_basin_corner_radius"))
	var legacy_radius := radius >= 2.35 - EPS and radius <= 3.35 + EPS
	var compact_radius := radius >= 1.05 - EPS and radius <= 1.55 + EPS
	if not legacy_radius and not compact_radius:
		failures.append(
			"seed %d cell %s: corner radius %.3f is out of range" % [
				si, cell, radius])
	var id := int(deck.get_meta("pool_rounded_basin_corner_id"))
	var dirs: Array[int] = []
	var inward := Vector2.ZERO
	match id:
		0:
			dirs = [1, 3]
			inward = Vector2(1.0, 1.0)
		1:
			dirs = [0, 3]
			inward = Vector2(-1.0, 1.0)
		2:
			dirs = [0, 2]
			inward = Vector2(-1.0, -1.0)
		3:
			dirs = [1, 2]
			inward = Vector2(1.0, -1.0)
		_:
			failures.append(
				"seed %d cell %s: invalid corner id %d" % [si, cell, id])
			return
	if compact_radius:
		var orientation := str(deck.get_meta(
			"pool_rounded_basin_corner_orientation", ""))
		if orientation != "concave_water_opening":
			failures.append(
				"seed %d cell %s: compact corner has wrong orientation %s" % [
					si, cell, orientation])
		var corner: Vector2 = deck.get_meta(
			"pool_rounded_basin_corner_square_corner", Vector2.ZERO)
		var arc_center: Vector2 = deck.get_meta(
			"pool_rounded_basin_corner_arc_center", Vector2.ZERO)
		var expected_center := corner + inward * radius
		if arc_center.distance_to(expected_center) > EPS:
			failures.append(
				("seed %d cell %s: compact corner arc center %s does not " +
				"point inward from square corner %s (expected %s)") % [
					si, cell, arc_center, corner, expected_center])
	if legacy_radius:
		for dir in dirs:
			if not bool(WorldGen.edge_info(ws, cell, dir, THEME)["wall"]):
				failures.append(
					"seed %d cell %s: rounded corner escapes through dir %d" % [
						si, cell, dir])


func _check_island(cell: Vector2i, chunk: Chunk, island: MeshInstance3D,
		coping: Array[MeshInstance3D], failures: Array[String], si: int) -> void:
	if coping.size() != 4:
		failures.append(
			"seed %d cell %s: island has %d coping quarters, expected 4" % [
				si, cell, coping.size()])
	var radius := float(island.get_meta("pool_rounded_pier_island_radius"))
	var legacy_radius := radius >= 1.65 - EPS and radius <= 2.05 + EPS
	var compact_radius := radius >= 0.70 - EPS and radius <= 1.20 + EPS
	if not legacy_radius and not compact_radius:
		failures.append(
			"seed %d cell %s: island radius %.3f is out of range" % [
				si, cell, radius])
	var center: Vector2 = island.get_meta("pool_rounded_pier_island_center")
	var matched_pier := false
	for pier in _meshes_with_meta(chunk, "pool_pier"):
		if Vector2(pier.position.x, pier.position.z).distance_to(center) < EPS:
			matched_pier = true
			break
	if not matched_pier:
		failures.append(
			"seed %d cell %s: island is not centered on a pier" % [si, cell])


func _meshes_with_meta(root: Node, meta_name: String) \
		-> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(meta_name):
			found.append(node)
	return found


func _shapes_with_meta(root: Node, meta_name: String) \
		-> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		if node.has_meta(meta_name):
			found.append(node)
	return found


func _areas_with_meta(root: Node, meta_name: String) -> Array[Area3D]:
	var found: Array[Area3D] = []
	for node in root.find_children("*", "Area3D", true, false):
		if node.has_meta(meta_name):
			found.append(node)
	return found


func _nodes_with_meta(root: Node, meta_name: String) -> Array[Node]:
	var found: Array[Node] = []
	_collect_nodes_with_meta(root, meta_name, found)
	return found


func _collect_nodes_with_meta(node: Node, meta_name: String,
		found: Array[Node]) -> void:
	if node.has_meta(meta_name):
		found.append(node)
	for child in node.get_children():
		_collect_nodes_with_meta(child, meta_name, found)


func _check_wet_space_piers(chunk: Chunk, failures: Array[String], si: int,
		cell: Vector2i, style: int) -> void:
	if style not in [WorldGen.POOL_BASIN, WorldGen.POOL_CHANNEL,
			WorldGen.POOL_STAIRS, WorldGen.POOL_CISTERN]:
		return
	var piers := _nodes_with_meta(chunk, "pool_pier")
	var islands := _nodes_with_meta(chunk, "pool_rounded_pier_island")
	if not piers.is_empty() or not islands.is_empty():
		failures.append(
			"seed %d cell %s style %d: wet space contains %d pool piers and %d rounded pier islands" % [
				si, cell, style, piers.size(), islands.size()])


func _check_jacuzzis(chunk: Chunk, failures: Array[String], si: int,
		cell: Vector2i) -> void:
	for jacuzzi in _nodes_with_meta(chunk, "pool_jacuzzi"):
		var waters := _nodes_with_meta(jacuzzi, "pool_jacuzzi_water")
		if waters.is_empty():
			failures.append(
				"seed %d cell %s: jacuzzi has no visible water surface" % [si, cell])
			continue
		var visible := false
		for water in waters:
			if water is MeshInstance3D:
				var water_mesh := (water as MeshInstance3D).mesh
				var water_material := (water as MeshInstance3D).material_override
				if water_mesh != null and water_material != null:
					visible = true
					break
		if not visible:
			failures.append(
				"seed %d cell %s: jacuzzi water has no mesh/material" % [si, cell])


func _check_ladder_volume(chunk: Chunk, failures: Array[String], si: int,
		cell: Vector2i, style: int) -> void:
	for node in chunk.find_children("*", "Node3D", true, false):
		if not node.has_meta("pool_ladder") \
				or str(node.get_meta("pool_ladder_site", "")) != "ledge":
			continue
		var dir := int(node.get_meta("pool_ladder_dir", -1))
		if style == WorldGen.POOL_CHANNEL and dir < 2 \
				and dir >= 0 and bool(WorldGen.edge_info(
					chunk.wseed, cell, dir, THEME)["wall"]):
			failures.append(
				"seed %d cell %s: channel ladder dir %d returns into a solid wall" % [
					si, cell, dir])
	var ladders := _areas_with_meta(chunk, "pool_ladder_volume")
	if ladders.size() != 1:
		failures.append("seed %d cell %s style %d: expected exactly one usable ladder volume, built %d" % [
			si, cell, style, ladders.size()])
		return
	var ladder := ladders[0]
	if ladder.collision_layer == 0 or ladder.collision_mask != 0:
		failures.append("seed %d cell %s style %d: ladder volume collision layer/mask is unusable" % [
			si, cell, style])
	var shapes := ladder.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() != 1 or shapes[0].shape == null:
		failures.append("seed %d cell %s style %d: ladder volume lacks one collision shape" % [
			si, cell, style])


func _check_water_layout(chunk: Chunk, failures: Array[String], si: int,
		cell: Vector2i, style: int) -> void:
	var water := _meshes_with_meta(chunk, "pool_water_surface")
	if water.size() != 1:
		failures.append("seed %d cell %s: expected one water surface, built %d" % [si, cell, water.size()])
		return
	var node := water[0]
	var center: Vector2 = node.get_meta("pool_water_center", Vector2.ZERO)
	var size: Vector2 = node.get_meta("pool_water_size", Vector2.ZERO)
	var connected := bool(node.get_meta("pool_water_connected", false))
	var links: Array = node.get_meta("pool_water_edge_links", [])
	var seen := {}
	for raw_dir in links:
		var dir := int(raw_dir)
		if dir < 0 or dir > 3 or seen.has(dir):
			failures.append("seed %d cell %s: invalid/duplicate water edge link %s" % [si, cell, raw_dir])
		else:
			seen[dir] = true
	if connected and links.is_empty():
		failures.append("seed %d cell %s: connected water has no edge links" % [si, cell])
	for dir in seen.keys():
		var reaches := false
		match int(dir):
			0: reaches = center.x + size.x * 0.5 >= chunk.S - EPS
			1: reaches = center.x - size.x * 0.5 <= EPS
			2: reaches = center.y + size.y * 0.5 >= chunk.S - EPS
			3: reaches = center.y - size.y * 0.5 <= EPS
		if not reaches:
			failures.append("seed %d cell %s: water link dir %d does not reach cell edge" % [si, cell, dir])
	if not connected and (size.x > 7.5 + EPS or size.y > 7.5 + EPS):
		failures.append("seed %d cell %s: basin footprint %.2fx%.2f exceeds compact limit" % [si, cell, size.x, size.y])
	if style == WorldGen.POOL_CHANNEL \
			and size.x >= chunk.S - EPS and size.y >= chunk.S - EPS:
		failures.append("seed %d cell %s: channel spans both axes" % [si, cell])
	if not connected and _meshes_with_meta(chunk, "pool_basin_deck").is_empty():
		failures.append("seed %d cell %s: compact basin has no deck pieces" % [si, cell])


func _check_coping_flush(chunk: Chunk, failures: Array[String], si: int,
		cell: Vector2i) -> void:
	for meta_name in ["pool_basin_coping", "pool_rounded_basin_corner_coping",
			"pool_rounded_pier_island_coping"]:
		for node in _meshes_with_meta(chunk, meta_name):
			if node.mesh == null:
				failures.append(
					"seed %d cell %s: %s has no coping mesh" % [
						si, cell, meta_name])
				continue
			var bounds := node.transform * node.get_aabb()
			var want_top := chunk.POOL_DECK_Y + 0.025
			if absf(bounds.end.y - want_top) > EPS:
				failures.append(
					"seed %d cell %s: %s top %.3f is not flush-proud at %.3f" % [
						si, cell, meta_name, bounds.end.y, want_top])
			if bounds.position.y > chunk.POOL_DECK_Y - 0.055 + EPS:
				failures.append(
					"seed %d cell %s: %s is stacked on the deck instead of recessed" % [
						si, cell, meta_name])
			if not node.has_meta("pool_coping_bullnose"):
				failures.append(
					"seed %d cell %s: %s does not use the bullnose profile" % [
						si, cell, meta_name])
			if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				failures.append("seed %d cell %s: %s casts a shadow" % [si, cell, meta_name])
