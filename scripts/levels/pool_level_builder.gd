extends "res://scripts/levels/chunk_level_builder.gd"


## Pool Rooms still use the world's 12 m structural grid, but water no longer
## inherits that grid size. Most wet cells contain one compact basin with a
## real tiled deck around it. Channels deliberately reach cell boundaries, and
## nearby basins can meet those channels so the level has occasional connected
## water routes instead of a collection of entirely isolated tubs.

# Proper cast-stone pool coping: most of the 120mm profile is recessed into the
# deck, while a 25mm crown and rounded water-side nose remain visible. The
# 8mm joints divide long runs into the individual slabs seen in real pools.
const POOL_COPING_WIDTH := 0.34
const POOL_COPING_HEIGHT := 0.12
const POOL_COPING_TOP_OFFSET := 0.025
const POOL_COPING_WATER_OVERHANG := 0.055
const POOL_COPING_DECK_SHIFT := \
	POOL_COPING_WIDTH * 0.5 - POOL_COPING_WATER_OVERHANG
const POOL_COPING_SLAB_LENGTH := 0.82
const POOL_COPING_JOINT_GAP := 0.008
const POOL_COPING_NOSE_SEGMENTS := 10
const POOL_SQUARE_COPING_CORNER_RADIUS := 0.30
# The compact-to-channel edge changes width across a cell seam. Give that
# change enough horizontal run for a genuinely smooth S bend; the old 46cm
# pair of quarter-circles forced the 34cm coping profile through an almost
# zero-length throat, where its deck-side edge folded into a visible stub.
const POOL_CONNECTED_COPING_MIN_RUN := 0.55
const POOL_CONNECTED_COPING_MAX_RUN := 0.62
# All channel cells share one centred lane section. Per-cell width rolls made
# a long rectangular pool change width abruptly at every 12 m chunk seam.
const POOL_CHANNEL_WIDTH := 3.65
# A channel opening onto a dry hall terminates inside its own wet room instead
# of running into the doorway's wall returns. The 60cm tiled landing is about
# two feet deep: enough to separate coping, ladder and dry-room architecture.
const POOL_DRY_BOUNDARY_SETBACK := 0.60
# The imported Bath mesh measures 2.655 x 2.088 m after scaling. Its authored
# origin includes a separate step at one end, so the bath itself is offset
# 0.326 m toward local -Z. The structural opening is smaller than the outer
# shell. The deck cut now follows just inside that shell instead of stopping
# under the inner rim, so tile cannot bleed through the molded recesses.
const POOL_JACUZZI_DECK_CUTOUT_SIZE := Vector2(2.60, 2.03)
const POOL_JACUZZI_DECK_CUTOUT_RADIUS := 0.31
const POOL_JACUZZI_CENTRE_OFFSET := Vector2(0.0, -0.326)
const POOL_JACUZZI_SINK := 1.015
const POOL_JACUZZI_DECK_REVEAL := 0.06
const POOL_JACUZZI_WATER_SIZE := Vector2(2.32, 1.72)
const POOL_JACUZZI_EXIT_SIZE := Vector2(2.32, 1.72)
const POOL_JACUZZI_WATER_INSET := 0.12


func _pool_style_dry_local(pool_style: int) -> bool:
	# Keep the level builder in lockstep with world generation. Reclassifying
	# a style here makes its visuals disagree with floor height, portals,
	# spawning, and cross-cell traversal calculated elsewhere.
	return chunk.pool_style_dry(pool_style)


func _pool_channel_axis_x(_c: Vector2i) -> bool:
	# A channel is a building-scale pool system, not a per-room corridor roll.
	# Letting neighboring cells independently choose X or Z made a narrow lane
	# meet the full 12m side of a perpendicular lane. Keep every channel on the
	# floor aligned so multi-cell rectangles remain one continuous basin.
	return true


func _pool_water_layout_for(c: Vector2i, pool_style: int) -> Dictionary:
	var size := Vector2(6.0, 6.0)
	var center := Vector2(chunk.S * 0.5, chunk.S * 0.5)
	var connected := false
	var axis_x := true
	var edge_links: Array[int] = []
	var rounded_corner := -1
	var corner_radius := 0.0
	if pool_style == WorldGen.POOL_CHANNEL:
		axis_x = _pool_channel_axis_x(c)
		var x0 := 0.0
		var x1 := chunk.S
		var z0 := 0.0
		var z1 := chunk.S
		var channel_dirs := [0, 1] if axis_x else [2, 3]
		for dir in channel_dirs:
			var info := chunk._edge_info(c, dir)
			if bool(info["wall"]):
				continue
			if _pool_open_dry_boundary(c, dir):
				match dir:
					0:
						x1 -= POOL_DRY_BOUNDARY_SETBACK
					1:
						x0 += POOL_DRY_BOUNDARY_SETBACK
					2:
						z1 -= POOL_DRY_BOUNDARY_SETBACK
					3:
						z0 += POOL_DRY_BOUNDARY_SETBACK
				continue
			edge_links.append(dir)
		size = Vector2(x1 - x0, POOL_CHANNEL_WIDTH) if axis_x \
			else Vector2(POOL_CHANNEL_WIDTH, z1 - z0)
		center = Vector2((x0 + x1) * 0.5, chunk.S * 0.5) if axis_x \
			else Vector2(chunk.S * 0.5, (z0 + z1) * 0.5)
		# A lane sealed at both ends (walls or dry thresholds) is a compact
		# body of water, whatever its shape. Claiming `connected` with no
		# edge links lied to everything that reads the metadata.
		connected = not edge_links.is_empty()
	else:
		match pool_style:
			WorldGen.POOL_STAIRS:
				size = Vector2(
					lerpf(5.6, 6.8, WorldGen.r01(chunk.wseed, c.x, c.y, 2212)),
					lerpf(5.2, 6.5, WorldGen.r01(chunk.wseed, c.x, c.y, 2213)))
			WorldGen.POOL_CISTERN:
				size = Vector2(
					lerpf(6.2, 7.4, WorldGen.r01(chunk.wseed, c.x, c.y, 2214)),
					lerpf(6.2, 7.4, WorldGen.r01(chunk.wseed, c.x, c.y, 2215)))
			_:
				size = Vector2(
					lerpf(5.0, 6.5, WorldGen.r01(chunk.wseed, c.x, c.y, 2216)),
					lerpf(5.0, 6.5, WorldGen.r01(chunk.wseed, c.x, c.y, 2217)))
		center += Vector2(
			(WorldGen.r01(chunk.wseed, c.x, c.y, 2218) - 0.5) * 1.25,
			(WorldGen.r01(chunk.wseed, c.x, c.y, 2219) - 0.5) * 1.25)
		var margin := 1.55
		center.x = clampf(center.x, size.x * 0.5 + margin,
			chunk.S - size.x * 0.5 - margin)
		center.y = clampf(center.y, size.y * 0.5 + margin,
			chunk.S - size.y * 0.5 - margin)
		# A compact basin bordering a channel can open into it. We only link
		# along the channel's own axis, so both water surfaces overlap at the
		# shared doorway without recursively asking the neighbour for a layout.
		for dir in 4:
			var info := chunk._edge_info(c, dir)
			if bool(info["wall"]):
				continue
			var nb: Vector2i = c + Vector2i(WorldGen.DIRV[dir])
			var nb_style := WorldGen.cell_style(
				chunk.wseed, nb, chunk.theme)
			if nb_style != WorldGen.POOL_CHANNEL:
				continue
			var nb_axis_x := _pool_channel_axis_x(nb)
			if (dir < 2 and nb_axis_x) or (dir >= 2 and not nb_axis_x):
				edge_links.append(dir)
		if not edge_links.is_empty():
			axis_x = edge_links[0] < 2
			# A rectangular compact basin may join opposite sides on one axis,
			# but never expand across both axes into another full-cell pool.
			for i in range(edge_links.size() - 1, -1, -1):
				if (edge_links[i] < 2) != axis_x:
					edge_links.remove_at(i)
			var x0 := center.x - size.x * 0.5
			var x1 := center.x + size.x * 0.5
			var z0 := center.y - size.y * 0.5
			var z1 := center.y + size.y * 0.5
			for dir in edge_links:
				match dir:
					0:
						x1 = chunk.S
					1:
						x0 = 0.0
					2:
						z1 = chunk.S
					3:
						z0 = 0.0
			center = Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			size = Vector2(x1 - x0, z1 - z0)
			connected = true
		var round_chance := 0.52
		if pool_style == WorldGen.POOL_BASIN:
			round_chance = 0.68
		elif pool_style == WorldGen.POOL_CISTERN:
			round_chance = 0.58
		elif pool_style == WorldGen.POOL_STAIRS:
			round_chance = 0.48
		if not connected \
				and WorldGen.r01(chunk.wseed, c.x, c.y, 2220) < round_chance:
			rounded_corner = int(
				WorldGen.r01(chunk.wseed, c.x, c.y, 2221) * 4.0) % 4
			corner_radius = lerpf(
				1.05, 1.45, WorldGen.r01(chunk.wseed, c.x, c.y, 2222))
	return {
		"center": center,
		"size": size,
		"connected": connected,
		"axis_x": axis_x,
		"edge_links": edge_links,
		"rounded_corner": rounded_corner,
		"corner_radius": corner_radius,
	}


func _pool_water_layout() -> Dictionary:
	return _pool_water_layout_for(chunk.cell, chunk.style)


func _pool_water_reaches_edge(c: Vector2i, pool_style: int, dir: int) -> bool:
	var layout := _pool_water_layout_for(c, pool_style)
	var links: Array = layout.get("edge_links", [])
	return links.has(dir)


func _pool_water_span_at_edge(
		c: Vector2i, pool_style: int, dir: int) -> Vector2:
	var layout := _pool_water_layout_for(c, pool_style)
	var links: Array = layout.get("edge_links", [])
	if not links.has(dir):
		return Vector2(INF, -INF)
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	if dir < 2:
		return Vector2(center.y - size.y * 0.5, center.y + size.y * 0.5)
	return Vector2(center.x - size.x * 0.5, center.x + size.x * 0.5)


func _pool_open_dry_boundary(c: Vector2i, dir: int) -> bool:
	var info := chunk._edge_info(c, dir)
	if bool(info["wall"]):
		return false
	var nb := c + Vector2i(WorldGen.DIRV[dir])
	return _pool_style_dry_local(
		WorldGen.cell_style(chunk.wseed, nb, chunk.theme))


func _pool_boundary_needs_coping(dir: int) -> bool:
	return _pool_open_dry_boundary(chunk.cell, dir)


func _pool_connection_runs(
		c: Vector2i, pool_style: int, dir: int) -> Vector2:
	if dir >= 2:
		return Vector2.ZERO
	var nb := c + Vector2i(WorldGen.DIRV[dir])
	var nb_style := WorldGen.cell_style(chunk.wseed, nb, chunk.theme)
	if _pool_style_dry_local(nb_style) \
			or (pool_style == WorldGen.POOL_CHANNEL) \
				== (nb_style == WorldGen.POOL_CHANNEL):
		return Vector2.ZERO
	var span := _pool_water_span_at_edge(c, pool_style, dir)
	var nb_span := _pool_water_span_at_edge(
		nb, nb_style, WorldGen.OPP[dir])
	if not is_finite(span.x) or not is_finite(nb_span.x):
		return Vector2.ZERO
	var low_gap := absf(span.x - nb_span.x)
	var high_gap := absf(span.y - nb_span.y)
	return Vector2(
		minf(POOL_CONNECTED_COPING_MAX_RUN,
			maxf(POOL_CONNECTED_COPING_MIN_RUN, low_gap * 0.90))
			if low_gap > 0.18 else 0.0,
		minf(POOL_CONNECTED_COPING_MAX_RUN,
			maxf(POOL_CONNECTED_COPING_MIN_RUN, high_gap * 0.90))
			if high_gap > 0.18 else 0.0)


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
	var layout := _pool_water_layout()
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	_pool_basin_deck_and_coping(layout)
	# The surface itself carries no collider: you wade through it, and the
	# basin floor underneath is what holds you up.
	# A subdivided plane, never a box. A box showed its side faces at every
	# chunk join — those were the black seams — and having no interior vertices
	# it left the vertex swell with nothing to displace, so the surface read
	# dead flat.
	#
	# It is exactly the compact basin footprint. Channels can meet at their
	# ends; ordinary basins leave dry thresholds on all four sides.
	var surf = PlaneMesh.new()
	surf.size = size
	surf.subdivide_width = maxi(12, int(size.x * 2.4))
	surf.subdivide_depth = maxi(12, int(size.y * 2.4))
	var water = MeshInstance3D.new()
	water.mesh = surf
	water.material_override = Mats.pool_water()
	water.position = Vector3(center.x, chunk.POOL_WATER_Y, center.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("pool_water_surface", true)
	water.set_meta("pool_water_size", size)
	water.set_meta("pool_water_center", center)
	water.set_meta("pool_water_connected", bool(layout["connected"]))
	water.set_meta("pool_water_edge_links", layout.get("edge_links", []))
	water.set_meta("pool_water_style", chunk.style)
	chunk.add_child(water)
	# Every generated basin gets exactly one usable exit. Room decoration no
	# longer decides whether the player is allowed to climb out.
	_pool_compact_ladder(2240)
	_pool_edge_steps()


func _pool_basin_deck_and_coping(layout: Dictionary) -> void:
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var x0 := center.x - size.x * 0.5
	var x1 := center.x + size.x * 0.5
	var z0 := center.y - size.y * 0.5
	var z1 := center.y + size.y * 0.5
	_pool_deck_piece(Vector2(x0 * 0.5, chunk.S * 0.5),
		Vector2(x0, chunk.S))
	_pool_deck_piece(Vector2((x1 + chunk.S) * 0.5, chunk.S * 0.5),
		Vector2(chunk.S - x1, chunk.S))
	_pool_deck_piece(Vector2(center.x, z0 * 0.5),
		Vector2(size.x, z0))
	_pool_deck_piece(Vector2(center.x, (z1 + chunk.S) * 0.5),
		Vector2(size.x, chunk.S - z1))
	var rounded_corner := int(layout.get("rounded_corner", -1))
	var radius := float(layout.get("corner_radius", 0.0))
	# A water edge on a chunk boundary is open only when the next chunk is wet.
	# Against a dry room it is still a real pool lip and needs coping under its
	# ladder/steps. This distinction was previously lost at every cell edge.
	var has_left := x0 > 0.05 or _pool_boundary_needs_coping(1)
	var has_right := x1 < chunk.S - 0.05 or _pool_boundary_needs_coping(0)
	var has_north := z0 > 0.05 or _pool_boundary_needs_coping(3)
	var has_south := z1 < chunk.S - 0.05 or _pool_boundary_needs_coping(2)
	var left_z0 := z0 + (
		radius if rounded_corner == 0 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_north else 0.0))
	var left_z1 := z1 - (
		radius if rounded_corner == 3 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_south else 0.0))
	var right_z0 := z0 + (
		radius if rounded_corner == 1 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_north else 0.0))
	var right_z1 := z1 - (
		radius if rounded_corner == 2 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_south else 0.0))
	var north_x0 := x0 + (
		radius if rounded_corner == 0 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_left else 0.0))
	var north_x1 := x1 - (
		radius if rounded_corner == 1 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_right else 0.0))
	var south_x0 := x0 + (
		radius if rounded_corner == 3 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_left else 0.0))
	var south_x1 := x1 - (
		radius if rounded_corner == 2 else (
			POOL_SQUARE_COPING_CORNER_RADIUS if has_right else 0.0))
	var left_connection := _pool_connection_runs(
		chunk.cell, chunk.style, 1)
	var right_connection := _pool_connection_runs(
		chunk.cell, chunk.style, 0)
	north_x0 += left_connection.x
	south_x0 += left_connection.y
	north_x1 -= right_connection.x
	south_x1 -= right_connection.y
	if has_left:
		_pool_vertical_coping(
			x0, left_z0, left_z1, Vector2(1.0, 0.0))
	if has_right:
		_pool_vertical_coping(
			x1, right_z0, right_z1, Vector2(-1.0, 0.0))
	if has_north:
		_pool_horizontal_coping(
			z0, north_x0, north_x1, Vector2(0.0, 1.0))
	if has_south:
		_pool_horizontal_coping(
			z1, south_x0, south_x1, Vector2(0.0, -1.0))
	if rounded_corner != 0 and has_left and has_north:
		_pool_square_coping_corner_arc(Vector2(x0, z0), 0)
	if rounded_corner != 1 and has_right and has_north:
		_pool_square_coping_corner_arc(Vector2(x1, z0), 1)
	if rounded_corner != 2 and has_right and has_south:
		_pool_square_coping_corner_arc(Vector2(x1, z1), 2)
	if rounded_corner != 3 and has_left and has_south:
		_pool_square_coping_corner_arc(Vector2(x0, z1), 3)
	if rounded_corner >= 0:
		_pool_compact_rounded_basin_corner(layout)
	if chunk.style != WorldGen.POOL_CHANNEL:
		for dir_value in layout.get("edge_links", []):
			var dir := int(dir_value)
			if dir < 2:
				_pool_connected_coping_transition(layout, dir)


func _pool_connected_coping_transition(
		layout: Dictionary, dir: int) -> void:
	var nb := chunk.cell + Vector2i(WorldGen.DIRV[dir])
	if WorldGen.cell_style(
			chunk.wseed, nb, chunk.theme) != WorldGen.POOL_CHANNEL:
		return
	var runs := _pool_connection_runs(
		chunk.cell, chunk.style, dir)
	if runs == Vector2.ZERO:
		return
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var own_low := center.y - size.y * 0.5
	var own_high := center.y + size.y * 0.5
	var channel_span := _pool_water_span_at_edge(
		nb, WorldGen.POOL_CHANNEL, WorldGen.OPP[dir])
	var edge := chunk.S if dir == 0 else 0.0
	if runs.x > 0.0:
		var run := runs.x
		var start := Vector2(
			edge - run if dir == 0 else edge + run, own_low)
		var end := Vector2(
			edge + run if dir == 0 else edge - run, channel_span.x)
		_pool_connected_coping_s_bend(
			start, end, 1.0 if dir == 0 else -1.0,
			dir, "low", run)

	if runs.y > 0.0:
		var run := runs.y
		var start := Vector2(
			edge - run if dir == 0 else edge + run, own_high)
		var end := Vector2(
			edge + run if dir == 0 else edge - run, channel_span.y)
		_pool_connected_coping_s_bend(
			start, end, -1.0 if dir == 0 else 1.0,
			dir, "high", run)


func _pool_connected_coping_s_bend(
		start: Vector2, end: Vector2, water_side: float,
		dir: int, side: String, run: float) -> void:
	var path: Array[Vector2] = []
	var segment_count := 18
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		# Zero slope at both ends makes the swept strip tangent to the two
		# straight pool edges. One path and one profile means the water nose
		# and the deck-side edge cannot diverge at an internal module joint.
		var smooth_t := t * t * (3.0 - 2.0 * t)
		path.append(Vector2(
			lerpf(start.x, end.x, t),
			lerpf(start.y, end.y, smooth_t)))
	var coping := MeshInstance3D.new()
	coping.mesh = PoolCornerMesh.path_bullnose(
		path, water_side,
		POOL_COPING_WIDTH - POOL_COPING_WATER_OVERHANG,
		POOL_COPING_WATER_OVERHANG,
		chunk.POOL_DECK_Y + POOL_COPING_TOP_OFFSET
			- POOL_COPING_HEIGHT * 0.5,
		POOL_COPING_HEIGHT, POOL_COPING_NOSE_SEGMENTS)
	coping.material_override = Mats.pool_coping()
	coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coping.set_meta("pool_connected_coping_turn", true)
	coping.set_meta("pool_connected_coping_continuous", true)
	coping.set_meta("pool_connected_coping_start", start)
	coping.set_meta("pool_connected_coping_end", end)
	coping.set_meta("pool_connected_coping_dir", dir)
	coping.set_meta("pool_connected_coping_side", side)
	coping.set_meta("pool_connected_coping_run", run)
	coping.set_meta("pool_coping_bullnose", true)
	chunk.add_child(coping)


func _pool_deck_piece(center: Vector2, size: Vector2) -> void:
	if size.x < 0.04 or size.y < 0.04:
		return
	var pieces: Array[Rect2] = [Rect2(center - size * 0.5, size)]
	for zone in chunk._runtime_shortcut_clearance_rects():
		var next: Array[Rect2] = []
		for piece in pieces:
			var cut := piece.intersection(zone)
			if cut.size.x <= 0.001 or cut.size.y <= 0.001:
				next.append(piece)
				continue
			var piece_end := piece.end
			var cut_end := cut.end
			# Four non-overlapping bands around the removed rectangle.
			if cut.position.x - piece.position.x > 0.04:
				next.append(Rect2(piece.position,
					Vector2(cut.position.x - piece.position.x, piece.size.y)))
			if piece_end.x - cut_end.x > 0.04:
				next.append(Rect2(Vector2(cut_end.x, piece.position.y),
					Vector2(piece_end.x - cut_end.x, piece.size.y)))
			if cut.position.y - piece.position.y > 0.04:
				next.append(Rect2(Vector2(cut.position.x, piece.position.y),
					Vector2(cut.size.x, cut.position.y - piece.position.y)))
			if piece_end.y - cut_end.y > 0.04:
				next.append(Rect2(Vector2(cut.position.x, cut_end.y),
					Vector2(cut.size.x, piece_end.y - cut_end.y)))
		pieces = next
	var h: float = chunk.POOL_DECK_Y + 0.3
	for piece in pieces:
		var piece_center := piece.position + piece.size * 0.5
		var deck = chunk._box(
			Vector3(piece_center.x, chunk.POOL_DECK_Y * 0.5 - 0.15,
				piece_center.y),
			Vector3(piece.size.x, h, piece.size.y), Mats.pool_tile())
		deck.set_meta("pool_basin_deck", true)


func _pool_coping_segment(center: Vector2, size: Vector2, axis: int,
		water_direction: Vector2) -> void:
	var length := size.y if axis == 0 else size.x
	if length < 0.05:
		return
	var water_dir := water_direction.normalized()
	var along := Vector2(0.0, 1.0) if axis == 0 \
		else Vector2(1.0, 0.0)
	var shifted_center := center - water_dir * POOL_COPING_DECK_SHIFT
	var slab_count := maxi(1, ceili(length / POOL_COPING_SLAB_LENGTH))
	var pitch := length / float(slab_count)
	var slab_length := maxf(0.04, pitch - POOL_COPING_JOINT_GAP)
	var yaw := atan2(water_dir.x, water_dir.y)
	var y_mid := chunk.POOL_DECK_Y + POOL_COPING_TOP_OFFSET \
		- POOL_COPING_HEIGHT * 0.5
	for i in slab_count:
		var offset := -length * 0.5 + pitch * (float(i) + 0.5)
		var slab_center := shifted_center + along * offset
		var coping := MeshInstance3D.new()
		coping.mesh = PoolCornerMesh.straight_bullnose(
			POOL_COPING_WIDTH, POOL_COPING_HEIGHT,
			POOL_COPING_NOSE_SEGMENTS)
		coping.position = Vector3(slab_center.x, y_mid, slab_center.y)
		coping.rotation.y = yaw
		coping.scale.x = slab_length
		coping.material_override = Mats.pool_coping()
		coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coping.set_meta("pool_basin_coping", true)
		coping.set_meta("pool_basin_coping_axis", axis)
		coping.set_meta("pool_coping_bullnose", true)
		coping.set_meta("pool_coping_slab_index", i)
		coping.set_meta("pool_coping_slab_count", slab_count)
		coping.set_meta("pool_coping_water_direction", water_dir)
		chunk.add_child(coping)


func _pool_vertical_coping(x: float, z0: float, z1: float,
		water_direction: Vector2) -> void:
	if z1 - z0 < 0.05:
		return
	_pool_coping_segment(
		Vector2(x, (z0 + z1) * 0.5),
		Vector2(POOL_COPING_WIDTH, z1 - z0), 0, water_direction)


func _pool_horizontal_coping(z: float, x0: float, x1: float,
		water_direction: Vector2) -> void:
	if x1 - x0 < 0.05:
		return
	_pool_coping_segment(
		Vector2((x0 + x1) * 0.5, z),
		Vector2(x1 - x0, POOL_COPING_WIDTH), 1, water_direction)


func _pool_square_coping_corner_arc(corner: Vector2, id: int) -> void:
	var radius := POOL_SQUARE_COPING_CORNER_RADIUS
	var center := corner
	var radial_start := Vector2.UP
	var sweep := 0.0
	match id:
		0:
			center += Vector2(radius, radius)
			sweep = -PI * 0.5
		1:
			center += Vector2(-radius, radius)
			sweep = PI * 0.5
		2:
			center += Vector2(-radius, -radius)
			radial_start = Vector2.DOWN
			sweep = -PI * 0.5
		3:
			center += Vector2(radius, -radius)
			radial_start = Vector2.DOWN
			sweep = PI * 0.5
	_pool_arc_coping(
		center, radial_start, sweep, radius, true, "pool_basin_coping")


func _pool_arc_coping(center: Vector2, radial_start: Vector2,
		sweep: float, boundary_radius: float, water_inside: bool,
		meta_name: String) -> void:
	var deck_span := POOL_COPING_WIDTH - POOL_COPING_WATER_OVERHANG
	var deck_radius := boundary_radius + deck_span \
		if water_inside else boundary_radius - deck_span
	var water_radius := boundary_radius - POOL_COPING_WATER_OVERHANG \
		if water_inside else boundary_radius + POOL_COPING_WATER_OVERHANG
	var middle_radius := (deck_radius + water_radius) * 0.5
	var arc_length := absf(sweep) * middle_radius
	var slab_count := maxi(1, ceili(arc_length / POOL_COPING_SLAB_LENGTH))
	var part_angle := absf(sweep) / float(slab_count)
	var gap_angle := minf(
		POOL_COPING_JOINT_GAP / maxf(middle_radius, 0.05),
		part_angle * 0.22)
	var direction := signf(sweep)
	var y_mid := chunk.POOL_DECK_Y + POOL_COPING_TOP_OFFSET \
		- POOL_COPING_HEIGHT * 0.5
	for i in slab_count:
		var angle_offset := direction * (
			part_angle * float(i) + gap_angle * 0.5)
		var slab_sweep := direction * (part_angle - gap_angle)
		var coping := MeshInstance3D.new()
		coping.mesh = PoolCornerMesh.annular_bullnose(
			center, radial_start.rotated(angle_offset), slab_sweep,
			deck_radius, water_radius, y_mid, POOL_COPING_HEIGHT,
			maxi(3, ceili(
				absf(slab_sweep) * maxf(deck_radius, water_radius) * 5.0)),
			POOL_COPING_NOSE_SEGMENTS)
		coping.material_override = Mats.pool_coping()
		coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coping.set_meta(meta_name, true)
		coping.set_meta("pool_coping_bullnose", true)
		coping.set_meta("pool_coping_slab_index", i)
		coping.set_meta("pool_coping_slab_count", slab_count)
		coping.set_meta("pool_coping_water_inside", water_inside)
		chunk.add_child(coping)


## The dry hall's raised floor: one square slab wall to wall. Per-corner
## fillets were tried and reverted — a slab corner rounds correctly only
## when both its edges face water, and coordinating that across dry
## neighbours bought nothing a plain square slab doesn't already give.


func _pool_dry_slab_piece(center: Vector2, size: Vector2) -> void:
	if size.x <= 0.02 or size.y <= 0.02:
		return
	var yc = chunk.POOL_DRY_Y * 0.5 - 0.15
	var h = chunk.POOL_DRY_Y + 0.3
	var slab := chunk._box(
		Vector3(center.x, yc, center.y),
		Vector3(size.x, h, size.y), Mats.pool_tile())
	slab.set_meta("pool_dry_slab_piece", true)


func _pool_planned_jacuzzi_site() -> Vector3:
	if chunk.style == WorldGen.POOL_DECK:
		if chunk.cell == Vector2i.ZERO:
			return Vector3(8.4, chunk.POOL_DRY_Y, 8.2)
		var roll := chunk._r(2410)
		if roll < 0.48 or roll >= 0.70:
			return Vector3.INF
	elif chunk.style == WorldGen.POOL_ALCOVE:
		if chunk._r(2344) >= 0.52:
			return Vector3.INF
	else:
		return Vector3.INF
	var x := 3.15 if chunk._r(2440) < 0.5 else 8.85
	var z := 3.15 if chunk._r(2441) < 0.5 else 8.85
	return Vector3(x, chunk.POOL_DRY_Y, z)


func _pool_jacuzzi_center(site: Vector3) -> Vector3:
	return site + Vector3(
		POOL_JACUZZI_CENTRE_OFFSET.x,
		0.0, POOL_JACUZZI_CENTRE_OFFSET.y)


func _pool_dry_slab() -> void:
	var jacuzzi := _pool_planned_jacuzzi_site()
	if jacuzzi == Vector3.INF:
		_pool_dry_slab_piece(
			Vector2(chunk.S * 0.5, chunk.S * 0.5),
			Vector2(chunk.S, chunk.S))
		return
	var hole_center := _pool_jacuzzi_center(jacuzzi)
	var x0 := hole_center.x \
		- POOL_JACUZZI_DECK_CUTOUT_SIZE.x * 0.5
	var x1 := hole_center.x \
		+ POOL_JACUZZI_DECK_CUTOUT_SIZE.x * 0.5
	var z0 := hole_center.z \
		- POOL_JACUZZI_DECK_CUTOUT_SIZE.y * 0.5
	var z1 := hole_center.z \
		+ POOL_JACUZZI_DECK_CUTOUT_SIZE.y * 0.5
	_pool_dry_slab_piece(
		Vector2(x0 * 0.5, chunk.S * 0.5), Vector2(x0, chunk.S))
	_pool_dry_slab_piece(
		Vector2((x1 + chunk.S) * 0.5, chunk.S * 0.5),
		Vector2(chunk.S - x1, chunk.S))
	_pool_dry_slab_piece(
		Vector2((x0 + x1) * 0.5, z0 * 0.5),
		Vector2(x1 - x0, z0))
	_pool_dry_slab_piece(
		Vector2((x0 + x1) * 0.5, (z1 + chunk.S) * 0.5),
		Vector2(x1 - x0, chunk.S - z1))
	_pool_jacuzzi_cutout_corners(
		hole_center, x0, x1, z0, z1)
	# The well shares the same zero-datum basin floor as the surrounding wet
	# Poolrooms, so entering it behaves like entering any other pool.
	var bottom := chunk._box(
		Vector3(hole_center.x, -0.15, hole_center.z),
		Vector3(
			POOL_JACUZZI_DECK_CUTOUT_SIZE.x, 0.30,
			POOL_JACUZZI_DECK_CUTOUT_SIZE.y),
		Mats.pool_tile())
	bottom.set_meta("pool_jacuzzi_basin_floor", true)


func _pool_jacuzzi_cutout_corners(
		_hole_center: Vector3,
		x0: float, x1: float, z0: float, z1: float) -> void:
	# The four surrounding slab boxes leave a rectangular opening. Fill only
	# the material OUTSIDE a rounded rectangle, so the cut follows the tub's
	# exterior silhouette while everything inside that perimeter stays clear.
	var r := POOL_JACUZZI_DECK_CUTOUT_RADIUS
	var corners := [
		[
			Vector2(x0, z0), Vector2(x0 + r, z0 + r),
			Vector2.UP, -PI * 0.5,
		],
		[
			Vector2(x1, z0), Vector2(x1 - r, z0 + r),
			Vector2.UP, PI * 0.5,
		],
		[
			Vector2(x1, z1), Vector2(x1 - r, z1 - r),
			Vector2.DOWN, -PI * 0.5,
		],
		[
			Vector2(x0, z1), Vector2(x0 + r, z1 - r),
			Vector2.DOWN, PI * 0.5,
		],
	]
	for i in corners.size():
		var corner: Vector2 = corners[i][0]
		var center: Vector2 = corners[i][1]
		var radial_start: Vector2 = corners[i][2]
		var sweep: float = corners[i][3]
		var fill := MeshInstance3D.new()
		fill.mesh = PoolCornerMesh.quarter_cove(
			center, radial_start, sweep, r, corner,
			-0.30, chunk.POOL_DRY_Y,
			chunk.POOL_CORNER_SEGMENTS)
		fill.material_override = Mats.pool_tile()
		fill.set_meta("pool_jacuzzi_cutout_corner", true)
		fill.set_meta("pool_jacuzzi_cutout_corner_index", i)
		fill.set_meta("pool_jacuzzi_cutout_radius", r)
		chunk.add_child(fill)
		_pool_cove_colliders(
			center, radial_start, sweep, r, corner,
			chunk.POOL_DRY_Y,
			"pool_jacuzzi_cutout_corner_collider")


## Which halls hold water. Roughly a third of the floor is dry tile, because a
## level that is nothing but standing water gives the player nowhere to stand,
## nothing to contrast the water against, and no way out of it.


func _pool_dry() -> bool:
	return _pool_style_dry_local(chunk.style)


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
		var info = chunk._edge_info(chunk.cell, dir)
		if bool(info["wall"]):
			continue
		var nb: Vector2i = chunk.cell + WorldGen.DIRV[dir]
		if _pool_style_dry_local(
				WorldGen.cell_style(chunk.wseed, nb, chunk.theme)):
			continue
		var nb_style = WorldGen.cell_style(chunk.wseed, nb, chunk.theme)
		if not _pool_water_reaches_edge(nb, nb_style, WorldGen.OPP[dir]):
			# A compact basin leaves a full-height deck at this doorway. The
			# dry room and flooded room therefore meet flush, with no stair or
			# ladder to bury in the neighbour's solid deck.
			continue
		var t = float(info["t"])
		var w = maxf(float(info["w"]), 2.6)
		# Edge reach is not enough: a 3.65m channel touches the boundary, but
		# most of that 12m boundary is still dry deck. Restrict this crossing
		# to the actual overlap of doorway and water, or do not build it.
		var water_span := _pool_water_span_at_edge(
			nb, nb_style, WorldGen.OPP[dir])
		var crossing_lo := maxf(t - w * 0.5, water_span.x)
		var crossing_hi := minf(t + w * 0.5, water_span.y)
		if crossing_hi - crossing_lo < 1.25:
			continue
		t = (crossing_lo + crossing_hi) * 0.5
		w = crossing_hi - crossing_lo
		# The neighbour may stand its own dry deck against this very stretch
		# of edge — a channel towpath, a basin side walk, a bridge end — all
		# at this same dry-hall height, so the two floors meet flush. Treads
		# would bury themselves in that deck, and a ladder would stand on
		# dry tile with its rails diving into solid floor.
		if _pool_nb_deck_blocks(nb, dir, t, w):
			continue
		if nb_style == WorldGen.POOL_STAIRS \
				and _pool_stairs_exit(nb) == WorldGen.OPP[dir]:
			# The stairs room sends its wide tiled stair to this very opening.
			# Our own treads and ladder would land fused into it — the stair
			# IS the crossing, so this side builds nothing.
			continue
		# Steps or a ladder — one way out per opening, never both fused
		# together in the same doorway.
		if chunk._r(2601 + dir) >= 0.55:
			if w > 5.0:
				var pair_offset := minf(w * 0.27, w * 0.5 - 0.75)
				_pool_wall_ladder(dir, t - pair_offset)
				_pool_wall_ladder(dir, t + pair_offset)
			else:
				_pool_wall_ladder(dir, t)
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


func _pool_clear_of_runtime_doorway(at: Vector2, radius: float) -> bool:
	var footprint := Rect2(at - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	for zone in chunk._runtime_shortcut_clearance_rects():
		if footprint.intersects(zone):
			return false
	return true


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
	var ramp: CollisionShape3D
	if dir < 2:
		ramp = chunk._collider_rot_box(Vector3(mid, y, at),
			Vector3(ln, 0.12, width), Vector3(0, 0, -outward * ang))
	else:
		ramp = chunk._collider_rot_box(Vector3(at, y, mid),
			Vector3(width, 0.12, ln), Vector3(outward * ang, 0, 0))
	ramp.set_meta("walkable_ramp", true)


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
	# Cap the water-facing edge with the same modular bullnose used by compact
	# basins, so legacy side decks cannot reintroduce the old square tile lip.
	match dir:
		0:
			_pool_vertical_coping(
				chunk.S - width, 0.0, chunk.S, Vector2(-1.0, 0.0))
		1:
			_pool_vertical_coping(
				width, 0.0, chunk.S, Vector2(1.0, 0.0))
		2:
			_pool_horizontal_coping(
				chunk.S - width, 0.0, chunk.S, Vector2(0.0, -1.0))
		_:
			_pool_horizontal_coping(
				width, 0.0, chunk.S, Vector2(0.0, 1.0))
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


func _pool_window(dir: int, along: float, tall = true, drop := 0.0) -> void:
	# Only ever on a solid outside wall. Placed on an edge that is actually an
	# opening, the pane hangs in mid-air in the middle of the doorway — which
	# is exactly what it was doing. This also keeps them sparse for free:
	# a room with three ways out can only carry one.
	if not bool(chunk._edge_info(chunk.cell, dir)["wall"]):
		return
	if WorldGen.pool_wall_aperture(chunk.wseed, chunk.cell, dir):
		return
	# Daylight is only credible where you cannot walk around the wall and
	# disprove it. An eye-level pane on an interior wall claims an outside
	# that the next room refutes, so the pills exist only in the taller
	# halls, high up under the ceiling, where the light reads as falling in
	# from somewhere genuinely beyond the building. 5.0 admits the 5.2m
	# multi-cell halls and the new multi-storey volumes; the ordinary
	# 4.1-4.6 rooms never qualify.
	if chunk.ceil_h < 5.0:
		return
	_pool_round_window(dir, along, tall, drop)


func _pool_round_window(
		dir: int, along: float, tall = true, drop := 0.0) -> void:
	# A CylinderMesh's axis is +Y. The caps therefore have to be turned onto the
	# wall normal individually — rotating the parent instead sent them spinning
	# off axis and left huge unshaded discs hanging in the room.
	var plane = (chunk.S - 0.12) if (dir == 0 or dir == 2) else 0.12
	var inward = -1.0 if (dir == 0 or dir == 2) else 1.0
	var r = 0.55
	var body = 1.45 if tall else 0.0
	# High under the ceiling, well above anything walkable, so the glow has
	# room to fall through the hall the way a clerestory would let it.
	var mid = chunk.ceil_h - 1.15 - body * 0.5 - drop
	var pivot = Node3D.new()
	pivot.position = Vector3(plane, mid, along) if dir < 2 \
		else Vector3(along, mid, plane)
	pivot.set_meta("pool_window", true)
	pivot.set_meta("pool_window_round", true)
	var pair_id := "pool_window_%d_%d_%d_%d_%d" % [
		chunk.cell.x, chunk.cell.y, dir,
		roundi(along * 100.0), roundi(drop * 100.0)]
	pivot.set_meta("pool_light_emitter", true)
	pivot.set_meta("pool_light_pair_id", pair_id)
	pivot.set_meta("pool_light_type", "window")
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
	# A normal hall needs one daylight shaft. The stacked window rows in a
	# triple-height hall receive two, so both the upper and middle wall bands
	# read as real sources instead of emissive decals.
	var light_count := int(chunk.get_meta("pool_window_light_count", 0))
	var max_lights := 2 if chunk.ceil_h >= 10.5 else 1
	if light_count >= max_lights:
		return
	chunk.set_meta("pool_window_lit", true)
	chunk.set_meta("pool_window_light_count", light_count + 1)
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
	lamp.set_meta("pool_direct_light", true)
	lamp.set_meta("pool_light_pair_id", pair_id)
	lamp.set_meta("pool_light_type", "window")
	chunk.add_child(lamp)


## Multi-storey Poolrooms always expose their scale with bright clerestories.
## One selected exterior wall per boundary cell keeps the daylight legible
## without wallpapering every surface. Triple-height halls get an offset
## second row: the empty wall now has a visible middle and upper level.
func _pool_tall_clerestories() -> bool:
	if chunk.ceil_h < 7.8:
		return false
	var walls: Array[int] = []
	for dir in 4:
		if bool(chunk._edge_info(chunk.cell, dir)["wall"]) \
				and not WorldGen.pool_wall_aperture(
					chunk.wseed, chunk.cell, dir):
			walls.append(dir)
	if walls.is_empty():
		return false
	var dir: int = walls[
		int(chunk._r(2448) * float(walls.size())) % walls.size()]
	if chunk.ceil_h >= 10.5:
		for along in [2.55, 6.0, 9.45]:
			_pool_window(dir, along, true)
		for along in [4.0, 8.0]:
			_pool_window(dir, along, true, 3.55)
	else:
		for along in [3.25, 8.75]:
			_pool_window(dir, along, true)
	chunk.set_meta("pool_tall_clerestory", true)
	chunk.set_meta("pool_tall_clerestory_wall", dir)
	return true


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
		if bool(chunk._edge_info(c, pick)["wall"]):
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


func _pool_nb_deck_blocks(
		_nb: Vector2i, _dir: int, _t: float, _w: float) -> bool:
	# Compact basins and channels no longer build full-height side walks or
	# bridges against shared edges, so no neighbour deck can bury an exit.
	return false


## A ladder out of the water at a pool/dry boundary, climbing the 1.15m to the
## dry floor. Built alongside the treads rather than instead of them, so a
## player who wants the ladder finds one and a player who does not can walk.


func _pool_wall_ladder(dir: int, along: float) -> void:
	# Hung off the dry cell's edge, out over the water it serves.
	var edge: float = chunk.S if dir == 0 else (0.0 if dir == 1 else (chunk.S if dir == 2 else 0.0))
	_pool_ladder_at(dir, edge, along, -1.0 if (dir == 0 or dir == 2) else 1.0)



## Every direct Pool Rooms light has a visible source.  Most cells use a
## recessed round ceiling disc; a few use a porcelain-orb wall sconce instead.
## Deliberately dark cells receive neither.  Windows add their own paired spot
## lights later when the room-specific architecture is built.


func _pool_lighting() -> void:
	var has_clerestory := _pool_tall_clerestories()
	# Keep a few genuinely dim pockets, but wet rooms should usually reveal the
	# visible fixture responsible for their illumination.
	var dark_chance := 0.08
	if chunk.style == WorldGen.POOL_ALCOVE:
		dark_chance = 0.22
	elif chunk.style == WorldGen.POOL_CISTERN:
		dark_chance = 0.12
	if chunk._r(2420) < dark_chance and not has_clerestory:
		chunk.set_meta("pool_intentionally_dim", true)
		return
	# A sconce is useful in lower, narrower rooms and gives the occasional
	# human-scale pool corridor a different rhythm from the ceiling grid.
	var has_orb := chunk._r(2421) < 0.18 and _pool_wall_orb_fixture(2422)
	if has_orb and _pool_dry():
		return
	var count := 1
	if not _pool_dry() \
			or chunk.style == WorldGen.POOL_GALLERY \
				or chunk.style == WorldGen.POOL_CISTERN \
				or chunk.style == WorldGen.POOL_SOLARIUM:
		count = 2
	var points: Array[Vector2] = []
	if count == 1:
		var at := Vector2(chunk.S * 0.5, chunk.S * 0.5)
		if WorldGen.portal(chunk.wseed, chunk.cell, chunk.theme) >= 0:
			at = Vector2(chunk.S * 0.5, chunk.S * 0.34)
		points.append(at)
	elif chunk.style == WorldGen.POOL_CHANNEL \
			and not bool(_pool_water_layout().get("axis_x", true)):
		points.append(Vector2(chunk.S * 0.5, chunk.S * 0.31))
		points.append(Vector2(chunk.S * 0.5, chunk.S * 0.69))
	else:
		points.append(Vector2(chunk.S * 0.31, chunk.S * 0.5))
		points.append(Vector2(chunk.S * 0.69, chunk.S * 0.5))
	for i in points.size():
		_pool_round_ceiling_fixture(points[i], i)
	chunk.set_meta("pool_ceiling_fixture_points", points)


func _pool_round_ceiling_fixture(at: Vector2, index: int) -> void:
	var pair_id := "pool_ceiling_%d_%d_%d" % [
		chunk.cell.x, chunk.cell.y, index]
	var housing: MeshInstance3D = chunk._cyl(
		Vector3(at.x, chunk.ceil_h - 0.055, at.y),
		0.52, 0.11, Mats.pool_coping(), false)
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	housing.set_meta("pool_ceiling_fixture", true)
	housing.set_meta("pool_light_emitter", true)
	housing.set_meta("pool_light_pair_id", pair_id)
	housing.set_meta("pool_light_type", "ceiling_disc")
	var disc: MeshInstance3D = chunk._cyl(
		Vector3(at.x, chunk.ceil_h - 0.116, at.y),
		0.43, 0.025, Mats.pool_daylight(), false)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.set_meta("pool_ceiling_fixture_glow", true)
	disc.set_meta("pool_light_emitter", true)
	disc.set_meta("pool_light_pair_id", pair_id)
	disc.set_meta("pool_light_type", "ceiling_disc")
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.975, 0.90)
	var height_scale := clampf(
		(chunk.ceil_h - 5.0) / 7.5, 0.0, 1.0)
	lamp.light_energy = lerpf(1.58, 2.35, height_scale)
	lamp.omni_range = maxf(
		8.2, chunk.ceil_h - chunk.POOL_DRY_Y + 1.8)
	lamp.shadow_enabled = false
	lamp.position = Vector3(at.x, chunk.ceil_h - 0.42, at.y)
	lamp.set_meta("pool_direct_light", true)
	lamp.set_meta("pool_light_pair_id", pair_id)
	lamp.set_meta("pool_light_type", "ceiling_disc")
	chunk.add_child(lamp)


func _pool_wall_orb_fixture(salt: int) -> bool:
	var walls: Array[int] = []
	for dir in 4:
		if bool(chunk._edge_info(chunk.cell, dir)["wall"]) \
				and not WorldGen.pool_wall_aperture(
					chunk.wseed, chunk.cell, dir):
			walls.append(dir)
	if walls.is_empty():
		return false
	var dir: int = walls[
		int(chunk._r(salt) * float(walls.size())) % walls.size()]
	var along := lerpf(2.2, chunk.S - 2.2, chunk._r(salt + 1))
	var plane: float = (chunk.S - chunk.T - 0.01) \
		if (dir == 0 or dir == 2) else (chunk.T + 0.01)
	var inward := -1.0 if (dir == 0 or dir == 2) else 1.0
	# Keep the globe in the upper wall band, consistently tucked beneath the
	# ceiling trim. The old 1.75-2.25m clamp put it at face/waist height in
	# tall rooms, where it read like a misplaced illuminated button.
	var height := maxf(2.65, chunk.ceil_h - 0.72)
	var wall_pos := Vector3(plane, height, along) if dir < 2 \
		else Vector3(along, height, plane)
	var room_dir := Vector3(inward, 0, 0) if dir < 2 \
		else Vector3(0, 0, inward)
	var pair_id := "pool_orb_%d_%d_%d" % [
		chunk.cell.x, chunk.cell.y, dir]
	var plate: MeshInstance3D = chunk._cyl(
		wall_pos, 0.23, 0.08, Mats.pool_coping(), false)
	if dir < 2:
		plate.rotation.z = PI * 0.5
	else:
		plate.rotation.x = PI * 0.5
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.set_meta("pool_wall_orb_plate", true)
	var stem_pos := wall_pos + room_dir * 0.12
	var stem: MeshInstance3D = chunk._cyl(
		stem_pos, 0.065, 0.22, Mats.pool_coping(), false)
	if dir < 2:
		stem.rotation.z = PI * 0.5
	else:
		stem.rotation.x = PI * 0.5
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var orb: MeshInstance3D = chunk._sphere(
		wall_pos + room_dir * 0.27, 0.21, Mats.pool_daylight())
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.set_meta("pool_wall_orb", true)
	orb.set_meta("pool_light_emitter", true)
	orb.set_meta("pool_light_pair_id", pair_id)
	orb.set_meta("pool_light_type", "porcelain_orb")
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.96, 0.86)
	var height_scale := clampf(
		(chunk.ceil_h - 5.0) / 7.5, 0.0, 1.0)
	lamp.light_energy = lerpf(1.36, 2.05, height_scale)
	lamp.omni_range = maxf(
		6.3, chunk.ceil_h - chunk.POOL_DRY_Y + 1.5)
	lamp.shadow_enabled = false
	lamp.position = wall_pos + room_dir * 0.42
	lamp.set_meta("pool_direct_light", true)
	lamp.set_meta("pool_light_pair_id", pair_id)
	lamp.set_meta("pool_light_type", "porcelain_orb")
	chunk.add_child(lamp)
	return true


## One abandoned float reads as a place people left; a dozen reads as a ball
## pit. Kept rare, and re-tinted per instance so the same ring is never
## obviously the same ring twice.
## A grid of piers. Offset so the rows never line up into a corridor, which is
## what turns an open hall into somewhere you lose track of yourself.


func _pool_piers(salt: int, count: int) -> Array[Vector3]:
	if not _pool_dry():
		return _pool_compact_piers(salt, count)
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
		if not _pool_clear_of_runtime_doorway(
				Vector2(gx, gz), chunk.POOL_PIER * 0.62):
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


func _pool_compact_piers(salt: int, count: int) -> Array[Vector3]:
	var layout := _pool_water_layout()
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var inset := 1.20
	var x0 := center.x - size.x * 0.5 + inset
	var x1 := center.x + size.x * 0.5 - inset
	var z0 := center.y - size.y * 0.5 + inset
	var z1 := center.y + size.y * 0.5 - inset
	var positions: Array[Vector3] = []
	if x1 <= x0 or z1 <= z0:
		return positions
	var target := mini(
		count, 3 if chunk.style == WorldGen.POOL_CISTERN else 2)
	var has_portal := WorldGen.portal(
		chunk.wseed, chunk.cell, chunk.theme) >= 0
	var fixture_points: Array = chunk.get_meta(
		"pool_ceiling_fixture_points", [])
	for i in 18:
		if positions.size() >= target:
			break
		var gx := lerpf(x0, x1, chunk._r(salt + i * 4))
		var gz := lerpf(z0, z1, chunk._r(salt + i * 4 + 1))
		if chunk._r(salt + i * 4 + 2) > 0.80:
			continue
		var point := Vector2(gx, gz)
		if not _pool_clear_of_runtime_doorway(
				point, chunk.POOL_PIER * 0.62):
			continue
		if has_portal and point.distance_to(
				Vector2(chunk.S * 0.5, chunk.S * 0.5)) < 2.25:
			continue
		var blocked := false
		for fixture in fixture_points:
			var fixture_point: Vector2 = fixture
			if point.distance_to(fixture_point) < 0.95:
				blocked = true
				break
		if blocked:
			continue
		for prior in positions:
			if point.distance_to(Vector2(prior.x, prior.z)) < 1.55:
				blocked = true
				break
		if blocked:
			continue
		var at := Vector3(gx, 0.0, gz)
		_pool_pier(at)
		positions.append(at)
	return positions


## Round one corner of the compact pool itself.  This is the pool equivalent
## of an inner wall cove: the circle centre is inset into the basin and the
## dry deck only fills the square corner outside that arc.  Do not replace this
## with a quarter-sector centred on the square corner; that makes the deck
## bulge convexly into the water.
func _pool_compact_rounded_basin_corner(layout: Dictionary) -> bool:
	var id := int(layout.get("rounded_corner", -1))
	var radius := float(layout.get("corner_radius", 0.0))
	if id < 0 or radius <= 0.0:
		return false
	var basin_center: Vector2 = layout["center"]
	var basin_size: Vector2 = layout["size"]
	var x0 := basin_center.x - basin_size.x * 0.5
	var x1 := basin_center.x + basin_size.x * 0.5
	var z0 := basin_center.y - basin_size.y * 0.5
	var z1 := basin_center.y + basin_size.y * 0.5
	var corner := Vector2.ZERO
	var center := Vector2.ZERO
	var radial_start := Vector2.UP
	var sweep := 0.0
	match id:
		0:
			corner = Vector2(x0, z0)
			center = corner + Vector2(radius, radius)
			sweep = -PI * 0.5
		1:
			corner = Vector2(x1, z0)
			center = corner + Vector2(-radius, radius)
			sweep = PI * 0.5
		2:
			corner = Vector2(x1, z1)
			center = corner + Vector2(-radius, -radius)
			radial_start = Vector2.DOWN
			sweep = -PI * 0.5
		3:
			corner = Vector2(x0, z1)
			center = corner + Vector2(radius, -radius)
			radial_start = Vector2.DOWN
			sweep = PI * 0.5
		_:
			return false
	var deck := MeshInstance3D.new()
	deck.mesh = PoolCornerMesh.quarter_cove(
		center, radial_start, sweep, radius, corner,
		0.0, chunk.POOL_DECK_Y, chunk.POOL_CORNER_SEGMENTS)
	deck.material_override = Mats.pool_tile()
	deck.set_meta("pool_rounded_basin_corner", true)
	deck.set_meta("pool_rounded_basin_corner_id", id)
	deck.set_meta("pool_rounded_basin_corner_radius", radius)
	deck.set_meta("pool_rounded_basin_corner_compact", true)
	deck.set_meta(
		"pool_rounded_basin_corner_orientation", "concave_water_opening")
	deck.set_meta("pool_rounded_basin_corner_square_corner", corner)
	deck.set_meta("pool_rounded_basin_corner_arc_center", center)
	chunk.add_child(deck)
	_pool_cove_colliders(
		center, radial_start, sweep, radius, corner,
		chunk.POOL_DECK_Y, "pool_rounded_basin_corner_collider")
	_pool_arc_coping(
		center, radial_start, sweep, radius, true,
		"pool_rounded_basin_corner_coping")
	return true


## Put a circular deck around an existing pier.  The water remains one
## continuous seam-free plane below it; the opaque deck hides that overlap.
func _pool_pier_island(salt: int, piers: Array[Vector3]) -> bool:
	var layout := _pool_water_layout()
	if piers.is_empty() or int(layout.get("rounded_corner", -1)) >= 0 \
			or chunk._r(salt) >= 0.56:
		return false
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var radius := lerpf(0.78, 1.12, chunk._r(salt + 2))
	var clearance := radius + 0.12
	var x0 := center.x - size.x * 0.5 + clearance
	var x1 := center.x + size.x * 0.5 - clearance
	var z0 := center.y - size.y * 0.5 + clearance
	var z1 := center.y + size.y * 0.5 - clearance
	var eligible: Array[Vector3] = []
	for at in piers:
		if at.x >= x0 and at.x <= x1 \
				and at.z >= z0 and at.z <= z1 \
				and _pool_clear_of_runtime_doorway(
					Vector2(at.x, at.z), radius):
			eligible.append(at)
	if eligible.is_empty():
		return false
	var at: Vector3 = eligible[
		int(chunk._r(salt + 1) * float(eligible.size())) % eligible.size()]
	var island: MeshInstance3D = chunk._cyl(
		Vector3(at.x, chunk.POOL_DECK_Y * 0.5, at.z),
		radius, chunk.POOL_DECK_Y, Mats.pool_tile())
	island.set_meta("pool_rounded_pier_island", true)
	island.set_meta("pool_rounded_pier_island_radius", radius)
	island.set_meta("pool_rounded_pier_island_center", Vector2(at.x, at.z))
	_pool_arc_coping(
		Vector2(at.x, at.z), Vector2.RIGHT, TAU, radius, false,
		"pool_rounded_pier_island_coping")
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


func _pool_cove_colliders(center: Vector2, radial_start: Vector2,
		sweep: float, radius: float, corner: Vector2,
		height: float, meta_name: String) -> void:
	var start := radial_start.normalized()
	var corner_bottom := Vector3(corner.x, 0.0, corner.y)
	var corner_top := Vector3(corner.x, height, corner.y)
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
			corner_bottom, arc0, arc1,
			corner_top, arc0 + Vector3.UP * height, arc1 + Vector3.UP * height,
		])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.set_meta(meta_name, true)
		cs.set_meta("pool_rounded_basin_corner_sector", i)
		chunk.body.add_child(cs)


func _pool_float(salt: int) -> void:
	if _pool_dry() or chunk._r(salt) > 0.16:
		return
	var layout := _pool_water_layout()
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var inset := 0.72
	var x0 := center.x - size.x * 0.5 + inset
	var x1 := center.x + size.x * 0.5 - inset
	var z0 := center.y - size.y * 0.5 + inset
	var z1 := center.y + size.y * 0.5 - inset
	if x1 <= x0 or z1 <= z0:
		return
	var at := Vector3(
		lerpf(x0, x1, chunk._r(salt + 1)),
		chunk.POOL_WATER_Y - 0.05,
		lerpf(z0, z1, chunk._r(salt + 2)))
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
	pivot.set_meta("pool_ladder_dir", dir)
	pivot.set_meta("pool_ladder_edge", edge)
	pivot.set_meta("pool_ladder_along", along)
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


func _pool_compact_ladder(salt: int) -> void:
	var layout := _pool_water_layout()
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	# Never place the guaranteed exit across a water connection: that keeps the
	# shared channel visually and physically open.
	var links: Array = layout.get("edge_links", [])
	var available: Array[int] = []
	for candidate in 4:
		if links.has(candidate):
			continue
		# A channel can end directly against a solid wall while its water still
		# reaches that cell edge. That is not a deck: placing the grab-rail
		# return there drives the ladder into/behind the wall. The transverse
		# sides always retain tiled deck, and an open dry terminus already has
		# the explicit 60cm landing, so both remain valid.
		if chunk.style == WorldGen.POOL_CHANNEL and candidate < 2 \
				and bool(chunk._edge_info(chunk.cell, candidate)["wall"]):
			continue
		available.append(candidate)
	if available.is_empty():
		available = [2, 3] if chunk.style == WorldGen.POOL_CHANNEL \
			else [0, 1, 2, 3]
	# Prefer a channel's recessed dry-room terminus. It keeps the guaranteed
	# exit on the new tiled landing and prevents a ladder from being stranded
	# on the old room seam, beside the doorway wall return.
	if chunk.style == WorldGen.POOL_CHANNEL:
		var dry_termini: Array[int] = []
		for candidate in available:
			if _pool_open_dry_boundary(chunk.cell, candidate):
				dry_termini.append(candidate)
		if not dry_termini.is_empty():
			available = dry_termini
	var dir: int = available[
		int(chunk._r(salt) * float(available.size())) % available.size()]
	var span: float = size.y if dir < 2 else size.x
	var jitter: float = (
		chunk._r(salt + 1) - 0.5) * minf(1.1, span * 0.22)
	match dir:
		0:
			_pool_ledge_ladder(
				0, center.x + size.x * 0.5, center.y + jitter)
		1:
			_pool_ledge_ladder(
				1, center.x - size.x * 0.5, center.y + jitter)
		2:
			_pool_ledge_ladder(
				2, center.y + size.y * 0.5, center.x + jitter)
		_:
			_pool_ledge_ladder(
				3, center.y - size.y * 0.5, center.x + jitter)


func _pool_basin_room() -> void:
	var piers := _pool_piers(
		2300, 1 + int(chunk._r(2301) * 1.99))
	_pool_pier_island(2388, piers)
	if chunk._r(2302) < 0.42:
		_pool_window(
			0 if chunk._r(2303) < 0.5 else 1,
			lerpf(3.0, chunk.S - 3.0, chunk._r(2304)))
	_pool_float(2305)


func _pool_channel_room() -> void:
	var layout := _pool_water_layout()
	var along_x: bool = layout["axis_x"]
	if chunk._r(2310) < 0.34 and chunk.ceil_h >= 5.0:
		_pool_window(
			2 if along_x else 0,
			lerpf(3.0, chunk.S - 3.0, chunk._r(2311)))
	if chunk._r(2314) < 0.34:
		_pool_piers(2315, 1)
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


func _pool_dry_prop_spot(salt: int, radius: float,
		inset := 2.0, tries := 12) -> Vector3:
	var span := chunk.S - inset * 2.0
	for i in tries:
		var at := Vector3(
			inset + span * chunk._r(salt + i * 2),
			chunk.POOL_DRY_Y,
			inset + span * chunk._r(salt + i * 2 + 1))
		if chunk._floor_spot_clear(at, radius, 2.2):
			return at
	return Vector3.INF


func _pool_lounge_chair(at: Vector3, yaw: float) -> bool:
	if not chunk._floor_spot_clear(at, 1.05, 1.05):
		return false
	var b0 := chunk.body.get_child_count()
	var pivot := chunk._attributed_floor_prop(
		chunk.POOL_LOUNGE_CHAIR_PATH, at, yaw,
		chunk.POOL_LOUNGE_CHAIR_SCALE, chunk.POOL_LOUNGE_CHAIR_CENTRE,
		"pool_lounge_chair", null, true)
	if pivot == null:
		return false
	pivot.set_meta("pool_lounge_chair", true)
	chunk._collider_yaw_box(
		at + Vector3.UP * 0.46, Vector3(1.90, 0.92, 1.18), yaw)
	chunk._bind_furnishing_colliders(pivot, b0)
	return true


func _pool_jacuzzi(at: Vector3, yaw: float) -> bool:
	var planned := _pool_planned_jacuzzi_site()
	if (planned == Vector3.INF or at.distance_to(planned) > 0.01) \
			and not chunk._floor_spot_clear(at, 1.65, 1.25):
		return false
	var pivot := chunk._attributed_floor_prop(
		chunk.POOL_JACUZZI_PATH, at, yaw,
		chunk.POOL_JACUZZI_SCALE, chunk.POOL_JACUZZI_CENTRE,
		"pool_jacuzzi", null, true)
	if pivot == null:
		return false
	pivot.set_meta("pool_jacuzzi", true)
	# This is a drop-in spa, not a freestanding appliance. The cabinet remains
	# below the tiled floor, while the molded white rim sits about 6cm proud
	# and overlaps the smaller structural opening. No open cavity can show
	# around its curved outside corners.
	pivot.position.y -= POOL_JACUZZI_SINK
	pivot.set_meta("pool_jacuzzi_in_ground", true)
	pivot.set_meta(
		"pool_jacuzzi_deck_reveal", POOL_JACUZZI_DECK_REVEAL)
	# The imported "Ladder" is actually a separate black wooden step/cabinet
	# beyond the white bath. It belongs to the freestanding installation and
	# must not poke through the deck in the in-ground version.
	var external_step := pivot.find_child("Ladder", true, false) as Node3D
	if external_step != null:
		external_step.visible = false
		external_step.set_meta("pool_jacuzzi_external_step_hidden", true)
	# The bath already has its own molded white rim. An additional cast-stone
	# ring around it read as pool coping and made the inset tub double-rimmed.
	# The cutout remains smaller than the authored shell, so that native rim
	# alone overlaps the deck and hides the structural opening.
	var water_mesh := PlaneMesh.new()
	# The structural cutout follows the outer rim; the water remains confined
	# to the inner bath and must not expand with that cutout.
	water_mesh.size = POOL_JACUZZI_WATER_SIZE
	water_mesh.subdivide_width = 8
	water_mesh.subdivide_depth = 8
	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	water.material_override = Mats.pool_water()
	water.position = Vector3(
		POOL_JACUZZI_CENTRE_OFFSET.x,
		chunk.POOL_DRY_Y - POOL_JACUZZI_WATER_INSET - pivot.position.y,
		POOL_JACUZZI_CENTRE_OFFSET.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("pool_jacuzzi_water", true)
	pivot.add_child(water)
	_pool_jacuzzi_exit_volume(at)
	return true


func _pool_jacuzzi_exit_volume(at: Vector3) -> void:
	# Four narrow climb strips hug the inside of the opening. Walking into any
	# wall of the tub while holding forward lifts the player to deck height;
	# the volume ends below the standing query point, so it cannot catch a
	# player who is already safely on the deck.
	var hole_center := _pool_jacuzzi_center(at)
	var area := Area3D.new()
	area.name = "JacuzziExitVolume"
	area.position = Vector3(hole_center.x, 0.75, hole_center.z)
	area.set_meta("pool_ladder_volume", true)
	area.set_meta("pool_jacuzzi_exit_volume", true)
	area.collision_layer = Player.LADDER_LAYER
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = false
	var strip := 0.44
	var inset := 0.18
	var height := 2.60
	var shapes := [
		[
			Vector3(
				-POOL_JACUZZI_EXIT_SIZE.x * 0.5 + inset, 0.0, 0.0),
			Vector3(strip, height, POOL_JACUZZI_EXIT_SIZE.y - 0.12),
		],
		[
			Vector3(
				POOL_JACUZZI_EXIT_SIZE.x * 0.5 - inset, 0.0, 0.0),
			Vector3(strip, height, POOL_JACUZZI_EXIT_SIZE.y - 0.12),
		],
		[
			Vector3(
				0.0, 0.0,
				-POOL_JACUZZI_EXIT_SIZE.y * 0.5 + inset),
			Vector3(POOL_JACUZZI_EXIT_SIZE.x - 0.12, height, strip),
		],
		[
			Vector3(
				0.0, 0.0,
				POOL_JACUZZI_EXIT_SIZE.y * 0.5 - inset),
			Vector3(POOL_JACUZZI_EXIT_SIZE.x - 0.12, height, strip),
		],
	]
	for shape_data in shapes:
		var cs := CollisionShape3D.new()
		cs.position = shape_data[0]
		var box := BoxShape3D.new()
		box.size = shape_data[1]
		cs.shape = box
		area.add_child(cs)
	chunk.add_child(area)


func _pool_lounge_group(salt: int) -> void:
	var first := _pool_dry_prop_spot(salt, 1.05)
	if first == Vector3.INF:
		return
	var yaw := chunk._r(salt + 30) * TAU
	if not _pool_lounge_chair(first, yaw):
		return
	# A second lounger makes a recognisable poolside group, but remains optional
	# when the room's piers or doorway clearances leave only one safe footprint.
	var side := Vector3(cos(yaw), 0.0, -sin(yaw)) * 1.45
	var second := first + side
	if second.x > 1.6 and second.x < chunk.S - 1.6 \
			and second.z > 1.6 and second.z < chunk.S - 1.6:
		_pool_lounge_chair(second, yaw)


func _pool_jacuzzi_landmark(_salt: int) -> void:
	var at := _pool_planned_jacuzzi_site()
	if at != Vector3.INF:
		# The slab cutout follows the authored bath axes, so keep every inset
		# jacuzzi aligned with that aperture.
		_pool_jacuzzi(at, 0.0)


func _pool_start_room_props() -> void:
	# Cell zero is always the arrival deck. Give visual QA a stable, immediate
	# example of both new assets instead of hiding them behind procedural odds.
	_pool_lounge_chair(
		Vector3(3.0, chunk.POOL_DRY_Y, 7.1), 0.0)
	_pool_lounge_chair(
		Vector3(3.0, chunk.POOL_DRY_Y, 9.5), 0.0)
	_pool_jacuzzi(_pool_planned_jacuzzi_site(), 0.0)


func _pool_deck_room() -> void:
	# Dry. The arrival deck stays clear enough to introduce the authored props;
	# later decks retain the irregular structural-pier rhythm.
	var dir = int(chunk._r(2320) * 3.99)
	if chunk.cell == Vector2i.ZERO:
		if chunk._r(2324) < 0.6:
			_pool_window(dir, lerpf(3.0, chunk.S - 3.0, chunk._r(2325)))
		_pool_start_room_props()
		return
	var planned_jacuzzi := _pool_planned_jacuzzi_site()
	if planned_jacuzzi == Vector3.INF:
		_pool_piers(2322, 2 + int(chunk._r(2323) * 1.99))
	if chunk._r(2324) < 0.6:
		_pool_window(dir, lerpf(3.0, chunk.S - 3.0, chunk._r(2325)))
	var furnishing_roll := chunk._r(2410)
	if furnishing_roll < 0.48:
		_pool_lounge_group(2411)
	elif furnishing_roll < 0.70:
		_pool_jacuzzi_landmark(2411)
	elif furnishing_roll < 0.84:
		_pool_lone_chair(2411)


func _pool_solarium_room() -> void:
	# The room the light comes into: a wall of tall windows and almost nothing
	# else, so the shafts have the whole space to fall through.
	var dir = int(chunk._r(2330) * 3.99)
	for i in 3:
		_pool_window(dir, 2.6 + float(i) * 3.4)
	_pool_piers(2331, 2)
	if chunk._r(2332) < 0.82:
		_pool_lounge_group(2333)


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
		if not bool(chunk._edge_info(chunk.cell, dir)["wall"]):
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
	# furnished with one implausibly preserved spa or a lone plastic chair.
	var planned_jacuzzi := _pool_planned_jacuzzi_site()
	if planned_jacuzzi == Vector3.INF:
		_pool_piers(2340, 1 + int(chunk._r(2341) * 1.99))
	if planned_jacuzzi != Vector3.INF:
		_pool_jacuzzi_landmark(2345)
	else:
		_pool_lone_chair(2345)


func _pool_stairs_room() -> void:
	if chunk._r(2354) < 0.42:
		_pool_piers(2355, 1)
	if chunk._r(2356) < 0.40:
		_pool_window(
			int(chunk._r(2357) * 4.0) % 4,
			lerpf(3.0, chunk.S - 3.0, chunk._r(2358)))
	_pool_float(2353)


func _pool_gallery_room() -> void:
	var dir = int(chunk._r(2360) * 3.99)
	_pool_handrail(dir, 1.5)
	_pool_piers(2361, 3 + int(chunk._r(2362) * 2.99))
	if chunk._r(2363) < 0.5:
		_pool_window((dir + 2) % 4, lerpf(3.0, chunk.S - 3.0, chunk._r(2364)))


func _pool_cistern_room() -> void:
	_pool_piers(2370, 2 + int(chunk._r(2372) * 1.99))
	if chunk._r(2373) < 0.55:
		_pool_window(
			int(chunk._r(2374) * 4.0) % 4,
			lerpf(3.0, chunk.S - 3.0, chunk._r(2375)))
	_pool_float(2371)
