extends SceneTree
## Pool Rooms basin-shape contract. Rounded corner decks and circular
## pier-islands are occasional Basin-only variants: each must carry complete
## coping/collision geometry, stay at deck height, and never become universal.
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
	var pier_island_count := 0
	for si in seed_count:
		var base := WorldGen.h(9321, si * 43, si * 71, 449) | 1
		var ws := WorldGen.level_seed(base, THEME)
		var built_this_seed := 0
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				if built_this_seed >= MAX_BASINS_PER_SEED:
					break
				var cell := Vector2i(x, z)
				if WorldGen.cell_style(ws, cell, THEME) != WorldGen.POOL_BASIN:
					continue
				var chunk := Chunk.new(ws, cell, THEME)
				basin_count += 1
				built_this_seed += 1
				var corners := _meshes_with_meta(
					chunk, "pool_rounded_basin_corner")
				var corner_coping := _meshes_with_meta(
					chunk, "pool_rounded_basin_corner_coping")
				var corner_colliders := _shapes_with_meta(
					chunk, "pool_rounded_basin_corner_collider")
				var islands := _meshes_with_meta(
					chunk, "pool_rounded_pier_island")
				var island_coping := _meshes_with_meta(
					chunk, "pool_rounded_pier_island_coping")
				if corners.size() > 1:
					failures.append(
						"seed %d cell %s: built %d rounded basin corners" % [
							si, cell, corners.size()])
				if islands.size() > 1:
					failures.append(
						"seed %d cell %s: built %d pier islands" % [
							si, cell, islands.size()])
				if not corners.is_empty() and not islands.is_empty():
					failures.append(
						"seed %d cell %s: corner and island overlap" % [
							si, cell])
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
				if islands.size() == 1:
					pier_island_count += 1
					_check_island(
						cell, chunk, islands[0], island_coping,
						failures, si)
				elif not island_coping.is_empty():
					failures.append(
						"seed %d cell %s: orphan island coping" % [
							si, cell])
				chunk.free()
			if built_this_seed >= MAX_BASINS_PER_SEED:
				break
	print(("pool basin audit: %d seeds | %d Basin chunks | %d rounded " +
		"corners | %d rounded pier islands") % [
			seed_count, basin_count, rounded_corner_count, pier_island_count])
	if rounded_corner_count == 0:
		failures.append("no rounded basin corner was generated")
	if pier_island_count == 0:
		failures.append("no rounded pier island was generated")
	if rounded_corner_count + pier_island_count >= basin_count:
		failures.append("rounded variants are universal instead of occasional")
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print(("  PASS — rounded Basin corners and pillar islands are occasional, " +
		"complete, and structurally aligned"))
	quit()


func _check_corner(ws: int, cell: Vector2i, deck: MeshInstance3D,
		coping: Array[MeshInstance3D], colliders: Array[CollisionShape3D],
		failures: Array[String], si: int) -> void:
	if coping.size() != 1:
		failures.append(
			"seed %d cell %s: corner has %d coping pieces, expected 1" % [
				si, cell, coping.size()])
	if colliders.size() != Chunk.POOL_CORNER_SEGMENTS:
		failures.append(
			"seed %d cell %s: corner has %d colliders, expected %d" % [
				si, cell, colliders.size(), Chunk.POOL_CORNER_SEGMENTS])
	var radius := float(deck.get_meta("pool_rounded_basin_corner_radius"))
	if radius < 2.35 - EPS or radius > 3.35 + EPS:
		failures.append(
			"seed %d cell %s: corner radius %.3f is out of range" % [
				si, cell, radius])
	var id := int(deck.get_meta("pool_rounded_basin_corner_id"))
	var dirs: Array[int] = []
	match id:
		0:
			dirs = [1, 3]
		1:
			dirs = [0, 3]
		2:
			dirs = [0, 2]
		3:
			dirs = [1, 2]
		_:
			failures.append(
				"seed %d cell %s: invalid corner id %d" % [si, cell, id])
			return
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
	if radius < 1.65 - EPS or radius > 2.05 + EPS:
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
