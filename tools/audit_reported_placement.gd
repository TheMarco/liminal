extends SceneTree
## Regression coverage for the three Sep 13 playtest screenshots.
## godot --headless --path . --script tools/audit_reported_placement.gd

const RUN_SEED := 1898940031
var failures: Array[String] = []
var writings := 0
var booths := 0
var doors := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func run() -> void:
	await check_writing()
	check_airport()
	check_asylum()
	for failure in failures:
		print("  FAIL " + failure)
	print("reported placement audit: %d failures; %d phrases/poses, %d booths, %d doors" \
		% [failures.size(), writings, booths, doors])
	Chunk.finish_prop_preloads()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)


func check_writing() -> void:
	var raised_floor_checked := false
	for theme in WorldGen.THEMES:
		var ws := WorldGen.level_seed(RUN_SEED, theme)
		# Exercise each theme's tightest non-corridor floor-to-ceiling space.
		var cell := Vector2i.ZERO
		var height := INF
		for x in 12:
			for z in 12:
				var at := Vector2i(x, z)
				if WorldGen.corridor(ws, at) != 0:
					continue
				var h := Chunk.cell_ceil_h(ws, at, theme) - Chunk.cell_floor_h(ws, at, theme)
				if h < height:
					height = h
					cell = at
		var batch: Array[PhotoAnomaly] = []
		for phrase in PhotoAnomaly.PHRASES:
			for dir in 4:
				var anomaly := PhotoAnomaly.new()
				# Match production: configure before entering the scene tree.
				anomaly.configure("fit", PhotoAnomaly.Type.WRITING, cell, ws, theme, dir, 6.0)
				anomaly._writing_label.text = phrase
				root.add_child(anomaly)
				batch.append(anomaly)
		await process_frame
		await process_frame
		var floor_y := Chunk.cell_floor_h(ws, cell, theme)
		var ceiling_y := Chunk.cell_ceil_h(ws, cell, theme)
		raised_floor_checked = raised_floor_checked or floor_y > 0.0
		for anomaly in batch:
			var label := anomaly._writing_label
			var bounds := label.get_aabb()
			var scaled := bounds.size * label.scale
			check(label.visible and scaled.y > 0.1, "writing never became visible: " + label.text)
			check(scaled.x <= PhotoAnomaly.WRITING_MAX_WIDTH + 0.001,
				"writing exceeds its reserved wall width: " + label.text)
			check(scaled.y <= PhotoAnomaly.WRITING_MAX_HEIGHT + 0.001,
				"writing exceeds maximum height: " + label.text)
			for p in anomaly.photo_points():
				check(p.y >= floor_y + PhotoAnomaly.WRITING_FLOOR_MARGIN - 0.001,
					"writing intersects floor/skirting: " + label.text)
				check(p.y <= ceiling_y - PhotoAnomaly.WRITING_CEILING_MARGIN + 0.001,
					"writing intersects ceiling: " + label.text)
			writings += 1
			anomaly.free()
	check(raised_floor_checked, "writing regression missed raised Poolrooms floor")


func check_airport() -> void:
	var ws := WorldGen.level_seed(RUN_SEED, 4)
	var route := DescentRoute.build(ws, 4, 3)
	var topology := DescentTopology.new(ws, 4)
	route.set_topology(topology)
	topology.plan_floor(route)
	var cells: Array[Vector2i] = []
	# Covers the reported airport district, including room-centre shifts.
	for x in range(20, 65):
		for z in range(10, 60):
			var at := Vector2i(x, z)
			if WorldGen.room_id(ws, at) == at \
					and WorldGen.cell_style(ws, at, 4) == WorldGen.AIR_FOODCOURT:
				cells.append(at)
	check(not cells.is_empty(), "airport regression found no food courts")
	var cull_proven := false
	for cell in cells:
		for state in topology.state_count():
			var spec := ChunkBuildSpec.new()
			spec.descent = true
			spec.topology = topology
			spec.topology_state_override = state
			spec.furniture_variant_override = topology.furniture_variant_for_state(cell, state)
			var chunk := Chunk.new(ws, cell, 4, spec)
			check(chunk.doorway_clearance_violations() == 0, "food court blocks a doorway")
			check(chunk.atomic_furnishing_support_violations() == 0, "food court has orphan physics/support")
			for child in chunk.get_children():
				if str(child.get_meta("atomic_furnishing", "")) == "airport_foodcourt_booth":
					check_booth(chunk, child)
			# Deliberately put a booth through a real doorway lane. All its high
			# accessories and both grouped colliders must disappear with it.
			var zones := chunk._doorway_clearance_rects()
			if not cull_proven and not zones.is_empty():
				var centre := zones[0].get_center()
				var n0 := chunk.get_child_count()
				var b0 := chunk.body.get_child_count()
				chunk._level_builder._air_foodcourt_booth(Vector3(centre.x, 0, centre.y), "CULL TEST", false)
				check(chunk.get_child_count() == n0 + 1, "booth leaked top-level components")
				check_booth(chunk, chunk.get_child(n0))
				chunk._clear_furnishings_from_doorways(n0, b0)
				check(chunk.get_child_count() == n0, "cull left floating booth pieces")
				check(chunk.body.get_child_count() == b0, "cull left invisible booth collision")
				cull_proven = true
			chunk.free()
	check(cull_proven, "airport regression missed deliberate doorway cull")
	check(booths > 1, "airport regression saw no surviving generated booths")


func check_booth(chunk: Chunk, booth: Node3D) -> void:
	booths += 1
	check(booth.find_children("*", "MeshInstance3D", true, false).size() == 14,
		"concession lost base, jambs, backing, slats, counter or menu")
	check(booth.find_children("*", "Label3D", true, false).size() == 1,
		"concession lost its name")
	check(chunk._mesh_min_y(booth, Transform3D.IDENTITY) <= 0.01, "concession floats above floor")
	check(not chunk._furniture_mutation_eligible(booth), "fixed concession can slide/turn away from its site")
	var gid := int(booth.get_meta("furnishing_group"))
	var shapes := 0
	for child in chunk.body.get_children():
		if int(child.get_meta("furnishing_group", -1)) == gid:
			shapes += 1
	check(shapes == 2, "concession physics is not grouped with its visuals")


func mesh_bounds(node: Node, parent: Transform3D = Transform3D.IDENTITY) -> AABB:
	var xf := parent
	if node is Node3D:
		xf *= (node as Node3D).transform
	var out := AABB()
	if node is MeshInstance3D:
		out = xf * (node as MeshInstance3D).get_aabb()
	for child in node.get_children():
		var box := mesh_bounds(child, xf)
		if box.size != Vector3.ZERO:
			out = box if out.size == Vector3.ZERO else out.merge(box)
	return out


func check_asylum() -> void:
	var combinations := {}
	for base in [RUN_SEED] + range(1, 128):
		if combinations.size() == 16:
			break
		var ws := WorldGen.level_seed(base, 5)
		var pending: Array[int] = []
		for dir in 4:
			var pick := WorldGen.h(ws, 4, 3, 1194 + dir) % Chunk.ASY_DOOR_PATHS.size()
			if not combinations.has(Vector2i(dir, pick)):
				pending.append(dir)
		if pending.is_empty():
			continue
		var chunk := Chunk.new(ws, Vector2i(4, 3), 5)
		for dir in pending:
			var n0 := chunk.get_child_count()
			var plane := WorldGen.CELL_SIZE - Chunk.T * 0.5 if dir in [0, 2] else Chunk.T * 0.5
			chunk._level_builder._asy_locked_door_wall(dir, plane)
			check(chunk.get_child_count() == n0 + 1, "asylum facade model failed to load")
			var door := chunk.get_child(n0) as Node3D
			var inward := -Vector3(WorldGen.DIRV[dir].x, 0, WorldGen.DIRV[dir].y)
			check(door.basis.z.dot(inward) > 0.999, "asylum door faces across the wall")
			var box := mesh_bounds(door)
			var depth := box.size.x if dir < 2 else box.size.z
			var width := box.size.z if dir < 2 else box.size.x
			check(depth < 0.35 and width > 1.0, "asylum mesh protrudes sideways from wall")
			check(absf(box.position.y) < 0.02, "asylum leaf is not grounded")
			var leaf := door.get_child(0)
			combinations[Vector2i(dir, int(leaf.get_meta("asylum_authored_leaf")))] = true
			doors += 1
		check(int(chunk.asylum_authored_audit()["violations"]) == 0, "asylum authored audit failed")
		chunk.free()
	check(combinations.size() == 16, "asylum regression missed some model/direction combinations: %d/16" % combinations.size())
