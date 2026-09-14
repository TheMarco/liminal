extends "res://tools/lib/audit_base.gd"
## Real capsule-sized flood fill through every opening of Annex turning bays,
## plus deterministic spacing, opacity and symmetric room-opening contracts.
const STEP := 0.4
const COUNT := 28
var bays := 0
var ports := 0
var ghost_paths := 0

func _point(at: Vector2i) -> Vector3:
	return Vector3(0.6 + at.x * STEP, 0, 0.6 + at.y * STEP)

func _bay(ws: int, cell: Vector2i) -> void:
	var chunk := Chunk.new(ws, cell, 2)
	var markers := chunk.find_children("*", "Node3D", true, false).filter(
		func(node: Node) -> bool: return node.has_meta("annex_corridor_bend"))
	expect(markers.size() == 1, "missing turning bay at %s" % cell)
	if markers.is_empty():
		chunk.free()
		return
	var marker: Node3D = markers[0]
	expect(float(marker.get_meta("annex_bend_clearance")) >= 1.3, "turning bay too narrow")
	var axis := int(marker.get_meta("annex_bend_axis"))
	var lane := float(marker.get_meta("annex_bend_lane_width"))
	# At the middle plane every line joining the two original corridor mouths
	# lies inside their shared transverse interval; all of that interval is solid.
	for sample in 21:
		var along := 6.0 - lane * 0.5 + lane * sample / 20.0
		var point := Vector3(6, 0, along) if axis == 1 else Vector3(along, 0, 6)
		expect(not chunk._floor_spot_clear(point, 0.01, 1.8), "bend permits a straight sightline")
	var clear := {}
	for x in COUNT:
		for z in COUNT:
			var at := Vector2i(x, z)
			if chunk._floor_spot_clear(_point(at), 0.4, 1.8):
				clear[at] = true
	var entrances: Array[Vector2i] = []
	for dir in 4:
		var info := WorldGen.edge_info(ws, cell, dir, 2)
		if info.wall:
			continue
		var t := float(info.t)
		var target := Vector3(11.4, 0, t) if dir == 0 else Vector3(0.6, 0, t)
		if dir >= 2:
			target = Vector3(t, 0, 11.4 if dir == 2 else 0.6)
		var nearest := Vector2i(-1, -1)
		var distance := INF
		for at: Vector2i in clear:
			var d := _point(at).distance_squared_to(target)
			if d < distance:
				distance = d
				nearest = at
		expect(distance < 0.12, "blocked bay entrance seed=%d cell=%s dir=%d" % [ws, cell, dir])
		entrances.append(nearest)
		ports += 1
	var queue: Array[Vector2i] = [entrances[0]]
	var seen := {entrances[0]: true}
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for delta in WorldGen.DIRV:
			var next: Vector2i = at + delta
			if clear.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	for entrance in entrances:
		expect(seen.has(entrance), "turning bay disconnects exits seed=%d cell=%s" % [ws, cell])
	# Exercise the actual short-path solver with the ghost's wider capsule,
	# sweeping the generated collision instead of relying on graph reachability.
	var clear_travel := func(from: Vector3, to: Vector3) -> bool:
		var steps := maxi(1, ceili(from.distance_to(to) / 0.15))
		for step in range(steps + 1):
			if not chunk._floor_spot_clear(from.lerp(to, float(step) / steps),
					ShadowFigure.MOVE_RADIUS, ShadowFigure.MOVE_HEIGHT):
				return false
		return true
	var start := Vector3(0.6, 0, 6) if axis == 1 else Vector3(6, 0, 0.6)
	var goal := Vector3(11.4, 0, 6) if axis == 1 else Vector3(6, 0, 11.4)
	for reverse in [false, true]:
		var from := goal if reverse else start
		var to := start if reverse else goal
		var path := GhostLocalPath.new()._find(from, to, clear_travel, 0.0)
		expect(not path.is_empty(), "ghost cannot navigate turning bay seed=%d cell=%s" % [ws, cell])
		for point in path:
			expect(clear_travel.call(from, point), "ghost path clips bay wall")
			from = point
		expect(from.distance_to(to) < 0.01, "ghost path does not reach opposite exit")
		ghost_paths += 1
	expect(chunk.doorway_clearance_violations() == 0, "turning bay violates approach clearance")
	expect(chunk.annex_fixture_obstruction_violations() == 0, "turning bay intersects ceiling fixtures")
	if not WorldGen.annex_light_gap(ws, cell):
		expect(int(chunk.get_meta("annex_ceiling_fixture_count", 0)) == 2,
			"turning bay lost its entrance/exit fixtures")
	chunk.free()
	bays += 1

func run() -> void:
	var fixtures := {}
	for seed in [1, 4242, 240721]:
		var ws := WorldGen.level_seed(seed, 2)
		for axis in [1, 2]:
			for line in range(-3, 4):
				var last := -1000
				for step in range(-64, 65):
					var cell := Vector2i(step, line * 5) if axis == 1 else Vector2i(line * 6, step)
					if not WorldGen.annex_corridor_bend(ws, cell):
						continue
					expect(last == -1000 or step - last <= 3, "Annex retains an overlong straight corridor")
					last = step
					var width := WorldGen.annex_horizontal_width(ws, cell.y) if axis == 1 \
						else WorldGen.annex_vertical_width(ws, cell.x)
					var key := "%d:%d:%d" % [axis, roundi(width * 10), 1 if step < 0 else 0]
					if not fixtures.has(key):
						fixtures[key] = [ws, cell]
	for fixture in fixtures.values():
		_bay(fixture[0], fixture[1])
		await process_frame
	expect(fixtures.size() == 16, "missed an axis/width/negative-coordinate fixture")
	var openings := 0
	for theme in WorldGen.THEMES:
		var ws := WorldGen.level_seed(240721, theme)
		for x in range(-9, 10):
			for z in range(-9, 10):
				var cell := Vector2i(x, z)
				for dir in [0, 2]:
					var neighbor: Vector2i = cell + WorldGen.DIRV[dir]
					var info := WorldGen.edge_info(ws, cell, dir, theme)
					var reverse := WorldGen.edge_info(ws, neighbor, WorldGen.OPP[dir], theme)
					expect(info == reverse, "room opening is asymmetric")
					var a := WorldGen.annex_corridor_axis(ws, cell) if theme == 2 else WorldGen.corridor(ws, cell)
					var b := WorldGen.annex_corridor_axis(ws, neighbor) if theme == 2 else WorldGen.corridor(ws, neighbor)
					var same := WorldGen.annex_room_id(ws, cell) == WorldGen.annex_room_id(ws, neighbor) if theme == 2 \
						else WorldGen.room_id(ws, cell) == WorldGen.room_id(ws, neighbor)
					if info.wall or a != 0 or b != 0 or same:
						continue
					openings += 1
					expect(not info.full_open and float(info.w) <= 4.4, "separate rooms still lose their whole shared wall")
					expect(absf(float(info.t) - 6.0) - float(info.w) * 0.5 >= 0.79,
						"room opening preserves the central runway")
	expect(openings > 500, "insufficient room-chain coverage")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("SIGHTLINES bays=%d traversable_ports=%d ghost_paths=%d staggered_room_edges=%d max_annex_run=36m" % [bays, ports, ghost_paths, openings])
	finish("bounded sightlines and traversable turning bays")
