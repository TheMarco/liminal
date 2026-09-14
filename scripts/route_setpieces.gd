class_name RouteSetpieces
extends ChunkLevelBuilder
## Route identities use furniture, not changes to the shared wall/floor graph.
## Compact fallback compositions fit a 12m room at real prop scale.
const NAMES := {1: "The final meeting", 2: "The waiting circle", 4: "Gate 00",
	5: "The empty ward", 6: "The last class", 7: "The closed cinema",
	8: "Visiting hours", 9: "The stopped pool clock", 10: "The signal choir",
	11: "The listening circle"}
const CLOCK_NAME := "The stopped clock"
const NATIVE := {1: WorldGen.OFFICE_BOARDROOM, 2: WorldGen.ANNEX_LOBBY,
	4: WorldGen.AIR_FOODCOURT, 5: WorldGen.ASY_CHAPEL, 6: WorldGen.SCH_AUDITORIUM,
	7: WorldGen.MALL_CINEMA, 8: WorldGen.PRISON_ROTUNDA,
	9: WorldGen.POOL_CISTERN, 10: WorldGen.BRUTAL_SANCTUM,
	11: WorldGen.BLOOM_STORM_APERTURE}

static func owner(route: DescentRoute, at: Vector2i) -> Vector2i:
	return WorldGen.annex_room_id(route.world_seed, at) if route.theme == 2 else WorldGen.room_id(route.world_seed, at)

static func eligible(route: DescentRoute, at: Vector2i) -> bool:
	if at in [owner(route, route.origin), owner(route, route.target), owner(route, route.objective_ritual_cell())] \
			or route.is_intro_door_room(at) or route.casino_landmarks.has(at) \
			or route.optional_vhs_cells().has(at):
		return false
	var members := WorldGen.owning_room_members(route.world_seed, at, route.theme)
	if members.size() == 3: return false # The centre of an L can be a wall.
	if route.theme == 2:
		if WorldGen.annex_corridor_axis(route.world_seed, at) != 0: return false
	else:
		if WorldGen.corridor(route.world_seed, at) != 0 \
				or not WorldGen.room_split(route.world_seed, at, route.theme).is_empty(): return false
	var style := WorldGen.cell_style(route.world_seed, at, route.theme)
	# These props ARE architecture: do not replace stairs, water courts, bars,
	# inserted tunnels or balcony supports with a furniture composition.
	return style not in [WorldGen.AIR_ESCALATOR, WorldGen.AIR_TRANSIT, WorldGen.AIR_BAGGAGE,
		WorldGen.MALL_ATRIUM, WorldGen.MALL_STORE, WorldGen.PRISON_CELLBLOCK,
		WorldGen.PRISON_CELLS, WorldGen.PRISON_SHOWER, WorldGen.BRUTAL_PASSAGE,
		WorldGen.BRUTAL_RAMP, WorldGen.BRUTAL_WATER_COURT, WorldGen.BRUTAL_ATRIUM,
		WorldGen.BLOOM_PASSAGE, WorldGen.BLOOM_ATRIUM]

static func plan_landmarks(route: DescentRoute) -> Dictionary:
	if route.floor_idx == 0 or not NAMES.has(route.theme): return {}
	var candidates: Array[Vector2i] = []
	var seen := {}
	for at in route.path_from_origin():
		var room := owner(route, at)
		if seen.has(room): continue
		seen[room] = true
		if eligible(route, room): candidates.append(room)
	if candidates.is_empty():
		# An unusual all-architectural route still gets a safe overhead identity;
		# do not flatten its stairs, water courts or partitions to make room.
		for at in route.path_from_origin():
			var room := owner(route, at)
			if room not in [owner(route, route.origin), owner(route, route.target)] \
					and not route.is_intro_door_room(room):
				return {room: CLOCK_NAME}
		return {}
	var chosen := candidates[candidates.size() / 2]
	for room in candidates:
		if WorldGen.cell_style(route.world_seed, room, route.theme) == NATIVE[route.theme]:
			chosen = room
			break
	return {chosen: str(NAMES[route.theme])}

## One reachable side-room recording, preferring actual dead ends. This is
## optional exploration, never an extra quota, required tape or compass target.
static func plan_discoveries(route: DescentRoute) -> Array[Vector2i]:
	var queue := route.path_from_origin()
	var distance := {}
	for at in queue: distance[at] = 0
	var candidates: Array[Vector2i] = []
	var dead_ends: Array[Vector2i] = []
	var seen := {}
	var head := 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		if int(distance[at]) >= 4: continue
		for dir in 4:
			if route.is_wall(at, dir): continue
			var next: Vector2i = at + WorldGen.DIRV[dir]
			if distance.has(next) or not route.scanned_contains(next): continue
			distance[next] = int(distance[at]) + 1
			queue.append(next)
			var room := owner(route, next)
			if seen.has(room) or route.is_path_room(room): continue
			seen[room] = true
			if not eligible(route, room): continue
			if route.theme == 9 and not Chunk.pool_style_dry(WorldGen.cell_style(route.world_seed, room, 9)): continue
			var members := WorldGen.owning_room_members(route.world_seed, room, route.theme)
			var exits := 0
			for member in members:
				for d in 4:
					if not members.has(member + WorldGen.DIRV[d]) and not route.is_wall(member, d): exits += 1
			candidates.append(room)
			if exits == 1: dead_ends.append(room)
	var pool := dead_ends if not dead_ends.is_empty() else candidates
	if pool.is_empty(): return []
	return [pool[posmod(WorldGen.h(route.world_seed, route.floor_idx, route.theme, 90317), pool.size())]]

func is_native() -> bool:
	return ctx.style == int(NATIVE.get(ctx.theme, -1))

func build_landmark(clock_only := false) -> void:
	var centre := Vector3(6, Chunk.cell_floor_h(ctx.world_seed, ctx.cell, ctx.theme), 6)
	# Anchor-cell compositions stay well away from every boundary, including
	# the per-cell circulation lanes inside larger merged rooms.
	var start := scene.chunk_child_count()
	var first := scene.collider_mark()
	var builder = Chunk.LEVEL_BUILDERS[ctx.theme].new(ctx, scene)
	match 9 if clock_only else ctx.theme:
		1:
			_table(centre, Vector2(3.2, 1.1), Mats.desk_white())
			for x in [-1.1, 0.0, 1.1]:
				for side in [-1.0, 1.0]: scene.task_chair(centre + Vector3(x, 0, side * 1.4), PI if side > 0 else 0)
			_board("MEETING IN PROGRESS", centre + Vector3(0, 1.95, 0), 3.2, 0.3, Mats.charcoal())
		2, 11:
			for i in 6:
				var angle := TAU * i / 6
				var p := centre + Vector3(sin(angle), 0, cos(angle)) * 1.65
				scene.attributed_floor_prop(Chunk.ANNEX_CHAIR_PATH, p, angle + PI,
					Chunk.ANNEX_CHAIR_SCALE, Chunk.ANNEX_CHAIR_CENTRE, "waiting_chair")
				scene.collider_yaw_box(p + Vector3(0, 0.47, 0), Chunk.ANNEX_CHAIR_COLLIDER_SIZE, angle + PI)
			if ctx.theme == 11:
				var growth := Node3D.new()
				growth.position = centre
				scene.add_node(growth)
				for i in 9:
					scene.model_ellipsoid(growth, Vector3(sin(i * 2.4) * 0.35, 0.25 + i * 0.2, cos(i * 2.4) * 0.35), Vector3(0.4, 0.28, 0.3), Mats.bloom_growth())
					if i > 0:
						var a := float(i - 1)
						scene.model_beam(growth, Vector3(sin(a * 2.4) * 0.35, 0.25 + a * 0.2, cos(a * 2.4) * 0.35), Vector3(sin(i * 2.4) * 0.35, 0.25 + i * 0.2, cos(i * 2.4) * 0.35), 0.18, Mats.bloom_growth())
				scene.collider_cylinder(centre + Vector3(0, 1, 0), 0.65, 2)
			else:
				_table(centre, Vector2(0.85, 0.85), Mats.darkwood())
				var clock := scene.cc0_prop("wall_clock", centre + Vector3(0, 0.82, 0), 0, 0.7)
				clock.rotation.x = -PI / 2
		4:
			_table(centre, Vector2(3.2, 0.9), Mats.sign_navy())
			_board("GATE 00\nALL DEPARTURES CANCELLED", centre + Vector3(0, 1.95, 0), 3.4, 0.75, Mats.sign_navy())
			for x in [-1.2, 1.2]:
				scene.attributed_floor_prop(Chunk.AIRPORT_LUGGAGE_PATH, centre + Vector3(x, 0, 1.45), 0,
					Chunk.AIRPORT_LUGGAGE_SCALE, Vector3.ZERO, "unclaimed_luggage")
		5:
			for x in [-1.45, 0.0, 1.45]: builder._asy_bed(centre + Vector3(x, 0, 0), 0, 9211)
			_board("NO PATIENTS", centre + Vector3(0, 2.05, -1.4), 2.2, 0.35, Mats.charcoal())
		6:
			for x in [-1.1, 1.1]:
				for z in [-0.6, 1.2]: builder._sch_desk(centre + Vector3(x, 0, z), PI, 9241)
			_board("CLASS DISMISSED", centre + Vector3(0, 1.55, -1.7), 3.3, 1.0, Mats.charcoal())
		7:
			_table(centre, Vector2(3.4, 0.85), Mats.darkwood())
			_board("TONIGHT\nNO SCREENING", centre + Vector3(0, 2.15, 0), 3.4, 0.85, Mats.darkwood())
			for x in [-1.1, 1.1]: scene.cc0_prop("CashRegister_01", centre + Vector3(x, 0.8, 0), 0, 0.75)
		8:
			_table(centre, Vector2(3.4, 0.85), Mats.prison_green())
			_board("VISITING HOURS\n00:00 - 00:00", centre + Vector3(0, 1.85, 0), 3.4, 0.85, Mats.prison_iron())
			for x in [-1.1, 1.1]:
				for side in [-1, 1]:
					scene.cylinder(centre + Vector3(x, 0.225, side * 1.25), 0.28, 0.45, Mats.prison_green())
		9:
			# Suspended above head height: never touch pool basins/decks/holes.
			_pool_clock(centre)
		10:
			for x in [-1.4, 0.0, 1.4]: builder._server_rack(centre + Vector3(x, 0, 0), 0)
			_board("SIGNAL LOST", centre + Vector3(0, 2.75, 0), 3.4, 0.45, Mats.charcoal())
	# Keep the whole scene atomic during doorway clearance, including colliders.
	var group := Node3D.new()
	group.name = "RouteLandmark"
	group.set_meta("route_landmark", ctx.route_landmark)
	scene.add_node(group)
	var pieces: Array[Node3D] = []
	for i in range(start, scene.chunk_child_count() - 1):
		var node := scene.chunk_child(i)
		if node is Node3D:
			pieces.append(node)
	for node in pieces:
		node.reparent(group, false)
	scene.claim_furnishing_group(group, "route_landmark", ctx.theme != 9)
	scene.bind_furnishing_colliders(group, first)
	scene.set_chunk_meta("route_landmark", ctx.route_landmark)

func _table(at: Vector3, extent: Vector2, material: Material) -> void:
	scene.box(at + Vector3(0, 0.76, 0), Vector3(extent.x, 0.08, extent.y), material)
	for x in [-extent.x * 0.43, extent.x * 0.43]:
		for z in [-extent.y * 0.37, extent.y * 0.37]:
			scene.box(at + Vector3(x, 0.36, z), Vector3(0.065, 0.72, 0.065), Mats.metal_gray())

func _board(text: String, at: Vector3, width: float, height: float, material: Material) -> void:
	var floor_y := Chunk.cell_floor_h(ctx.world_seed, ctx.cell, ctx.theme)
	# Thin upright sign with two supports, printed on both faces.
	scene.box(at, Vector3(width, height, 0.09), material)
	for x in [-width * 0.42, width * 0.42]:
		var h := maxf(0.1, at.y - height * 0.5 - floor_y)
		scene.cylinder(Vector3(at.x + x, floor_y + h * 0.5, at.z), 0.025, h, Mats.metal_gray())
	for side in [-1, 1]:
		var label := Label3D.new()
		label.text = text
		label.font = VhsOsd.FONT
		label.font_size = 64
		var longest := 1
		for line in text.split("\n"): longest = maxi(longest, line.length())
		label.pixel_size = minf(height / (80.0 * text.count("\n") + 100), width / (40.0 * longest))
		label.modulate = Color(0.83, 0.78, 0.62)
		label.outline_size = 0
		label.position = at + Vector3(0, 0, 0.051 * side)
		label.rotation.y = PI if side < 0 else 0
		scene.add_node(label)

func _pool_clock(at: Vector3) -> void:
	var y := ctx.ceiling_height - 0.5
	# Four faces share one solid housing and a mast fixed to the ceiling.
	scene.box(Vector3(at.x, y, at.z), Vector3(0.82, 0.72, 0.82), Mats.metal_gray(), false)
	for side in 4:
		var yaw := side * PI * 0.5
		var clock := Node3D.new()
		clock.name = "StoppedClock%d" % side
		clock.position = Vector3(at.x, y, at.z) + Vector3(sin(yaw), 0, cos(yaw)) * 0.425
		clock.rotation.y = yaw
		scene.add_node(clock)
		var face := scene.model_cylinder(clock, Vector3.ZERO, 0.33, 0.045, Mats.box_white())
		face.rotation.x = PI / 2
		for mark in 12:
			var angle := TAU * mark / 12
			var tick := scene.model_box(clock, Vector3(sin(angle) * 0.275, cos(angle) * 0.275, 0.026), Vector3(0.018, 0.065, 0.008), Mats.charcoal())
			tick.rotation.z = -angle
		scene.model_box(clock, Vector3(0, 0.11, 0.035), Vector3(0.018, 0.22, 0.014), Mats.charcoal())
		scene.model_box(clock, Vector3(0.065, 0, 0.039), Vector3(0.13, 0.022, 0.014), Mats.charcoal())
	# The centre mast attaches the clock cluster to the ceiling, not the floor.
	scene.cylinder(Vector3(at.x, y + 0.43, at.z), 0.045, 0.14, Mats.metal_gray(), false)
