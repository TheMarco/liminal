extends SceneTree
## Regression audit for charging-station placement clearance and water exclusion.
## godot --headless --path . --script tools/audit_charging_station_placement.gd

var failures := 0
var checks := 0
var built := 0
var stations := 0
var missing_cells: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHARGING_STATION_AUDIT: " + message)

func box(parent: Node, at: Vector3, size: Vector3, meta := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	if meta != "":
		node.set_meta(meta, true)
	parent.add_child(node)
	return node

func slab(parent: Node, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	shape.position = at
	body.add_child(shape)
	parent.add_child(body)

func plane(parent: Node, at: Vector3, size: Vector2, meta: String) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.set_meta(meta, true)
	parent.add_child(node)

func synthetic() -> void:
	var chunk := Node3D.new()
	slab(chunk, Vector3(6, -0.1, 6), Vector3(12, 0.2, 12))
	box(chunk, Vector3(2.0, 0.9, 2.0), Vector3(1.0, 1.8, 1.0))
	var nested := Node3D.new()
	nested.position = Vector3(4, 0, 4)
	box(nested, Vector3.ZERO, Vector3(1.0, 1.8, 1.0))
	chunk.add_child(nested)
	var geometry := ChargingStationPlacement.new(chunk)
	check(geometry.clear(Vector3(6, 0, 6), 0.0, false, []), "clear dry baseline rejected")
	check(not geometry.clear(Vector3(2, 0, 2), 0.0, false, []), "visual obstacle was not rejected")
	check(not geometry.clear(Vector3(4, 0, 4), 0.0, false, []), "nested obstacle was not rejected")
	check(not geometry.clear(Vector3(6, 0, 6), 0.0, false, [Rect2(5.45, 5.45, 1.0, 1.0)]), "doorway overlap was not rejected")
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		check(geometry.clear(Vector3(6, 0, 6), yaw, false, []), "dry baseline rejected at yaw %f" % yaw)
	chunk.free()

	# An object can miss the cabinet while occupying the standing space.
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		var access := Node3D.new()
		var fixture := Node3D.new()
		fixture.position = Vector3(6, 0, 6)
		fixture.rotation.y = yaw
		access.add_child(fixture)
		slab(fixture, Vector3(0, 0.7, 0.95), Vector3(0.4, 1.4, 0.3))
		geometry = ChargingStationPlacement.new(access)
		check(not geometry.clear(Vector3(6, 0, 6), yaw, false, []),
			"nested solid in standing space accepted")
		access.free()

	var wet := Node3D.new()
	slab(wet, Vector3(6, -0.1, 6), Vector3(12, 0.2, 12))
	geometry = ChargingStationPlacement.new(wet)
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		check(geometry.clear(Vector3(6, 0, 6), yaw, true, []), "dry pool deck rejected")
	plane(wet, Vector3(6, -0.3, 6), Vector2(2.0, 2.0), "pool_water_surface")
	var bath := Node3D.new()
	bath.position = Vector3(9, 0, 9)
	wet.add_child(bath)
	plane(bath, Vector3(0, -0.25, 0), Vector2(2.0, 2.0), "pool_jacuzzi_water")
	geometry = ChargingStationPlacement.new(wet)
	check(not geometry.clear(Vector3(6, 0, 6), 0.0, true, []), "pool water was not rejected")
	check(not geometry.clear(Vector3(9, 0, 9), 0.0, true, []), "nested jacuzzi water was not rejected")
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		check(not geometry.clear(Vector3(6, 0, 6), yaw, true, []), "water accepted at yaw %f" % yaw)
	wet.free()

func has_station(chunk: Chunk) -> Node3D:
	for child in chunk.get_children():
		if child is Node3D and child.has_meta("charging_station"):
			return child as Node3D
	return null

func sweep() -> void:
	for seed in [7, 918273, 405195947]:
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(seed, theme)
			for x in range(-3, 6):
				for z in range(-3, 6):
					var cell := Vector2i(x, z)
					var chunk := Chunk.new(ws, cell, theme)
					built += 1
					var station := has_station(chunk)
					if station == null:
						if chunk._is_charging_station_cell():
							missing_cells[theme] = int(missing_cells.get(theme, 0)) + 1
						chunk.free()
						continue
					stations += 1
					var geometry := ChargingStationPlacement.new(chunk)
					check(geometry.clear(station.position, station.rotation.y, theme == 9,
						chunk._doorway_clearance_rects()), "seed %d theme %d cell %s station overlaps" % [seed, theme, cell])
					chunk.free()

func descent_targets() -> void:
	for base in [7, 918273, 405195947]:
		var order := DescentRun.order_for(base)
		for floor_idx in range(DescentRun.FLOOR_COUNT - 1):
			var theme: int = order[floor_idx]
			var ws := WorldGen.level_seed(base, theme)
			var route := DescentRoute.build(ws, theme, floor_idx)
			var chunk := Chunk.new(ws, route.target, theme, {"descent": true, "target": true,
				"target_wall": route.target_wall, "floor_idx": floor_idx, "base_seed": base})
			var station := has_station(chunk)
			check(station != null, "seed %d floor %d target missing station" % [base, floor_idx + 1])
			if station != null:
				var geometry := ChargingStationPlacement.new(chunk)
				check(geometry.clear(station.position, station.rotation.y, theme == 9,
					chunk._doorway_clearance_rects()), "seed %d floor %d target station not clear" % [base, floor_idx + 1])
			chunk.free()

func run() -> void:
	synthetic()
	sweep()
	descent_targets()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("CHARGING_STATION_AUDIT: %s checks=%d failures=%d missing_selected=%s chunks=%d stations=%d" % [
		"PASS" if failures == 0 else "FAIL", checks, failures, missing_cells, built, stations])
	quit(1 if failures else 0)
