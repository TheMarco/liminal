extends "res://scripts/levels/chunk_level_builder.gd"


func _air_zone_sign(salt: int) -> String:
	var zone = WorldGen.macro_zone(chunk.wseed, chunk.cell, chunk.theme)
	var labels: Array = chunk.AIR_ZONE_SIGNS[zone]
	return labels[int(chunk._r(salt) * (float(labels.size()) - 0.01))]


func _air_pick_wall(salt: int) -> int:
	return WorldGen.anchor_wall(chunk.wseed, chunk.cell, salt)


## Yaw that points a node's local +z at the given edge.


func _gate_code() -> String:
	var letters = ["A", "B", "C", "D", "E"]
	return "%s%d" % [letters[int(chunk._r(300) * 4.99)], 1 + int(chunk._r(301) * 27.99)]


func _air_lighting() -> void:
	if chunk.style == WorldGen.AIR_TRANSIT:
		return  # transit corridors light themselves under the dropped bulkhead
	var is_spawn = chunk.cell == Vector2i.ZERO
	var dead = (not is_spawn) and chunk._r(8) < 0.04
	var flicker = (not is_spawn) and (not dead) and chunk._r(9) < 0.11
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.air_panel().duplicate()
	else:
		pmat = Mats.air_panel()
	# long recessed light lines running the hall
	for gx in [3.0, 9.0]:
		for gz in [2.5, 6.0, 9.5]:
			chunk._troffer(Vector3(gx, 0, gz), Vector2(2.6, 0.22), pmat, Mats.metal_gray())
	if dead:
		return
	var light = chunk._make_main_light(flicker, pmat, 1.7)
	light.light_color = Color(0.85, 0.91, 1.0)
	light.omni_range = 14.5
	light.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.6, chunk.S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	chunk.add_child(light)


## Overhead wayfinding hung from the deck above: navy backlit box, yellow
## text both sides, twin drop rods.


func _hang_sign(pos: Vector3, yaw: float, text: String, top = 0.0) -> void:
	var v = Node3D.new()
	v.position = pos
	v.rotation.y = yaw
	chunk.add_child(v)
	var w = maxf(1.6, 0.115 * float(text.length()) + 0.55)
	var rod_h = maxf(0.1, (top if top > 0.0 else chunk.ceil_h) - pos.y - 0.275)
	for sx in [-w * 0.36, w * 0.36]:
		chunk._mcyl(v, Vector3(sx, 0.275 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	chunk._mrbox(v, Vector3.ZERO, Vector3(w, 0.55, 0.09), Mats.sign_navy(), 0.015)
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
	if chunk.style == WorldGen.AIR_TRANSIT:
		return  # would poke through the transit bulkhead
	var txt = _air_zone_sign(345 + dir)
	if dir == 0:
		_hang_sign(Vector3(chunk.S - 0.8, chunk.AIR_DOOR + 0.6, t), PI / 2.0, txt)
	else:
		_hang_sign(Vector3(t, chunk.AIR_DOOR + 0.6, chunk.S - 0.8), 0.0, txt)


## Authored three-panel departures board. Its black display panels are left
## intact and carry the same deterministic live flight rows as the old
## generated FIDS, so the housing can change without losing world-specific data.


func _fids(parent: Node3D, lpos: Vector3, lyaw: float, big: bool, hang: bool) -> void:
	var v = Node3D.new()
	v.position = lpos
	v.rotation.y = lyaw
	v.set_meta("attributed_furnishing", "airport_departure_board")
	parent.add_child(v)
	var model_scale = chunk.AIRPORT_DEPARTURE_BOARD_BIG_SCALE if big \
		else chunk.AIRPORT_DEPARTURE_BOARD_SMALL_SCALE
	var w = chunk.AIRPORT_DEPARTURE_BOARD_UNITS.x * model_scale
	var h = chunk.AIRPORT_DEPARTURE_BOARD_UNITS.y * model_scale
	if hang:
		var rod_h = maxf(0.1, chunk.ceil_h - lpos.y - h / 2.0)
		for sx in [-w * 0.36, w * 0.36]:
			chunk._mcyl(v, Vector3(sx, h / 2.0 + rod_h / 2.0, -0.04),
				0.016, rod_h, Mats.charcoal())
	var board = chunk._attributed_prop_local(v, chunk.AIRPORT_DEPARTURE_BOARD_PATH,
		-chunk.AIRPORT_DEPARTURE_BOARD_CENTRE * model_scale, 0.0,
		Vector3.ONE * model_scale)
	var front_z = chunk.AIRPORT_DEPARTURE_BOARD_UNITS.z * model_scale * 0.52
	if board != null:
		board.set_meta("authored_model", "airport_departure_board")
	else:
		# A generated fallback keeps airport construction robust if the imported
		# scene is unavailable in an editor-only or stripped export.
		chunk._mrbox(v, Vector3(0, 0, -0.045), Vector3(w, h, 0.13),
			Mats.charcoal(), 0.02)
		chunk._mquad(v, Vector3(0, 0, 0.022), Vector2(w - 0.12, h - 0.12),
			Mats.screen_glow())
		var hd = Label3D.new()
		hd.text = "DEPARTURES"
		hd.font_size = 54 if big else 36
		hd.pixel_size = 0.0022 if big else 0.0018
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
		var hsh = WorldGen.h(chunk.wseed, chunk.cell.x * 3 + i, chunk.cell.y - i, 350)
		dest += chunk.AIR_DESTS[hsh % chunk.AIR_DESTS.size()] + "\n"
		tim += "%02d:%02d\n" % [(hsh >> 3) % 24, ((hsh >> 8) % 12) * 5]
		gate += "%s%d\n" % [["A", "B", "C", "D"][(hsh >> 13) % 4], 1 + ((hsh >> 15) % 28)]
		stat += chunk.AIR_STATUS[(hsh >> 19) % chunk.AIR_STATUS.size()] + "\n"
	# Destination occupies the left panel; time and gate share the centre;
	# status sits on the right. Positions scale with both board variants.
	var xs = [-0.444, -0.031, 0.153, 0.291]
	var texts = [dest, tim, gate, stat]
	for ci in 4:
		var lb = Label3D.new()
		lb.text = texts[ci]
		lb.font_size = 40 if big else 24
		lb.pixel_size = 0.0018 if big else 0.0016
		lb.modulate = Color(1.0, 0.72, 0.18)
		lb.outline_modulate = Color(0.16, 0.08, 0.0, 0.8)
		lb.outline_size = 2
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Clear the model's own "All other airlines" subheader before the first
		# data row; keeping this relative preserves the spacing on both sizes.
		lb.position = Vector3(xs[ci] * w, h / 2.0 - h * 0.26, front_z)
		v.add_child(lb)


func _air_wall_fids(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(46 + dir) - 0.5) * 4.0
	var yaw = 0.0
	var pos: Vector3
	if dir < 2:
		yaw = PI / 2.0 if n > 0.0 else -PI / 2.0
		pos = Vector3(inner + n * 0.10, 2.5, along)
	else:
		yaw = 0.0 if n > 0.0 else PI
		pos = Vector3(along, 2.5, inner + n * 0.10)
	_fids(chunk, pos, yaw, false, false)


## Pair of backlit advertising lightboxes.


func _air_adboxes(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var idx = int(chunk._r(50 + dir) * 3.99)
	for k in 2:
		var along = chunk.S / 2.0 + (float(k) - 0.5) * 3.4
		var fc = inner + n * 0.05
		if dir < 2:
			chunk._box(Vector3(fc, 1.9, along), Vector3(0.08, 1.92, 1.32), Mats.charcoal(), false)
			var q = chunk._quad(Vector3(fc + n * 0.045, 1.9, along), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			chunk._box(Vector3(along, 1.9, fc), Vector3(1.32, 1.92, 0.08), Mats.charcoal(), false)
			var q = chunk._quad(Vector3(along, 1.9, fc + n * 0.045), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = 0.0 if n > 0.0 else PI


## Authored four-seat airport bank. Existing layouts asked for three to five
## generated seats; the real model keeps its designed proportions in all of
## those placements instead of being stretched to an arbitrary count.


func _seat_row(p: Vector3, yaw: float, _n: int, _salt: int) -> void:
	var body0 = chunk.body.get_child_count()
	var row = chunk._furnishing_pivot(p, yaw, "airport_seat_row")
	row.set_meta("airport_seat_facing_yaw", yaw)
	var seats = chunk._attributed_floor_prop(chunk.AIRPORT_SEATS_PATH, Vector3.ZERO,
		PI / 2.0, chunk.AIRPORT_SEATS_SCALE, chunk.AIRPORT_SEATS_CENTRE,
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
	chunk._collider_yaw_box(p + Vector3(0, 0.414, 0),
		Vector3(2.10, 0.83, 0.62), yaw)
	chunk._bind_furnishing_colliders(row, body0)


## One piece from the authored luggage set. The GLB was material-merged, so
## pieces are recovered by their mesh-node membership instead of by subtree.
## `backpack_only` replaces the old "lying suitcase" use with the source set's
## naturally low backpack instead of tipping a rigid case onto an arbitrary side.


func _airport_luggage_model(parent: Node3D, p: Vector3, yaw: float,
		salt: int, backpack_only = false) -> Node3D:
	var piece = 0 if backpack_only else mini(int(chunk._r(salt) * 3.0), 2)
	var pivot = Node3D.new()
	pivot.name = "AirportLuggage"
	pivot.position = p
	pivot.rotation.y = yaw
	pivot.set_meta("attributed_furnishing", "airport_luggage")
	pivot.set_meta("airport_luggage_piece", piece)
	parent.add_child(pivot)
	var inst = chunk._attributed_prop_local(pivot, chunk.AIRPORT_LUGGAGE_PATH,
		-chunk.AIRPORT_LUGGAGE_CENTRES[piece] * chunk.AIRPORT_LUGGAGE_SCALE, 0.0,
		Vector3.ONE * chunk.AIRPORT_LUGGAGE_SCALE)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	inst.set_meta("authored_model", "airport_luggage")
	var keep: Array = chunk.AIRPORT_LUGGAGE_NODES[piece]
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	for found in meshes:
		var mesh_node = found as MeshInstance3D
		if not keep.has(String(mesh_node.name)):
			mesh_node.get_parent().remove_child(mesh_node)
			mesh_node.free()
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source = mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not chunk.AIRPORT_LUGGAGE_BODY_MATERIALS.has(source.resource_name):
				continue
			var tinted = source.duplicate() as BaseMaterial3D
			var tint: Color = chunk.AIRPORT_LUGGAGE_PALETTE[
				mini(int(chunk._r(salt + 19) * chunk.AIRPORT_LUGGAGE_PALETTE.size()),
					chunk.AIRPORT_LUGGAGE_PALETTE.size() - 1)]
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
	var body0 = chunk.body.get_child_count()
	var group = chunk._furnishing_pivot(p, yaw, "airport_luggage")
	var pivot = _airport_luggage_model(group, Vector3.ZERO, 0.0, salt,
		backpack_only)
	if pivot == null:
		group.get_parent().remove_child(group)
		group.free()
		return
	var piece: int = pivot.get_meta("airport_luggage_piece")
	var collider: Vector3 = chunk.AIRPORT_LUGGAGE_COLLIDERS[piece]
	chunk._collider_yaw_box(p + Vector3(0, collider.y * 0.5, 0), collider, yaw)
	chunk._bind_furnishing_colliders(group, body0)


func _air_column(p: Vector2) -> void:
	# The shaft, floor shoe and ceiling cap are one structural assembly. Keeping
	# them as top-level siblings let doorway clearance remove the shaft while
	# leaving its low steel shoe behind as a mysterious "hockey puck".
	var pivot = chunk._furnishing_pivot(Vector3(p.x, 0, p.y), 0.0, "airport_column")
	var b0 = chunk.body.get_child_count()
	chunk._mcyl(pivot, Vector3(0, chunk.ceil_h / 2.0, 0), 0.34, chunk.ceil_h, Mats.paint_white())
	chunk._mcyl(pivot, Vector3(0, 0.09, 0), 0.40, 0.18, Mats.steel())
	chunk._mcyl(pivot, Vector3(0, chunk.ceil_h - 0.15, 0), 0.40, 0.3, Mats.charcoal())
	chunk._collider_cyl(pivot.position + Vector3(0, chunk.ceil_h / 2.0, 0), 0.34, chunk.ceil_h)
	chunk._bind_furnishing_colliders(pivot, b0)


func _air_bin(p: Vector3) -> void:
	chunk._waste_bin(p, chunk._r(int(p.x * 7.0 + p.z * 13.0) + 431) * TAU, "airport_bin")


## Nested baggage trolley (optionally a rank of them).


func _air_trolley(p: Vector3, yaw: float, salt: int, count = 1) -> void:
	for k in count:
		var v = Node3D.new()
		v.position = p + Vector3(0, 0, 0).rotated(Vector3.UP, yaw) + Vector3(sin(yaw), 0, cos(yaw)) * (0.55 * float(k))
		v.rotation.y = yaw
		chunk.add_child(v)
		var bs = chunk._mbox(v, Vector3(0, 0.26, 0.05), Vector3(0.6, 0.045, 0.86), Mats.steel())
		bs.rotation.x = 0.07
		chunk._mbox(v, Vector3(0, 0.47, 0.46), Vector3(0.58, 0.42, 0.035), Mats.steel())
		for sx in [-0.27, 0.27]:
			chunk._mcyl(v, Vector3(sx, 0.66, -0.38), 0.02, 0.8, Mats.steel())
		var hb = chunk._mcyl(v, Vector3(0, 1.05, -0.38), 0.022, 0.58, Mats.rubber_black())
		hb.rotation.z = PI / 2.0
		for sx in [-0.24, 0.24]:
			var wh = chunk._mcyl(v, Vector3(sx, 0.075, 0.34), 0.075, 0.05, Mats.rubber_black())
			wh.rotation.z = PI / 2.0
		var wb = chunk._mcyl(v, Vector3(0, 0.075, -0.34), 0.075, 0.05, Mats.rubber_black())
		wb.rotation.z = PI / 2.0
		if k == 0 and chunk._r(salt + 7) < 0.4:
			_airport_luggage_model(v, Vector3(0, 0.285, 0.05), 0.0,
				salt + 8, true)
	var dv = Vector3(sin(yaw), 0, cos(yaw))
	var cc = p + dv * (0.275 * float(count - 1))
	chunk._collider_yaw_box(cc + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.1 + 0.55 * float(count - 1)), yaw)


## Chrome queue posts with retractable belts strung between them.


func _stanchion_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		var t = float(i) / float(n - 1)
		var pp = a.lerp(b, t)
		chunk._cyl(pp + Vector3(0, 0.49, 0), 0.028, 0.98, Mats.chrome())
		chunk._cyl(pp + Vector3(0, 0.015, 0), 0.16, 0.03, Mats.chrome(), false)
		chunk._cyl(pp + Vector3(0, 0.95, 0), 0.045, 0.06, Mats.charcoal(), false)
	for i in n - 1:
		var p0 = a.lerp(b, float(i) / float(n - 1)) + Vector3(0, 0.88, 0)
		var p1 = a.lerp(b, float(i + 1) / float(n - 1)) + Vector3(0, 0.88, 0)
		var bl = chunk._beam(p0 + (p1 - p0) * 0.06, p1 - (p1 - p0) * 0.06, 0.045, Mats.rubber_black())
		bl.scale.y = 0.022
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- airport: gate ------------------------------------------------------------


func _air_gate() -> void:
	var wdir = _air_pick_wall(310)
	var yw = chunk._yaw_for(wdir) if wdir >= 0 else float(int(chunk._r(311) * 3.99)) * PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var code = _gate_code()
	if wdir >= 0:
		_air_window_wall(o, yw)
	# carpet island under the lounge
	var cp = chunk._wp(o, Vector3(0, 0.008, -1.2), yw)
	var cm = chunk._mbox(chunk, cp, Vector3(10.6, 0.016, 6.6), Mats.airport_carpet())
	cm.rotation.y = yw
	# gate desk off to one side, facing the seats
	_air_gate_desk(o, yw, code)
	# Every lounge row faces the glass. A single deliberately flipped bank used
	# to make the whole gate read as randomly rotated furniture.
	var ri = 0
	for rz in [0.7, -1.1, -2.9]:
		for rx in [-1.9, 1.9]:
			_seat_row(chunk._wp(o, Vector3(rx, 0, rz), yw), yw, 4, 313 + ri)
			ri += 1
	# a bag that never boarded
	if chunk._r(318) < 0.55:
		_airport_luggage(chunk._wp(o, Vector3(-2.6 + 5.2 * chunk._r(319), 0, 1.6), yw),
			chunk._r(320) * TAU, 321)
	if chunk._r(330) < 0.72:
		chunk._security_camera(chunk._wp(o, Vector3(4.7, 3.55, 3.8), yw), yw + PI)


## Full-height glass curtain wall 2.2m inside the anchor wall; the strip
## behind it is the night: black apron, taxiway lights, a docked jetway.


func _air_window_wall(o: Vector3, yw: float) -> void:
	var W = Node3D.new()
	W.position = o
	W.rotation.y = yw
	chunk.add_child(W)
	var gz = 3.8   # glass plane, local z
	# mullions and transoms
	for mx in [-5.95, -4.0, -2.0, 0.0, 2.0, 4.0, 5.95]:
		chunk._mbox(W, Vector3(mx, chunk.ceil_h / 2.0, gz), Vector3(0.09, chunk.ceil_h, 0.14), Mats.charcoal())
	chunk._mbox(W, Vector3(0, 0.06, gz), Vector3(chunk.S, 0.12, 0.14), Mats.charcoal())
	chunk._mbox(W, Vector3(0, chunk.ceil_h - 0.07, gz), Vector3(chunk.S, 0.14, 0.14), Mats.charcoal())
	for ty in [1.35, 2.9]:
		chunk._mbox(W, Vector3(0, ty, gz), Vector3(chunk.S, 0.07, 0.10), Mats.charcoal())
	# The glass itself — one thin sheet, one collider. Airport glazing uses a
	# stronger blue-grey tint than generic decorative glass so the collision
	# plane never reads as empty air.
	var barrier_glass = chunk._mbox(W, Vector3(0, chunk.ceil_h / 2.0, gz),
		Vector3(chunk.S - 0.1, chunk.ceil_h - 0.2, 0.024), Mats.airport_glass())
	barrier_glass.set_meta("airport_barrier_glass", true)
	barrier_glass.set_meta("barrier_alpha", 0.38)
	chunk._collider_yaw_box(chunk._wp(o, Vector3(0, chunk.ceil_h / 2.0, gz), yw), Vector3(chunk.S, chunk.ceil_h, 0.1), yw)
	# Two rows of ceramic manifestation dots make the full-height pane legible
	# head-on without turning the apron view into an opaque wall.
	for row_y in [1.28, 1.58]:
		for i in 16:
			var mx = -5.55 + 0.74 * float(i)
			chunk._mrbox(W, Vector3(mx, row_y, gz - 0.018),
				Vector3(0.12, 0.045, 0.012), Mats.airport_glass_marker(), 0.012)
	# dark soffit over the strip so no interior ceiling reads as "outside"
	chunk._mbox(W, Vector3(0, chunk.ceil_h - 0.10, 4.85), Vector3(chunk.S, 0.06, 2.15), Mats.charcoal())
	# side caps close the strip ends
	for sx in [-5.9, 5.9]:
		chunk._mbox(W, Vector3(sx, chunk.ceil_h / 2.0, 4.85), Vector3(0.1, chunk.ceil_h, 2.1), Mats.charcoal())
		chunk._collider_yaw_box(chunk._wp(o, Vector3(sx, chunk.ceil_h / 2.0, 4.85), yw), Vector3(0.12, chunk.ceil_h, 2.1), yw)
	# apron floor and the night beyond
	var ap = chunk._mbox(W, Vector3(0, 0.012, 4.9), Vector3(chunk.S, 0.022, 2.15), Mats.asphalt())
	ap.rotation.y = 0.0
	var night = chunk._mquad(W, Vector3(0, chunk.ceil_h / 2.0, 5.82), Vector2(chunk.S, chunk.ceil_h), Mats.apron_night())
	night.rotation.y = PI
	# taxiway edge lights receding along the strip
	for i in 5:
		var lx = -5.0 + 2.5 * float(i)
		chunk._msphere(W, Vector3(lx, 0.06, 5.3), 0.045, Mats.lamp_blue())
	for li in 2:
		var l = OmniLight3D.new()
		l.light_color = Color(0.3, 0.55, 1.0)
		l.light_energy = 0.35
		l.omni_range = 3.5
		l.position = Vector3(-2.5 + 5.0 * float(li), 0.4, 5.2)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 16.0
		l.distance_fade_length = 8.0
		W.add_child(l)
	_air_jetway(W)
	# most gates have their aircraft still on stand
	if chunk._r(322) < 0.6:
		_air_docked_plane(W)
	# boarding door set into the glass, sealed
	var dx = -2.6
	for jx in [dx - 0.7, dx + 0.7]:
		chunk._mbox(W, Vector3(jx, 1.15, gz), Vector3(0.12, 2.3, 0.18), Mats.steel())
	chunk._mbox(W, Vector3(dx, 2.36, gz), Vector3(1.52, 0.12, 0.18), Mats.steel())
	chunk._mbox(W, Vector3(dx, 1.15, gz + 0.02), Vector3(1.3, 2.3, 0.05), Mats.charcoal())
	chunk._mbox(W, Vector3(dx, 1.02, gz - 0.05), Vector3(0.8, 0.06, 0.05), Mats.steel())
	chunk._mbox(W, Vector3(dx - 0.25, 1.7, gz + 0.05),
		Vector3(0.3, 0.4, 0.02), Mats.airport_glass())


## A widebody parked at the stand, seen side-on through the glass. This is a
## deliberately shallow forced-perspective diorama: the aircraft stays inside
## the sealed apron strip while the dark rear plane supplies the missing depth.


func _air_docked_plane(W: Node3D) -> void:
	# This is a shallow gate-window diorama, not real exterior space. The old
	# 2.3 m fuselage was centred on the terminal boundary and deliberately ran
	# past the side returns. In adjoining rooms its end cap and body therefore
	# appeared through solid walls as giant grey discs and tubes. Keep every
	# visible aircraft mesh wholly inside the sealed apron strip instead.
	var P = Node3D.new()
	P.set_meta("airport_apron_setpiece", "docked_plane")
	W.add_child(P)
	var fus_y = 2.3
	var fus_z = 4.88
	var fus_r = 0.88
	var fus = chunk._mcyl(P, Vector3(0, fus_y, fus_z), fus_r, 10.5, Mats.jetway_body())
	fus.rotation.z = PI / 2.0
	fus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# cabin windows above the centreline — a scatter of them still warm
	for i in 15:
		var wx = -5.6 + 0.8 * float(i)
		if absf(wx) > 5.05:
			continue
		if chunk._r(560 + i) < 0.25:
			continue
		var lit = chunk._r(580 + i) < 0.4
		var wmat: Material = Mats.cabin_warm() if lit else Mats.screen_dark()
		var wnd = chunk._mbox(P, Vector3(wx, fus_y + 0.24, fus_z - fus_r - 0.015),
			Vector3(0.10, 0.13, 0.03), wmat)
		wnd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# one engine pod slung ahead of the glassline, its wing lost in the dark
	var wing = chunk._mbox(P, Vector3(2.6, 2.0, 5.18), Vector3(2.4, 0.1, 0.86), Mats.jetway_body())
	wing.rotation.y = 0.28
	wing.rotation.z = 0.05
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nac = chunk._mcyl(P, Vector3(2.1, 1.28, 4.82), 0.44, 1.35, Mats.jetway_body())
	nac.rotation.z = PI / 2.0
	nac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var intake = chunk._mcyl(P, Vector3(1.40, 1.28, 4.82), 0.37, 0.05, Mats.screen_dark())
	intake.rotation.z = PI / 2.0
	intake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# anti-collision beacon flashing on the shoulder of the hull
	var bmat: StandardMaterial3D = Mats.lamp_red().duplicate()
	var bulb = chunk._msphere(P, Vector3(0.8, fus_y + 0.76, 4.38), 0.055, bmat)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bc = Beacon.new()
	bc.mat = bmat
	bc.phase = chunk._r(590) * 1.4
	bc.light_color = Color(1.0, 0.12, 0.08)
	bc.omni_range = 4.0
	bc.position = Vector3(0.8, fus_y + 0.72, 4.32)
	bc.shadow_enabled = false
	bc.distance_fade_enabled = true
	bc.distance_fade_begin = 20.0
	bc.distance_fade_length = 8.0
	P.add_child(bc)
	# faint spill of cabin light onto the apron below the windows
	var spill = OmniLight3D.new()
	spill.light_color = Color(1.0, 0.8, 0.55)
	spill.light_energy = 0.2
	spill.omni_range = 3.2
	spill.position = Vector3(-1.5, fus_y, 4.15)
	spill.shadow_enabled = false
	spill.distance_fade_enabled = true
	spill.distance_fade_begin = 16.0
	spill.distance_fade_length = 6.0
	P.add_child(spill)


## The jetway out on the apron: ribbed telescoping tunnel on its wheel bogie,
## rotunda at the far end, red beacon still breathing.


func _air_jetway(W: Node3D) -> void:
	var J = Node3D.new()
	J.position = Vector3(-0.8, 1.95, 5.15)
	J.rotation.y = 0.06
	J.rotation.z = 0.08
	W.add_child(J)
	var tube = chunk._mcyl(J, Vector3.ZERO, 0.5, 5.6, Mats.jetway_body())
	tube.rotation.z = PI / 2.0
	# accordion ribs over the telescoping midsection
	for i in 7:
		var rx = -1.9 + 0.5 * float(i)
		var tor = MeshInstance3D.new()
		tor.mesh = chunk.TOR
		tor.material_override = Mats.charcoal()
		tor.position = Vector3(rx, 0, 0)
		tor.rotation.z = PI / 2.0
		tor.scale = Vector3(0.72, 0.5, 0.72)
		J.add_child(tor)
	# dark window band along the tunnel
	chunk._mbox(J, Vector3(0.6, 0.18, 0.55), Vector3(2.6, 0.34, 0.04), Mats.screen_dark())
	# rotunda cab at the far end
	chunk._mrbox(J, Vector3(-3.1, -0.1, 0), Vector3(1.35, 1.6, 1.5), Mats.jetway_body(), 0.08)
	chunk._mbox(J, Vector3(-3.1, 0.25, 0), Vector3(1.4, 0.4, 1.4), Mats.screen_dark())
	# service door end nearest the glass
	chunk._mrbox(J, Vector3(2.85, -0.05, 0), Vector3(0.95, 1.9, 1.05), Mats.jetway_body(), 0.05)
	# wheel bogie
	chunk._mbox(J, Vector3(-1.0, -1.25, 0), Vector3(0.16, 1.7, 0.16), Mats.charcoal())
	var axle = chunk._mcyl(J, Vector3(-1.0, -2.05, 0), 0.04, 0.6, Mats.charcoal())
	axle.rotation.x = PI / 2.0
	for sz in [-0.26, 0.26]:
		var wh = chunk._mcyl(J, Vector3(-1.0, -2.05, sz), 0.3, 0.18, Mats.rubber_black())
		wh.rotation.x = PI / 2.0
	# anti-collision beacon
	chunk._msphere(J, Vector3(0.4, 0.6, 0), 0.05, Mats.lamp_red())
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 0.22
	l.omni_range = 2.6
	l.position = Vector3(0.4, 0.85, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 18.0
	l.distance_fade_length = 8.0
	J.add_child(l)


func _air_gate_desk(o: Vector3, yw: float, code: String) -> void:
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(1.7, 0, 2.4), yw)
	v.rotation.y = yw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 0.06, 0), Vector3(2.3, 0.12, 0.6), Mats.charcoal())
	chunk._mrbox(v, Vector3(0, 0.56, 0), Vector3(2.3, 1.0, 0.58), Mats.desk_white(), 0.02)
	chunk._mbox(v, Vector3(0, 1.08, 0), Vector3(2.36, 0.04, 0.66), Mats.steel())
	# two dead monitors on poles
	for mx in [-0.5, 0.5]:
		chunk._mcyl(v, Vector3(mx, 1.2, 0.05), 0.02, 0.2, Mats.charcoal())
		chunk._mrbox(v, Vector3(mx, 1.44, 0.05), Vector3(0.44, 0.3, 0.035), Mats.screen_dark(), 0.008)
	chunk._collider_yaw_box(v.position + Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 0.7), yw)
	# the lit gate sign overhead
	var sv = Node3D.new()
	sv.position = chunk._wp(o, Vector3(1.7, 3.4, 1.7), yw)
	sv.rotation.y = yw
	chunk.add_child(sv)
	var rod_h = chunk.ceil_h - 3.4 - 0.34
	for sx in [-0.5, 0.5]:
		chunk._mcyl(sv, Vector3(sx, 0.34 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	chunk._mrbox(sv, Vector3.ZERO, Vector3(1.5, 0.68, 0.1), Mats.sign_navy(), 0.015)
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
	var span = chunk._room_span()
	var along_x = span.x >= span.y
	var yw = 0.0 if along_x else PI / 2.0
	var run = (span.x if along_x else span.y) - 2.6
	var lat = span.y if along_x else span.x
	if run < 6.0:
		_air_hall()   # too short for a walkway; furnish it as a plain hall
		return
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var pair = chunk._r(321) < 0.55 and lat >= 10.0
	var offs = [-1.35, 1.35] if pair else [0.0]
	var flow0 = 1.0 if chunk._r(322) < 0.5 else -1.0
	for i in offs.size():
		_travelator(chunk._wp(o, Vector3(0, 0, offs[i]), yw), yw,
			flow0 * (1.0 if i == 0 else -1.0), 323 + i, minf(10.4, run))
		_hang_sign(o + Vector3(0, 3.55, 0), yw + PI / 2.0,
			_air_zone_sign(326))
	# a seat row parked against the quiet side, only if there is room beside
	# the belts for it
	var side = lat / 2.0 - 1.6
	if chunk._r(327) < 0.55 and side >= (3.4 if pair else 2.8):
		var sp = chunk._wp(o, Vector3(0.8, 0, side * (1.0 if chunk._r(329) < 0.5 else -1.0)), yw)
		_seat_row(sp, yw + PI / 2.0, 5, 328)
	# Clutter keeps to the margins, well clear of the belts — but the seat row
	# above is parked on that same margin, and `clut` collapses onto `side`
	# whenever the room is narrow enough, putting both on one line. Each has to
	# check the spot is free or the bag ends up standing inside the seating.
	var clut = minf(side, 4.5 if pair else 3.9)
	if clut >= 2.6:
		if chunk._r(540) < 0.5:
			var bp = chunk._wp(o, Vector3(-3.5 + 7.0 * chunk._r(541), 0,
				clut * (1.0 if chunk._r(542) < 0.5 else -1.0)), yw)
			if chunk._floor_spot_clear(bp, 0.42, 1.0):
				_air_bin(bp)
		if chunk._r(543) < 0.2:
			var cp = chunk._wp(o, Vector3(-3.0 + 6.0 * chunk._r(544), 0,
				clut * (1.0 if chunk._r(545) < 0.5 else -1.0)), yw)
			if chunk._floor_spot_clear(cp, 0.40, 1.0):
				_airport_luggage(cp, chunk._r(546) * TAU, 547)


## One moving walkway: deck, animated belt, glass balustrades, and an Area3D
## that actually carries whoever stands on it.


func _travelator(p: Vector3, yaw: float, flow: float, salt: int, L = 8.4) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var BW = 1.15
	chunk._mbox(v, Vector3(0, 0.055, 0), Vector3(L, 0.11, BW + 0.7), Mats.steel())
	var belt = chunk._mbox(v, Vector3(0, 0.117, 0), Vector3(L - 1.0, 0.014, BW), Mats.belt())
	belt.set_instance_shader_parameter("speed", flow * 0.75)
	for e in [-1.0, 1.0]:
		var ramp = chunk._mbox(v, Vector3(e * (L / 2.0 + 0.26), 0.048, 0), Vector3(0.64, 0.02, BW + 0.7), Mats.steel())
		ramp.rotation.z = -e * 0.16
		chunk._mbox(v, Vector3(e * (L / 2.0 - 0.30), 0.115, 0), Vector3(0.5, 0.014, BW), Mats.caution_yellow())
	for szn in [-1.0, 1.0]:
		var z: float = szn * (BW / 2.0 + 0.16)
		chunk._mbox(v, Vector3(0, 0.32, z), Vector3(L, 0.42, 0.06), Mats.steel())
		var bg = chunk._mbox(v, Vector3(0, 0.78, z),
			Vector3(L - 0.3, 0.55, 0.024), Mats.airport_glass())
		bg.set_meta("airport_barrier_glass", true)
		bg.set_meta("barrier_alpha", 0.38)
		bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bh = chunk._mrbox(v, Vector3(0, 1.08, z), Vector3(L, 0.075, 0.09), Mats.rubber_black(), 0.03)
		bh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for e in [-1.0, 1.0]:
			chunk._mrbox(v, Vector3(e * (L / 2.0 - 0.06), 0.6, z), Vector3(0.1, 0.98, 0.09), Mats.rubber_black(), 0.04)
		chunk._collider_yaw_box(chunk._wp(p, Vector3(0, 0.6, z), yaw), Vector3(L, 1.25, 0.1), yaw)
	# deck + end ramps the player can actually walk up
	chunk._collider_yaw_box(p + Vector3(0, 0.065, 0), Vector3(L - 0.9, 0.13, BW + 0.5), yaw)
	for e in [-1.0, 1.0]:
		chunk._collider_rot_box(chunk._wp(p, Vector3(e * (L / 2.0 + 0.22), 0.05, 0), yaw),
			Vector3(0.95, 0.035, BW + 0.5), Vector3(0, yaw, -e * 0.16))
	var tv = Travelator.new()
	tv.dirv = Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	tv.speed = 0.75
	var cs = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = Vector3(L - 1.6, 1.6, BW)
	cs.shape = sh
	tv.add_child(cs)
	tv.position = p + Vector3(0, 0.95, 0)
	tv.rotation.y = yaw
	chunk.add_child(tv)


## Transit corridor: three chained walkways in a complete low tube. Side room
## connections get finished portals into a narrow walking margin; every other
## stretch is continuous wall, so there is no cell-end route behind a facade.


func _air_transit() -> void:
	var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
	var along_x: bool
	if cdir != 0:
		along_x = cdir == 1
	else:
		along_x = WorldGen.r01(chunk.wseed, 0, chunk.cell.y, 511) < 0.5
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var wall_half = 5.2
	var wh = 3.5
	for k in 3:
		var off = (float(k) - 1.0) * 3.4
		var flow = 1.0 if k % 2 == 0 else -1.0
		_travelator(chunk._wp(o, Vector3(0, 0, off), yw), yw, flow, 512 + k, 10.4)

	# A single architectural contract drives wall cuts, returns and dressing.
	for si in 2:
		var data = _air_transit_side_data(si, along_x, wall_half)
		_air_transit_wall_side(o, yw, float(data["side"]), wh, data["bay"])
		if chunk._r(530 + si) < 0.62:
			var at = _air_transit_ad_t(si, data["bay"])
			if at < 90.0:
				var side: float = data["side"] - signf(float(data["side"])) * 0.1
				var q = chunk._mquad(chunk, chunk._wp(o, Vector3(at, 1.9, side), yw),
					Vector2(1.2, 1.8), Mats.adbox(int(chunk._r(534 + si) * 3.99)))
				q.rotation.y = yw + (PI if side > 0.0 else 0.0)

	# The dropped lid now reaches the continuous walls. Side portal helpers add
	# their own small ceiling patches over the remaining boundary recess.
	var sof = chunk._mbox(chunk, chunk._wp(o, Vector3(0, wh + 0.06, 0), yw),
		Vector3(chunk.S, 0.12, wall_half * 2.0 + chunk.T), Mats.airport_ceiling())
	sof.rotation.y = yw
	# Low light lines under the bulkhead — the tall terminal above stays dark.
	var pmat = Mats.air_panel()
	for li in 2:
		var lane = -1.7 if li == 0 else 1.7
		for t in [-3.0, 0.0, 3.0]:
			var st = chunk._mbox(chunk, chunk._wp(o, Vector3(t, wh - 0.03, lane), yw),
				Vector3(2.2, 0.05, 0.16), pmat)
			st.rotation.y = yw
	var l = OmniLight3D.new()
	l.light_color = Color(0.85, 0.91, 1.0)
	l.light_energy = 1.2
	l.omni_range = 11.0
	l.position = o + Vector3(0, wh - 0.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	chunk.add_child(l)
	# Wayfinding over the two genuine walking lanes, tucked under the lid.
	for ki in 2:
		var sl = -1.7 if ki == 0 else 1.7
		if chunk._r(516 + ki) < 0.55:
			_hang_sign(chunk._wp(o, Vector3(0, 2.8, sl), yw), yw + PI / 2.0,
					_air_zone_sign(518 + ki), wh)


func _air_transit_side_data(si: int, along_x: bool, wall_half: float) -> Dictionary:
	var side = -wall_half if si == 0 else wall_half
	var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info = WorldGen.edge_info(chunk.wseed, chunk.cell, sdir, chunk.theme)
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
		segs = chunk._cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
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
	var wc = chunk._wp(o, Vector3(c, wh * 0.5, side), yw)
	var wall = chunk._mbox(chunk, wc, Vector3(ln, wh, chunk.T),
		Mats.airport_wall_variant(chunk._finish_variant()))
	wall.rotation.y = yw
	chunk._collider_yaw_box(wc, Vector3(ln, wh, chunk.T), yw)
	var inn = side - signf(side) * (chunk.T * 0.5 + 0.022)
	var kick = chunk._mbox(chunk, chunk._wp(o, Vector3(c, 0.11, inn), yw),
		Vector3(ln, 0.22, 0.045), Mats.steel())
	kick.rotation.y = yw
	var bumper = chunk._mbox(chunk, chunk._wp(o, Vector3(c, 0.78, inn - signf(side) * 0.02), yw),
		Vector3(ln, 0.055, 0.075), Mats.rubber_black())
	bumper.rotation.y = yw
	for seam in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		if seam <= a + 0.05 or seam >= b - 0.05:
			continue
		var reveal = chunk._mbox(chunk, chunk._wp(o, Vector3(seam, wh * 0.5, inn), yw),
			Vector3(0.028, wh, 0.035), Mats.metal_gray())
		reveal.rotation.y = yw


func _air_transit_header(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var hh = wh - chunk.AIR_DOOR
	if hh <= 0.02:
		return
	var hp = chunk._wp(o, Vector3(t, chunk.AIR_DOOR + hh * 0.5, side), yw)
	var head = chunk._mbox(chunk, hp, Vector3(width, hh, chunk.T),
		Mats.airport_wall_variant(chunk._finish_variant()))
	head.rotation.y = yw
	chunk._collider_yaw_box(hp, Vector3(width, hh, chunk.T), yw)


func _air_transit_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn = side - signf(side) * (chunk.T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = chunk._mbox(chunk, chunk._wp(o, Vector3(edge, chunk.AIR_DOOR * 0.5, inn), yw),
			Vector3(0.2, chunk.AIR_DOOR, chunk.T + 0.2), Mats.steel())
		jamb.rotation.y = yw
	var lintel = chunk._mbox(chunk, chunk._wp(o, Vector3(t, chunk.AIR_DOOR + 0.1, inn), yw),
		Vector3(width + 0.22, 0.2, chunk.T + 0.2), Mats.steel())
	lintel.rotation.y = yw
	# Small backlit identifier fixed to the portal head, facing the transit lane.
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(t, chunk.AIR_DOOR - 0.16, inn - signf(side) * 0.04), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	chunk.add_child(v)
	chunk._mrbox(v, Vector3.ZERO, Vector3(minf(width - 0.35, 2.35), 0.23, 0.05),
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
	var outer = signf(side) * (chunk.S * 0.5 - chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = chunk._wp(o, Vector3(edge, wh * 0.5, dc), yw)
		var ret = chunk._mbox(chunk, wp, Vector3(chunk.T, wh, depth),
			Mats.airport_wall_variant(chunk._finish_variant()))
		ret.rotation.y = yw
		chunk._collider_yaw_box(wp, Vector3(chunk.T, wh, depth), yw)
		var inward = chunk.T * 0.5 + 0.022 if edge < t else -(chunk.T * 0.5 + 0.022)
		var kick = chunk._mbox(chunk, chunk._wp(o, Vector3(edge + inward, 0.11, dc), yw),
			Vector3(0.045, 0.22, depth), Mats.steel())
		kick.rotation.y = yw
	var roof = chunk._mbox(chunk, chunk._wp(o, Vector3(t, wh + 0.06, dc), yw),
		Vector3(width, 0.12, depth), Mats.airport_ceiling())
	roof.rotation.y = yw
	var bl = OmniLight3D.new()
	bl.light_color = Color(0.85, 0.91, 1.0)
	bl.light_energy = 0.48
	bl.omni_range = 4.6
	bl.position = chunk._wp(o, Vector3(t, wh - 0.38, dc), yw)
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	chunk.add_child(bl)


func _air_transit_ad_t(si: int, bay: Array) -> float:
	var raw = -3.0 + 6.0 * chunk._r(532 + si)
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
	var yw = chunk._yaw_for(wdir) if wdir >= 0 else ((PI / 2.0) if chunk._r(361) < 0.5 else 0.0)
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# The authored position is 4.78m wide, so a row of two fills the same span
	# three narrow generated desks used to. Falling back to the generated desk
	# restores the tighter three-desk row.
	if chunk._prop_scene(chunk.CHECKIN_DESK_PATH) != null:
		for di in 2:
			_checkin_desk(o, yw, -2.6 + 5.2 * float(di), 365 + di * 4)
	else:
		for di in 3:
			_checkin_desk(o, yw, -3.6 + 3.6 * float(di), 365 + di * 4)
	# the big board hanging over the queue
	_fids(chunk, chunk._wp(o, Vector3(0, 3.15, 1.1), yw), yw + PI, true, true)
	# serpentine of queue barriers holding a line for no one
	_stanchion_line(chunk._wp(o, Vector3(-4.2, 0, 1.6), yw), chunk._wp(o, Vector3(4.2, 0, 1.6), yw), 6)
	_stanchion_line(chunk._wp(o, Vector3(4.2, 0, 0.4), yw), chunk._wp(o, Vector3(-4.2, 0, 0.4), yw), 6)
	if chunk._r(374) < 0.5:
		_stanchion_line(chunk._wp(o, Vector3(-4.2, 0, -0.8), yw), chunk._wp(o, Vector3(4.2, 0, -0.8), yw), 6)
	if chunk._r(375) < 0.55:
		_air_trolley(chunk._wp(o, Vector3(-4.6 + 9.2 * chunk._r(376), 0, -2.6), yw), chunk._r(377) * TAU, 378, 1)
	if chunk._r(379) < 0.68:
		chunk._security_camera(chunk._wp(o, Vector3(4.55, 3.45, chunk.S * 0.5 - chunk.T * 0.5), yw), yw + PI)


func _checkin_desk(o: Vector3, yw: float, dx: float, salt: int) -> void:
	var authored = chunk._prop_scene(chunk.CHECKIN_DESK_PATH) != null
	# The generated desk is a shallow counter that sat 3.55m off centre. The
	# authored position is 3.2m deep, so it stands back far enough for its belt
	# housing to reach the wall without the counter crowding the queue lane.
	var dz = 4.20 if authored else 3.55
	var b0 = chunk.body.get_child_count()
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(dx, 0, dz), yw)
	v.rotation.y = yw
	v.set_meta("atomic_furnishing", "airport_checkin_desk")
	v.set_meta("floor_supported", true)
	chunk._furnishing_group_serial += 1
	v.set_meta("furnishing_group", chunk._furnishing_group_serial)
	chunk.add_child(v)
	# The authored position supplies the counter, the agent monitor mast, the
	# baggage scale and the belt housing — the twelve primitives that used to
	# fake them are the fallback below. Its counter faces local -Z, which is
	# the queue side, matching the generated desk it replaces.
	var desk: Node3D = null
	if authored:
		desk = chunk._attributed_prop_local(v, chunk.CHECKIN_DESK_PATH,
			-chunk.CHECKIN_DESK_CENTRE * chunk.CHECKIN_DESK_SCALE, 0.0,
			Vector3.ONE * chunk.CHECKIN_DESK_SCALE)
	if desk != null:
		v.set_meta("attributed_furnishing", "airport_checkin_desk")
		# Counter run and the belt housing behind it, as two boxes rather than
		# one: the queue side in front of the counter must stay walkable.
		chunk._collider_yaw_box(chunk._wp(v.position, Vector3(0, 0.58, -1.05), yw),
			Vector3(chunk.CHECKIN_DESK_W, 1.16, 1.10), yw)
		chunk._collider_yaw_box(chunk._wp(v.position, Vector3(0, 0.72, 0.60), yw),
			Vector3(chunk.CHECKIN_DESK_W, 1.44, 2.00), yw)
	else:
		# counter facing the queue (local -z)
		chunk._mbox(v, Vector3(0.35, 0.06, 0), Vector3(1.9, 0.12, 0.68), Mats.charcoal())
		chunk._mrbox(v, Vector3(0.35, 0.57, 0), Vector3(1.9, 1.02, 0.66), Mats.desk_white(), 0.02)
		chunk._mbox(v, Vector3(0.35, 1.1, 0), Vector3(1.96, 0.04, 0.74), Mats.steel())
		chunk._collider_yaw_box(chunk._wp(v.position, Vector3(0.35, 0.6, 0), yw), Vector3(1.9, 1.2, 0.75), yw)
		# monitor on a pole, screen to the agent side
		chunk._mcyl(v, Vector3(0.85, 1.55, 0.1), 0.025, 0.9, Mats.metal_gray())
		var lit = chunk._r(salt) < 0.4
		chunk._mrbox(v, Vector3(0.85, 2.1, 0.1), Vector3(0.5, 0.34, 0.04), Mats.screen_glow() if lit else Mats.screen_dark(), 0.008)
		if lit:
			var lb = Label3D.new()
			lb.text = "CLOSED"
			lb.font_size = 40
			lb.pixel_size = 0.002
			lb.modulate = Color(1.0, 0.5, 0.25)
			lb.position = Vector3(0.85, 2.1, 0.13)
			v.add_child(lb)
		# baggage scale and the belt that climbs into the wall housing
		chunk._mbox(v, Vector3(-0.75, 0.17, 0.35), Vector3(0.8, 0.34, 0.95), Mats.steel())
		chunk._mbox(v, Vector3(-0.75, 0.355, 0.35), Vector3(0.68, 0.02, 0.85), Mats.rubber_black())
		var stub = chunk._mbox(v, Vector3(-0.75, 0.62, 1.25), Vector3(0.68, 0.05, 1.0), Mats.rubber_black())
		stub.rotation.x = -0.45
		chunk._mbox(v, Vector3(-0.75, 1.0, 1.95), Vector3(0.92, 1.9, 0.5), Mats.steel())
		for fi in 4:
			chunk._mbox(v, Vector3(-0.99 + 0.16 * float(fi), 1.25, 1.68), Vector3(0.14, 0.5, 0.02), Mats.rubber_black())
		chunk._collider_yaw_box(chunk._wp(v.position, Vector3(-0.75, 0.5, 0.8), yw), Vector3(0.9, 1.0, 2.0), yw)
	chunk._bind_furnishing_colliders(v, b0)
	# Position number hanging above. Over the authored desk it moves a metre
	# forward, to hang over the counter rather than the belt run behind it —
	# far enough back to leave the big departures board its own airspace, and
	# 2.5m clear of the 3.55m monitor mast at the desk's other end.
	var pn = Node3D.new()
	pn.position = chunk._wp(o, Vector3(dx + 0.35, 3.0,
		dz - (1.00 if authored else 0.0)), yw)
	pn.rotation.y = yw
	chunk.add_child(pn)
	var rod_h = chunk.ceil_h - 3.0 - 0.26
	chunk._mcyl(pn, Vector3(0, 0.26 + rod_h / 2.0, 0), 0.014, rod_h, Mats.charcoal())
	chunk._mrbox(pn, Vector3.ZERO, Vector3(0.5, 0.5, 0.08), Mats.sign_navy(), 0.012)
	for sside in [-1.0, 1.0]:
		var nl = Label3D.new()
		nl.text = "%02d" % (1 + (WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 2) % 24))
		nl.font_size = 90
		nl.pixel_size = 0.0026
		nl.modulate = Color(0.96, 0.92, 0.5)
		nl.position = Vector3(0, 0, sside * 0.05)
		nl.rotation.y = 0.0 if sside > 0.0 else PI
		pn.add_child(nl)


# --- airport: baggage claim ---------------------------------------------------


func _air_baggage() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# This marker stays on the chunk even if doorway cleanup removes a
	# furnishing. Audits can therefore distinguish a room that never requested
	# a carousel from a requested carousel that was partially/fully culled.
	chunk.set_meta("airport_baggage_carousel_expected", true)
	# The rim, belt and centre island are one bounded furnishing. They used to
	# be unrelated top-level nodes, so doorway cleanup could remove whichever
	# outer panels crossed an approach while leaving the inner belt behind.
	# Pulling the radius inside the 3.6m protected lanes and binding the whole
	# assembly guarantees a carousel is either complete or absent.
	var body0 = chunk.body.get_child_count()
	var carousel = chunk._furnishing_pivot(c, 0.0,
		"airport_baggage_carousel")
	carousel.set_meta("airport_carousel_complete", true)
	# RoundedBox bevel geometry extends about 0.21m beyond its nominal radial
	# half-depth, so a 2.22m centre line still grazed a lane beginning 2.40m
	# from the room centre. Keep the complete visible shell comfortably inside.
	var rim_radius = 2.05
	# static stainless rim
	var seg = 18
	for i in seg:
		var ang = TAU * float(i) / float(seg)
		var rp = Vector3(cos(ang) * rim_radius, 0.22,
			sin(ang) * rim_radius)
		var b = chunk._mrbox(carousel, rp, Vector3(0.80, 0.44, 0.18),
			Mats.steel(), 0.015)
		b.rotation.y = -(ang + PI / 2.0)
		b.set_meta("airport_carousel_siding", true)
		var lip = chunk._mrbox(carousel,
			rp + Vector3(cos(ang) * 0.07, 0.235,
				sin(ang) * 0.07),
			Vector3(0.82, 0.055, 0.22), Mats.steel(), 0.012)
		lip.rotation.y = -(ang + PI / 2.0)
		lip.set_meta("airport_carousel_lip", true)
	for i in 8:
		var ang = TAU * float(i) / 8.0
		chunk._collider_yaw_box(c + Vector3(cos(ang) * rim_radius, 0.35,
			sin(ang) * rim_radius), Vector3(1.76, 0.70, 0.20),
			-(ang + PI / 2.0))
	# the bed of slats, turning forever
	var sp = Spinner.new()
	sp.speed = 0.16 if chunk._r(379) < 0.8 else 0.0
	sp.position = Vector3(0, 0.47, 0)
	sp.set_meta("airport_carousel_belt", true)
	carousel.add_child(sp)
	var belt_radius = 1.54
	var slats = 28
	for i in slats:
		var ang = TAU * float(i) / float(slats)
		var sl = chunk._mbox(sp, Vector3(cos(ang) * belt_radius, 0,
			sin(ang) * belt_radius), Vector3(1.20, 0.035, 0.32),
			Mats.rubber_black())
		sl.rotation.y = -ang
		sl.set_meta("airport_carousel_slat", true)
	for i in 1 + int(chunk._r(380) * 2.0):
		var ang = chunk._r(381 + i) * TAU
		# Luggage rides inside the outer lip and follows the belt tangent. A
		# randomly yawed case at the slat radius could overhang the protected
		# doorway lane by a few centimetres and cause cleanup to reject the
		# otherwise valid complete carousel.
		var luggage_radius = 1.25
		_airport_luggage_model(sp,
			Vector3(cos(ang) * luggage_radius, 0.019,
				sin(ang) * luggage_radius),
			-(ang + PI / 2.0) + (chunk._r(385 + i) - 0.5) * 0.28,
			383 + i, chunk._r(387 + i) < 0.34)
	# centre island
	chunk._mcyl(carousel, Vector3(0, 0.5, 0), 0.90, 1.0,
		Mats.metal_gray())
	chunk._mcone(carousel, Vector3(0, 1.0, 0), 1.0, 0.55,
		Mats.metal_gray())
	chunk._collider_cyl(c + Vector3(0, 0.5, 0), 0.90, 1.0)
	chunk._bind_furnishing_colliders(carousel, body0)
	# feed chute descending from the ceiling void, mouth over the belt
	var duct = chunk._box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Mats.steel(), false)
	duct.rotation.x = 0.5
	chunk._collider_rot_box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Vector3(0.5, 0, 0))
	chunk._box(c + Vector3(0, 3.7, -5.0), Vector3(1.25, 2.6, 0.85), Mats.steel())
	for fi in 5:
		var fl = chunk._box(c + Vector3(-0.44 + 0.22 * float(fi), 0.85,
			-1.54), Vector3(0.2, 0.5, 0.02),
			Mats.rubber_black(), false)
		fl.rotation.x = 0.4
	# belt number totem, still lit
	var tot = Vector3(c.x - 3.4, 0, c.z - 2.4)
	chunk._box(tot + Vector3(0, 1.35, 0), Vector3(0.55, 2.7, 0.2), Mats.charcoal())
	chunk._quad(tot + Vector3(0, 1.9, 0.104), Vector2(0.42, 0.6), Mats.screen_glow())
	var num = Label3D.new()
	num.text = "%d" % (1 + (WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 386) % 8))
	num.font_size = 220
	num.pixel_size = 0.0022
	num.modulate = Color(0.96, 0.92, 0.5)
	num.position = tot + Vector3(0, 1.9, 0.12)
	chunk.add_child(num)
	_hang_sign(c + Vector3(0.5, 3.6, 0.5), float(int(chunk._r(387) * 3.99)) * PI / 2.0, "Baggage Claim")
	# trolley rank and strays
	if chunk._r(388) < 0.7:
		_air_trolley(Vector3(1.6 + 1.2 * chunk._r(389), 0, 1.5), (chunk._r(390) - 0.5) * 0.4, 391, 2 + int(chunk._r(392) * 2.0))
	if chunk._r(393) < 0.6:
		var stray = Vector3(2.2 + 7.6 * chunk._r(394), 0, 8.6 + 1.6 * chunk._r(395))
		if chunk._floor_spot_clear(stray, 0.40, 1.0):
			_airport_luggage(stray, chunk._r(396) * TAU, 397, chunk._r(398) < 0.5)
	if chunk.room_n >= 2:
		_air_baggage_large_dressing(c)


## Seating and trolley ranks scale with a merged baggage hall while the main
## carousel remains the visual anchor. The added islands sit outside its sweep.


func _air_baggage_large_dressing(c: Vector3) -> void:
	var span = chunk._room_span()
	var spots = []
	if span.x > 12.1:
		spots.append(c + Vector3(-7.2, 0, 0))
		spots.append(c + Vector3(7.2, 0, 0))
	if span.y > 12.1:
		spots.append(c + Vector3(0, 0, -7.2))
		spots.append(c + Vector3(0, 0, 7.2))
	# Baggage halls have no apron window. Pick one cardinal room direction and
	# keep every island aligned to it instead of turning each toward the belt.
	var seat_yaw = float(int(chunk._r(431) * 3.99)) * PI / 2.0
	for i in spots.size():
		var sp: Vector3 = spots[i]
		_seat_row(sp, seat_yaw, 4, 430 + i * 4)
	var tp = c + Vector3(span.x * 0.5 - 2.0, 0, -span.y * 0.5 + 2.0)
	_air_trolley(tp, PI * 0.25 + (chunk._r(448) - 0.5) * 0.3, 449,
		2 + int(chunk._r(450) * 1.99))
	if chunk._r(451) < 0.75:
		_airport_luggage(tp + Vector3(-1.2, 0, 0.7), chunk._r(452) * TAU,
			453, chunk._r(454) < 0.4)


# --- airport: escalators ------------------------------------------------------


func _air_escalator() -> void:
	var wdir = _air_pick_wall(390)
	if wdir < 0:
		_air_hall()
		return
	var yw = chunk._yaw_for(wdir)
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	for cx in [-1.15, 1.15]:
		_escalator_flight(o, yw, cx)
	# mezzanine landing hugging the wall
	var lp = chunk._wp(o, Vector3(0, 2.16, 4.48), yw)
	var lm = chunk._mbox(chunk, lp, Vector3(5.6, 0.18, 2.75), Mats.steel())
	lm.rotation.y = yw
	chunk._collider_yaw_box(lp, Vector3(5.6, 0.18, 2.75), yw)
	# glass rail along the landing front, gaps at the flight mouths
	for seg in [[-2.8, -1.77], [-0.53, 0.53], [1.77, 2.8]]:
		var sc: float = (seg[0] + seg[1]) / 2.0
		var sl: float = seg[1] - seg[0]
		_air_rail(chunk._wp(o, Vector3(sc, 0, 3.14), yw), yw + PI / 2.0, sl)
	for sxn in [-2.77, 2.77]:
		_air_rail(chunk._wp(o, Vector3(sxn, 0, 4.48), yw), yw, 2.7)
	# roller shutter sealing whatever the mezzanine led to; a solid backing
	# panel sits behind the ribs so no light stripes the wall through the gaps
	var bk = chunk._mbox(chunk, chunk._wp(o, Vector3(0, 3.55, 5.79), yw), Vector3(4.9, 2.6, 0.05), Mats.charcoal())
	bk.rotation.y = yw
	for i in 14:
		var rb = chunk._mbox(chunk, chunk._wp(o, Vector3(0, 2.42 + 0.17 * float(i), 5.72), yw), Vector3(4.9, 0.155, 0.06), Mats.metal_gray())
		rb.rotation.y = yw
		rb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gxn in [-2.5, 2.5]:
		var gd = chunk._mbox(chunk, chunk._wp(o, Vector3(gxn, 3.55, 5.72), yw), Vector3(0.14, 2.6, 0.12), Mats.charcoal())
		gd.rotation.y = yw
		gd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk._collider_yaw_box(chunk._wp(o, Vector3(0, 3.55, 5.72), yw), Vector3(5.2, 2.7, 0.15), yw)
	var cl = Label3D.new()
	cl.text = "CLOSED FOR MAINTENANCE"
	cl.font_size = 40
	cl.pixel_size = 0.002
	cl.modulate = Color(0.85, 0.85, 0.85, 0.8)
	cl.position = chunk._wp(o, Vector3(0, 3.3, 5.62), yw)
	cl.rotation.y = yw + PI
	chunk.add_child(cl)
	# support columns under the landing lip
	for sxn in [-2.5, 2.5]:
		var scp = chunk._wp(o, Vector3(sxn, 1.05, 3.3), yw)
		chunk._cyl(scp, 0.11, 2.1, Mats.steel())
	# out-of-service barrier across one flight
	var bx = -1.15 if chunk._r(399) < 0.5 else 1.15
	_stanchion_line(chunk._wp(o, Vector3(bx - 0.6, 0, -2.3), yw), chunk._wp(o, Vector3(bx + 0.6, 0, -2.3), yw), 2)


## Landing-edge glass rail segment, centred at p, running along local x.


func _air_rail(p: Vector3, yaw: float, ln: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var gl = chunk._mbox(v, Vector3(0, 2.72, 0), Vector3(ln, 0.9, 0.028), Mats.glass_tint())
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hr = chunk._mrbox(v, Vector3(0, 3.2, 0), Vector3(ln + 0.05, 0.07, 0.08), Mats.rubber_black(), 0.03)
	hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk._collider_yaw_box(p + Vector3(0, 2.85, 0), Vector3(ln, 1.3, 0.1), yaw)


## One frozen escalator flight rising toward local +z from z -1.1 to the
## landing at z 3.1, y 2.25. Steps are dressing; a hidden slope does the work.


func _escalator_flight(o: Vector3, yw: float, cx: float) -> void:
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(cx, 0, 0), yw)
	v.rotation.y = yw
	chunk.add_child(v)
	var ang = 0.475   # atan2(2.25, 4.38)
	# steps
	for i in 12:
		var sy = 0.1875 * float(i + 1)
		var sz = -1.1 + 0.36 * float(i) + 0.18
		chunk._mbox(v, Vector3(0, sy - 0.11, sz), Vector3(1.0, 0.22, 0.38), Mats.charcoal())
		chunk._mbox(v, Vector3(0, sy - 0.008, sz + 0.155), Vector3(0.96, 0.014, 0.05), Mats.caution_yellow())
	# landing plates
	chunk._mbox(v, Vector3(0, 0.03, -1.62), Vector3(1.24, 0.06, 0.75), Mats.steel())
	chunk._mbox(v, Vector3(0, 2.22, 3.03), Vector3(1.24, 0.07, 0.5), Mats.steel())
	# balustrades: skirt, tinted glass, black handrail. The thin pieces never
	# cast shadows — the room light would smear them into long streaks across
	# the walls.
	for sxn in [-0.62, 0.62]:
		var sk = chunk._mbox(v, Vector3(sxn, 1.23, 0.95), Vector3(0.07, 0.5, 5.1), Mats.steel())
		sk.rotation.x = -ang
		var gl = chunk._mbox(v, Vector3(sxn, 1.78, 0.95), Vector3(0.026, 0.75, 4.85), Mats.glass_tint())
		gl.rotation.x = -ang
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hr = chunk._mrbox(v, Vector3(sxn, 2.2, 0.95), Vector3(0.085, 0.075, 5.15), Mats.rubber_black(), 0.03)
		hr.rotation.x = -ang
		hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# horizontal handrail stubs at both ends
		var s1 = chunk._mrbox(v, Vector3(sxn, 0.98, -1.75), Vector3(0.085, 0.075, 0.6), Mats.rubber_black(), 0.03)
		s1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s2 = chunk._mrbox(v, Vector3(sxn, 3.2, 3.35), Vector3(0.085, 0.075, 0.5), Mats.rubber_black(), 0.03)
		s2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# newel posts
		chunk._mbox(v, Vector3(sxn, 0.5, -1.95), Vector3(0.06, 0.96, 0.06), Mats.steel())
		chunk._mbox(v, Vector3(sxn, 2.25 + 0.47, 3.45), Vector3(0.06, 0.96, 0.06), Mats.steel())
		chunk._collider_rot_box(chunk._wp(v.position, Vector3(sxn, 1.75, 0.95), yw),
			Vector3(0.1, 1.6, 5.1), Vector3(-ang, yw, 0))
	# truss cladding underneath
	var tr = chunk._mbox(v, Vector3(0, 0.52, 0.95), Vector3(1.36, 0.4, 5.15), Mats.jetway_body())
	tr.rotation.x = -ang
	# the walkable slope
	chunk._collider_rot_box(chunk._wp(v.position, Vector3(0, 1.03, 0.95), yw),
		Vector3(1.15, 0.2, 4.95), Vector3(-ang, yw, 0))
	chunk._collider_yaw_box(chunk._wp(v.position, Vector3(0, 0.015, -1.62), yw), Vector3(1.24, 0.03, 0.8), yw)


# --- airport: hall & common ---------------------------------------------------


func _air_hall() -> void:
	# the overflow hall: seating for a delay that outlived its passengers
	# (a portal claims the middle of the room when one is open here)
	var span = chunk._room_span()
	var mx = span.x / 2.0 - 2.4
	var mz = span.y / 2.0 - 2.4
	if chunk.portal_dest < 0 and chunk._r(400) < 0.6 and mx > 0.5 and mz > 0.5:
		# rows sit square to the room and clear of its walls
		_seat_row(Vector3(chunk.S / 2.0 + (chunk._r(401) - 0.5) * 2.0 * mx, 0,
			chunk.S / 2.0 + (chunk._r(402) - 0.5) * 2.0 * mz),
			float(int(chunk._r(403) * 3.99)) * PI / 2.0, 5, 404)
	if chunk._r(405) < 0.4:
		chunk._planter(Vector3(2.6 + 6.8 * chunk._r(406), 0, 2.6 + 6.8 * chunk._r(407)))
	if chunk.portal_dest < 0 and chunk._r(408) < 0.3:
		# wet floor sign guarding a dry floor
		var p = Vector3(3.0 + 6.0 * chunk._r(409), 0, 3.0 + 6.0 * chunk._r(410))
		chunk._cc0_prop("WetFloorSign_01", p, chunk._r(411) * TAU)
		chunk._collider_box(p + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	if chunk.portal_dest < 0 and chunk._r(411) < 0.35:
		_fids(chunk, Vector3(2.5 + 7.0 * chunk._r(412), 2.6, 2.5 + 7.0 * chunk._r(413)),
			float(int(chunk._r(414) * 3.99)) * PI / 2.0, true, true)


## Landmark: a shuttered food court. Three distinct concession fronts frame
## a sparse field of real tables; the central aisle stays clear enough to see
## the dead menu boards from the adjoining concourse.


func _air_foodcourt() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var names = ["SKYLINE GRILL", "COFFEE / TEA", "FRESH EXPRESS"]
	for i in 3:
		var x = -6.6 + 6.6 * float(i)
		var kp = c + Vector3(x, 0, -8.5)
		chunk._rbox(kp + Vector3(0, 0.65, 0), Vector3(5.4, 1.3, 1.35), Mats.jetway_body(), 0.03)
		# Corrugated shutter, counter and a black menu strip.
		for sl in 8:
			chunk._box(kp + Vector3(0, 1.22 + 0.22 * float(sl), 0.69),
				Vector3(5.0, 0.12, 0.04), Mats.metal_gray(), false)
		chunk._rbox(kp + Vector3(0, 1.0, 1.0), Vector3(5.2, 0.12, 0.78), Mats.steel(), 0.025)
		chunk._box(kp + Vector3(0, 3.45, 0.72), Vector3(4.7, 0.65, 0.08), Mats.charcoal(), false)
		var sign = Label3D.new()
		sign.text = names[i]
		sign.font_size = 96
		sign.pixel_size = 0.0025
		sign.modulate = Color(0.72, 0.88, 1.0) if i != 1 else Color(1.0, 0.72, 0.34)
		sign.position = kp + Vector3(0, 3.46, 0.78)
		chunk.add_child(sign)
		chunk._collider_box(kp + Vector3(0, 1.3, 0), Vector3(5.5, 2.6, 1.5))
	# Four battered public tables, deliberately asymmetrical around the aisle.
	var table_offsets: Array[Vector3] = [Vector3(-5.4, 0, -1.8), Vector3(4.8, 0, -2.0),
		Vector3(-4.5, 0, 4.4), Vector3(5.6, 0, 4.0)]
	for i in 4:
		var tp: Vector3 = c + table_offsets[i]
		var yaw = (0.0 if i % 2 == 0 else PI / 2.0) + (chunk._r(430 + i) - 0.5) * 0.15
		chunk._cc0_prop("wooden_picnic_table", tp, yaw)
		chunk._collider_yaw_box(tp + Vector3(0, 0.4, 0), Vector3(2.3, 0.8, 3.1), yaw)
	# Cleaning and service equipment gives the set piece a second read.
	var cartp = c + Vector3(8.0, 0, 7.6)
	chunk._cc0_prop("CoffeeCart_01", cartp, -PI / 2.0)
	chunk._collider_yaw_box(cartp + Vector3(0, 0.85, 0), Vector3(2.2, 1.7, 1.1), -PI / 2.0)
	var wetp = c + Vector3(0.8, 0, 5.2)
	chunk._cc0_prop("WetFloorSign_01", wetp, chunk._r(438) * TAU)
	chunk._collider_box(wetp + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	_hang_sign(c + Vector3(0, 3.7, 6.4), 0.0, "FOOD COURT")


func _air_common() -> void:
	# structural columns in the open styles
	if chunk.style == WorldGen.AIR_CONCOURSE or chunk.style == WorldGen.AIR_HALL \
			or chunk.style == WorldGen.AIR_BAGGAGE or chunk.style == WorldGen.AIR_FOODCOURT:
		for p in [Vector2(1.7, 1.7), Vector2(10.3, 1.7), Vector2(1.7, 10.3), Vector2(10.3, 10.3)]:
			if WorldGen.r01(chunk.wseed, chunk.cell.x + int(p.x), chunk.cell.y + int(p.y), 330) < 0.5:
				_air_column(p)
	# random scatter never lands in cells with belts — a suitcase parked on a
	# moving walkway pins whoever it carries into it
	var has_belts = chunk.style == WorldGen.AIR_TRANSIT or chunk.style == WorldGen.AIR_CONCOURSE
	# Scattered floor props take a free spot rather than any spot. Dropping one
	# on a random point in the cell is how a suitcase ends up standing inside a
	# row of gate seating, which is furniture the gate placed long before this.
	if not has_belts and chunk._r(334) < 0.5:
		var bin_p = chunk._free_floor_spot(335, 0.42, 2.6, 1.0)
		if bin_p != Vector3.INF:
			_air_bin(bin_p)
	# a suitcase standing perfectly upright, no owner in any direction
	if not has_belts and chunk.style != WorldGen.AIR_ESCALATOR and chunk._r(337) < 0.18:
		var case_p = chunk._free_floor_spot(338, 0.40, 2.6, 1.0)
		if case_p != Vector3.INF:
			_airport_luggage(case_p, chunk._r(340) * TAU, 341)
	# A low backpack from the authored set replaces the old oversized open trunk.
	if chunk.style == WorldGen.AIR_BAGGAGE and chunk._r(345) < 0.4:
		var vsp = chunk._free_floor_spot(346, 0.42, 2.4, 0.6)
		if vsp != Vector3.INF:
			var vsy = chunk._r(348) * TAU
			_airport_luggage(vsp, vsy, 349, true)
	# PA speakers live in the busy styles
	var wants_pa = chunk.style == WorldGen.AIR_GATE or chunk.style == WorldGen.AIR_CHECKIN \
		or chunk.style == WorldGen.AIR_BAGGAGE or chunk.style == WorldGen.AIR_FOODCOURT
	if wants_pa and chunk._r(342) < 0.5:
		var snd = AirportSounds.new()
		snd.position = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
		chunk.add_child(snd)


## Usable rectangle of this room, in metres, centred on room_centre. An
## L-shaped room reports only its root cell, since that is the largest part
## guaranteed to be free of walls.
