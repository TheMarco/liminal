extends SceneTree
## Real player-sized floor routes through furnished Airport transit cells.
## Unlike a doorway-overlap audit, includes the low walkway ramps and checks
## that every open entrance belongs to the same walkable component.
const BASE_SEEDS := [1913359303, 240721, 9137]
const PITCH := 0.2
const INSET := 0.4
const GRID := 57
var failures := 0
var cases := 0
var entrances := 0
var axes := {}
var concourses := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("AIRPORT_PASSAGES: " + message)

func _point(at: Vector2i) -> Vector3:
	return Vector3(INSET + at.x * PITCH, 0.92, INSET + at.y * PITCH)

func _copy_physics(node: Node, parent_xf: Transform3D, holder: Node3D) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf *= (node as Node3D).transform
	if node is StaticBody3D:
		var body := StaticBody3D.new()
		body.transform = xf
		body.collision_layer = node.collision_layer
		body.collision_mask = node.collision_mask
		for child in node.get_children():
			if child is CollisionShape3D:
				body.add_child(child.duplicate())
		holder.add_child(body)
	for child in node.get_children():
		_copy_physics(child, xf, holder)

func _fixture_cells(ws: int, centre: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var counts := {1: 0, 2: 0}
	for radius in range(0, 18):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var cell := centre + Vector2i(dx, dz)
				var axis := WorldGen.corridor(ws, cell)
				if axis == 0 or counts[axis] >= 3 or WorldGen.cell_style(ws, cell, 4) != WorldGen.AIR_TRANSIT:
					continue
				var side_open := false
				for dir in ([2, 3] if axis == 1 else [0, 1]):
					side_open = side_open or not bool(WorldGen.edge_info(ws, cell, dir, 4)["wall"])
				if side_open:
					found.append(cell)
					counts[axis] += 1
		if counts[1] == 3 and counts[2] == 3:
			break
	return found

func _concourse_cells(ws: int, centre: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for radius in range(0, 22):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var cell := centre + Vector2i(dx, dz)
				if WorldGen.cell_style(ws, cell, 4) != WorldGen.AIR_CONCOURSE or WorldGen.room_size(ws, cell) != 1:
					continue
				var chunk := Chunk.new(ws, cell, 4)
				var has_belts := not chunk.find_children("*", "Travelator", true, false).is_empty()
				chunk.free()
				if has_belts:
					found.append(cell)
					if found.size() == 3:
						return found
	return found

func _scan(base: int, ws: int, cell: Vector2i) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var central: Chunk
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var chunk := Chunk.new(ws, cell + Vector2i(dx, dz), 4)
			chunk.position = Vector3(dx * 12.0, 0, dz * 12.0)
			# Use the actual generated shapes, including neighbours' boundary
			# walls, without starting unrelated audio/encounters in this probe.
			_copy_physics(chunk, Transform3D.IDENTITY, holder)
			if dx == 0 and dz == 0:
				central = chunk
			else:
				chunk.free()
	await physics_frame
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.collide_with_areas = false
	var space := holder.get_world_3d().direct_space_state
	for node in central.get_children():
		if node.has_meta("walkway_length_m"):
			var end_gap := (12.0 - float(node.get_meta("walkway_length_m")) - 1.12) * 0.5
			check(end_gap >= 1.20, "seed %d cell %s lacks a full-size end cross-aisle: %.2fm" % [base, cell, end_gap])
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID, GRID)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in GRID:
		for z in GRID:
			query.transform.origin = _point(Vector2i(x, z))
			grid.set_point_solid(Vector2i(x, z), not space.intersect_shape(query, 1).is_empty())
	var entries: Array[Vector2i] = []
	for dir in 4:
		var edge := central._edge_info(cell, dir)
		if edge["wall"]:
			continue
		var t := float(edge["t"])
		var p := Vector2(12.0 - INSET, t) if dir == 0 else Vector2(INSET, t) if dir == 1 \
			else Vector2(t, 12.0 - INSET) if dir == 2 else Vector2(t, INSET)
		var id := Vector2i(roundi((p.x - INSET) / PITCH), roundi((p.y - INSET) / PITCH))
		check(grid.is_in_boundsv(id) and not grid.is_point_solid(id),
			"seed %d cell %s entrance %d blocked at %s" % [base, cell, dir, p])
		if grid.is_in_boundsv(id) and not grid.is_point_solid(id):
			entries.append(id)
	for i in range(1, entries.size()):
		check(not grid.get_id_path(entries[0], entries[i]).is_empty(),
			"seed %d cell %s no floor route between entrances %s and %s" % [base, cell, entries[0], entries[i]])
	entrances += entries.size()
	cases += 1
	if central.style == WorldGen.AIR_TRANSIT:
		axes[WorldGen.corridor(ws, cell)] = true
	else:
		concourses += 1
	print("AIRPORT_PASSAGES case seed=%d cell=%s entrances=%d" % [base, cell, entries.size()])
	central.free()
	holder.free()
	await physics_frame

func run() -> void:
	for base in BASE_SEEDS:
		var ws := WorldGen.level_seed(base, 4)
		var centre := Vector2i(36, 47) if base == 1913359303 else Vector2i.ZERO
		var samples := _fixture_cells(ws, centre)
		check(samples.size() == 6, "missing transit sample coverage")
		for cell in samples:
			await _scan(base, ws, cell)
		var small_rooms := _concourse_cells(ws, centre)
		check(small_rooms.size() == 3, "missing single-cell concourse coverage")
		for cell in small_rooms:
			await _scan(base, ws, cell)
	check(axes.size() == 2 and entrances >= 54, "missing both-axis/side-entrance coverage")
	check(concourses == 9, "missing furnished concourse coverage")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("AIRPORT_PASSAGES: cells=%d concourses=%d entrances=%d axes=%d failures=%d" % [cases, concourses, entrances, axes.size(), failures])
	quit(1 if failures else 0)
