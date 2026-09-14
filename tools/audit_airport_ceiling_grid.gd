extends SceneTree
## Verifies Airport ceiling fixtures against the 60cm world panel lattice.

const PITCH := 0.6
const SEAM_OFFSET := 0.3
const EPS := 0.002
const S := WorldGen.CELL_SIZE
var failures := 0
var lights := 0
var vents := 0
var transit_cells := 0
var grand_cells := 0
var grand_depths := {}
var grand_meshes := {}
var fitted_boards := 0
var fitted_signs := 0
var regular_mid_height_cells := 0
var regular_escalator_cells := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("AIRPORT_CEILING_GRID_AUDIT: " + message)

func _init() -> void:
	call_deferred("run")

func _fixture_nodes(chunk: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in chunk.find_children("*", "Node3D", true, false):
		if node.has_meta("airport_ceiling_fixture"):
			result.append(node as Node3D)
	return result

func _bounds(node: Node3D, offset: Vector3) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != node:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var box := node.transform * xf * mi.get_aabb()
		box.position += offset
		out = box if first else out.merge(box)
		first = false
	return out

func _local_bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != node:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var box := xf * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

func _audit_grand(node: Node3D, height: float, style: int) -> void:
	grand_cells += 1
	var drop := AirportGrandCeiling.depth(height, style)
	var expected_drop := 0.20 if style == WorldGen.AIR_ESCALATOR else (0.76 if height >= 6.0 else 0.42)
	check(is_equal_approx(drop, expected_drop), "grand ceiling has wrong depth")
	check(node.position.is_equal_approx(Vector3(0, height, 0)), "grand ceiling is not attached to the slab")
	if style == WorldGen.AIR_ESCALATOR:
		check(height - drop >= 4.19, "escalator landing has insufficient headroom")
	grand_depths[drop] = int(grand_depths.get(drop, 0)) + 1
	check(node.get_meta("coffer_count", -1) == 16, "%s coffer count is not 16" % node.name)
	check(is_equal_approx(float(node.get_meta("coffer_depth", -1.0)), drop), "%s depth metadata mismatch" % node.name)
	var meshes := node.find_children("*", "MeshInstance3D", false, false)
	check(meshes.size() == 4, "%s has %d MeshInstance3D children" % [node.name, meshes.size()])
	var total_triangles := 0
	for child in meshes:
		var mi := child as MeshInstance3D
		check(mi.get_child_count() == 0, "%s mesh child has unexpected descendants" % mi.name)
		check(mi.mesh != null, "%s has no mesh" % mi.name)
		if mi.mesh == null:
			continue
		var arrays := mi.mesh.surface_get_arrays(0)
		check(arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_VERTEX].size() > 0,
			"%s mesh arrays are empty" % mi.name)
		check(arrays[Mesh.ARRAY_NORMAL].size() > 0, "%s has no normals" % mi.name)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for normal in normals:
			check(normal.is_finite() and normal.y <= EPS, "%s has invalid/upward normal %s" % [mi.name, normal])
		var indices = arrays[Mesh.ARRAY_INDEX]
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		total_triangles += (indices.size() if indices != null and indices.size() > 0 else vertices.size()) / 3
		var key := roundi(drop * 1000.0)
		if not grand_meshes.has(key):
			grand_meshes[key] = []
		if not grand_meshes[key].has(mi.mesh.get_instance_id()):
			grand_meshes[key].append(mi.mesh.get_instance_id())
	var b := _local_bounds(node)
	check(absf(b.position.x) <= EPS and absf(b.position.z) <= EPS and absf(b.size.x - 12.0) <= EPS
		and absf(b.size.z - 12.0) <= EPS, "%s geometry bounds are not complete 12x12: %s" % [node.name, b])
	check(absf(b.position.y + drop) <= EPS and b.end.y <= EPS,
		"%s vertical bounds %s do not span -depth..0" % [node.name, b])
	check(total_triangles <= 700, "%s has %d triangles" % [node.name, total_triangles])
	check(grand_meshes[roundi(drop * 1000.0)].size() == 4,
		"depth %.2f does not use exactly four shared mesh resources" % drop)
	for body in node.find_children("*", "PhysicsBody3D", true, false):
		check(false, "%s contains physics node %s" % [node.name, body.name])

func _on_lattice(v: float) -> bool:
	var n := (v - SEAM_OFFSET) / PITCH
	return absf(n - round(n)) <= EPS / PITCH

func _scan(ws: int, cell: Vector2i) -> void:
	var chunk := Chunk.new(ws, cell, 4)
	var style := WorldGen.cell_style(ws, cell, 4)
	var boxes: Array[AABB] = []
	var sl := 0
	var sv := 0
	var grand_nodes := chunk.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
		return n.has_meta("airport_grand_ceiling"))
	# Keep this independent of the implementation threshold: intermediate
	# 4.4m rooms must never silently regain the wood ceiling treatment.
	var wants_grand := style != WorldGen.AIR_TRANSIT and chunk.ceil_h >= 6.2 - EPS
	check(grand_nodes.size() == (1 if wants_grand else 0), "style %d height %.2f has %d grand ceilings" % [style, chunk.ceil_h, grand_nodes.size()])
	var has_regular_roof := false
	var has_wood_roof := false
	for child in chunk.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.material_override == Mats.air_coffer_rib() or mi.material_override == Mats.air_coffer_inset():
			check(wants_grand, "wood material on ordinary ceiling at height %.2f, style %d" % [chunk.ceil_h, style])
		if mi.get_parent() == chunk and mi.position.y > chunk.ceil_h:
			has_regular_roof = has_regular_roof or mi.material_override == Mats.airport_ceiling()
			has_wood_roof = has_wood_roof or mi.material_override == Mats.air_coffer_inset()
	check(has_wood_roof if wants_grand else has_regular_roof, "ceiling slab material does not match its height tier")
	if is_equal_approx(chunk.ceil_h, 4.4):
		regular_mid_height_cells += 1
		check(not wants_grand, "4.4m room must retain regular panels")
	if style == WorldGen.AIR_ESCALATOR:
		regular_escalator_cells += 1
	for grand in grand_nodes:
		_audit_grand(grand as Node3D, chunk.ceil_h, style)
	if wants_grand:
		var soffit := chunk.ceil_h - AirportGrandCeiling.depth(chunk.ceil_h, style)
		for node in chunk.get_children():
			if node.has_meta("airport_sign_body_height"):
				fitted_signs += 1
				check(node.position.y + 0.275 <= soffit - 0.10, "wayfinding sign clips coffer")
			if node.has_meta("airport_hanging_board_height"):
				fitted_boards += 1
				var half_h := float(node.get_meta("airport_hanging_board_height")) * 0.5
				check(node.position.y + half_h <= soffit - 0.17, "departures board clips coffer")
				check(node.position.y - half_h >= 2.25 - EPS, "departures board crowds passenger headroom")
	for fixture in _fixture_nodes(chunk):
		var kind := String(fixture.get_meta("airport_ceiling_fixture", ""))
		check(not wants_grand, "ordinary airport fixture %s exists in grand ceiling cell" % fixture.name)
		var panels: Vector2i = fixture.get_meta("airport_ceiling_panels", Vector2i.ZERO)
		check(panels.x > 0 and panels.y > 0, "%s has invalid panel metadata" % fixture.name)
		var b := _bounds(fixture, Vector3(cell.x * S, 0, cell.y * S))
		var want := Vector2(panels) * PITCH
		check(absf(b.size.x - want.x) < 0.012 and absf(b.size.z - want.y) < 0.012,
			"%s size %s panels %s" % [fixture.name, b.size, panels])
		for edge in [b.position.x, b.end.x, b.position.z, b.end.z]:
			check(_on_lattice(edge), "%s edge %.4f misses lattice" % [fixture.name, edge])
		check(b.position.x >= cell.x * S - EPS and b.end.x <= (cell.x + 1) * S + EPS
			and b.position.z >= cell.y * S - EPS and b.end.z <= (cell.y + 1) * S + EPS,
			"%s crosses cell" % fixture.name)
		var ceiling_y := 3.5 if style == WorldGen.AIR_TRANSIT else chunk.ceil_h
		check(b.end.y <= ceiling_y + EPS and b.position.y >= ceiling_y - 0.10,
			"fixture is not recessed directly beneath ceiling datum")
		for old in boxes:
			check(not old.intersects(b.grow(-0.01)), "%s overlaps fixture" % fixture.name)
		boxes.append(b)
		if kind == "light":
			sl += 1
		elif kind == "vent":
			sv += 1
		else:
			check(false, "unknown fixture kind %s" % kind)
	var transit := style == WorldGen.AIR_TRANSIT
	check((sl == 0 and sv == 0) if wants_grand else (sl == 6 and sv == (0 if transit else 2)),
		"style %d has %d lights/%d vents" % [style, sl, sv])
	lights += sl
	vents += sv
	if transit:
		transit_cells += 1
	chunk.free()

func run() -> void:
	for style in [WorldGen.AIR_GATE, WorldGen.AIR_CONCOURSE, WorldGen.AIR_HALL,
			WorldGen.AIR_CHECKIN, WorldGen.AIR_BAGGAGE, WorldGen.AIR_ESCALATOR, WorldGen.AIR_TRANSIT]:
		for height in [3.2, 3.5, 3.8, 4.4, 6.2]:
			check(AirportGrandCeiling.applies(height, style) == (height == 6.2 and style != WorldGen.AIR_TRANSIT),
				"wood ceiling eligibility is wrong for height %.2f, style %d" % [height, style])
	var cap := Mats.annex_half_wall_cap()
	for wood in [Mats.air_coffer_rib(), Mats.air_coffer_inset()]:
		check(wood != cap and wood.albedo_texture == cap.albedo_texture,
			"grand ceiling must reuse the supplied wood without changing the Annex material")
		check(wood.uv1_triplanar and wood.uv1_world_triplanar
			and wood.uv1_scale.is_equal_approx(Vector3.ONE / 3.0),
			"grand ceiling wood grain is not world-mapped at the coffer scale")
		check(is_zero_approx(wood.metallic) and wood.emission_texture == wood.albedo_texture,
			"grand ceiling wood reverted to metal or lost textured cove bounce")
	var ceiling := Mats.airport_ceiling() as StandardMaterial3D
	check(ceiling.uv1_world_triplanar and ceiling.uv1_triplanar, "airport material is not world-triplanar")
	check(ceiling.uv1_scale.is_equal_approx(Vector3.ONE / PITCH), "airport material scale changed: %s" % ceiling.uv1_scale)
	var office := Mats.office_ceiling() as StandardMaterial3D
	check(office != ceiling and office.uv1_scale.is_equal_approx(Vector3.ONE / 0.75),
		"Airport changed the Office material")
	check(ceiling.albedo_texture == office.albedo_texture and ceiling.normal_enabled
		and ceiling.normal_texture != null and ceiling.roughness_texture != null,
		"Airport no longer uses the authored acoustic panel PBR maps")
	for seed in [1, 240721, 9137]:
		var ws := WorldGen.level_seed(seed, 4)
		for x in range(-3, 4):
			for z in range(-3, 4):
				_scan(ws, Vector2i(x, z))
	check(transit_cells > 0, "sample did not cover transit")
	check(grand_depths.size() == 1 and grand_depths.has(0.76), "only tallest halls should receive grand ceilings: %s" % grand_depths)
	check(regular_mid_height_cells > 0 and regular_escalator_cells > 0, "sample missed intermediate rooms/escalators")
	check(fitted_boards > 0 and fitted_signs > 0, "sample missed hanging boards/signs")
	print("Regular panels retained: %d intermediate rooms, %d escalator cells" % [regular_mid_height_cells, regular_escalator_cells])
	print("Grand ceiling clearances: %d fitted boards, %d hanging signs" % [fitted_boards, fitted_signs])
	print("AIRPORT_CEILING_GRID_AUDIT: cells=147 lights=%d vents=%d transit=%d grand=%d depths=%s shared_meshes=%d failures=%d" % [lights, vents, transit_cells, grand_cells, grand_depths, grand_meshes.size(), failures])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures else 0)
