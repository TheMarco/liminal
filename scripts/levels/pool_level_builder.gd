extends "res://scripts/levels/chunk_level_builder.gd"


func _pool_floor_ceiling() -> void:
	chunk._box(Vector3(chunk.S / 2.0, chunk.ceil_h + 0.15, chunk.S / 2.0), Vector3(chunk.S, 0.3, chunk.S),
		Mats.pool_wall_tile())
	if _pool_dry():
		# A dry hall. Its floor is a solid slab standing just clear of the
		# water next door, so you walk out of the pool onto it rather than
		# climbing, and it is genuinely somewhere to stand and dry off.
		_pool_dry_slab()
		_pool_edge_steps()
		return
	chunk._box(Vector3(chunk.S / 2.0, -0.15, chunk.S / 2.0), Vector3(chunk.S, 0.3, chunk.S), Mats.pool_tile())
	# The surface itself carries no collider: you wade through it, and the
	# basin floor underneath is what holds you up.
	# A subdivided plane, never a box. A box showed its side faces at every
	# chunk join — those were the black seams — and having no interior vertices
	# it left the vertex swell with nothing to displace, so the surface read
	# dead flat.
	#
	# Exactly one cell across, with NO overlap onto the neighbour. Lapping the
	# plane past the cell stacked two translucent surfaces at every join, and
	# 0.6 opacity over 0.6 is 0.84 — a darker strip that a grazing view smears
	# into a broad bar across the water. The swell is a pure function of world
	# position, so neighbouring planes agree along the shared edge anyway and
	# meeting exactly is seamless.
	var surf = PlaneMesh.new()
	surf.size = Vector2(chunk.S, chunk.S)
	surf.subdivide_width = 28
	surf.subdivide_depth = 28
	var water = MeshInstance3D.new()
	water.mesh = surf
	water.material_override = Mats.pool_water()
	water.position = Vector3(chunk.S / 2.0, chunk.POOL_WATER_Y, chunk.S / 2.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("pool_water_surface", true)
	chunk.add_child(water)
	_pool_edge_steps()


## The dry hall's raised floor: one square slab wall to wall. Per-corner
## fillets were tried and reverted — a slab corner rounds correctly only
## when both its edges face water, and coordinating that across dry
## neighbours bought nothing a plain square slab doesn't already give.


func _pool_dry_slab() -> void:
	var yc = chunk.POOL_DRY_Y * 0.5 - 0.15
	var h = chunk.POOL_DRY_Y + 0.3
	chunk._box(Vector3(chunk.S / 2.0, yc, chunk.S / 2.0), Vector3(chunk.S, h, chunk.S), Mats.pool_tile())


## Which halls hold water. Roughly a third of the floor is dry tile, because a
## level that is nothing but standing water gives the player nowhere to stand,
## nothing to contrast the water against, and no way out of it.


func _pool_dry() -> bool:
	return chunk.pool_style_dry(chunk.style)


## The walkable floor height of this cell: zero everywhere except the pool
## floor, whose dry halls stand 1.42m clear of the water datum. Anything that
## plants itself on "the floor" — portals, the wander elevator — must stand
## on this, or it ends up buried to the waist in a dry hall.


func _floor_h() -> float:
	return chunk.POOL_DRY_Y if chunk.theme == 9 and _pool_dry() else 0.0


## Where a dry hall meets a flooded one, the floor has to step. Three broad
## tiled treads in the doorway, always built by whichever side is dry so the
## two cells cannot each build their own and interleave.


func _pool_edge_steps() -> void:
	if not _pool_dry():
		return
	for dir in 4:
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)
		if bool(info["wall"]):
			continue
		var nb: Vector2i = chunk.cell + WorldGen.DIRV[dir]
		if chunk.pool_style_dry(WorldGen.cell_style(chunk.wseed, nb, chunk.theme)):
			continue
		var t = float(info["t"])
		var w = maxf(float(info["w"]), 2.6)
		# The neighbour may stand its own dry deck against this very stretch
		# of edge — a channel towpath, a basin side walk, a bridge end — all
		# at this same dry-hall height, so the two floors meet flush. Treads
		# would bury themselves in that deck, and a ladder would stand on
		# dry tile with its rails diving into solid floor.
		if _pool_nb_deck_blocks(nb, dir, t, w):
			continue
		var nb_style = WorldGen.cell_style(chunk.wseed, nb, chunk.theme)
		if nb_style == WorldGen.POOL_STAIRS \
				and _pool_stairs_exit(nb) == WorldGen.OPP[dir]:
			# The stairs room sends its wide tiled stair to this very opening.
			# Our own treads and ladder would land fused into it — the stair
			# IS the crossing, so this side builds nothing.
			continue
		# Steps or a ladder — one way out per opening, never both fused
		# together in the same doorway.
		if chunk._r(2601 + dir) >= 0.55:
			_pool_wall_ladder(dir, t - w * 0.26)
			if w > 5.0:
				_pool_wall_ladder(dir, t + w * 0.34)
			continue
		var steps = 3
		for i in steps:
			# Each tread is lower and reaches further out into the water.
			var top = chunk.POOL_DRY_Y * (1.0 - float(i) / float(steps))
			var out = 0.55 + float(i) * 0.55
			var pos: Vector3
			var size: Vector3
			# The treads protrude INTO the flooded neighbour. The original
			# signs placed them inside this cell — inside the solid dry
			# slab — which buried every tread and left the wall ladder as
			# the only actual way out of the water.
			match dir:
				0:
					pos = Vector3(chunk.S + out * 0.5, top * 0.5, t)
					size = Vector3(out, maxf(top, 0.10), w)
				1:
					pos = Vector3(-out * 0.5, top * 0.5, t)
					size = Vector3(out, maxf(top, 0.10), w)
				2:
					pos = Vector3(t, top * 0.5, chunk.S + out * 0.5)
					size = Vector3(w, maxf(top, 0.10), out)
				_:
					pos = Vector3(t, top * 0.5, -out * 0.5)
					size = Vector3(w, maxf(top, 0.10), out)
			var tread = chunk._box(pos, size, Mats.pool_tile())
			tread.set_meta("pool_step", true)
		# The walking ramp must run along the treads' OUTER top corners: laid
		# from the dry lip itself it passes under them, and every riser face
		# is a wall again. From the top tread's edge it grazes each corner.
		_pool_step_ramp(dir, t, w,
			chunk.S if (dir == 0 or dir == 2) else 0.0, chunk.POOL_DRY_Y, 1.65, 0.55)


## A round tiled pier from the basin floor to the ceiling. These are the
## columns standing in the water in every reference image, and they are what
## breaks the sight lines into something you can get lost in. Round rather
## than square: the world-space tile shader bends the grid around the barrel,
## and the curve is what keeps the floor from being wall-to-wall right angles.


func _pool_pier(at: Vector3) -> void:
	var p = chunk._cyl(Vector3(at.x, chunk.ceil_h * 0.5, at.z), chunk.POOL_PIER * 0.62,
		chunk.ceil_h, Mats.pool_tile())
	p.set_meta("pool_pier", true)


## An invisible walking ramp over a run of treads. The player controller has
## no step-up logic — every vertical tread face is a wall to it — so a stair
## only works when a smooth collider carries the feet across it. The ramp
## descends from `drop` height at `edge + outward*start` to the floor at
## `edge + outward*(start+run)`; `start` sits it on the top tread's OUTER
## edge so the line grazes every tread corner instead of passing under them.
## For dir 0/2 the run descends toward +axis, for dir 1/3 toward -axis.


func _pool_step_ramp(dir: int, at: float, width: float, edge: float,
		drop: float, run: float, start = 0.0) -> void:
	var ang = atan(drop / run)
	var ln = sqrt(drop * drop + run * run)
	var outward = 1.0 if (dir == 0 or dir == 2) else -1.0
	var mid = edge + outward * (start + run * 0.5)
	var y = drop * 0.5 - 0.06
	if dir < 2:
		chunk._collider_rot_box(Vector3(mid, y, at),
			Vector3(ln, 0.12, width), Vector3(0, 0, -outward * ang))
	else:
		chunk._collider_rot_box(Vector3(at, y, mid),
			Vector3(width, 0.12, ln), Vector3(outward * ang, 0, 0))


## A dry walkway along one wall, its coping lip proud of the water, plus the
## ladder that is the only way back up onto it. `dir` picks the wall.


func _pool_deck(dir: int, width: float) -> void:
	var half = width * 0.5
	var centre = half
	var deck_pos: Vector3
	var deck_size: Vector3
	match dir:
		0:
			deck_pos = Vector3(chunk.S - centre, chunk.POOL_DECK_Y * 0.5, chunk.S / 2.0)
			deck_size = Vector3(width, chunk.POOL_DECK_Y, chunk.S)
		1:
			deck_pos = Vector3(centre, chunk.POOL_DECK_Y * 0.5, chunk.S / 2.0)
			deck_size = Vector3(width, chunk.POOL_DECK_Y, chunk.S)
		2:
			deck_pos = Vector3(chunk.S / 2.0, chunk.POOL_DECK_Y * 0.5, chunk.S - centre)
			deck_size = Vector3(chunk.S, chunk.POOL_DECK_Y, width)
		_:
			deck_pos = Vector3(chunk.S / 2.0, chunk.POOL_DECK_Y * 0.5, centre)
			deck_size = Vector3(chunk.S, chunk.POOL_DECK_Y, width)
	var deck = chunk._box(deck_pos, deck_size, Mats.pool_tile())
	deck.set_meta("pool_deck", true)
	# The coping: a darker rounded band capping the edge, which is what makes
	# this read as a built pool rather than a hole cut in a floor.
	var lip_pos = deck_pos
	var lip_size = deck_size
	var inward = -1.0 if dir == 0 or dir == 2 else 1.0
	if dir < 2:
		lip_pos.x = deck_pos.x + inward * (half - 0.11)
		lip_size = Vector3(0.22, 0.10, chunk.S)
	else:
		lip_pos.z = deck_pos.z + inward * (half - 0.11)
		lip_size = Vector3(chunk.S, 0.10, 0.22)
	lip_pos.y = chunk.POOL_DECK_Y + 0.05
	chunk._box(lip_pos, lip_size, Mats.pool_coping(), false)
	var along = lerpf(3.0, chunk.S - 3.0, chunk._r(2210 + dir))
	_pool_ladder(dir, half, along)


## Stainless grab rails hooping out of the deck edge down into the water. The
## rails are the climbable volume: the player script looks for the area, not
## for the geometry, so the ladder works no matter how it is dressed.


func _pool_ladder(dir: int, deck_half: float, along: float) -> void:
	var inward = -1.0 if dir == 0 or dir == 2 else 1.0
	var edge: float = (chunk.S - deck_half) if dir == 0 \
		else (deck_half if dir == 1 else 0.0)
	var pivot = Node3D.new()
	if dir < 2:
		pivot.position = Vector3(edge + inward * 0.16, 0.0, along)
	else:
		edge = (chunk.S - deck_half) if dir == 2 else deck_half
		pivot.position = Vector3(along, 0.0, edge + inward * 0.16)
	pivot.rotation.y = 0.0 if dir < 2 else PI / 2.0
	pivot.set_meta("pool_ladder", true)
	chunk.add_child(pivot)
	var rail = Mats.pool_rail()
	# two uprights curving over the coping, and three rungs between them
	for side in [-1.0, 1.0]:
		chunk._mcyl(pivot, Vector3(0, chunk.POOL_DECK_Y * 0.5 + 0.25, side * 0.24),
			0.028, chunk.POOL_DECK_Y + 0.5, rail)
	for i in 3:
		var y = 0.30 + float(i) * 0.34
		chunk._mbox(pivot, Vector3(0, y, 0), Vector3(0.06, 0.035, chunk.POOL_LADDER_W),
			rail)
	var area = Area3D.new()
	area.position = Vector3(0, chunk.POOL_DECK_Y * 0.5, 0)
	area.set_meta("pool_ladder_volume", true)
	# The player finds this with a point query on its own layer; it must never
	# collide with anything, only be findable.
	area.collision_layer = Player.LADDER_LAYER
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.95, chunk.POOL_DECK_Y + 1.2, chunk.POOL_LADDER_W + 0.5)
	cs.shape = box
	area.add_child(cs)
	pivot.add_child(area)


## A wide tiled stair walking down into the water, the calmest way in.
## `at` centres it across the wall — aligned with a doorway when there is one.


func _pool_stairs(dir: int, at = chunk.S / 2.0) -> void:
	var steps = 4
	for i in steps:
		var h = chunk.POOL_DECK_Y * (1.0 - float(i) / float(steps))
		var depth = 0.55
		var run = 1.3 + float(i) * depth
		var pos: Vector3
		var size: Vector3
		if dir < 2:
			var x: float = (chunk.S - run * 0.5) if dir == 0 else run * 0.5
			pos = Vector3(x, h * 0.5, at)
			size = Vector3(run, maxf(h, 0.08), 4.6)
		else:
			var z: float = (chunk.S - run * 0.5) if dir == 2 else run * 0.5
			pos = Vector3(at, h * 0.5, z)
			size = Vector3(4.6, maxf(h, 0.08), run)
		var st = chunk._box(pos, size, Mats.pool_tile())
		st.set_meta("pool_step", true)
	# The stair descends INWARD from its wall, so the ramp runs in the
	# opposite sense to an edge-step ramp on the same wall, starting on the
	# top step's outer edge (1.3 out) to graze every corner below it.
	_pool_step_ramp(WorldGen.OPP[dir], at, 4.6,
		chunk.S if (dir == 0 or dir == 2) else 0.0, chunk.POOL_DECK_Y, 2.2, 1.3)


## Every window on this floor is the same rounded pill. The old flat variant
## built a stacked-box "arch" that read as a lumpy white rectangle pasted on
## the tile rather than an opening — it had no reveal, so nothing about it
## said the wall had thickness. Kept as a name so callers need not care.


func _pool_window(dir: int, along: float, tall = true) -> void:
	# Only ever on a solid outside wall. Placed on an edge that is actually an
	# opening, the pane hangs in mid-air in the middle of the doorway — which
	# is exactly what it was doing. This also keeps them sparse for free:
	# a room with three ways out can only carry one.
	if not bool(WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]):
		return
	# Daylight is only credible where you cannot walk around the wall and
	# disprove it. An eye-level pane on an interior wall claims an outside
	# that the next room refutes, so the pills exist only in the taller
	# halls, high up under the ceiling, where the light reads as falling in
	# from somewhere genuinely beyond the building. 5.0 admits the 5.2m
	# multi-cell halls and the 7.4m landmarks; the ordinary 4.1-4.6 rooms
	# never qualify.
	if chunk.ceil_h < 5.0:
		return
	_pool_round_window(dir, along, tall)


func _pool_round_window(dir: int, along: float, tall = true) -> void:
	# A CylinderMesh's axis is +Y. The caps therefore have to be turned onto the
	# wall normal individually — rotating the parent instead sent them spinning
	# off axis and left huge unshaded discs hanging in the room.
	var plane = (chunk.S - 0.12) if (dir == 0 or dir == 2) else 0.12
	var inward = -1.0 if (dir == 0 or dir == 2) else 1.0
	var r = 0.55
	var body = 1.45 if tall else 0.0
	# High under the ceiling, well above anything walkable, so the glow has
	# room to fall through the hall the way a clerestory would let it.
	var mid = chunk.ceil_h - 1.15 - body * 0.5
	var pivot = Node3D.new()
	pivot.position = Vector3(plane, mid, along) if dir < 2 \
		else Vector3(along, mid, plane)
	pivot.set_meta("pool_window", true)
	pivot.set_meta("pool_window_round", true)
	chunk.add_child(pivot)
	# A reveal in front of the light. Without this the pane sits flush on the
	# tile and reads as a decal; recessed, the jamb catches a highlight and the
	# wall finally has thickness.
	var reveal = Mats.pool_wall_tile()
	var rw = r + 0.16
	var rsize = Vector3(0.20, body + rw * 2.0, rw * 2.0) if dir < 2 \
		else Vector3(rw * 2.0, body + rw * 2.0, 0.20)
	var frame = chunk._mbox(pivot, Vector3(inward * -0.11, 0.0, 0.0) if dir < 2 \
		else Vector3(0.0, 0.0, inward * -0.11), rsize, reveal)
	frame.set_meta("pool_window_reveal", true)
	var glow = Mats.pool_daylight()
	var caps: Array = [-1.0, 1.0] if body > 0.01 else [0.0]
	for sgn: float in caps:
		var c = chunk._mcyl(pivot, Vector3(0, sgn * body * 0.5, 0), r, 0.09, glow)
		if dir < 2:
			c.rotation.z = PI / 2.0
		else:
			c.rotation.x = PI / 2.0
	if body > 0.01:
		var size = Vector3(0.09, body, r * 2.0) if dir < 2 \
			else Vector3(r * 2.0, body, 0.09)
		chunk._mbox(pivot, Vector3.ZERO, size, glow)
	if chunk.has_meta("pool_window_lit"):
		return
	chunk.set_meta("pool_window_lit", true)
	var lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.98, 0.90)
	lamp.light_energy = 3.8
	lamp.spot_range = 17.0
	lamp.spot_angle = 46.0
	lamp.shadow_enabled = false
	lamp.position = pivot.position + (Vector3(inward * 0.35, 0, 0) if dir < 2 \
		else Vector3(0, 0, inward * 0.35))
	lamp.rotation.y = (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
		else (PI if dir == 2 else 0.0)
	# Mounted high, the beam must dive to reach the water and the floor.
	lamp.rotation.x = -0.62
	lamp.set_meta("pool_window_light", true)
	chunk.add_child(lamp)


## Crown strips for one pool wall, on BOTH faces of the canonical wall.
## Each face's strip sits at ITS room's ceiling: the two rooms sharing this
## wall can have different heights, and a single strip at the owner's height
## floated mid-wall in the taller neighbour.


func _pool_crown_trims(dir: int, plane: float, from: float, to: float) -> void:
	if to - from < 0.05:
		return
	for side: float in [-1.0, 1.0]:
		var room_cell := _pool_face_cell(dir, side)
		var side_ceil = chunk.cell_ceil_h(chunk.wseed, room_cell, chunk.theme)
		var face = plane + side * chunk.POOL_WALL_T * 0.5
		var off = face + side * 0.05
		var mid = (from + to) * 0.5
		var strip = chunk._box(
			Vector3(off, side_ceil - 0.05, mid) if dir < 2 \
				else Vector3(mid, side_ceil - 0.05, off),
			Vector3(0.1, 0.1, to - from) if dir < 2 \
				else Vector3(to - from, 0.1, 0.1),
			Mats.crown(), false)
		strip.set_meta("pool_crown", true)
		strip.set_meta("pool_straight_crown", true)
		strip.set_meta("pool_crown_dir", dir)
		strip.set_meta("pool_crown_side", side)
		strip.set_meta("pool_crown_cell", room_cell)
		strip.set_meta("pool_crown_from", from)
		strip.set_meta("pool_crown_to", to)


## Which cell's room lies against face `side` of a wall on edge `dir`.


func _pool_face_cell(dir: int, side: float) -> Vector2i:
	match dir:
		0:
			return chunk.cell if side < 0.0 else chunk.cell + Vector2i(1, 0)
		1:
			return chunk.cell if side > 0.0 else chunk.cell + Vector2i(-1, 0)
		2:
			return chunk.cell if side < 0.0 else chunk.cell + Vector2i(0, 1)
		_:
			return chunk.cell if side > 0.0 else chunk.cell + Vector2i(0, -1)


## The wall a stairs room sends its wide stair to: the first edge, scanning
## from the cell's own roll, that opens onto a dry hall. Deterministic from
## the cell's dice alone, so the dry neighbour can skip its own treads and
## ladder at that shared opening — the stair IS the crossing. -1 when the
## room has no dry neighbour to climb out to.


func _pool_stairs_exit(c: Vector2i) -> int:
	var dir = int(WorldGen.r01(chunk.wseed, c.x, c.y, 2350) * 3.99)
	for d in 4:
		var pick = (dir + d) % 4
		if bool(WorldGen.edge_info(chunk.wseed, c, pick, chunk.theme)["wall"]):
			continue
		if chunk.pool_style_dry(WorldGen.cell_style(
				chunk.wseed, c + WorldGen.DIRV[pick], chunk.theme)):
			return pick
	return -1


## Whether the flooded neighbour `nb` stands its own dry deck against the
## stretch of shared edge our opening (centre `t`, width `w`) faces: a
## channel towpath, a basin side walk along that wall, or the end of a
## basin bridge. All stand at POOL_DRY_Y, flush with our dry floor.
## Predicted from the neighbour's own dice — the same salts its room
## builder rolls — so the two cells agree without either building the
## other. This started as a channel-towpath check; the stray ladder found
## standing mid-deck with its rails diving into solid tile was the same
## situation with a basin side walk nobody predicted.


func _pool_nb_deck_blocks(nb: Vector2i, dir: int, t: float, w: float) -> bool:
	var facing: int = WorldGen.OPP[dir]
	var st = WorldGen.cell_style(chunk.wseed, nb, chunk.theme)
	if st == WorldGen.POOL_CHANNEL:
		var axis = WorldGen.corridor(chunk.wseed, nb)
		if axis == 0 or WorldGen.r01(chunk.wseed, nb.x, nb.y, 2313) >= 0.5:
			return false
		return facing == (3 if axis == 1 else 1)
	if st == WorldGen.POOL_STAIRS:
		# A stairs room can hang its own 2.2m side walk off the wall at
		# (stair dir + 2) % 4 — the salts here mirror _pool_stairs_room.
		if WorldGen.r01(chunk.wseed, nb.x, nb.y, 2354) >= 0.5:
			return false
		var sdir = _pool_stairs_exit(nb)
		if sdir < 0:
			sdir = int(WorldGen.r01(chunk.wseed, nb.x, nb.y, 2350) * 3.99)
		var wd2 = (sdir + 2) % 4
		if wd2 == facing:
			return true
		if wd2 == dir:
			return false
		var lo2 = (chunk.S - 2.2) if (wd2 == 0 or wd2 == 2) else 0.0
		var hi2 = chunk.S if (wd2 == 0 or wd2 == 2) else 2.2
		return t - w / 2.0 < hi2 and t + w / 2.0 > lo2
	if st != WorldGen.POOL_BASIN:
		return false
	var roll = WorldGen.r01(chunk.wseed, nb.x, nb.y, 2380)
	var lo = 0.0
	var hi = -1.0
	if roll < 0.46:
		var wd = int(WorldGen.r01(chunk.wseed, nb.x, nb.y, 2381) * 3.99)
		if wd == facing:
			return true
		if wd == dir:
			return false
		# A perpendicular side walk meets our edge near one corner, over its
		# own width along the shared coordinate.
		var span = lerpf(2.2, 3.2, WorldGen.r01(chunk.wseed, nb.x, nb.y, 2382))
		lo = (chunk.S - span) if (wd == 0 or wd == 2) else 0.0
		hi = chunk.S if (wd == 0 or wd == 2) else span
	elif roll < 0.64:
		var along_x = WorldGen.r01(chunk.wseed, nb.x, nb.y, 2383) < 0.5
		# A bridge only reaches the two edges its axis runs between.
		if along_x != (facing == 0 or facing == 1):
			return false
		lo = chunk.S / 2.0 - 1.05
		hi = chunk.S / 2.0 + 1.05
	else:
		return false
	return t - w / 2.0 < hi and t + w / 2.0 > lo


## A ladder out of the water at a pool/dry boundary, climbing the 1.15m to the
## dry floor. Built alongside the treads rather than instead of them, so a
## player who wants the ladder finds one and a player who does not can walk.


func _pool_wall_ladder(dir: int, along: float) -> void:
	# Hung off the dry cell's edge, out over the water it serves.
	var edge: float = chunk.S if dir == 0 else (0.0 if dir == 1 else (chunk.S if dir == 2 else 0.0))
	_pool_ladder_at(dir, edge, along, -1.0 if (dir == 0 or dir == 2) else 1.0)



## Rooms are lit by daylight they cannot see the source of, plus the odd
## working fluorescent over a dry hall. The water does the rest: its specular
## picks the fixtures up as the long rectangles the reference is full of.


func _pool_lighting() -> void:
	var warm = Color(0.94, 0.97, 0.95)
	var lamp = OmniLight3D.new()
	lamp.light_color = warm
	lamp.light_energy = 1.05
	lamp.omni_range = 14.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.7, chunk.S / 2.0)
	chunk.add_child(lamp)
	if chunk.style == WorldGen.POOL_ALCOVE:
		lamp.light_energy = 0.45
		return
	if chunk.style == WorldGen.POOL_DECK or chunk.style == WorldGen.POOL_GALLERY \
			or chunk.style == WorldGen.POOL_CHANNEL:
		var strip = chunk._box(Vector3(chunk.S / 2.0, chunk.ceil_h - 0.06, chunk.S / 2.0),
			Vector3(0.55, 0.06, chunk.S - 2.2), Mats.pool_daylight(), false)
		strip.set_meta("pool_strip", true)
		var s2 = OmniLight3D.new()
		s2.light_color = warm
		s2.light_energy = 1.0
		s2.omni_range = 11.0
		s2.shadow_enabled = false
		s2.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.5, chunk.S / 2.0)
		chunk.add_child(s2)


## One abandoned float reads as a place people left; a dozen reads as a ball
## pit. Kept rare, and re-tinted per instance so the same ring is never
## obviously the same ring twice.
## A grid of piers. Offset so the rows never line up into a corridor, which is
## what turns an open hall into somewhere you lose track of yourself.


func _pool_piers(salt: int, count: int) -> Array[Vector3]:
	var placed = 0
	var positions: Array[Vector3] = []
	var has_portal = WorldGen.portal(chunk.wseed, chunk.cell, chunk.theme) >= 0
	var has_strip = chunk.style == WorldGen.POOL_DECK \
		or chunk.style == WorldGen.POOL_GALLERY or chunk.style == WorldGen.POOL_CHANNEL
	for i in 9:
		if placed >= count:
			return positions
		var gx = 2.4 + float(i % 3) * 3.6
		var gz = 2.4 + float(i / 3) * 3.6
		gx += (chunk._r(salt + i * 3) - 0.5) * 1.1
		gz += (chunk._r(salt + i * 3 + 1) - 0.5) * 1.1
		if chunk._r(salt + i * 3 + 2) > 0.72:
			continue
		# Nothing may grow through a pier: not the portal swirling at the
		# room centre, not the recessed ceiling light strip, not a cistern
		# skylight. Reject the grid slot rather than shuffle it, so the
		# survivors stay on the same irregular grid as everywhere else.
		if has_portal and Vector2(gx, gz).distance_to(
				Vector2(chunk.S / 2.0, chunk.S / 2.0)) < 2.4:
			continue
		if has_strip and absf(gx - chunk.S / 2.0) < 1.0:
			continue
		if chunk.style == WorldGen.POOL_CISTERN and absf(gz - chunk.S / 2.0) < 2.4:
			var near_sky = false
			for sx in [3.0, 6.0, 9.0]:
				if absf(gx - sx) < 1.5:
					near_sky = true
			if near_sky:
				continue
		var at := Vector3(gx, 0, gz)
		_pool_pier(at)
		positions.append(at)
		placed += 1
	return positions


## Occasionally turn a Basin corner into a quarter-round dry deck.  Requiring
## both adjacent boundaries to be real walls keeps the two omitted mesh end
## caps buried and makes the curve read as pool geometry rather than a loose
## platform floating in open water.
func _pool_rounded_basin_corner(salt: int) -> bool:
	if chunk._r(salt) >= 0.28:
		return false
	var candidates: Array[Dictionary] = [
		{"center": Vector2(0.0, 0.0), "start": Vector2(1.0, 0.0),
			"dirs": [1, 3], "id": 0},
		{"center": Vector2(chunk.S, 0.0), "start": Vector2(0.0, 1.0),
			"dirs": [0, 3], "id": 1},
		{"center": Vector2(chunk.S, chunk.S), "start": Vector2(-1.0, 0.0),
			"dirs": [0, 2], "id": 2},
		{"center": Vector2(0.0, chunk.S), "start": Vector2(0.0, -1.0),
			"dirs": [1, 2], "id": 3},
	]
	var eligible: Array[Dictionary] = []
	for candidate in candidates:
		var dirs: Array = candidate["dirs"]
		if bool(WorldGen.edge_info(
				chunk.wseed, chunk.cell, int(dirs[0]), chunk.theme)["wall"]) \
				and bool(WorldGen.edge_info(
				chunk.wseed, chunk.cell, int(dirs[1]), chunk.theme)["wall"]):
			eligible.append(candidate)
	if eligible.is_empty():
		return false
	var candidate: Dictionary = eligible[
		int(chunk._r(salt + 1) * float(eligible.size())) % eligible.size()]
	var radius := lerpf(2.35, 3.35, chunk._r(salt + 2))
	var center: Vector2 = candidate["center"]
	var radial_start: Vector2 = candidate["start"]
	var deck := MeshInstance3D.new()
	deck.mesh = PoolCornerMesh.quarter_sector(
		center, radial_start, PI * 0.5, radius,
		0.0, chunk.POOL_DECK_Y, chunk.POOL_CORNER_SEGMENTS)
	deck.material_override = Mats.pool_tile()
	deck.set_meta("pool_rounded_basin_corner", true)
	deck.set_meta("pool_rounded_basin_corner_id", int(candidate["id"]))
	deck.set_meta("pool_rounded_basin_corner_radius", radius)
	chunk.add_child(deck)
	_pool_sector_colliders(center, radial_start, PI * 0.5, radius,
		chunk.POOL_DECK_Y, "pool_rounded_basin_corner_collider")
	var coping := MeshInstance3D.new()
	coping.mesh = PoolCornerMesh.quarter_annulus(
		center, radial_start, PI * 0.5, radius - 0.18, radius + 0.02,
		chunk.POOL_DECK_Y, chunk.POOL_DECK_Y + 0.10,
		chunk.POOL_CORNER_SEGMENTS)
	coping.material_override = Mats.pool_coping()
	coping.set_meta("pool_rounded_basin_corner_coping", true)
	chunk.add_child(coping)
	return true


## Put a circular deck around an existing pier.  The water remains one
## continuous seam-free plane below it; the opaque deck hides that overlap.
func _pool_pier_island(salt: int, piers: Array[Vector3],
		side_dir: int, side_width: float, bridge_axis: int) -> bool:
	if piers.is_empty() or chunk._r(salt) >= 0.38:
		return false
	var eligible: Array[Vector3] = []
	# Test against the largest island we can subsequently choose.  Testing a
	# smaller per-pier radius and then rolling a larger final radius could let
	# the finished coping overlap a wall or walkway.
	var clearance_radius := 2.05
	for at in piers:
		if at.x - clearance_radius < 0.45 \
				or at.x + clearance_radius > chunk.S - 0.45 \
				or at.z - clearance_radius < 0.45 \
				or at.z + clearance_radius > chunk.S - 0.45:
			continue
		if not _pool_island_clear_of_layout(
				at, clearance_radius, side_dir, side_width, bridge_axis):
			continue
		eligible.append(at)
	if eligible.is_empty():
		return false
	var at: Vector3 = eligible[
		int(chunk._r(salt + 1) * float(eligible.size())) % eligible.size()]
	var radius := lerpf(1.65, 2.05, chunk._r(salt + 2))
	var island: MeshInstance3D = chunk._cyl(
		Vector3(at.x, chunk.POOL_DECK_Y * 0.5, at.z),
		radius, chunk.POOL_DECK_Y, Mats.pool_tile())
	island.set_meta("pool_rounded_pier_island", true)
	island.set_meta("pool_rounded_pier_island_radius", radius)
	island.set_meta("pool_rounded_pier_island_center", Vector2(at.x, at.z))
	for quarter in 4:
		var coping := MeshInstance3D.new()
		coping.mesh = PoolCornerMesh.quarter_annulus(
			Vector2(at.x, at.z), Vector2.RIGHT.rotated(float(quarter) * PI * 0.5),
			PI * 0.5, radius - 0.18, radius + 0.02,
			chunk.POOL_DECK_Y, chunk.POOL_DECK_Y + 0.10,
			chunk.POOL_CORNER_SEGMENTS)
		coping.material_override = Mats.pool_coping()
		coping.set_meta("pool_rounded_pier_island_coping", true)
		chunk.add_child(coping)
	return true


func _pool_island_clear_of_layout(at: Vector3, radius: float,
		side_dir: int, side_width: float, bridge_axis: int) -> bool:
	var gap := 0.32
	match side_dir:
		0:
			if at.x + radius + gap > chunk.S - side_width:
				return false
		1:
			if at.x - radius - gap < side_width:
				return false
		2:
			if at.z + radius + gap > chunk.S - side_width:
				return false
		3:
			if at.z - radius - gap < side_width:
				return false
	if bridge_axis == 1 and absf(at.z - chunk.S * 0.5) \
			< 1.05 + radius + gap:
		return false
	if bridge_axis == 0 and absf(at.x - chunk.S * 0.5) \
			< 1.05 + radius + gap:
		return false
	return true


func _pool_sector_colliders(center: Vector2, radial_start: Vector2,
		sweep: float, radius: float, height: float, meta_name: String) -> void:
	var start := radial_start.normalized()
	var center_bottom := Vector3(center.x, 0.0, center.y)
	var center_top := Vector3(center.x, height, center.y)
	for i in chunk.POOL_CORNER_SEGMENTS:
		var u0 := start.rotated(
			sweep * float(i) / float(chunk.POOL_CORNER_SEGMENTS))
		var u1 := start.rotated(
			sweep * float(i + 1) / float(chunk.POOL_CORNER_SEGMENTS))
		var arc0 := Vector3(
			center.x + u0.x * radius, 0.0,
			center.y + u0.y * radius)
		var arc1 := Vector3(
			center.x + u1.x * radius, 0.0,
			center.y + u1.y * radius)
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			center_bottom, arc0, arc1,
			center_top, arc0 + Vector3.UP * height, arc1 + Vector3.UP * height,
		])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.set_meta(meta_name, true)
		cs.set_meta("pool_rounded_basin_corner_sector", i)
		chunk.body.add_child(cs)


func _pool_float(salt: int) -> void:
	if _pool_dry() or chunk._r(salt) > 0.16:
		return
	var at = Vector3(lerpf(2.6, chunk.S - 2.6, chunk._r(salt + 1)), chunk.POOL_WATER_Y - 0.05,
		lerpf(2.6, chunk.S - 2.6, chunk._r(salt + 2)))
	if not chunk._floor_spot_clear(Vector3(at.x, 0.0, at.z), 0.6, 0.4):
		return
	var pivot = chunk._furnishing_pivot(at, chunk._r(salt + 3) * TAU, "pool_float", false)
	var inst = chunk._attributed_prop_local(pivot, chunk.POOL_BUOY_PATH, Vector3.ZERO, 0.0,
		Vector3.ONE * 0.55)
	if inst == null:
		return
	var tint: Color = chunk.POOL_BUOY_TINTS[
		WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 7) % chunk.POOL_BUOY_TINTS.size()]
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi = node as MeshInstance3D
		var m = StandardMaterial3D.new()
		m.albedo_color = tint
		m.roughness = 0.34
		mi.material_override = m
	inst.set_meta("pool_float_tint", tint)


## Handrail along a dry edge — the detail that most says "municipal pool".


func _pool_handrail(dir: int, inset: float) -> void:
	var rail = Mats.pool_rail()
	var pivot = Node3D.new()
	var base = chunk.POOL_DRY_Y if _pool_dry() else 0.0
	if dir < 2:
		pivot.position = Vector3((chunk.S - inset) if dir == 0 else inset, base, chunk.S / 2.0)
	else:
		pivot.position = Vector3(chunk.S / 2.0, base, (chunk.S - inset) if dir == 2 else inset)
	pivot.rotation.y = 0.0 if dir < 2 else PI / 2.0
	pivot.set_meta("pool_handrail", true)
	chunk.add_child(pivot)
	var span = chunk.S - 1.6
	var top = chunk._mcyl(pivot, Vector3(0, 0.92, 0), 0.026, span, rail)
	top.rotation.x = PI / 2.0
	for i in 4:
		var z = -span * 0.5 + span * (float(i) / 3.0)
		chunk._mcyl(pivot, Vector3(0, 0.46, z), 0.024, 0.92, rail)


## A dry walkway along one wall of a flooded room, standing at the same height
## as the dry halls, with a ladder down into the water. This is what stops the
## floor being all-or-nothing: most pools should have an edge you can walk.


func _pool_side_walk(dir: int, width: float) -> void:
	var pos: Vector3
	var size: Vector3
	var half = width * 0.5
	match dir:
		0:
			pos = Vector3(chunk.S - half, chunk.POOL_DRY_Y * 0.5, chunk.S / 2.0)
			size = Vector3(width, chunk.POOL_DRY_Y, chunk.S)
		1:
			pos = Vector3(half, chunk.POOL_DRY_Y * 0.5, chunk.S / 2.0)
			size = Vector3(width, chunk.POOL_DRY_Y, chunk.S)
		2:
			pos = Vector3(chunk.S / 2.0, chunk.POOL_DRY_Y * 0.5, chunk.S - half)
			size = Vector3(chunk.S, chunk.POOL_DRY_Y, width)
		_:
			pos = Vector3(chunk.S / 2.0, chunk.POOL_DRY_Y * 0.5, half)
			size = Vector3(chunk.S, chunk.POOL_DRY_Y, width)
	var walk = chunk._box(pos, size, Mats.pool_tile())
	walk.set_meta("pool_side_walk", true)
	# The ladder hangs off its inner edge, over the water it serves.
	var inner: float = (chunk.S - width) if dir == 0 else (width if dir == 1 else 0.0)
	if dir >= 2:
		inner = (chunk.S - width) if dir == 2 else width
	_pool_ledge_ladder(dir, inner, chunk.S * 0.28 + (chunk._r(2500 + dir) - 0.5) * 1.6)
	_pool_ledge_ladder(dir, inner, chunk.S * 0.72 + (chunk._r(2504 + dir) - 0.5) * 1.6)


## A narrow raised causeway straight across a flooded room.


func _pool_bridge(along_x: bool) -> void:
	var w = 2.1
	var pos = Vector3(chunk.S / 2.0, chunk.POOL_DRY_Y * 0.5, chunk.S / 2.0)
	var size = Vector3(chunk.S, chunk.POOL_DRY_Y, w) if along_x \
		else Vector3(w, chunk.POOL_DRY_Y, chunk.S)
	var deck = chunk._box(pos, size, Mats.pool_tile())
	deck.set_meta("pool_bridge", true)
	if along_x:
		_pool_ledge_ladder(3, (chunk.S + w) * 0.5, lerpf(3.0, chunk.S - 3.0, chunk._r(2510)))
		_pool_ledge_ladder(2, (chunk.S - w) * 0.5, lerpf(3.0, chunk.S - 3.0, chunk._r(2511)))
	else:
		_pool_ledge_ladder(1, (chunk.S + w) * 0.5, lerpf(3.0, chunk.S - 3.0, chunk._r(2510)))
		_pool_ledge_ladder(0, (chunk.S - w) * 0.5, lerpf(3.0, chunk.S - 3.0, chunk._r(2511)))


## A real pool ladder: two uprights from the basin floor, rungs at and below
## the lip, and — the part that was missing — grab rails that bend over the
## edge and run back across the deck. Without that top return it is two bare
## posts standing in the water with its rungs hidden under the surface.


func _pool_ladder_at(dir: int, edge: float, along: float, inward: float,
		site = "wall") -> void:
	along = clampf(along, 1.1, chunk.S - 1.1)
	# Placement computed from the model's measured anatomy, not guessed. In its
	# own space: the deck flanges sit at y ≈ 0 and z ≈ 0, the grab rails arch
	# to +0.79 ABOVE that plane, and the treads hang to −0.46 BELOW it at
	# z 0.47–0.58. So y = 0 is the DECK PLANE and +Z is the WATER direction.
	# Seating it is therefore exact: origin a hand's width onto the dry side of
	# the lip, raised to POOL_DRY_Y, +Z yawed toward the water. The flanges
	# land on tile, the rails stand over the deck, and the treads overhang the
	# edge and descend through the waterline — the reference photo, verbatim.
	var setback = 0.15
	var pivot = Node3D.new()
	var off = inward * setback
	match dir:
		0: pivot.position = Vector3(edge + off, 0.0, along)
		1: pivot.position = Vector3(edge + off, 0.0, along)
		2: pivot.position = Vector3(along, 0.0, edge + off)
		_: pivot.position = Vector3(along, 0.0, edge + off)
	pivot.rotation.y = 0.0 if dir < 2 else PI / 2.0
	pivot.set_meta("pool_ladder", true)
	pivot.set_meta("pool_ladder_site", site)
	chunk.add_child(pivot)
	# Water direction along the working axis is -inward; the pivot's own PI/2
	# for dir >= 2 flips the sense, hence the sign split.
	var model_yaw = (-inward if dir < 2 else inward) * PI / 2.0
	var inst = chunk._attributed_prop_local(pivot, chunk.POOL_LADDER_PATH,
		Vector3(0.0, chunk.POOL_DRY_Y, 0.0), model_yaw,
		Vector3.ONE * chunk.POOL_LADDER_SCALE)
	if inst != null:
		inst.set_meta("pool_ladder_model", true)
	var area = Area3D.new()
	area.position = Vector3(0, 0.9, 0)
	area.set_meta("pool_ladder_volume", true)
	area.collision_layer = Player.LADDER_LAYER
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.6, 3.0, chunk.POOL_LADDER_W + 1.1)
	cs.shape = box
	area.add_child(cs)
	pivot.add_child(area)


func _pool_ledge_ladder(dir: int, edge: float, along: float) -> void:
	_pool_ladder_at(dir, edge, along,
		1.0 if (dir == 0 or dir == 2) else -1.0, "ledge")


func _pool_basin_room() -> void:
	_pool_underwater_lights(2390)
	# Most pools have an edge. Only a minority are wall-to-wall water.
	var roll = chunk._r(2380)
	var side_dir := -1
	var side_width := 0.0
	var bridge_axis := -1
	if roll < 0.46:
		side_dir = int(chunk._r(2381) * 3.99)
		side_width = lerpf(2.2, 3.2, chunk._r(2382))
		_pool_side_walk(side_dir, side_width)
	elif roll < 0.64:
		var along_x: bool = chunk._r(2383) < 0.5
		bridge_axis = 1 if along_x else 0
		_pool_bridge(along_x)
	var rounded_corner := false
	if roll >= 0.64:
		rounded_corner = _pool_rounded_basin_corner(2384)
	var piers := _pool_piers(2300, 3 + int(chunk._r(2301) * 2.99))
	if not rounded_corner:
		_pool_pier_island(2388, piers, side_dir, side_width, bridge_axis)
	if chunk._r(2302) < 0.42:
		_pool_window(0 if chunk._r(2303) < 0.5 else 1, lerpf(3.0, chunk.S - 3.0, chunk._r(2304)))
	_pool_float(2305)


func _pool_channel_room() -> void:
	# A swimming lane: walled either side of the through axis, with both ends
	# open so the water keeps running out of sight. Each flank is one solid
	# mass from the cell boundary to the lane edge — the freestanding slabs
	# this replaces floated a metre inside the cell, leaving a walled-off
	# trench of dead water that every doorway on that side faithfully dropped
	# its treads and ladder into.
	var axis = WorldGen.corridor(chunk.wseed, chunk.cell)
	var along_x = axis == 1
	# A towpath down one side of the lane, so a channel is swimmable or
	# walkable rather than forcing you into the water every time.
	var towpath = chunk._r(2313) < 0.5
	# Windows only exist in the taller halls (see _pool_window); a lane
	# that never qualifies must not carve the alcove that would lead to one.
	var window = chunk._r(2310) < 0.34 and chunk.ceil_h >= 5.0
	var win_at = lerpf(3.5, chunk.S - 3.5, chunk._r(2311))
	for side in 2:
		var dir_side: int
		if along_x:
			dir_side = 3 if side == 0 else 2
		else:
			dir_side = 1 if side == 0 else 0
		if towpath and side == 0:
			continue  # the deck takes this flank; the lane widens to meet it
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, dir_side, chunk.theme)
		var cuts: Array = []
		if not bool(info["wall"]):
			if bool(info["full_open"]):
				continue  # the lane lies open to the neighbour
			cuts.append([float(info["t"]) - float(info["w"]) / 2.0,
				float(info["t"]) + float(info["w"]) / 2.0])
		elif window and side == 1:
			# The pill window sits on the boundary wall, so the mass in front
			# of it becomes a deep tiled alcove ending in the glowing pane.
			cuts.append([win_at - 0.85, win_at + 0.85])
		# A doorway on an END of the lane can sit across this flank's strip.
		# Left alone, that door opens straight into the solid mass — with its
		# treads and ladder mounted flat against the tile. Pull the mass back
		# from that end so the door gets an open pocket around into the lane.
		var a0 = 0.0
		var a1 = chunk.S
		var strip0 = chunk.T if side == 0 else chunk.S - chunk.POOL_LANE
		var strip1 = chunk.POOL_LANE if side == 0 else chunk.S - chunk.T
		for end_dir in ([1, 0] if along_x else [3, 2]):
			var einfo = WorldGen.edge_info(chunk.wseed, chunk.cell, end_dir, chunk.theme)
			if bool(einfo["wall"]) or bool(einfo["full_open"]):
				continue
			var lo = float(einfo["t"]) - float(einfo["w"]) / 2.0
			var hi = float(einfo["t"]) + float(einfo["w"]) / 2.0
			if hi < strip0 or lo > strip1:
				continue
			if end_dir == 1 or end_dir == 3:
				a0 = maxf(a0, 2.0)
			else:
				a1 = minf(a1, chunk.S - 2.0)
		_pool_channel_fill(dir_side, cuts, a0, a1)
	if window:
		_pool_window(2 if along_x else 0, win_at, false)
	if towpath:
		_pool_side_walk(3 if along_x else 1, 2.0)
	_pool_float(2312)


## One flank of the lane, solid from just inside the cell boundary to the
## lane edge, with `cuts` carving full-height passages through the mass where
## a doorway or window alcove needs to reach the water.


func _pool_channel_fill(dir: int, cuts: Array, a0 = 0.0, a1 = chunk.S) -> void:
	var near = dir == 1 or dir == 3
	var d0 = chunk.T if near else chunk.S - chunk.POOL_LANE
	var d1 = chunk.POOL_LANE if near else chunk.S - chunk.T
	var spans: Array = []
	var at = a0
	for cut in cuts:
		spans.append([at, clampf(float(cut[0]), a0, a1)])
		at = clampf(float(cut[1]), a0, a1)
	spans.append([at, a1])
	var dc = (d0 + d1) * 0.5
	# Plain square masses: every span is one box with 90-degree ends, at the
	# boundary or at a doorway cut alike. End fillets were tried and
	# reverted with the rest of the corner rounding.
	var mat = Mats.pool_wall_tile()
	for span in spans:
		var a = float(span[0])
		var b = float(span[1])
		if b - a < 0.05:
			continue
		var c = (a + b) * 0.5
		var f = chunk._box(
			Vector3(dc, chunk.ceil_h * 0.5, c) if dir < 2 \
				else Vector3(c, chunk.ceil_h * 0.5, dc),
			Vector3(d1 - d0, chunk.ceil_h, b - a) if dir < 2 \
				else Vector3(b - a, chunk.ceil_h, d1 - d0),
			mat)
		f.set_meta("pool_channel_side", true)


func _pool_deck_room() -> void:
	# Dry. Tiled floor to tiled wall, a few structural piers and the light.
	var dir = int(chunk._r(2320) * 3.99)
	_pool_piers(2322, 2 + int(chunk._r(2323) * 1.99))
	if chunk._r(2324) < 0.6:
		_pool_window(dir, lerpf(3.0, chunk.S - 3.0, chunk._r(2325)))
	if chunk._r(2410) < 0.18:
		_pool_lone_chair(2411)


func _pool_solarium_room() -> void:
	# The room the light comes into: a wall of tall windows and almost nothing
	# else, so the shafts have the whole space to fall through.
	var dir = int(chunk._r(2330) * 3.99)
	for i in 3:
		_pool_window(dir, 2.6 + float(i) * 3.4)
	_pool_piers(2331, 2)


## One white plastic chair, alone, facing nowhere in particular.


func _pool_lone_chair(salt: int) -> void:
	if chunk._r(salt) > 0.6:
		return
	var at = Vector3(chunk.S / 2.0 + (chunk._r(salt + 1) - 0.5) * 3.0, chunk.POOL_DRY_Y,
		chunk.S / 2.0 + (chunk._r(salt + 2) - 0.5) * 3.0)
	# The chair must not stand inside a pier or any other solid; alone means
	# alone in open floor, and it is rare enough to simply not appear here.
	if not chunk._floor_spot_clear(Vector3(at.x, chunk.POOL_DRY_Y, at.z), 0.55, 0.9):
		return
	var pivot = chunk._furnishing_pivot(at, chunk._r(salt + 3) * TAU, "pool_chair")
	var inst = chunk._attributed_prop_local(pivot, chunk.POOL_CHAIR_PATH,
		-chunk.POOL_CHAIR_CENTRE, 0.0)
	if inst == null:
		return
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name != chunk.POOL_CHAIR_MESH:
			(mi as MeshInstance3D).visible = false
	chunk._collider_yaw_box(at + Vector3(0, 0.44, 0),
		Vector3(0.66, 0.88, 0.66), pivot.rotation.y)


## Submerged wall units. Each is a real LED disc half-proud of the tile below
## the waterline, with an actual light pushed out into the water in front of
## it, so a flooded hall gets the up-glow the reference pools all have.


func _pool_underwater_lights(salt: int) -> void:
	var built = 0
	for dir in 4:
		if built >= 2:
			return
		if not bool(WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]):
			continue
		if chunk._r(salt + dir) > 0.55:
			continue
		var along = lerpf(2.5, chunk.S - 2.5, chunk._r(salt + 10 + dir))
		var face = (chunk.S - chunk.T) if (dir == 0 or dir == 2) else chunk.T
		var pivot = Node3D.new()
		var room_dir = Vector3.ZERO
		match dir:
			0:
				pivot.position = Vector3(face, 0.55, along)
				pivot.rotation.y = -PI / 2.0
				room_dir = Vector3(-1, 0, 0)
			1:
				pivot.position = Vector3(face, 0.55, along)
				pivot.rotation.y = PI / 2.0
				room_dir = Vector3(1, 0, 0)
			2:
				pivot.position = Vector3(along, 0.55, face)
				pivot.rotation.y = PI
				room_dir = Vector3(0, 0, -1)
			_:
				pivot.position = Vector3(along, 0.55, face)
				room_dir = Vector3(0, 0, 1)
		pivot.set_meta("pool_underwater_light", true)
		chunk.add_child(pivot)
		var inst = chunk._attributed_prop_local(pivot, chunk.POOL_LIGHT_PATH,
			Vector3.ZERO, 0.0, Vector3.ONE * chunk.POOL_LIGHT_SCALE)
		if inst == null:
			pivot.queue_free()
			return
		# The glb is authored OBLIQUE: in model space the disc's outward
		# normal is (0.648, 0.297, 0.701) and its back plate centre sits at
		# (1.329, 0.610, 1.437) — nowhere near the origin. Mounted raw it
		# floated off the wall at a skew angle. Counter-rotate the normal
		# onto pivot +Z (the room direction) and pull the rotated back
		# plate onto the pivot origin, 3mm embedded so it cannot show a gap.
		var q = Quaternion(
			Vector3(0.648259, 0.297395, 0.70094).normalized(), Vector3(0, 0, 1))
		inst.quaternion = q
		inst.position = -(q * Vector3(1.328672, 0.60954, 1.436646)) \
			* chunk.POOL_LIGHT_SCALE
		inst.position.z -= 0.003
		var lamp = OmniLight3D.new()
		lamp.light_color = Color(0.72, 0.90, 0.98)
		lamp.light_energy = 1.5
		lamp.omni_range = 4.2
		lamp.shadow_enabled = false
		lamp.position = pivot.position + room_dir * 0.45
		chunk.add_child(lamp)
		built += 1


func _pool_alcove_room() -> void:
	# No windows at all. Still, dim, and coved to a tiled tank — and sometimes
	# furnished with exactly one white plastic chair, which is the image.
	_pool_piers(2340, 1 + int(chunk._r(2341) * 1.99))
	_pool_lone_chair(2345)


func _pool_stairs_room() -> void:
	_pool_underwater_lights(2391)
	# The stair is "the calmest way in", so it should actually BE a way in:
	# prefer the wall whose edge opens onto a dry hall, and centre the run on
	# that doorway, so climbing it delivers you through the door onto dry
	# tile. Only when no dry neighbour exists does the rolled wall stand.
	var dir = _pool_stairs_exit(chunk.cell)
	var at = chunk.S / 2.0
	if dir < 0:
		dir = int(chunk._r(2350) * 3.99)
	else:
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)
		if not bool(info["full_open"]):
			at = clampf(float(info["t"]), 2.65, chunk.S - 2.65)
	_pool_stairs(dir, at)
	if chunk._r(2354) < 0.5:
		_pool_side_walk((dir + 2) % 4, 2.2)
	if chunk._r(2351) < 0.45:
		_pool_window((dir + 2) % 4, lerpf(3.0, chunk.S - 3.0, chunk._r(2352)))
	_pool_float(2353)


func _pool_gallery_room() -> void:
	var dir = int(chunk._r(2360) * 3.99)
	_pool_handrail(dir, 1.5)
	_pool_piers(2361, 3 + int(chunk._r(2362) * 2.99))
	if chunk._r(2363) < 0.5:
		_pool_window((dir + 2) % 4, lerpf(3.0, chunk.S - 3.0, chunk._r(2364)))


func _pool_cistern_room() -> void:
	# The landmark: a wide dim hall of piers lit only from high skylights, so
	# the far end of the water is never quite resolvable.
	_pool_underwater_lights(2392)
	_pool_piers(2370, 7)
	for i in 3:
		var sky = chunk._box(Vector3(3.0 + float(i) * 3.0, chunk.ceil_h - 0.05, chunk.S * 0.5),
			Vector3(1.5, 0.08, 3.4), Mats.pool_daylight(), false)
		sky.set_meta("pool_skylight", true)
		var lamp = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.98, 0.92)
		lamp.light_energy = 1.4
		lamp.omni_range = 12.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(3.0 + float(i) * 3.0, chunk.ceil_h - 1.2, chunk.S * 0.5)
		chunk.add_child(lamp)
	_pool_float(2371)
