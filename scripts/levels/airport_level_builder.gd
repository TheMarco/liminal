extends "res://scripts/levels/chunk_level_builder.gd"
static var _carousel_belt_material: ShaderMaterial
static var _walkway_fitted_meshes: Dictionary = {}
static var _walkway_glass_material: StandardMaterial3D
# Authored ramps project 56cm past each nominal belt end. Leave a full 1.24m
# floor cross-aisle beyond them (over 1.1m clear even beside a boundary wall).
const WALKWAY_RAMP_OVERHANG := 0.56
const WALKWAY_END_AISLE := 1.24


func _air_zone_sign(salt: int) -> String:
	var zone = WorldGen.macro_zone(ctx.world_seed, ctx.cell, ctx.theme)
	var labels: Array = Chunk.AIR_ZONE_SIGNS[zone]
	return labels[int(ctx.random01(salt) * (float(labels.size()) - 0.01))]


func _air_pick_wall(salt: int) -> int:
	return WorldGen.anchor_wall(ctx.world_seed, ctx.cell, salt)


## Yaw that points a node's local +z at the given edge.


func _gate_code() -> String:
	var letters = ["A", "B", "C", "D", "E"]
	return "%s%d" % [letters[int(ctx.random01(300) * 4.99)], 1 + int(ctx.random01(301) * 27.99)]


func _air_ceiling_fixture(desired: Vector3, panels: Vector2i,
		material: Material, ceiling_y: float, vent := false) -> Node3D:
	var origin := Vector2(ctx.cell) * WorldGen.CELL_SIZE
	var snapped := AirportCeilingGrid.center(Vector2(desired.x, desired.z) + origin, panels) - origin
	var fixture := Node3D.new()
	fixture.position = Vector3(snapped.x, ceiling_y, snapped.y)
	fixture.set_meta("airport_ceiling_fixture", "vent" if vent else "light")
	fixture.set_meta("airport_ceiling_panels", panels)
	scene.add_node(fixture)
	var size := AirportCeilingGrid.outer_size(panels)
	var rim := AirportCeilingGrid.FRAME
	# The diffuser is recessed above a slim painted T-bar frame. Every outer
	# edge, including the frame, lands exactly on the acoustic panel lattice.
	scene.model_box(fixture, Vector3(0, -0.028, 0),
		Vector3(size.x - rim * 2.0, 0.025, size.y - rim * 2.0), material)
	for sign in [-1.0, 1.0]:
		scene.model_box(fixture, Vector3(0, -0.052, sign * (size.y - rim) * 0.5),
			Vector3(size.x, 0.045, rim), Mats.paint_white())
		scene.model_box(fixture, Vector3(sign * (size.x - rim) * 0.5, -0.052, 0),
			Vector3(rim, 0.045, size.y - rim * 2.0), Mats.paint_white())
	if vent:
		for i in 6:
			scene.model_box(fixture, Vector3(0, -0.047, (float(i) - 2.5) * 0.074),
				Vector3(size.x - 0.10, 0.016, 0.035), Mats.metal_gray())
	return fixture


func _air_lighting() -> void:
	if ctx.style == WorldGen.AIR_TRANSIT:
		return  # transit corridors light themselves under the dropped bulkhead
	var is_spawn = ctx.cell == Vector2i.ZERO
	var dead = (not is_spawn) and ctx.random01(8) < 0.04
	var flicker = (not is_spawn) and (not dead) and ctx.random01(9) < 0.11
	var grand := AirportGrandCeiling.applies(ctx.ceiling_height, ctx.style)
	var lit_material := Mats.air_coffer_light() if grand else Mats.air_panel()
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = lit_material.duplicate()
	else:
		pmat = lit_material
	# Two-panel rectangular diffusers on a regular grid. Narrower gate rooms
	# use single-panel squares; both share the exact same seams and trim.
	if grand:
		var ceiling := Node3D.new()
		ceiling.name = "GrandTerminalCeiling"
		AirportGrandCeiling.attach(ceiling, ctx.ceiling_height, ctx.style, pmat)
		scene.add_node(ceiling)
	else:
		var panels := Vector2i.ONE if ctx.style == WorldGen.AIR_GATE else Vector2i(2, 1)
		for gx in [3.0, 9.0]:
			for gz in [2.5, 6.0, 9.5]:
				_air_ceiling_fixture(Vector3(gx, 0, gz), panels, pmat, ctx.ceiling_height)
		for z in [3.6, 8.4]:
			_air_ceiling_fixture(Vector3(6, 0, z), Vector2i.ONE,
				Mats.charcoal(), ctx.ceiling_height, true)
	if dead:
		return
	var energy := lerpf(1.35, 1.9, clampf((ctx.ceiling_height - 3.2) / 3.0, 0.0, 1.0))
	var light_drop := AirportGrandCeiling.depth(ctx.ceiling_height, ctx.style) + 0.30 if grand else 0.6
	var source := Vector3(6.0, ctx.ceiling_height - light_drop, 6.0)
	if not grand:
		source = Vector3(3.0, ctx.ceiling_height - 0.6, 2.5)
	var light = scene.fixture_light(flicker, pmat, energy, source,
		"airport_grand_coffer" if grand else "airport_ceiling_fixture")
	light.light_color = Color(1.0, 0.95, 0.84) if grand else Color(0.94, 0.97, 1.0)
	light.omni_attenuation = 0.85
	light.omni_range = 14.5
	light.shadow_enabled = true
	# One point light represents a ceiling grid of broad diffusers. Its hard,
	# fully opaque shadows made bright terminal walls turn abruptly black.
	light.shadow_opacity = 0.55
	light.shadow_blur = 3.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	scene.add_node(light)


## Overhead wayfinding hung from the deck above: navy backlit box, yellow
## text both sides, twin drop rods.


func _hang_sign(pos: Vector3, yaw: float, text: String, top = 0.0) -> void:
	if top <= 0.0 and AirportGrandCeiling.applies(ctx.ceiling_height, ctx.style):
		var soffit := ctx.ceiling_height - AirportGrandCeiling.depth(ctx.ceiling_height, ctx.style)
		pos.y = minf(pos.y, soffit - 0.43)
	var v = Node3D.new()
	v.position = pos
	v.rotation.y = yaw
	v.set_meta("airport_sign_body_height", 0.55)
	scene.add_node(v)
	var w = maxf(1.6, 0.115 * float(text.length()) + 0.55)
	var rod_h = maxf(0.1, (top if top > 0.0 else ctx.ceiling_height) - pos.y - 0.275)
	for sx in [-w * 0.36, w * 0.36]:
		scene.model_cylinder(v, Vector3(sx, 0.275 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	scene.model_rounded_box(v, Vector3.ZERO, Vector3(w, 0.55, 0.09), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb = Label3D.new()
		lb.text = text
		lb.font_size = 96
		lb.pixel_size = 0.0024
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0, sside * 0.055)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Built by the canonical edge owner: a wayfinding sign hung just inside the
## portal, pointing deeper into a terminal that never ends.


func _air_portal_sign(dir: int, t: float) -> void:
	if ctx.style == WorldGen.AIR_TRANSIT:
		return  # would poke through the transit bulkhead
	var txt = _air_zone_sign(345 + dir)
	if dir == 0:
		_hang_sign(Vector3(WorldGen.CELL_SIZE - 0.8, Chunk.AIR_DOOR + 0.6, t), PI / 2.0, txt)
	else:
		_hang_sign(Vector3(t, Chunk.AIR_DOOR + 0.6, WorldGen.CELL_SIZE - 0.8), 0.0, txt)


## Authored three-panel departures board. Its black display panels are left
## intact and carry the same deterministic live flight rows as the old
## generated FIDS, so the housing can change without losing world-specific data.


func _fids(parent: Node3D, lpos: Vector3, lyaw: float, big: bool, hang: bool) -> void:
	var v = Node3D.new()
	v.position = lpos
	v.rotation.y = lyaw
	v.set_meta("attributed_furnishing", "airport_departure_board")
	if parent == null:
		scene.add_node(v)
	else:
		parent.add_child(v)
	var model_scale: float = Chunk.AIRPORT_DEPARTURE_BOARD_BIG_SCALE if big \
		else Chunk.AIRPORT_DEPARTURE_BOARD_SMALL_SCALE
	var original_scale: float = model_scale
	if hang and AirportGrandCeiling.applies(ctx.ceiling_height, ctx.style):
		# The board must fit BETWEEN passenger headroom and the new soffit,
		# rather than burying its header in a coffer or lowering it into heads.
		var soffit := ctx.ceiling_height - AirportGrandCeiling.depth(ctx.ceiling_height, ctx.style)
		var max_top := soffit - 0.18
		model_scale = minf(model_scale, (max_top - 2.25) / Chunk.AIRPORT_DEPARTURE_BOARD_UNITS.y)
		var half_h := Chunk.AIRPORT_DEPARTURE_BOARD_UNITS.y * model_scale * 0.5
		lpos.y = clampf(lpos.y, 2.25 + half_h, max_top - half_h)
		v.position = lpos
	var w = Chunk.AIRPORT_DEPARTURE_BOARD_UNITS.x * model_scale
	var h = Chunk.AIRPORT_DEPARTURE_BOARD_UNITS.y * model_scale
	if hang:
		v.set_meta("airport_hanging_board_height", h)
		var rod_h = maxf(0.1, ctx.ceiling_height - lpos.y - h / 2.0)
		for sx in [-w * 0.36, w * 0.36]:
			scene.model_cylinder(v, Vector3(sx, h / 2.0 + rod_h / 2.0, -0.04),
				0.016, rod_h, Mats.charcoal())
	var board = scene.attributed_prop_local(v, Chunk.AIRPORT_DEPARTURE_BOARD_PATH,
		-Chunk.AIRPORT_DEPARTURE_BOARD_CENTRE * model_scale, 0.0,
		Vector3.ONE * model_scale)
	var front_z = Chunk.AIRPORT_DEPARTURE_BOARD_UNITS.z * model_scale * 0.52
	if board != null:
		board.set_meta("authored_model", "airport_departure_board")
	else:
		# A generated fallback keeps airport construction robust if the imported
		# scene is unavailable in an editor-only or stripped export.
		scene.model_rounded_box(v, Vector3(0, 0, -0.045), Vector3(w, h, 0.13),
			Mats.charcoal(), 0.02)
		scene.model_quad(v, Vector3(0, 0, 0.022), Vector2(w - 0.12, h - 0.12),
			Mats.screen_glow())
		var hd = Label3D.new()
		hd.text = "DEPARTURES"
		hd.font_size = 54 if big else 36
		hd.pixel_size = (0.0022 if big else 0.0018) * model_scale / original_scale
		hd.modulate = Color(0.93, 0.96, 1.0)
		hd.position = Vector3(0, h / 2.0 - 0.17, 0.03)
		v.add_child(hd)
		front_z = 0.03
	var rows = 8 if big else 4
	var dest = ""
	var tim = ""
	var gate = ""
	var stat = ""
	for i in rows:
		var hsh = WorldGen.h(ctx.world_seed, ctx.cell.x * 3 + i, ctx.cell.y - i, 350)
		dest += Chunk.AIR_DESTS[hsh % Chunk.AIR_DESTS.size()] + "\n"
		tim += "%02d:%02d\n" % [(hsh >> 3) % 24, ((hsh >> 8) % 12) * 5]
		gate += "%s%d\n" % [["A", "B", "C", "D"][(hsh >> 13) % 4], 1 + ((hsh >> 15) % 28)]
		stat += Chunk.AIR_STATUS[(hsh >> 19) % Chunk.AIR_STATUS.size()] + "\n"
	# Destination occupies the left panel; time and gate share the centre;
	# status sits on the right. Positions scale with both board variants.
	var xs = [-0.444, -0.031, 0.153, 0.291]
	var texts = [dest, tim, gate, stat]
	for ci in 4:
		var lb = Label3D.new()
		lb.text = texts[ci]
		lb.font_size = 40 if big else 24
		lb.pixel_size = (0.0018 if big else 0.0016) * model_scale / original_scale
		lb.modulate = Color(1.0, 0.72, 0.18)
		lb.outline_modulate = Color(0.16, 0.08, 0.0, 0.8)
		lb.outline_size = 0
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Clear the model's own "All other airlines" subheader before the first
		# data row; keeping this relative preserves the spacing on both sizes.
		lb.position = Vector3(xs[ci] * w, h / 2.0 - h * 0.26, front_z)
		v.add_child(lb)


func _air_wall_fids(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (Chunk.T / 2.0)
	var along = WorldGen.CELL_SIZE / 2.0 + (ctx.random01(46 + dir) - 0.5) * 4.0
	var yaw = 0.0
	var pos: Vector3
	if dir < 2:
		yaw = PI / 2.0 if n > 0.0 else -PI / 2.0
		pos = Vector3(inner + n * 0.10, 2.5, along)
	else:
		yaw = 0.0 if n > 0.0 else PI
		pos = Vector3(along, 2.5, inner + n * 0.10)
	_fids(null, pos, yaw, false, false)


## Pair of backlit advertising lightboxes.


func _air_adboxes(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (Chunk.T / 2.0)
	var idx = int(ctx.random01(50 + dir) * float(Chunk.POSTER_AIRPORT.size()) * 0.99)
	for k in 2:
		var along = WorldGen.CELL_SIZE / 2.0 + (float(k) - 0.5) * 3.4
		var fc = inner + n * 0.05
		var poster_path := str(Chunk.POSTER_AIRPORT[
			posmod(idx + k, Chunk.POSTER_AIRPORT.size())])
		var lightbox_mat := Mats.poster_lightbox(poster_path)
		if dir < 2:
			scene.box(Vector3(fc, 1.9, along), Vector3(0.08, 1.92, 1.32), Mats.charcoal(), false)
			var q = scene.quad(Vector3(fc + n * 0.045, 1.9, along), Vector2(1.2, 1.6), lightbox_mat)
			q.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
			q.set_meta("airport_poster_lightbox", true)
			q.set_meta("airport_poster_path", poster_path)
			q.set_meta("airport_poster_aspect", 0.75)
		else:
			scene.box(Vector3(along, 1.9, fc), Vector3(1.32, 1.92, 0.08), Mats.charcoal(), false)
			var q = scene.quad(Vector3(along, 1.9, fc + n * 0.045), Vector2(1.2, 1.6), lightbox_mat)
			q.rotation.y = 0.0 if n > 0.0 else PI
			q.set_meta("airport_poster_lightbox", true)
			q.set_meta("airport_poster_path", poster_path)
			q.set_meta("airport_poster_aspect", 0.75)


## Authored four-seat airport bank. Existing layouts asked for three to five
## generated seats; the real model keeps its designed proportions in all of
## those placements instead of being stretched to an arbitrary count.


func _seat_row(p: Vector3, yaw: float, _n: int, _salt: int) -> void:
	var body0 = scene.collider_mark()
	var row = scene.furnishing_pivot(p, yaw, "airport_seat_row")
	row.set_meta("airport_seat_facing_yaw", yaw)
	var seats = scene.attributed_floor_prop(Chunk.AIRPORT_SEATS_PATH, Vector3.ZERO,
		PI / 2.0, Chunk.AIRPORT_SEATS_SCALE, Chunk.AIRPORT_SEATS_CENTRE,
		"airport_seats", row)
	if seats == null:
		row.get_parent().remove_child(row)
		row.free()
		return
	var staged_root = seats.find_child("RootNode", true, false)
	if staged_root != null:
		for staged_name in ["Light", "Camera", "Light_001", "Light_002"]:
			var staged = staged_root.find_child(staged_name, false, false)
			if staged != null:
				staged_root.remove_child(staged)
				staged.free()
	scene.collider_yaw_box(p + Vector3(0, 0.414, 0),
		Vector3(2.10, 0.83, 0.62), yaw)
	scene.bind_furnishing_colliders(row, body0)


## One piece from the authored luggage set. The GLB was material-merged, so
## pieces are recovered by their mesh-node membership instead of by subtree.
## `backpack_only` replaces the old "lying suitcase" use with the source set's
## naturally low backpack instead of tipping a rigid case onto an arbitrary side.


func _airport_luggage_model(parent: Node3D, p: Vector3, yaw: float,
		salt: int, backpack_only = false) -> Node3D:
	var piece = 0 if backpack_only else mini(int(ctx.random01(salt) * 3.0), 2)
	var pivot = Node3D.new()
	pivot.name = "AirportLuggage"
	pivot.position = p
	pivot.rotation.y = yaw
	pivot.set_meta("attributed_furnishing", "airport_luggage")
	pivot.set_meta("airport_luggage_piece", piece)
	parent.add_child(pivot)
	var inst = scene.attributed_prop_local(pivot, Chunk.AIRPORT_LUGGAGE_PATH,
		-Chunk.AIRPORT_LUGGAGE_CENTRES[piece] * Chunk.AIRPORT_LUGGAGE_SCALE, 0.0,
		Vector3.ONE * Chunk.AIRPORT_LUGGAGE_SCALE)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	inst.set_meta("authored_model", "airport_luggage")
	var keep: Array = Chunk.AIRPORT_LUGGAGE_NODES[piece]
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	for found in meshes:
		var mesh_node = found as MeshInstance3D
		if not keep.has(String(mesh_node.name)):
			mesh_node.get_parent().remove_child(mesh_node)
			mesh_node.free()
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source = mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not Chunk.AIRPORT_LUGGAGE_BODY_MATERIALS.has(source.resource_name):
				continue
			var tinted = source.duplicate() as BaseMaterial3D
			var tint: Color = Chunk.AIRPORT_LUGGAGE_PALETTE[
				mini(int(ctx.random01(salt + 19) * Chunk.AIRPORT_LUGGAGE_PALETTE.size()),
					Chunk.AIRPORT_LUGGAGE_PALETTE.size() - 1)]
			if source.resource_name.ends_with("_02") \
					or source.resource_name.ends_with("_streep"):
				tint = tint.lightened(0.16)
			tinted.albedo_color = tint
			mesh_node.set_surface_override_material(surface, tinted)
	return pivot


## Loose airport luggage gets a conservative physical footprint and remains an
## atomic furnishing for doorway/prop-overlap culling.
## A bag standing on the floor on its own. It is registered as a furnishing —
## not just a model with a collider — so doorway clearance can remove it and the
## prop-overlap audit can see it. Without a `furnishing_group` its colliders
## stay untagged, and untagged colliders are invisible to both.


func _airport_luggage(p: Vector3, yaw: float, salt: int,
		backpack_only = false) -> void:
	var body0 = scene.collider_mark()
	var group = scene.furnishing_pivot(p, yaw, "airport_luggage")
	var pivot = _airport_luggage_model(group, Vector3.ZERO, 0.0, salt,
		backpack_only)
	if pivot == null:
		group.get_parent().remove_child(group)
		group.free()
		return
	var piece: int = pivot.get_meta("airport_luggage_piece")
	var collider: Vector3 = Chunk.AIRPORT_LUGGAGE_COLLIDERS[piece]
	scene.collider_yaw_box(p + Vector3(0, collider.y * 0.5, 0), collider, yaw)
	scene.bind_furnishing_colliders(group, body0)


func _air_column(p: Vector2) -> void:
	# The shaft, floor shoe and ceiling cap are one structural assembly. Keeping
	# them as top-level siblings let doorway clearance remove the shaft while
	# leaving its low steel shoe behind as a mysterious "hockey puck".
	var pivot = scene.furnishing_pivot(Vector3(p.x, 0, p.y), 0.0, "airport_column")
	var b0 = scene.collider_mark()
	scene.model_cylinder(pivot, Vector3(0, ctx.ceiling_height / 2.0, 0), 0.34, ctx.ceiling_height, Mats.paint_white())
	scene.model_cylinder(pivot, Vector3(0, 0.09, 0), 0.40, 0.18, Mats.steel())
	scene.model_cylinder(pivot, Vector3(0, ctx.ceiling_height - 0.15, 0), 0.40, 0.3, Mats.charcoal())
	var detail_key = "air_column_h%.3f" % ctx.ceiling_height
	ProceduralDetails.attach(pivot, detail_key, func(d: ProceduralDetails) -> void:
		# Narrow collars break up the otherwise featureless shaft.  The cover is
		# shallow enough to remain inside the column's existing floor shoe.
		d.ring(Vector3(0, 0.22, 0), 0.345, 0.012, Mats.steel())
		d.ring(Vector3(0, ctx.ceiling_height - 0.32, 0), 0.345, 0.012, Mats.steel())
		d.box(Vector3(0, 0.82, -0.337), Vector3(0.19, 0.28, 0.014),
			Mats.metal_gray(), 0.012)
	)
	scene.collider_cylinder(pivot.position + Vector3(0, ctx.ceiling_height / 2.0, 0), 0.34, ctx.ceiling_height)
	scene.bind_furnishing_colliders(pivot, b0)


func _air_bin(p: Vector3) -> void:
	scene.waste_bin(p, ctx.random01(int(p.x * 7.0 + p.z * 13.0) + 431) * TAU, "airport_bin")


## Authored four-caster steel trolley (optionally a rank of them).


func _air_trolley(p: Vector3, yaw: float, salt: int, count = 1) -> void:
	if count <= 0:
		return
	var ps = scene.prop_scene(Chunk.AIRPORT_TROLLEY_PATH)
	if ps == null:
		push_error("Airport trolley asset failed to load: %s" % Chunk.AIRPORT_TROLLEY_PATH)
		return
	var b0 = scene.collider_mark()
	var rank = scene.furnishing_pivot(p, yaw, "airport_trolley_rank")
	rank.name = "AirportTrolleyRank"
	rank.set_meta("airport_trolley_rank", true)
	rank.set_meta("trolley_count", count)
	for k in count:
		var v := Node3D.new()
		v.name = "AirportTrolley"
		v.position = Vector3(0, 0, 0.55 * float(k))
		v.set_meta("airport_trolley", true)
		v.set_meta("trolley_index", k)
		rank.add_child(v)
		var inst := ps.instantiate() as Node3D
		v.add_child(inst)
		inst.set_meta("authored_asset", Chunk.AIRPORT_TROLLEY_PATH)
		# Frontmost load avoids nesting intersection with the next cart's sign panel.
		if k == count - 1 and ctx.random01(salt + 7) < 0.4:
			# Contact height and tilt follow the authored platform's slope.
			var bag = _airport_luggage_model(v, Vector3(0, 0.3253, 0.06), 0.0,
				salt + 8, true)
			if bag != null:
				bag.rotation.x = -atan(0.055)
				bag.set_meta("airport_trolley_load", true)
	var dv = Vector3(sin(yaw), 0, cos(yaw))
	var cc = p + dv * (0.275 * float(count - 1))
	scene.collider_yaw_box(cc + Vector3(0, 0.58, 0), Vector3(0.70, 1.16, 1.10 + 0.55 * float(count - 1)), yaw)
	scene.bind_furnishing_colliders(rank, b0)


## Chrome queue posts with retractable belts strung between them.


func _stanchion_line(a: Vector3, b: Vector3, n: int) -> void:
	var line_yaw = atan2((b - a).x, (b - a).z)
	for i in n:
		var t = float(i) / float(n - 1)
		var pp = a.lerp(b, t)
		scene.cylinder(pp + Vector3(0, 0.49, 0), 0.028, 0.98, Mats.chrome())
		scene.cylinder(pp + Vector3(0, 0.015, 0), 0.16, 0.03, Mats.chrome(), false)
		scene.cylinder(pp + Vector3(0, 0.95, 0), 0.045, 0.06, Mats.charcoal(), false)
		var reel = Node3D.new()
		reel.position = pp
		reel.rotation.y = line_yaw
		scene.add_node(reel)
		ProceduralDetails.attach(reel, "air_stanchion_reel_v2", func(d: ProceduralDetails) -> void:
			d.box(Vector3(0, 0.95, 0), Vector3(0.13, 0.105, 0.085), Mats.charcoal(), 0.025)
			d.box(Vector3(0, 0.91, -0.049), Vector3(0.065, 0.07, 0.014), Mats.steel(), 0.004)
			d.box(Vector3(0, 0.91, 0.049), Vector3(0.065, 0.07, 0.014), Mats.steel(), 0.004)
		)
	for i in n - 1:
		var p0 = a.lerp(b, float(i) / float(n - 1)) + Vector3(0, 0.88, 0)
		var p1 = a.lerp(b, float(i + 1) / float(n - 1)) + Vector3(0, 0.88, 0)
		var bl = scene.beam(p0 + (p1 - p0) * 0.06, p1 - (p1 - p0) * 0.06, 0.045, Mats.rubber_black())
		bl.scale.y = 0.022
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- airport: gate ------------------------------------------------------------


func _air_gate() -> void:
	var wdir = _air_pick_wall(310)
	var yw = scene.yaw_for(wdir) if wdir >= 0 else float(int(ctx.random01(311) * 3.99)) * PI / 2.0
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var code = _gate_code()
	if wdir >= 0:
		_air_window_wall(o, yw)
	# carpet island under the lounge
	var cp = scene.world_point(o, Vector3(0, 0.008, -1.2), yw)
	var cm = scene.model_box(null, cp, Vector3(10.6, 0.016, 6.6), Mats.airport_carpet())
	cm.rotation.y = yw
	# gate desk off to one side, facing the seats
	_air_gate_desk(o, yw, code)
	# Every lounge row faces the glass. A single deliberately flipped bank used
	# to make the whole gate read as randomly rotated furniture.
	var ri = 0
	for rz in [0.7, -1.1, -2.9]:
		for rx in [-1.9, 1.9]:
			_seat_row(scene.world_point(o, Vector3(rx, 0, rz), yw), yw, 4, 313 + ri)
			ri += 1
	# a bag that never boarded
	if ctx.random01(318) < 0.55:
		_airport_luggage(scene.world_point(o, Vector3(-2.6 + 5.2 * ctx.random01(319), 0, 1.6), yw),
			ctx.random01(320) * TAU, 321)
	if ctx.random01(330) < 0.72:
		scene.security_camera(scene.world_point(o, Vector3(4.7, 3.55, 3.8), yw), yw + PI)


## Full-height glass curtain wall 2.2m inside the anchor wall; the strip
## behind it is the night: black apron, taxiway lights, a docked jetway.


func _air_window_wall(o: Vector3, yw: float) -> void:
	var W = Node3D.new()
	W.position = o
	W.rotation.y = yw
	scene.add_node(W)
	var gz = 3.8   # glass plane, local z
	# mullions and transoms
	for mx in [-5.95, -4.0, -2.0, 0.0, 2.0, 4.0, 5.95]:
		scene.model_box(W, Vector3(mx, ctx.ceiling_height / 2.0, gz), Vector3(0.09, ctx.ceiling_height, 0.14), Mats.charcoal())
	scene.model_box(W, Vector3(0, 0.06, gz), Vector3(WorldGen.CELL_SIZE, 0.12, 0.14), Mats.charcoal())
	scene.model_box(W, Vector3(0, ctx.ceiling_height - 0.07, gz), Vector3(WorldGen.CELL_SIZE, 0.14, 0.14), Mats.charcoal())
	for ty in [1.35, 2.9]:
		scene.model_box(W, Vector3(0, ty, gz), Vector3(WorldGen.CELL_SIZE, 0.07, 0.10), Mats.charcoal())
	# The glass itself — one thin sheet, one collider. Airport glazing uses a
	# stronger blue-grey tint than generic decorative glass so the collision
	# plane never reads as empty air.
	var barrier_glass = scene.model_box(W, Vector3(0, ctx.ceiling_height / 2.0, gz),
		Vector3(WorldGen.CELL_SIZE - 0.1, ctx.ceiling_height - 0.2, 0.024), Mats.airport_glass())
	barrier_glass.set_meta("airport_barrier_glass", true)
	barrier_glass.set_meta("barrier_alpha", 0.62)
	scene.collider_yaw_box(scene.world_point(o, Vector3(0, ctx.ceiling_height / 2.0, gz), yw), Vector3(WorldGen.CELL_SIZE, ctx.ceiling_height, 0.1), yw)
	# Two rows of ceramic manifestation dots make the full-height pane legible
	# head-on without turning the apron view into an opaque wall.
	for row_y in [1.28, 1.58]:
		for i in 16:
			var mx = -5.55 + 0.74 * float(i)
			scene.model_rounded_box(W, Vector3(mx, row_y, gz - 0.018),
				Vector3(0.12, 0.045, 0.012), Mats.airport_glass_marker(), 0.012)
	# dark soffit over the strip so no interior ceiling reads as "outside"
	scene.model_box(W, Vector3(0, ctx.ceiling_height - 0.10, 4.85), Vector3(WorldGen.CELL_SIZE, 0.06, 2.15), Mats.charcoal())
	# side caps close the strip ends
	for sx in [-5.9, 5.9]:
		scene.model_box(W, Vector3(sx, ctx.ceiling_height / 2.0, 4.85), Vector3(0.1, ctx.ceiling_height, 2.1), Mats.charcoal())
		scene.collider_yaw_box(scene.world_point(o, Vector3(sx, ctx.ceiling_height / 2.0, 4.85), yw), Vector3(0.12, ctx.ceiling_height, 2.1), yw)
	# apron floor and the night beyond
	var ap = scene.model_box(W, Vector3(0, 0.012, 4.9), Vector3(WorldGen.CELL_SIZE, 0.022, 2.15), Mats.asphalt())
	ap.rotation.y = 0.0
	var night = scene.model_quad(W, Vector3(0, ctx.ceiling_height / 2.0, 5.82), Vector2(WorldGen.CELL_SIZE, ctx.ceiling_height), Mats.apron_night())
	night.rotation.y = PI
	# taxiway edge lights receding along the strip
	for i in 5:
		var lx = -5.0 + 2.5 * float(i)
		var taxi_pos = Vector3(lx, 0.06, 5.3)
		scene.model_sphere(W, taxi_pos, 0.045, Mats.lamp_blue())
		var l = OmniLight3D.new()
		l.light_color = Color(0.3, 0.55, 1.0)
		l.light_energy = 0.14
		l.omni_range = 2.25
		l.position = taxi_pos
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 16.0
		l.distance_fade_length = 8.0
		l.set_meta("visible_source", "taxiway_blue_beacon")
		W.add_child(l)
	_air_jetway(W)
	# most gates have their aircraft still on stand
	if ctx.random01(322) < 0.6:
		_air_docked_plane(W)
	# boarding door set into the glass, sealed
	var dx = -2.6
	for jx in [dx - 0.7, dx + 0.7]:
		scene.model_box(W, Vector3(jx, 1.15, gz), Vector3(0.12, 2.3, 0.18), Mats.steel())
	scene.model_box(W, Vector3(dx, 2.36, gz), Vector3(1.52, 0.12, 0.18), Mats.steel())
	scene.model_box(W, Vector3(dx, 1.15, gz + 0.02), Vector3(1.3, 2.3, 0.05), Mats.charcoal())
	scene.model_box(W, Vector3(dx, 1.02, gz - 0.05), Vector3(0.8, 0.06, 0.05), Mats.steel())
	scene.model_box(W, Vector3(dx - 0.25, 1.7, gz + 0.05),
		Vector3(0.3, 0.4, 0.02), Mats.airport_glass())


## Authored twin-engine airliner staged at shallow depth for the sealed apron.


func _air_docked_plane(W: Node3D) -> void:
	var ps = scene.prop_scene(Chunk.AIRPORT_PLANE_PATH)
	if ps == null:
		push_error("Airport plane asset failed to load: %s" % Chunk.AIRPORT_PLANE_PATH)
		return
	var P := Node3D.new()
	P.name = "AirportAirliner"
	P.position = Vector3(0, 0.025, 5.275)
	# Face the nose and forward boarding door toward the jetway's docking cab.
	P.rotation.y = PI
	P.scale = Vector3(1.0, minf(1.0, (ctx.ceiling_height - 0.18) / 3.41), 0.115)
	P.set_meta("airport_apron_setpiece", "docked_plane")
	P.set_meta("authored_asset", Chunk.AIRPORT_PLANE_PATH)
	W.add_child(P)
	var inst := ps.instantiate() as Node3D
	P.add_child(inst)
	for mesh in P.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.12, 0.08)
	l.light_energy = 0.22
	l.omni_range = 2.6
	l.position = Vector3(0.18, 1.95, 0)
	var beacon := scene.model_sphere(P, l.position, 0.065, Mats.lamp_red())
	beacon.set_meta("visible_source", "plane_red_beacon")
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 18.0
	l.distance_fade_length = 8.0
	P.add_child(l)
	l.set_meta("visible_source", "plane_red_beacon")


## Glass boarding bridge with a blue lift frame, service stairs and docking
## bellows. Its depth is staged for the sealed apron behind the terminal glass.


func _air_jetway(W: Node3D) -> void:
	var ps = scene.prop_scene(Chunk.AIRPORT_JETWAY_PATH)
	if ps == null:
		push_error("Airport jetway asset failed to load: %s" % Chunk.AIRPORT_JETWAY_PATH)
		return
	var J := Node3D.new()
	J.name = "AirportJetway"
	J.position = Vector3(0.55, 0.024, 4.4)
	# Keep the bridge floor below the aircraft windows in the shallow apron.
	J.scale = Vector3(1.0, 0.76 * minf(1.0, (ctx.ceiling_height - 0.18) / 3.41), 0.42)
	J.set_meta("authored_asset", Chunk.AIRPORT_JETWAY_PATH)
	J.set_meta("airport_apron_setpiece", "jetway")
	W.add_child(J)
	var inst := ps.instantiate() as Node3D
	J.add_child(inst)
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 0.22
	l.omni_range = 2.6
	l.position = Vector3(2.61, 3.36, -0.58)
	var beacon := scene.model_sphere(J, l.position, 0.065, Mats.lamp_red())
	beacon.set_meta("visible_source", "jetway_red_beacon")
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 18.0
	l.distance_fade_length = 8.0
	J.add_child(l)
	l.set_meta("visible_source", "jetway_red_beacon")


func _air_gate_desk(o: Vector3, yw: float, code: String) -> void:
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(scene.world_point(o, Vector3(1.7, 0, 2.45), yw),
		yw, "airport_gate_desk")
	var model = scene.attributed_prop_local(v, Chunk.AIRPORT_GATE_DESK_PATH, Vector3.ZERO, 0.0)
	if model != null:
		# Passenger fascia faces -Z; screens and open cabinet bays face staff +Z.
		for box in [
			[Vector3(0, 0.58, -0.48), Vector3(2.40, 1.16, 0.13)],
			[Vector3(-1.18, 0.49, 0.13), Vector3(0.10, 0.98, 1.0)],
			[Vector3(1.18, 0.49, 0.13), Vector3(0.10, 0.98, 1.0)],
			[Vector3(0, 0.929, 0.045), Vector3(2.30, 0.056, 1.05)],
			[Vector3(-0.97, 0.472, -0.16), Vector3(0.28, 0.86, 0.55)],
			[Vector3(0.97, 0.472, -0.16), Vector3(0.28, 0.86, 0.55)],
			[Vector3(0, 0.47, -0.13), Vector3(0.06, 0.86, 0.56)],
		]:
			scene.collider_yaw_box(scene.world_point(v.position, box[0], yw), box[1], yw)
		for x in [-0.58, 0.58]:
			scene.collider_yaw_box(scene.world_point(v.position, Vector3(x, 1.265, -0.17), yw),
				Vector3(0.47, 0.305, 0.047), yw)
		scene.bind_furnishing_colliders(v, b0)
	# the lit gate sign overhead
	var sv = Node3D.new()
	var sign_y = minf(3.4, ctx.ceiling_height - 0.45)
	sv.position = scene.world_point(o, Vector3(1.7, sign_y, 1.7), yw)
	sv.rotation.y = yw
	scene.add_node(sv)
	var rod_h = ctx.ceiling_height - sign_y - 0.34
	for sx in [-0.5, 0.5]:
		scene.model_cylinder(sv, Vector3(sx, 0.34 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	scene.model_rounded_box(sv, Vector3.ZERO, Vector3(1.5, 0.68, 0.1), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb = Label3D.new()
		lb.text = "Gate %s" % code
		lb.font_size = 110
		lb.pixel_size = 0.0028
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0.1, sside * 0.06)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(lb)
		var st = Label3D.new()
		st.text = "FLIGHT CLOSED"
		st.font_size = 56
		st.pixel_size = 0.0024
		st.modulate = Color(1.0, 0.45, 0.25)
		st.position = Vector3(0, -0.2, sside * 0.06)
		st.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(st)


# --- airport: concourse -------------------------------------------------------


func _air_concourse() -> void:
	# belts run along the room's LONG axis and are cut to fit between its
	# walls, so a walkway never drives into masonry
	var span = scene.room_span()
	var along_x = span.x >= span.y
	var yw = 0.0 if along_x else PI / 2.0
	var run := _walkway_run_for_span(span.x if along_x else span.y)
	var lat = span.y if along_x else span.x
	if run < 6.0:
		_air_hall()   # too short for a walkway; furnish it as a plain hall
		return
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var pair = ctx.random01(321) < 0.55 and lat >= 10.0
	var offs = [-1.35, 1.35] if pair else [0.0]
	var flow0 = 1.0 if ctx.random01(322) < 0.5 else -1.0
	for i in offs.size():
		_travelator(scene.world_point(o, Vector3(0, 0, offs[i]), yw), yw,
			flow0 * (1.0 if i == 0 else -1.0), 323 + i, run)
		_hang_sign(o + Vector3(0, 3.55, 0), yw + PI / 2.0,
			_air_zone_sign(326))
	# a seat row parked against the quiet side, only if there is room beside
	# the belts for it
	var side = lat / 2.0 - 1.6
	if ctx.random01(327) < 0.55 and side >= (3.4 if pair else 2.8):
		var sp = scene.world_point(o, Vector3(0.8, 0, side * (1.0 if ctx.random01(329) < 0.5 else -1.0)), yw)
		_seat_row(sp, yw + PI / 2.0, 5, 328)
	# Clutter keeps to the margins, well clear of the belts — but the seat row
	# above is parked on that same margin, and `clut` collapses onto `side`
	# whenever the room is narrow enough, putting both on one line. Each has to
	# check the spot is free or the bag ends up standing inside the seating.
	var clut = minf(side, 4.5 if pair else 3.9)
	if clut >= 2.6:
		if ctx.random01(540) < 0.5:
			var bp = scene.world_point(o, Vector3(-3.5 + 7.0 * ctx.random01(541), 0,
				clut * (1.0 if ctx.random01(542) < 0.5 else -1.0)), yw)
			if scene.floor_spot_clear(bp, 0.42, 1.0):
				_air_bin(bp)
		if ctx.random01(543) < 0.2:
			var cp = scene.world_point(o, Vector3(-3.0 + 6.0 * ctx.random01(544), 0,
				clut * (1.0 if ctx.random01(545) < 0.5 else -1.0)), yw)
			if scene.floor_spot_clear(cp, 0.40, 1.0):
				_airport_luggage(cp, ctx.random01(546) * TAU, 547)


## One moving walkway: deck, animated belt, glass balustrades, and an Area3D
## that actually carries whoever stands on it.


func _walkway_run_for_span(span: float) -> float:
	return minf(10.4, span - 2.0 * (WALKWAY_RAMP_OVERHANG + WALKWAY_END_AISLE))


func _walkway_fit_length(model: Node3D, length: float, source_length: float) -> void:
	# Keep each manufactured end unchanged. Only the straight centre changes
	# length; cache the resulting meshes once for all instances of that length.
	if is_equal_approx(length, source_length):
		return
	var source_half := source_length * 0.5 - 1.0
	var fitted_half := length * 0.5 - 1.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := "%s:%.3f" % [mi.mesh.resource_path, length]
		if not _walkway_fitted_meshes.has(key):
			var fitted := ArrayMesh.new()
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in vertices.size():
					var x := vertices[i].x
					vertices[i].x = (x * fitted_half / source_half if absf(x) <= source_half
						else x + signf(x) * (length - source_length) * 0.5)
				arrays[Mesh.ARRAY_VERTEX] = vertices
				fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				fitted.surface_set_material(surface, mi.mesh.surface_get_material(surface))
			_walkway_fitted_meshes[key] = fitted
		mi.mesh = _walkway_fitted_meshes[key]


func _travelator(p: Vector3, yaw: float, flow: float, _salt: int, L = 8.4) -> void:
	var b0 := scene.collider_mark()
	var v := scene.furnishing_pivot(p, yaw, "airport_travelator")
	v.set_meta("surface_wear_prop", "airport_travelator")
	v.set_meta("walkway_length_m", L)
	v.set_meta("walkway_flow", flow)
	var long_model := is_equal_approx(L, 10.4)
	var model := scene.attributed_prop_local(v,
		Chunk.AIRPORT_WALKWAY_LONG_PATH if long_model else Chunk.AIRPORT_WALKWAY_PATH,
		Vector3.ZERO, 0.0)
	if model != null:
		_walkway_fit_length(model, L, 10.4 if long_model else 8.4)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.name == "WalkwayBelt":
				mi.material_override = Mats.belt()
				mi.set_instance_shader_parameter("speed", flow * 0.75)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif mi.name == "WalkwayGlass":
				if _walkway_glass_material == null:
					_walkway_glass_material = mi.mesh.surface_get_material(0).duplicate()
					_walkway_glass_material.albedo_color = Color(0.53, 0.72, 0.78, 0.18)
					_walkway_glass_material.cull_mode = BaseMaterial3D.CULL_BACK
				mi.material_override = _walkway_glass_material
				mi.set_meta("airport_barrier_glass", true)
				mi.set_meta("barrier_alpha", 0.18)
				# The continuous black perimeter and steel skirt visibly mark
				# the barrier even through clear glass. Audit that physical frame.
				mi.set_meta("barrier_frame_path", mi.get_path_to(model.find_child("*_Body", true, false)))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var BW := 1.15
	for side in [-1.0, 1.0]:
		scene.collider_yaw_box(scene.world_point(p, Vector3(0, 0.6, side * 0.735), yaw),
			Vector3(L, 1.25, 0.1), yaw)
	# deck + end ramps the player can actually walk up
	scene.collider_yaw_box(p + Vector3(0, 0.065, 0), Vector3(L - 1.10, 0.13, BW + 0.5), yaw)
	for e in [-1.0, 1.0]:
		var ramp_collider := scene.collider_rotated_box(
			scene.world_point(p, Vector3(e * (L / 2.0 - 0.02), 0.05856, 0), yaw),
			Vector3(1.166, 0.025, BW + 0.5),
			Vector3(0, yaw, -e * atan(0.118 / 1.16)))
		ramp_collider.set_meta("walkable_ramp", true)
	scene.bind_furnishing_colliders(v, b0)
	var tv = Travelator.new()
	# Doorway culling must also retire the drive when it removes this walkway.
	tv.set_meta("furnishing_group", v.get_meta("furnishing_group"))
	tv.dirv = Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	tv.speed = 0.75
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(L - 1.6, 1.6, BW)
	cs.shape = sh
	tv.add_child(cs)
	tv.position = p + Vector3(0, 0.95, 0)
	tv.rotation.y = yaw
	scene.add_node(tv)


## Transit corridor: three chained walkways in a complete low tube. Side room
## connections get finished portals into a narrow walking margin; every other
## stretch is continuous wall, so there is no cell-end route behind a facade.


func _air_transit() -> void:
	var cdir = WorldGen.corridor(ctx.world_seed, ctx.cell)
	var along_x: bool
	if cdir != 0:
		along_x = cdir == 1
	else:
		along_x = WorldGen.r01(ctx.world_seed, 0, ctx.cell.y, 511) < 0.5
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var wall_half = 5.2
	var wh = 3.5
	for k in 3:
		var off = (float(k) - 1.0) * 3.4
		var flow = 1.0 if k % 2 == 0 else -1.0
		_travelator(scene.world_point(o, Vector3(0, 0, off), yw), yw, flow, 512 + k,
			_walkway_run_for_span(WorldGen.CELL_SIZE))

	# A single architectural contract drives wall cuts, returns and dressing.
	for si in 2:
		var data = _air_transit_side_data(si, along_x, wall_half)
		_air_transit_wall_side(o, yw, float(data["side"]), wh, data["bay"])
		if ctx.random01(530 + si) < 0.62:
			var at = _air_transit_ad_t(si, data["bay"])
			if at < 90.0:
				var side: float = data["side"] - signf(float(data["side"])) * 0.1
				var q = scene.model_quad(null, scene.world_point(o, Vector3(at, 1.9, side), yw),
					Vector2(1.2, 1.8), Mats.adbox(int(ctx.random01(534 + si) * 3.99)))
				q.rotation.y = yw + (PI if side > 0.0 else 0.0)

	# The dropped lid now reaches the continuous walls. Side portal helpers add
	# their own small ceiling patches over the remaining boundary recess.
	var sof = scene.model_box(null, scene.world_point(o, Vector3(0, wh + 0.06, 0), yw),
		Vector3(WorldGen.CELL_SIZE, 0.12, wall_half * 2.0 + Chunk.T), Mats.airport_ceiling())
	sof.rotation.y = yw
	# The dropped transit lid shares the terminal grid. Its fixtures use the
	# local 3.5m datum, never the unused high ceiling above it.
	var pmat = Mats.air_panel()
	for li in 2:
		var lane = -1.7 if li == 0 else 1.7
		for t in [-3.0, 0.0, 3.0]:
			_air_ceiling_fixture(scene.world_point(o, Vector3(t, 0, lane), yw),
				Vector2i(2, 1) if along_x else Vector2i(1, 2), pmat, wh)
	var l = OmniLight3D.new()
	l.light_color = Color(0.94, 0.97, 1.0)
	l.light_energy = 1.2
	l.omni_range = 11.0
	l.position = o + Vector3(0, wh - 0.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	l.set_meta("stream_room_light", true)
	l.set_meta("visible_source", "transit_ceiling_fixtures")
	scene.add_node(l)
	# Wayfinding over the two genuine walking lanes, tucked under the lid.
	for ki in 2:
		var sl = -1.7 if ki == 0 else 1.7
		if ctx.random01(516 + ki) < 0.55:
			_hang_sign(scene.world_point(o, Vector3(0, 2.8, sl), yw), yw + PI / 2.0,
					_air_zone_sign(518 + ki), wh)


func _air_transit_side_data(si: int, along_x: bool, wall_half: float) -> Dictionary:
	var side = -wall_half if si == 0 else wall_half
	var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info = scene.edge_info(ctx.cell, sdir)
	var bay = []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw = clampf(float(info["w"]) + 0.3, 4.1, 6.5)
		bay = [bt, bw]
	return {"side": side, "bay": bay}


func _air_transit_wall_side(o: Vector3, yw: float, side: float,
		wh: float, bay: Array) -> void:
	var segs = [[-6.0, 6.0]]
	if not bay.is_empty():
		segs = scene.cut_segments(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_air_transit_wall_run(o, yw, side, wh, float(sg[0]), float(sg[1]))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_air_transit_header(o, yw, side, wh, bt, bw)
		_air_transit_open_casing(o, yw, side, bt, bw)
		_air_transit_bay_returns(o, yw, side, wh, bt, bw)


## Full-length wall run with modular aluminium reveals, a stainless kick plate
## and a baggage-cart bumper rail. Segmentation matches its collider exactly.


func _air_transit_wall_run(o: Vector3, yw: float, side: float,
		wh: float, a: float, b: float) -> void:
	var ln = b - a
	if ln < 0.04:
		return
	var c = (a + b) * 0.5
	var wc = scene.world_point(o, Vector3(c, wh * 0.5, side), yw)
	var wall = scene.model_box(null, wc, Vector3(ln, wh, Chunk.T),
		Mats.airport_wall_variant(scene.finish_variant()))
	wall.rotation.y = yw
	scene.collider_yaw_box(wc, Vector3(ln, wh, Chunk.T), yw)
	var inn = side - signf(side) * (Chunk.T * 0.5 + 0.022)
	var kick = scene.model_box(null, scene.world_point(o, Vector3(c, 0.11, inn), yw),
		Vector3(ln, 0.22, 0.045), Mats.steel())
	kick.rotation.y = yw
	var bumper = scene.model_box(null, scene.world_point(o, Vector3(c, 0.78, inn - signf(side) * 0.02), yw),
		Vector3(ln, 0.055, 0.075), Mats.rubber_black())
	bumper.rotation.y = yw
	for seam in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		if seam <= a + 0.05 or seam >= b - 0.05:
			continue
		var reveal = scene.model_box(null, scene.world_point(o, Vector3(seam, wh * 0.5, inn), yw),
			Vector3(0.028, wh, 0.035), Mats.metal_gray())
		reveal.rotation.y = yw


func _air_transit_header(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var hh = wh - Chunk.AIR_DOOR
	if hh <= 0.02:
		return
	var hp = scene.world_point(o, Vector3(t, Chunk.AIR_DOOR + hh * 0.5, side), yw)
	var head = scene.model_box(null, hp, Vector3(width, hh, Chunk.T),
		Mats.airport_wall_variant(scene.finish_variant()))
	head.rotation.y = yw
	scene.collider_yaw_box(hp, Vector3(width, hh, Chunk.T), yw)


func _air_transit_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn = side - signf(side) * (Chunk.T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = scene.model_box(null, scene.world_point(o, Vector3(edge, Chunk.AIR_DOOR * 0.5, inn), yw),
			Vector3(0.2, Chunk.AIR_DOOR, Chunk.T + 0.2), Mats.steel())
		jamb.rotation.y = yw
	var lintel = scene.model_box(null, scene.world_point(o, Vector3(t, Chunk.AIR_DOOR + 0.1, inn), yw),
		Vector3(width + 0.22, 0.2, Chunk.T + 0.2), Mats.steel())
	lintel.rotation.y = yw
	# Small backlit identifier fixed to the portal head, facing the transit lane.
	var v = Node3D.new()
	v.position = scene.world_point(o, Vector3(t, Chunk.AIR_DOOR - 0.16, inn - signf(side) * 0.04), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	scene.add_node(v)
	scene.model_rounded_box(v, Vector3.ZERO, Vector3(minf(width - 0.35, 2.35), 0.23, 0.05),
		Mats.sign_navy(), 0.008)
	var lb = Label3D.new()
	lb.text = "CONCOURSE ACCESS"
	lb.font_size = 42
	lb.pixel_size = 0.00165
	lb.modulate = Color(0.96, 0.92, 0.5)
	lb.position = Vector3(0, 0, 0.031)
	v.add_child(lb)


## Short returns link the low transit shell to the actual cell-edge portal.
## They close the sliver behind adjacent panels and roof the recess at 3.5m.


func _air_transit_bay_returns(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var outer = signf(side) * (WorldGen.CELL_SIZE * 0.5 - Chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = scene.world_point(o, Vector3(edge, wh * 0.5, dc), yw)
		var ret = scene.model_box(null, wp, Vector3(Chunk.T, wh, depth),
			Mats.airport_wall_variant(scene.finish_variant()))
		ret.rotation.y = yw
		scene.collider_yaw_box(wp, Vector3(Chunk.T, wh, depth), yw)
		var inward = Chunk.T * 0.5 + 0.022 if edge < t else -(Chunk.T * 0.5 + 0.022)
		var kick = scene.model_box(null, scene.world_point(o, Vector3(edge + inward, 0.11, dc), yw),
			Vector3(0.045, 0.22, depth), Mats.steel())
		kick.rotation.y = yw
	var roof = scene.model_box(null, scene.world_point(o, Vector3(t, wh + 0.06, dc), yw),
		Vector3(width, 0.12, depth), Mats.airport_ceiling())
	roof.rotation.y = yw
	var diffuser = scene.model_box(null, scene.world_point(o, Vector3(t, wh - 0.06, dc), yw),
		Vector3(minf(width * 0.65, 1.2), 0.045, maxf(0.18, depth * 0.55)), Mats.air_panel())
	diffuser.rotation.y = yw
	var bl = OmniLight3D.new()
	bl.light_color = Color(0.85, 0.91, 1.0)
	bl.light_energy = 0.48
	bl.omni_range = 4.6
	bl.position = scene.world_point(o, Vector3(t, wh - 0.16, dc), yw)
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	bl.set_meta("stream_room_light", true)
	bl.set_meta("visible_source", "transit_bay_diffuser")
	scene.add_node(bl)


func _air_transit_ad_t(si: int, bay: Array) -> float:
	var raw = -3.0 + 6.0 * ctx.random01(532 + si)
	var candidates = [raw, -3.9, 3.9, 0.0]
	if si == 1:
		candidates = [raw, 3.9, -3.9, 0.0]
	for t in candidates:
		if bay.is_empty() or absf(float(t) - float(bay[0])) >= float(bay[1]) * 0.5 + 0.9:
			return float(t)
	return 99.0


# --- airport: check-in --------------------------------------------------------


func _air_checkin() -> void:
	var wdir = _air_pick_wall(360)
	var yw = scene.yaw_for(wdir) if wdir >= 0 else ((PI / 2.0) if ctx.random01(361) < 0.5 else 0.0)
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	# The authored position is 4.78m wide, so a row of two fills the same span
	# three narrow generated desks used to. Falling back to the generated desk
	# restores the tighter three-desk row.
	if scene.prop_scene(Chunk.CHECKIN_DESK_PATH) != null:
		for di in 2:
			_checkin_desk(o, yw, -2.6 + 5.2 * float(di), 365 + di * 4)
	else:
		for di in 3:
			_checkin_desk(o, yw, -3.6 + 3.6 * float(di), 365 + di * 4)
	# the big board hanging over the queue
	_fids(null, scene.world_point(o, Vector3(0, 3.15, 1.1), yw), yw + PI, true, true)
	# serpentine of queue barriers holding a line for no one
	_stanchion_line(scene.world_point(o, Vector3(-4.2, 0, 1.6), yw), scene.world_point(o, Vector3(4.2, 0, 1.6), yw), 6)
	_stanchion_line(scene.world_point(o, Vector3(4.2, 0, 0.4), yw), scene.world_point(o, Vector3(-4.2, 0, 0.4), yw), 6)
	if ctx.random01(374) < 0.5:
		_stanchion_line(scene.world_point(o, Vector3(-4.2, 0, -0.8), yw), scene.world_point(o, Vector3(4.2, 0, -0.8), yw), 6)
	if ctx.random01(375) < 0.55:
		_air_trolley(scene.world_point(o, Vector3(-4.6 + 9.2 * ctx.random01(376), 0, -2.6), yw), ctx.random01(377) * TAU, 378, 1)
	if ctx.random01(379) < 0.68:
		scene.security_camera(scene.world_point(o, Vector3(4.55, 3.45, WorldGen.CELL_SIZE * 0.5 - Chunk.T * 0.5), yw), yw + PI)


func _checkin_desk(o: Vector3, yw: float, dx: float, salt: int) -> void:
	var authored = scene.prop_scene(Chunk.CHECKIN_DESK_PATH) != null
	# The generated desk is a shallow counter that sat 3.55m off centre. The
	# authored position is 3.2m deep, so it stands back far enough for its belt
	# housing to reach the wall without the counter crowding the queue lane.
	var dz = 4.20 if authored else 3.55
	var b0 = scene.collider_mark()
	var v = Node3D.new()
	v.position = scene.world_point(o, Vector3(dx, 0, dz), yw)
	v.rotation.y = yw
	scene.claim_furnishing_group(v, "airport_checkin_desk", true)
	scene.add_node(v)
	# The authored position supplies the counter, the agent monitor mast, the
	# baggage scale and the belt housing — the twelve primitives that used to
	# fake them are the fallback below. Its counter faces local -Z, which is
	# the queue side, matching the generated desk it replaces.
	var desk: Node3D = null
	if authored:
		desk = scene.attributed_prop_local(v, Chunk.CHECKIN_DESK_PATH,
			-Chunk.CHECKIN_DESK_CENTRE * Chunk.CHECKIN_DESK_SCALE, 0.0,
			Vector3.ONE * Chunk.CHECKIN_DESK_SCALE)
	if desk != null:
		v.set_meta("attributed_furnishing", "airport_checkin_desk")
		# Counter run and the belt housing behind it, as two boxes rather than
		# one: the queue side in front of the counter must stay walkable.
		scene.collider_yaw_box(scene.world_point(v.position, Vector3(0, 0.58, -1.05), yw),
			Vector3(Chunk.CHECKIN_DESK_W, 1.16, 1.10), yw)
		scene.collider_yaw_box(scene.world_point(v.position, Vector3(0, 0.72, 0.60), yw),
			Vector3(Chunk.CHECKIN_DESK_W, 1.44, 2.00), yw)
	else:
		# counter facing the queue (local -z)
		scene.model_box(v, Vector3(0.35, 0.06, 0), Vector3(1.9, 0.12, 0.68), Mats.charcoal())
		scene.model_rounded_box(v, Vector3(0.35, 0.57, 0), Vector3(1.9, 1.02, 0.66), Mats.desk_white(), 0.02)
		scene.model_box(v, Vector3(0.35, 1.1, 0), Vector3(1.96, 0.04, 0.74), Mats.steel())
		scene.collider_yaw_box(scene.world_point(v.position, Vector3(0.35, 0.6, 0), yw), Vector3(1.9, 1.2, 0.75), yw)
		# monitor on a pole, screen to the agent side
		scene.model_cylinder(v, Vector3(0.85, 1.55, 0.1), 0.025, 0.9, Mats.metal_gray())
		var lit = ctx.random01(salt) < 0.4
		scene.model_rounded_box(v, Vector3(0.85, 2.1, 0.1), Vector3(0.5, 0.34, 0.04), Mats.screen_glow() if lit else Mats.screen_dark(), 0.008)
		if lit:
			var lb = Label3D.new()
			lb.text = "CLOSED"
			lb.font_size = 40
			lb.pixel_size = 0.002
			lb.modulate = Color(1.0, 0.5, 0.25)
			lb.position = Vector3(0.85, 2.1, 0.13)
			v.add_child(lb)
		# baggage scale and the belt that climbs into the wall housing
		scene.model_box(v, Vector3(-0.75, 0.17, 0.35), Vector3(0.8, 0.34, 0.95), Mats.steel())
		scene.model_box(v, Vector3(-0.75, 0.355, 0.35), Vector3(0.68, 0.02, 0.85), Mats.rubber_black())
		var stub = scene.model_box(v, Vector3(-0.75, 0.62, 1.25), Vector3(0.68, 0.05, 1.0), Mats.rubber_black())
		stub.rotation.x = -0.45
		scene.model_box(v, Vector3(-0.75, 1.0, 1.95), Vector3(0.92, 1.9, 0.5), Mats.steel())
		for fi in 4:
			scene.model_box(v, Vector3(-0.99 + 0.16 * float(fi), 1.25, 1.68), Vector3(0.14, 0.5, 0.02), Mats.rubber_black())
		scene.collider_yaw_box(scene.world_point(v.position, Vector3(-0.75, 0.5, 0.8), yw), Vector3(0.9, 1.0, 2.0), yw)
	scene.bind_furnishing_colliders(v, b0)
	# Position number hanging above. Over the authored desk it moves a metre
	# forward, to hang over the counter rather than the belt run behind it —
	# far enough back to leave the big departures board its own airspace, and
	# 2.5m clear of the 3.55m monitor mast at the desk's other end.
	var pn = Node3D.new()
	pn.position = scene.world_point(o, Vector3(dx + 0.35, 3.0,
		dz - (1.00 if authored else 0.0)), yw)
	pn.rotation.y = yw
	scene.add_node(pn)
	var rod_h = ctx.ceiling_height - 3.0 - 0.26
	scene.model_cylinder(pn, Vector3(0, 0.26 + rod_h / 2.0, 0), 0.014, rod_h, Mats.charcoal())
	scene.model_rounded_box(pn, Vector3.ZERO, Vector3(0.5, 0.5, 0.08), Mats.sign_navy(), 0.012)
	for sside in [-1.0, 1.0]:
		var nl = Label3D.new()
		nl.text = "%02d" % (1 + (WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + 2) % 24))
		nl.font_size = 90
		nl.pixel_size = 0.0026
		nl.modulate = Color(0.96, 0.92, 0.5)
		nl.position = Vector3(0, 0, sside * 0.05)
		nl.rotation.y = 0.0 if sside > 0.0 else PI
		pn.add_child(nl)


# --- airport: baggage claim ---------------------------------------------------


func _air_baggage() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	scene.set_chunk_meta("airport_baggage_carousel_expected", true)
	var body0 = scene.collider_mark()
	var carousel = scene.furnishing_pivot(c, 0.0, "airport_baggage_carousel")
	var model = scene.attributed_prop_local(carousel, Chunk.AIRPORT_CAROUSEL_PATH,
		Vector3.ZERO, 0.0)
	if model == null:
		return
	carousel.set_meta("airport_carousel_complete", true)
	carousel.set_meta("airport_baggage_number_totem", true)
	var belt = model.find_child("CarouselBelt", true, false) as MeshInstance3D
	var movement = preload("res://scripts/airport_carousel_motion.gd").new()
	movement.name = "CarouselLuggageMotion"
	movement.speed = 0.115 if ctx.random01(379) < 0.8 else 0.0
	carousel.add_child(movement)
	if belt != null:
		if _carousel_belt_material == null:
			_carousel_belt_material = ShaderMaterial.new()
			_carousel_belt_material.shader = preload("res://shaders/airport_carousel_belt.gdshader")
		belt.material_override = _carousel_belt_material
		belt.set_meta("airport_carousel_belt", true)
		belt.set_instance_shader_parameter("belt_speed", movement.speed)
	var luggage_count = 3 + int(ctx.random01(380) * 3.0)
	for i in luggage_count:
		var carrier = Node3D.new()
		carrier.set_meta("carousel_path_offset", fposmod(ctx.random01(381) * movement.PATH_LENGTH
			+ float(i) * movement.PATH_LENGTH / float(luggage_count), movement.PATH_LENGTH))
		movement.add_child(carrier)
		_airport_luggage_model(carrier, Vector3.ZERO, 0.0,
			383 + i, ctx.random01(387 + i) < 0.34)
	movement.place_luggage()
	# One capsule deck and the three taller fixtures, bound atomically to the model.
	scene.collider_yaw_box(c + Vector3(0, 0.38, 0), Vector3(3.0, 0.76, 4.0), 0.0)
	for z in [-movement.HALF_STRAIGHT, movement.HALF_STRAIGHT]:
		scene.collider_cylinder(c + Vector3(0, 0.38, z), movement.OUTER_RADIUS, 0.76)
	var lift: float = movement.FIXTURE_LIFT
	var end_shift: float = movement.END_SHIFT
	scene.collider_yaw_box(c + Vector3(0, 0.715 + lift, -1.17 - end_shift), Vector3(0.66, 0.45, 0.74), 0.0)
	scene.collider_yaw_box(c + Vector3(-0.025, 1.12 + lift, 1.26 + end_shift), Vector3(0.55, 1.22, 0.18), 0.0)
	scene.collider_yaw_box(c + Vector3(0, 0.9 + lift, 0.08), Vector3(0.065, 0.86, 0.72), 0.0)
	scene.bind_furnishing_colliders(carousel, body0)
	var num = Label3D.new()
	num.name = "BaggageCarouselNumber"
	num.text = "%d" % (1 + (WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 386) % 8))
	num.font_size = 220
	num.pixel_size = 0.0022
	num.modulate = Color(0.96, 0.80, 0.08)
	num.outline_size = 0
	num.position = Vector3(0, 1.30 + lift, 1.343 + end_shift)
	carousel.add_child(num)
	_hang_sign(c + Vector3(0.5, 3.6, 0.5), float(int(ctx.random01(387) * 3.99)) * PI / 2.0, "Baggage Claim")
	# trolley rank and strays
	if ctx.random01(388) < 0.7:
		_air_trolley(Vector3(1.6 + 1.2 * ctx.random01(389), 0, 1.5), (ctx.random01(390) - 0.5) * 0.4, 391, 2 + int(ctx.random01(392) * 2.0))
	if ctx.random01(393) < 0.6:
		var stray = Vector3(2.2 + 7.6 * ctx.random01(394), 0, 8.6 + 1.6 * ctx.random01(395))
		if scene.floor_spot_clear(stray, 0.40, 1.0):
			_airport_luggage(stray, ctx.random01(396) * TAU, 397, ctx.random01(398) < 0.5)
	if ctx.room_size >= 2:
		_air_baggage_large_dressing(c)


## Seating and trolley ranks scale with a merged baggage hall while the main
## carousel remains the visual anchor. The added islands sit outside its sweep.


func _air_baggage_large_dressing(c: Vector3) -> void:
	var span = scene.room_span()
	var spots = []
	if span.x > 12.1:
		spots.append(c + Vector3(-7.2, 0, 0))
		spots.append(c + Vector3(7.2, 0, 0))
	if span.y > 12.1:
		spots.append(c + Vector3(0, 0, -7.2))
		spots.append(c + Vector3(0, 0, 7.2))
	# Baggage halls have no apron window. Pick one cardinal room direction and
	# keep every island aligned to it instead of turning each toward the belt.
	var seat_yaw = float(int(ctx.random01(431) * 3.99)) * PI / 2.0
	for i in spots.size():
		var sp: Vector3 = spots[i]
		_seat_row(sp, seat_yaw, 4, 430 + i * 4)
	var tp = c + Vector3(span.x * 0.5 - 2.0, 0, -span.y * 0.5 + 2.0)
	_air_trolley(tp, PI * 0.25 + (ctx.random01(448) - 0.5) * 0.3, 449,
		2 + int(ctx.random01(450) * 1.99))
	if ctx.random01(451) < 0.75:
		_airport_luggage(tp + Vector3(-1.2, 0, 0.7), ctx.random01(452) * TAU,
			453, ctx.random01(454) < 0.4)


# --- airport: escalators ------------------------------------------------------


func _air_escalator() -> void:
	var wdir = _air_pick_wall(390)
	if wdir < 0:
		_air_hall()
		return
	var yw = scene.yaw_for(wdir)
	var o = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	for cx in [-1.15, 1.15]:
		_escalator_flight(o, yw, cx)
	# mezzanine landing hugging the wall
	var lp = scene.world_point(o, Vector3(0, 2.16, 4.48), yw)
	var lm = scene.model_box(null, lp, Vector3(5.6, 0.18, 2.75), Mats.steel())
	lm.rotation.y = yw
	scene.collider_yaw_box(lp, Vector3(5.6, 0.18, 2.75), yw)
	# glass rail along the landing front, gaps at the flight mouths
	for seg in [[-2.8, -1.77], [-0.53, 0.53], [1.77, 2.8]]:
		var sc: float = (seg[0] + seg[1]) / 2.0
		var sl: float = seg[1] - seg[0]
		_air_rail(scene.world_point(o, Vector3(sc, 0, 3.14), yw), yw + PI / 2.0, sl)
	for sxn in [-2.77, 2.77]:
		_air_rail(scene.world_point(o, Vector3(sxn, 0, 4.48), yw), yw, 2.7)
	# roller shutter sealing whatever the mezzanine led to; a solid backing
	# panel sits behind the ribs so no light stripes the wall through the gaps
	var bk = scene.model_box(null, scene.world_point(o, Vector3(0, 3.55, 5.79), yw), Vector3(4.9, 2.6, 0.05), Mats.charcoal())
	bk.rotation.y = yw
	for i in 14:
		var rb = scene.model_box(null, scene.world_point(o, Vector3(0, 2.42 + 0.17 * float(i), 5.72), yw), Vector3(4.9, 0.155, 0.06), Mats.metal_gray())
		rb.rotation.y = yw
		rb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gxn in [-2.5, 2.5]:
		var gd = scene.model_box(null, scene.world_point(o, Vector3(gxn, 3.55, 5.72), yw), Vector3(0.14, 2.6, 0.12), Mats.charcoal())
		gd.rotation.y = yw
		gd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.collider_yaw_box(scene.world_point(o, Vector3(0, 3.55, 5.72), yw), Vector3(5.2, 2.7, 0.15), yw)
	var cl = Label3D.new()
	cl.text = "CLOSED FOR MAINTENANCE"
	cl.font_size = 40
	cl.pixel_size = 0.002
	cl.modulate = Color(0.85, 0.85, 0.85, 0.8)
	cl.position = scene.world_point(o, Vector3(0, 3.3, 5.62), yw)
	cl.rotation.y = yw + PI
	scene.add_node(cl)
	# support columns under the landing lip
	for sxn in [-2.5, 2.5]:
		var scp = scene.world_point(o, Vector3(sxn, 1.05, 3.3), yw)
		scene.cylinder(scp, 0.11, 2.1, Mats.steel())
	# out-of-service barrier across one flight
	var bx = -1.15 if ctx.random01(399) < 0.5 else 1.15
	_stanchion_line(scene.world_point(o, Vector3(bx - 0.6, 0, -2.3), yw), scene.world_point(o, Vector3(bx + 0.6, 0, -2.3), yw), 2)


## Landing-edge glass rail segment, centred at p, running along local x.


func _air_rail(p: Vector3, yaw: float, ln: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	scene.add_node(v)
	var gl = scene.model_box(v, Vector3(0, 2.72, 0), Vector3(ln, 0.9, 0.028), Mats.airport_glass())
	gl.set_meta("airport_barrier_glass", true)
	gl.set_meta("barrier_alpha", 0.62)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hr = scene.model_rounded_box(v, Vector3(0, 3.2, 0), Vector3(ln + 0.05, 0.07, 0.08), Mats.rubber_black(), 0.03)
	hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.collider_yaw_box(p + Vector3(0, 2.85, 0), Vector3(ln, 1.3, 0.1), yaw)


## One frozen escalator flight rising toward local +z from z -1.1 to the
## landing at z 3.1, y 2.25. Steps are dressing; a hidden slope does the work.


func _escalator_flight(o: Vector3, yw: float, cx: float) -> void:
	var p := scene.world_point(o, Vector3(cx, 0, 0), yw)
	var b0 := scene.collider_mark()
	var v := scene.furnishing_pivot(p, yw, "airport_escalator")
	scene.attributed_prop_local(v, Chunk.AIRPORT_ESCALATOR_PATH, Vector3.ZERO, 0.0)
	# The authored treads follow this existing walkable slope and landings.
	for side in [-0.62, 0.62]:
		scene.collider_rotated_box(scene.world_point(p, Vector3(side, 1.75, 0.95), yw),
			Vector3(0.1, 1.6, 5.1), Vector3(-0.475, yw, 0))
	scene.collider_rotated_box(scene.world_point(p, Vector3(0, 1.03, 0.95), yw),
		Vector3(1.15, 0.2, 4.95), Vector3(-0.475, yw, 0))
	scene.collider_yaw_box(scene.world_point(p, Vector3(0, 0.015, -1.62), yw),
		Vector3(1.24, 0.03, 0.8), yw)
	scene.bind_furnishing_colliders(v, b0)


func _air_hall() -> void:
	# the overflow hall: seating for a delay that outlived its passengers
	# (a portal claims the middle of the room when one is open here)
	var span = scene.room_span()
	var mx = span.x / 2.0 - 2.4
	var mz = span.y / 2.0 - 2.4
	if ctx.portal_destination < 0 and ctx.random01(400) < 0.6 and mx > 0.5 and mz > 0.5:
		# rows sit square to the room and clear of its walls
		_seat_row(Vector3(WorldGen.CELL_SIZE / 2.0 + (ctx.random01(401) - 0.5) * 2.0 * mx, 0,
			WorldGen.CELL_SIZE / 2.0 + (ctx.random01(402) - 0.5) * 2.0 * mz),
			float(int(ctx.random01(403) * 3.99)) * PI / 2.0, 5, 404)
	if ctx.random01(405) < 0.4:
		scene.planter(Vector3(2.6 + 6.8 * ctx.random01(406), 0, 2.6 + 6.8 * ctx.random01(407)))
	if ctx.portal_destination < 0 and ctx.random01(408) < 0.3:
		# wet floor sign guarding a dry floor
		var p = Vector3(3.0 + 6.0 * ctx.random01(409), 0, 3.0 + 6.0 * ctx.random01(410))
		scene.cc0_prop("WetFloorSign_01", p, ctx.random01(411) * TAU)
		scene.collider_box(p + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	if ctx.portal_destination < 0 and ctx.random01(411) < 0.35:
		_fids(null, Vector3(2.5 + 7.0 * ctx.random01(412), 2.6, 2.5 + 7.0 * ctx.random01(413)),
			float(int(ctx.random01(414) * 3.99)) * PI / 2.0, true, true)


## Landmark: a shuttered food court. Three distinct concession fronts frame
## a sparse field of real tables; the central aisle stays clear enough to see
## the dead menu boards from the adjoining concourse.


func _air_foodcourt() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var names = ["SKYLINE GRILL", "COFFEE / TEA", "FRESH EXPRESS"]
	for i in 3:
		var x = -6.6 + 6.6 * float(i)
		var kp = c + Vector3(x, 0, -8.5)
		_air_foodcourt_booth(kp, names[i], i == 1)
	# Four battered public tables, deliberately asymmetrical around the aisle.
	var table_offsets: Array[Vector3] = [Vector3(-5.4, 0, -1.8), Vector3(4.8, 0, -2.0),
		Vector3(-4.5, 0, 4.4), Vector3(5.6, 0, 4.0)]
	for i in 4:
		var tp: Vector3 = c + table_offsets[i]
		var yaw = (0.0 if i % 2 == 0 else PI / 2.0) + (ctx.random01(430 + i) - 0.5) * 0.15
		scene.cc0_prop("wooden_picnic_table", tp, yaw)
		scene.collider_yaw_box(tp + Vector3(0, 0.4, 0), Vector3(2.3, 0.8, 3.1), yaw)
	# Cleaning and service equipment gives the set piece a second read.
	var cartp = c + Vector3(8.0, 0, 7.6)
	scene.cc0_prop("CoffeeCart_01", cartp, -PI / 2.0)
	scene.collider_yaw_box(cartp + Vector3(0, 0.85, 0), Vector3(2.2, 1.7, 1.1), -PI / 2.0)
	var wetp = c + Vector3(0.8, 0, 5.2)
	scene.cc0_prop("WetFloorSign_01", wetp, ctx.random01(438) * TAU)
	scene.collider_box(wetp + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	_hang_sign(c + Vector3(0, 3.7, 6.4), 0.0, "FOOD COURT")


func _air_foodcourt_booth(pos: Vector3, title: String, coffee: bool) -> void:
	# Clearance must retire the WHOLE concession, including high slats/signs
	# and physics, never shave away its base and leave floating accessories.
	var booth := scene.furnishing_pivot(pos, 0.0, "airport_foodcourt_booth")
	booth.set_meta("fixed_furnishing", true)
	var b0 := scene.collider_mark()
	scene.model_rounded_box(booth, Vector3(0, 0.5, 0),
		Vector3(5.4, 1.0, 1.35), Mats.jetway_body(), 0.03)
	# Full-height jambs and an opaque shutter backing join the slats/menu to
	# the floor-supported housing, even when viewed away from a room wall.
	for side in [-1.0, 1.0]:
		scene.model_box(booth, Vector3(side * 2.62, 1.9, 0),
			Vector3(0.16, 3.8, 1.35), Mats.jetway_body())
	scene.model_box(booth, Vector3(0, 2.4, 0.62),
		Vector3(5.08, 2.8, 0.1), Mats.metal_gray())
	# Corrugated shutter, counter and a black menu strip.
	for sl in 8:
		scene.model_box(booth, Vector3(0, 1.22 + 0.22 * float(sl), 0.69),
			Vector3(5.0, 0.12, 0.04), Mats.metal_gray())
	scene.model_rounded_box(booth, Vector3(0, 1.06, 1.0),
		Vector3(5.2, 0.12, 0.78), Mats.steel(), 0.025)
	scene.model_box(booth, Vector3(0, 3.45, 0.72),
		Vector3(4.7, 0.65, 0.08), Mats.charcoal())
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 96
	sign.pixel_size = 0.0025
	sign.modulate = Color(1.0, 0.72, 0.34) if coffee else Color(0.72, 0.88, 1.0)
	sign.position = Vector3(0, 3.46, 0.78)
	booth.add_child(sign)
	scene.collider_box(pos + Vector3(0, 1.9, 0), Vector3(5.4, 3.8, 1.35))
	scene.collider_box(pos + Vector3(0, 1.06, 1.0), Vector3(5.2, 0.12, 0.78))
	scene.bind_furnishing_colliders(booth, b0)


func _air_common() -> void:
	# structural columns in the open styles
	if ctx.style == WorldGen.AIR_CONCOURSE or ctx.style == WorldGen.AIR_HALL \
			or ctx.style == WorldGen.AIR_BAGGAGE or ctx.style == WorldGen.AIR_FOODCOURT:
		for p in [Vector2(1.7, 1.7), Vector2(10.3, 1.7), Vector2(1.7, 10.3), Vector2(10.3, 10.3)]:
			if WorldGen.r01(ctx.world_seed, ctx.cell.x + int(p.x), ctx.cell.y + int(p.y), 330) < 0.5:
				_air_column(p)
	# random scatter never lands in cells with belts — a suitcase parked on a
	# moving walkway pins whoever it carries into it
	var has_belts = ctx.style == WorldGen.AIR_TRANSIT or ctx.style == WorldGen.AIR_CONCOURSE
	# Scattered floor props take a free spot rather than any spot. Dropping one
	# on a random point in the cell is how a suitcase ends up standing inside a
	# row of gate seating, which is furniture the gate placed long before this.
	if not has_belts and ctx.random01(334) < 0.5:
		var bin_p = scene.free_floor_spot(335, 0.42, 2.6, 1.0)
		if bin_p != Vector3.INF:
			_air_bin(bin_p)
	# a suitcase standing perfectly upright, no owner in any direction
	if not has_belts and ctx.style != WorldGen.AIR_ESCALATOR and ctx.random01(337) < 0.18:
		var case_p = scene.free_floor_spot(338, 0.40, 2.6, 1.0)
		if case_p != Vector3.INF:
			_airport_luggage(case_p, ctx.random01(340) * TAU, 341)
	# A low backpack from the authored set replaces the old oversized open trunk.
	if ctx.style == WorldGen.AIR_BAGGAGE and ctx.random01(345) < 0.4:
		var vsp = scene.free_floor_spot(346, 0.42, 2.4, 0.6)
		if vsp != Vector3.INF:
			var vsy = ctx.random01(348) * TAU
			_airport_luggage(vsp, vsy, 349, true)
	# PA speakers live in the busy styles
	var wants_pa = ctx.style == WorldGen.AIR_GATE or ctx.style == WorldGen.AIR_CHECKIN \
		or ctx.style == WorldGen.AIR_BAGGAGE or ctx.style == WorldGen.AIR_FOODCOURT
	if wants_pa and ctx.random01(342) < 0.5:
		var snd = AirportSounds.new()
		snd.position = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
		scene.add_node(snd)


## Usable rectangle of this room, in metres, centred on room_centre. An
## L-shaped room reports only its root cell, since that is the largest part
## guaranteed to be free of walls.
