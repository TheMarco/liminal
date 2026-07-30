extends "res://scripts/levels/chunk_level_builder.gd"


func _casino_flush_mount(at: Vector3, lens_mat: Material) -> void:
	var y = chunk.ceil_h - 0.045
	var plate = chunk._cyl(Vector3(at.x, y, at.z), 0.34, 0.055, Mats.darkwood(), false)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring = chunk._cyl(Vector3(at.x, y - 0.035, at.z), 0.285, 0.075, Mats.brass(), false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass = chunk._cyl(Vector3(at.x, y - 0.085, at.z), 0.205, 0.065, lens_mat, false)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A small central finial makes the silhouette read as a fixture rather than
	# another luminous disc pasted onto the ceiling.
	var finial = chunk._sphere(Vector3(at.x, y - 0.14, at.z), 0.055, Mats.brass())
	finial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hotel circulation is lit by a chain of warm flush mounts, not the four
## fluorescent panels used in gaming rooms.  Each fixture owns its light so
## highlights and falloff follow the visible architecture down the corridor.


func _hall_lighting() -> void:
	var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
	var along_x = cdir != 2
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	var dead_i = -1
	var flick_i = -1
	if chunk.cell != Vector2i.ZERO and chunk._r(8) < 0.10:
		dead_i = int(chunk._r(18) * 2.99)
	elif chunk.cell != Vector2i.ZERO and chunk._r(9) < 0.18:
		flick_i = int(chunk._r(19) * 2.99)
	# A 12m chunk contains five complete 2.4m coffers. Use the first, middle and
	# last medallion centres (local 1.2, 6.0, 10.8); the old 2/6/10 rhythm only
	# aligned its middle fixture and visibly walked off the rosettes down a hall.
	for i in 3:
		var t = -4.8 + 4.8 * float(i)
		var at = chunk._wp(o, Vector3(t, chunk.ceil_h - 0.08, 0), yw)
		chunk._cyl(at + Vector3(0, 0.025, 0), 0.27, 0.08, Mats.brass(), false)
		var lens_mat: StandardMaterial3D = Mats.panel_dead() if i == dead_i else Mats.panel_on()
		if i == flick_i:
			lens_mat = Mats.panel_on().duplicate()
		chunk._cyl(at - Vector3(0, 0.035, 0), 0.20, 0.035, lens_mat, false)
		if i == dead_i:
			continue
		var light: OmniLight3D
		if i == flick_i:
			light = chunk._make_main_light(true, lens_mat, 0.58)
		else:
			light = OmniLight3D.new()
			light.light_energy = 0.58
		light.light_color = Color(1.0, 0.72, 0.46)
		light.omni_range = 5.6
		light.position = at - Vector3(0, 0.30, 0)
		light.shadow_enabled = i == 1
		light.distance_fade_enabled = true
		light.distance_fade_begin = 20.0
		light.distance_fade_length = 7.0
		light.distance_fade_shadow = 15.0
		chunk.add_child(light)


func _chandelier() -> void:
	# a real ornate chandelier (CC0 model, hangs 1.04m below its origin) with
	# a warm bulb glowing in its heart
	var ch = chunk._cc0_prop("Chandelier_03", Vector3(chunk.S / 2.0, chunk.ceil_h - 0.05, chunk.S / 2.0), chunk._r(30) * TAU, 1.35)
	chunk._disable_shadows(ch)
	chunk._sphere(Vector3(chunk.S / 2.0, chunk.ceil_h - 0.95, chunk.S / 2.0), 0.13, Mats.bulb())


# --- furnishing --------------------------------------------------------------

## Resolve a proposed single-room split once and share the result between the
## partition, its furnishings, and wall decoration. Previously `_partition`
## could silently slide or rotate the wall while every later system continued
## using the stale proposal, which produced bisected art and furniture on the
## wrong side of the actual room.


func _pillars(h: float, mat: Material) -> void:
	var points = [Vector2(2.2, 2.2), Vector2(9.8, 2.2),
		Vector2(2.2, 9.8), Vector2(9.8, 9.8)]
	if chunk.style == WorldGen.STYLE_GRAND and chunk.room_n >= 4:
		# Local (6,6) is shifted to the 24x24 room centre after furnishing.
		# An eight-column perimeter grid leaves a generous central axis while
		# making the whole hall, not just its middle cell, feel supported.
		points = []
		for px in [-8.0, 0.0, 8.0]:
			for pz in [-8.0, 0.0, 8.0]:
				if px == 0.0 and pz == 0.0:
					continue
				points.append(Vector2(6.0 + px, 6.0 + pz))
	for p in points:
		chunk._box(Vector3(p.x, 0.06, p.y), Vector3(0.95, 0.12, 0.95), Mats.darkwood())
		chunk._cyl(Vector3(p.x, h / 2.0, p.y), 0.34, h, mat)
		for ring_y in [0.28, h - 0.28]:
			var tor = MeshInstance3D.new()
			tor.mesh = chunk.TOR
			tor.material_override = Mats.brass()
			tor.position = Vector3(p.x, ring_y, p.y)
			tor.scale = Vector3(0.5, 0.22, 0.5)
			chunk.add_child(tor)


# --- vegas: slots ------------------------------------------------------------


func _slots() -> void:
	var idx = 0
	for row in [[4.35, -1.0], [7.65, 1.0]]:
		var z: float = row[0]
		var fx: float = row[1]
		for i in 5:
			_slot_machine(3.4 + 1.3 * i, z, fx, idx)
			idx += 1
	# colored glow washing over each bank's player side
	var glow_cols = [Color(1.0, 0.35, 0.6), Color(0.45, 0.8, 1.0)]
	var glow_z = [3.0, 9.0]
	for gi in 2:
		var gl = OmniLight3D.new()
		gl.light_color = glow_cols[gi]
		gl.light_energy = 0.7
		gl.omni_range = 5.5
		gl.position = Vector3(chunk.S / 2.0, 2.3, glow_z[gi])
		gl.shadow_enabled = false
		gl.distance_fade_enabled = true
		gl.distance_fade_begin = 16.0
		gl.distance_fade_length = 8.0
		chunk.add_child(gl)
	# magenta ceiling cove around the slot floor
	var cy = chunk.ceil_h - 0.22
	chunk._box(Vector3(chunk.S / 2.0, cy, 0.5), Vector3(chunk.S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	chunk._box(Vector3(chunk.S / 2.0, cy, chunk.S - 0.5), Vector3(chunk.S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	chunk._box(Vector3(0.5, cy, chunk.S / 2.0), Vector3(0.06, 0.05, chunk.S - 1.6), Mats.neon_pink(), false)
	chunk._box(Vector3(chunk.S - 0.5, cy, chunk.S / 2.0), Vector3(0.06, 0.05, chunk.S - 1.6), Mats.neon_pink(), false)
	_slots_sign()
	var snd = SlotSounds.new()
	snd.position = Vector3(chunk.S / 2.0, 1.6, chunk.S / 2.0)
	chunk.add_child(snd)


## Most of the casino floor uses morrrtu1o's properly attributed, textured
## vintage cabinet, while a small minority remains newer procedural hardware
## so the bank does not read as ten copies of one machine. The downloaded
## source can disappear without breaking the generated fallback.


func _slot_machine(x: float, z: float, f: float, idx: int) -> void:
	if posmod(idx, 5) == 4:
		_slot_machine_alt(x, z, f, idx)
		return
	if chunk._slot_scene == null:
		chunk._slot_scene = chunk._prop_scene(chunk.SLOT_MACHINE_PATH)
	if chunk._slot_scene == null:
		_procedural_slot_machine(x, z, f, idx)
		return

	var m = Node3D.new()
	m.name = "VintageSlotMachine"
	m.set_meta("slot_machine", true)
	m.set_meta("slot_asset", "morrrtu1o_slot_machine")
	m.position = Vector3(x, 0, z)
	if f < 0.0:
		m.rotation.y = PI
	chunk.add_child(m)

	var inst = chunk._slot_scene.instantiate() as Node3D
	inst.name = "AttributedCabinet"
	inst.scale = Vector3.ONE * chunk.SLOT_MACHINE_SCALE
	inst.position.y = chunk.SLOT_MACHINE_FLOOR_OFFSET * chunk.SLOT_MACHINE_SCALE
	# The model is a closed, double-sided cabinet with an explicit front and
	# service back. These tags let the generated-world audit distinguish that
	# deliberate volume from the old stacks of unsupported display quads.
	inst.set_meta("slot_front_shell", true)
	inst.set_meta("slot_rear_shell", true)
	m.add_child(inst)

	# The downloaded prop supplies the cabinet and PBR wear. A tiny live status
	# lamp ties it into the surrounding bank lighting without bleaching its
	# baked artwork or turning the vintage machine into another neon pillar.
	var status = chunk._mcyl(m, Vector3(0.22, 0.91, 0.31),
		0.015, 0.012, Mats.slot_status_blue())
	status.rotation.x = PI / 2.0

	if chunk._r(60 + idx) < 0.85:
		var cyaw = (0.0 if f > 0.0 else PI) + (chunk._r(66 + idx) - 0.5) * 0.6
		var cpos = Vector3(x + (chunk._r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		chunk._cc0_prop("bar_chair_round_01", cpos, cyaw)
		chunk._collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	chunk._collider_box(Vector3(x, 0.85, z), Vector3(0.88, 1.70, 0.76))


## The minority cabinet, so a bank never reads as ten copies of the vintage
## one. This used to be forty-two primitives with live shader screens; it is
## now a second authored machine, and the generated cabinet below stays as the
## fallback if the model is missing.


func _slot_machine_alt(x: float, z: float, f: float, idx: int) -> void:
	var yaw = 0.0 if f > 0.0 else PI
	var b0 = chunk.body.get_child_count()
	var pivot = chunk._attributed_floor_prop(chunk.SLOT_ALT_PATH, Vector3(x, 0, z), yaw,
		chunk.SLOT_ALT_SCALE, chunk.SLOT_ALT_CENTRE, "slot_machine_alt", null, true)
	if pivot == null:
		_procedural_slot_machine(x, z, f, idx)
		return
	pivot.set_meta("slot_machine", true)
	pivot.set_meta("slot_asset", "slot_machine_alt")
	# The generated-world audit checks that no cabinet is an unsupported stack
	# of display quads. This one is a closed authored volume, front and back.
	pivot.set_meta("slot_front_shell", true)
	pivot.set_meta("slot_rear_shell", true)
	if chunk._r(60 + idx) < 0.85:
		var cyaw = yaw + (chunk._r(66 + idx) - 0.5) * 0.6
		var cpos = Vector3(x + (chunk._r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		chunk._cc0_prop("bar_chair_round_01", cpos, cyaw)
		chunk._collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	chunk._collider_box(Vector3(x, 0.88, z), Vector3(0.62, 1.76, 1.10))
	chunk._bind_furnishing_colliders(pivot, b0)


## Newer alternate machine: sculpted cabinet shell (shared ArrayMesh) with the
## full panel stack riding its sloped front, and a bonus wheel or marquee.


func _procedural_slot_machine(x: float, z: float, f: float, idx: int) -> void:
	var m = Node3D.new()
	m.name = "SlotMachine"
	m.set_meta("slot_machine", true)
	m.position = Vector3(x, 0, z)
	if f < 0.0:
		m.rotation.y = PI
	chunk.add_child(m)
	var cabinet_type = idx % 4
	# Bonus wheels are visual punctuation, not half the casino floor. The other
	# cabinets split between classic mechanical, slant-top and portrait video
	# silhouettes so a bank no longer reads as ten clones.
	var has_wheel = cabinet_type == 0
	var accent: Material = Mats.slot_accent_amber() \
		if posmod(idx, 3) == 0 else Mats.slot_accent_cyan()
	var bodymat: Material = Mats.slot_cabinet_variant(idx)
	var plastic = Mats.slot_molded_plastic()
	var trim = Mats.slot_brushed_metal()

	var shell = MeshInstance3D.new()
	shell.mesh = Cabinet.mesh()
	shell.material_override = bodymat
	m.add_child(shell)
	# The sculpted shell's rear used to be a single custom-mesh face. It could
	# disappear from the back because of face winding/material culling, leaving
	# a bank of convincing fronts that looked hollow from the central aisle.
	# Build the rear as real volume, with the service hardware a casino cabinet
	# would actually expose.
	var rear = chunk._mrbox(m, Vector3(0, 1.06, -0.225),
		Vector3(0.58, 2.08, 0.12), bodymat, 0.025)
	rear.name = "RearShell"
	rear.set_meta("slot_rear_shell", true)
	var service = chunk._mrbox(m, Vector3(0, 1.08, -0.294),
		Vector3(0.45, 1.42, 0.025), plastic, 0.018)
	service.name = "RearServiceDoor"
	# Recessed ventilation slots, a lock and a low power-entry cover keep the
	# back readable without turning the normally hidden side into another sign.
	for vi in 7:
		chunk._mbox(m, Vector3(0, 1.66 + float(vi) * 0.055, -0.310),
			Vector3(0.27, 0.014, 0.012), Mats.rubber_black())
	var rear_lock = chunk._mcyl(m, Vector3(0.155, 1.29, -0.316),
		0.025, 0.018, trim)
	rear_lock.rotation.x = PI / 2.0
	chunk._mrbox(m, Vector3(0, 0.34, -0.312),
		Vector3(0.26, 0.20, 0.035), plastic, 0.01)
	# Manufacturer/service label, hinge knuckles and power inlet.
	chunk._mbox(m, Vector3(-0.105, 0.82, -0.323),
		Vector3(0.14, 0.09, 0.008), Mats.slot_service_label())
	for hy in [0.58, 1.05, 1.50]:
		var hinge = chunk._mcyl(m, Vector3(-0.236, hy, -0.312),
			0.018, 0.07, trim)
		hinge.rotation.x = PI / 2.0
	chunk._mbox(m, Vector3(0.07, 0.33, -0.334),
		Vector3(0.075, 0.085, 0.012), Mats.rubber_black())
	chunk._mbox(m, Vector3(0, 0.135, -0.286),
		Vector3(0.60, 0.22, 0.16), plastic)
	# The screen stack used to be a collection of front-facing quads over an
	# open custom mesh. A continuous recessed substrate now closes every gap
	# around and between the ticker, reels and paytable, so the casino cannot
	# be seen through the face of the machine from oblique angles.
	var front = chunk._mrbox(m, Vector3(0, 1.18, 0.205),
		Vector3(0.58, 1.92, 0.13), bodymat, 0.024)
	front.name = "FrontShell"
	front.set_meta("slot_front_shell", true)
	chunk._mrbox(m, Vector3(0, 1.42, 0.252),
		Vector3(0.50, 1.23, 0.018), plastic, 0.009)
	# Restrained edge illumination: most real cabinets illuminate the display
	# frame, not two floor-to-top neon poles. One machine per bank keeps the
	# louder full-height treatment; the rest have short inset light guides.
	var accent_h = 1.55 if posmod(idx, 5) == 0 else 0.68
	var accent_y = 1.08 if accent_h > 1.0 else 1.43
	for sx in [-1.0, 1.0]:
		chunk._mbox(m, Vector3(sx * 0.284, accent_y, 0.275),
			Vector3(0.014, accent_h, 0.018), accent)
		chunk._mbox(m, Vector3(sx * 0.264, 1.42, 0.292),
			Vector3(0.018, 1.10, 0.022), trim)
	chunk._mrbox(m, Vector3(0, 0.24, 0.235), Vector3(0.36, 0.13, 0.06), plastic, 0.015)
	chunk._mquad(m, Vector3(0, 0.42, 0.278), Vector2(0.44, 0.26), Mats.ticker())
	# Ticket bin and lockable lower cash door.
	chunk._mrbox(m, Vector3(0, 0.125, 0.322),
		Vector3(0.24, 0.055, 0.055), trim, 0.008)
	chunk._mbox(m, Vector3(-0.18, 0.23, 0.304),
		Vector3(0.09, 0.055, 0.008), Mats.slot_service_label())
	var cash_lock = chunk._mcyl(m, Vector3(0.20, 0.32, 0.310),
		0.017, 0.014, trim)
	cash_lock.rotation.x = PI / 2.0
	for sx in [-1.0, 1.0]:
		chunk._mbox(m, Vector3(sx * 0.19, 0.64, 0.272),
			Vector3(0.09, 0.14, 0.015), plastic)
	var deck = chunk._mrbox(m, Vector3(0, 0.84, 0.30),
		Vector3(0.54, 0.045, 0.26), plastic, 0.012)
	deck.rotation.x = 0.45
	var bmats: Array = [Mats.lamp_amber(), Mats.red_knob(), Mats.chrome(), Mats.lamp_red(), Mats.lamp_amber()]
	for bi in 5:
		var btn = chunk._mcyl(m, Vector3(-0.17 + 0.077 * bi, 0.875, 0.345), 0.024, 0.02, bmats[bi])
		btn.rotation.x = 0.45
	# Bill validator, player card reader and ticket-printer mouth.
	chunk._mbox(m, Vector3(0.19, 0.80, 0.315), Vector3(0.12, 0.09, 0.07), plastic)
	chunk._mbox(m, Vector3(0.19, 0.815, 0.352), Vector3(0.07, 0.012, 0.01), Mats.lamp_green())
	chunk._mrbox(m, Vector3(-0.18, 0.785, 0.356),
		Vector3(0.10, 0.052, 0.018), Mats.slot_status_blue(), 0.006)
	chunk._mbox(m, Vector3(0.02, 0.755, 0.361),
		Vector3(0.105, 0.012, 0.008), Mats.rubber_black())
	var reels = chunk._mquad(m, Vector3(0, 1.18, 0.335), Vector2(0.46, 0.40), Mats.slot_reels())
	reels.rotation.x = -0.107
	var pay = chunk._mquad(m, Vector3(0, 1.66, 0.275), Vector2(0.46, 0.34),
		Mats.slot_artwork(idx))
	pay.rotation.x = -0.095
	var glass = chunk._mquad(m, Vector3(0, 1.45, 0.315), Vector2(0.5, 1.0), Mats.glass())
	glass.rotation.x = -0.1
	# Speaker grille and the seam of the hinged screen/service door.
	for si in 7:
		chunk._mbox(m, Vector3(-0.15 + si * 0.05, 1.925, 0.302),
			Vector3(0.028, 0.012, 0.008), Mats.rubber_black())
	chunk._mbox(m, Vector3(0, 0.715, 0.300),
		Vector3(0.46, 0.008, 0.008), trim)
	chunk._mrbox(m, Vector3(0, 2.19, -0.02),
		Vector3(0.54, 0.18, 0.40), plastic, 0.02)
	chunk._mquad(m, Vector3(0, 2.19, 0.185), Vector2(0.5, 0.16), Mats.ticker())
	chunk._mcyl(m, Vector3(0, 2.33, -0.16), 0.035, 0.1, Mats.lamp_amber())
	chunk._mcyl(m, Vector3(0, 2.42, -0.16), 0.03, 0.08, Mats.lamp_red())
	if has_wheel:
		chunk._mbox(m, Vector3(0, 2.38, 0.0), Vector3(0.16, 0.35, 0.1), Mats.gold_mirror())
		# The bonus wheel was another front-only quad. A shallow metal drum
		# closes the topper and gives its silhouette proper depth from behind.
		var wheel_back = chunk._mcyl(m, Vector3(0, 2.72, -0.035),
			0.35, 0.11, Mats.sign_housing())
		wheel_back.rotation.x = PI / 2.0
		wheel_back.set_meta("slot_topper_back", true)
		var wheel_hub = chunk._mcyl(m, Vector3(0, 2.72, -0.096),
			0.075, 0.025, Mats.chrome())
		wheel_hub.rotation.x = PI / 2.0
		chunk._mquad(m, Vector3(0, 2.72, 0.06), Vector2(0.66, 0.66), Mats.slot_wheel())
		var ring = MeshInstance3D.new()
		ring.mesh = chunk.TOR
		ring.material_override = Mats.ring_pink() if chunk._r(84 + idx) < 0.5 else Mats.ring_cyan()
		ring.position = Vector3(0, 2.72, 0.03)
		ring.scale = Vector3(0.36, 0.16, 0.36)
		ring.rotation.x = PI / 2.0
		m.add_child(ring)
		for sx in [-1.0, 1.0]:
			var wing = chunk._mbox(m, Vector3(sx * 0.30, 2.62, -0.02), Vector3(0.1, 0.5, 0.08), Mats.gold_mirror())
			wing.rotation.z = -sx * 0.3
	else:
		var top_h = 0.52 if cabinet_type == 1 else 0.38
		var top_y = 2.53 if cabinet_type == 1 else 2.47
		chunk._mrbox(m, Vector3(0, top_y, 0.0),
			Vector3(0.54, top_h, 0.14), plastic, 0.02)
		chunk._mquad(m, Vector3(0, top_y, 0.075),
			Vector2(0.5, min(top_h - 0.04, 0.34)), Mats.slot_artwork(idx + 1))
		# Only the deliberately old mechanical variant retains a pull arm.
		if cabinet_type == 2:
			var arm = chunk._mcyl(m, Vector3(0.33, 1.35, -0.02),
				0.018, 0.34, trim)
			arm.rotation.x = -0.4
			var knob = MeshInstance3D.new()
			knob.mesh = chunk.SPH
			knob.material_override = Mats.red_knob()
			knob.position = Vector3(0.33, 1.5, -0.09)
			knob.scale = Vector3.ONE * 0.09
			m.add_child(knob)
	if chunk._r(60 + idx) < 0.85:
		var cyaw = (0.0 if f > 0.0 else PI) + (chunk._r(66 + idx) - 0.5) * 0.6
		var cpos = Vector3(x + (chunk._r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		# a real worn bar stool pulled up to the machine
		chunk._cc0_prop("bar_chair_round_01", cpos, cyaw)
		chunk._collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	chunk._collider_box(Vector3(x, 1.42, z), Vector3(0.68, 2.85, 0.72))


func _chair_at(p: Vector3, yaw: float, _mat: Material) -> Node3D:
	var ch = chunk._cc0_prop("bar_chair_round_01", p, yaw)
	chunk._collider_cyl(p + Vector3(0, 0.38, 0), 0.25, 0.76)
	return ch


## Backlit SLOTS sign on the first solid wall of the room.


func _slots_sign() -> void:
	if chunk._r(88) > 0.7:
		return
	for dir in 4:
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)
		if not info["wall"]:
			continue
		var plane = (chunk.S - chunk.T / 2.0) if (dir == 0 or dir == 2) else (chunk.T / 2.0)
		var n = -1.0 if (dir == 0 or dir == 2) else 1.0
		var inner = plane + n * (chunk.T * 0.5)
		var off = inner + n * 0.05
		var lb = Label3D.new()
		lb.text = "S L O T S"
		lb.font_size = 140
		lb.pixel_size = 0.0028
		lb.outline_size = 20
		lb.outline_modulate = Color(0.4, 0.05, 0.1)
		lb.modulate = Color(1.0, 0.78, 0.25)
		if dir < 2:
			lb.position = Vector3(off, 2.45, chunk.S / 2.0)
			lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
			chunk._box(Vector3(off, 2.13, chunk.S / 2.0), Vector3(0.04, 0.05, 2.2), Mats.neon_amber(), false)
		else:
			lb.position = Vector3(chunk.S / 2.0, 2.45, off)
			lb.rotation.y = 0.0 if n > 0.0 else PI
			chunk._box(Vector3(chunk.S / 2.0, 2.13, off), Vector3(2.2, 0.05, 0.04), Mats.neon_amber(), false)
		chunk.add_child(lb)
		return


## Backlit neon lettering pointing at amenities that are never found.


func _casino_neon(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T * 0.5)
	var off = inner + n * 0.05
	var pick = int(chunk._r(56 + dir) * (float(chunk.CASINO_NEON.size()) - 0.01))
	var txt: String = chunk.CASINO_NEON[pick][0]
	var colr: Color = chunk.CASINO_NEON[pick][1]
	var lb = Label3D.new()
	lb.text = txt
	lb.font_size = 120
	lb.pixel_size = 0.0026
	lb.outline_size = 18
	lb.outline_modulate = Color(colr.r * 0.22, colr.g * 0.22, colr.b * 0.22)
	lb.modulate = colr
	var tube = Mats.neon_col("c%d" % pick, colr)
	if dir < 2:
		lb.position = Vector3(off, 2.42, chunk.S / 2.0)
		lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		chunk._box(Vector3(off, 2.12, chunk.S / 2.0), Vector3(0.04, 0.045, 1.9), tube, false)
	else:
		lb.position = Vector3(chunk.S / 2.0, 2.42, off)
		lb.rotation.y = 0.0 if n > 0.0 else PI
		chunk._box(Vector3(chunk.S / 2.0, 2.12, off), Vector3(1.9, 0.045, 0.04), tube, false)
	chunk.add_child(lb)
	var l = OmniLight3D.new()
	l.light_color = colr
	l.light_energy = 0.45
	l.omni_range = 4.0
	l.position = lb.position + Vector3(n * 0.35, -0.1, 0) if dir < 2 else lb.position + Vector3(0, -0.1, n * 0.35)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 14.0
	l.distance_fade_length = 6.0
	chunk.add_child(l)


## Bill-change machine humming against the wall, screen still lit.


func _change_machine(dir: int, plane: float) -> void:
	var n = -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner = plane + n * (chunk.T * 0.5)
	var along = 2.4 + 7.2 * chunk._r(58 + dir)
	var v = Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.30, 0, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 0, inner + n * 0.30)
		v.rotation.y = 0.0 if n > 0.0 else PI
	chunk.add_child(v)
	# The authored cabinet carries its own CHANGE branding, coin tray and bill
	# slot, so the generated panel stack and Label3D marquee are gone with it.
	var unit = chunk._attributed_prop_local(v, chunk.CHANGE_MACHINE_PATH,
		-chunk.CHANGE_MACHINE_CENTRE * chunk.CHANGE_MACHINE_SCALE, 0.0,
		Vector3.ONE * chunk.CHANGE_MACHINE_SCALE)
	if unit == null:
		chunk._mrbox(v, Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.5),
			Mats.slot_body(), 0.03)
		chunk._mquad(v, Vector3(-0.12, 1.42, 0.253), Vector2(0.34, 0.24), Mats.ticker())
		chunk._mbox(v, Vector3(0, 0.98, 0.26), Vector3(0.5, 0.05, 0.03), Mats.chrome())
		var lb = Label3D.new()
		lb.text = "CHANGE"
		lb.font_size = 72
		lb.pixel_size = 0.0022
		lb.modulate = Color(1.0, 0.72, 0.2)
		lb.position = Vector3(0, 1.75, 0.26)
		v.add_child(lb)
	else:
		v.set_meta("attributed_furnishing", "casino_change_machine")
	chunk._collider_yaw_box(v.position + Vector3(0, 0.88, 0),
		Vector3(1.0, 1.76, 0.52), v.rotation.y)


## Blackjack table nobody deals anymore: baize, shoe, chips, three stools.
## The authored blackjack setpiece: semicircular table, felt, and six matching
## stools already arranged around the player arc. It replaces the generated
## table outright rather than standing beside it, so a floor never shows both
## versions of the same furniture.


func _blackjack_authored(p: Vector3, salt: int) -> bool:
	var yaw = chunk._r(salt + 41) * TAU
	var pivot = chunk._attributed_floor_prop(chunk.CASINO_BLACKJACK_PATH, p, yaw,
		chunk.CASINO_BLACKJACK_SCALE, Vector3.ZERO, "blackjack_table")
	if pivot == null:
		return false
	# Collide the table body only. The stools sit outside it and are thin
	# enough that walking between them reads as intended rather than blocked.
	chunk._collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(2.45, 0.90, 1.15), yaw)
	return true


## Roulette: wheel head at one end, betting layout at the other, one piece.


func _roulette(p: Vector3, salt: int) -> void:
	var yaw = chunk._r(salt) * TAU
	if chunk._attributed_floor_prop(chunk.CASINO_ROULETTE_PATH, p, yaw,
			chunk.CASINO_ROULETTE_SCALE, chunk.CASINO_ROULETTE_CENTRE, "roulette_table") == null:
		return
	chunk._collider_yaw_box(p + Vector3(0, 0.48, 0), Vector3(3.5, 0.96, 2.12), yaw)


## Every table is the authored one now. The generated felt-and-torus table below
## survives only as an import-failure fallback: two versions of the same
## furniture on one casino floor read as a bug, not as variety.


func _blackjack(p: Vector3, salt: int) -> void:
	if _blackjack_authored(p, salt):
		return
	chunk._cyl(p + Vector3(0, 0.76, 0), 0.92, 0.06, Mats.felt_green(), false)
	var rim = MeshInstance3D.new()
	rim.mesh = chunk.TOR
	rim.material_override = Mats.darkwood()
	rim.position = p + Vector3(0, 0.775, 0)
	rim.scale = Vector3(1.24, 0.22, 1.24)
	chunk.add_child(rim)
	chunk._cyl(p + Vector3(0, 0.38, 0), 0.15, 0.76, Mats.darkwood(), false)
	chunk._cyl(p + Vector3(0, 0.05, 0), 0.48, 0.1, Mats.darkwood(), false)
	chunk._collider_cyl(p + Vector3(0, 0.45, 0), 0.95, 0.9)
	# dealer side: chip rack and shoe
	chunk._rbox(p + Vector3(0, 0.815, -0.45), Vector3(0.42, 0.035, 0.18), Mats.sign_housing(), 0.008, false)
	chunk._rbox(p + Vector3(0.45, 0.83, -0.28), Vector3(0.16, 0.1, 0.24), Mats.body_black(), 0.02, false)
	# cards where the last hand stopped
	for i in 5:
		var ca = chunk._box(p + Vector3((chunk._r(salt + i) - 0.5) * 1.1, 0.795, (chunk._r(salt + 9 + i) - 0.5) * 0.9),
			Vector3(0.063, 0.004, 0.088), Mats.paint_white(), false)
		ca.rotation.y = chunk._r(salt + 17 + i) * TAU
	# chip stacks
	var chip_mats: Array = [Mats.red_knob(), Mats.body_black(), Mats.body_blue()]
	for i in 3:
		chunk._cyl(p + Vector3(0.2 - 0.2 * float(i), 0.82, 0.32), 0.036,
			0.05 + 0.05 * chunk._r(salt + 22 + i), chip_mats[i], false)
	# stools around the player arc
	for i in 3:
		var ang = PI * (0.3 + 0.2 * float(i)) + (chunk._r(salt + 27 + i) - 0.5) * 0.2
		var cp = p + Vector3(cos(ang) * 1.4, 0, sin(ang) * 1.4)
		_chair_at(cp, atan2(cos(ang), sin(ang)) + (chunk._r(salt + 31 + i) - 0.5) * 0.5, Mats.velvet())


## Brass posts and sagging red rope framing the grand hall's centre aisle.
## Two queue lines flanking the casino's main axis, laid out on the authored
## barrier's own 1.891m post pitch rather than a chosen one.


func _velvet_ropes() -> void:
	for xr in [3.0, 9.0]:
		for i in 4:
			chunk._rope_barrier(Vector3(xr, 0,
				2.4 + chunk.ROPE_BARRIER_PITCH * (float(i) + 0.5)), PI / 2.0,
				"casino_queue_rope")


## One pair of brass stanchions and the swag between them. `yaw` turns the
## run: the authored unit lies along its local X.


func _casino_ballroom() -> void:
	var c = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# Inlaid dance floor and brass border.
	chunk._box(c + Vector3(0, 0.012, 0.6), Vector3(10.2, 0.024, 8.2), Mats.marble_photo(), false)
	for sx in [-5.18, 5.18]:
		chunk._box(c + Vector3(sx, 0.027, 0.6), Vector3(0.08, 0.03, 8.35), Mats.brass(), false)
	for sz in [-3.52, 4.72]:
		chunk._box(c + Vector3(0, 0.027, sz), Vector3(10.35, 0.03, 0.08), Mats.brass(), false)
	# Low stage across the far side, curtain folds and an abandoned microphone.
	var stage = c + Vector3(0, 0, -8.0)
	chunk._rbox(stage + Vector3(0, 0.22, 0), Vector3(9.2, 0.44, 2.7), Mats.darkwood(), 0.025)
	for i in 9:
		var x = -4.2 + 1.05 * float(i)
		chunk._box(stage + Vector3(x, 2.45, -1.22), Vector3(0.58, 4.4, 0.10),
			Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	var mic = stage + Vector3(0.8, 0.44, 0.35)
	chunk._cyl(mic + Vector3(0, 0.72, 0), 0.025, 1.44, Mats.chrome(), false)
	chunk._sphere(mic + Vector3(0, 1.48, 0), 0.065, Mats.charcoal())
	chunk._collider_box(stage + Vector3(0, 0.24, 0), Vector3(9.3, 0.48, 2.8))
	# Supper tables form a loose ring, leaving the dance floor empty.
	for i in 6:
		var ang = TAU * float(i) / 6.0 + PI / 6.0
		var tp = c + Vector3(cos(ang) * 8.1, 0, 0.9 + sin(ang) * 7.2)
		chunk._cc0_prop("coffee_table_round_01", tp, ang)
		chunk._collider_cyl(tp + Vector3(0, 0.26, 0), 0.67, 0.52)
		for j in 3:
			var ca = ang + TAU * float(j) / 3.0 + 0.35
			var cp = tp + Vector3(cos(ca) * 1.0, 0, sin(ca) * 1.0)
			chunk._cc0_prop("bar_chair_round_01", cp, ca + PI)
			chunk._collider_cyl(cp + Vector3(0, 0.38, 0), 0.25, 0.76)
	var title = Label3D.new()
	title.text = "THE SILVER ROOM"
	title.font_size = 140
	title.pixel_size = 0.003
	title.modulate = Color(1.0, 0.72, 0.22)
	title.position = stage + Vector3(0, 3.8, -1.30)
	chunk.add_child(title)


## Hotel corridor: a 3m lane of numbered, permanently locked rooms.  The
## guest-room strips behind the two walls are real reserved floor-plan volume:
## they may continue invisibly through several corridor cells, but no navigable
## opening can expose a door's back.  Actual room connections get a cased bay
## with return walls all the way to the canonical cell-edge doorway.


func _hallway() -> void:
	var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
	var along_x = cdir != 2
	var yw = 0.0 if along_x else PI / 2.0
	var o = Vector3(chunk.S / 2.0, 0, chunk.S / 2.0)
	# A fitted runner, inset from the walls so a dark carpet border remains.
	var run = chunk._mbox(chunk, chunk._wp(o, Vector3(0, 0.013, 0), yw),
		Vector3(12.0, 0.026, 2.18), Mats.carpet_red())
	run.rotation.y = yw

	var side_data = []
	for si in 2:
		var side = -1.5 if si == 0 else 1.5
		var sdir = (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info = WorldGen.edge_info(chunk.wseed, chunk.cell, sdir, chunk.theme)
		var bay = []
		if not info["wall"]:
			# Edge t runs in +x or +z.  Local corridor x runs toward -z after
			# the 90-degree rotation, hence the sign flip in a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw = clampf(float(info["w"]) + 0.42, 2.05, 4.2)
			bay = [bt, bw]
		var doors = _hall_locked_doors(si, bay)
		_hall_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# A grandfather clock that no longer agrees with anything.  It is allowed
	# only on uninterrupted wall, never in an actual room bay or over a door.
	if chunk._r(288) < 0.14:
		var csi = 0 if chunk._r(290) < 0.5 else 1
		var ct = -3.9 + 7.8 * chunk._r(289)
		if _hall_clear_at(ct, side_data[csi]["doors"], side_data[csi]["bay"], 0.62):
			var cside: float = side_data[csi]["side"] - signf(side_data[csi]["side"]) * 0.28
			var ckp = chunk._wp(o, Vector3(ct, 0, cside), yw)
			var cky = yw + (0.0 if cside < 0.0 else PI)
			chunk._cc0_prop("vintage_grandfather_clock_01", ckp, cky)
			chunk._collider_yaw_box(ckp + Vector3(0, 1.1, 0), Vector3(0.66, 2.2, 0.46), cky)

	# Staggered sconces, moved to the nearest clean stretch when a generated bay
	# happens to claim their usual position.
	for si in 2:
		var sd: Dictionary = side_data[si]
		var t = _hall_sconce_t(si, sd["doors"], sd["bay"])
		if t > 90.0:
			continue
		var side: float = sd["side"] - signf(sd["side"]) * 0.14
		var wpp = chunk._wp(o, Vector3(t, 0, side), yw)
		var outn = Vector3(0, 0, -signf(side)).rotated(Vector3.UP, yw)
		chunk._box(wpp + Vector3(0, 1.78, 0), Vector3(0.1, 0.34, 0.1), Mats.brass(), false)
		chunk._cyl(wpp + outn * 0.1 + Vector3(0, 1.86, 0), 0.10, 0.17, Mats.shade(), false)
		chunk._sphere(wpp + outn * 0.1 + Vector3(0, 1.97, 0), 0.035, Mats.bulb())
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.70, 0.43)
		l.light_energy = 0.34
		l.omni_range = 3.8
		l.position = wpp + outn * 0.28 + Vector3(0, 1.95, 0)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 6.0
		chunk.add_child(l)


## Candidate locked rooms on one side of the hotel corridor.  A real bay owns
## its stretch of wall and suppresses any decorative door that would overlap.


func _hall_locked_doors(si: int, bay: Array) -> Array:
	var doors = []
	for di in 3:
		var t = -3.2 + 3.2 * float(di)
		if chunk._r(270 + si * 4 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 1.0:
			continue
		doors.append(t)
	return doors


func _hall_clear_at(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	return corridor_clear_at(t, doors, bay, clearance, 0.62)


func _hall_sconce_t(si: int, doors: Array, bay: Array) -> float:
	var candidates = [-1.6, 1.6, -4.55, 4.55]
	if si == 1:
		candidates = [1.6, -1.6, 4.55, -4.55]
	for t in candidates:
		if _hall_clear_at(float(t), doors, bay, 0.48):
			return float(t)
	return 99.0


## One complete side of the corridor shell.  Walls run the full 12m and are
## cut only for a filled locked door or for a return-walled real room bay.


func _hall_wall_side(o: Vector3, yw: float, side: float, doors: Array, bay: Array) -> void:
	var segs = [[-6.0, 6.0]]
	for dt in doors:
		segs = chunk._cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = chunk._cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_hall_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for dt in doors:
		_hall_header(o, yw, side, float(dt), 1.22)
		_hall_door(o, yw, float(dt), side,
			275 + (0 if side < 0.0 else 8) + int(round((float(dt) + 3.2) / 3.2)))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_hall_header(o, yw, side, bt, bw)
		_hall_open_casing(o, yw, side, bt, bw)
		_hall_bay_returns(o, yw, side, bt, bw)


func _hall_wall_run(o: Vector3, yw: float, side: float, a: float, b: float) -> void:
	var ln = b - a
	if ln < 0.04:
		return
	var c = (a + b) * 0.5
	var wc = chunk._wp(o, Vector3(c, chunk.ceil_h / 2.0, side), yw)
	var wl = chunk._mbox(chunk, wc, Vector3(ln, chunk.ceil_h, 0.16),
		Mats.hall_wallpaper_variant(chunk._finish_variant()))
	wl.rotation.y = yw
	chunk._collider_yaw_box(wc, Vector3(ln, chunk.ceil_h, 0.16), yw)
	var inn = side - signf(side) * 0.11
	for spec in [[0.075, 0.15, 0.055, Mats.darkwood()],
		[1.0, 0.08, 0.04, Mats.darkwood()],
		[chunk.ceil_h - 0.05, 0.1, 0.05, Mats.crown()]]:
		var tr = chunk._mbox(chunk, chunk._wp(o, Vector3(c, spec[0], inn), yw),
			Vector3(ln, spec[1], spec[2]), spec[3])
		tr.rotation.y = yw


func _hall_header(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var hh = chunk.ceil_h - chunk.DOOR_TOP
	if hh <= 0.02:
		return
	var hp = chunk._wp(o, Vector3(t, chunk.DOOR_TOP + hh * 0.5, side), yw)
	var hmesh = chunk._mbox(chunk, hp, Vector3(width, hh, 0.16),
		Mats.hall_wallpaper_variant(chunk._finish_variant()))
	hmesh.rotation.y = yw
	chunk._collider_yaw_box(hp, Vector3(width, hh, 0.16), yw)


## The recess connecting the narrow lane to a real canonical edge doorway.
## Its returns also compartmentalize the inaccessible guest-room strip.


func _hall_bay_returns(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var outer = signf(side) * (chunk.S * 0.5 - chunk.T)
	var depth = absf(outer - side)
	var dc = (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp = chunk._wp(o, Vector3(edge, chunk.ceil_h * 0.5, dc), yw)
		var ret = chunk._mbox(chunk, wp, Vector3(0.16, chunk.ceil_h, depth),
			Mats.hall_wallpaper_variant(chunk._finish_variant()))
		ret.rotation.y = yw
		chunk._collider_yaw_box(wp, Vector3(0.16, chunk.ceil_h, depth), yw)
	# Continue the runner into the doorway recess so it reads as intentional
	# circulation rather than a hole punched into the side of the corridor.
	var carpet = chunk._mbox(chunk, chunk._wp(o, Vector3(t, 0.014, dc), yw),
		Vector3(width, 0.028, depth), Mats.carpet_red())
	carpet.rotation.y = yw


func _hall_open_casing(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var inn = side - signf(side) * 0.11
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb = chunk._mbox(chunk, chunk._wp(o, Vector3(edge, chunk.DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, chunk.DOOR_TOP, 0.25), Mats.darkwood())
		jamb.rotation.y = yw
	var head = chunk._mbox(chunk, chunk._wp(o, Vector3(t, chunk.DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.25), Mats.darkwood())
	head.rotation.y = yw


func _hall_door(o: Vector3, yw: float, t: float, side: float, salt: int) -> void:
	var inn = side - signf(side) * 0.11
	var v = Node3D.new()
	v.position = chunk._wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	chunk.add_child(v)
	# A real slab in a real opening: rounded edges, deep jambs, panel moulding,
	# hinges and hardware.  Its collider seals the reserved room volume behind.
	chunk._mrbox(v, Vector3(0, 1.10, 0.0), Vector3(1.04, 2.2, 0.075), Mats.wood_door(), 0.018)
	for py in [0.58, 1.35]:
		chunk._mrbox(v, Vector3(0, py, 0.043), Vector3(0.72, 0.46, 0.018), Mats.darkwood(), 0.008)
		chunk._mrbox(v, Vector3(0, py, 0.054), Vector3(0.58, 0.33, 0.012), Mats.wood_door(), 0.006)
	chunk._mbox(v, Vector3(-0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	chunk._mbox(v, Vector3(0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	chunk._mbox(v, Vector3(0, 2.25, 0.0), Vector3(1.26, 0.12, 0.28), Mats.darkwood())
	for hy in [0.45, 1.7]:
		chunk._mbox(v, Vector3(-0.515, hy, 0.055), Vector3(0.035, 0.12, 0.025), Mats.brass())
	chunk._mbox(v, Vector3(0.36, 1.02, 0.058), Vector3(0.12, 0.22, 0.025), Mats.brass())
	chunk._msphere(v, Vector3(0.36, 1.02, 0.095), 0.045, Mats.brass())
	chunk._msphere(v, Vector3(0, 1.66, 0.09), 0.025, Mats.brass())
	chunk._collider_yaw_box(chunk._wp(o, Vector3(t, 1.1, inn), yw), Vector3(1.06, 2.2, 0.11), yw)
	var num = Label3D.new()
	num.text = "%d%02d" % [10 + WorldGen.h(chunk.wseed, chunk.cell.x + int(t * 3.0), chunk.cell.y, salt) % 20,
		WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y + int(t * 5.0), salt + 1) % 100]
	num.font_size = 44
	num.pixel_size = 0.0018
	num.modulate = Color(0.85, 0.7, 0.4)
	num.position = Vector3(0, 1.98, 0.09)
	v.add_child(num)
	if chunk._r(salt + 2) < 0.22:
		chunk._mcyl(v, Vector3(0.72, 0.025, 0.35), 0.16, 0.03, Mats.chrome())
		chunk._msphere(v, Vector3(0.72, 0.075, 0.35), 0.09, Mats.chrome())


# --- vegas: lounge -----------------------------------------------------------


func _lounge() -> void:
	# a pair of real Victorian sofas facing off over a real coffee table
	chunk._cc0_prop("sofa_03", Vector3(6, 0, 4.6), 0.0)
	chunk._collider_box(Vector3(6, 0.55, 4.6), Vector3(2.75, 1.1, 0.95))
	chunk._cc0_prop("sofa_03", Vector3(6, 0, 7.4), PI)
	chunk._collider_box(Vector3(6, 0.55, 7.4), Vector3(2.75, 1.1, 0.95))
	chunk._cc0_prop("CoffeeTable_01", Vector3(6, 0, 6), 0.0)
	chunk._collider_box(Vector3(6, 0.27, 6), Vector3(1.55, 0.54, 1.0))
	if chunk._r(26) < 0.55:
		var ay = -PI * 0.75 + (chunk._r(27) - 0.5) * 0.4
		chunk._cc0_prop("ArmChair_01", Vector3(8.9, 0, 8.7), ay)
		chunk._collider_yaw_box(Vector3(8.9, 0.55, 8.7), Vector3(0.9, 1.1, 0.8), ay)
		if chunk._r(28) < 0.5:
			chunk._cc0_prop("Ottoman_01", Vector3(8.1, 0, 7.8), ay + (chunk._r(29) - 0.5) * 0.8)
			chunk._collider_box(Vector3(8.1, 0.3, 7.8), Vector3(0.9, 0.62, 0.65))
	var lp = Vector3(3.4, 0, 6.0)
	chunk._cyl(lp + Vector3(0, 0.8, 0), 0.035, 1.6, Mats.brass(), false)
	chunk._cyl(lp + Vector3(0, 1.68, 0), 0.21, 0.28, Mats.shade(), false)
	chunk._sphere(lp + Vector3(0, 1.55, 0), 0.07, Mats.bulb())
	chunk._collider_cyl(lp + Vector3(0, 0.9, 0), 0.24, 1.8)
	if chunk._r(25) < 0.5:
		chunk._planter(Vector3(9.2, 0, 9.2))
	# muffled PA muzak drifting from the lounge ceiling
	var mz = AudioStreamPlayer3D.new()
	mz.stream = SoundBank.muzak()
	mz.unit_size = 4.0
	mz.max_distance = 24.0
	mz.volume_db = -14.0
	mz.bus = SoundBank.HALL_BUS
	mz.position = Vector3(chunk.S / 2.0, chunk.ceil_h - 0.3, chunk.S / 2.0)
	chunk.add_child(mz)
	mz.ready.connect(func(): mz.play(randf() * 11.0))


## Was seven rounded boxes and two tilted cushions, which read as upholstered
## geometry rather than as a sofa. `sofa_03` was already in the project and
## already used elsewhere, so this was only ever a missing call.


func _sofa(center: Vector3, face: float) -> void:
	var yaw = 0.0 if face > 0.0 else PI
	chunk._cc0_prop("sofa_03", center, yaw)
	chunk._collider_box(center + Vector3(0, 0.55, 0), Vector3(2.74, 1.10, 0.95))


func _casino_service_cart(p: Vector3, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = chunk._r(salt) * TAU
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, 0.76, 0), Vector3(1.05, 0.07, 0.56), Mats.darkwood(), 0.025)
	chunk._mrbox(v, Vector3(0, 0.28, 0), Vector3(0.92, 0.045, 0.46), Mats.darkwood(), 0.018)
	for sx in [-0.44, 0.44]:
		for sz in [-0.20, 0.20]:
			chunk._mcyl(v, Vector3(sx, 0.40, sz), 0.018, 0.72, Mats.brass())
			chunk._mcyl(v, Vector3(sx, 0.055, sz), 0.055, 0.05, Mats.charcoal())
	# Two glasses, one bottle, and a plate left slightly off square.
	for gx in [-0.22, 0.10]:
		chunk._mcyl(v, Vector3(gx, 0.84, -0.06), 0.045, 0.13, Mats.glass_tint())
		chunk._mcyl(v, Vector3(gx, 0.92, -0.06), 0.065, 0.018, Mats.glass_tint())
	chunk._mcyl(v, Vector3(0.32, 0.91, 0.08), 0.045, 0.28, Mats.glass_tint())
	chunk._mcyl(v, Vector3(-0.08, 0.805, 0.12), 0.18, 0.025, Mats.crown())
	chunk._collider_yaw_box(p + Vector3(0, 0.42, 0), Vector3(1.08, 0.84, 0.6), v.rotation.y)


## Archive boxes and loose forms occupy a corner of some otherwise empty
## offices. The pile is broad enough to read, low enough not to become a wall.
