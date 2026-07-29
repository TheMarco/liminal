extends SceneTree
## Pool Rooms rounded-corner contract.  Every true L at a grid vertex is owned
## once by the south-west chunk, both incident wall runs stop at the shared
## tangent radius, and one quarter-annulus supplies render geometry, collision
## and crown trim.  T and four-way vertices preserve their through-wall runs,
## while every room quadrant bounded by two solid arms receives an additive
## curved inner cove with matching collision and crown trim.
##
## Run: godot --headless --path . --log-file /tmp/pool-audit.log \
##   --script tools/audit_pool_corners.gd -- [seeds]

const SCAN_R := 7
const BUILDS_PER_SEED := 12
const EPS := 0.035


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 4, 1, 12)
	var failures: Array[String] = []
	var checked_chunks := 0
	var checked_corners := 0
	var checked_walls := 0
	var checked_colliders := 0
	var checked_crowns := 0
	var checked_inner_coves := 0
	var checked_inner_cove_colliders := 0
	var checked_inner_cove_crowns := 0
	var checked_slabs := 0
	for si in seed_count:
		var base := WorldGen.h(7420, si * 41, si * 67, 913) | 1
		var ws := WorldGen.level_seed(base, 9)
		var picks := _pick_cells(ws)
		for c in picks:
			checked_chunks += 1
			var chunk := Chunk.new(ws, c, 9)
			var arms := Chunk.pool_corner_arms(ws, c)
			var rounded := _is_l(arms)
			var corner_meshes: Array[MeshInstance3D] = []
			var corner_crowns: Array[MeshInstance3D] = []
			var corner_colliders: Array[CollisionShape3D] = []
			var inner_coves: Array[MeshInstance3D] = []
			var inner_cove_crowns: Array[MeshInstance3D] = []
			var inner_cove_colliders: Array[CollisionShape3D] = []
			for m in chunk.find_children("*", "MeshInstance3D", true, false):
				if m.has_meta("pool_rounded_corner"):
					corner_meshes.append(m)
				if m.has_meta("pool_corner_crown"):
					corner_crowns.append(m)
				if m.has_meta("pool_inner_cove"):
					inner_coves.append(m)
				if m.has_meta("pool_inner_cove_crown"):
					inner_cove_crowns.append(m)
			for shape in chunk.find_children(
					"*", "CollisionShape3D", true, false):
				if shape.has_meta("pool_corner_collider"):
					corner_colliders.append(shape)
				if shape.has_meta("pool_inner_cove_collider"):
					inner_cove_colliders.append(shape)
			var want_meshes := 1 if rounded else 0
			if corner_meshes.size() != want_meshes:
				failures.append(
					"seed %d cell %s: expected %d rounded corner, built %d" % [
						si, c, want_meshes, corner_meshes.size()])
			if rounded and corner_meshes.size() == 1:
				checked_corners += 1
				_check_corner_mesh(
					ws, c, arms, corner_meshes[0], failures, si)
			var want_colliders := Chunk.POOL_CORNER_SEGMENTS if rounded else 0
			if corner_colliders.size() != want_colliders:
				failures.append(
					"seed %d cell %s: expected %d corner colliders, built %d" % [
						si, c, want_colliders, corner_colliders.size()])
			elif rounded:
				checked_colliders += corner_colliders.size()
				_check_corner_colliders(
					c, corner_colliders, failures, si)
			var want_crowns := 3 if rounded else 0
			if corner_crowns.size() != want_crowns:
				failures.append(
					"seed %d cell %s: expected %d curved crowns, built %d" % [
						si, c, want_crowns, corner_crowns.size()])
			elif rounded:
				checked_crowns += corner_crowns.size()
				_check_corner_crowns(
					ws, c, arms, corner_crowns, failures, si)
			var cove_quadrants := _inner_cove_quadrants(arms)
			if inner_coves.size() != cove_quadrants.size():
				failures.append(
					"seed %d cell %s: expected %d inner coves, built %d" % [
						si, c, cove_quadrants.size(), inner_coves.size()])
			elif not cove_quadrants.is_empty():
				checked_inner_coves += inner_coves.size()
				_check_inner_coves(
					ws, c, cove_quadrants, inner_coves, failures, si)
			var want_cove_colliders := \
				cove_quadrants.size() * Chunk.POOL_CORNER_SEGMENTS
			if inner_cove_colliders.size() != want_cove_colliders:
				failures.append(
					("seed %d cell %s: expected %d inner-cove colliders, " +
					"built %d") % [
						si, c, want_cove_colliders,
						inner_cove_colliders.size()])
			elif not cove_quadrants.is_empty():
				checked_inner_cove_colliders += inner_cove_colliders.size()
				_check_inner_cove_colliders(
					c, cove_quadrants, inner_cove_colliders, failures, si)
			if inner_cove_crowns.size() != cove_quadrants.size():
				failures.append(
					("seed %d cell %s: expected %d inner-cove crowns, " +
					"built %d") % [
						si, c, cove_quadrants.size(),
						inner_cove_crowns.size()])
			elif not cove_quadrants.is_empty():
				checked_inner_cove_crowns += inner_cove_crowns.size()
				_check_inner_cove_crowns(
					ws, c, cove_quadrants, inner_cove_crowns,
					failures, si)
			checked_walls += _check_walls(
				ws, c, chunk, failures, si)
			if Chunk.pool_style_dry(WorldGen.cell_style(ws, c, 9)):
				checked_slabs += 1
				if not _has_dry_slab(chunk):
					failures.append(
						"seed %d cell %s: dry slab is not one full square" % [
							si, c])
			chunk.free()
	print(("pool rounded-corner audit: %d seeds | %d chunks | %d rounded " +
		"corners, %d inner coves, %d wall ends, %d outer collider sectors, " +
		"%d inner collider sectors, %d curved outer crowns, %d curved inner " +
			"crowns, %d dry slabs checked") % [
			seed_count, checked_chunks, checked_corners,
			checked_inner_coves, checked_walls, checked_colliders,
			checked_inner_cove_colliders, checked_crowns,
			checked_inner_cove_crowns, checked_slabs])
	for req in [
			[checked_corners, "rounded corner"],
			[checked_inner_coves, "rounded inner cove"],
			[checked_walls, "wall endpoint"],
			[checked_colliders, "corner collider"],
			[checked_inner_cove_colliders, "inner-cove collider"],
			[checked_crowns, "curved crown"],
			[checked_inner_cove_crowns, "inner-cove crown"],
			[checked_slabs, "dry slab"],
	]:
		if int(req[0]) == 0:
			failures.append(
				"no %s was ever checked — audit is inert" % str(req[1]))
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print(("  PASS — tangent L-turns and T/cross inner coves have verified " +
		"meshes, collision, crowns and walls"))
	quit()


func _pick_cells(ws: int) -> Array[Vector2i]:
	var rounded: Array[Vector2i] = []
	var inner_coves: Array[Vector2i] = []
	var dry: Array[Vector2i] = []
	var other: Array[Vector2i] = []
	for x in range(-SCAN_R, SCAN_R + 1):
		for z in range(-SCAN_R, SCAN_R + 1):
			var c := Vector2i(x, z)
			var arms := Chunk.pool_corner_arms(ws, c)
			if _is_l(arms):
				if rounded.size() < 4:
					rounded.append(c)
			elif not _inner_cove_quadrants(arms).is_empty():
				if inner_coves.size() < 4:
					inner_coves.append(c)
			elif Chunk.pool_style_dry(WorldGen.cell_style(ws, c, 9)):
				if dry.size() < 2:
					dry.append(c)
			elif other.size() < 2:
				other.append(c)
	var result: Array[Vector2i] = []
	result.append_array(rounded)
	result.append_array(inner_coves)
	result.append_array(dry)
	result.append_array(other)
	if result.size() > BUILDS_PER_SEED:
		result.resize(BUILDS_PER_SEED)
	return result


func _is_l(arms: Array[Vector2i]) -> bool:
	return arms.size() == 2 \
		and arms[0].x * arms[1].x + arms[0].y * arms[1].y == 0


## Kept independent of Chunk.pool_inner_cove_quadrants so the audit can catch
## a production classifier regression rather than repeating it verbatim.
func _inner_cove_quadrants(arms: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if arms.size() < 3:
		return result
	for quadrant in [
			Vector2i(1, 1),
			Vector2i(-1, 1),
			Vector2i(-1, -1),
			Vector2i(1, -1),
	]:
		if arms.has(Vector2i(quadrant.x, 0)) \
				and arms.has(Vector2i(0, quadrant.y)):
			result.append(quadrant)
	return result


func _check_corner_mesh(ws: int, c: Vector2i, arms: Array[Vector2i],
		m: MeshInstance3D, failures: Array[String], si: int) -> void:
	var checks := {
		"pool_corner_radius": Chunk.POOL_PILLAR_RADIUS,
		"pool_corner_thickness": Chunk.POOL_WALL_T,
		"pool_corner_segments": float(Chunk.POOL_CORNER_SEGMENTS),
	}
	for key in checks:
		if not m.has_meta(key) \
				or absf(float(m.get_meta(key)) - float(checks[key])) > EPS:
			failures.append(
				"seed %d cell %s: corner has wrong %s" % [si, c, key])
	var want_vertex := c + Vector2i(1, 1)
	if m.get_meta("pool_corner_grid_vertex", Vector2i.ZERO) != want_vertex:
		failures.append(
			"seed %d cell %s: corner has wrong grid vertex" % [si, c])
	var want_top := maxf(
		_arm_top(ws, c, arms[0]), _arm_top(ws, c, arms[1]))
	if absf(float(m.get_meta("pool_corner_wall_top", -1.0)) - want_top) > EPS:
		failures.append(
			"seed %d cell %s: corner top does not match incident walls" % [
				si, c])
	var bb: AABB = m.transform * m.get_aabb()
	if absf(bb.position.y) > EPS \
			or absf(bb.position.y + bb.size.y - want_top) > EPS:
		failures.append(
			"seed %d cell %s: rounded mesh vertical bounds are wrong" % [si, c])


func _check_corner_colliders(c: Vector2i,
		colliders: Array[CollisionShape3D],
		failures: Array[String], si: int) -> void:
	var sectors: Array[bool] = []
	sectors.resize(Chunk.POOL_CORNER_SEGMENTS)
	sectors.fill(false)
	var want_vertex := c + Vector2i(1, 1)
	for shape in colliders:
		var sector := int(shape.get_meta("pool_corner_sector", -1))
		if sector < 0 or sector >= sectors.size():
			failures.append(
				"seed %d cell %s: collider has invalid sector %d" % [
					si, c, sector])
		else:
			sectors[sector] = true
		if shape.get_meta("pool_corner_grid_vertex", Vector2i.ZERO) \
				!= want_vertex:
			failures.append(
				"seed %d cell %s: collider has wrong grid vertex" % [si, c])
		if not (shape.shape is ConvexPolygonShape3D):
			failures.append(
				"seed %d cell %s: corner collider is not convex" % [si, c])
	for i in Chunk.POOL_CORNER_SEGMENTS:
		if not sectors[i]:
			failures.append(
				"seed %d cell %s: corner collider sector %d missing" % [
					si, c, i])


func _check_corner_crowns(ws: int, c: Vector2i,
		arms: Array[Vector2i], crowns: Array[MeshInstance3D],
		failures: Array[String], si: int) -> void:
	var quadrant := arms[0] + arms[1]
	var expected := {
		"inner": c + Vector2i(
			1 if quadrant.x > 0 else 0,
			1 if quadrant.y > 0 else 0),
		"outer_a": c + Vector2i(
			1 if (arms[0] - arms[1]).x > 0 else 0,
			1 if (arms[0] - arms[1]).y > 0 else 0),
		"outer_b": c + Vector2i(
			1 if (arms[1] - arms[0]).x > 0 else 0,
			1 if (arms[1] - arms[0]).y > 0 else 0),
	}
	var seen_inner := false
	var seen_outer_a := false
	var seen_outer_b := false
	for crown in crowns:
		var face := str(crown.get_meta("pool_corner_crown_face", ""))
		if not expected.has(face):
			failures.append(
				"seed %d cell %s: curved crown has unknown face" % [si, c])
			continue
		if face == "inner":
			seen_inner = true
		elif face == "outer_a":
			seen_outer_a = true
		else:
			seen_outer_b = true
		var room_cell: Vector2i = expected[face]
		if crown.get_meta("pool_corner_crown_cell", Vector2i.ZERO) \
				!= room_cell:
			failures.append(
				"seed %d cell %s: %s crown belongs to wrong room" % [
					si, c, face])
		var want_top := Chunk.cell_ceil_h(ws, room_cell, 9)
		var bb: AABB = crown.transform * crown.get_aabb()
		if absf(bb.position.y + bb.size.y - want_top) > EPS:
			failures.append(
				"seed %d cell %s: %s crown is at wrong ceiling" % [
					si, c, face])
	if not seen_inner:
		failures.append(
			"seed %d cell %s: inner curved crown missing" % [si, c])
	if not seen_outer_a:
		failures.append(
			"seed %d cell %s: arm-A outer curved crown missing" % [si, c])
	if not seen_outer_b:
		failures.append(
			"seed %d cell %s: arm-B outer curved crown missing" % [si, c])


func _check_inner_coves(ws: int, c: Vector2i,
		quadrants: Array[Vector2i], coves: Array[MeshInstance3D],
		failures: Array[String], si: int) -> void:
	var seen := {}
	var want_vertex := c + Vector2i(1, 1)
	var vertex := Vector2(Chunk.S, Chunk.S)
	var face_offset := Chunk.POOL_WALL_T * 0.5
	for cove in coves:
		var quadrant: Vector2i = cove.get_meta(
			"pool_inner_cove_quadrant", Vector2i.ZERO)
		if not quadrants.has(quadrant):
			failures.append(
				"seed %d cell %s: inner cove has unknown quadrant %s" % [
					si, c, quadrant])
			continue
		seen[quadrant] = int(seen.get(quadrant, 0)) + 1
		if cove.get_meta("pool_corner_grid_vertex", Vector2i.ZERO) \
				!= want_vertex:
			failures.append(
				"seed %d cell %s: inner cove has wrong grid vertex" % [si, c])
		if int(cove.get_meta("pool_corner_segments", -1)) \
				!= Chunk.POOL_CORNER_SEGMENTS:
			failures.append(
				"seed %d cell %s: inner cove has wrong segment count" % [si, c])
		var want_center := vertex + Vector2(quadrant) * Chunk.POOL_PILLAR_RADIUS
		var got_center: Vector2 = cove.get_meta(
			"pool_inner_cove_center_local", Vector2.ZERO)
		if got_center.distance_to(want_center) > EPS:
			failures.append(
				"seed %d cell %s: inner cove has wrong centre" % [si, c])
		var want_top := maxf(
			_arm_top(ws, c, Vector2i(quadrant.x, 0)),
			_arm_top(ws, c, Vector2i(0, quadrant.y)))
		if absf(float(cove.get_meta(
				"pool_inner_cove_wall_top", -1.0)) - want_top) > EPS:
			failures.append(
				"seed %d cell %s: inner cove top misses incident walls" % [
					si, c])
		var bb: AABB = cove.transform * cove.get_aabb()
		if absf(bb.position.y) > EPS \
				or absf(bb.position.y + bb.size.y - want_top) > EPS:
			failures.append(
				"seed %d cell %s: inner cove vertical bounds are wrong" % [
					si, c])
		var want_x0 := Chunk.S + (
			face_offset if quadrant.x > 0 else -Chunk.POOL_PILLAR_RADIUS)
		var want_x1 := Chunk.S + (
			Chunk.POOL_PILLAR_RADIUS if quadrant.x > 0 else -face_offset)
		var want_z0 := Chunk.S + (
			face_offset if quadrant.y > 0 else -Chunk.POOL_PILLAR_RADIUS)
		var want_z1 := Chunk.S + (
			Chunk.POOL_PILLAR_RADIUS if quadrant.y > 0 else -face_offset)
		if absf(bb.position.x - want_x0) > EPS \
				or absf(bb.position.x + bb.size.x - want_x1) > EPS \
				or absf(bb.position.z - want_z0) > EPS \
				or absf(bb.position.z + bb.size.z - want_z1) > EPS:
			failures.append(
				"seed %d cell %s: inner cove does not reach both tangencies" % [
					si, c])
	for quadrant in quadrants:
		if int(seen.get(quadrant, 0)) != 1:
			failures.append(
				"seed %d cell %s: quadrant %s has %d inner coves" % [
					si, c, quadrant, int(seen.get(quadrant, 0))])


func _check_inner_cove_colliders(c: Vector2i,
		quadrants: Array[Vector2i],
		colliders: Array[CollisionShape3D],
		failures: Array[String], si: int) -> void:
	var sectors := {}
	var want_vertex := c + Vector2i(1, 1)
	for quadrant in quadrants:
		var present: Array[bool] = []
		present.resize(Chunk.POOL_CORNER_SEGMENTS)
		present.fill(false)
		sectors[quadrant] = present
	for shape in colliders:
		var quadrant: Vector2i = shape.get_meta(
			"pool_inner_cove_quadrant", Vector2i.ZERO)
		var sector := int(shape.get_meta("pool_inner_cove_sector", -1))
		if not sectors.has(quadrant):
			failures.append(
				"seed %d cell %s: cove collider has unknown quadrant %s" % [
					si, c, quadrant])
		elif sector < 0 or sector >= Chunk.POOL_CORNER_SEGMENTS:
			failures.append(
				"seed %d cell %s: cove collider has invalid sector %d" % [
					si, c, sector])
		else:
			var present: Array = sectors[quadrant]
			present[sector] = true
			sectors[quadrant] = present
		if shape.get_meta("pool_corner_grid_vertex", Vector2i.ZERO) \
				!= want_vertex:
			failures.append(
				"seed %d cell %s: cove collider has wrong grid vertex" % [
					si, c])
		if not (shape.shape is ConvexPolygonShape3D):
			failures.append(
				"seed %d cell %s: inner-cove collider is not convex" % [si, c])
	for quadrant in quadrants:
		var present: Array = sectors[quadrant]
		for i in Chunk.POOL_CORNER_SEGMENTS:
			if not bool(present[i]):
				failures.append(
					"seed %d cell %s: quadrant %s collider sector %d missing" % [
						si, c, quadrant, i])


func _check_inner_cove_crowns(ws: int, c: Vector2i,
		quadrants: Array[Vector2i], crowns: Array[MeshInstance3D],
		failures: Array[String], si: int) -> void:
	var seen := {}
	var want_vertex := c + Vector2i(1, 1)
	for crown in crowns:
		var quadrant: Vector2i = crown.get_meta(
			"pool_inner_cove_quadrant", Vector2i.ZERO)
		if not quadrants.has(quadrant):
			failures.append(
				"seed %d cell %s: inner crown has unknown quadrant %s" % [
					si, c, quadrant])
			continue
		seen[quadrant] = int(seen.get(quadrant, 0)) + 1
		var room_cell := c + Vector2i(
			1 if quadrant.x > 0 else 0,
			1 if quadrant.y > 0 else 0)
		if crown.get_meta("pool_corner_grid_vertex", Vector2i.ZERO) \
				!= want_vertex:
			failures.append(
				"seed %d cell %s: inner crown has wrong grid vertex" % [si, c])
		if crown.get_meta(
				"pool_inner_cove_crown_cell", Vector2i.ZERO) != room_cell:
			failures.append(
				"seed %d cell %s: inner crown belongs to wrong room" % [si, c])
		var want_top := Chunk.cell_ceil_h(ws, room_cell, 9)
		var bb: AABB = crown.transform * crown.get_aabb()
		if absf(bb.position.y + bb.size.y - want_top) > EPS:
			failures.append(
				"seed %d cell %s: inner crown is at wrong ceiling" % [si, c])
	for quadrant in quadrants:
		if int(seen.get(quadrant, 0)) != 1:
			failures.append(
				"seed %d cell %s: quadrant %s has %d inner crowns" % [
					si, c, quadrant, int(seen.get(quadrant, 0))])


func _arm_top(ws: int, c: Vector2i, arm: Vector2i) -> float:
	var edge_cell := c
	var dir := 0
	if arm == Vector2i(1, 0):
		edge_cell += Vector2i(1, 0)
		dir = 2
	elif arm == Vector2i(-1, 0):
		dir = 2
	elif arm == Vector2i(0, 1):
		edge_cell += Vector2i(0, 1)
	return maxf(
		Chunk.cell_ceil_h(ws, edge_cell, 9),
		Chunk.cell_ceil_h(ws, edge_cell + WorldGen.DIRV[dir], 9))


func _check_walls(ws: int, c: Vector2i, chunk: Chunk,
		failures: Array[String], si: int) -> int:
	var checks := 0
	for m in chunk.find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta("pool_wall_dir"):
			continue
		var dir := int(m.get_meta("pool_wall_dir"))
		if dir != 0 and dir != 2:
			failures.append(
				"seed %d cell %s: wall built on non-owned dir %d" % [
					si, c, dir])
		var bb: AABB = m.transform * m.get_aabb()
		var want_top := maxf(
			Chunk.cell_ceil_h(ws, c, 9),
			Chunk.cell_ceil_h(ws, c + WorldGen.DIRV[dir], 9))
		if float(m.get_meta("pool_wall_y0", 0.0)) < EPS \
				and absf(bb.position.y + bb.size.y - want_top) > 0.05:
			failures.append(
				"seed %d cell %s dir %d: wall top is wrong" % [si, c, dir])
	for dir in [0, 2]:
		if bool(WorldGen.edge_info(ws, c, dir, 9)["full_open"]):
			continue
		for at_max in [false, true]:
			var kind := _end_kind(ws, c, dir, at_max)
			if kind == "open":
				continue
			checks += 1
			var want_end := _want_end(at_max, kind)
			var found := false
			for m in chunk.find_children(
					"*", "MeshInstance3D", true, false):
				if int(m.get_meta("pool_wall_dir", -1)) != dir \
						or float(m.get_meta("pool_wall_y0", 1.0)) > EPS:
					continue
				var bb: AABB = m.transform * m.get_aabb()
				var end := bb.position.z if not at_max \
					else bb.position.z + bb.size.z
				if dir >= 2:
					end = bb.position.x if not at_max \
						else bb.position.x + bb.size.x
				if absf(end - want_end) < EPS:
					found = true
					break
			if not found:
				failures.append(
					("seed %d cell %s dir %d at_max=%s (%s): no wall " +
					"end at %.3f") % [
						si, c, dir, at_max, kind, want_end])
	return checks


func _end_kind(ws: int, c: Vector2i, dir: int, at_max: bool) -> String:
	if bool(WorldGen.edge_info(ws, c, dir, 9)["full_open"]):
		return "open"
	var collinear: Array
	var perp_a: Array
	var perp_b: Array
	match dir:
		0:
			collinear = [c + Vector2i(0, 1 if at_max else -1), 0]
			perp_a = [c, 2 if at_max else 3]
			perp_b = [c + Vector2i(1, 0), 2 if at_max else 3]
		1:
			collinear = [c + Vector2i(0, 1 if at_max else -1), 1]
			perp_a = [c, 2 if at_max else 3]
			perp_b = [c + Vector2i(-1, 0), 2 if at_max else 3]
		2:
			collinear = [c + Vector2i(1 if at_max else -1, 0), 2]
			perp_a = [c, 0 if at_max else 1]
			perp_b = [c + Vector2i(0, 1), 0 if at_max else 1]
		_:
			collinear = [c + Vector2i(1 if at_max else -1, 0), 3]
			perp_a = [c, 0 if at_max else 1]
			perp_b = [c + Vector2i(0, -1), 0 if at_max else 1]
	if not bool(WorldGen.edge_info(
			ws, collinear[0] as Vector2i, int(collinear[1]), 9)["full_open"]):
		return "straight"
	var has_a := not bool(WorldGen.edge_info(
		ws, perp_a[0] as Vector2i, int(perp_a[1]), 9)["full_open"])
	var has_b := not bool(WorldGen.edge_info(
		ws, perp_b[0] as Vector2i, int(perp_b[1]), 9)["full_open"])
	if has_a and has_b:
		return "t"
	if has_a or has_b:
		return "l"
	return "free"


func _want_end(at_max: bool, kind: String) -> float:
	var retract := 0.0
	if kind == "t":
		retract = Chunk.POOL_WALL_T * 0.5
	elif kind == "l":
		retract = Chunk.POOL_PILLAR_RADIUS
	return Chunk.S - retract if at_max else retract


func _has_dry_slab(chunk: Chunk) -> bool:
	for m in chunk.find_children("*", "MeshInstance3D", true, false):
		if not (m.mesh is BoxMesh):
			continue
		var bb: AABB = m.transform * m.get_aabb()
		if bb.size.x > Chunk.S - EPS and bb.size.z > Chunk.S - EPS \
				and absf(
					bb.position.y + bb.size.y - Chunk.POOL_DRY_Y) < 0.05:
			return true
	return false
