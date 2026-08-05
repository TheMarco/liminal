extends "res://scripts/levels/chunk_level_builder.gd"


func _prison_lighting() -> void:
	# The friend of the dark is the reader of nothing: this floor was crushed
	# to black. Fewer dead fixtures, twice the energy, and a second fill light
	# in the big set-piece rooms — still the coldest floor, but readable.
	var dead = chunk.cell != Vector2i.ZERO and chunk._r(1800) < 0.08
	var flicker = not dead and chunk.cell != Vector2i.ZERO and chunk._r(1801) < 0.16
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.prison_panel()
	if flicker:
		lens = Mats.prison_panel().duplicate()
	var along_x = WorldGen.corridor(chunk.wseed, chunk.cell) != 2
	for t in [-3.6, 0.0, 3.6]:
		var p = Vector3(6 + t, 0, 6) if along_x else Vector3(6, 0, 6 + t)
		chunk._troffer(p, Vector2(1.25, 0.20) if along_x else Vector2(0.20, 1.25),
			lens, Mats.prison_iron())
	if dead:
		return
	var big = chunk.style == WorldGen.PRISON_CELLBLOCK or chunk.style == WorldGen.PRISON_ROTUNDA
	var light = chunk._make_main_light(flicker, lens, 2.1 if big else 1.8)
	light.light_color = Color(0.78, 0.87, 0.79)
	light.omni_range = 14.5
	light.position = Vector3(6, chunk.ceil_h - 0.55, 6)
	light.shadow_enabled = big
	light.distance_fade_enabled = true
	light.distance_fade_begin = 23.0
	light.distance_fade_length = 8.0
	chunk.add_child(light)
	if big and chunk.ceil_h > 5.0:
		# high fill washing the range so the tall volume does not eat the light
		var fill = OmniLight3D.new()
		fill.light_color = Color(0.72, 0.80, 0.74)
		fill.light_energy = 0.8
		fill.omni_range = 11.0
		fill.position = Vector3(6, chunk.ceil_h * 0.55, 6)
		fill.shadow_enabled = false
		fill.distance_fade_enabled = true
		fill.distance_fade_begin = 20.0
		fill.distance_fade_length = 8.0
		chunk.add_child(fill)


func _prison_number_wall(dir: int, plane: float) -> void:
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var inner = plane + n * (chunk.T * 0.5 + 0.025)
	var along = lerpf(3.0, 9.0, chunk._r(1810 + dir))
	var lab = Label3D.new()
	lab.text = "%s-%02d" % [char(65 + posmod(chunk.cell.x + chunk.cell.y, 6)),
		WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 1812 + dir) % 40 + 1]
	lab.font_size = 96
	lab.pixel_size = 0.0025
	lab.modulate = Color(0.20, 0.24, 0.20)
	lab.position = Vector3(inner, 1.75, along) if dir < 2 else Vector3(along, 1.75, inner)
	if dir == 0: lab.rotation.y = -PI / 2.0
	elif dir == 1: lab.rotation.y = PI / 2.0
	elif dir == 2: lab.rotation.y = PI
	chunk.add_child(lab)


## A sealed, non-interactive steel door on a genuinely solid prison wall. The
## source GLB contains two complete door arrangements several metres apart;
## retain only its coherent near-origin assembly so no duplicate geometry can
## materialise elsewhere in the room. The structural wall remains the collider,
## making the façade unmistakably locked without adding an invisible barrier.


func _prison_locked_door_wall(dir: int, plane: float) -> void:
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var inner = plane + n * (chunk.T * 0.5)
	var along = lerpf(3.1, 8.9, chunk._r(1816 + dir))
	var yaw = PI if dir == 0 else (0.0 if dir == 1 \
		else (PI / 2.0 if dir == 2 else -PI / 2.0))
	var pos = Vector3(inner + n * 0.035, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.035)
	var inst = chunk._attributed_prop_local(chunk, chunk.PRISON_DOOR_OLD_PATH, pos, yaw,
		Vector3.ONE * (2.16 / 2.78388))
	if inst == null:
		return
	var distant_variant = inst.find_child("Null_1", true, false)
	if distant_variant != null:
		var variant_parent = distant_variant.get_parent()
		variant_parent.remove_child(distant_variant)
		distant_variant.free()
	inst.set_meta("wall_mounted_prison_door", true)
	inst.set_meta("locked_facade", true)


func _prison_bars(origin: Vector3, yaw: float, width: float, height: float,
		with_gate = true, solid = true) -> void:
	var v = Node3D.new()
	v.position = origin
	v.rotation.y = yaw
	chunk.add_child(v)
	var gate_half = 0.55 if with_gate else 0.0
	for i in range(int(width / 0.25) + 1):
		var x = -width * 0.5 + float(i) * 0.25
		if with_gate and absf(x) < gate_half:
			continue
		chunk._mcyl(v, Vector3(x, height * 0.5, 0), 0.025, height, Mats.prison_iron())
	for y in [0.18, height - 0.18]:
		chunk._mbox(v, Vector3(0, y, 0), Vector3(width, 0.08, 0.08), Mats.prison_iron())
	if with_gate:
		for x in [-gate_half, gate_half]:
			chunk._mbox(v, Vector3(x, height * 0.5, 0), Vector3(0.08, height, 0.08),
				Mats.prison_iron())
		chunk._mbox(v, Vector3(0, height - 0.18, 0), Vector3(gate_half * 2.0, 0.08, 0.08),
			Mats.prison_iron())
	if solid:
		if with_gate:
			var side_w = width * 0.5 - gate_half
			for side in [-1.0, 1.0]:
				var local_x = float(side) * (gate_half + side_w * 0.5)
				var cp = origin + Vector3(cos(yaw), 0, -sin(yaw)) * local_x
				chunk._collider_yaw_box(cp + Vector3(0, height * 0.5, 0),
					Vector3(side_w, height, 0.12), yaw)
		else:
			chunk._collider_yaw_box(origin + Vector3(0, height * 0.5, 0),
				Vector3(width, height, 0.12), yaw)


func _prison_bunk(p: Vector3, yaw: float, cell_context = false) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "prison_bunk")
	v.set_meta("enrichment_prop", "double_bunk")
	v.set_meta("prison_cell_context", cell_context)
	# The CC BY replacement's long axis is X. Turn it into the cell's local Z,
	# scale its two-metre authored length to 1.76m and lift its lowest foot onto
	# the floor. This replaces the former noncommercial prison-specific model.
	var model_scale = 0.88
	var authored = chunk._attributed_prop_local(v, chunk.PRISON_BUNK_PATH,
		Vector3(0, 0.834936 * model_scale, 0), PI / 2.0,
		Vector3.ONE * model_scale)
	if authored == null:
		# Import failure is intentionally obvious but still structurally safe:
		# retain a compact welded silhouette rather than leaving floating cell
		# effects where the bunk should have supported the composition.
		for x in [-0.48, 0.48]:
			for z in [-0.96, 0.96]:
				chunk._mcyl(v, Vector3(x, 0.76, z), 0.035, 1.52,
					Mats.prison_iron())
		for level in [0.34, 1.18]:
			chunk._mrbox(v, Vector3(0, level, 0),
				Vector3(0.96, 0.12, 1.92), Mats.asy_cloth(), 0.025)
	else:
		authored.set_meta("prison_cell_model", "bunk_bed")
	chunk._collider_yaw_box(chunk._wp(p, Vector3(0, 0.735, 0), yaw),
		Vector3(1.34, 1.47, 1.80), yaw)
	chunk._bind_furnishing_colliders(v, b0)


func _prison_toilet(p: Vector3, yaw: float, cell_context = false) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "prison_toilet_combo")
	v.set_meta("enrichment_prop", "detention_toilet_sink")
	v.set_meta("prison_cell_context", cell_context)
	# The authored bowl is floor-aligned and faces local +Z; turn it toward the
	# cell interior (-Z) and keep its baked grime, seat, tank and plumbing
	# together. The small steel basin behind it is generated as a separate,
	# wall-supported detention fixture, never as part of the bowl itself.
	var authored = chunk._attributed_prop_local(v, chunk.PRISON_TOILET_PATH,
		Vector3.ZERO, PI, Vector3.ONE * 0.96)
	if authored != null:
		authored.set_meta("prison_cell_model", "toilet")
	else:
		chunk._mrbox(v, Vector3(0, 0.30, -0.25), Vector3(0.48, 0.60, 0.58),
			Mats.steel(), 0.10)
	# Compact vandal-resistant wall basin and backsplash.
	chunk._mrbox(v, Vector3(0, 0.96, 0.18), Vector3(0.54, 0.54, 0.13),
		Mats.steel(), 0.035)
	chunk._mellipsoid(v, Vector3(0, 0.91, 0.02), Vector3(0.27, 0.09, 0.20),
		Mats.steel())
	var basin = chunk._mcyl(v, Vector3(0, 0.965, -0.005), 0.16, 0.014,
		Mats.charcoal())
	basin.scale.z *= 0.70
	for bx in [-0.12, 0.12]:
		var button = chunk._mcyl(v, Vector3(bx, 1.12, 0.105), 0.030, 0.025,
			Mats.prison_green())
		button.rotation.x = PI / 2.0
	chunk._mbox(v, Vector3(0, 1.12, 0.01), Vector3(0.05, 0.13, 0.05),
		Mats.chrome())
	chunk._mbox(v, Vector3(0, 1.065, -0.035), Vector3(0.05, 0.05, 0.11),
		Mats.chrome())
	chunk._mrbox(v, Vector3(-0.39, 0.72, 0.18), Vector3(0.18, 0.20, 0.12),
		Mats.prison_iron(), 0.018)
	chunk._collider_yaw_box(chunk._wp(p, Vector3(0, 0.60, -0.10), yaw),
		Vector3(0.62, 1.20, 0.96), yaw)
	chunk._bind_furnishing_colliders(v, b0)


## Cell-only context audit. Bunks and detention toilet/sink units are allowed
## only inside actual barred cell strips, never as generic room enrichment.


func _prison_corridor() -> void:
	var along_x = WorldGen.corridor(chunk.wseed, chunk.cell) != 2
	var yaw = 0.0 if along_x else PI / 2.0
	# shakedown table mid-gallery: the slab was floating with no legs and no
	# collider — a proper fixed steel table now
	var table_b0 = chunk.body.get_child_count()
	var table = chunk._furnishing_pivot(Vector3(6, 0, 6), 0.0, "prison_shakedown_table")
	chunk._mbox(table, Vector3(0, 1.02, 0), Vector3(1.1, 0.08, 1.1), Mats.prison_iron())
	for lx in [-0.42, 0.42]:
		for lz in [-0.42, 0.42]:
			chunk._mbox(table, Vector3(lx, 0.49, lz), Vector3(0.09, 0.98, 0.09),
				Mats.prison_iron())
	chunk._collider_box(Vector3(6, 0.55, 6), Vector3(1.1, 1.1, 1.1))
	chunk._bind_furnishing_colliders(table, table_b0)
	if chunk._r(1830) < 0.45:
		chunk._security_camera(Vector3(6, minf(2.85, chunk.ceil_h - 0.28), 6),
			chunk._r(1831) * TAU)
	if chunk._r(1832) < 0.42:
		var refuse_pos = Vector3(2.0, 0, 2.1) if along_x \
			else Vector3(9.9, 0, 2.0)
		chunk._cc0_floor_prop("metal_trash_can", refuse_pos, yaw, 0.72,
			"prison_refuse_can", Vector3(1.36, 0.68, 0.46),
			Vector3(-0.08, 0.34, 0))


## Yaw for a prop standing against wall `dir` and facing the room.


func _wall_facing(dir: int) -> float:
	match dir:
		0: return -PI / 2.0
		1: return PI / 2.0
		2: return PI
	return 0.0


## World point on the room side of wall `dir`: `along` down the wall, `off`
## in from the inner face.


func _wall_pt(dir: int, along: float, off: float, y = 0.0) -> Vector3:
	match dir:
		0: return Vector3(chunk.S - chunk.T - off, y, along)
		1: return Vector3(chunk.T + off, y, along)
		2: return Vector3(along, y, chunk.S - chunk.T - off)
	return Vector3(along, y, chunk.T + off)


## A strip of real cells along one wall: masonry fins split it into 2.4m
## bays, each fronted floor-to-header with square bars and a slid-open or
## shut gate — bunk, toilet and shelf inside, number plate over the door.
## Bays never cross a doorway lane, so a strip can never seal a room.


func _prison_cell_strip(dir: int, salt: int) -> void:
	var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
	var info = chunk._edge_info(chunk.cell, dir)
	var clear_a = 99.0
	var clear_b = -99.0
	if not info["wall"]:
		if info["full_open"]:
			return
		clear_a = float(info["t"]) - float(info["w"]) / 2.0 - 0.7
		clear_b = float(info["t"]) + float(info["w"]) / 2.0 + 0.7
	var bh = 2.55
	var deep = 2.6
	var byaw = 0.0 if dir >= 2 else PI / 2.0   # bunk long axis into the cell
	# masonry fins at every bay boundary that stays clear of the door lane
	for fi in 5:
		var fx = 1.2 + float(fi) * 2.4
		if fx > clear_a and fx < clear_b:
			continue
		chunk._sfb(dir, plane, deep / 2.0, fx, bh / 2.0, 0.14, bh, deep,
			Mats.prison_wall(), true)
	for bay in 4:
		var bc = 2.4 + float(bay) * 2.4
		if bc + 1.2 > clear_a and bc - 1.2 < clear_b:
			continue
		var giv = WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + bay)
		var open_gate = WorldGen.hr01(giv, 1) < 0.6
		# header beam, and masonry carrying on above it
		chunk._sfb(dir, plane, deep, bc, bh + 0.11, 2.4, 0.22, 0.16, Mats.prison_iron())
		if chunk.ceil_h > bh + 0.45:
			chunk._sfb(dir, plane, deep, bc, (bh + 0.22 + chunk.ceil_h) / 2.0, 2.4,
				chunk.ceil_h - bh - 0.22, 0.12, Mats.prison_wall())
		# the bar front: gate bay on the fin side the hash picks
		var gside = -1.0 if WorldGen.hr01(giv, 2) < 0.5 else 1.0
		var gc = bc + gside * 0.62
		var b0 = bc - 1.08
		var nb = 10
		for bi in nb:
			var bx = b0 + (2.16 / float(nb - 1)) * float(bi)
			if open_gate and absf(bx - gc) < 0.40:
				continue
			chunk._sfb(dir, plane, deep, bx, bh / 2.0, 0.045, bh, 0.045, Mats.prison_iron())
		if open_gate:
			# the gate itself, slid aside and left there for thirty years
			for gi in 4:
				chunk._sfb(dir, plane, deep + 0.09, bc - gside * (0.35 + float(gi) * 0.11),
					bh / 2.0, 0.045, bh - 0.1, 0.045, Mats.prison_green())
		else:
			for gi2 in 3:
				chunk._sfb(dir, plane, deep + 0.09, gc - 0.26 + float(gi2) * 0.26,
					bh / 2.0, 0.05, bh - 0.1, 0.05, Mats.prison_green())
		# what a man's whole world was: bunk, toilet, shelf
		_prison_bunk(_wall_pt(dir, bc - 0.58, 1.30), byaw, true)
		_prison_toilet(_wall_pt(dir, bc + 0.74, 0.62),
			chunk._yaw_for(dir), true)
		var effects = chunk._furnishing_pivot(Vector3.ZERO, 0.0,
			"prison_cell_personal_effects", false)
		effects.set_meta("enrichment_prop", "cell_personal_effects")
		var shelf = chunk._sfb(dir, plane, 0.16, bc + 0.7, 1.5,
			0.9, 0.05, 0.28, Mats.prison_green())
		chunk._adopt_local(effects, shelf)
		# One or two recognizable remnants per cell: a battered book set or a
		# rusted food tin. They are grouped with the shelf, so neither can ever
		# survive as unsupported floating clutter.
		var effect_pos = _wall_pt(dir, bc + 0.7, 0.16, 1.535)
		if WorldGen.hr01(giv, 8) < 0.58:
			var books = chunk._cc0_prop("book_encyclopedia_set_01", effect_pos,
				chunk._yaw_for(dir), 0.72)
			chunk._adopt_local(effects, books)
		if WorldGen.hr01(giv, 9) < 0.48:
			var tin_offset = Vector3(0.25, 0, 0).rotated(
				Vector3.UP, chunk._yaw_for(dir))
			var tin = chunk._cc0_prop("can_rusted", effect_pos + tin_offset,
				chunk._yaw_for(dir) + 0.25, 0.86)
			chunk._adopt_local(effects, tin)
		# number plate over the door
		var lab = Label3D.new()
		lab.text = "%s %02d" % [char(65 + posmod(chunk.cell.x + chunk.cell.y, 4)),
			(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 20 + bay) % 48) + 1]
		lab.font_size = 60
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.72, 0.74, 0.68)
		lab.position = _wall_pt(dir, bc, deep + 0.11, bh + 0.11)
		lab.rotation.y = (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
			else (PI if dir == 2 else 0.0)
		chunk.add_child(lab)
		# collider along the bar line, split at an open gate
		var n = -1.0 if dir == 0 or dir == 2 else 1.0
		var bp = plane + n * (chunk.T * 0.5 + deep)
		if open_gate:
			for seg in [[bc - 1.2, gc - 0.40], [gc + 0.40, bc + 1.2]]:
				var sc: float = (seg[0] + seg[1]) / 2.0
				var sw: float = seg[1] - seg[0]
				if sw < 0.1:
					continue
				if dir < 2:
					chunk._collider_box(Vector3(bp, bh / 2.0, sc), Vector3(0.12, bh, sw))
				else:
					chunk._collider_box(Vector3(sc, bh / 2.0, bp), Vector3(sw, bh, 0.12))
		else:
			if dir < 2:
				chunk._collider_box(Vector3(bp, bh / 2.0, bc), Vector3(0.12, bh, 2.4))
			else:
				chunk._collider_box(Vector3(bc, bh / 2.0, bp), Vector3(2.4, bh, 0.12))


func _prison_cellblock() -> void:
	# strips down both long walls; the whole block agrees on the axis
	var ax = WorldGen.r01(chunk.wseed, chunk.room_root.x, chunk.room_root.y, 1840) < 0.5
	# NOTE: a ternary of two array literals loses the Array[int] type at
	# runtime — assign the literals directly
	var dirs: Array[int] = [2, 3]
	if not ax:
		dirs = [0, 1]
	for d in dirs:
		_prison_cell_strip(d, 1842 + d * 30)
	# painted circulation lanes down the central range
	var lane_r = 2.55
	for side in [-1.0, 1.0]:
		var lp = Vector3(6.0 + (0.0 if ax else side * lane_r), 0.012,
			6.0 + (side * lane_r if ax else 0.0))
		var ls = Vector3(chunk.S - 1.0, 0.015, 0.07) if ax else Vector3(0.07, 0.015, chunk.S - 1.0)
		chunk._box(lp, ls, Mats.caution_yellow(), false)
	# catwalk over each strip when the block is tall — the Alcatraz register
	if chunk.ceil_h > 5.4:
		for d2 in dirs:
			var plane = (chunk.S - chunk.T / 2.0) if (d2 == 0 or d2 == 2) else (chunk.T / 2.0)
			var deck = chunk._sfb(d2, plane, 1.25, 6.0, 3.26, chunk.S - 1.6, 0.14, 2.5, Mats.prison_iron())
			deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in 11:
				var rx = 1.3 + float(i) * 0.94
				var rp = chunk._sfb(d2, plane, 2.42, rx, 3.82, 0.045, 1.0, 0.045, Mats.prison_iron())
				rp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var tr = chunk._sfb(d2, plane, 2.42, 6.0, 4.3, chunk.S - 1.6, 0.06, 0.06, Mats.prison_iron())
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _prison_cells() -> void:
	# a small room of close cells: one strip along the first solid wall
	for d in 4:
		if chunk._solid_wall(d):
			_prison_cell_strip(d, 1870 + d * 25)
			break
	# Bolted writing shelf with two real supports. The previous single leg made
	# the slab read as a floating or half-deleted table from most approaches.
	var desk_b0 = chunk.body.get_child_count()
	var desk = chunk._furnishing_pivot(Vector3(8.8, 0, 6.4), 0.0, "prison_writing_table")
	chunk._mrbox(desk, Vector3(0, 0.72, 0), Vector3(1.35, 0.08, 0.62),
		Mats.prison_green(), 0.02)
	for lx in [-0.55, 0.55]:
		chunk._mbox(desk, Vector3(lx, 0.36, 0), Vector3(0.07, 0.72, 0.55),
			Mats.prison_iron())
	chunk._mbox(desk, Vector3(0, 0.20, 0), Vector3(1.12, 0.06, 0.08),
		Mats.prison_iron())
	chunk._collider_yaw_box(Vector3(8.8, 0.42, 6.4), Vector3(1.35, 0.84, 0.64), 0)
	chunk._bind_furnishing_colliders(desk, desk_b0)
	if chunk._r(1877) < 0.5:
		chunk._cc0_prop("wooden_crate_02", Vector3(2.3, 0, 2.4), chunk._r(1878) * TAU, 0.8)


func _prison_mess_table(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "prison_mess_table")
	chunk._mrbox(v, Vector3(0, 0.78, 0), Vector3(3.5, 0.10, 0.82), Mats.prison_green(), 0.025)
	for z in [-0.88, 0.88]:
		chunk._mbox(v, Vector3(0, 0.48, z), Vector3(3.2, 0.09, 0.35), Mats.prison_green())
		for x in [-1.35, 1.35]:
			chunk._mbox(v, Vector3(x, 0.27, z), Vector3(0.08, 0.54, 0.08), Mats.prison_iron())
	# A few abandoned stainless trays, cups and one dented food tin stop the
	# room reading as four pristine geometry blocks.
	for ti in 2:
		var tx = -0.82 + float(ti) * 1.55
		var tz = -0.14 if ti == 0 else 0.16
		chunk._mrbox(v, Vector3(tx, 0.86, tz), Vector3(0.48, 0.035, 0.30),
			Mats.steel(), 0.02)
		chunk._mcyl(v, Vector3(tx + 0.16, 0.96, tz - 0.05), 0.045, 0.18,
			Mats.prison_iron())
	if chunk._r(1880 + int(p.x + p.z)) < 0.48:
		chunk._cc0_prop_local(v, "can_rusted", Vector3(0.28, 0.84, 0.0),
			chunk._r(1881 + int(p.x)) * TAU, 0.85)
	chunk._collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(3.5, 1.0, 2.0), yaw)
	chunk._bind_furnishing_colliders(v, b0)


func _prison_mess() -> void:
	# ranks of fixed tables under the lamps, and the serving line that fed
	# eight hundred men in twenty minutes
	_prison_mess_table(Vector3(3.4, 0, 3.6), PI / 2.0)
	_prison_mess_table(Vector3(3.4, 0, 8.4), PI / 2.0)
	_prison_mess_table(Vector3(8.6, 0, 3.6), PI / 2.0)
	_prison_mess_table(Vector3(8.6, 0, 8.4), PI / 2.0)
	var service_dir = -1
	for d in 4:
		if not chunk._solid_wall(d):
			continue
		service_dir = d
		var plane = (chunk.S - chunk.T / 2.0) if (d == 0 or d == 2) else (chunk.T / 2.0)
		var service_b0 = chunk.body.get_child_count()
		var service = chunk._furnishing_pivot(Vector3.ZERO, 0.0, "prison_serving_line")
		var base = chunk._sfb(d, plane, 0.55, 6.0, 0.62, 6.8, 1.24, 0.9,
			Mats.prison_green(), true)
		chunk._adopt_local(service, base)
		var top = chunk._sfb(d, plane, 0.55, 6.0, 1.28, 7.0, 0.07, 1.05, Mats.steel())
		chunk._adopt_local(service, top)
		# tray rail
		var rail = chunk._sfb(d, plane, 1.12, 6.0, 0.98, 6.8, 0.035, 0.035, Mats.chrome())
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk._adopt_local(service, rail)
		# pass-through shelf and the cold well behind
		var well_a = chunk._sfb(d, plane, 0.30, 4.2, 1.05, 2.2, 0.24, 0.35, Mats.steel())
		var well_b = chunk._sfb(d, plane, 0.30, 7.6, 1.05, 2.2, 0.24, 0.35, Mats.steel())
		chunk._adopt_local(service, well_a)
		chunk._adopt_local(service, well_b)
		chunk._bind_furnishing_colliders(service, service_b0)
		break
	# Put the clock on the same real wall as the serving line. The old fixed
	# north-wall transform left it suspended in space whenever another wall
	# was selected.
	if service_dir >= 0:
		var clock_plane = (chunk.S - chunk.T / 2.0) if (service_dir == 0 or service_dir == 2) \
			else (chunk.T / 2.0)
		chunk._wall_clock(service_dir, clock_plane)
	if chunk._r(1883) < 0.75:
		chunk._cc0_floor_prop("industrial_storage_cart", Vector3(10.5, 0, 6.0),
			-PI / 2.0, 0.72, "prison_mess_service_cart",
			Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))


func _prison_shower_station(wall: int, along: float) -> void:
	var mount = _wall_pt(wall, along, 0.02)
	var v = chunk._furnishing_pivot(mount, chunk._yaw_for(wall),
		"prison_shower_fixture", false)
	v.set_meta("enrichment_prop", "detention_shower_head")
	# Exposed riser, wall flange and vandal-resistant cross valve.
	var pipe_bottom = 1.24
	var pipe_top = chunk.ceil_h - 0.42
	chunk._mbox(v, Vector3(0, (pipe_bottom + pipe_top) * 0.5, 0),
		Vector3(0.045, pipe_top - pipe_bottom, 0.045), Mats.pipe_rust())
	var flange = MeshInstance3D.new()
	flange.mesh = chunk.TOR
	flange.material_override = Mats.prison_iron()
	flange.position = Vector3(0, 1.25, -0.035)
	flange.rotation.x = PI / 2.0
	flange.scale = Vector3(0.09, 0.035, 0.09)
	v.add_child(flange)
	chunk._mbox(v, Vector3(0, 1.25, -0.07), Vector3(0.30, 0.035, 0.035),
		Mats.prison_green())
	chunk._mbox(v, Vector3(0, 1.25, -0.07), Vector3(0.035, 0.30, 0.035),
		Mats.prison_green())
	chunk._mcyl(v, Vector3(0, 1.25, -0.11), 0.035, 0.04, Mats.chrome()).rotation.x = PI / 2.0
	# Bent arm and a thick shower rose aimed down into the room.
	var arm_y = chunk.ceil_h - 1.02
	chunk._mbeam(v, Vector3(0, arm_y, 0), Vector3(0, arm_y, -0.52),
		0.038, Mats.pipe_rust())
	chunk._mbeam(v, Vector3(0, arm_y, -0.52), Vector3(0, arm_y - 0.13, -0.66),
		0.038, Mats.pipe_rust())
	var rose = chunk._mcyl(v, Vector3(0, arm_y - 0.18, -0.70), 0.17, 0.09,
		Mats.prison_iron())
	rose.rotation.x = 0.60
	var face = chunk._mcyl(v, Vector3(0, arm_y - 0.215, -0.725), 0.135, 0.012,
		Mats.charcoal())
	face.rotation.x = 0.60
	# Soap dish and drain-cleaning hose hook at waist height.
	chunk._mrbox(v, Vector3(0.28, 0.92, -0.10), Vector3(0.34, 0.045, 0.24),
		Mats.prison_iron(), 0.018)
	chunk._mbox(v, Vector3(0.28, 1.02, 0), Vector3(0.04, 0.22, 0.04),
		Mats.prison_iron())


func _prison_shower() -> void:
	# Tiled block: pick a genuinely solid edge first. The former hard-coded
	# north wall could be an internal opening in a merged shower room, leaving
	# a row of shower heads and valves hanging across open space.
	var wall = -1
	for d in 4:
		if chunk._solid_wall(d):
			wall = d
			break
	if wall < 0:
		return
	var plane = (chunk.S - chunk.T / 2.0) if (wall == 0 or wall == 2) else (chunk.T / 2.0)
	# Five detailed institutional shower stations on the selected solid wall.
	for i in 5:
		var along = 2.0 + float(i) * 2.0
		_prison_shower_station(wall, along)
	# drain channel along the shower lane
	chunk._sfb(wall, plane, 1.85, 6.0, 0.006, 9.6, 0.012, 0.22, Mats.charcoal())
	chunk._sfb(wall, plane, 3.25, 6.0, 0.02, 10.0, 0.04, 0.10, Mats.prison_tile())
	# slat benches by the entrance
	var bench_b0 = chunk.body.get_child_count()
	var bench_pos = _wall_pt(wall, 6.0, 9.75)
	var bench = chunk._furnishing_pivot(bench_pos, chunk._yaw_for(wall),
		"prison_shower_bench")
	chunk._mbox(bench, Vector3(0, 0.72, 0), Vector3(5.8, 0.10, 0.45), Mats.prison_green())
	for bx in [-2.7, 0.0, 2.7]:
		chunk._mbox(bench, Vector3(bx, 0.36, 0), Vector3(0.08, 0.72, 0.38),
			Mats.prison_iron())
	chunk._collider_yaw_box(bench_pos + Vector3(0, 0.42, 0),
		Vector3(5.8, 0.84, 0.48), chunk._yaw_for(wall))
	chunk._bind_furnishing_colliders(bench, bench_b0)
	if chunk._r(1885) < 0.5:
		chunk._cc0_prop("WetFloorSign_01", Vector3(4.4, 0, 6.6), chunk._r(1886) * TAU, 0.9)
	# A coherent sanitation cluster: the downloaded props are small enough not
	# to need collision, but share one floor-supported pivot so they cannot
	# survive without their placement context.
	var sanitation_pos = _wall_pt(wall, 9.15, 1.05)
	var sanitation = chunk._furnishing_pivot(sanitation_pos,
		chunk._yaw_for(wall), "prison_sanitation_clutter")
	sanitation.set_meta("enrichment_prop", "sanitation_clutter")
	chunk._cc0_prop_local(sanitation, "plunger", Vector3(0, 0, 0), -0.18, 1.0)
	chunk._cc0_prop_local(sanitation, "drain_cleaner", Vector3(0.23, 0, 0.10), 0.25, 1.0)
	chunk._cc0_prop_local(sanitation, "can_rusted", Vector3(-0.22, 0, 0.08), -0.2, 0.9)


## A guard station should look like prison furniture, not two bright office
## panels seen edge-on. The real battered steel desk, CRT, keyboard, papers,
## and chair are one atomic workstation with matching collision.


func _prison_guard_desk(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var station = chunk._furnishing_pivot(p, yaw, "prison_guard_desk")
	station.set_meta("office_workstation", true)
	var desk = chunk._load_model("metal_office_desk", p, yaw)
	chunk._adopt_local(station, desk)
	chunk._collider_yaw_box(p + Vector3(0, 0.42, 0), Vector3(2.05, 0.84, 1.0), yaw)
	var terminal = chunk._vt100(p, yaw)
	chunk._adopt_local(station, terminal)
	var forward = Vector3(sin(yaw), 0, cos(yaw))
	var keyboard = chunk._vt100_keyboard(p + forward * 0.34, yaw)
	chunk._adopt_local(station, keyboard)
	var side = Vector3(cos(yaw), 0, -sin(yaw)) * 0.62
	var papers = chunk._cc0_prop("office_notepads",
		p + side + Vector3(0, 0.80, 0), yaw + 0.08, 0.45)
	chunk._adopt_local(station, papers)
	# The desk phone the block was run from. The booths down the corridor keep
	# their own wall-mounted handsets; this is the station's outside line.
	var phone = chunk._attributed_floor_prop(chunk.DESK_PHONE_PATH,
		p - side * 0.72 + Vector3(0, 0.795, 0), yaw + PI + 0.22,
		chunk.DESK_PHONE_SCALE, Vector3.ZERO, "desk_phone", station)
	if phone != null:
		chunk._set_model_material(phone, Mats.prison_handset())
	var chair = chunk._task_chair(p + forward * 1.02, yaw + PI)
	chunk._adopt_local(station, chair)
	chunk._bind_furnishing_colliders(station, b0)


func _prison_guard() -> void:
	var c = Vector3(8.2, 0, 7.0) if chunk.portal_dest < 0 else Vector3(9.2, 0, 9.2)
	_prison_bars(c + Vector3(0, 0, -1.65), 0, 4.1, 2.75, true)
	_prison_bars(c + Vector3(-2.05, 0, 0), PI / 2.0, 3.3, 2.75, false)
	_prison_guard_desk(c, PI)
	# Cameras use their actual wall plate. The previous room-centre placement
	# left this visibly hovering above the desk.
	for d in 4:
		if chunk._solid_wall(d):
			var plane = (chunk.S - chunk.T / 2.0) if (d == 0 or d == 2) else (chunk.T / 2.0)
			chunk._security_camera_wall(d, plane)
			break
	# A floor-standing key cabinet and a stack of monitors showing empty ranges.
	# The original was a shallow box more than a metre above any support.
	var key_b0 = chunk.body.get_child_count()
	var key_pos = c + Vector3(1.35, 0, 0.9)
	var keys = chunk._furnishing_pivot(key_pos, 0.0, "prison_key_cabinet")
	chunk._mrbox(keys, Vector3(0, 0.95, 0), Vector3(0.72, 1.90, 0.42),
		Mats.prison_green(), 0.025)
	chunk._mbox(keys, Vector3(0, 1.18, -0.22), Vector3(0.54, 0.84, 0.025),
		Mats.charcoal())
	for ky in 3:
		for kx in 3:
			chunk._mbox(keys, Vector3(-0.17 + float(kx) * 0.17,
				0.92 + float(ky) * 0.22, -0.245), Vector3(0.025, 0.05, 0.015),
				Mats.brass())
	chunk._collider_yaw_box(key_pos + Vector3(0, 0.95, 0), Vector3(0.74, 1.9, 0.44), 0)
	chunk._bind_furnishing_colliders(keys, key_b0)
	var monitor_b0 = chunk.body.get_child_count()
	var mv = chunk._furnishing_pivot(c + Vector3(0.9, 0, -0.9),
		PI * 0.75, "prison_monitor_console")
	# A solid dark rack and intermediate shelf make the four CRTs read as a
	# monitor console from every side, not as pale cubes hovering behind bars.
	chunk._mrbox(mv, Vector3(0, 0.38, 0), Vector3(1.28, 0.76, 0.58),
		Mats.prison_green(), 0.025)
	chunk._mbox(mv, Vector3(0, 1.18, 0.18), Vector3(1.24, 1.18, 0.08),
		Mats.prison_green())
	chunk._mbox(mv, Vector3(0, 1.19, 0), Vector3(1.22, 0.055, 0.54),
		Mats.prison_iron())
	for mi in 4:
		var mp = Vector3(-0.28 + 0.56 * float(mi % 2),
			0.94 + 0.49 * float(mi / 2), 0)
		chunk._mrbox(mv, mp, Vector3(0.5, 0.42, 0.42), Mats.iron_dark(), 0.025)
		chunk._mbox(mv, mp + Vector3(0, 0, -0.215),
			Vector3(0.38, 0.30, 0.01), Mats.screen_glow() if mi == 2 else Mats.screen_dark())
	chunk._collider_yaw_box(mv.position + Vector3(0, 0.9, 0), Vector3(1.25, 1.9, 0.55), mv.rotation.y)
	chunk._bind_furnishing_colliders(mv, monitor_b0)


func _prison_industry() -> void:
	for z in [3.6, 8.2]:
		var p = Vector3(6, 0, z)
		var bench_b0 = chunk.body.get_child_count()
		var bench = chunk._furnishing_pivot(p, 0.0, "prison_industry_bench")
		chunk._mrbox(bench, Vector3(0, 0.78, 0), Vector3(4.6, 0.12, 1.15),
			Mats.prison_green(), 0.025)
		for x in [-2.0, 2.0]:
			chunk._mbox(bench, Vector3(x, 0.38, 0), Vector3(0.09, 0.76, 0.92),
				Mats.prison_iron())
		chunk._collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(4.6, 1.0, 1.2), 0)
		# a vice and left-behind work on each bench
		chunk._mbox(bench, Vector3(-1.2, 0.95, 0.2), Vector3(0.24, 0.22, 0.18),
			Mats.iron_dark())
		if chunk._r(1893 + int(z)) < 0.6:
			chunk._mbox(bench, Vector3(1.1, 0.90, -0.15), Vector3(0.5, 0.12, 0.35),
				Mats.box_white())
		chunk._bind_furnishing_colliders(bench, bench_b0)
	chunk._cc0_prop("steel_frame_shelves_01", Vector3(10.7, 0, 6), -PI / 2.0, 0.1)
	chunk._collider_yaw_box(Vector3(10.7, 0.9, 6), Vector3(2.0, 1.8, 0.75), -PI / 2.0)
	# work lamps low over the benches
	for lz in [3.6, 8.2]:
		var lamp = chunk._cc0_prop("hanging_industrial_lamp", Vector3(6, chunk.ceil_h - 0.06, lz),
			0.0, 0.85)
		chunk._disable_shadows(lamp)
	if chunk._r(1897) < 0.6:
		chunk._cc0_prop("wooden_crate_02", Vector3(1.8, 0, 9.6), chunk._r(1898) * TAU, 0.9)
	if chunk._r(1899) < 0.4:
		# ships as an upright wheel — lay it flat
		var tyre = chunk._cc0_prop("old_tyre", Vector3(2.2, 0.085, 2.1), chunk._r(1900) * TAU)
		tyre.rotation.x = PI / 2.0
	# A battered rolling job cart and its detached refuse lid create the
	# maintenance-shop density the bare benches were missing.
	chunk._cc0_floor_prop("industrial_storage_cart", Vector3(2.0, 0, 6.0),
		PI / 2.0, 0.72, "prison_industry_cart",
		Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))
	if chunk._r(1901) < 0.72:
		chunk._cc0_floor_prop("metal_trash_can", Vector3(9.8, 0, 2.0),
			0.0, 0.68, "prison_industry_refuse",
			Vector3(1.28, 0.64, 0.44), Vector3(-0.06, 0.32, 0))


func _prison_visitation_phone(parent: Node3D, side_z: float) -> void:
	var phone = Node3D.new()
	phone.position = Vector3(0, 0, side_z * 0.08)
	phone.set_meta("prison_visitation_phone", true)
	phone.set_meta("enrichment_prop", "visitation_phone")
	parent.add_child(phone)
	# The authored handset carries its own body, cradle and coiled cord. It
	# hangs on the divider facing whichever side of the glass this booth is,
	# which is what `side_z` selects. Its centre is corrected under a pivot
	# rather than in the offset, so the turn cannot get the sign wrong.
	var mount = Node3D.new()
	mount.position = Vector3(0.42, 1.28, 0.0)
	mount.rotation.y = 0.0 if side_z > 0.0 else PI
	phone.add_child(mount)
	var hung = chunk._attributed_prop_local(mount, chunk.PRISON_WALL_PHONE_PATH,
		Vector3(-chunk.PRISON_WALL_PHONE_CENTRE.x, -chunk.PRISON_WALL_PHONE_CENTRE.y,
			-chunk.PRISON_WALL_PHONE_CENTRE.z) * chunk.PRISON_WALL_PHONE_SCALE,
		0.0, Vector3.ONE * chunk.PRISON_WALL_PHONE_SCALE)
	if hung != null:
		hung.set_meta("authored_model", "visitation_phone")
		return
	mount.get_parent().remove_child(mount)
	mount.free()
	# Wall plate and keypad on the occupant's side of the glass.
	chunk._mrbox(phone, Vector3(0.33, 1.35, 0),
		Vector3(0.34, 0.46, 0.09), Mats.prison_green(), 0.025)
	for row in 3:
		for col in 2:
			var key = chunk._mcyl(phone, Vector3(0.25 + float(col) * 0.085,
				1.25 + float(row) * 0.085, side_z * 0.052),
				0.018, 0.018, Mats.metal_gray())
			key.rotation.x = PI / 2.0
	# A heavy vertical receiver with distinct ear and mouth caps.
	chunk._mrbox(phone, Vector3(0.51, 1.37, side_z * 0.075),
		Vector3(0.085, 0.34, 0.085), Mats.charcoal(), 0.025)
	for py in [1.18, 1.56]:
		var cap = chunk._mcyl(phone, Vector3(0.51, py, side_z * 0.075),
			0.075, 0.11, Mats.rubber_black())
		cap.rotation.x = PI / 2.0
	for py in [1.22, 1.52]:
		chunk._mbox(phone, Vector3(0.45, py, side_z * 0.04),
			Vector3(0.08, 0.045, 0.09), Mats.prison_iron())
	# Slack cord drops to the counter in a crooked, readable loop.
	var cord = [
		Vector3(0.50, 1.15, side_z * 0.09),
		Vector3(0.55, 1.06, side_z * 0.11),
		Vector3(0.48, 0.98, side_z * 0.12),
		Vector3(0.56, 0.91, side_z * 0.12),
		Vector3(0.45, 0.86, side_z * 0.10),
	]
	for i in cord.size() - 1:
		chunk._mbeam(phone, cord[i], cord[i + 1], 0.012, Mats.rubber_black())


func _prison_visitation_booth(p: Vector3) -> void:
	var b0 = chunk.body.get_child_count()
	var booth = chunk._furnishing_pivot(p, 0.0, "prison_visitation_booth")
	booth.set_meta("visitation_counter", true)
	booth.set_meta("visitation_stool_count", 2)
	# Each bay is a complete little booth: counter, floor base, glass, handset
	# and two bolted stools. Doorway clearance may remove one bay, but cannot
	# separate a row of stools from the furniture they face.
	chunk._mrbox(booth, Vector3(0, 0.82, 0), Vector3(1.34, 0.16, 1.1),
		Mats.prison_green(), 0.025)
	chunk._mbox(booth, Vector3(0, 0.375, 0), Vector3(1.26, 0.75, 0.85),
		Mats.prison_green())
	chunk._mbox(booth, Vector3(0, 1.75, 0), Vector3(1.34, 1.7, 0.055),
		Mats.mall_glass())
	for side_x in [-1.0, 1.0]:
		chunk._mbox(booth, Vector3(side_x * 0.65, 1.28, 0),
			Vector3(0.055, 1.95, 1.1), Mats.prison_iron())
	for side_z: float in [-1.0, 1.0]:
		_prison_visitation_phone(booth, side_z)
		var stool_z: float = side_z * 1.15
		chunk._mcyl(booth, Vector3(0, 0.30, stool_z), 0.05, 0.60,
			Mats.prison_iron())
		chunk._mcyl(booth, Vector3(0, 0.63, stool_z), 0.19, 0.06,
			Mats.prison_green())
		chunk._collider_cyl(p + Vector3(0, 0.35, stool_z), 0.20, 0.70)
	chunk._collider_yaw_box(p + Vector3(0, 0.75, 0), Vector3(1.34, 1.5, 1.2), 0)
	chunk._bind_furnishing_colliders(booth, b0)


func _prison_visitation() -> void:
	for i in 4:
		_prison_visitation_booth(Vector3(3.75 + float(i) * 1.5, 0, 6.4))


func _prison_rotunda() -> void:
	var c = Vector3(6, 0, 6)
	var radius = 2.45
	# Raised masonry plinth and a roof plate make the hub a small building
	# inside the block, not a ring of arbitrary posts.
	chunk._cyl(c + Vector3(0, 0.36, 0), radius, 0.72, Mats.prison_green(), false)
	chunk._cyl(c + Vector3(0, 3.18, 0), radius + 0.16, 0.16, Mats.prison_iron(), false)
	# Dense iron cage: three polygonal rings and twenty-four verticals.
	var sides = 24
	for i in sides:
		var a = TAU * float(i) / float(sides)
		var b = TAU * float(i + 1) / float(sides)
		var p0 = c + Vector3(cos(a), 0, sin(a)) * radius
		var p1 = c + Vector3(cos(b), 0, sin(b)) * radius
		chunk._beam(p0 + Vector3(0, 0.74, 0), p1 + Vector3(0, 0.74, 0),
			0.055, Mats.prison_iron())
		chunk._beam(p0 + Vector3(0, 1.92, 0), p1 + Vector3(0, 1.92, 0),
			0.035, Mats.prison_iron())
		chunk._beam(p0 + Vector3(0, 3.08, 0), p1 + Vector3(0, 3.08, 0),
			0.055, Mats.prison_iron())
		chunk._beam(p0 + Vector3(0, 0.74, 0), p0 + Vector3(0, 3.08, 0),
			0.035, Mats.prison_iron())
	# A circular control desk, instrument blocks and a cold lamp are visible
	# through the bars from every branch of the rotunda.
	chunk._cyl(c + Vector3(0, 1.02, 0), 1.55, 0.16, Mats.prison_iron(), false)
	chunk._cyl(c + Vector3(0, 0.80, 0), 1.18, 0.44, Mats.prison_green(), false)
	for i in 6:
		var a = TAU * float(i) / 6.0
		var p = c + Vector3(cos(a), 1.18, sin(a)) * 1.23
		var panel = chunk._box(p, Vector3(0.54, 0.30, 0.12), Mats.charcoal(), false)
		panel.rotation.y = -a + PI / 2.0
		var lamp = chunk._box(p + Vector3(0, 0.02, 0), Vector3(0.20, 0.08, 0.13),
			Mats.prison_panel(), false)
		lamp.rotation.y = panel.rotation.y
	chunk._collider_cyl(c + Vector3(0, 1.5, 0), radius, 3.0)
	# Roof-hung camera on an actual pendant, rather than a housing suspended in
	# the middle of the rotunda with nothing behind its wall plate.
	var cam_yaw = chunk._r(1899) * TAU
	var cam_forward = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var cam_mount = c + cam_forward * 0.62 + Vector3(0, 2.78, 0)
	chunk._box(cam_mount - cam_forward * 0.08 + Vector3(0, 0.20, 0),
		Vector3(0.14, 0.54, 0.14), Mats.prison_iron(), false)
	chunk._security_camera(cam_mount, cam_yaw)
	var guard_light = OmniLight3D.new()
	guard_light.position = c + Vector3(0, 2.75, 0)
	guard_light.light_color = Color(0.68, 0.88, 0.72)
	guard_light.light_energy = 2.4
	guard_light.omni_range = 9.5
	guard_light.shadow_enabled = true
	guard_light.distance_fade_enabled = true
	guard_light.distance_fade_begin = 24.0
	guard_light.distance_fade_length = 8.0
	chunk.add_child(guard_light)
	# radial walkway lanes painted out from the hub to every branch
	for i in 4:
		var a = TAU * float(i) / 4.0 + TAU / 8.0
		var dirv = Vector3(cos(a), 0, sin(a))
		var lp = c + dirv * (radius + 1.75)
		var lane = chunk._box(lp + Vector3(0, 0.012, 0), Vector3(0.07, 0.015, 2.6),
			Mats.caution_yellow(), false)
		lane.rotation.y = -a + PI / 2.0
