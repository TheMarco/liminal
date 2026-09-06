extends SceneTree

const THEME := 9
const SCAN_R := 8
const MAX_ROOMS_PER_SEED := 24
const SEEDS := [1029384756, 405195947, 918273645, 246813579, 135792468,
	777777777, 314159265, 271828182, 42424242, 987654321, 1122334455,
	556677889, 192837465, 8675309, 20260905, 808080808]

var _failures: Array[String] = []
var _checked_styles := {}
var _small_basins := 0
var _channels := 0
var _stairs := 0
var _wet_pier_chunks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for ws: int in SEEDS:
		var built := 0
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				if built >= MAX_ROOMS_PER_SEED:
					break
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				if style not in [WorldGen.POOL_BASIN, WorldGen.POOL_CHANNEL,
						WorldGen.POOL_STAIRS, WorldGen.POOL_CISTERN]:
					continue
				if WorldGen.room_id(ws, cell) != cell:
					continue
				var chunk := Chunk.new(ws, cell, THEME)
				get_root().add_child(chunk)
				built += 1
				_checked_styles[style] = int(_checked_styles.get(style, 0)) + 1
				if style == WorldGen.POOL_CHANNEL: _channels += 1
				if style == WorldGen.POOL_STAIRS: _stairs += 1
				_check_chunk(chunk, style, ws, cell)
				chunk.free()
				await process_frame
			if built >= MAX_ROOMS_PER_SEED:
				break
	# Explicit regression anchor requested by the production change.
	var explicit_ws := 1029384756
	var explicit := Chunk.new(explicit_ws, Vector2i(8, -2), THEME)
	get_root().add_child(explicit)
	_check_chunk(explicit, WorldGen.cell_style(explicit_ws, Vector2i(8, -2), THEME),
		1029384756, Vector2i(8, -2))
	explicit.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if _checked_styles.get(WorldGen.POOL_BASIN, 0) == 0 \
			or _checked_styles.get(WorldGen.POOL_CHANNEL, 0) == 0 \
			or _checked_styles.get(WorldGen.POOL_STAIRS, 0) == 0 \
			or _checked_styles.get(WorldGen.POOL_CISTERN, 0) == 0 \
			or _wet_pier_chunks == 0:
		_failures.append("inert pool style coverage: %s" % _checked_styles)
	print("POOL_LAYOUT checked=%s small=%d channels=%d stairs=%d wet_piers=%d" %
		[_checked_styles, _small_basins, _channels, _stairs, _wet_pier_chunks])
	for failure in _failures:
		push_error("POOL_LAYOUT FAIL: " + failure)
	if _failures.is_empty():
		print("POOL_LAYOUT PASS")
	quit(1 if not _failures.is_empty() else 0)

func _check_chunk(chunk: Chunk, style: int, seed: int, cell: Vector2i) -> void:
	if chunk.doorway_clearance_violations() != 0:
		_failures.append("seed %d cell %s: doorway clearance violation" % [seed, cell])
	var waters := _with_meta(chunk, "pool_water_surface")
	if waters.size() != 1:
		_failures.append("seed %d cell %s: expected exactly one water footprint" % [seed, cell])
		return
	var piers := _with_meta(chunk, "pool_pier")
	var water_area := 0.0
	var water_size := Vector2.ZERO
	var water_center := Vector2.ZERO
	if not waters.is_empty():
		water_size = waters[0].get_meta("pool_water_size", Vector2.ZERO)
		water_center = waters[0].get_meta("pool_water_center", Vector2.ZERO)
		water_area = water_size.x * water_size.y
	if water_area > 0.0 and water_area < 36.0:
		_small_basins += 1
	if water_area > 0.0 and (water_size.x < 6.0 or water_size.y < 6.0) and not piers.is_empty():
		_failures.append("seed %d cell %s: short-side basin has piers" % [seed, cell])
	if not piers.is_empty() and water_area > 0.0:
		_wet_pier_chunks += 1
	if style == WorldGen.POOL_CHANNEL or style == WorldGen.POOL_STAIRS:
		if not piers.is_empty():
			_failures.append("seed %d cell %s: %s has wet piers" % [seed, cell, style])
	if water_area < 36.0 and not piers.is_empty():
		_failures.append("seed %d cell %s: small basin has piers" % [seed, cell])
	if water_area < 70.0 and piers.size() > 1:
		_failures.append("seed %d cell %s: compact basin has %d piers" % [seed, cell, piers.size()])
	if water_area >= 70.0 and piers.size() > 2:
		_failures.append("seed %d cell %s: basin has %d piers" % [seed, cell, piers.size()])
	var supports := piers.duplicate()
	supports.append_array(_with_meta(chunk, "pool_rounded_pier_island"))
	for support: MeshInstance3D in supports:
		var p := _pier_center(support)
		var r := _pier_radius(support)
		var footprint := Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0)
		for lane: Rect2 in chunk.get_meta("pool_access_lanes", []):
			if footprint.intersects(lane):
				_failures.append("seed %d cell %s: support obstructs pool access" % [seed, cell])
		for lane: Rect2 in chunk._doorway_clearance_rects():
			if footprint.intersects(lane):
				_failures.append("seed %d cell %s: support obstructs doorway approach" % [seed, cell])
	for i in supports.size():
		var a := _pier_center(supports[i])
		var radius := _pier_radius(supports[i])
		if absf(a.x - water_center.x) < 0.8 + radius - 0.001 \
				or absf(a.y - water_center.y) < 0.8 + radius - 0.001:
			_failures.append("seed %d cell %s: pier crosses center band" % [seed, cell])
		var edge_gap := minf(minf(a.x - radius - (water_center.x - water_size.x * 0.5),
			water_center.x + water_size.x * 0.5 - a.x - radius),
			minf(a.y - radius - (water_center.y - water_size.y * 0.5),
			water_center.y + water_size.y * 0.5 - a.y - radius))
		if edge_gap < 0.90 - 0.001:
			_failures.append("seed %d cell %s: pier boundary gap %.2f" % [seed, cell, edge_gap])
		# An island is concentric with its own pier; pair spacing applies to piers.
		if i >= piers.size():
			continue
		for j in range(i):
			if a.distance_to(_pier_center(piers[j])) < 1.40 + radius + _pier_radius(piers[j]) - 0.001:
				_failures.append("seed %d cell %s: piers too close" % [seed, cell])
	if style == WorldGen.POOL_STAIRS:
		var stairs := _with_meta(chunk, "pool_walk_in_stairs")
		var ramps := _shapes_with_meta(chunk, "pool_entry_ramp")
		var valid_ramps := 0
		for ramp in ramps:
			if bool(ramp.get_meta("walkable_ramp", false)):
				valid_ramps += 1
		if stairs.is_empty() or ramps.size() != 1 or valid_ramps != 1:
			_failures.append("seed %d cell %s: stairs walk-in/ramp metadata incomplete" % [seed, cell])

func _with_meta(root: Node, key: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(key): result.append(node)
	return result

func _pier_center(node: MeshInstance3D) -> Vector2:
	var box := node.get_aabb()
	var world := _chunk_transform(node) * box.get_center()
	return Vector2(world.x, world.z)

func _pier_radius(node: MeshInstance3D) -> float:
	var box := node.get_aabb()
	var transformed := _chunk_transform(node) * box
	return maxf(transformed.size.x, transformed.size.z) * 0.5

func _chunk_transform(node: Node3D) -> Transform3D:
	var xf := node.transform
	var parent := node.get_parent()
	while parent is Node3D and not parent is Chunk:
		xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return xf

func _shapes_with_meta(root: Node, key: String) -> Array[CollisionShape3D]:
	var result: Array[CollisionShape3D] = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		if node.has_meta(key): result.append(node)
	return result
