extends "res://scripts/levels/chunk_level_builder.gd"


func _asy_tiled_room() -> bool:
	return chunk.style == WorldGen.ASY_TREATMENT or chunk.style == WorldGen.ASY_HYDRO


func _asy_wall_mat() -> Material:
	if _asy_tiled_room():
		return Mats.asy_tile()
	return Mats.asy_wall() if chunk._r(47) < 0.72 else Mats.asy_wall_sick()


## Slide a wall-hugging prop along wall `dir` so it cannot block the doorway —
## a bed in front of a room's only door would seal it for good.


func _asy_wall_clear(dir: int, want: float, span: float) -> float:
	var info = WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)
	if info["wall"] or info["full_open"]:
		return want
	var t: float = info["t"]
	var hw: float = float(info["w"]) * 0.5 + 0.6 + span * 0.5
	if absf(want - t) >= hw:
		return want
	var cand = t + hw if want >= t else t - hw
	if cand < 1.2 or cand > chunk.S - 1.2:
		cand = t + hw if cand < 1.2 else t - hw
	return clampf(cand, 1.2, chunk.S - 1.2)


func _asy_sounds() -> void:
	var snd = AsylumSounds.new()
	snd.position = Vector3(chunk.S / 2.0, 1.4, chunk.S / 2.0)
	chunk.add_child(snd)


func _asy_lighting() -> void:
	var is_spawn = chunk.cell == Vector2i.ZERO
	var dead = (not is_spawn) and chunk._r(8) < 0.13
	var flicker = (not is_spawn) and (not dead) and chunk._r(9) < 0.30
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.asy_panel().duplicate()
	else:
		pmat = Mats.asy_panel()
	var pts = [Vector2(3.6, 6.0), Vector2(8.4, 6.0)]
	if chunk.style == WorldGen.ASY_CORRIDOR:
		var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
		if cdir == 1:
			pts = [Vector2(2.4, 6.0), Vector2(6.0, 6.0), Vector2(9.6, 6.0)]
		else:
			pts = [Vector2(6.0, 2.4), Vector2(6.0, 6.0), Vector2(6.0, 9.6)]
	for pt in pts:
		_asy_fixture(Vector3(pt.x, 0, pt.y), pmat)
	if dead:
		return
	var tall = chunk.ceil_h > 4.0
	var light = chunk._make_main_light(flicker, pmat, 1.8 if tall else 1.35)
	light.light_color = Color(0.8, 0.94, 0.72)
	light.omni_range = 13.5 if tall else 11.5
	light.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.55, chunk.S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 16.0
	chunk.add_child(light)


## Real twin-tube fixture on rusted drop rods, lens panel underneath. Thin
## fixture parts must not cast — the room omni would smear them into streaks.


func _asy_fixture(at: Vector3, pmat: Material) -> void:
	var drop = 0.22
	var y = chunk.ceil_h - drop
	var fixture = chunk._asy_model("mounted_fluorescent_lights", Vector3(at.x, y, at.z), 0.0)
	chunk._asy_no_shadows(fixture)
	for dz in [-0.26, 0.26]:
		var rod = chunk._cyl(Vector3(at.x, y + drop / 2.0, at.z + dz), 0.012, drop, Mats.asy_metal(), false)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens = chunk._box(Vector3(at.x, y - 0.045, at.z), Vector3(0.8, 0.02, 0.55), pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- asylum: props ------------------------------------------------------------

## Rusty hospital bed frame (model) + a stained mattress most of the time.
## Ward bed. The authored frame arrives already made up — mattress, pillow and a
## sheet thrown back — so it needs none of the generated bedding below. The bare
## CC0 frame stays in the mix as a minority so a long ward does not read as one
## bed stamped twenty times.


func _asy_bed(p: Vector3, yaw: float, salt: int) -> void:
	if chunk._r(salt + 7) < 0.76:
		# Its long axis is X; turn that onto the row's local Z.
		var authored = chunk._attributed_floor_prop(chunk.ASY_BED_PATH, p,
			yaw + PI / 2.0, chunk.ASY_BED_SCALE, chunk.ASY_BED_CENTRE, "ward_bed")
		if authored != null:
			chunk._collider_yaw_box(p + Vector3(0, 0.6, 0),
				Vector3(1.05, 1.2, 1.95), yaw)
			return
	chunk._asy_model("old_bed_frame", p, yaw)
	chunk._collider_yaw_box(p + Vector3(0, 0.6, 0), Vector3(0.95, 1.2, 2.05), yaw)
	if chunk._r(salt) >= 0.8:
		return
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	var mt = chunk._mrbox(v, Vector3(0, 0.52, 0.03), Vector3(0.8, 0.15, 1.78), Mats.asy_cloth(), 0.05)
	mt.rotation.y = (chunk._r(salt + 1) - 0.5) * 0.08
	if chunk._r(salt + 2) < 0.5:
		chunk._mrbox(v, Vector3(0, 0.63, -0.68), Vector3(0.52, 0.09, 0.34), Mats.asy_canvas(), 0.04)


## Wheeled stretcher, straps still across the mattress. The authored gurney is
## tilted half upright with a syringe left on its tray; the generated one below
## covers the rest and any import failure.


func _asy_gurney(p: Vector3, yaw: float, salt: int) -> void:
	var transport_radius = 1.05
	if not _asy_transport_clear(p, transport_radius):
		return
	if chunk._r(salt + 11) < 0.70:
		var authored = chunk._attributed_floor_prop(chunk.ASY_GURNEY_PATH, p,
			yaw + PI / 2.0, 1.0, chunk.ASY_GURNEY_CENTRE, "gurney")
		if authored != null:
			authored.set_meta("asylum_transport_kind", "gurney")
			authored.set_meta("asylum_transport_radius", transport_radius)
			chunk._collider_yaw_box(p + Vector3(0, 0.55, 0),
				Vector3(0.80, 1.10, 1.90), yaw)
			return
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	v.set_meta("asylum_transport_kind", "gurney")
	v.set_meta("asylum_transport_radius", transport_radius)
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, 0.8, 0), Vector3(0.64, 0.05, 1.9), Mats.asy_metal(), 0.02)
	chunk._mrbox(v, Vector3(0, 0.9, 0), Vector3(0.58, 0.13, 1.8), Mats.asy_cloth(), 0.05)
	for sz in [-0.38, 0.3]:
		chunk._mbox(v, Vector3(0, 0.97, sz), Vector3(0.62, 0.02, 0.09), Mats.charcoal())
	for lx in [-0.26, 0.26]:
		for lz in [-0.78, 0.78]:
			chunk._mcyl(v, Vector3(lx, 0.45, lz), 0.022, 0.72, Mats.asy_metal())
			chunk._msphere(v, Vector3(lx, 0.07, lz), 0.07, Mats.charcoal())
	if chunk._r(salt) < 0.4:
		# sheet hanging half off — someone left in a hurry
		var sh = chunk._mrbox(v, Vector3(0.18, 0.78, 0.5), Vector3(0.5, 0.35, 0.03), Mats.asy_canvas(), 0.02)
		sh.rotation.z = 0.35
	chunk._collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.95), yaw)


## The centrepiece: a fixed restraint table, leather straps buckled shut.


func _asy_restraint_table(p: Vector3, yaw: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.9), Mats.asy_metal())
	chunk._mrbox(v, Vector3(0, 0.72, 0), Vector3(0.85, 0.09, 2.0), Mats.asy_metal(), 0.02)
	chunk._mrbox(v, Vector3(0, 0.8, 0.04), Vector3(0.74, 0.08, 1.82), Mats.asy_canvas(), 0.04)
	chunk._mrbox(v, Vector3(0, 0.86, -0.78), Vector3(0.4, 0.07, 0.26), Mats.asy_canvas(), 0.03)
	for sz in [-0.42, 0.08, 0.56]:
		chunk._mbox(v, Vector3(0, 0.85, sz), Vector3(0.92, 0.02, 0.1), Mats.charcoal())
		chunk._mbox(v, Vector3(0.42, 0.85, sz), Vector3(0.06, 0.03, 0.05), Mats.steel())
	for sx in [-0.44, 0.44]:
		var strap = chunk._mbox(v, Vector3(sx, 0.6, 0.28), Vector3(0.025, 0.34, 0.09), Mats.charcoal())
		strap.rotation.x = (0.2 if sx > 0.0 else -0.15)
	chunk._collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 2.0), yaw)


## Electroshock station: instrument cart, dial box, two paddles on a wire.


func _asy_ect(p: Vector3, yaw: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	for sy in [0.34, 0.72]:
		chunk._mrbox(v, Vector3(0, sy, 0), Vector3(0.56, 0.03, 0.42), Mats.steel(), 0.01)
	for lx in [-0.25, 0.25]:
		for lz in [-0.17, 0.17]:
			chunk._mcyl(v, Vector3(lx, 0.37, lz), 0.015, 0.7, Mats.chrome())
			chunk._msphere(v, Vector3(lx, 0.05, lz), 0.05, Mats.charcoal())
	# the machine itself: a grey box, a white gauge, red pilot, bakelite dials
	chunk._mrbox(v, Vector3(0, 0.87, 0), Vector3(0.5, 0.26, 0.34), Mats.metal_gray(), 0.02)
	var gauge = chunk._mcyl(v, Vector3(-0.12, 0.9, 0.176), 0.06, 0.015, Mats.paint_white())
	gauge.rotation.x = PI / 2.0
	for di in 3:
		var knob = chunk._mcyl(v, Vector3(0.06 + 0.11 * float(di), 0.84, 0.176), 0.025, 0.03, Mats.red_knob())
		knob.rotation.x = PI / 2.0
	chunk._msphere(v, Vector3(0.18, 0.95, 0.17), 0.014, Mats.lamp_red())
	# paddles resting on the lower shelf, leads drooping back up to the box
	for px in [-0.12, 0.1]:
		chunk._mcyl(v, Vector3(px, 0.39, 0.05), 0.05, 0.035, Mats.charcoal())
		chunk._mcyl(v, Vector3(px, 0.42, 0.05), 0.012, 0.09, Mats.charcoal())
	# leads sagging from the paddles back up into the box
	_asy_wire(v, Vector3(-0.12, 0.46, 0.05), Vector3(-0.2, 0.87, -0.1))
	_asy_wire(v, Vector3(0.1, 0.46, 0.05), Vector3(0.2, 0.87, -0.1))
	chunk._collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.62, 1.0, 0.5), yaw)


## Sagging two-segment cable between two local points.


func _asy_wire(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mid = (a + b) * 0.5 + Vector3(0, -0.14, 0.1)
	for seg in [[a, mid], [mid, b]]:
		var mi = MeshInstance3D.new()
		mi.mesh = chunk.BOX
		mi.material_override = Mats.rubber_black()
		var d: Vector3 = seg[1] - seg[0]
		var up = Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		mi.transform = Transform3D(Basis.looking_at(d, up), (seg[0] + seg[1]) / 2.0)
		mi.scale = Vector3(0.014, 0.014, d.length())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Transport props share conservative floor radii. If a later furnishing rolls
## the same spot, omit it instead of interpenetrating an earlier one.


func _asy_transport_clear(p: Vector3, radius: float) -> bool:
	for node in chunk.find_children("*", "Node3D", true, false):
		if not node.has_meta("asylum_transport_radius"):
			continue
		var other = node as Node3D
		if p.distance_to(other.position) < radius \
				+ float(other.get_meta("asylum_transport_radius")) \
				+ chunk.ASY_TRANSPORT_CLEARANCE:
			return false
	return true


func _asy_wheelchair(p: Vector3, yaw: float) -> void:
	var transport_radius = 0.70
	if not _asy_transport_clear(p, transport_radius):
		return
	var b0 = chunk.body.get_child_count()
	var pivot = chunk._furnishing_pivot(p, yaw, "asylum_wheelchair")
	pivot.set_meta("asylum_transport_kind", "wheelchair")
	pivot.set_meta("asylum_transport_radius", transport_radius)
	var model = chunk._asy_model("wheelchair_01", p, yaw)
	chunk._adopt_local(pivot, model)
	chunk._collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.85, 1.1, 1.1), yaw)
	chunk._bind_furnishing_colliders(pivot, b0)


func _asy_chair(p: Vector3, yaw: float, tipped: bool) -> void:
	var ch = chunk._asy_model("SchoolChair_01", p, yaw)
	if tipped:
		ch.position.y = 0.28
		ch.rotation.z = PI / 2.0 - 0.06
		return
	chunk._collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.58, 1.0, 0.68), yaw)


func _asy_medbox(p: Vector3, yaw: float) -> void:
	chunk._asy_model("medical_box", p, yaw)


func _asy_iv(p: Vector3) -> void:
	var yaw = chunk._r(int(p.x * 17.0 + p.z * 3.0) + 812) * TAU
	var b0 = chunk.body.get_child_count()
	var pivot = chunk._attributed_floor_prop(chunk.IV_DRIP_PATH, p, yaw, chunk.IV_DRIP_SCALE,
		chunk.IV_DRIP_CENTRE, "asylum_iv_stand", null, true)
	if pivot == null:
		var v = Node3D.new()
		v.position = p
		chunk.add_child(v)
		chunk._mcyl(v, Vector3(0, 0.95, 0), 0.017, 1.9, Mats.chrome())
		chunk._mcyl(v, Vector3(0, 0.025, 0), 0.2, 0.05, Mats.asy_metal())
		chunk._mbox(v, Vector3(0, 1.88, 0), Vector3(0.4, 0.02, 0.02), Mats.chrome())
		chunk._mrbox(v, Vector3(0.16, 1.68, 0), Vector3(0.13, 0.24, 0.05),
			Mats.glass_tint(), 0.02)
		_asy_wire(v, Vector3(0.16, 1.56, 0), Vector3(0.05, 0.9, 0.06))
		chunk._collider_cyl(p + Vector3(0, 0.95, 0), 0.2, 1.9)
		return
	# The five-castor base is 0.84m across but nothing above 0.2m is wider than
	# the pole, so the collider follows the pole and lets a player's feet pass
	# between the legs rather than bouncing off a metre-wide invisible drum.
	chunk._collider_cyl(p + Vector3(0, 1.0, 0), 0.17, 1.95)
	chunk._bind_furnishing_colliders(pivot, b0)


## Claw-foot hydrotherapy tub; half of them still hold black water. The authored
## tub already runs down Z at 0.80 scale, so it drops straight into the row.


func _asy_tub(p: Vector3, yaw: float, salt: int) -> void:
	if chunk._r(salt + 13) < 0.72:
		var authored = chunk._attributed_floor_prop(chunk.ASY_BATH_PATH, p, yaw,
			chunk.ASY_BATH_SCALE, Vector3.ZERO, "hydro_bath")
		if authored != null:
			chunk._collider_yaw_box(p + Vector3(0, 0.34, 0),
				Vector3(0.80, 0.68, 1.85), yaw)
			if chunk._r(salt) < 0.55:
				var water = chunk._mquad(authored, Vector3(0, 0.55, 0),
					Vector2(0.52, 1.55), Mats.puddle())
				water.rotation.x = -PI / 2.0
			return
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, 0.36, 0), Vector3(0.8, 0.6, 1.7), Mats.paint_white(), 0.09)
	chunk._mrbox(v, Vector3(0, 0.6, 0), Vector3(0.62, 0.18, 1.5), Mats.charcoal(), 0.05)
	# rust bleeding from the drain end
	chunk._mbox(v, Vector3(0, 0.2, 0.83), Vector3(0.3, 0.4, 0.03), Mats.asy_metal())
	for fx in [-0.34, 0.34]:
		for fz in [-0.72, 0.72]:
			chunk._msphere(v, Vector3(fx, 0.07, fz), 0.07, Mats.iron_dark())
	if chunk._r(salt) < 0.55:
		var wq = chunk._mquad(v, Vector3(0, 0.63, 0), Vector2(0.6, 1.46), Mats.puddle())
		wq.rotation.x = -PI / 2.0
	# taps
	chunk._mcyl(v, Vector3(0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	chunk._mcyl(v, Vector3(-0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	chunk._collider_yaw_box(p + Vector3(0, 0.35, 0), Vector3(0.85, 0.7, 1.75), yaw)


func _asy_trolley(p: Vector3, yaw: float) -> void:
	var transport_radius = 0.62
	if not _asy_transport_clear(p, transport_radius):
		return
	var trolley = chunk._attributed_floor_prop(chunk.ASY_TROLLEY_PATH, p, yaw, 1.0,
		chunk.ASY_TROLLEY_CENTRE, "instrument_trolley")
	if trolley == null:
		return
	trolley.set_meta("asylum_transport_kind", "trolley")
	trolley.set_meta("asylum_transport_radius", transport_radius)
	chunk._collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(1.06, 0.92, 0.62), yaw)


## Steel scrub trough on tubular legs under three gooseneck taps. It is modelled
## down its local Z, so `yaw` runs it along a wall with the taps at the back.


func _asy_scrub_sink(p: Vector3, yaw: float) -> void:
	if chunk._attributed_floor_prop(chunk.ASY_SCRUB_SINK_PATH, p, yaw, 1.0,
			Vector3.ZERO, "scrub_sink") == null:
		return
	chunk._collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.88, 0.90, 2.22), yaw)


# --- asylum: wall decor -------------------------------------------------------

## Paper still pinned where somebody left it: forms, duty notices, one pink
## slip. The authored sheet spans 2.13m, so it wants a solid wall run.


func _asy_wall_notices(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var along = chunk.S / 2.0 + (chunk._r(1180 + dir) - 0.5) * 2.6
	var y = 1.46 + (chunk._r(1184 + dir) - 0.5) * 0.22
	var yaw = (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
		else (PI if dir == 2 else 0.0)
	var pos = Vector3(inner + n * 0.015, y, along) if dir < 2 \
		else Vector3(along, y, inner + n * 0.015)
	var pivot = Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	chunk.add_child(pivot)
	# The sheet is floored at export; lift its own centre onto the mount height.
	var inst = chunk._attributed_prop_local(pivot, chunk.ASY_NOTICES_PATH,
		Vector3(0, -0.496, 0), 0.0)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	pivot.set_meta("asylum_wall_notices", true)
	chunk._asy_no_shadows(pivot)


## A sealed hospital leaf on a genuinely solid wall. The wall stays the
## collider, so the door reads as locked for good without adding an invisible
## barrier — the same treatment the prison's authored doors get. Mounted at
## authored height, which the 3.0m asylum ceiling clears.


func _asy_locked_door_wall(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T * 0.5)
	var along = lerpf(3.2, 8.8, chunk._r(1190 + dir))
	var yaw = (PI if dir == 0 else 0.0) if dir < 2 \
		else (PI / 2.0 if dir == 2 else -PI / 2.0)
	var pos = Vector3(inner + n * 0.03, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.03)
	var pick = WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 1194 + dir) % chunk.ASY_DOOR_PATHS.size()
	var pivot = Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	chunk.add_child(pivot)
	var inst = chunk._attributed_prop_local(pivot, chunk.ASY_DOOR_PATHS[pick],
		Vector3.ZERO, chunk.ASY_DOOR_FACE_YAW[pick])
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	pivot.set_meta("wall_mounted_asylum_door", true)
	pivot.set_meta("locked_facade", true)
	inst.set_meta("asylum_authored_leaf", pick)


## A straitjacket on a wall hook, straps hanging loose.


func _asy_straitjacket(dir: int, plane: float) -> void:
	var along = chunk.S / 2.0 + (chunk._r(46 + dir) - 0.5) * 5.0
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var v = Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	chunk.add_child(v)
	chunk._mcyl(v, Vector3(0, 2.06, 0.045), 0.015, 0.09, Mats.iron_dark())
	var torso = chunk._mrbox(v, Vector3(0, 1.6, 0.1), Vector3(0.52, 0.78, 0.15), Mats.asy_canvas(), 0.07)
	torso.rotation.z = (chunk._r(48 + dir) - 0.5) * 0.1
	# arms wrapped across the front
	var arm = chunk._mrbox(v, Vector3(0, 1.52, 0.185), Vector3(0.46, 0.13, 0.06), Mats.asy_canvas(), 0.04)
	arm.rotation.z = 0.28
	var arm2 = chunk._mrbox(v, Vector3(0, 1.42, 0.2), Vector3(0.46, 0.13, 0.05), Mats.asy_canvas(), 0.04)
	arm2.rotation.z = -0.24
	for si in 3:
		var sx = -0.14 + 0.14 * float(si)
		var strap = chunk._mbox(v, Vector3(sx, 1.02, 0.12), Vector3(0.045, 0.42, 0.015), Mats.asy_canvas())
		strap.rotation.x = (chunk._r(50 + dir + si) - 0.5) * 0.25
		strap.rotation.z = (chunk._r(53 + dir + si) - 0.5) * 0.2
		chunk._mbox(v, Vector3(sx, 0.82, 0.12), Vector3(0.05, 0.03, 0.02), Mats.steel())


## Written by hand, by someone who was not well. Two hands share the walls:
## Rock Salt is the shaky block-capital marker, Caveat the fast desperate
## cursive — picked per wall so a corridor reads as years of different people.
func _asy_scrawl(dir: int, plane: float) -> void:
	var along = chunk.S / 2.0 + (chunk._r(46 + dir) - 0.5) * 6.0
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var lb = Label3D.new()
	lb.text = chunk.ASY_SCRAWLS[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 55 + dir) % chunk.ASY_SCRAWLS.size()]
	# cursive runs smaller and tighter than the block marker, so it needs the
	# larger point size to end up the same height on the wall
	var hand = 0 if chunk._r(60 + dir) < 0.55 else 1
	lb.font = chunk._scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0035 * (1.0 + (chunk._r(61 + dir) - 0.5) * 0.5)
	lb.width = 900.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	# this floor is near-black, and dark-on-dark writing may as well not exist —
	# a third of it is scratched THROUGH the paint, pale against the plaster
	var ink = chunk._r(56 + dir)
	if ink < 0.42:
		lb.modulate = Color(0.34, 0.06, 0.05, 0.85)   # dried rust-red marker
	elif ink < 0.66:
		lb.modulate = Color(0.16, 0.15, 0.13, 0.9)    # charcoal, almost gone
	else:
		lb.modulate = Color(0.66, 0.64, 0.56, 0.92)   # scratched into the paint
	var y = 1.25 + chunk._r(57 + dir) * 0.6
	if dir < 2:
		lb.position = Vector3(inner + n * 0.02, y, along)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(along, y, inner + n * 0.02)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	# a hand steadied against a wall still wanders off true
	lb.rotation.z = (chunk._r(59 + dir) - 0.5) * 0.22
	chunk.add_child(lb)


## Cork noticeboard, duty rosters still pinned, one sheet hanging by a corner.


func _asy_noticeboard(dir: int, plane: float) -> void:
	var along = chunk.S / 2.0 + (chunk._r(46 + dir) - 0.5) * 4.0
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var v = Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 1.62, 0.025), Vector3(1.2, 0.85, 0.05), Mats.darkwood())
	chunk._mbox(v, Vector3(0, 1.62, 0.045), Vector3(1.08, 0.73, 0.02), Mats.asy_cloth())
	for i in 4:
		var px = -0.35 + 0.24 * float(i)
		if chunk._r(60 + dir + i) < 0.75:
			var sheet = chunk._mbox(v, Vector3(px, 1.6 + (chunk._r(63 + i) - 0.5) * 0.3, 0.062),
				Vector3(0.16, 0.22, 0.004), Mats.box_white())
			sheet.rotation.z = (chunk._r(66 + dir + i) - 0.5) * (0.9 if i == 2 else 0.14)


func _asy_crutches(dir: int, plane: float) -> void:
	var along = chunk.S / 2.0 + (chunk._r(46 + dir) - 0.5) * 5.5
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T / 2.0)
	var v = Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.22, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner + n * 0.22)
		v.rotation.y = 0.0 if n > 0.0 else PI
	chunk.add_child(v)
	# instanced under the lean node directly — reparent() needs a live tree
	var ps: PackedScene = chunk._asy_scenes.get("vintage_crutches_01")
	if ps == null:
		ps = load("res://models/asylum/vintage_crutches_01/vintage_crutches_01_1k.gltf")
		chunk._asy_scenes["vintage_crutches_01"] = ps
	var m: Node3D = ps.instantiate()
	m.rotation = Vector3(0.17, 0.0, 0.0)
	v.add_child(m)


# --- asylum: rooms ------------------------------------------------------------


func _asy_cell_props() -> void:
	var bx = _asy_wall_clear(3, 2.6 + 6.8 * chunk._r(760), 1.1)
	_asy_bed(Vector3(bx, 0, 1.35), PI if chunk._r(761) < 0.5 else 0.0, 762)
	if chunk._r(763) < 0.45:
		var bx2 = _asy_wall_clear(2, 2.6 + 6.8 * chunk._r(764), 1.1)
		_asy_bed(Vector3(bx2, 0, chunk.S - 1.35), PI if chunk._r(765) < 0.5 else 0.0, 766)
	if chunk._r(767) < 0.4:
		_asy_wheelchair(Vector3(3.0 + 6.0 * chunk._r(768), 0, 3.5 + 5.0 * chunk._r(769)), chunk._r(770) * TAU)
	if chunk._r(771) < 0.5:
		_asy_chair(Vector3(2.5 + 7.0 * chunk._r(772), 0, 3.5 + 5.0 * chunk._r(773)), chunk._r(774) * TAU, chunk._r(775) < 0.25)
	if chunk._r(776) < 0.55:
		chunk._asy_papers(Vector3(4.0 + 4.0 * chunk._r(777), 0, 4.0 + 4.0 * chunk._r(778)), 780, 6)
	if chunk._r(781) < 0.35:
		_asy_iv(Vector3(bx + 1.3, 0, 1.6))
	if chunk._r(782) < 0.3:
		_asy_medbox(Vector3(3.0 + 6.0 * chunk._r(783), 0, 4.0 + 4.0 * chunk._r(784)), chunk._r(785) * TAU)


## Two facing rows of beds down the room's long axis — a ward nobody closed.


func _asy_ward() -> void:
	var span = chunk._room_span()
	var long_x = span.x >= span.y
	var L = maxf(span.x, span.y)
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var nbeds = int((L - 3.0) / 2.6)
	var salt = 790
	for si in 2:
		var lat = -4.15 if si == 0 else 4.15
		for bi in nbeds:
			var along = -(L / 2.0 - 2.2) + 2.6 * float(bi) + (chunk._r(salt) - 0.5) * 0.5
			salt += 1
			if chunk._r(salt) < 0.18:
				salt += 3
				continue
			salt += 1
			var p = c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			var yaw: float
			if long_x:
				yaw = 0.0 if lat > 0.0 else PI
			else:
				yaw = PI / 2.0 if lat > 0.0 else -PI / 2.0
			_asy_bed(p, yaw + (chunk._r(salt) - 0.5) * 0.07, salt + 40)
			salt += 1
			if chunk._r(salt) < 0.25:
				var ivoff = Vector3(1.35, 0, 0) if long_x else Vector3(0, 0, 1.35)
				_asy_iv(p + ivoff)
			salt += 1
	# Reserve distinct stations down the central aisle. These three props used
	# to roll independent positions around `c`, allowing a wheelchair to spawn
	# inside the gurney (or either transport to swallow the trolley).
	var aisle = Vector3.RIGHT if long_x else Vector3.FORWARD
	var cross = Vector3.FORWARD if long_x else Vector3.RIGHT
	var transport_yaw = PI / 2.0 if long_x else 0.0
	if chunk._r(860) < 0.55:
		_asy_wheelchair(c - aisle * 2.4 - cross * 0.65,
			transport_yaw + (chunk._r(863) - 0.5) * 0.16)
	if chunk._r(864) < 0.6:
		chunk._asy_papers(c + Vector3((chunk._r(865) - 0.5) * 4.0, 0, (chunk._r(866) - 0.5) * 4.0), 867, 7)
	if chunk._r(868) < 0.35:
		_asy_gurney(c + aisle * 2.0 + cross * 0.55,
			transport_yaw + (chunk._r(871) - 0.5) * 0.12, 872)
	# One trolley abandoned mid-round between the bed rows.
	if chunk._r(873) < 0.42:
		_asy_trolley(c - aisle * 0.15 + cross * 1.25,
			transport_yaw + PI / 2.0 + (chunk._r(876) - 0.5) * 0.18)


## The big common room: a therapy circle nobody dismissed, a rocking chair
## facing the wall, papers everywhere.


func _asy_dayroom() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var span = chunk._room_span()
	var large = span.x > 12.1 or span.y > 12.1
	var base = chunk._r(880) * TAU
	var chair_count = 11 if large else 7
	var circle_r = 4.1 if large else 2.3
	for i in chair_count:
		if chunk._r(881 + i) < 0.2:
			continue
		var ang = base + TAU * float(i) / float(chair_count)
		var cp = c + Vector3(cos(ang) * circle_r, 0, sin(ang) * circle_r)
		var face = atan2(c.x - cp.x, c.z - cp.z)
		_asy_chair(cp, face + (chunk._r(900 + i) - 0.5) * 0.5, chunk._r(920 + i) < 0.15)
	if large:
		# Secondary activity islands stop the 24m dayroom reading as one chair
		# circle marooned in a warehouse-sized shell.
		_asy_dayroom_table(c + Vector3(-6.2, 0, 5.0), 940)
		_asy_dayroom_table(c + Vector3(6.2, 0, -5.0), 950)
	var rp = c + Vector3(7.6, 0, 7.9)
	var rock = chunk._asy_model("Rockingchair_01", rp, PI * 0.83)
	rock.position.y = -0.1
	chunk._collider_yaw_box(rp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), PI * 0.83)
	if chunk._r(902) < 0.6:
		_asy_wheelchair(c + Vector3(-6.2 * chunk._r(903), 0, 5.0 * (chunk._r(904) - 0.5)), chunk._r(905) * TAU)
	chunk._asy_papers(c + Vector3((chunk._r(906) - 0.5) * 5.0, 0, (chunk._r(907) - 0.5) * 5.0), 908, 9)
	if chunk._r(909) < 0.5:
		_asy_gurney(c + Vector3(-5.5, 0, -5.0 * (chunk._r(910) - 0.5)), chunk._r(911) * TAU, 912)
	# a long-dead television would be too kind; a fallen noticeboard instead
	if chunk._r(913) < 0.4:
		var fb = chunk._box(c + Vector3(3.5 * (chunk._r(914) - 0.5), 0.04, -4.5), Vector3(1.2, 0.06, 0.85), Mats.darkwood(), false)
		fb.rotation.y = chunk._r(915) * TAU


## A scarred institutional table and three mismatched chairs, laid out as a
## smaller therapy or card-game group around the edge of a large dayroom.


func _asy_dayroom_table(c: Vector3, salt: int) -> void:
	var body0 = chunk.body.get_child_count()
	var table = chunk._furnishing_pivot(c, 0.0, "asylum_dayroom_table")
	table.set_meta("chemistry_surface_y", 0.755)
	chunk._mrbox(table, Vector3(0, 0.72, 0), Vector3(1.55, 0.07, 1.0),
		Mats.asy_concrete(), 0.025)
	for sx in [-0.62, 0.62]:
		for sz in [-0.36, 0.36]:
			chunk._mcyl(table, Vector3(sx, 0.35, sz), 0.025, 0.7,
				Mats.asy_metal())
	# A minority of common-room tables retain one or two abandoned vessels.
	# Both are children of the supported table assembly, so doorway culling can
	# never leave them suspended after removing the furniture underneath.
	if chunk._r(salt + 20) < 0.68:
		chunk._chemistry_glassware(table, Vector3(-0.28, 0.758, 0.08),
			(chunk._r(salt + 21) - 0.5) * 0.8, salt + 22, false,
			"asylum_dayroom")
		if chunk._r(salt + 23) < 0.42:
			chunk._chemistry_glassware(table, Vector3(0.32, 0.758, -0.12),
				(chunk._r(salt + 24) - 0.5) * 0.9, salt + 25, false,
				"asylum_dayroom")
	chunk._collider_box(c + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.05))
	chunk._bind_furnishing_colliders(table, body0)
	for i in 3:
		var ang = TAU * float(i) / 3.0 + 0.35 + (chunk._r(salt + i) - 0.5) * 0.2
		var cp = c + Vector3(cos(ang) * 1.25, 0, sin(ang) * 1.05)
		_asy_chair(cp, atan2(c.x - cp.x, c.z - cp.z), chunk._r(salt + 5 + i) < 0.25)


## A compact institutional utility counter gives the treatment-room glassware
## an explicit support surface instead of balancing it on the restraint table
## or a trolley whose authored shelf height varies by model.


func _asy_chemistry_counter(p: Vector3, yaw: float, salt: int) -> void:
	var body0 = chunk.body.get_child_count()
	var counter = chunk._furnishing_pivot(p, yaw, "asylum_chemistry_counter")
	counter.set_meta("chemistry_surface_y", 0.785)
	chunk._mrbox(counter, Vector3(0, 0.36, 0), Vector3(1.42, 0.72, 0.52),
		Mats.asy_metal(), 0.025)
	chunk._mrbox(counter, Vector3(0, 0.75, 0), Vector3(1.52, 0.07, 0.60),
		Mats.asy_concrete(), 0.02)
	chunk._mbox(counter, Vector3(0, 0.92, -0.27), Vector3(1.48, 0.30, 0.035),
		Mats.asy_metal())
	chunk._chemistry_glassware(counter, Vector3(-0.34, 0.788, 0.04),
		(chunk._r(salt) - 0.5) * 0.65, salt + 1, false, "asylum_treatment")
	chunk._chemistry_glassware(counter, Vector3(0.32, 0.788, -0.03),
		(chunk._r(salt + 2) - 0.5) * 0.65, salt + 19, false,
		"asylum_treatment")
	chunk._collider_yaw_box(p + Vector3(0, 0.39, 0),
		Vector3(1.52, 0.78, 0.60), yaw)
	chunk._bind_furnishing_colliders(counter, body0)


func _asy_treatment() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var yaw = (PI / 2.0 if chunk._r(920) < 0.5 else 0.0) + (chunk._r(921) - 0.5) * 0.12
	_asy_restraint_table(c, yaw)
	var side = Vector3(cos(yaw), 0, -sin(yaw))
	_asy_ect(c + side * 1.5, yaw + PI / 2.0, 922)
	# surgical lamp aimed at the table
	chunk._cyl(Vector3(c.x, chunk.ceil_h - 0.3, c.z), 0.02, 0.6, Mats.asy_metal(), false)
	var dish = chunk._cyl(Vector3(c.x, chunk.ceil_h - 0.62, c.z), 0.3, 0.14, Mats.steel(), false)
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk._sphere(Vector3(c.x, chunk.ceil_h - 0.68, c.z), 0.07, Mats.bulb())
	var sp = SpotLight3D.new()
	sp.position = Vector3(c.x, chunk.ceil_h - 0.7, c.z)
	sp.rotation.x = -PI / 2.0
	sp.spot_angle = 38.0
	sp.spot_range = chunk.ceil_h
	sp.light_energy = 4.2
	sp.light_color = Color(0.95, 1.0, 0.88)
	sp.shadow_enabled = true
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 20.0
	sp.distance_fade_length = 8.0
	chunk.add_child(sp)
	# the barber chair in the corner is somehow worse than the table
	if chunk._r(923) < 0.6:
		var bp = Vector3(2.2, 0, 2.4)
		var byaw = chunk._r(924) * TAU
		chunk._asy_model("BarberShopChair_01", bp, byaw)
		chunk._collider_yaw_box(bp + Vector3(0, 0.7, 0), Vector3(0.8, 1.5, 1.35), byaw)
	if chunk._r(925) < 0.6:
		_asy_medbox(c + side * -1.6 + Vector3(0, 0, 0.6), chunk._r(926) * TAU)
	# The steel autopsy table stands off to one side of the restraint table,
	# where a second table would actually have been wheeled.
	if chunk._r(1226) < 0.48:
		var ap = c + side * -2.6 + Vector3(0, 0, -1.1)
		if chunk._attributed_floor_prop(chunk.ASY_AUTOPSY_PATH, ap, yaw + PI / 2.0, 1.0,
				chunk.ASY_AUTOPSY_CENTRE, "autopsy_table") != null:
			chunk._collider_yaw_box(ap + Vector3(0, 0.42, 0),
				Vector3(1.20, 0.84, 2.30), yaw + PI / 2.0)
	# The instrument trolley belongs at the table's side, within reach of it.
	if chunk._r(1210) < 0.72:
		_asy_trolley(c + side * (1.15 if chunk._r(1211) < 0.5 else -1.15)
			+ Vector3(0, 0, 0.85), yaw + (chunk._r(1212) - 0.5) * 0.4)
	var chemistry_counter_pos = c + Vector3(3.65, 0, -3.65)
	_asy_chemistry_counter(chemistry_counter_pos,
		atan2(c.x - chemistry_counter_pos.x, c.z - chemistry_counter_pos.z),
		1230)
	# A scrub trough against the first solid wall, taps to the tiles. Its length
	# runs down local Z, so turn it a quarter from the facing to lie along.
	if chunk._r(1213) < 0.55:
		for dir in 4:
			if not WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]:
				continue
			_asy_scrub_sink(
				chunk._wall_pt(dir, chunk.S / 2.0 + (chunk._r(1214) - 0.5) * 2.2, 0.62),
				chunk._wall_facing(dir) + PI / 2.0)
			break
	chunk._asy_papers(c + Vector3(1.8, 0, 1.6), 927, 5)
	# floor drain
	var dr = chunk._cyl(c + Vector3(0.9 * cos(yaw), 0.006, 0.7), 0.14, 0.012, Mats.iron_dark(), false)
	dr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _asy_hydro() -> void:
	var span = chunk._room_span()
	var long_x = span.x >= span.y
	var L = maxf(span.x, span.y)
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var ntubs = int((L - 3.0) / 2.5)
	var salt = 930
	# one row of tubs per 12m of width, offset to leave a walk lane
	var lats: Array = [-2.9, 2.9] if minf(span.x, span.y) > 12.1 else [2.6]
	for lat in lats:
		for ti in ntubs:
			var along = -(L / 2.0 - 2.4) + 2.5 * float(ti) + (chunk._r(salt) - 0.5) * 0.3
			salt += 1
			if chunk._r(salt) < 0.15:
				salt += 2
				continue
			salt += 1
			var p = c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			_asy_tub(p, 0.0 if long_x else PI / 2.0, salt + 30)
			salt += 1
	for ci in 3:
		if chunk._r(950 + ci) < 0.6:
			chunk._chain(c + Vector3((chunk._r(953 + ci) - 0.5) * 6.0, 0, (chunk._r(956 + ci) - 0.5) * 6.0))
	if chunk._r(960) < 0.5:
		_asy_wheelchair(c + Vector3(-3.5 * chunk._r(961), 0, -3.0 * chunk._r(962)), chunk._r(963) * TAU)
	if chunk._r(964) < 0.4:
		_asy_iv(c + Vector3(3.0 * (chunk._r(965) - 0.5), 0, -2.5))
	# The trough the tubs were filled and emptied from, against a solid wall.
	if chunk._r(1220) < 0.62:
		for dir in 4:
			if not WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]:
				continue
			_asy_scrub_sink(
				chunk._wall_pt(dir, chunk.S / 2.0 + (chunk._r(1221) - 0.5) * 3.0, 0.60),
				chunk._wall_facing(dir) + PI / 2.0)
			break
	if chunk._r(1222) < 0.4:
		_asy_trolley(c + Vector3((chunk._r(1223) - 0.5) * 4.0, 0,
			(chunk._r(1224) - 0.5) * 3.0), chunk._r(1225) * TAU)


func _asy_office() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var yaw = [0.0, PI / 2.0, PI, -PI / 2.0][int(chunk._r(970) * 3.99)] as float
	var dp = c + Vector3((chunk._r(971) - 0.5) * 2.0, 0, (chunk._r(972) - 0.5) * 2.0)
	chunk._asy_model("metal_office_desk", dp, yaw)
	chunk._collider_yaw_box(dp + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.95), yaw)
	var back = Vector3(sin(yaw), 0, cos(yaw))
	_asy_chair(dp + back * 0.95, yaw + PI + (chunk._r(973) - 0.5) * 0.6, chunk._r(974) < 0.3)
	_asy_medbox(dp + Vector3(0, 0.79, 0) + back * -0.1 + Vector3(cos(yaw) * 0.55, 0, -sin(yaw) * 0.55), yaw + 0.3)
	# papers drifted off the desk years ago
	chunk._asy_papers(dp + back * 1.2, 975, 8)
	chunk._asy_papers(c + Vector3(2.5 * (chunk._r(976) - 0.5), 0, 2.5 * (chunk._r(977) - 0.5)), 978, 6)
	# filing cabinets against the first solid wall
	for dir in 4:
		if WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]:
			chunk._filing_bank(dir, (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0))
			break
	if chunk._r(979) < 0.4:
		_asy_iv(c + Vector3(4.0, 0, -3.5 * (chunk._r(980) - 0.5)))


## Landmark: an institutional chapel/assembly room. Long scarred pews point
## toward a tiny dais, while one wheelchair has been left in the centre aisle.
## The aisle itself remains a clean sightline and traversal route.


func _asy_chapel() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# Shallow dais and plain altar at the north end.
	var front = c + Vector3(0, 0, -8.0)
	chunk._rbox(front + Vector3(0, 0.16, 0), Vector3(8.0, 0.32, 2.8), Mats.darkwood(), 0.025)
	chunk._rbox(front + Vector3(0, 0.88, 0.1), Vector3(2.2, 1.45, 0.75), Mats.asy_concrete(), 0.035)
	chunk._collider_box(front + Vector3(0, 0.48, 0), Vector3(8.1, 0.96, 2.9))
	# A stark wall cross; it is architecture, not a glowing quest marker.
	chunk._box(front + Vector3(0, 3.45, -1.43), Vector3(0.30, 2.2, 0.09), Mats.darkwood(), false)
	chunk._box(front + Vector3(0, 3.70, -1.43), Vector3(1.45, 0.28, 0.09), Mats.darkwood(), false)
	# Two banks of pews leave a generous central aisle.
	for row in 6:
		var z = -4.5 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var p = c + Vector3(side * 3.65, 0, z)
			chunk._rbox(p + Vector3(0, 0.54, 0), Vector3(5.6, 0.15, 0.66), Mats.darkwood(), 0.035, false)
			chunk._rbox(p + Vector3(0, 0.92, -0.28), Vector3(5.6, 0.72, 0.12), Mats.darkwood(), 0.035, false)
			for sx in [-2.5, 0.0, 2.5]:
				chunk._box(p + Vector3(sx, 0.30, 0), Vector3(0.10, 0.60, 0.58), Mats.iron_dark(), false)
			chunk._collider_box(p + Vector3(0, 0.65, 0), Vector3(5.7, 1.3, 0.75))
	# Human-scale detail makes the symmetry feel abandoned rather than staged.
	_asy_wheelchair(c + Vector3(0.7, 0, 4.2), PI + 0.22)
	chunk._asy_papers(c + Vector3(-0.8, 0, 6.5), 1101, 11)
	var rockp = front + Vector3(4.8, 0, 0.2)
	chunk._asy_model("Rockingchair_01", rockp, -PI / 2.0)
	chunk._collider_yaw_box(rockp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), -PI / 2.0)


## A narrow but structurally complete ward corridor. Locked patient rooms are
## sealed volumes behind continuous masonry; actual graph connections become
## return-walled cross-passages to the canonical cell-edge doorway. The spacing
## stays irregular so this never acquires the office floor's modular rhythm.


func _asy_corridor() -> void:
	var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
	var along_x = cdir != 2
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var lane_half = 2.05
	var side_data = []
	for si in 2:
		var side = -lane_half if si == 0 else lane_half
		var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, sdir, chunk.theme)
		var bay = []
		if not info["wall"]:
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw = clampf(float(info["w"]) + 0.34, 1.9, 2.9)
			bay = [bt, bw]
		var doors = _asy_corridor_doors(si, bay)
		_asy_corridor_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# Abandoned transport is parked only against uninterrupted wall. It adds
	# history without blocking a real connection or floating in front of a door.
	for si in 2:
		var data: Dictionary = side_data[si]
		for di in 2:
			var t = _asy_corridor_prop_t(si, di, data["doors"], data["bay"])
			if t > 90.0:
				continue
			var side: float = (-1.42 if si == 0 else 1.42)
			var pp = chunk._wp(o, Vector3(t, 0, side), yw)
			var rr = chunk._r(724 + si * 5 + di)
			var park_yaw = yw + PI / 2.0
			if rr < 0.18:
				_asy_gurney(pp, park_yaw + (chunk._r(726 + di) - 0.5) * 0.18,
					728 + si * 3 + di)
			elif rr < 0.3:
				_asy_bed(pp, park_yaw + (chunk._r(729 + di) - 0.5) * 0.14,
					730 + si * 3 + di)
			elif rr < 0.46:
				_asy_wheelchair(pp, chunk._r(731 + si * 3 + di) * TAU)
			elif rr < 0.59:
				_asy_iv(pp)
			elif rr < 0.76:
				chunk._asy_papers(pp, 733 + si * 7 + di, 5)
	if chunk._r(740) < 0.4:
		_asy_sign(o, yw)


func _asy_corridor_doors(si: int, bay: Array) -> Array:
	var doors = []
	# Offset the two sides and perturb the end positions slightly: real old wards
	# accrete rooms, unlike the perfectly repeated office grid.
	var positions = [-3.65, -0.15, 3.42] if si == 0 else [-3.28, 0.3, 3.78]
	for di in positions.size():
		var t: float = positions[di] + (chunk._r(700 + si * 7 + di) - 0.5) * 0.26
		if chunk._r(704 + si * 7 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.9:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[1]))
	return doors


func _asy_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.62 + clearance:
			return false
	return true


func _asy_corridor_prop_t(si: int, index: int, doors: Array, bay: Array) -> float:
	var raw = -4.45 + 8.9 * chunk._r(720 + si * 9 + index)
	var candidates = [raw, -4.65, 4.65, -1.72, 1.72]
	if (si + index) % 2 == 1:
		candidates = [raw, 4.65, -4.65, 1.72, -1.72]
	for t in candidates:
		if _asy_corridor_clear(float(t), doors, bay, 0.82):
			return float(t)
	return 99.0


## One complete masonry side, cut only for a filled locked door or for a real
## cross-passage. Wall, tile and collider share the exact same segmentation.


func _asy_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs = [[-6.0, 6.0]]
	for dt in doors:
		segs = chunk._cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = chunk._cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_asy_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt = float(doors[di])
		_asy_corridor_header(o, yw, side, dt, 1.22)
		_asy_corridor_door(o, yw, dt, side,
			750 + (0 if side < 0.0 else 14) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_asy_corridor_header(o, yw, side, bt, bw)
		_asy_corridor_open_casing(o, yw, side, bt, bw)
		_asy_corridor_bay_returns(o, yw, side, bt, bw)


func _asy_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln = b - a
	if ln < 0.04:
		return
	var c = (a + b) * 0.5
	var wc = chunk._wp(o, Vector3(c, chunk.ceil_h * 0.5, side), yw)
	var wall = chunk._mbox(chunk, wc, Vector3(ln, chunk.ceil_h, 0.18), _asy_wall_mat())
	wall.rotation.y = yw
	chunk._collider_yaw_box(wc, Vector3(ln, chunk.ceil_h, 0.18), yw)
	var inn = side - signf(side) * 0.115
	var tile = chunk._mbox(chunk, chunk._wp(o, Vector3(c, 0.69, inn), yw),
		Vector3(ln, 1.38, 0.05), Mats.asy_tile())
	tile.rotation.y = yw
	var rail = chunk._mbox(chunk, chunk._wp(o, Vector3(c, 1.39, inn - signf(side) * 0.018), yw),
		Vector3(ln, 0.07, 0.07), Mats.asy_metal_green())
	rail.rotation.y = yw


func _asy_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh = chunk.ceil_h - chunk.DOOR_TOP
	if hh <= 0.02:
		return
	var hp = chunk._wp(o, Vector3(t, chunk.DOOR_TOP + hh * 0.5, side), yw)
	var head = chunk._mbox(chunk, hp, Vector3(width, hh, 0.18), _asy_wall_mat())
	head.rotation.y = yw
	chunk._collider_yaw_box(hp, Vector3(width, hh, 0.18), yw)


## These returns are the crucial illusion: they carry the corridor wall all the
## way to the real boundary opening and close both neighboring patient volumes.


func _asy_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer = signf(side) * (chunk.S * 0.5 - chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = chunk._wp(o, Vector3(edge, chunk.ceil_h * 0.5, dc), yw)
		var ret = chunk._mbox(chunk, wp, Vector3(0.18, chunk.ceil_h, depth), _asy_wall_mat())
		ret.rotation.y = yw
		chunk._collider_yaw_box(wp, Vector3(0.18, chunk.ceil_h, depth), yw)
		var tile_in = 0.115 if edge < t else -0.115
		var tile = chunk._mbox(chunk, chunk._wp(o, Vector3(edge + tile_in, 0.69, dc), yw),
			Vector3(0.05, 1.38, depth), Mats.asy_tile())
		tile.rotation.y = yw
		var rail = chunk._mbox(chunk, chunk._wp(o, Vector3(edge + tile_in, 1.39, dc), yw),
			Vector3(0.07, 0.07, depth), Mats.asy_metal_green())
		rail.rotation.y = yw
	var floor_strip = chunk._mbox(chunk, chunk._wp(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.asy_checker())
	floor_strip.rotation.y = yw


func _asy_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn = side - signf(side) * 0.115
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = chunk._mbox(chunk, chunk._wp(o, Vector3(edge, chunk.DOOR_TOP * 0.5, inn), yw),
			Vector3(0.12, chunk.DOOR_TOP, 0.3), Mats.asy_metal_green())
		jamb.rotation.y = yw
	var lintel = chunk._mbox(chunk, chunk._wp(o, Vector3(t, chunk.DOOR_TOP + 0.065, inn), yw),
		Vector3(width + 0.18, 0.13, 0.3), Mats.asy_metal_green())
	lintel.rotation.y = yw


## Heavy ward door installed into an actual wall opening. Most hang an authored
## hospital leaf, which brings its own vision panel, hatch and handle; the
## generated leaf below covers the remainder and any import failure. Either way
## the panel is backed by darkness, suggesting a lightless cell without
## exposing empty map.


func _asy_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn = side - signf(side) * 0.115
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	chunk.add_child(v)
	# Casing first: it is the same whichever leaf hangs in it.
	chunk._mbox(v, Vector3(-0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	chunk._mbox(v, Vector3(0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	chunk._mbox(v, Vector3(0, 2.22, 0), Vector3(1.26, 0.13, 0.3), Mats.asy_metal())
	# Darkness behind the leaf, so a vision panel reads as an unlit room.
	chunk._mrbox(v, Vector3(0, 1.06, -0.02), Vector3(1.02, 2.12, 0.02),
		Mats.charcoal(), 0.004)
	if _asy_authored_leaf(v, salt):
		chunk._collider_yaw_box(chunk._wp(o, Vector3(t, 1.06, inn), yw),
			Vector3(1.02, 2.12, 0.16), yw)
		_asy_door_number(v, t, salt)
		return
	chunk._mrbox(v, Vector3(0, 1.06, 0), Vector3(1.0, 2.12, 0.09),
		Mats.asy_metal_green(), 0.012)
	# Opaque backing first, then dirty glass and a welded cross-mesh.
	chunk._mrbox(v, Vector3(0, 1.65, 0.047), Vector3(0.34, 0.42, 0.02),
		Mats.charcoal(), 0.006)
	chunk._mrbox(v, Vector3(0, 1.65, 0.061), Vector3(0.3, 0.38, 0.012),
		Mats.glass_tint(), 0.005)
	for bx in [-0.075, 0.075]:
		chunk._mbox(v, Vector3(bx, 1.65, 0.071), Vector3(0.014, 0.4, 0.01), Mats.iron_dark())
	for by in [1.54, 1.65, 1.76]:
		chunk._mbox(v, Vector3(0, by, 0.072), Vector3(0.32, 0.012, 0.01), Mats.iron_dark())
	# Food hatch, hinges and a lock whose key has long since disappeared.
	chunk._mrbox(v, Vector3(0, 0.68, 0.057), Vector3(0.4, 0.17, 0.025),
		Mats.asy_metal(), 0.006)
	chunk._mbox(v, Vector3(0, 0.59, 0.074), Vector3(0.13, 0.03, 0.025), Mats.steel())
	for hy in [0.42, 1.12, 1.82]:
		chunk._mbox(v, Vector3(-0.49, hy, 0.045), Vector3(0.045, 0.14, 0.055), Mats.iron_dark())
	chunk._mrbox(v, Vector3(0.35, 1.02, 0.066), Vector3(0.13, 0.22, 0.03),
		Mats.iron_dark(), 0.006)
	chunk._msphere(v, Vector3(0.35, 1.02, 0.102), 0.035, Mats.steel())
	chunk._collider_yaw_box(chunk._wp(o, Vector3(t, 1.06, inn), yw),
		Vector3(1.02, 2.12, 0.13), yw)
	_asy_door_number(v, t, salt)


## Hang one of the four authored hospital leaves in a casing already built at
## `v`. Returns false when the model is unavailable, leaving the caller to fall
## back to its generated leaf.


func _asy_authored_leaf(v: Node3D, salt: int) -> bool:
	if chunk._r(salt + 17) >= 0.74:
		return false
	var pick = WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 23) % chunk.ASY_DOOR_PATHS.size()
	var leaf = chunk._attributed_prop_local(v, chunk.ASY_DOOR_PATHS[pick],
		Vector3(0, 0, 0.045), chunk.ASY_DOOR_FACE_YAW[pick],
		Vector3.ONE * chunk.ASY_LEAF_FIT)
	if leaf == null:
		return false
	leaf.set_meta("asylum_authored_leaf", pick)
	return true


## Room number stencilled on the wall beside the opening rather than on the leaf
## itself, which is where a ward actually put them — and which keeps it clear of
## the vision panels and hatches the authored leaves carry.


func _asy_door_number(v: Node3D, t: float, salt: int) -> void:
	var num = Label3D.new()
	num.text = "%02d" % (WorldGen.h(chunk.wseed, chunk.cell.x + int(t * 3.0), chunk.cell.y, salt) % 40 + 1)
	num.font_size = 42
	num.pixel_size = 0.0018
	num.modulate = Color(0.82, 0.86, 0.77)
	num.position = Vector3(-0.78, 1.86, 0.055)
	v.add_child(num)


func _asy_sign(o: Vector3, yw: float) -> void:
	var zone = WorldGen.macro_zone(chunk.wseed, chunk.cell, chunk.theme)
	var labels: Array = chunk.ASY_ZONE_SIGNS[zone]
	var txt: String = labels[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 741) % labels.size()]
	var y = chunk.ceil_h - 0.55
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(0, y, 0), yw)
	v.rotation.y = yw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 0.3, 0), Vector3(0.02, 0.3, 0.02), Mats.iron_dark())
	var plate = chunk._mbox(v, Vector3(0, 0, 0), Vector3(1.5, 0.36, 0.05), Mats.asy_metal_green())
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sside in [-1.0, 1.0]:
		var lb = Label3D.new()
		lb.text = txt
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.88, 0.92, 0.84)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


# --- school -------------------------------------------------------------------
# One building painted over every summer. Cream block above a red line, a floor
# ground until it mirrors the strip lights, and locker runs down every corridor.
# The rooms are all the ones you remember and none of them are in use.


func asylum_authored_audit() -> Dictionary:
	var report = {
		"beds": 0, "gurneys": 0, "trolleys": 0, "baths": 0, "sinks": 0,
		"notices": 0, "facade_doors": 0, "casing_leaves": 0, "violations": 0,
	}
	if chunk.theme != 5:
		return report
	var kinds = {
		"ward_bed": "beds", "gurney": "gurneys",
		"instrument_trolley": "trolleys", "hydro_bath": "baths",
		"scrub_sink": "sinks",
	}
	for node in chunk.find_children("*", "Node3D", true, false):
		if node.has_meta("attributed_furnishing"):
			var kind = str(node.get_meta("attributed_furnishing"))
			if kinds.has(kind):
				report[kinds[kind]] += 1
		if node.has_meta("asylum_wall_notices"):
			report["notices"] += 1
		if bool(node.get_meta("wall_mounted_asylum_door", false)):
			report["facade_doors"] += 1
			if not bool(node.get_meta("locked_facade", false)):
				report["violations"] += 1
		if not node.has_meta("asylum_authored_leaf"):
			continue
		report["casing_leaves"] += 1
		var pick = int(node.get_meta("asylum_authored_leaf"))
		if pick < 0 or pick >= chunk.ASY_DOOR_PATHS.size() \
				or str(node.get_meta("attributed_asset", "")) \
				!= chunk.ASY_DOOR_PATHS[pick]:
			report["violations"] += 1
	return report
