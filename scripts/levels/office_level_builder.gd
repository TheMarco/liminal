extends "res://scripts/levels/chunk_level_builder.gd"


func _office_door_decor(dir: int, plane: float) -> void:
	var along = WorldGen.CELL_SIZE / 2.0 + (ctx.random01(46 + dir) - 0.5) * 5.0
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (Chunk.T / 2.0)
	var fc = inner + n * 0.02
	if dir < 2:
		scene.box(Vector3(fc, 1.06, along), Vector3(0.05, 2.1, 1.0), Mats.wood_door(), false)
		scene.cylinder(Vector3(fc + n * 0.03, 1.05, along + 0.36), 0.02, 0.12, Mats.chrome(), false)
	else:
		scene.box(Vector3(along, 1.06, fc), Vector3(1.0, 2.1, 0.05), Mats.wood_door(), false)
		scene.cylinder(Vector3(along + 0.36, 1.05, fc + n * 0.03), 0.02, 0.12, Mats.chrome(), false)


## Plain wall clock — the kind that makes time feel slower.


func _office_lighting() -> void:
	if ctx.style == WorldGen.OFFICE_CORRIDOR:
		_office_corridor_lighting()
		return
	var is_spawn = ctx.cell == Vector2i.ZERO
	var dead = (not is_spawn) and ctx.random01(8) < 0.02
	var flicker = (not is_spawn) and (not dead) and ctx.random01(9) < 0.05
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	# dense, even grid of fluorescent troffers — shadowless corporate daylight
	for gx in [3.0, 9.0]:
		for gz in [2.1, 4.7, 7.3, 9.9]:
			scene.troffer(Vector3(gx, 0, gz), Vector2(1.15, 0.55), pmat, Mats.metal_gray())
	# AC diffuser grilles between the light rows
	for vp in [Vector2(6.0, 3.4), Vector2(6.0, 8.6)]:
		scene.box(Vector3(vp.x, ctx.ceiling_height - 0.015, vp.y), Vector3(0.62, 0.03, 0.62), Mats.metal_gray(), false)
		for si in 4:
			scene.box(Vector3(vp.x, ctx.ceiling_height - 0.035, vp.y - 0.21 + 0.14 * float(si)),
				Vector3(0.54, 0.012, 0.05), Mats.charcoal(), false)
	if dead:
		return
	var light = scene.main_light(flicker, pmat, 1.0)
	light.light_color = Color(0.93, 1.0, 0.95)
	light.omni_range = 12.5
	light.position = Vector3(WorldGen.CELL_SIZE / 2.0, ctx.ceiling_height - 0.5, WorldGen.CELL_SIZE / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	scene.add_node(light)


## Corridor fixtures follow the actual lane instead of filling the entire
## 12m cell.  Besides reading as intentional architecture, this prevents
## light from leaking out of the reserved office volumes behind locked doors.


func _office_corridor_lighting() -> void:
	var cdir = WorldGen.corridor(ctx.world_seed, ctx.cell)
	var along_x = cdir != 2
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var dead = ctx.random01(8) < 0.025
	var flicker = not dead and ctx.random01(9) < 0.07
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	for t in [-4.5, -1.5, 1.5, 4.5]:
		var at = scene.world_point(o, Vector3(t, 0, 0), yw)
		scene.troffer(at, Vector2(1.15, 0.5) if along_x else Vector2(0.5, 1.15),
			pmat, Mats.metal_gray())
	# One supply and one return grille, both kept over the corridor rather than
	# in the inaccessible office strips.
	for t in [-3.0, 3.0]:
		var vp = scene.world_point(o, Vector3(t, ctx.ceiling_height - 0.018, 0.88 if t < 0.0 else -0.88), yw)
		var grille = scene.model_box(null, vp, Vector3(0.58, 0.032, 0.58), Mats.metal_gray())
		grille.rotation.y = yw
	if dead:
		return
	var light = scene.main_light(flicker, pmat, 0.82)
	light.light_color = Color(0.91, 1.0, 0.94)
	light.omni_range = 10.5
	light.position = Vector3(WorldGen.CELL_SIZE / 2.0, ctx.ceiling_height - 0.48, WorldGen.CELL_SIZE / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	scene.add_node(light)


## Ceiling light fixture: recessed glowing lens inside a trim frame, instead
## of a bare emissive slab stuck to the tiles.


func _office_floor_files(p: Vector3, salt: int) -> void:
	for i in 3:
		var v = Node3D.new()
		var ox = -0.30 if i != 1 else 0.30
		v.position = p + Vector3(ox, 0, -0.14)
		v.rotation.y = (ctx.random01(salt + i) - 0.5) * 0.34
		scene.add_node(v)
		var y = 0.70 if i == 2 else 0.24
		scene.model_rounded_box(v, Vector3(0, y, 0), Vector3(0.58, 0.46, 0.48), Mats.box_white(), 0.015)
		scene.model_box(v, Vector3(0, y + 0.235, 0), Vector3(0.5, 0.018, 0.4), Mats.paint_white())
	scene.scattered_papers(p + Vector3(0.6, 0, 0.35), salt + 8, 6)
	scene.collider_box(p + Vector3(0, 0.42, 0), Vector3(1.25, 0.84, 1.0))


# --- office props ------------------------------------------------------------

## One or two real split-system indoor units per generated office room. The
## room anchor owns the whole set, including merged multi-cell rooms, so the
## same room never receives a duplicate from each member chunk.


func _office_air_conditioners(split: Array) -> void:
	var candidates = []
	var wall_off = 0.165
	var mount_y = ctx.ceiling_height - 0.34
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for member in scene.room_members():
		var base = Vector3(float(member.x - ctx.cell.x) * WorldGen.CELL_SIZE, 0.0,
			float(member.y - ctx.cell.y) * WorldGen.CELL_SIZE)
		for dir in 4:
			var neighbour: Vector2i = member + directions[dir]
			if WorldGen.room_id(ctx.world_seed, neighbour) == ctx.room_root:
				continue
			var info = scene.edge_info(member, dir)
			# A split-system unit belongs on an uninterrupted structural wall.
			# Doorway headers and open/glass partitions are not mounts: both made
			# the cabinet visibly float or straddle circulation openings.
			if not bool(info["wall"]) or bool(info["full_open"]):
				continue
			# Two edge-biased bays leave the centre available for pictures,
			# clocks and door signage while still allowing a pair in a large room.
			for slot in 2:
				var along = 3.0 if slot == 0 else 9.0
				var partition_hits_wall = not split.is_empty() \
					and ((bool(split[0]) and dir < 2) \
						or (not bool(split[0]) and dir >= 2))
				if partition_hits_wall \
						and absf(along - float(split[1])) < 0.82:
					continue
				# Wall art is emitted by each member chunk before this room-root
				# fixture exists. Predict its exact interval and reject a true
				# wall-plane overlap; a score penalty still allowed collisions
				# whenever every otherwise attractive wall was decorated.
				var art := scene.office_wall_art_layout(member, dir)
				if not art.is_empty():
					var art_size: Vector2 = art["size"]
					var horizontal_overlap := absf(along - float(art["along"])) \
						< 0.625 + art_size.x * 0.5 + 0.10
					var vertical_overlap := absf(mount_y - float(art["y"])) \
						< 0.21 + art_size.y * 0.5 + 0.08
					if horizontal_overlap and vertical_overlap:
						continue
				var p: Vector3
				match dir:
					0:
						p = base + Vector3(WorldGen.CELL_SIZE - Chunk.T - wall_off, mount_y, along)
					1:
						p = base + Vector3(Chunk.T + wall_off, mount_y, along)
					2:
						p = base + Vector3(along, mount_y, WorldGen.CELL_SIZE - Chunk.T - wall_off)
					_:
						p = base + Vector3(along, mount_y, Chunk.T + wall_off)
				var decor_busy = WorldGen.r01(ctx.world_seed, member.x, member.y,
					1040 + dir) < scene.wall_art_chance() \
					or WorldGen.r01(ctx.world_seed, member.x, member.y, 40 + dir) < 0.58
				var score = posmod(WorldGen.h(ctx.world_seed, member.x * 5 + slot,
					member.y * 7 - dir, 1880), 100000)
				if decor_busy:
					score += 100000
				candidates.append({
					"member": member, "dir": dir, "slot": slot,
					"position": p, "score": score, "suspended": false,
					"along": along,
				})
	if candidates.is_empty():
		return
	var desired = 2 if ctx.room_size >= 2 \
		or WorldGen.r01(ctx.world_seed, ctx.room_root.x, ctx.room_root.y, 1881) < 0.28 else 1
	var selected = []
	while selected.size() < desired and not candidates.is_empty():
		var best_idx = 0
		var best_score = 1 << 30
		for i in candidates.size():
			var candidate: Dictionary = candidates[i]
			var score: int = int(candidate["score"])
			if not selected.is_empty():
				var first: Dictionary = selected[0]
				if candidate["member"] == first["member"] \
						and int(candidate["dir"]) == int(first["dir"]):
					score += 220000
			if score < best_score:
				best_score = score
				best_idx = i
		selected.append(candidates.pop_at(best_idx))
	for candidate in selected:
		var p: Vector3 = candidate["position"]
		var dir: int = int(candidate["dir"])
		var pivot = scene.furnishing_pivot(p, scene.wall_facing(dir),
			"office_air_conditioner", false)
		var unit = scene.attributed_prop_local(pivot,
			Chunk.OFFICE_AIR_CONDITIONER_PATH,
			-Chunk.OFFICE_AIR_CONDITIONER_CENTRE * Chunk.OFFICE_AIR_CONDITIONER_SCALE,
			0.0, Vector3.ONE * Chunk.OFFICE_AIR_CONDITIONER_SCALE)
		if unit == null:
			pivot.get_parent().remove_child(pivot)
			pivot.free()
			continue
		pivot.set_meta("attributed_furnishing", "office_air_conditioner")
		pivot.set_meta("office_ac_mount", true)
		pivot.set_meta("office_ac_member", candidate["member"])
		pivot.set_meta("office_ac_dir", dir)
		pivot.set_meta("office_ac_slot", int(candidate["slot"]))
		pivot.set_meta("office_ac_along", float(candidate["along"]))
		pivot.set_meta("office_ac_expected", selected.size())
		pivot.set_meta("office_ac_suspended", false)
		unit.set_meta("authored_model", "office_air_conditioner")


## A continuous corporate corridor with real plan depth.  Locked doors seal
## inaccessible office/service volumes behind the side walls; genuine graph
## connections open into return-walled vestibules that reach the canonical
## cell-edge doorway.  Nothing ends short of a boundary or shifts between
## adjacent corridor cells, so the player can never walk around a facade.


func _office_corridor() -> void:
	var cdir = WorldGen.corridor(ctx.world_seed, ctx.cell)
	var along_x = cdir != 2
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var lane_half = 1.85
	# A quieter carpet-tile lane makes the circulation spine readable and masks
	# the floor seam where vestibules branch toward actual rooms.
	var lane = scene.model_box(null, scene.world_point(o, Vector3(0, 0.012, 0), yw),
		Vector3(WorldGen.CELL_SIZE, 0.024, lane_half * 2.0 - 0.18), Mats.office_lane_carpet())
	lane.rotation.y = yw

	var side_data = []
	for si in 2:
		var side = -lane_half if si == 0 else lane_half
		var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info = scene.edge_info(ctx.cell, sdir)
		var bay = []
		if not info["wall"]:
			# Edge t runs in world +x/+z. Local corridor x points toward -z after
			# the quarter-turn used by a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw = clampf(float(info["w"]) + 0.38, 1.95, 3.15)
			bay = [bt, bw]
		var doors = _office_corridor_doors(si, bay)
		_office_corridor_wall_side(o, yw, side, doors, bay)
		_office_corridor_utilities(o, yw, side, si, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	if ctx.random01(254) < 0.5:
		_office_dept_sign(along_x)
	# A wall directory or clock gives the lane a destination and is placed only
	# on structure that is not claimed by a locked door or a real vestibule.
	if ctx.random01(260) < 0.62:
		var dsi = 0 if ctx.random01(261) < 0.5 else 1
		var dt = _office_corridor_clear_t(dsi, side_data[dsi]["doors"],
			side_data[dsi]["bay"])
		if dt < 90.0:
			_office_corridor_directory(o, yw, float(side_data[dsi]["side"]), dt)
	# Period CCTV hardware makes the sealed office frontage feel monitored and
	# inhabited. It is wall-mounted above head height, so it cannot compromise
	# the corridor or a vestibule arrival.
	if ctx.random01(262) < 0.42:
		var csi = 0 if ctx.random01(263) < 0.5 else 1
		var cside = float(side_data[csi]["side"])
		var ct = -4.55 if ctx.random01(264) < 0.5 else 4.55
		var cp = scene.world_point(o, Vector3(ct, 2.45, cside), yw)
		scene.security_camera(cp, yw + PI if cside > 0.0 else yw)
	# a wet floor sign guarding nothing, halfway down the lane
	if ctx.random01(256) < 0.16:
		var t2 = 2.5 + 7.0 * ctx.random01(258)
		var sp2 = scene.world_point(o, Vector3(t2 - 6.0, 0, (ctx.random01(257) - 0.5) * 0.7), yw)
		scene.cc0_prop("WetFloorSign_01", sp2, ctx.random01(259) * TAU)
		scene.collider_box(sp2 + Vector3(0, 0.3, 0), Vector3(0.35, 0.6, 0.35))


## Locked private offices on one side of a corridor. A real vestibule owns
## its whole wall interval and suppresses any facade that would overlap it.


func _office_corridor_doors(si: int, bay: Array) -> Array:
	var doors = []
	for di in 3:
		var t = -3.55 + 3.55 * float(di)
		if ctx.random01(270 + si * 5 + di) >= 0.68:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.92:
			continue
		doors.append(t)
	# Long stretches with no real connection still need at least one piece of
	# evidence that the inaccessible strip is occupied office volume.
	if doors.is_empty() and bay.is_empty():
		doors.append([-3.55, 0.0, 3.55][int(ctx.random01(279 + si) * 2.99)])
	return doors


func _office_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	return corridor_clear_at(t, doors, bay, clearance, 0.66)


func _office_corridor_clear_t(si: int, doors: Array, bay: Array) -> float:
	var candidates = [-1.75, 1.75, -4.65, 4.65]
	if si == 1:
		candidates = [1.75, -1.75, 4.65, -4.65]
	for t in candidates:
		if _office_corridor_clear(float(t), doors, bay, 0.62):
			return float(t)
	return 99.0


## Services belong on the corridor shell the player can actually see, not on
## the canonical cell boundary hidden behind the inaccessible office strip.
## A receptacle occupies a clear wall run; a switch sits beside a sealed door
## or real vestibule, just as it would in a maintained office building.


func _office_corridor_utilities(o: Vector3, yw: float, side: float, si: int,
		doors: Array, bay: Array) -> void:
	var face = side - signf(side) * 0.078
	var facing = yw + (PI if side > 0.0 else 0.0)
	var base = 1480 + si * 23
	if ctx.random01(base) < 0.82:
		var outlet_t = _office_corridor_clear_t(si, doors, bay)
		if outlet_t < 90.0:
			scene.wall_utility_mount(
				scene.world_point(o, Vector3(outlet_t, 0.31, face), yw),
				facing, 0.31, false)
	if ctx.random01(base + 1) >= 0.88:
		return
	var opening_t = 99.0
	var opening_half = 0.0
	if not doors.is_empty():
		opening_t = float(doors[0])
		opening_half = 0.63
	elif not bay.is_empty():
		opening_t = float(bay[0])
		opening_half = float(bay[1]) * 0.5
	if opening_t > 90.0:
		return
	var switch_t = opening_t + opening_half + 0.25
	if switch_t > 5.72:
		switch_t = opening_t - opening_half - 0.25
	if switch_t < -5.72 \
			or not _office_corridor_clear(switch_t, doors, bay, 0.08):
		return
	scene.wall_utility_mount(
		scene.world_point(o, Vector3(switch_t, 1.12, face), yw),
		facing, 1.12, true)


## One complete side wall, cut only by a sealed door or by a real vestibule.


func _office_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs = [[-6.0, 6.0]]
	for dt in doors:
		segs = scene.cut_segments(segs, float(dt) - 0.63, float(dt) + 0.63)
	if not bay.is_empty():
		segs = scene.cut_segments(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_office_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt = float(doors[di])
		_office_corridor_header(o, yw, side, dt, 1.26)
		_office_corridor_door(o, yw, dt, side,
			285 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_office_corridor_header(o, yw, side, bt, bw)
		_office_corridor_open_casing(o, yw, side, bt, bw)
		_office_corridor_bay_returns(o, yw, side, bt, bw)


func _office_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln = b - a
	if ln < 0.04:
		return
	var c = (a + b) * 0.5
	var wc = scene.world_point(o, Vector3(c, ctx.ceiling_height * 0.5, side), yw)
	var wall = scene.model_box(null, wc, Vector3(ln, ctx.ceiling_height, 0.15),
		Mats.office_wall_variant(scene.finish_variant()))
	wall.rotation.y = yw
	scene.collider_yaw_box(wc, Vector3(ln, ctx.ceiling_height, 0.15), yw)


func _office_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh = ctx.ceiling_height - Chunk.DOOR_TOP
	if hh <= 0.02:
		return
	var hp = scene.world_point(o, Vector3(t, Chunk.DOOR_TOP + hh * 0.5, side), yw)
	var head = scene.model_box(null, hp, Vector3(width, hh, 0.15),
		Mats.office_wall_variant(scene.finish_variant()))
	head.rotation.y = yw
	scene.collider_yaw_box(hp, Vector3(width, hh, 0.15), yw)


## Return walls connect the corridor shell to the actual cell-edge doorway and
## close the inaccessible strips on both sides of the vestibule.


func _office_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer = signf(side) * (WorldGen.CELL_SIZE * 0.5 - Chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = scene.world_point(o, Vector3(edge, ctx.ceiling_height * 0.5, dc), yw)
		var ret = scene.model_box(null, wp, Vector3(0.15, ctx.ceiling_height, depth),
			Mats.office_wall_variant(scene.finish_variant()))
		ret.rotation.y = yw
		scene.collider_yaw_box(wp, Vector3(0.15, ctx.ceiling_height, depth), yw)
	var carpet = scene.model_box(null, scene.world_point(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.office_lane_carpet())
	carpet.rotation.y = yw


func _office_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn = side - signf(side) * 0.105
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = scene.model_box(null, scene.world_point(o, Vector3(edge, Chunk.DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, Chunk.DOOR_TOP, 0.24), Mats.paint_white())
		jamb.rotation.y = yw
	var head = scene.model_box(null, scene.world_point(o, Vector3(t, Chunk.DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.24), Mats.paint_white())
	head.rotation.y = yw


## A sealed office door installed in a real wall opening. The collider and
## opaque privacy glass make the facade honest even though the room is not
## generated; deep jambs make the wall thickness visible at grazing angles.


func _office_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn = side - signf(side) * 0.105
	var v = Node3D.new()
	v.position = scene.world_point(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	scene.add_node(v)
	var service = ctx.random01(salt) < 0.24
	var door_mat: Material = Mats.metal_gray() if service else Mats.wood_door()
	scene.model_rounded_box(v, Vector3(0, 1.09, 0), Vector3(1.04, 2.18, 0.07), door_mat, 0.012)
	scene.model_box(v, Vector3(-0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	scene.model_box(v, Vector3(0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	scene.model_box(v, Vector3(0, 2.25, 0), Vector3(1.26, 0.12, 0.25), Mats.paint_white())
	if not service and ctx.random01(salt + 1) < 0.62:
		# Milky vision panel with a slim aluminium bead.
		scene.model_rounded_box(v, Vector3(0, 1.58, 0.041), Vector3(0.43, 0.5, 0.014),
			Mats.office_privacy_glass(), 0.01)
		for sx in [-0.235, 0.235]:
			scene.model_box(v, Vector3(sx, 1.58, 0.052), Vector3(0.025, 0.55, 0.018), Mats.chrome())
		for sy in [1.295, 1.865]:
			scene.model_box(v, Vector3(0, sy, 0.052), Vector3(0.495, 0.025, 0.018), Mats.chrome())
	# Lever, latch plate, and a dead access-control reader.
	scene.model_rounded_box(v, Vector3(0.36, 1.02, 0.06), Vector3(0.13, 0.2, 0.025), Mats.chrome(), 0.008)
	scene.model_sphere(v, Vector3(0.36, 1.02, 0.092), 0.035, Mats.chrome())
	scene.model_rounded_box(v, Vector3(0.24, 1.02, 0.1), Vector3(0.25, 0.035, 0.035), Mats.chrome(), 0.012)
	scene.model_rounded_box(v, Vector3(0.72, 1.28, 0.07), Vector3(0.12, 0.2, 0.035), Mats.charcoal(), 0.008)
	scene.model_box(v, Vector3(0.72, 1.34, 0.091), Vector3(0.055, 0.025, 0.008), Mats.lamp_red())
	scene.collider_yaw_box(scene.world_point(o, Vector3(t, 1.09, inn), yw),
		Vector3(1.06, 2.18, 0.11), yw)
	var plate = scene.model_rounded_box(v, Vector3(-0.78, 1.58, 0.075),
		Vector3(0.34, 0.24, 0.025), Mats.paint_white(), 0.006)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb = Label3D.new()
	lb.text = "ELECTRICAL" if service else Chunk.OFFICE_CORRIDOR_LABELS[
		WorldGen.h(ctx.world_seed, ctx.cell.x + int(t * 5.0), ctx.cell.y, salt + 2) % Chunk.OFFICE_CORRIDOR_LABELS.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00125
	lb.width = 245.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.modulate = Color(0.06, 0.18, 0.12)
	lb.position = Vector3(-0.78, 1.58, 0.09)
	v.add_child(lb)


func _office_corridor_directory(o: Vector3, yw: float, side: float, t: float) -> void:
	var inn = side - signf(side) * 0.095
	var v = Node3D.new()
	v.position = scene.world_point(o, Vector3(t, 1.55, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	scene.add_node(v)
	scene.model_rounded_box(v, Vector3(0, 0, 0), Vector3(0.76, 0.88, 0.045), Mats.charcoal(), 0.008)
	scene.model_quad(v, Vector3(0, 0, 0.026), Vector2(0.69, 0.81), Mats.paint_white())
	var title = Label3D.new()
	title.text = "DIRECTORY"
	title.font_size = 50
	title.pixel_size = 0.0016
	title.modulate = Color(0.055, 0.19, 0.12)
	title.position = Vector3(0, 0.25, 0.035)
	v.add_child(title)
	var body_label = Label3D.new()
	body_label.text = "PROCESSING  4E\nARCHIVES      4F\nWELLNESS      4G\nSTAIRS        <--"
	body_label.font_size = 30
	body_label.pixel_size = 0.00145
	body_label.modulate = Color(0.12, 0.2, 0.16)
	body_label.position = Vector3(0, -0.09, 0.035)
	v.add_child(body_label)


## MDR-style desk cluster: cross divider, four desks facing outward, each
## with a CRT terminal, keyboard and chair. The room's reason to exist.


func _office_cubicles() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var span = scene.room_span()
	var centres = [c]
	if span.x > 12.1 and span.y > 12.1:
		centres = [c + Vector3(-5.4, 0, -5.4), c + Vector3(5.4, 0, -5.4),
			c + Vector3(-5.4, 0, 5.4), c + Vector3(5.4, 0, 5.4)]
	elif span.x > 12.1:
		centres = [c + Vector3(-5.6, 0, 0), c + Vector3(5.6, 0, 0)]
	elif span.y > 12.1:
		centres = [c + Vector3(0, 0, -5.6), c + Vector3(0, 0, 5.6)]
	for ci in centres.size():
		_office_cubicle_cluster(centres[ci], ci * 12)
	var snd = OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	scene.add_node(snd)


## One four-person work island. Large merged rooms arrange several of these
## from their true span rather than leaving three quarters of the floor empty.


func _office_cubicle_cluster(c: Vector3, qi_base: int) -> void:
	# cross divider
	scene.box(c + Vector3(0, 0.675, 0), Vector3(3.6, 1.35, 0.08), Mats.divider_gray())
	scene.box(c + Vector3(0, 0.675, 0), Vector3(0.08, 1.35, 3.6), Mats.divider_gray())
	# white cap rails
	scene.box(c + Vector3(0, 1.36, 0), Vector3(3.7, 0.04, 0.12), Mats.paint_white(), false)
	scene.box(c + Vector3(0, 1.36, 0), Vector3(0.12, 0.04, 3.7), Mats.paint_white(), false)
	var qi = 0
	for q in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		_office_desk(c + Vector3(q.x * 1.5, 0, 0), Vector2(0, q.y), qi_base + qi)
		qi += 1
	# waste bin
	var bin_side = -1.0 if int(qi_base / 12) % 2 == 1 else 1.0
	scene.cylinder(c + Vector3(1.7 * bin_side, 0.18, 1.7), 0.14, 0.36, Mats.charcoal())


func _office_desk(c: Vector3, d: Vector2, qi = 0) -> void:
	# One top-level pivot makes doorway clearance atomic: the desk, terminal,
	# keyboard and loose items are culled together or survive together.
	var workstation = Node3D.new()
	workstation.set_meta("office_workstation", true)
	scene.add_node(workstation)
	var dv = Vector3(d.x, 0, d.y)
	var deskc = c + dv * 1.05
	var top_size = Vector3(0.8, 0.035, 1.5) if d.x != 0.0 else Vector3(1.5, 0.035, 0.8)
	scene.model_rounded_box(workstation, deskc + Vector3(0, 0.73, 0), top_size, Mats.desk_white(), 0.012)
	# side panel legs
	var leg_off = Vector3(0, 0, 0.68) if d.x != 0.0 else Vector3(0.68, 0, 0)
	var leg_size = Vector3(0.74, 0.71, 0.04) if d.x != 0.0 else Vector3(0.04, 0.71, 0.74)
	scene.model_rounded_box(workstation, deskc + leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008)
	scene.model_rounded_box(workstation, deskc - leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008)
	scene.collider_box(deskc + Vector3(0, 0.4, 0), top_size * Vector3(1.0, 1.0, 1.0) + Vector3(0, 0.77, 0))
	# Terminal at the inner edge, screen facing the worker (outward). Every
	# office desk uses the authored IBM 3278/VT100-style unit. It arrives as one
	# complete, non-interactive display-and-keyboard assembly, replacing the old
	# generated E-query terminal and its separate keyboard.
	var yaw = atan2(dv.x, dv.z)
	scene.office_ibm_terminal(workstation, deskc, yaw, qi)
	# Real paper and stationery silhouettes replace the old anonymous white
	# slabs on selected desks, while leaving room for the terminal and keyboard.
	var clutter = ctx.random01(59 + qi)
	# The authored terminal is much wider than the old generated CRT. Keep
	# loose stationery beyond its housing instead of letting pencils emerge
	# through the side, while retaining enough desk-edge clearance.
	var side_dir = Vector3(cos(yaw), 0, -sin(yaw))
	var desk_item: Node3D
	if clutter < 0.22:
		desk_item = scene.cc0_prop("clipboard",
			deskc + side_dir * 0.54 + Vector3(0, 0.75, 0),
			ctx.random01(62 + qi) * TAU, 0.82)
	elif clutter < 0.48:
		desk_item = scene.cc0_prop("office_notepads",
			deskc + side_dir * 0.55 + Vector3(0, 0.752, 0),
			yaw + (ctx.random01(63 + qi) - 0.5) * 0.14, 0.42)
	elif clutter < 0.62:
		desk_item = scene.cc0_prop("stationery_supplies",
			deskc + side_dir * 0.52 + Vector3(0, 0.78, 0),
			yaw + PI / 2.0 + (ctx.random01(64 + qi) - 0.5) * 0.08, 0.28)
	if desk_item != null:
		scene.adopt_local(workstation, desk_item)
	# The phone sits on the opposite side of the terminal from the stationery,
	# so the two never share the same corner of the desk.
	_office_desk_phone(workstation, deskc, yaw, qi)
	# chair facing the desk, never perfectly parked
	scene.task_chair(c + dv * 1.95 + Vector3((ctx.random01(97 + qi) - 0.5) * 0.2, 0, 0),
		yaw + (ctx.random01(87 + qi) - 0.5) * 0.5)


## A desk phone at the worker's elbow.
##
## This is the only place the attributed office phone enters the game.


func _office_desk_phone(workstation: Node3D, deskc: Vector3, yaw: float,
		qi: int) -> void:
	if ctx.random01(1260 + qi) >= 0.38:
		return
	var side = Vector3(cos(yaw), 0, -sin(yaw)) * -0.52
	# The replacement keeps the former phone's compact footprint and sits at the
	# worker's elbow without changing workstation clearance.
	scene.attributed_floor_prop(Chunk.OFFICE_PHONE_PATH,
		deskc + side + Vector3(0, 0.7475, 0),
		yaw + (ctx.random01(1270 + qi) - 0.5) * 0.5,
		Chunk.OFFICE_PHONE_SCALE, Chunk.OFFICE_PHONE_CENTRE,
		"office_phone", workstation)


## The authored IBM 3278 set down on a desk top. Its screen faces model +X, so
## a quarter turn off the desk's own yaw points it at whoever sat there. The
## source scene left a `Lamp` node behind; it is dropped on the way in.


func _office_poster(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (Chunk.T / 2.0)
	var along = WorldGen.CELL_SIZE / 2.0 + (ctx.random01(63 + dir) - 0.5) * 5.0
	var v = Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.03, 1.7, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 1.7, inner + n * 0.03)
		v.rotation.y = 0.0 if n > 0.0 else PI
	v.rotation.z = (ctx.random01(64 + dir) - 0.5) * 0.04
	scene.add_node(v)
	scene.model_box(v, Vector3(0, 0, -0.008), Vector3(0.68, 0.94, 0.016), Mats.charcoal())
	scene.model_quad(v, Vector3(0, 0, 0.004), Vector2(0.62, 0.88), Mats.paint_white())
	var hd = Label3D.new()
	hd.text = Chunk.OFFICE_POSTERS[int(ctx.random01(65 + dir) * (float(Chunk.OFFICE_POSTERS.size()) - 0.01))]
	hd.font_size = 30
	hd.pixel_size = 0.0016
	hd.width = 380.0
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD
	hd.modulate = Color(0.1, 0.25, 0.16)
	hd.outline_size = 0
	hd.position = Vector3(0, 0.22, 0.01)
	v.add_child(hd)
	var bd = Label3D.new()
	bd.text = "a reminder from Facilities"
	bd.font_size = 16
	bd.pixel_size = 0.0014
	bd.modulate = Color(0.45, 0.48, 0.45)
	bd.outline_size = 0
	bd.position = Vector3(0, -0.3, 0.01)
	v.add_child(bd)


## White acrylic department sign hung over the corridor.


func _office_dept_sign(along_x: bool) -> void:
	var v = Node3D.new()
	v.position = Vector3(WorldGen.CELL_SIZE / 2.0, 2.55, WorldGen.CELL_SIZE / 2.0)
	v.rotation.y = PI / 2.0 if along_x else 0.0
	scene.add_node(v)
	var rod_h = ctx.ceiling_height - 2.55 - 0.19
	for sx in [-0.55, 0.55]:
		scene.model_cylinder(v, Vector3(sx, 0.19 + rod_h / 2.0, 0), 0.012, rod_h, Mats.metal_gray())
	scene.model_rounded_box(v, Vector3.ZERO, Vector3(1.6, 0.38, 0.05), Mats.paint_white(), 0.01)
	var zone = WorldGen.macro_zone(ctx.world_seed, ctx.cell, ctx.theme)
	var labels: Array = Chunk.OFFICE_ZONE_DEPTS[zone]
	for sside in [-1.0, 1.0]:
		var lb = Label3D.new()
		lb.text = labels[int(ctx.random01(255) * (float(labels.size()) - 0.01))]
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.08, 0.22, 0.14)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Authored multifunction office printer, shared by open and small offices.


func _copier(p: Vector3, salt: int) -> void:
	var yaw = (ctx.random01(salt) - 0.5) * 0.3
	var body0 = scene.collider_mark()
	var printer = scene.attributed_floor_prop(Chunk.OFFICE_PRINTER_PATH, p, yaw,
		Chunk.OFFICE_PRINTER_SCALE, Chunk.OFFICE_PRINTER_CENTRE, "office_printer")
	if printer == null:
		return
	scene.collider_yaw_box(p + Vector3(0, 0.676, 0),
		Vector3(1.21, 1.352, 0.70), yaw)
	scene.bind_furnishing_colliders(printer, body0)

func _office_storage() -> void:
	# The floor-standing copier, parked against a wall with its finisher trays
	# out. It is the one machine everyone walked to, so the storage room is
	# where it ends up when the floor is stripped.
	if ctx.random01(1250) < 0.62:
		for d in 4:
			if not scene.solid_wall(d):
				continue
			var pp = scene.wall_point(d, 9.1, 0.45)
			var pyaw = scene.wall_facing(d)
			if scene.attributed_floor_prop(Chunk.OFFICE_PRINTER_PATH, pp, pyaw,
					Chunk.OFFICE_PRINTER_SCALE, Chunk.OFFICE_PRINTER_CENTRE,
					"office_printer") != null:
				scene.collider_yaw_box(pp + Vector3(0, 0.68, 0),
					Vector3(1.22, 1.36, 0.72), pyaw)
			break
	scene.shelf_unit(Vector3(3.5, 0, 6.0), false, 30)
	if ctx.random01(33) < 0.55:
		# a real steel rack (model ships 10x life size — scaled to 2.1m)
		scene.cc0_prop("steel_frame_shelves_01", Vector3(8.5, 0, 6.0), PI / 2.0, 0.1)
		scene.collider_box(Vector3(8.5, 1.1, 6.0), Vector3(0.6, 2.2, 1.15))
	else:
		scene.shelf_unit(Vector3(8.5, 0, 6.0), false, 34)
	if ctx.random01(36) < 0.45:
		var dy = (ctx.random01(37) - 0.5) * 0.2
		scene.cc0_prop("drawer_cabinet", Vector3(2.2, 0, 1.1), dy)
		scene.collider_yaw_box(Vector3(2.2, 0.95, 1.1), Vector3(1.2, 1.9, 0.55), dy)
	if ctx.random01(38) < 0.4:
		scene.shelf_unit(Vector3(6.0, 0, 2.0), true, 39)


func _office_break() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	# round table with four chairs
	scene.cylinder(c + Vector3(0, 0.72, 0), 0.55, 0.05, Mats.desk_white(), false)
	scene.cylinder(c + Vector3(0, 0.36, 0), 0.06, 0.72, Mats.metal_gray(), false)
	scene.cylinder(c + Vector3(0, 0.02, 0), 0.3, 0.04, Mats.metal_gray(), false)
	scene.collider_cylinder(c + Vector3(0, 0.4, 0), 0.6, 0.8)
	for i in 4:
		var ang = TAU * float(i) / 4.0 + 0.4
		var cp = c + Vector3(cos(ang) * 1.15, 0, sin(ang) * 1.15)
		scene.task_chair(cp, ang + PI / 2.0 + (ctx.random01(98 + i) - 0.5) * 0.7)
	# counter along the south wall with a coffee maker
	scene.rounded_box(Vector3(4.5, 0.45, 0.75), Vector3(3.0, 0.9, 0.6), Mats.desk_white(), 0.015)
	scene.rounded_box(Vector3(3.6, 1.08, 0.75), Vector3(0.3, 0.36, 0.3), Mats.charcoal(), 0.02, false)
	scene.box(Vector3(3.6, 1.02, 0.92), Vector3(0.05, 0.02, 0.04), Mats.lamp_red(), false)
	# water cooler in the corner
	var wc = Vector3(10.5, 0, 1.0)
	var wc_body0 = scene.collider_mark()
	var cooler = scene.attributed_floor_prop(Chunk.OFFICE_WATER_COOLER_PATH, wc, PI,
		Chunk.OFFICE_WATER_COOLER_SCALE, Chunk.OFFICE_WATER_COOLER_CENTRE,
		"office_water_cooler")
	if cooler != null:
		scene.collider_box(wc + Vector3(0, 0.69, 0), Vector3(0.34, 1.38, 0.36))
		scene.bind_furnishing_colliders(cooler, wc_body0)
	# the catering cart that never gets restocked
	if ctx.random01(103) < 0.5:
		var cy2 = PI / 2.0 + (ctx.random01(104) - 0.5) * 0.3
		scene.cc0_prop("CoffeeCart_01", Vector3(10.4, 0, 8.6), cy2)
		scene.collider_yaw_box(Vector3(10.4, 0.85, 8.6), Vector3(2.2, 1.7, 1.1), cy2)
	# a dead CRT television on a low table, facing the chairs
	if ctx.random01(106) < 0.4:
		var tvp = Vector3(1.6, 0, 9.8)
		scene.cc0_prop("coffee_table_round_01", tvp, 0.0)
		scene.collider_cylinder(tvp + Vector3(0, 0.25, 0), 0.66, 0.5)
		scene.cc0_prop("television_02", tvp + Vector3(0, 0.49, 0), PI * 0.78 + (ctx.random01(107) - 0.5) * 0.3)


## Landmark: a boardroom far larger than the company could have needed. The
## single long table and repeated empty chairs create a strong navigational
## silhouette; the live wall display makes it visible through several doors.


func _office_boardroom() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var ln = 11.5
	scene.rounded_box(c + Vector3(0, 0.75, 0), Vector3(ln, 0.10, 2.15), Mats.desk_white(), 0.045)
	for x in [-4.7, -1.6, 1.6, 4.7]:
		scene.rounded_box(c + Vector3(x, 0.38, 0), Vector3(0.18, 0.72, 1.65), Mats.metal_gray(), 0.025)
	scene.collider_box(c + Vector3(0, 0.48, 0), Vector3(ln, 0.96, 2.2))
	for side in [-1.0, 1.0]:
		for i in 8:
			var x = -4.9 + 1.4 * float(i)
			var cp = c + Vector3(x, 0, side * 1.75)
			scene.task_chair(cp, 0.0 if side < 0.0 else PI)
	# One chair sits conspicuously far from the head of the table.
	scene.task_chair(c + Vector3(7.0, 0, 0), -PI / 2.0 + 0.18)
	# Dark wall-sized presentation display with a stubborn status line.
	scene.box(c + Vector3(-8.9, 1.75, 0), Vector3(0.10, 2.3, 5.8), Mats.charcoal(), false)
	var screen = Label3D.new()
	screen.text = "QUARTER  48\nATTENDANCE  0"
	screen.font_size = 92
	screen.pixel_size = 0.0028
	screen.modulate = Color(0.42, 1.0, 0.66)
	screen.position = c + Vector3(-8.82, 1.78, 0)
	screen.rotation.y = PI / 2.0
	scene.add_node(screen)
	# Real models break up the procedural table geometry at the room edges.
	scene.cc0_prop("drawer_cabinet", c + Vector3(8.8, 0, -7.7), -PI / 2.0)
	scene.collider_yaw_box(c + Vector3(8.8, 0.95, -7.7), Vector3(1.15, 1.9, 0.52), -PI / 2.0)
	for p in [c + Vector3(-8.5, 0, -8.0), c + Vector3(8.5, 0, 8.0)]:
		scene.cc0_prop("potted_plant_02", p, ctx.random01(118 + int(p.x)) * TAU)
		scene.collider_cylinder(p + Vector3(0, 0.42, 0), 0.34, 0.84)
	var snd = OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	scene.add_node(snd)


# --- the Annex ---------------------------------------------------------------

## Theme 2 is almost prop-free. Its identity comes from continuous carpet, a
## low drop ceiling and wall-like interruptions, plus one rare furniture hoard
## reserved for the largest rooms.
