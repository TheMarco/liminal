extends SceneTree
## Pool edge continuity contract:
## - linked channel cells keep the same transverse water span;
## - dry-side wall ladders only appear where their doorway overlaps water.
## - a channel facing a dry hall stops 60cm inside the wet room, with coping
##   on that recessed edge rather than fused into the doorway wall return.
##
## Run:
##   godot --headless --path . --script tools/audit_pool_crossings.gd -- [seeds]

const THEME := 9
const SCAN_R := 8
const LADDER_HALF_WIDTH := 0.40
const DRY_BOUNDARY_SETBACK := 0.60


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 8, 2, 24)
	var failures: Array[String] = []
	var checked_ladders := 0
	var checked_channel_seams := 0
	var checked_channel_ladders := 0
	var checked_dry_boundary_termini := 0
	var checked_connected_coping := 0
	for si in seed_count:
		var base := WorldGen.h(4819, si * 37, si * 61, 983) | 1
		var ws := WorldGen.level_seed(base, THEME)
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				var chunk := Chunk.new(ws, cell, THEME)
				if Chunk.pool_style_dry(style):
					checked_ladders += _check_dry_ladders(
						ws, cell, chunk, failures, si)
				else:
					checked_dry_boundary_termini += _check_dry_boundary_termini(
						ws, cell, chunk, failures, si)
					if style == WorldGen.POOL_CHANNEL:
						checked_channel_seams += _check_channel_seams(
							ws, cell, chunk, failures, si)
						checked_channel_ladders += _check_channel_ladder_landing(
							ws, cell, chunk, failures, si)
					else:
						checked_connected_coping += _check_connected_coping(
							ws, cell, chunk, failures, si)
				chunk.free()
	if checked_channel_seams == 0:
		failures.append("no linked channel seam was checked")
	if checked_channel_ladders == 0:
		failures.append("no channel ladder landing was checked")
	if checked_dry_boundary_termini == 0:
		failures.append("no recessed wet-to-dry channel terminus was checked")
	if checked_connected_coping == 0:
		failures.append("no rounded compact-to-channel coping transition was checked")
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print(("pool crossing audit: PASS — %d dry-room ladders over water, "
		+ "%d channel ladders on real landings, %d continuous "
		+ "channel seams, %d recessed wet-to-dry termini, %d rounded " +
		"connected coping junctions") % [
		checked_ladders, checked_channel_ladders, checked_channel_seams,
		checked_dry_boundary_termini, checked_connected_coping])
	quit()


func _check_dry_ladders(ws: int, cell: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	var checked := 0
	for node in chunk.find_children("*", "", true, false):
		if not node.has_meta("pool_ladder") \
				or str(node.get_meta("pool_ladder_site", "")) != "wall":
			continue
		checked += 1
		var dir := int(node.get_meta("pool_ladder_dir", -1))
		var along := float(node.get_meta("pool_ladder_along", -INF))
		if dir < 0 or dir > 3:
			failures.append(
				"seed %d cell %s: wall ladder has no valid direction" % [
					si, cell])
			continue
		var nb := cell + Vector2i(WorldGen.DIRV[dir])
		var nb_chunk := Chunk.new(ws, nb, THEME)
		var waters := _meshes_with_meta(nb_chunk, "pool_water_surface")
		if waters.size() != 1:
			failures.append(
				"seed %d cell %s dir %d: ladder neighbor has no water layout" % [
					si, cell, dir])
			nb_chunk.free()
			continue
		var center: Vector2 = waters[0].get_meta("pool_water_center")
		var size: Vector2 = waters[0].get_meta("pool_water_size")
		var lo := center.y - size.y * 0.5 if dir < 2 \
			else center.x - size.x * 0.5
		var hi := center.y + size.y * 0.5 if dir < 2 \
			else center.x + size.x * 0.5
		if along - LADDER_HALF_WIDTH < lo \
				or along + LADDER_HALF_WIDTH > hi:
			failures.append(
				"seed %d cell %s dir %d: ladder %.2f lies outside water span %.2f..%.2f" % [
					si, cell, dir, along, lo, hi])
		nb_chunk.free()
	return checked


func _check_channel_seams(ws: int, cell: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	var waters := _meshes_with_meta(chunk, "pool_water_surface")
	if waters.size() != 1:
		return 0
	var links: Array = waters[0].get_meta("pool_water_edge_links", [])
	var checked := 0
	for dir_value in links:
		var dir := int(dir_value)
		# Check every pair once.
		if dir == 1 or dir == 3:
			continue
		var nb := cell + Vector2i(WorldGen.DIRV[dir])
		if WorldGen.cell_style(ws, nb, THEME) != WorldGen.POOL_CHANNEL:
			continue
		var nb_chunk := Chunk.new(ws, nb, THEME)
		var nb_waters := _meshes_with_meta(nb_chunk, "pool_water_surface")
		if nb_waters.size() != 1:
			nb_chunk.free()
			continue
		var a := _transverse_span(waters[0], dir)
		var b := _transverse_span(nb_waters[0], WorldGen.OPP[dir])
		checked += 1
		if not a.is_equal_approx(b):
			failures.append(
				"seed %d cell %s dir %d: channel span %s changes to %s" % [
					si, cell, dir, a, b])
		nb_chunk.free()
	return checked


func _check_channel_ladder_landing(
		ws: int, cell: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	var checked := 0
	for node in chunk.find_children("*", "Node3D", true, false):
		if not node.has_meta("pool_ladder") \
				or str(node.get_meta("pool_ladder_site", "")) != "ledge":
			continue
		checked += 1
		var dir := int(node.get_meta("pool_ladder_dir", -1))
		if dir < 0 or dir > 3:
			failures.append(
				"seed %d cell %s: channel ladder has invalid direction" % [
					si, cell])
			continue
		if dir < 2 and bool(
				WorldGen.edge_info(ws, cell, dir, THEME)["wall"]):
			failures.append(
				"seed %d cell %s dir %d: channel ladder returns into wall" % [
					si, cell, dir])
	return checked


func _check_dry_boundary_termini(ws: int, cell: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	if WorldGen.cell_style(ws, cell, THEME) != WorldGen.POOL_CHANNEL:
		return 0
	var waters := _meshes_with_meta(chunk, "pool_water_surface")
	if waters.size() != 1:
		return 0
	var links: Array = waters[0].get_meta("pool_water_edge_links", [])
	var coping := _meshes_with_meta(chunk, "pool_basin_coping")
	var center: Vector2 = waters[0].get_meta("pool_water_center")
	var size: Vector2 = waters[0].get_meta("pool_water_size")
	var checked := 0
	var channel_dirs := [0, 1]
	for dir in channel_dirs:
		var info := WorldGen.edge_info(ws, cell, dir, THEME)
		if bool(info["wall"]):
			continue
		var nb := cell + Vector2i(WorldGen.DIRV[dir])
		if not Chunk.pool_style_dry(
				WorldGen.cell_style(ws, nb, THEME)):
			continue
		checked += 1
		if links.has(dir):
			failures.append(
				"seed %d cell %s dir %d: dry terminus is still a water link" % [
					si, cell, dir])
		var water_edge := center.x + size.x * 0.5 if dir == 0 \
			else center.x - size.x * 0.5
		var expected_edge := Chunk.S - DRY_BOUNDARY_SETBACK \
			if dir == 0 else DRY_BOUNDARY_SETBACK
		if absf(water_edge - expected_edge) > 0.02:
			failures.append(
				"seed %d cell %s dir %d: water ends at %.2f, expected %.2f" % [
					si, cell, dir, water_edge, expected_edge])
		var found := false
		for slab in coping:
			var bounds := slab.transform * slab.get_aabb()
			match dir:
				0:
					found = bounds.position.x <= expected_edge + 0.35 \
						and bounds.end.x >= expected_edge - 0.08
				1:
					found = bounds.position.x <= expected_edge + 0.08 \
						and bounds.end.x >= expected_edge - 0.35
			if found:
				break
		if not found:
			failures.append(
				"seed %d cell %s dir %d: recessed terminus has no coping" % [
					si, cell, dir])
	return checked


func _check_connected_coping(ws: int, cell: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	var waters := _meshes_with_meta(chunk, "pool_water_surface")
	if waters.size() != 1:
		return 0
	var links: Array = waters[0].get_meta("pool_water_edge_links", [])
	var expected := 0
	for dir_value in links:
		var dir := int(dir_value)
		if dir >= 2:
			continue
		var nb := cell + Vector2i(WorldGen.DIRV[dir])
		if WorldGen.cell_style(ws, nb, THEME) == WorldGen.POOL_CHANNEL:
			expected += 1
	if expected == 0:
		return 0
	var turns := _meshes_with_meta(chunk, "pool_connected_coping_turn")
	for dir_value in links:
		var dir := int(dir_value)
		if dir >= 2:
			continue
		var nb := cell + Vector2i(WorldGen.DIRV[dir])
		if WorldGen.cell_style(ws, nb, THEME) != WorldGen.POOL_CHANNEL:
			continue
		var matching: Array[MeshInstance3D] = []
		for turn in turns:
			if int(turn.get_meta(
					"pool_connected_coping_dir", -1)) == dir:
				matching.append(turn)
		var nb_chunk := Chunk.new(ws, nb, THEME)
		var nb_waters := _meshes_with_meta(
			nb_chunk, "pool_water_surface")
		var expected_sides := {}
		if nb_waters.size() == 1:
			var own_span := _transverse_span(waters[0], dir)
			var nb_span := _transverse_span(
				nb_waters[0], WorldGen.OPP[dir])
			if absf(own_span.x - nb_span.x) > 0.18:
				expected_sides["low"] = true
			if absf(own_span.y - nb_span.y) > 0.18:
				expected_sides["high"] = true
		nb_chunk.free()
		if matching.size() != expected_sides.size():
			failures.append(
				"seed %d cell %s dir %d: expected %d continuous S bends, found %d" % [
					si, cell, dir, expected_sides.size(), matching.size()])
			continue
		var seen_sides := {}
		for turn in matching:
			if not bool(turn.get_meta(
					"pool_connected_coping_continuous", false)):
				failures.append(
					"seed %d cell %s dir %d: coping turn is still modular" % [
						si, cell, dir])
			var side := str(turn.get_meta(
				"pool_connected_coping_side", ""))
			seen_sides[side] = true
			var start: Vector2 = turn.get_meta(
				"pool_connected_coping_start", Vector2.INF)
			var end: Vector2 = turn.get_meta(
				"pool_connected_coping_end", Vector2.INF)
			var run := float(turn.get_meta(
				"pool_connected_coping_run", 0.0))
			var edge := chunk.S if dir == 0 else 0.0
			var expected_start_x := edge - run if dir == 0 \
				else edge + run
			var expected_end_x := edge + run if dir == 0 \
				else edge - run
			if absf(start.x - expected_start_x) > 0.01 \
					or absf(end.x - expected_end_x) > 0.01:
				failures.append(
					"seed %d cell %s dir %d: S bend does not straddle seam" % [
						si, cell, dir])
		for side in expected_sides:
			if not seen_sides.has(side):
				failures.append(
					"seed %d cell %s dir %d: S bend is missing %s side" % [
						si, cell, dir, side])
	return expected


func _transverse_span(water: MeshInstance3D, dir: int) -> Vector2:
	var center: Vector2 = water.get_meta("pool_water_center")
	var size: Vector2 = water.get_meta("pool_water_size")
	if dir < 2:
		return Vector2(center.y - size.y * 0.5, center.y + size.y * 0.5)
	return Vector2(center.x - size.x * 0.5, center.x + size.x * 0.5)


func _meshes_with_meta(root_node: Node, key: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(key):
			result.append(node as MeshInstance3D)
	return result
