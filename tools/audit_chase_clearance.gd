extends "res://tools/lib/audit_base.gd"
## Headless regression audit for chaseable room entrances and interior clearance.

const STEP := 0.2
const MIN := 0.6
const MAX := 11.4
const SAMPLES := 55
const SEEDS := [4242, 918273, 240721]
const THEMES := [6, 10]
const STYLES := {
	6: [WorldGen.SCH_CLASSROOM, WorldGen.SCH_CAFETERIA],
	10: [WorldGen.BRUTAL_HALL, WorldGen.BRUTAL_GALLERY, WorldGen.BRUTAL_SERVICE],
}

var cases := 0
var points := 0

func _point(at: Vector2i) -> Vector3:
	return Vector3(MIN + at.x * STEP, 0, MIN + at.y * STEP)

func _anchor(ws: int, theme: int, style: int) -> Vector2i:
	for radius in range(0, 40):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				if max(abs(x), abs(z)) != radius or WorldGen.room_id(ws, cell) != cell \
					or WorldGen.room_size(ws, cell) != 1:
					continue
				if WorldGen.cell_style(ws, cell, theme) == style:
					return cell
	return Vector2i(100000, 100000)

func _check(ws: int, theme: int, cell: Vector2i, style: int) -> void:
	cases += 1
	var chunk := Chunk.new(ws, cell, theme)
	if theme == 10 and cell == Vector2i.ZERO:
		# Check the actual compact-field crossing with a 1m-diameter capsule,
		# not merely a path around its perimeter. Old tightly packed rows fail.
		for i in 24:
			expect(chunk._floor_spot_clear(Vector3(6, 0, 3.8 + i * 0.2), 0.5, 1.8),
				"compact central aisle blocked seed=%d sample=%d" % [ws, i])
		for lane in [4.95, 7.25]:
			for i in 21:
				expect(chunk._floor_spot_clear(Vector3(4.0 + i * 0.2, 0, lane), 0.5, 1.8),
					"compact row aisle blocked seed=%d lane=%.2f sample=%d" % [ws, lane, i])
	if theme == 6 and style == WorldGen.SCH_CLASSROOM:
		var desks: Array[Node3D] = []
		for child in chunk.get_children():
			if child.has_meta("school_student_station"):
				desks.append(child)
		var gaps := 0
		for i in desks.size():
			for j in range(i + 1, desks.size()):
				if absf(desks[i].position.distance_to(desks[j].position) - 2.0) < 0.01:
					gaps += 1
					var middle := desks[i].position.lerp(desks[j].position, 0.5)
					middle.y = 0.0
					expect(chunk._floor_spot_clear(middle, 0.4, 1.8),
						"school inter-desk gap obstructed seed=%d cell=%s" % [ws, cell])
		expect(gaps >= 4, "school fixture lacks enough adjacent desks to test")
	var clear := {}
	for x in SAMPLES:
		for z in SAMPLES:
			var at := Vector2i(x, z)
			if chunk._floor_spot_clear(_point(at), 0.4, 1.8):
				clear[at] = true
	points += clear.size()
	var entrances: Array[Vector2i] = []
	for dir in 4:
		var info := chunk._edge_info(cell, dir)
		if info.wall:
			continue
		var nearest := Vector2i(-1, -1)
		var distance := INF
		for at: Vector2i in clear:
			var along := MIN + at.x * STEP if dir >= 2 else MIN + at.y * STEP
			var t := float(info.t)
			var inside := (along >= t - float(info.w) * 0.5 and along <= t + float(info.w) * 0.5)
			var boundary := MIN if dir == 1 or dir == 3 else MAX
			var edge_distance := absf((MIN + at.y * STEP) - boundary) if dir >= 2 else absf((MIN + at.x * STEP) - boundary)
			if edge_distance > 0.35:
				continue
			if bool(info.full_open) and not inside:
				continue
			var target := Vector3(MAX, 0, t) if dir == 0 else Vector3(MIN, 0, t)
			if dir >= 2:
				target = Vector3(t, 0, MAX if dir == 2 else MIN)
			var d := _point(at).distance_squared_to(target)
			if d < distance:
				distance = d
				nearest = at
		if nearest.x < 0:
			expect(false, "no clear entrance seed=%d theme=%d cell=%s style=%d dir=%d" % [ws, theme, cell, style, dir])
			continue
		if not bool(info.full_open):
			expect(sqrt(distance) <= 0.35, "entrance clearance seed=%d theme=%d cell=%s style=%d dir=%d" % [ws, theme, cell, style, dir])
		entrances.append(nearest)
	if entrances.is_empty():
		expect(false, "room has no entrances seed=%d theme=%d cell=%s style=%d" % [ws, theme, cell, style])
	else:
		var queue: Array[Vector2i] = [entrances[0]]
		var seen := {entrances[0]: true}
		var head := 0
		while head < queue.size():
			var at: Vector2i = queue[head]; head += 1
			for delta in WorldGen.DIRV:
				var next: Vector2i = at + delta
				if clear.has(next) and not seen.has(next):
					var midpoint := _point(at).lerp(_point(next), 0.5)
					if chunk._floor_spot_clear(midpoint, 0.4, 1.8):
						seen[next] = true; queue.append(next)
		for entrance in entrances:
			expect(seen.has(entrance), "entrance disconnected seed=%d theme=%d cell=%s style=%d" % [ws, theme, cell, style])
		var center := Vector2i(27, 27)
		var nearest_center := center
		var best := INF
		for center_at: Vector2i in clear:
			var d := _point(center_at).distance_to(Vector3(6, 0, 6))
			if d < best: best = d; nearest_center = center_at
		expect(best <= 2.0 and seen.has(nearest_center), "center isolated seed=%d theme=%d cell=%s style=%d" % [ws, theme, cell, style])
	chunk.free()

func run() -> void:
	expect(Chunk.SCH_DESK_COL_PITCH - 0.80 >= 1.1, "school desk column pitch too narrow")
	expect(Chunk.SCH_DESK_ROW_PITCH - 0.96 >= 1.0, "school desk row pitch too narrow")
	for seed in SEEDS:
		for theme in THEMES:
			var ws := WorldGen.level_seed(seed, theme)
			for style in STYLES[theme]:
				var cell := _anchor(ws, theme, style)
				if cell.x > 90000:
					expect(false, "missing style anchor seed=%d theme=%d style=%d" % [seed, theme, style]); continue
				_check(ws, theme, cell, style)
				await process_frame
			if theme == 10:
				_check(ws, theme, Vector2i.ZERO, -1)
				await process_frame
	print("CHASE_CLEARANCE cases=%d clear_samples=%d seeds=%d themes=%d" % [cases, points, SEEDS.size(), THEMES.size()])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("chase clearance and room reachability")
