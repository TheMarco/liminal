extends "res://scripts/levels/chunk_level_builder.gd"


func _sch_tiled_room() -> bool:
	return chunk.style == WorldGen.SCH_BATHROOM


func _sch_wall_mat() -> Material:
	if _sch_tiled_room():
		return Mats.sch_tile()
	return Mats.sch_wall_variant(chunk._finish_variant())


func _sch_floor_mat() -> Material:
	match chunk.style:
		WorldGen.SCH_GYM, WorldGen.SCH_AUDITORIUM:
			return Mats.sch_gymfloor()
		WorldGen.SCH_BATHROOM:
			return Mats.sch_tile()
		WorldGen.SCH_CAFETERIA, WorldGen.SCH_ADMIN:
			return Mats.sch_terrazzo()
	return Mats.sch_floor()


## Which way the corridor runs, as a unit vector in cell space.


func _sch_corridor_axis() -> int:
	return WorldGen.corridor(chunk.wseed, chunk.cell)


## Surface-mounted twin tube: a steel channel with a lens under it. Nothing
## here casts — the room light would rake the housings into streaks.


func _sch_strip(at: Vector3, along_x: bool, ln: float, pmat: Material) -> void:
	var y = chunk.ceil_h - 0.06
	var body_size = Vector3(ln, 0.09, 0.24) if along_x else Vector3(0.24, 0.09, ln)
	var housing = chunk._box(Vector3(at.x, y, at.z), body_size, Mats.sch_trim(), false)
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_size = Vector3(ln - 0.12, 0.03, 0.15) if along_x else Vector3(0.15, 0.03, ln - 0.12)
	var lens = chunk._box(Vector3(at.x, y - 0.06, at.z), lens_size, pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _sch_lighting() -> void:
	var is_spawn = chunk.cell == Vector2i.ZERO
	# A school is maintained — the asylum is the one that gets to be pitch
	# dark. A dead cell here left rooms with nothing but ambient, which on
	# this floor is not enough to see the far wall by.
	var dead = (not is_spawn) and chunk._r(8) < 0.02
	var flicker = (not is_spawn) and (not dead) and chunk._r(9) < 0.12
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.sch_panel().duplicate()
	else:
		pmat = Mats.sch_panel()
	var cdir = _sch_corridor_axis()
	if cdir != 0:
		# a single line of strips running the length of the passage, which is
		# what makes a school corridor read as endless
		var along_x = cdir == 1
		for t in [2.0, 6.0, 10.0]:
			var at = Vector3(t, 0, chunk.S / 2.0) if along_x else Vector3(chunk.S / 2.0, 0, t)
			_sch_strip(at, along_x, 2.6, pmat)
	elif chunk.style == WorldGen.SCH_GYM:
		for gx in [4.0, 12.0, 20.0]:
			for gz in [4.0, 12.0, 20.0]:
				_sch_strip(Vector3(gx, 0, gz), true, 3.2, pmat)
	else:
		for gx in [3.4, 8.6]:
			for gz in [3.0, 9.0]:
				_sch_strip(Vector3(gx, 0, gz), chunk._r(60) < 0.5, 2.4, pmat)
	if dead:
		return
	var tall = chunk.ceil_h > 4.5
	var light = chunk._make_main_light(flicker, pmat, 2.1 if tall else 1.5)
	light.light_color = Color(0.94, 0.97, 1.0)
	light.omni_range = 17.0 if tall else 12.0
	light.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.5, chunk.S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	chunk.add_child(light)


## The architectural contract for one side of a school hall. Coordinates are
## corridor-local: x follows the hall and z points toward its side rooms.


func _sch_corridor_side_data(si: int, along_x: bool) -> Dictionary:
	var side = -2.05 if si == 0 else 2.05
	var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info = WorldGen.edge_info(chunk.wseed, chunk.cell, sdir, chunk.theme)
	var bay = []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw = clampf(float(info["w"]) + 0.62, 2.25, 2.9)
		bay = [bt, bw]
	return {"side": side, "bay": bay, "doors": _sch_corridor_doors(si, bay)}


## Long enclosed stretches get evidence of classrooms behind them. A genuine
## connection owns its interval and suppresses any locked-door facade nearby.


func _sch_corridor_doors(si: int, bay: Array) -> Array:
	var doors = []
	var positions = [-3.25, 3.3] if si == 0 else [-3.55, 3.0]
	for di in positions.size():
		var t: float = positions[di] + (chunk._r(330 + si * 7 + di) - 0.5) * 0.24
		if chunk._r(334 + si * 7 + di) >= 0.72:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.95:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[int(chunk._r(348 + si) * 1.99)]))
	return doors


## A school corridor is about four metres across. The side strips are reserved
## classroom volume: continuous walls seal them, locked doors fill real cuts,
## and actual graph connections become cased, return-walled recesses.


func _sch_narrow() -> void:
	var along_x = _sch_corridor_axis() == 1
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	for si in 2:
		var data = _sch_corridor_side_data(si, along_x)
		_sch_corridor_wall_side(o, yw, float(data["side"]), data["doors"], data["bay"])


func _sch_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs = [[-6.0, 6.0]]
	for dt in doors:
		segs = chunk._cut_seg(segs, float(dt) - 0.62, float(dt) + 0.62)
	if not bay.is_empty():
		segs = chunk._cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_sch_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt = float(doors[di])
		_sch_corridor_header(o, yw, side, dt, 1.24)
		_sch_corridor_door(o, yw, dt, side,
			360 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_sch_corridor_header(o, yw, side, bt, bw)
		_sch_corridor_open_casing(o, yw, side, bt, bw)
		_sch_corridor_bay_returns(o, yw, side, bt, bw)
		_sch_corridor_bay_light(o, yw, side, bt)


func _sch_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln = b - a
	if ln < 0.04:
		return
	var c = (a + b) * 0.5
	var wc = chunk._wp(o, Vector3(c, chunk.ceil_h * 0.5, side), yw)
	var wall = chunk._mbox(chunk, wc, Vector3(ln, chunk.ceil_h, chunk.T),
		Mats.sch_wall_variant(chunk._finish_variant()))
	wall.rotation.y = yw
	chunk._collider_yaw_box(wc, Vector3(ln, chunk.ceil_h, chunk.T), yw)
	var inn = side - signf(side) * (chunk.T * 0.5 + 0.025)
	var band = chunk._mbox(chunk, chunk._wp(o, Vector3(c, chunk.SCH_BAND, inn), yw),
		Vector3(ln, 0.17, 0.04), Mats.sch_red())
	band.rotation.y = yw
	var base = chunk._mbox(chunk, chunk._wp(o, Vector3(c, 0.06, inn), yw),
		Vector3(ln, 0.12, 0.05), Mats.charcoal())
	base.rotation.y = yw


func _sch_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh = chunk.ceil_h - chunk.DOOR_TOP
	if hh <= 0.02:
		return
	var hp = chunk._wp(o, Vector3(t, chunk.DOOR_TOP + hh * 0.5, side), yw)
	var head = chunk._mbox(chunk, hp, Vector3(width, hh, chunk.T),
		Mats.sch_wall_variant(chunk._finish_variant()))
	head.rotation.y = yw
	chunk._collider_yaw_box(hp, Vector3(width, hh, chunk.T), yw)


func _sch_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn = side - signf(side) * (chunk.T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = chunk._mbox(chunk, chunk._wp(o, Vector3(edge, chunk.DOOR_TOP * 0.5, inn), yw),
			Vector3(0.17, chunk.DOOR_TOP, chunk.T + 0.14), Mats.sch_red())
		jamb.rotation.y = yw
	var lintel = chunk._mbox(chunk, chunk._wp(o, Vector3(t, chunk.DOOR_TOP + 0.08, inn), yw),
		Vector3(width + 0.17, 0.16, chunk.T + 0.14), Mats.sch_red())
	lintel.rotation.y = yw


## Close the dead classroom strips on both sides of a real connection and carry
## the red datum line and cove base all the way to its boundary doorway.


func _sch_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer = signf(side) * (chunk.S * 0.5 - chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = chunk._wp(o, Vector3(edge, chunk.ceil_h * 0.5, dc), yw)
		var ret = chunk._mbox(chunk, wp, Vector3(chunk.T, chunk.ceil_h, depth),
			Mats.sch_wall_variant(chunk._finish_variant()))
		ret.rotation.y = yw
		chunk._collider_yaw_box(wp, Vector3(chunk.T, chunk.ceil_h, depth), yw)
		var inward = chunk.T * 0.5 + 0.025 if edge < t else -(chunk.T * 0.5 + 0.025)
		var band = chunk._mbox(chunk, chunk._wp(o, Vector3(edge + inward, chunk.SCH_BAND, dc), yw),
			Vector3(0.04, 0.17, depth), Mats.sch_red())
		band.rotation.y = yw
		var base = chunk._mbox(chunk, chunk._wp(o, Vector3(edge + inward, 0.06, dc), yw),
			Vector3(0.05, 0.12, depth), Mats.charcoal())
		base.rotation.y = yw


func _sch_corridor_bay_light(o: Vector3, yw: float, side: float, t: float) -> void:
	var outer = signf(side) * (chunk.S * 0.5 - chunk.T)
	var dc = (outer + side) * 0.5
	var bl = OmniLight3D.new()
	bl.light_color = Color(0.94, 0.97, 1.0)
	bl.light_energy = 0.72
	bl.omni_range = 5.8
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	bl.position = chunk._wp(o, Vector3(t, chunk.ceil_h - 0.5, dc), yw)
	chunk.add_child(bl)


## A closed classroom door in a genuine opening: deep painted-steel jambs,
## opaque wired safety glass, a closer, lever and room plate. Its collider seals
## the reserved classroom volume behind it.


func _sch_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn = side - signf(side) * (chunk.T * 0.5 + 0.025)
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	const LEAF_HEIGHT := 2.23
	v.set_meta("school_swing_door", true)
	v.set_meta("school_door_leaf_top", LEAF_HEIGHT)
	v.set_meta("school_door_frame_top", chunk.DOOR_TOP)
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, LEAF_HEIGHT * 0.5, 0),
		Vector3(1.03, LEAF_HEIGHT, 0.075),
		Mats.sch_door(), 0.01)
	chunk._mbox(v, Vector3(-0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	chunk._mbox(v, Vector3(0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	chunk._mbox(v, Vector3(0, 2.24, 0), Vector3(1.27, 0.13, 0.26), Mats.sch_red())
	# Narrow safety-glass panel and its embedded wire grid.
	chunk._mrbox(v, Vector3(0, 1.55, 0.043), Vector3(0.3, 0.68, 0.018),
		Mats.sch_wired_glass(), 0.006)
	for wx in [-0.09, 0.0, 0.09]:
		chunk._mbox(v, Vector3(wx, 1.55, 0.055), Vector3(0.008, 0.64, 0.008), Mats.sch_trim())
	for wy in [1.37, 1.55, 1.73]:
		chunk._mbox(v, Vector3(0, wy, 0.056), Vector3(0.28, 0.008, 0.008), Mats.sch_trim())
	# Lever set and a surface closer with its articulated arm.
	chunk._mrbox(v, Vector3(0.35, 1.01, 0.055), Vector3(0.13, 0.2, 0.025),
		Mats.sch_trim(), 0.006)
	chunk._mbox(v, Vector3(0.24, 1.01, 0.08), Vector3(0.25, 0.035, 0.035), Mats.sch_trim())
	chunk._mrbox(v, Vector3(-0.27, 2.02, 0.05), Vector3(0.4, 0.1, 0.07),
		Mats.sch_trim(), 0.008)
	chunk._mbox(v, Vector3(0.03, 2.04, 0.084), Vector3(0.31, 0.025, 0.025), Mats.sch_trim())
	chunk._collider_yaw_box(
		chunk._wp(o, Vector3(t, LEAF_HEIGHT * 0.5, inn), yw),
		Vector3(1.05, LEAF_HEIGHT, 0.12), yw)
	var plate = chunk._mrbox(v, Vector3(0.79, 1.7, 0.045),
		Vector3(0.3, 0.22, 0.025), Mats.sch_white(), 0.005)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb = Label3D.new()
	var zone = WorldGen.macro_zone(chunk.wseed, chunk.cell, chunk.theme)
	var labels: Array = chunk.SCH_ZONE_ROOMS[zone]
	lb.text = labels[WorldGen.h(chunk.wseed, chunk.cell.x + int(t * 4.0), chunk.cell.y, salt) % labels.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00145
	lb.modulate = Color(0.16, 0.22, 0.24)
	lb.position = Vector3(0.79, 1.7, 0.061)
	v.add_child(lb)


func _sch_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	return corridor_clear_at(t, doors, bay, clearance, 0.63)


func _sch_corridor_prop_t(si: int, salt: int, doors: Array, bay: Array,
		clearance: float) -> float:
	var raw = -3.8 + 7.6 * chunk._r(salt)
	var candidates = [raw, -4.65, 4.65, -1.7, 1.7]
	if si == 1:
		candidates = [raw, 4.65, -4.65, 1.7, -1.7]
	for t in candidates:
		if _sch_corridor_clear(float(t), doors, bay, clearance):
			return float(t)
	return 99.0


## Locker banks use the exact same cuts as the architecture, so they finish at
## jambs rather than covering doors or jutting into a real classroom recess.


func _sch_passage_lockers(salt: int) -> void:
	var along_x = _sch_corridor_axis() == 1
	var depth = 0.42
	var hgt = 1.83
	for si in 2:
		var data = _sch_corridor_side_data(si, along_x)
		var side: float = data["side"]
		var doors: Array = data["doors"]
		var bay: Array = data["bay"]
		var segs = [[-5.6, 5.6]]
		for dt in doors:
			segs = chunk._cut_seg(segs, float(dt) - 0.86, float(dt) + 0.86)
		if not bay.is_empty():
			segs = chunk._cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5 - 0.28,
				float(bay[0]) + float(bay[1]) * 0.5 + 0.28)
		var mat: Material = Mats.sch_locker() if chunk._r(salt + si) < 0.68 \
			else Mats.sch_locker_blue()
		var lo_local = side - signf(side) * (chunk.T * 0.5 + depth * 0.5)
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 1.0:
				continue
			if along_x:
				_sch_locker_run(true, chunk.S * 0.5 + lo_local, a + chunk.S * 0.5,
					b + chunk.S * 0.5, -signf(side), mat, depth, hgt, salt + si * 19)
			else:
				_sch_locker_run(false, chunk.S * 0.5 + lo_local, chunk.S * 0.5 - b,
					chunk.S * 0.5 - a, -signf(side), mat, depth, hgt, salt + si * 19)


## The bank itself: carcass, kick plinth, and two tiers of doors with vents
## and latches. One collider for the whole run, not forty.


func _sch_locker_run(along_x: bool, off: float, from: float, to: float,
		facing: float, mat: Material, depth: float, hgt: float, salt: int) -> void:
	if _sch_locker_run_authored(along_x, off, from, to, facing, depth):
		return
	_sch_locker_run_generated(along_x, off, from, to, facing, mat, depth,
		hgt, salt)


## The authored bank is 1.97m of doors, so a corridor length is tiled with as
## many whole banks as fit and the remainder split evenly at both ends rather
## than stretching one bank to length — a stretched locker reads immediately as
## the wrong door proportion. Runs shorter than one bank fall back to single
## columns, and anything shorter than that is left to the generated run.


func _sch_locker_run_authored(along_x: bool, off: float, from: float,
		to: float, facing: float, gen_depth: float) -> bool:
	var ln = to - from
	if ln < chunk.GYM_LOCKER_W or chunk._prop_scene(chunk.LOCKERS_PATH) == null:
		return false
	# `facing` is +1/-1 across the run's axis. The full locker bank's doors
	# face local +Z, while the short single-locker fallback was authored with
	# its doors on local -Z. Account for that source-axis mismatch here rather
	# than letting short runs show their featureless backs to the corridor.
	var yaw = 0.0
	if along_x:
		yaw = 0.0 if facing > 0.0 else PI
	else:
		yaw = PI / 2.0 if facing > 0.0 else -PI / 2.0
	var use_bank = ln >= chunk.LOCKERS_RUN_W
	if not use_bank:
		yaw += PI
	var unit_w = chunk.LOCKERS_RUN_W if use_bank else chunk.GYM_LOCKER_W
	var path = chunk.LOCKERS_PATH if use_bank else chunk.GYM_LOCKER_PATH
	var scl = chunk.LOCKERS_SCALE if use_bank else chunk.GYM_LOCKER_SCALE
	var centre = chunk.LOCKERS_CENTRE if use_bank else chunk.GYM_LOCKER_CENTRE
	var kind = "school_locker_bank" if use_bank else "school_locker_column"
	var cnt = int(ln / unit_w)
	var pad = (ln - float(cnt) * unit_w) * 0.5
	# `off` is the centre of the generated carcass, so the wall face it stood
	# against is half its depth behind. The authored bank is 0.48m deep rather
	# than 0.42m; align the backs, not the centres, or the run floats.
	var depth = 0.48
	var mid = off - facing * gen_depth * 0.5 + facing * depth * 0.5
	var placed = 0
	for i in cnt:
		var t = from + pad + unit_w * (float(i) + 0.5)
		var p = Vector3(t, 0, mid) if along_x else Vector3(mid, 0, t)
		var bank_b0 = chunk.body.get_child_count()
		var bank = chunk._attributed_floor_prop(path, p, yaw, scl, centre, kind,
			null, true)
		if bank == null:
			continue
		bank.set_meta("school_locker_faces_corridor", true)
		bank.set_meta("school_locker_source_front_axis",
			"+z" if use_bank else "-z")
		placed += 1
		var size = Vector3(unit_w, 1.85, depth) if along_x \
			else Vector3(depth, 1.85, unit_w)
		chunk._collider_box(p + Vector3(0, 0.925, 0), size)
		chunk._bind_furnishing_colliders(bank, bank_b0)
	return placed > 0


func _sch_locker_run_generated(along_x: bool, off: float, from: float,
		to: float, facing: float, mat: Material, depth: float, hgt: float,
		salt: int) -> void:
	var ln = to - from
	var plinth = 0.12
	var c = (from + to) * 0.5
	if along_x:
		chunk._box(Vector3(c, plinth + (hgt - plinth) / 2.0, off), Vector3(ln, hgt - plinth, depth), mat, false)
		chunk._box(Vector3(c, plinth / 2.0, off), Vector3(ln, plinth, depth - 0.06), Mats.charcoal(), false)
		chunk._collider_box(Vector3(c, hgt / 2.0, off), Vector3(ln, hgt, depth))
	else:
		chunk._box(Vector3(off, plinth + (hgt - plinth) / 2.0, c), Vector3(depth, hgt - plinth, ln), mat, false)
		chunk._box(Vector3(off, plinth / 2.0, c), Vector3(depth - 0.06, plinth, ln), Mats.charcoal(), false)
		chunk._collider_box(Vector3(off, hgt / 2.0, c), Vector3(depth, hgt, ln))
	var dw = 0.305
	var cnt = int(ln / dw)
	if cnt < 1:
		return
	var pad = (ln - float(cnt) * dw) * 0.5
	var face = off + facing * (depth * 0.5 + 0.012)
	for i in cnt:
		var t = from + pad + dw * (float(i) + 0.5)
		for tier in 2:
			var y = plinth + 0.44 + 0.85 * float(tier)
			var open = WorldGen.r01(chunk.wseed, chunk.cell.x * 61 + i, chunk.cell.y * 13 + tier, salt + 3) < 0.05
			var dm: Material = Mats.charcoal() if open else mat
			var fs = Vector3(dw - 0.018, 0.82, 0.024) if along_x else Vector3(0.024, 0.82, dw - 0.018)
			var fp = Vector3(t, y, face) if along_x else Vector3(face, y, t)
			chunk._box(fp, fs, dm, false)
			if open:
				continue
			var vs = Vector3(dw * 0.5, 0.10, 0.012) if along_x else Vector3(0.012, 0.10, dw * 0.5)
			var vp = Vector3(t, y + 0.33, face + facing * 0.014) if along_x \
				else Vector3(face + facing * 0.014, y + 0.33, t)
			chunk._box(vp, vs, Mats.charcoal(), false)
			var hs = Vector3(0.035, 0.13, 0.03) if along_x else Vector3(0.03, 0.13, 0.035)
			var hp = Vector3(t + dw * 0.3, y - 0.26, face + facing * 0.02) if along_x \
				else Vector3(face + facing * 0.02, y - 0.26, t + dw * 0.3)
			chunk._box(hp, hs, Mats.sch_trim(), false)


func _sch_corridor() -> void:
	_sch_narrow()
	_sch_passage_lockers(300)
	var along_x = _sch_corridor_axis() == 1
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var side_data = [_sch_corridor_side_data(0, along_x),
		_sch_corridor_side_data(1, along_x)]
	if chunk._r(309) < 0.36:
		var cam_si = 0 if chunk._r(308) < 0.5 else 1
		var cam_side = float(side_data[cam_si]["side"])
		var cam_t = -4.55 if chunk._r(307) < 0.5 else 4.55
		chunk._security_camera(chunk._wp(o, Vector3(cam_t, 2.48, cam_side), yw),
			yw + PI if cam_side > 0.0 else yw)
	# a bin, and sometimes something knocked over and left
	var si = 1 if chunk._r(311) < 0.5 else 0
	var data: Dictionary = side_data[si]
	var t = _sch_corridor_prop_t(si, 310, data["doors"], data["bay"], 0.58)
	var side = -1.15 if si == 0 else 1.15
	var p = chunk._wp(o, Vector3(t, 0, side), yw)
	if chunk._r(312) < 0.62:
		if t < 90.0:
			_sch_bin(p)
	if chunk._r(313) < 0.35:
		var si2 = 1 if chunk._r(315) < 0.5 else 0
		var data2: Dictionary = side_data[si2]
		var t2 = _sch_corridor_prop_t(si2, 314, data2["doors"], data2["bay"], 0.92)
		if t2 < 90.0:
			var s2 = -1.1 if si2 == 0 else 1.1
			# The authored cart is 1.09m across, half again the generated one
			# it replaced, and the locker banks now stand 0.48m off these
			# walls. Walk it in from the wall until it genuinely fits, and
			# leave the corridor empty rather than park it inside a locker.
			var tp = chunk._wp(o, Vector3(t2, 0, s2), yw)
			for pull in 4:
				if chunk._floor_spot_clear(tp, 0.58):
					break
				s2 *= 0.6
				tp = chunk._wp(o, Vector3(t2, 0, s2), yw)
			if chunk._floor_spot_clear(tp, 0.58):
				_sch_trolley(tp, chunk._r(316) * TAU)
	if chunk._r(317) < 0.3:
		var si3 = 1 if chunk._r(319) < 0.5 else 0
		var data3: Dictionary = side_data[si3]
		var t3 = _sch_corridor_prop_t(si3, 318, data3["doors"], data3["bay"], 0.78)
		if t3 < 90.0:
			var s3 = -1.0 if si3 == 0 else 1.0
			_sch_stack_chairs(chunk._wp(o, Vector3(t3, 0, s3), yw), chunk._r(320) * TAU, 321)


## Wheeled steel bin, the kind parked by the doors and never emptied.


func _sch_bin(p: Vector3) -> void:
	chunk._waste_bin(p, chunk._r(int(p.x * 11.0 + p.z * 5.0) + 288) * TAU, "school_bin")


## Stacked plastic chairs, shoved against a wall at the end of term.


func _sch_stack_chairs(p: Vector3, yaw: float, salt: int) -> void:
	# Use the real school-chair model here: its shaped seat, welded frame and
	# back cut-out are most noticeable when several silhouettes overlap.
	var n = 3 + int(chunk._r(salt + 1) * 1.99)
	for i in n:
		var nested = Vector3(0, 0.065 * float(i), 0.035 * float(i)).rotated(Vector3.UP, yaw)
		chunk._load_model("SchoolChair_01", p + nested,
			yaw + (chunk._r(salt + 4 + i) - 0.5) * 0.035)
	chunk._collider_yaw_box(p + Vector3(0, 0.57, 0), Vector3(0.62, 1.14, 0.76), yaw)


## Janitor's trolley — mop bucket on castors, handle, a bag hanging off it.
## Janitor's cart. The authored model is the only noncommercial asset the
## school floor depends on, and this is its single entry point, so the
## dependency lifts out by deleting one branch.


func _sch_trolley(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var pivot = chunk._attributed_floor_prop(chunk.SCH_CLEANING_CART_PATH, p, yaw,
		chunk.SCH_CLEANING_CART_SCALE, chunk.SCH_CLEANING_CART_CENTRE,
		"school_janitor_trolley", null, true)
	if pivot != null:
		chunk._collider_yaw_box(p + Vector3(0, 0.42, 0),
			Vector3(1.05, 0.84, 0.80), yaw)
		chunk._bind_furnishing_colliders(pivot, b0)
		return
	_sch_trolley_generated(p, yaw)


func _sch_trolley_generated(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "school_janitor_trolley")
	var plastic = Mats.sch_cart_plastic()
	# Solid moulded bucket, rolled rim and a dark open well. The old body used
	# translucent water-jug plastic, exposing the wheels and wall behind it.
	var tub = chunk._mrbox(v, Vector3(0, 0.35, 0), Vector3(0.62, 0.50, 0.46),
		plastic, 0.07)
	tub.set_meta("school_cart_opaque_body", true)
	chunk._mrbox(v, Vector3(0, 0.61, 0), Vector3(0.68, 0.08, 0.52),
		plastic, 0.025)
	chunk._mrbox(v, Vector3(0, 0.655, -0.02), Vector3(0.52, 0.018, 0.36),
		Mats.charcoal(), 0.015)
	# Rear wringer tower and roller.
	chunk._mrbox(v, Vector3(0, 0.83, 0.18), Vector3(0.48, 0.36, 0.12),
		plastic, 0.025)
	var roller = chunk._mcyl(v, Vector3(0, 0.86, 0.115), 0.065, 0.40,
		Mats.rubber_black())
	roller.rotation.z = PI / 2.0
	# A complete push handle, rather than one unexplained vertical pole.
	for sx in [-0.24, 0.24]:
		chunk._mcyl(v, Vector3(sx, 1.02, 0.22), 0.018, 0.78, Mats.sch_trim())
	var grip = chunk._mcyl(v, Vector3(0, 1.40, 0.22), 0.035, 0.52,
		Mats.rubber_black())
	grip.rotation.z = PI / 2.0
	for sx in [-0.2, 0.2]:
		for sz in [-0.14, 0.14]:
			chunk._mcyl(v, Vector3(sx, 0.055, sz), 0.055, 0.05,
				Mats.rubber_black())
	chunk._collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.45), yaw)
	chunk._bind_furnishing_colliders(v, b0)


## Yaw that sits a student facing the given wall, so the class faces the board
## rather than the back of the room.
##
## The convention here is +Z, not the usual -Z forward: a chair's backrest is
## modelled at local -Z, so whoever is sitting in it looks along local +Z.
## That means (sin yaw, cos yaw) is the direction the class is facing, and
## everything else in the room is laid out from that vector.


func _sch_face_yaw(dir: int) -> float:
	match dir:
		0: return PI / 2.0        # faces +x
		1: return -PI / 2.0       # faces -x
		2: return 0.0             # faces +z
	return PI                     # faces -z


## A solid wall to hang the front of the room on, or -1 if the cell has none.


func _sch_front_wall(salt: int) -> int:
	return WorldGen.anchor_wall(chunk.wseed, chunk.cell, salt)


## Canonical student station: the authored model contains both desk and chair.
## Every classroom route uses this helper, including split classroom variants,
## so keeping the choice here singular prevents mixed furniture sets.


func _sch_desk(p: Vector3, yaw: float, _salt: int) -> void:
	var station = chunk._attributed_floor_prop(chunk.SCH_DESK_PATH, p,
		yaw + chunk.SCH_DESK_YAW_FIX, chunk.SCH_DESK_SCALE, chunk.SCH_DESK_CENTRE, "school_desk")
	if station == null:
		return
	station.set_meta("school_student_station", true)
	station.set_meta("school_student_facing_yaw", yaw)
	chunk._collider_yaw_box(p + Vector3(0, 0.42, 0),
		Vector3(0.80, 0.84, 0.96), yaw)


func _sch_desk_row(p: Vector3, yaw: float, n: int, salt: int) -> void:
	var rx = cos(yaw)
	var rz = -sin(yaw)
	for i in n:
		var d = (float(i) - float(n - 1) * 0.5) * chunk.SCH_DESK_COL_PITCH
		_sch_desk(p + Vector3(rx * d, 0, rz * d), yaw, salt + i * 5)


## The board, the tray of stubs under it, and the strip of pinned work above.


func _sch_chalkboard(dir: int) -> void:
	# A board is only valid on a genuinely solid classroom edge. In particular,
	# never invent one on the fallback facing used by an all-doorway classroom.
	var binfo = WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)
	if not binfo["wall"]:
		return
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var inner = plane + n * (chunk.T / 2.0)
	var ln = 4.2
	var y = 1.55
	var cen = chunk.S / 2.0
	# Board, frame, chalk, dust and pinned work are one furnishing pivot. If a
	# perpendicular doorway approach culls the board, all of its writing leaves
	# with it instead of surviving as text painted directly on the wall.
	var board_root = Node3D.new()
	board_root.set_meta("school_chalkboard", dir)
	chunk.add_child(board_root)
	var bm: Material = Mats.sch_board()
	var d0 = inner + n * 0.03
	if dir < 2:
		chunk._mbox(board_root, Vector3(d0, y, cen), Vector3(0.05, 1.25, ln), bm)
		chunk._mbox(board_root, Vector3(d0 + n * 0.02, y - 0.68, cen), Vector3(0.09, 0.05, ln), Mats.sch_trim())
		for edge in [-1.0, 1.0]:
			chunk._mbox(board_root, Vector3(d0, y, cen + edge * ln / 2.0),
				Vector3(0.07, 1.33, 0.06), Mats.sch_trim())
	else:
		chunk._mbox(board_root, Vector3(cen, y, d0), Vector3(ln, 1.25, 0.05), bm)
		chunk._mbox(board_root, Vector3(cen, y - 0.68, d0 + n * 0.02),
			Vector3(ln, 0.05, 0.09), Mats.sch_trim())
		for edge in [-1.0, 1.0]:
			chunk._mbox(board_root, Vector3(cen + edge * ln / 2.0, y, d0),
				Vector3(0.06, 1.33, 0.07), Mats.sch_trim())
	_sch_chalk(board_root, dir, cen, ln)
	# a row of work pinned above it, curling off the wall
	if chunk._r(71) < 0.7:
		for i in 5:
			var t = cen - 1.7 + 0.85 * float(i)
			var py = 2.48
			var ps = Vector3(0.01, 0.3, 0.22) if dir < 2 else Vector3(0.22, 0.3, 0.01)
			var pp = Vector3(inner + n * 0.02, py, t) if dir < 2 else Vector3(t, py, inner + n * 0.02)
			chunk._mbox(board_root, pp, ps, Mats.box_white())


func _sch_classroom() -> void:
	var fw = _sch_front_wall(72)
	var has_board_wall = fw >= 0
	if not has_board_wall:
		fw = 3
	else:
		_sch_chalkboard(fw)
	var yaw = _sch_face_yaw(fw)
	# the direction the class looks — toward the board
	var fx = sin(yaw)
	var fz = cos(yaw)
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# teacher's desk between the class and the board
	var td = c + Vector3(fx, 0, fz) * 3.5
	var teacher_b0 = chunk.body.get_child_count()
	var teacher = chunk._furnishing_pivot(td, yaw, "school_teacher_station")
	# A genuinely modelled steel teacher's desk replaces the old slab-and-leg
	# primitive. Its worn drawers and overhang make the front of the room read
	# as a specific abandoned workplace rather than another student table. The
	# desk, supplies and chair are one atomic furnishing: a doorway can remove
	# the station, but can never leave its cup and pens hovering behind.
	var teacher_desk = chunk._load_model("metal_office_desk", td, yaw)
	chunk._adopt_local(teacher, teacher_desk)
	chunk._collider_yaw_box(td + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.95), yaw)
	# The source pencils run along local X. Quarter-turn them across the desk,
	# and derive the root height from the measured model bottom so neither the
	# pencils nor their cup hover above the steel top.
	const DESK_TOP := 0.7875
	const STATIONERY_BOTTOM := -0.0737
	var stationery_jitter := (chunk._r(73) - 0.5) * 0.12
	var supplies = chunk._cc0_prop("stationery_supplies",
		chunk._wp(td, Vector3(
			-0.48, DESK_TOP - STATIONERY_BOTTOM, 0.05), yaw),
		yaw + PI / 2.0 + stationery_jitter)
	supplies.set_meta("school_teacher_stationery", true)
	supplies.set_meta("school_stationery_quarter_turn", PI / 2.0)
	supplies.set_meta("school_stationery_source_bottom", STATIONERY_BOTTOM)
	supplies.set_meta("school_stationery_desk_top", DESK_TOP)
	chunk._adopt_local(teacher, supplies)
	var teacher_chair = chunk._task_chair(
		td + Vector3(fx, 0, fz) * 1.0, yaw)
	chunk._adopt_local(teacher, teacher_chair)
	chunk._bind_furnishing_colliders(teacher, teacher_b0)
	# rows of desks, filling back from the front
	var rows = 4
	for row in rows:
		var back = 0.3 + chunk.SCH_DESK_ROW_PITCH * float(row)
		var origin = c + Vector3(fx, 0, fz) * (1.4 - back)
		_sch_desk_row(origin, yaw, 5, 80 + row * 20)
	if has_board_wall and chunk._r(74) < 0.5:
		_sch_screen(fw)
	# the stuff that accumulates down the side of every classroom
	# Keep the arrival classroom's perimeter bare. Its only real exit can land
	# on either side wall, and a tall cupboard in that bay made a valid spawn
	# feel like a sealed pocket even when the capsule itself was clear.
	if chunk.room_root != Vector2i.ZERO:
		var side = Vector3(fz, 0, -fx)      # perpendicular to the class's facing
		_sch_cupboard(c + side * 4.7 + Vector3(fx, 0, fz) * 1.2,
			yaw + PI / 2.0, 88)
		if chunk._r(89) < 0.7:
			_sch_stack(c - side * 4.9, yaw + PI / 2.0, 90)
		_sch_bin(c + Vector3(fx, 0, fz) * 3.0 + side * 3.4)


## Steel storage cupboard, the tall kind with the dented doors.


func _sch_cupboard(p: Vector3, yaw: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var hgt = 1.95
	chunk._mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.46), Mats.sch_trim())
	for sx in [-0.25, 0.25]:
		chunk._mbox(v, Vector3(sx, hgt / 2.0, 0.235), Vector3(0.47, hgt - 0.08, 0.02),
			Mats.metal_gray())
		chunk._mbox(v, Vector3(sx + 0.19, 1.0, 0.25), Vector3(0.05, 0.16, 0.02), Mats.charcoal())
	chunk._collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.5), yaw)
	if chunk._r(salt) < 0.5:
		for i in 3:
			chunk._mbox(v, Vector3(-0.3 + 0.3 * float(i), hgt + 0.09, 0),
				Vector3(0.26, 0.18, 0.3), Mats.box_white())


## Left up from a lesson that was interrupted, or that nobody sat. The hand
## is the same shaky marker the asylum walls are written in — a school board
## is chalk, so it is pale on green, and half rubbed out with the side of a
## fist.
func _sch_chalk(board_root: Node3D, dir: int, cen: float, ln: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var inner = plane + n * (chunk.T / 2.0)
	var lb = Label3D.new()
	lb.set_meta("school_chalk", true)
	lb.text = chunk.SCH_CHALK[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 77) % chunk.SCH_CHALK.size()]
	var hand = 0 if chunk._r(78) < 0.6 else 1
	lb.font = chunk._scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0030 * (1.0 + (chunk._r(79) - 0.5) * 0.3)
	lb.width = 1000.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	lb.modulate = Color(0.88, 0.90, 0.85, 0.72)   # chalk, and a dusty board
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y = 1.62
	var t = cen + (chunk._r(80) - 0.5) * (ln * 0.25)
	if dir < 2:
		lb.position = Vector3(inner + n * 0.06, y, t)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(t, y, inner + n * 0.06)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	lb.rotation.z = (chunk._r(81) - 0.5) * 0.05
	board_root.add_child(lb)
	# the ghost of the last lesson, wiped with the side of a hand
	for i in 3:
		var sy = 1.15 + 0.42 * float(i)
		var sw = lerpf(0.6, 1.5, chunk._r(82 + i))
		var st = cen + (chunk._r(85 + i) - 0.5) * (ln - sw)
		var ss = Vector3(0.008, 0.3, sw) if dir < 2 else Vector3(sw, 0.3, 0.008)
		var sp = Vector3(inner + n * 0.045, sy, st) if dir < 2 \
			else Vector3(st, sy, inner + n * 0.045)
		var sm = chunk._mbox(board_root, sp, ss, Mats.sch_chalkdust())
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Audit hook: chalk must be a descendant of a board pivot, and every board
## pivot must belong to a solid generated edge.


func _sch_screen(dir: int) -> void:
	# The working lift is a complete wall set piece. A classroom roller on that
	# same wall used to read as an unexplained grey square covering its doors.
	if WorldGen.elevator_cell(chunk.wseed, chunk.cell, chunk.theme):
		return
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var inner = plane + n * (chunk.T / 2.0)
	var drop = lerpf(0.3, 0.7, chunk._r(75))
	var y = chunk.ceil_h - 0.35 - drop / 2.0
	var t = chunk.S / 2.0 + (chunk._r(76) - 0.5) * 2.0
	# A compact, permanently wall-mounted roller screen. The imported portable
	# screen had asset-space poles several metres tall and could read as a
	# floating box with antennae. This assembly is attached to the same solid
	# wall as the classroom board and owns every one of its pieces.
	var screen = chunk._furnishing_pivot(Vector3.ZERO, 0.0,
		"school_projector_screen", false)
	screen.set_meta("school_projector_screen", dir)
	screen.set_meta("school_projector_screen_compact", true)
	if dir < 2:
		chunk._mrbox(screen, Vector3(inner + n * 0.09, chunk.ceil_h - 0.3, t),
			Vector3(0.11, 0.13, 1.95), Mats.sch_trim(), 0.025)
		chunk._mbox(screen, Vector3(inner + n * 0.09, y, t),
			Vector3(0.025, drop, 1.75), Mats.box_white())
		chunk._mbox(screen, Vector3(inner + n * 0.105, y - drop * 0.5 - 0.035, t),
			Vector3(0.045, 0.055, 1.82), Mats.sch_trim())
		for side in [-1.0, 1.0]:
			chunk._mbox(screen, Vector3(inner, chunk.ceil_h - 0.3, t + side * 0.86),
				Vector3(0.16, 0.22, 0.07), Mats.sch_trim())
	else:
		chunk._mrbox(screen, Vector3(t, chunk.ceil_h - 0.3, inner + n * 0.09),
			Vector3(1.95, 0.13, 0.11), Mats.sch_trim(), 0.025)
		chunk._mbox(screen, Vector3(t, y, inner + n * 0.09),
			Vector3(1.75, drop, 0.025), Mats.box_white())
		chunk._mbox(screen, Vector3(t, y - drop * 0.5 - 0.035, inner + n * 0.105),
			Vector3(1.82, 0.055, 0.045), Mats.sch_trim())
		for side in [-1.0, 1.0]:
			chunk._mbox(screen, Vector3(t + side * 0.86, chunk.ceil_h - 0.3, inner),
				Vector3(0.07, 0.22, 0.16), Mats.sch_trim())


## Folding table with the benches welded on — cafeteria, and nowhere else.


func _sch_caf_table(p: Vector3, yaw: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var ln = 2.9
	chunk._mbox(v, Vector3(0, 0.75, 0), Vector3(ln, 0.05, 0.76), Mats.sch_desk())
	for sz in [-0.72, 0.72]:
		chunk._mbox(v, Vector3(0, 0.45, sz), Vector3(ln, 0.04, 0.28), Mats.sch_desk())
		for sx in [-ln * 0.32, ln * 0.32]:
			chunk._mbox(v, Vector3(sx, 0.22, sz), Vector3(0.05, 0.44, 0.26), Mats.sch_trim())
	for sx in [-ln * 0.32, ln * 0.32]:
		chunk._mbox(v, Vector3(sx, 0.37, 0), Vector3(0.07, 0.74, 0.1), Mats.sch_trim())
		chunk._mbox(v, Vector3(sx, 0.06, 0), Vector3(0.09, 0.12, 1.5), Mats.sch_trim())
	chunk._collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(ln, 0.8, 1.6), yaw)
	if chunk._r(salt) < 0.4:
		chunk._mbox(v, Vector3((chunk._r(salt + 1) - 0.5) * 1.8, 0.785, (chunk._r(salt + 2) - 0.5) * 0.4),
			Vector3(0.35, 0.03, 0.26), Mats.sch_chair(0.08))


func _sch_cafeteria() -> void:
	var span = chunk._room_span()
	var big = span.x > 20.0 or span.y > 20.0
	var along_x = span.x >= span.y
	var yaw = 0.0 if along_x else PI / 2.0
	var cols = 3 if big else 2
	var rows = 3 if big else 2
	var pitch = 3.4
	for r in rows:
		for cc in cols:
			var u = (float(cc) - float(cols - 1) * 0.5) * pitch
			var w = (float(r) - float(rows - 1) * 0.5) * (pitch * 0.85)
			var p = Vector3(chunk.S / 2.0 + u, 0, chunk.S / 2.0 + w)
			_sch_caf_table(p, yaw, 400 + r * 30 + cc * 7)
	# the serving line against whichever wall is solid
	var sw = _sch_front_wall(410)
	if sw >= 0:
		_sch_servery(sw)


## Stainless serving counter with a sneeze guard and empty wells.


func _sch_servery(dir: int) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var inner = plane + n * (chunk.T / 2.0)
	var ln = 5.0
	var d = inner + n * 0.5
	var c = chunk.S / 2.0
	if dir < 2:
		chunk._box(Vector3(d, 0.45, c), Vector3(0.9, 0.9, ln), Mats.sch_trim())
		chunk._box(Vector3(d, 0.93, c), Vector3(1.0, 0.06, ln + 0.1), Mats.steel(), false)
		chunk._box(Vector3(d - n * 0.1, 1.55, c), Vector3(0.03, 0.5, ln), Mats.glass(), false)
		for i in 3:
			chunk._box(Vector3(d, 0.97, c - 1.5 + 1.5 * float(i)), Vector3(0.55, 0.05, 0.9),
				Mats.charcoal(), false)
	else:
		chunk._box(Vector3(c, 0.45, d), Vector3(ln, 0.9, 0.9), Mats.sch_trim())
		chunk._box(Vector3(c, 0.93, d), Vector3(ln + 0.1, 0.06, 1.0), Mats.steel(), false)
		chunk._box(Vector3(c, 1.55, d - n * 0.1), Vector3(ln, 0.5, 0.03), Mats.glass(), false)
		for i in 3:
			chunk._box(Vector3(c - 1.5 + 1.5 * float(i), 0.97, d), Vector3(0.9, 0.05, 0.55),
				Mats.charcoal(), false)


func _sch_bathroom() -> void:
	var sw = _sch_front_wall(500)
	if sw < 0:
		sw = 3
	# stalls along the front wall, sinks on the one to its left, and a run of
	# urinals facing the stalls across the room
	_sch_stalls(sw)
	_sch_sinks((sw + 2) % 4)
	_sch_urinals((sw + 1) % 4)


## A run of cubicles: partitions, doors ajar, gap at the floor.


func _sch_stalls(dir: int) -> void:
	var yaw = chunk._yaw_for(dir)
	var depth = 1.58
	var pm = Mats.sch_chair(0.35)
	var cnt = 3
	var w = 1.18
	var start = chunk.S / 2.0 - float(cnt) * w * 0.5
	for i in cnt:
		var t = start + w * (float(i) + 0.5)
		var stall_pos = chunk._wall_pt(dir, t, 0.02)
		var b0 = chunk.body.get_child_count()
		var stall = chunk._furnishing_pivot(stall_pos, yaw,
			"school_bathroom_stall")
		stall.set_meta("school_stall_complete", true)
		# Full-depth side partitions with a realistic floor gap.
		for sx in [-w * 0.5, w * 0.5]:
			chunk._mbox(stall, Vector3(sx, 1.15, -depth * 0.5),
				Vector3(0.055, 1.78, depth), pm)
			chunk._collider_yaw_box(chunk._wp(stall_pos,
				Vector3(sx, 1.15, -depth * 0.5), yaw),
				Vector3(0.06, 1.82, depth), yaw)
			chunk._mbox(stall, Vector3(sx, 1.02, -depth),
				Vector3(0.075, 2.04, 0.075), Mats.sch_trim())
		chunk._mbox(stall, Vector3(0, 2.02, -depth),
			Vector3(w, 0.09, 0.08), Mats.sch_trim())
		# One restrained door angle per cubicle. The old panels used their long
		# axis as the hinge offset and fanned through one another.
		var extent = 1.0 if i % 2 == 0 else -1.0
		var angle = lerpf(0.10, 0.62,
			WorldGen.r01(chunk.wseed, chunk.cell.x + i, chunk.cell.y, 505))
		var door_w = w - 0.14
		var door = Node3D.new()
		door.position = Vector3(-extent * w * 0.5 + extent * 0.055,
			0, -depth)
		door.rotation.y = extent * angle
		door.set_meta("school_stall_door", true)
		stall.add_child(door)
		chunk._mbox(door, Vector3(extent * door_w * 0.5, 1.10, 0),
			Vector3(door_w, 1.66, 0.055), pm)
		chunk._mcyl(door, Vector3(extent * (door_w - 0.12), 1.10, -0.05),
			0.025, 0.05, Mats.sch_trim()).rotation.x = PI / 2.0
		var door_local = door.position + Vector3(extent * door_w * 0.5,
			1.10, 0).rotated(Vector3.UP, door.rotation.y)
		chunk._collider_yaw_box(chunk._wp(stall_pos, door_local, yaw),
			Vector3(door_w, 1.66, 0.06), yaw + door.rotation.y)
		# Authored porcelain. The stall runs from the wall at local z=0 out to
		# its door at -depth, so the pan turns to put its cistern against the
		# wall and its bowl toward the door. Six primitives used to fake it.
		var pan = chunk._attributed_floor_prop(chunk.SCH_TOILET_PATH,
			Vector3(0, 0, -0.30), PI, chunk.SCH_TOILET_SCALE, chunk.SCH_TOILET_CENTRE,
			"school_stall_toilet", stall)
		if pan != null:
			pan.set_meta("school_stall_toilet", true)
		else:
			chunk._mrbox(stall, Vector3(0, 0.26, -0.43),
				Vector3(0.38, 0.52, 0.48), Mats.sch_white(), 0.10)
			chunk._mellipsoid(stall, Vector3(0, 0.48, -0.62),
				Vector3(0.54, 0.22, 0.68), Mats.sch_white())
			var seat = MeshInstance3D.new()
			seat.mesh = chunk.TOR
			seat.material_override = Mats.sch_trim()
			seat.position = Vector3(0, 0.57, -0.64)
			seat.scale = Vector3(0.27, 0.045, 0.34)
			seat.set_meta("school_stall_toilet", true)
			stall.add_child(seat)
			chunk._mrbox(stall, Vector3(0, 0.78, -0.16),
				Vector3(0.48, 0.58, 0.24), Mats.sch_white(), 0.045)
			chunk._mbox(stall, Vector3(0, 1.085, -0.16),
				Vector3(0.50, 0.045, 0.27), Mats.sch_white())
		chunk._collider_yaw_box(chunk._wp(stall_pos, Vector3(0, 0.37, -0.30), yaw),
			Vector3(0.52, 0.74, 0.64), yaw)
		chunk._bind_furnishing_colliders(stall, b0)


## Sinks under a long mirror, one tap dripping somewhere in the building.


func _sch_sinks(dir: int) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var inner = plane + n * (chunk.T / 2.0)
	var facing = chunk._wall_facing(dir)
	var cnt = 3
	var w = 0.92
	var start = chunk.S / 2.0 - float(cnt) * w * 0.5
	var d = inner + n * 0.22
	# mirror band
	var mp = Vector3(inner + n * 0.02, 1.72, chunk.S / 2.0) if dir < 2 \
		else Vector3(chunk.S / 2.0, 1.72, inner + n * 0.02)
	chunk._box(mp, Vector3(0.02, 0.9, float(cnt) * w) if dir < 2 else Vector3(float(cnt) * w, 0.9, 0.02),
		Mats.gold_mirror(), false)
	for i in cnt:
		var t = start + w * (float(i) + 0.5)
		# The authored basin is a pedestal unit with its own tap and trap, so
		# it takes a wall point directly rather than a box and a chrome stub.
		var sp = Vector3(inner + n * 0.30, 0, t) if dir < 2 \
			else Vector3(t, 0, inner + n * 0.30)
		var sink_b0 = chunk.body.get_child_count()
		var basin = chunk._attributed_floor_prop(chunk.SCH_SINK_PATH, sp, facing,
			chunk.SCH_SINK_SCALE, chunk.SCH_SINK_CENTRE, "school_sink", null, true)
		if basin != null:
			chunk._collider_yaw_box(sp + Vector3(0, 0.54, 0),
				Vector3(0.75, 1.07, 0.60), facing)
			chunk._bind_furnishing_colliders(basin, sink_b0)
			continue
		var bp = Vector3(d, 0.86, t) if dir < 2 else Vector3(t, 0.86, d)
		chunk._box(bp, Vector3(0.44, 0.16, 0.6) if dir < 2 else Vector3(0.6, 0.16, 0.44),
			Mats.sch_white(), true)
		var tp = Vector3(inner + n * 0.08, 1.06, t) if dir < 2 else Vector3(t, 1.06, inner + n * 0.08)
		chunk._cyl(tp, 0.02, 0.16, Mats.chrome(), false)


## A run of wall-hung urinals on the wall opposite the stalls. The generated
## bathroom never had any. This is the one authored fixture that must not be
## floor-corrected: it is modelled already hanging, its lowest point 0.60m up
## its own mounting plane, so only X and Z are recentred.


func _sch_urinals(dir: int) -> void:
	var facing = chunk._wall_facing(dir)
	# This source asset's visible front is local -X, not the +Z convention
	# used by the wall-placement helpers. A positive quarter-turn maps that
	# front to the requested wall-facing axis (90 degrees counter-clockwise).
	var urinal_yaw = facing + PI / 2.0
	var cnt = 3
	var w = 0.78
	const URINAL_DEPTH := 0.39
	const WALL_CLEARANCE := 0.015
	const MOUNT_STANDOFF := URINAL_DEPTH * 0.5 + WALL_CLEARANCE
	var start = chunk.S / 2.0 - float(cnt) * w * 0.5
	for i in cnt:
		var t = start + w * (float(i) + 0.5)
		# `_wall_pt(..., 0)` is already the finished room-side wall face.
		# Centre the bowl half its depth into the room so its porcelain back,
		# rather than its middle, meets that plane.
		var p = chunk._wall_pt(dir, t, MOUNT_STANDOFF)
		var b0 = chunk.body.get_child_count()
		var pivot = Node3D.new()
		pivot.position = p
		pivot.rotation.y = urinal_yaw
		# Wall-hung, so no `floor_supported`: the support audit would otherwise
		# want its lowest mesh on the floor, which is the one thing it is not.
		pivot.set_meta("atomic_furnishing", "school_urinal")
		chunk._furnishing_group_serial += 1
		pivot.set_meta("furnishing_group", chunk._furnishing_group_serial)
		chunk.add_child(pivot)
		var unit = chunk._attributed_prop_local(pivot, chunk.SCH_URINAL_PATH,
			Vector3(-chunk.SCH_URINAL_CENTRE.x, 0.0, -chunk.SCH_URINAL_CENTRE.z)
				* chunk.SCH_URINAL_SCALE, 0.0, Vector3.ONE * chunk.SCH_URINAL_SCALE)
		if unit == null:
			pivot.get_parent().remove_child(pivot)
			pivot.free()
			return
		pivot.set_meta("attributed_furnishing", "school_urinal")
		pivot.set_meta("school_urinal_quarter_turn", PI / 2.0)
		pivot.set_meta("school_urinal_wall_dir", dir)
		pivot.set_meta("school_urinal_mount_standoff", MOUNT_STANDOFF)
		pivot.set_meta("school_urinal_depth", URINAL_DEPTH)
		pivot.set_meta("school_urinal_wall_clearance", WALL_CLEARANCE)
		unit.set_meta("authored_model", "school_urinal")
		# The visual quarter-turn swaps the source model's X/Z footprint. Keep
		# collision in the corrected front-facing frame so no side-on invisible
		# slab remains in the bathroom.
		chunk._collider_yaw_box(p + Vector3(0, 1.04, 0),
			Vector3(0.40, 0.90, URINAL_DEPTH), facing)
		chunk._bind_furnishing_colliders(pivot, b0)


func _sch_gym() -> void:
	var span = chunk._room_span()
	var half = minf(span.x, span.y) * 0.5
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# painted court, laid on the boards
	var lm = Mats.sch_red()
	var cl = half - 1.6
	for sx in [-cl, cl]:
		chunk._box(c + Vector3(sx, 0.004, 0), Vector3(0.06, 0.008, cl * 2.0), lm, false)
	for sz in [-cl, cl]:
		chunk._box(c + Vector3(0, 0.004, sz), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	chunk._box(c + Vector3(0, 0.004, 0), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	chunk._cyl(c + Vector3(0, 0.004, 0), 1.8, 0.008, lm, false)
	chunk._cyl(c + Vector3(0, 0.006, 0), 1.66, 0.008, Mats.sch_gymfloor(), false)
	# a hoop at each end, and bleachers down one side
	for sgn in [-1.0, 1.0]:
		_sch_hoop(c + Vector3(0, 0, sgn * (half - 0.7)), 0.0 if sgn < 0.0 else PI)
	_sch_bleachers(c + Vector3(-(half - 1.3), 0, 0), PI / 2.0, minf(half * 1.5, 9.0))
	if chunk._r(600) < 0.6:
		_sch_bleachers(c + Vector3(half - 1.3, 0, 0), -PI / 2.0, minf(half * 1.5, 9.0))


## Landmark: the school auditorium. A real raised stage and two disciplined
## seating banks give the hall a remembered orientation, while one displaced
## modelled chair breaks the procedural rhythm near the centre aisle.


func _sch_auditorium() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var stage = c + Vector3(0, 0, -8.2)
	chunk._rbox(stage + Vector3(0, 0.32, 0), Vector3(15.5, 0.64, 3.5), Mats.sch_desk(), 0.025)
	chunk._collider_box(stage + Vector3(0, 0.34, 0), Vector3(15.6, 0.68, 3.6))
	# Heavy red curtains, closed except for an uneasy centre gap.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var x = side * (1.0 + 1.15 * float(i))
			chunk._box(stage + Vector3(x, 3.1, -1.58), Vector3(0.72, 5.3, 0.10),
				Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	# Lectern and a microphone left facing the empty seats.
	chunk._rbox(stage + Vector3(-2.0, 1.05, 0.35), Vector3(1.1, 1.45, 0.65), Mats.darkwood(), 0.035)
	var stem = chunk._cyl(stage + Vector3(1.6, 1.35, 0.35), 0.025, 1.9, Mats.charcoal(), false)
	stem.rotation.z = -0.12
	chunk._sphere(stage + Vector3(1.72, 2.28, 0.35), 0.06, Mats.charcoal())
	# Six rows, split by the centre aisle, using the same authored blue plastic
	# chair as classrooms instead of simplified procedural seat blocks.
	for row in 6:
		var z = -4.6 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var row_c = c + Vector3(side * 4.2, 0, z)
			for col in 5:
				var x = (float(col) - 2.0) * 1.25
				var p = row_c + Vector3(x, 0, 0)
				var chair_yaw = PI + \
					(chunk._r(1200 + row * 10 + col) - 0.5) * 0.05
				chunk._load_model("SchoolChair_01", p, chair_yaw)
			chunk._collider_box(row_c + Vector3(0, 0.58, 0), Vector3(6.0, 1.16, 0.78))
	var loose = c + Vector3(0.25, 0, 5.8)
	chunk._load_model("SchoolChair_01", loose, PI + 0.48)
	chunk._collider_yaw_box(loose + Vector3(0, 0.5, 0), Vector3(0.58, 1.02, 0.7), PI + 0.48)
	# Structural openings add their own housed EXIT cabinets. Decorative raw
	# words on this back wall looked like floating navigation markers and could
	# imply doors that do not exist, so the auditorium adds none of its own.


## Backboard, ring, and the folded arms holding it off the wall.


func _sch_hoop(p: Vector3, yaw: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 3.05, 0), Vector3(1.8, 1.05, 0.05), Mats.sch_white())
	chunk._mbox(v, Vector3(0, 2.86, 0), Vector3(0.59, 0.45, 0.02), Mats.sch_red())
	chunk._mbox(v, Vector3(0, 2.62, 0.22), Vector3(0.45, 0.03, 0.45), Mats.sch_red())
	for sx in [-0.5, 0.5]:
		chunk._mbox(v, Vector3(sx, 3.5, -0.5), Vector3(0.06, 0.06, 1.1), Mats.sch_trim())
	chunk._mbox(v, Vector3(0, 3.05, -0.55), Vector3(0.08, 0.08, 1.1), Mats.sch_trim())
	# net, as a ring of short hanging strands
	for i in 8:
		var a = TAU * float(i) / 8.0
		chunk._mcyl(v, Vector3(sin(a) * 0.2, 2.46, 0.22 + cos(a) * 0.2), 0.008, 0.3, Mats.box_white())


## Retractable bleachers, pulled out and left out.


func _sch_bleachers(p: Vector3, yaw: float, ln: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var tiers = 4
	for i in tiers:
		var y = 0.42 + 0.42 * float(i)
		var z = -0.4 - 0.62 * float(i)
		chunk._mbox(v, Vector3(0, y, z), Vector3(ln, 0.06, 0.5), Mats.sch_desk())
		chunk._mbox(v, Vector3(0, y - 0.21, z - 0.28), Vector3(ln, 0.42, 0.06), Mats.sch_trim())
	chunk._collider_yaw_box(p + Vector3(-sin(yaw) * 1.5, 1.0, -cos(yaw) * 1.5),
		Vector3(ln, 2.0, 3.0), yaw)


func _sch_library() -> void:
	var span = chunk._room_span()
	# Run stacks parallel to the dominant doorway flow and distribute them
	# across that flow. The old layout varied their position along the same axis
	# as their length, overlapping the runs into one solid barricade.
	var x_doors = 0
	var z_doors = 0
	for member in chunk._room_members():
		for dir in 4:
			var edge = WorldGen.edge_info(chunk.wseed, member, dir, chunk.theme)
			if edge["wall"] or edge["full_open"]:
				continue
			if dir < 2:
				x_doors += 1
			else:
				z_doors += 1
	var along_x = x_doors >= z_doors if x_doors + z_doors > 0 else span.x >= span.y
	var large = maxf(span.x, span.y) > 20.0
	var runs = 3 if large else 2
	for i in runs:
		var pitch = 5.8 if large else 8.4
		var u = (float(i) - float(runs - 1) * 0.5) * pitch
		var p = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0 + u) if along_x \
			else Vector3(chunk.S / 2.0 + u, 0, chunk.S / 2.0)
		_sch_stack(p, 0.0 if along_x else PI / 2.0, 620 + i * 9)
	# The small-room table sits between the end approaches; large libraries have
	# enough interior depth to move it out into a separate reading bay.
	var tp = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	if large:
		tp += Vector3(0, 0, 7.8) if along_x else Vector3(7.8, 0, 0)
	_sch_caf_table(tp, 0.0 if along_x else PI / 2.0, 640)


## A double-sided run of shelving, most of it still full.


func _sch_stack(p: Vector3, yaw: float, salt: int) -> void:
	var body0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "school_library_stack")
	v.set_meta("school_library_stack", true)
	var ln = 4.4
	var hgt = 2.0
	var real_side = -0.17 if chunk._r(salt + 20) < 0.5 else 0.17
	var real_sh = 1 + int(chunk._r(salt + 21) * 2.99)
	var real_left = lerpf(-1.65, 0.95, chunk._r(salt + 22))
	chunk._mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.06), Mats.sch_desk())
	for sz in [-0.17, 0.17]:
		for sh in 4:
			var y = 0.42 + 0.46 * float(sh)
			chunk._mbox(v, Vector3(0, y, sz), Vector3(ln, 0.04, 0.34), Mats.sch_desk())
			# books, in blocks with gaps where a shelf has been raided
			var x = -ln * 0.5 + 0.2
			var k = 0
			while x < ln * 0.5 - 0.3:
				var bw = lerpf(0.25, 0.7, WorldGen.r01(chunk.wseed, chunk.cell.x + k, chunk.cell.y + sh, salt))
				if is_equal_approx(sz, real_side) and sh == real_sh \
						and x + bw > real_left - 0.03 and x < real_left + 0.62:
					x = real_left + 0.66
					k += 1
					continue
				if WorldGen.r01(chunk.wseed, chunk.cell.x + k * 3, chunk.cell.y + sh, salt + 1) < 0.28:
					x += bw
					k += 1
					continue
				var bh = lerpf(0.24, 0.34, WorldGen.r01(chunk.wseed, k, sh, salt + 2))
				var hue = WorldGen.r01(chunk.wseed, k * 7, sh, salt + 3)
				chunk._mbox(v, Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, sz), Vector3(bw, bh, 0.26),
					Mats.sch_chair(hue))
				x += bw + 0.03
				k += 1
	chunk._mbox(v, Vector3(0, hgt - 0.02, 0), Vector3(ln, 0.05, 0.42), Mats.sch_desk())
	var origin_x = real_left if real_side > 0.0 else real_left + 0.55
	var by = 0.42 + 0.46 * float(real_sh) + 0.025
	var books = chunk._cc0_prop_local(v, "book_encyclopedia_set_01",
		Vector3(origin_x, by, real_side), 0.0 if real_side > 0.0 else PI)
	books.set_meta("school_library_encyclopedia_set", true)
	chunk._collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.46), yaw)
	chunk._bind_furnishing_colliders(v, body0)


func _sch_lab() -> void:
	var span = chunk._room_span()
	var along_x = span.x >= span.y
	var yaw = 0.0 if along_x else PI / 2.0
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var table_positions: Array[Vector3] = [c]
	if maxf(span.x, span.y) > 18.0:
		var axis = Vector3.RIGHT if along_x else Vector3.FORWARD
		table_positions = [c - axis * 3.75, c + axis * 3.75]
	for ti in table_positions.size():
		var p: Vector3 = table_positions[ti]
		var salt = 700 + ti * 31
		if not _sch_chemistry_table(p, yaw, salt):
			continue
		# Tall lab stools line the two long working faces. Their assemblies and
		# colliders are atomic, so doorway clearance may remove an end stool
		# without leaving a floating seat or an invisible obstruction.
		for side in [-1.0, 1.0]:
			for si in 3:
				if chunk._r(salt + 10 + si + (8 if side > 0.0 else 0)) < 0.14:
					continue
				var local = Vector3((float(si) - 1.0) * 1.35, 0,
					side * 2.68)
				_sch_stool(chunk._wp(p, local, yaw),
					salt + 18 + si + (8 if side > 0.0 else 0))
	var fw = _sch_front_wall(710)
	if fw >= 0:
		_sch_chalkboard(fw)


## The authored island already includes its base cabinets, black worktop, sink,
## taps and plumbing. It replaces the former primitive bench completely rather
## than sitting on top of it. Individual glassware pieces use triangle-verified
## support slots on its L-shaped 0.862m work surface.


func _sch_chemistry_table(p: Vector3, yaw: float, salt: int) -> bool:
	var body0 = chunk.body.get_child_count()
	var table = chunk._furnishing_pivot(p, yaw, "school_chemistry_table")
	table.set_meta("attributed_furnishing", "school_chemistry_table")
	table.set_meta("chemistry_surface_y", 0.862)
	var inst = chunk._attributed_prop_local(table, chunk.SCH_CHEMISTRY_TABLE_PATH,
		-chunk.SCH_CHEMISTRY_TABLE_CENTRE * chunk.SCH_CHEMISTRY_TABLE_SCALE, 0.0,
		Vector3.ONE * chunk.SCH_CHEMISTRY_TABLE_SCALE)
	if inst == null:
		table.get_parent().remove_child(table)
		table.free()
		return false
	inst.set_meta("authored_model", "school_chemistry_table")
	var item_count = 3 + int(chunk._r(salt + 2) * 3.99)
	var first_slot = int(chunk._r(salt + 3) \
		* chunk.SCH_CHEMISTRY_COUNTER_POINTS.size())
	var stride = 3 if chunk._r(salt + 4) < 0.5 else 7
	for item in item_count:
		var slot = (first_slot + item * stride) \
			% chunk.SCH_CHEMISTRY_COUNTER_POINTS.size()
		var point: Vector3 = chunk.SCH_CHEMISTRY_COUNTER_POINTS[slot]
		point.x += (chunk._r(salt + 20 + item * 3) - 0.5) * 0.10
		point.z += (chunk._r(salt + 21 + item * 3) - 0.5) * 0.10
		var glass = chunk._chemistry_glassware(table, point,
			chunk._r(salt + 22 + item * 3) * TAU, salt + 50 + item * 11,
			false, "school_lab")
		if glass != null:
			glass.set_meta("school_counter_slot", slot)
	chunk._collider_yaw_box(p + Vector3(0, 0.44, 0),
		Vector3(4.46, 0.88, 3.86), yaw)
	chunk._bind_furnishing_colliders(table, body0)
	return true


func _sch_stool(p: Vector3, salt: int) -> void:
	var body0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p,
		WorldGen.r01(chunk.wseed, chunk.cell.x, chunk.cell.y, salt) * TAU, "school_lab_stool")
	chunk._mcyl(v, Vector3(0, 0.62, 0), 0.17, 0.05, Mats.sch_desk())
	for i in 4:
		var a = TAU * float(i) / 4.0 + PI / 4.0
		chunk._mcyl(v, Vector3(sin(a) * 0.13, 0.31, cos(a) * 0.13), 0.014, 0.62, Mats.sch_trim())
	chunk._mcyl(v, Vector3(0, 0.28, 0), 0.15, 0.02, Mats.sch_trim())
	chunk._collider_cyl(p + Vector3(0, 0.32, 0), 0.2, 0.64)
	chunk._bind_furnishing_colliders(v, body0)


func _sch_admin() -> void:
	# A working lift gets the whole room-side approach. The former reception
	# counter and rear desk were placed independently of the lift wall and
	# could stand directly in front of the doors.
	if WorldGen.elevator_cell(chunk.wseed, chunk.cell, chunk.theme):
		return
	var fw = _sch_front_wall(800)
	# the counter you wait at, across the room
	var yaw = _sch_face_yaw(fw if fw >= 0 else 3)
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var v = Node3D.new()
	v.set_meta("school_admin_counter", true)
	v.position = c
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 0.52, 0), Vector3(4.4, 1.04, 0.5), Mats.sch_desk())
	chunk._mbox(v, Vector3(0, 1.08, 0), Vector3(4.6, 0.07, 0.66), Mats.sch_desk())
	chunk._collider_yaw_box(c + Vector3(0, 0.55, 0), Vector3(4.4, 1.1, 0.55), yaw)
	var back = c - Vector3(sin(yaw), 0, cos(yaw)) * 2.4
	chunk._small_desk(back, yaw + PI)
	chunk._shelf_unit(back + Vector3(cos(yaw) * 2.2, 0, -sin(yaw) * 2.2), absf(cos(yaw)) > 0.5, 810)


# --- school: things on the walls ----------------------------------------------

## Cork board behind glass, layered with notices for terms already over.


func _sch_noticeboard(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(900 + dir) - 0.5) * 3.4
	var w = lerpf(1.5, 2.4, chunk._r(904 + dir))
	var y = 1.62
	var d0 = inner + n * 0.03
	var frame = Vector3(0.06, 1.25, w) if dir < 2 else Vector3(w, 1.25, 0.06)
	var fp = Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	chunk._box(fp, frame, Mats.sch_trim(), false)
	var cork = Vector3(0.02, 1.12, w - 0.1) if dir < 2 else Vector3(w - 0.1, 1.12, 0.02)
	var cp = Vector3(d0 + n * 0.03, y, along) if dir < 2 else Vector3(along, y, d0 + n * 0.03)
	chunk._box(cp, cork, Mats.sch_cork(), false)
	for i in 6:
		var px = along + (WorldGen.r01(chunk.wseed, chunk.cell.x + i, chunk.cell.y, 908 + dir) - 0.5) * (w - 0.35)
		var py = y + (WorldGen.r01(chunk.wseed, chunk.cell.x, chunk.cell.y + i, 912 + dir) - 0.5) * 0.85
		var ps = Vector3(0.008, 0.26, 0.19) if dir < 2 else Vector3(0.19, 0.26, 0.008)
		var pp = Vector3(d0 + n * 0.05, py, px) if dir < 2 else Vector3(px, py, d0 + n * 0.05)
		chunk._box(pp, ps, Mats.box_white(), false)


## Drinking fountain. Two of them, always, at the height of two different
## years of children.


func _sch_fountain(dir: int, plane: float) -> void:
	# A bathroom has its own plumbing and every wall already spoken for by
	# stalls, sinks or urinals. The old fountain was a 0.44m-deep pair of boxes
	# and could tuck in beside a stall run; the authored bubbler is 0.92m deep
	# and lands inside one.
	if chunk.style == WorldGen.SCH_BATHROOM:
		return
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(920 + dir) - 0.5) * 3.0
	var facing = chunk._wall_facing(dir)
	# One authored bubbler with its own bowl, bubbler head and back panel,
	# where the pair of stacked boxes used to stand in for two.
	var fp = Vector3(inner + n * 0.44, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.44)
	# Corridor walls carry locker banks, and a bubbler that deep will sit
	# inside one. Slide along the wall for a gap before giving the wall up.
	if not chunk._floor_spot_clear(fp, 0.46):
		var found = false
		for step in 6:
			var shift = (float(step) - 2.5) * 1.7
			var alt = fp + (Vector3(0, 0, shift) if dir < 2 \
				else Vector3(shift, 0, 0))
			if alt.x < 1.4 or alt.x > chunk.S - 1.4 or alt.z < 1.4 or alt.z > chunk.S - 1.4:
				continue
			if chunk._floor_spot_clear(alt, 0.46):
				fp = alt
				found = true
				break
		if not found:
			return
	var fount_b0 = chunk.body.get_child_count()
	var bubbler = chunk._attributed_floor_prop(chunk.SCH_FOUNTAIN_PATH, fp, facing,
		chunk.SCH_FOUNTAIN_SCALE, chunk.SCH_FOUNTAIN_CENTRE, "school_fountain", null, true)
	if bubbler != null:
		chunk._collider_yaw_box(fp + Vector3(0, 0.53, 0),
			Vector3(0.88, 1.05, 0.92), facing)
		chunk._bind_furnishing_colliders(bubbler, fount_b0)
		return
	for pair in 2:
		var t = along + (float(pair) - 0.5) * 0.72
		var y = 0.86 if pair == 0 else 0.72
		var d0 = inner + n * 0.19
		var bs = Vector3(0.38, 0.36, 0.44) if dir < 2 else Vector3(0.44, 0.36, 0.38)
		var bp = Vector3(d0, y, t) if dir < 2 else Vector3(t, y, d0)
		chunk._box(bp, bs, Mats.sch_white(), true)
		var ss = Vector3(0.34, 0.05, 0.4) if dir < 2 else Vector3(0.4, 0.05, 0.34)
		var sp = Vector3(d0, y + 0.19, t) if dir < 2 else Vector3(t, y + 0.19, d0)
		chunk._box(sp, ss, Mats.chrome(), false)


## The trophy case by the front doors, still lit, still full.


func _sch_case(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(930 + dir) - 0.5) * 2.6
	var w = 2.2
	var y = 1.5
	var depth = 0.34
	var d0 = inner + n * depth * 0.5
	var box = Vector3(depth, 1.9, w) if dir < 2 else Vector3(w, 1.9, depth)
	var bp = Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	chunk._box(bp, box, Mats.sch_trim(), true)
	var gs = Vector3(0.02, 1.7, w - 0.14) if dir < 2 else Vector3(w - 0.14, 1.7, 0.02)
	var gp = Vector3(inner + n * (depth + 0.01), y, along) if dir < 2 \
		else Vector3(along, y, inner + n * (depth + 0.01))
	chunk._box(gp, gs, Mats.glass(), false)
	for sh in 3:
		var sy = 0.95 + 0.52 * float(sh)
		var ss = Vector3(depth - 0.08, 0.03, w - 0.16) if dir < 2 else Vector3(w - 0.16, 0.03, depth - 0.08)
		var sp = Vector3(d0, sy, along) if dir < 2 else Vector3(along, sy, d0)
		chunk._box(sp, ss, Mats.sch_desk(), false)
		for i in 4:
			var tx = along + (float(i) - 1.5) * 0.48
			var hgt = lerpf(0.16, 0.3, WorldGen.r01(chunk.wseed, chunk.cell.x + i, chunk.cell.y + sh, 934))
			var tp = Vector3(d0, sy + 0.03 + hgt * 0.5, tx) if dir < 2 \
				else Vector3(tx, sy + 0.03 + hgt * 0.5, d0)
			chunk._cyl(tp, 0.05, hgt, Mats.brass(), false)
			var cp2 = tp + Vector3(0, hgt * 0.5, 0)
			chunk._sphere(cp2, 0.06, Mats.brass())


## A poster, curling at one corner: fire drill, periodic table, a motto.


func _sch_poster(dir: int, plane: float) -> void:
	const POSTER_MESSAGES := [
		"KEEP GOING. THE HALLWAY REMEMBERS.",
		"BE READY WHEN THE BELL RINGS.",
		"YOU ARE ALMOST WHERE YOU NEED TO BE.",
		"STAY CALM. STAY TOGETHER.",
		"DO YOUR BEST. DO NOT LOOK BACK.",
	]
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(940 + dir) - 0.5) * 4.0
	var y = lerpf(1.5, 2.0, chunk._r(944 + dir))
	var w = lerpf(0.55, 0.9, chunk._r(948 + dir))
	var h = w * 1.4
	var hue = chunk._r(952 + dir)
	var ps = Vector3(0.012, h, w) if dir < 2 else Vector3(w, h, 0.012)
	var pp = Vector3(inner + n * 0.02, y, along) if dir < 2 else Vector3(along, y, inner + n * 0.02)
	var mi = chunk._box(pp, ps, Mats.sch_chair(hue), false)
	mi.rotate_object_local(Vector3(1, 0, 0) if dir < 2 else Vector3(0, 0, 1),
		(chunk._r(956 + dir) - 0.5) * 0.06)
	var label := Label3D.new()
	label.text = POSTER_MESSAGES[int(chunk._r(960 + dir) * (float(POSTER_MESSAGES.size()) - 0.01))]
	label.font_size = 22
	label.pixel_size = 0.0012
	label.width = 300.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.08, 0.12, 0.12)
	label.outline_size = 0
	if dir < 2:
		label.position = Vector3(0.008, 0, 0)
		label.rotation.y = PI / 2.0
	else:
		label.position = Vector3(0, 0, 0.008)
	mi.add_child(label)
