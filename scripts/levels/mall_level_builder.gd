extends "res://scripts/levels/chunk_level_builder.gd"


func _mall_payphone_bank(dir: int, count: int) -> void:
	var facing = chunk._wall_facing(dir)
	# Wall art mounts on the centre of a run, so a bank placed there ends up
	# shoulder to shoulder with a poster. Sit it well off to one side.
	var along = 3.3 if chunk._r(1641 + dir) < 0.5 else 8.7
	var origin = chunk._wall_pt(dir, along, 0.0)
	var pv = Node3D.new()
	pv.position = origin
	pv.rotation.y = facing
	chunk.add_child(pv)
	# The authored housing is 0.74m tall about its own mounting plane, so a
	# 1.38m mount cut it in half on the mall's 1.21m brass rail — the same
	# fault the wall art was moved for. Lift it so the bottom of the housing
	# clears the rail by the shared margin instead of straddling it.
	var mount = 1.38
	var band = chunk._wall_band_top()
	if band > 0.0:
		mount = maxf(mount,
			band + chunk.WALL_BAND_CLEAR + chunk.MALL_PAYPHONE_DROP * chunk.MALL_PAYPHONE_SCALE)
	var span = 1.0
	for ph in count:
		var px = (float(ph) - float(count - 1) * 0.5) * span
		var authored = chunk._attributed_prop_local(pv, chunk.MALL_PAYPHONE_PATH,
			Vector3(px, mount, 0.0), 0.0,
			Vector3.ONE * chunk.MALL_PAYPHONE_SCALE)
		if authored != null:
			# The authored housing is its own backboard; the charcoal panel the
			# generated bank needed would only read as a slab behind it.
			authored.set_meta("authored_model", "payphone")
		else:
			chunk._mbox(pv, Vector3(px, 1.45, -0.25), Vector3(0.72, 0.85, 0.5),
				Mats.charcoal())
			chunk._mbox(pv, Vector3(px, 1.38, 0.08), Vector3(0.30, 0.44, 0.14),
				Mats.metal_gray())
			chunk._mbox(pv, Vector3(px - 0.11, 1.38, 0.15),
				Vector3(0.05, 0.24, 0.05), Mats.charcoal())
	# The authored housing stands 0.16m off the wall, not the half metre the
	# generated boxes needed; a deeper collider would stop the player short of
	# a wall they can see is flat.
	var forward = Vector3(sin(facing), 0, cos(facing))
	chunk._collider_yaw_box(origin + forward * 0.09 + Vector3(0, mount, 0),
		Vector3(span * float(count) - 0.1, 0.78, 0.20), facing)


## Freestanding concourse directory. The authored board is a readable front face
## with no base and blank sides, so the plinth and edge frame around it are
## generated — they carry the collision and hide the edges the source never
## modelled. The board's own five floors of listings do the rest.


func _mall_directory_pylon(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var pylon = chunk._furnishing_pivot(p, yaw, "mall_directory")
	var board = chunk._attributed_prop_local(pylon, chunk.MALL_DIRECTORY_PATH,
		Vector3(-chunk.MALL_DIRECTORY_CENTRE.x * chunk.MALL_DIRECTORY_SCALE, 0.42,
			-chunk.MALL_DIRECTORY_CENTRE.z * chunk.MALL_DIRECTORY_SCALE - 0.055),
		0.0, Vector3.ONE * chunk.MALL_DIRECTORY_SCALE)
	if board == null:
		# generated lightbox, as before the authored board existed
		chunk._mrbox(pylon, Vector3(0, 1.15, 0), Vector3(1.35, 2.3, 0.22),
			Mats.mall_trim(), 0.04)
		chunk._mbox(pylon, Vector3(0, 1.32, -0.115), Vector3(1.1, 1.55, 0.02),
			Mats.mall_sign_face())
	else:
		board.set_meta("authored_model", "mall_directory")
		# plinth, then a steel edge frame closing the blank sides and back
		chunk._mrbox(pylon, Vector3(0, 0.21, 0), Vector3(1.12, 0.42, 0.30),
			Mats.mall_trim(), 0.03)
		chunk._mrbox(pylon, Vector3(0, 1.30, 0.085), Vector3(1.06, 1.83, 0.09),
			Mats.mall_trim(), 0.02)
		for fx in [-0.515, 0.515]:
			chunk._mbox(pylon, Vector3(fx, 1.30, 0.02), Vector3(0.05, 1.83, 0.16),
				Mats.mall_trim())
		chunk._mbox(pylon, Vector3(0, 2.20, 0.02), Vector3(1.11, 0.06, 0.16),
			Mats.mall_trim())
		var dl = Label3D.new()
		dl.text = "DIRECTORY"
		dl.font_size = 52
		dl.pixel_size = 0.0019
		dl.modulate = Color(0.32, 0.28, 0.24)
		dl.position = Vector3(0, 2.31, -0.07)
		pylon.add_child(dl)
	chunk._collider_yaw_box(p + Vector3(0, 1.15, 0), Vector3(1.2, 2.3, 0.34), yaw)
	chunk._bind_furnishing_colliders(pylon, b0)


## Bank of steel filing cabinets, one drawer always left open.


func _mall_lighting() -> void:
	var dead = chunk.cell != Vector2i.ZERO and chunk._r(1600) < 0.10
	var flicker = not dead and chunk.cell != Vector2i.ZERO and chunk._r(1601) < 0.14
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.mall_panel()
	if flicker:
		lens = Mats.mall_panel().duplicate()
	var cor = chunk.style == WorldGen.MALL_CORRIDOR
	var cdir = WorldGen.corridor(chunk.wseed, chunk.cell)
	if cor:
		var along_x = cdir != 2
		for t in [-4.2, -1.4, 1.4, 4.2]:
			var p = Vector3(6.0 + t, 0, 6.0) if along_x else Vector3(6.0, 0, 6.0 + t)
			chunk._troffer(p, Vector2(1.65, 0.24) if along_x else Vector2(0.24, 1.65),
				lens, Mats.mall_trim())
	else:
		for p in [Vector2(3.0, 3.0), Vector2(9.0, 3.0),
				Vector2(3.0, 9.0), Vector2(9.0, 9.0)]:
			chunk._troffer(Vector3(p.x, 0, p.y), Vector2(1.25, 0.3), lens, Mats.mall_trim())
	if dead:
		return
	var light = chunk._make_main_light(flicker, lens, 1.08 if cor else 1.22)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.omni_range = 13.5
	light.position = Vector3(6, chunk.ceil_h - 0.65, 6)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 8.0
	chunk.add_child(light)


func _mall_poster_case(dir: int, plane: float) -> void:
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var inner = plane + n * (chunk.T * 0.5 + 0.04)
	var along = lerpf(3.3, 8.7, chunk._r(1610 + dir))
	var pos = Vector3(inner, 1.65, along) if dir < 2 else Vector3(along, 1.65, inner)
	var frame_size = Vector3(0.10, 1.75, 1.14) if dir < 2 else Vector3(1.14, 1.75, 0.10)
	chunk._box(pos, frame_size, Mats.mall_trim(), false)
	var paper_pos = pos + (Vector3(n * 0.06, 0, 0) if dir < 2 else Vector3(0, 0, n * 0.06))
	var paper_size = Vector3(0.012, 1.58, 0.97) if dir < 2 else Vector3(0.97, 1.58, 0.012)
	chunk._box(paper_pos, paper_size,
		Mats.sch_chair(0.48 if chunk._r(1614 + dir) < 0.5 else 0.08), false)
	var out = Vector3(n, 0, 0) if dir < 2 else Vector3(0, 0, n)
	var art_pos = paper_pos + out * 0.006
	var yaw = (PI / 2.0 if n > 0.0 else -PI / 2.0) if dir < 2 \
		else (0.0 if n > 0.0 else PI)
	chunk._wall_art_mount(art_pos, yaw, dir, chunk._wall_art_path(1622 + dir * 9),
		Vector2(0.91, 1.50), 0.0)
	var glass_pos = paper_pos + out * 0.035
	chunk._box(glass_pos, paper_size, Mats.mall_glass(), false)


## A box on the room side of a wall. `off` is the distance from the wall's
## inner face to the box CENTRE, `along` the position down the wall, `w` its
## width along the wall, `h` height, `d` depth off the wall.


func _mall_storefront(dir: int, plane: float) -> void:
	for ui in 2:
		_mall_unit(dir, plane, 3.15 if ui == 0 else 8.85, 4.8, 1700 + ui * 40 + dir)
	# masonry pier between the two units
	chunk._sfb(dir, plane, 0.28, 6.0, 1.8, 0.9, 3.6, 0.56, Mats.mall_wall(), true)


func _mall_unit(dir: int, plane: float, uc: float, w: float, salt: int) -> void:
	var giv = WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt)
	var rs = WorldGen.hr01(giv, 1)
	var state = 0          # 0 shutter down, 1 three-quarters, 2 dead glass
	if rs > 0.55: state = 1
	if rs > 0.80: state = 2
	var top = minf(3.6, chunk.ceil_h - 0.05)
	var gt = top - 0.62    # glass / shutter head height under the fascia
	# end piers and soffit lid
	for side in [-1.0, 1.0]:
		chunk._sfb(dir, plane, 0.28, uc + side * (w / 2.0 - 0.10), top / 2.0,
			0.20, top, 0.56, Mats.mall_trim(), true)
	chunk._sfb(dir, plane, 0.30, uc, top + 0.03, w, 0.06, 0.60, Mats.mall_trim())
	# Sign fascia with the store's name on it. A painted board needs a dark
	# backing: the lightbox face is pale and faintly emissive, so it shows past
	# the artwork's own edges as two lit strips.
	var painted = _mall_painted_sign_index(giv)
	chunk._sfb(dir, plane, 0.28, uc, top - 0.29, w - 0.4, 0.50, 0.50,
		Mats.mall_sign_board() if painted >= 0 else Mats.mall_sign_face())
	_mall_unit_sign(dir, plane, uc, giv, top - 0.29, painted)
	# black interior behind whatever closes the front
	chunk._sfb(dir, plane, 0.24, uc, gt / 2.0, w - 0.5, gt, 0.44, Mats.charcoal())
	# floor bulkhead riser
	chunk._sfb(dir, plane, 0.47, uc, 0.175, w - 0.4, 0.35, 0.12, Mats.mall_trim())
	if state == 0:
		chunk._sfb(dir, plane, 0.50, uc, (0.06 + gt) / 2.0, w - 0.5, gt - 0.06, 0.05,
			Mats.mall_shutter())
		chunk._sfb(dir, plane, 0.50, uc, 0.10, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	elif state == 1:
		# stuck three-quarters down: a black gap breathes underneath
		chunk._sfb(dir, plane, 0.50, uc, (1.1 + gt) / 2.0, w - 0.5, gt - 1.1, 0.05,
			Mats.mall_shutter())
		chunk._sfb(dir, plane, 0.50, uc, 1.06, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	else:
		# dead glass over the dark: three bays, mullions, a push-bar door
		var bw = (w - 0.5) / 3.0
		for b in 3:
			var bc = uc - (w - 0.5) / 2.0 + bw * (float(b) + 0.5)
			chunk._sfb(dir, plane, 0.50, bc, 0.35 + (gt - 0.35) / 2.0, bw - 0.06,
				gt - 0.35, 0.02, Mats.mall_glass())
		for mx in [-1.5, -0.5, 0.5, 1.5]:
			chunk._sfb(dir, plane, 0.50, uc + mx * bw, gt / 2.0 + 0.175, 0.06,
				gt - 0.35, 0.07, Mats.mall_trim())
		chunk._sfb(dir, plane, 0.53, uc, 1.05, bw - 0.3, 0.05, 0.03, Mats.brass())
	# shutter housing above the head
	chunk._sfb(dir, plane, 0.44, uc, gt + 0.14, w - 0.4, 0.26, 0.30, Mats.charcoal())
	# one solid collider across the unit
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var p = plane + n * (chunk.T * 0.5 + 0.30)
	if dir < 2:
		chunk._collider_box(Vector3(p, top / 2.0, uc), Vector3(0.60, top, w))
	else:
		chunk._collider_box(Vector3(uc, top / 2.0, p), Vector3(w, top, 0.60))


## A painted fascia sign cropped from the CC BY-NC mall source, fitted to the
## generated fascia at the artwork's own aspect so it is never stretched.
##
## This is the single point where that noncommercial dependency enters the game.
## Delete this function and the `_mall_painted_sign` call in `_mall_unit_sign`
## and every storefront falls back to the generated MALL_NAMES lettering, with
## nothing else to unpick.
## Which painted fascia this unit gets, or -1 for generated lettering. Decided
## before the fascia is built, because the two want different backing — and the
## texture is confirmed present here so the dark board can never end up hosting
## the generated lettering, which would be unreadable on it.


func _mall_painted_sign_index(giv: int) -> int:
	if WorldGen.hr01(giv, 7) >= 0.55:
		return -1
	var index: int = giv % chunk.MALL_SIGN_FACES.size()
	if not ResourceLoader.exists(chunk.MALL_SIGN_DIR + "sign_%s.webp"
			% chunk.MALL_SIGN_FACES[index][0]):
		return -1
	return index


func _mall_painted_sign(dir: int, plane: float, uc: float, index: int,
		y: float) -> bool:
	var entry: Array = chunk.MALL_SIGN_FACES[index]
	var tex = load(chunk.MALL_SIGN_DIR + "sign_%s.webp" % entry[0]) as Texture2D
	if tex == null:
		return false
	var aspect: float = entry[1]
	# Fit to whichever bound binds first, never stretching the artwork.
	var h: float = minf(chunk.MALL_SIGN_MAX_H, chunk.MALL_SIGN_MAX_W / aspect)
	var w: float = h * aspect
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.86
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing's front face stands 0.665m off the plane. Anything
	# shallower than that has its lower half swallowed by the housing, which is
	# exactly the bug the generated lettering was moved to 0.70 to escape.
	var p = plane + n * (chunk.T * 0.5 + 0.70)
	var quad = MeshInstance3D.new()
	quad.mesh = chunk.QUAD
	quad.material_override = mat
	quad.scale = Vector3(w, h, 1.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if dir < 2:
		quad.position = Vector3(p, y, uc)
		quad.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		quad.position = Vector3(uc, y, p)
		quad.rotation.y = PI if dir == 2 else 0.0
	quad.set_meta("mall_painted_sign", entry[0])
	quad.set_meta("mall_sign_fit", Vector2(w, h))
	chunk.add_child(quad)
	return true


func _mall_unit_sign(dir: int, plane: float, uc: float, giv: int, y: float,
		painted = -1) -> void:
	if painted >= 0 and _mall_painted_sign(dir, plane, uc, painted, y):
		return
	var text: String = chunk.MALL_NAMES[giv % chunk.MALL_NAMES.size()]
	var lit = WorldGen.hr01(giv, 2) < 0.18
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing projects 0.665m from the wall. The old lettering sat
	# at 0.620m, so its lower strokes were literally behind that geometry.
	# Bring it to the actual front face and fit the full name to the fascia.
	var p = plane + n * (chunk.T * 0.5 + 0.70)
	var lab = Label3D.new()
	lab.text = text
	lab.font_size = 84
	var sign_font = ThemeDB.fallback_font
	var text_px = sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, lab.font_size).x
	var safe_world_width = 3.95
	lab.pixel_size = minf(0.0026, safe_world_width / maxf(text_px + 20.0, 1.0))
	lab.width = ceili(text_px + 24.0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.modulate = Color(1.0, 0.62, 0.42) if lit else Color(0.30, 0.26, 0.22)
	lab.outline_size = 0
	lab.set_meta("mall_store_sign", true)
	lab.set_meta("safe_world_width", safe_world_width)
	if dir < 2:
		lab.position = Vector3(p, y, uc)
		lab.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		lab.position = Vector3(uc, y, p)
		lab.rotation.y = PI if dir == 2 else 0.0
	chunk.add_child(lab)
	if lit:
		# the one sign down the gallery that still runs
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.36)
		l.light_energy = 0.55
		l.omni_range = 3.4
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 20.0
		l.distance_fade_length = 8.0
		l.position = lab.position + Vector3(n * 0.3, 0.1, 0) if dir < 2 \
			else lab.position + Vector3(0, 0.1, n * 0.3)
		chunk.add_child(l)


## Mall regression hook: storefront lettering must fit its fascia, and exit
## housings must overlap the solid wall above an opening rather than float
## below the lintel.


func _mall_sign(pos: Vector3, yaw: float, text: String, size = 0.12,
		suspended = true) -> Node3D:
	var v = chunk._furnishing_pivot(pos, yaw, "mall_sign", false)
	var sign_w = maxf(1.25, text.length() * 0.13)
	chunk._mrbox(v, Vector3.ZERO,
		Vector3(sign_w, 0.48, 0.08),
		Mats.mall_trim(), 0.03)
	# Directional signs are ceiling-hung in real malls. Two thin rods keep
	# these from reading as unexplained floating rectangles in tall galleries.
	var hanger_h = chunk.ceil_h - (pos.y + 0.24)
	if suspended and hanger_h > 0.10:
		for hx in [-sign_w * 0.34, sign_w * 0.34]:
			chunk._mcyl(v, Vector3(hx, 0.24 + hanger_h * 0.5, 0),
				0.015, hanger_h, Mats.brass())
	var lab = Label3D.new()
	lab.text = text
	lab.font_size = 72
	lab.pixel_size = 0.002
	lab.modulate = Color(0.92, 0.75, 0.48)
	lab.outline_size = 0
	lab.position = Vector3(0, 0, 0.05)
	v.add_child(lab)
	return v


## Authored wire shopping cart. The source handle is on local -Z while the old
## generated cart's handle was on +Z, so the model turns inside the placement
## pivot. Existing room yaws and loaded-cart contents therefore keep exactly
## the same architectural facing.


func _mall_shopping_cart(p: Vector3, yaw: float, loaded = false) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "mall_shopping_cart")
	v.set_meta("enrichment_prop", "shopping_cart")
	v.set_meta("mall_cart_loaded", loaded)
	var model_yaw = PI
	var source_centre = chunk.MALL_SHOPPING_CART_CENTRE.rotated(
		Vector3.UP, model_yaw)
	var authored = chunk._attributed_prop_local(v, chunk.MALL_SHOPPING_CART_PATH,
		-source_centre * chunk.MALL_SHOPPING_CART_SCALE, model_yaw,
		Vector3.ONE * chunk.MALL_SHOPPING_CART_SCALE)
	if authored == null:
		v.get_parent().remove_child(v)
		v.free()
		return
	v.set_meta("attributed_furnishing", "mall_shopping_cart")
	authored.set_meta("authored_model", "mall_shopping_cart")
	if loaded:
		chunk._cc0_prop_local(v, "long_life_food", Vector3(-0.10, 0.62, -0.04),
			0.18, 1.0)
		chunk._mrbox(v, Vector3(0.24, 0.68, 0.12), Vector3(0.26, 0.18, 0.32),
			Mats.box_white(), 0.02)
	chunk._collider_yaw_box(chunk._wp(p, Vector3(0, 0.51, 0), yaw),
		Vector3(0.68, 1.02, 1.05), yaw)
	chunk._bind_furnishing_colliders(v, b0)


## Slatted concourse bench. `yaw` is the direction the sitter faces, matching
## the authored model's local +Z.


func _mall_bench(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var pivot = chunk._attributed_floor_prop(chunk.CITY_BENCH_PATH, p, yaw,
		chunk.CITY_BENCH_SCALE, chunk.CITY_BENCH_CENTRE, "mall_bench", null, true)
	if pivot == null:
		_mrbox_bench_fallback(p, yaw)
		return
	# Collide the seat block only. The backrest is behind it and the cast-iron
	# ends are thin enough that a box around the whole footprint would read as
	# an invisible wall at the edges.
	chunk._collider_yaw_box(p + Vector3(0, 0.42, -0.1), Vector3(1.89, 0.85, 0.5), yaw)
	chunk._bind_furnishing_colliders(pivot, b0)


func _mrbox_bench_fallback(p: Vector3, yaw: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, 0.49, 0), Vector3(2.1, 0.16, 0.58), Mats.sch_desk(), 0.06)
	chunk._mrbox(v, Vector3(0, 0.92, -0.25), Vector3(2.1, 0.58, 0.12), Mats.sch_desk(), 0.04)
	for x in [-0.82, 0.82]:
		chunk._mbox(v, Vector3(x, 0.23, 0), Vector3(0.09, 0.46, 0.50), Mats.mall_trim())
	chunk._collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.1, 1.04, 0.62), yaw)


func _mall_corridor() -> void:
	var along_x = WorldGen.corridor(chunk.wseed, chunk.cell) != 2
	var yaw = 0.0 if along_x else PI / 2.0
	# seating island down the middle of the gallery: benches back-to-back
	_mall_bench(Vector3(6.0, 0, 7.35) if along_x else Vector3(7.35, 0, 6.0), yaw)
	if chunk._r(1634) < 0.7:
		_mall_bench(Vector3(6.0, 0, 6.55) if along_x else Vector3(6.55, 0, 6.0), yaw + PI)
	if chunk._r(1635) < 0.6:
		var bp = Vector3(3.6, 0, 6.95) if along_x else Vector3(6.95, 0, 3.6)
		if chunk._waste_bin(bp, chunk._r(1636) * TAU, "mall_bin") == null:
			# a mall bin: brick-red cylinder with a black swing lid
			var bin_b0 = chunk.body.get_child_count()
			var bin = chunk._furnishing_pivot(bp, 0.0, "mall_bin")
			chunk._mcyl(bin, Vector3(0, 0.42, 0), 0.30, 0.84, Mats.velvet_rust())
			chunk._mcyl(bin, Vector3(0, 0.89, 0), 0.26, 0.10, Mats.charcoal())
			chunk._collider_cyl(bp + Vector3(0, 0.45, 0), 0.32, 0.95)
			chunk._bind_furnishing_colliders(bin, bin_b0)
	if chunk._r(1630) < 0.72:
		var plant_pos = Vector3(2.1, 0, 4.4) if along_x else Vector3(4.4, 0, 2.1)
		chunk._planter(plant_pos)
	if chunk._r(1631) < 0.35:
		chunk._cc0_prop("WetFloorSign_01",
			Vector3(9.4, 0, 5.0) if along_x else Vector3(5.0, 0, 9.4), yaw, 0.9)
	var sign_p = Vector3(6.0, minf(3.35, chunk.ceil_h - 0.5), 5.1) if along_x \
		else Vector3(5.1, minf(3.35, chunk.ceil_h - 0.5), 6.0)
	_mall_sign(sign_p, yaw, chunk.MALL_NAMES[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 1632) % chunk.MALL_NAMES.size()])
	if chunk._r(1636) < 0.58:
		var cart_p = Vector3(8.8, 0, 2.3) if along_x \
			else Vector3(2.3, 0, 8.8)
		_mall_shopping_cart(cart_p, yaw + (chunk._r(1637) - 0.5) * 0.55,
			chunk._r(1638) < 0.28)
	# A pair of payphones on a solid concourse wall. Atriums are barely 2% of
	# mall cells, so a bank placed only there was effectively never seen; the
	# gallery is where anyone actually walks past one.
	if chunk._r(1639) < 0.42:
		for dir in 4:
			if _solid_wall(dir):
				_mall_payphone_bank(dir, 2)
				break


func _mall_display_table(p: Vector3, yaw: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mrbox(v, Vector3(0, 0.76, 0), Vector3(2.2, 0.12, 0.9), Mats.sch_white(), 0.035)
	for x in [-0.87, 0.87]:
		chunk._mbox(v, Vector3(x, 0.36, 0), Vector3(0.10, 0.72, 0.72), Mats.mall_trim())
	for i in 4:
		var x = -0.72 + float(i) * 0.48
		var col = Mats.sch_chair(WorldGen.r01(chunk.wseed, chunk.cell.x + i, chunk.cell.y, salt))
		chunk._mrbox(v, Vector3(x, 0.88, 0), Vector3(0.30, 0.11, 0.48), col, 0.03)
	chunk._collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.2, 1.04, 0.92), yaw)


func _solid_wall(dir: int) -> bool:
	return WorldGen.edge_info(chunk.wseed, chunk.cell, dir, chunk.theme)["wall"]


## Wall shelving for a raided retail unit: brackets, mostly-bare boards, the
## odd carton nobody wanted. Only on genuinely solid walls, so a run can
## never seal a doorway.


func _mall_shelves(dir: int, salt: int) -> void:
	if not _solid_wall(dir):
		return
	var v = Node3D.new()
	v.position = Vector3(6.0, 0, 6.0)
	v.rotation.y = chunk._yaw_for(dir)
	chunk.add_child(v)
	# local +z faces the wall: boards hang at z 5.42, run 7m along x
	for ux in [-3.5, -1.75, 0.0, 1.75, 3.5]:
		chunk._mbox(v, Vector3(ux, 1.1, 5.47), Vector3(0.05, 2.2, 0.05), Mats.mall_trim())
	for b in 4:
		var by = 0.42 + float(b) * 0.55
		chunk._mbox(v, Vector3(0, by, 5.36), Vector3(7.1, 0.04, 0.34), Mats.sch_white())
	for b2 in 3:
		if WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + b2), 3) < 0.4:
			var bx = lerpf(-3.2, 3.2, WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + b2), 4))
			chunk._mbox(v, Vector3(bx, 0.62 + float(b2) * 0.55, 5.36),
				Vector3(0.42, 0.30, 0.30), Mats.box_white())
	# A few recognisable pantry products among the anonymous cartons.
	for si in 2:
		if WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 20 + si), 8) < 0.72:
			var sx = -2.1 + float(si) * 3.9
			chunk._cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.99 + float(si) * 0.55, 5.15),
				PI + 0.08 * float(si), 0.9)
	chunk._collider_yaw_box(chunk._wp(Vector3(6, 0, 6), Vector3(0, 1.1, 5.42), chunk._yaw_for(dir)),
		Vector3(7.1, 2.2, 0.45), chunk._yaw_for(dir))


## A chrome garment rack, picked clean but for a few dark shapes.


func _mall_rack(p: Vector3, yaw: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	for sx in [-0.7, 0.7]:
		chunk._mcyl(v, Vector3(sx, 0.7, 0), 0.022, 1.4, Mats.chrome())
		chunk._mbox(v, Vector3(sx, 0.02, 0), Vector3(0.5, 0.04, 0.5), Mats.chrome())
	chunk._mcyl(v, Vector3(0, 1.38, 0), 0.018, 1.5, Mats.chrome()).rotation.z = PI / 2.0
	var ng = 1 + WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt) % 3
	for g in ng:
		var gx = lerpf(-0.55, 0.55, WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + g), 5))
		chunk._mbox(v, Vector3(gx, 0.98, 0), Vector3(0.34, 0.78, 0.06),
			Mats.fabric_charcoal())
	chunk._collider_yaw_box(p + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 0.55), yaw)


## Checkout counter with a dead register.


func _mall_counter(p: Vector3, yaw: float) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "mall_checkout_counter")
	v.set_meta("enrichment_prop", "CashRegister_01")
	chunk._mrbox(v, Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.75), Mats.mall_trim(), 0.05)
	chunk._mrbox(v, Vector3(0, 1.02, 0), Vector3(2.35, 0.06, 0.9), Mats.sch_white(), 0.02)
	chunk._cc0_prop_local(v, "CashRegister_01", Vector3(-0.58, 1.05, -0.02),
		PI, 0.78)
	# Receipt roll, card pad and a forgotten price gun.
	chunk._mrbox(v, Vector3(0.28, 1.11, -0.10), Vector3(0.24, 0.09, 0.22),
		Mats.charcoal(), 0.02)
	chunk._mbox(v, Vector3(0.69, 1.11, 0.05), Vector3(0.18, 0.12, 0.30),
		Mats.body_black())
	chunk._collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(2.35, 1.1, 0.9), yaw)
	chunk._bind_furnishing_colliders(v, b0)


func _mall_store() -> void:
	# a small unit stripped to the walls: shelving on every solid wall (up to
	# three), racks and a counter in the floor
	var runs = 0
	for d in 4:
		if runs >= 3:
			break
		if _solid_wall(d):
			_mall_shelves(d, 1644 + d)
			runs += 1
	_mall_display_table(Vector3(4.6, 0, 6.0), PI / 2.0, 1640)
	_mall_rack(Vector3(7.6, 0, 4.6), chunk._r(1646) * 0.5, 1647)
	_mall_rack(Vector3(7.2, 0, 7.6), PI / 2.0 + chunk._r(1648) * 0.5, 1649)
	_mall_counter(Vector3(3.4, 0, 9.6), PI)
	_mall_sign(Vector3(6.0, minf(3.15, chunk.ceil_h - 0.45), 1.0), PI,
		chunk.MALL_NAMES[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 1641) % chunk.MALL_NAMES.size()])
	if chunk._r(1642) < 0.55:
		chunk._cc0_prop("potted_plant_02", Vector3(2.1, 0, 9.4), chunk._r(1643) * TAU, 0.9)
	if chunk._r(1651) < 0.4:
		chunk._cc0_prop("wooden_crate_01", Vector3(9.6, 0, 9.3), chunk._r(1652) * TAU, 0.85)
	_mall_shopping_cart(Vector3(9.1, 0, 2.3), PI / 2.0 + chunk._r(1654) * 0.35,
		chunk._r(1655) < 0.5)


## Long low double-sided gondola shelving, the spine of a dead department
## store floor.


func _mall_gondola(p: Vector3, yaw: float, ln: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	chunk.add_child(v)
	chunk._mbox(v, Vector3(0, 0.07, 0), Vector3(ln, 0.14, 1.0), Mats.mall_trim())
	chunk._mbox(v, Vector3(0, 0.75, 0), Vector3(ln, 1.36, 0.16), Mats.mall_trim())
	for side in [-1.0, 1.0]:
		for b in 3:
			chunk._mbox(v, Vector3(0, 0.34 + float(b) * 0.44, side * 0.28),
				Vector3(ln, 0.035, 0.42), Mats.sch_white())
	var nb = WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt) % 4
	for i in nb:
		var bx = lerpf(-ln * 0.4, ln * 0.4, WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + i), 6))
		var side2 = -1.0 if WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + i), 7) < 0.5 else 1.0
		chunk._mbox(v, Vector3(bx, 0.52, side2 * 0.28), Vector3(0.4, 0.3, 0.3), Mats.box_white())
	for stock in 2:
		if WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt + 30 + stock), 4) < 0.7:
			var sx = -ln * 0.24 + float(stock) * ln * 0.48
			var sz = -0.29 if stock == 0 else 0.29
			chunk._cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.80 + float(stock) * 0.43, sz),
				0.0 if stock == 0 else PI, 0.78)
	chunk._collider_yaw_box(p + Vector3(0, 0.72, 0), Vector3(ln, 1.44, 1.0), yaw)


func _mall_anchor() -> void:
	for p in [Vector3(3, 0, 3), Vector3(9, 0, 3), Vector3(3, 0, 9), Vector3(9, 0, 9)]:
		chunk._cyl(p + Vector3(0, chunk.ceil_h * 0.5, 0), 0.26, chunk.ceil_h, Mats.mall_trim())
	# gondola rows down the sales floor, aisles between
	_mall_gondola(Vector3(6.0, 0, 4.3), 0, 5.2, 1660)
	_mall_gondola(Vector3(6.0, 0, 7.7), 0, 5.2, 1665)
	_mall_display_table(Vector3(6, 0, 1.9), 0, 1670)
	# checkout lane by one clear corner
	_mall_counter(Vector3(9.8, 0, 10.0), -PI / 2.0)
	_mall_sign(Vector3(6.0, minf(3.3, chunk.ceil_h - 0.4), 10.9), 0.0, "HOUSE & HOME")
	if chunk._r(1661) < 0.7:
		chunk._cc0_prop("sofa_03", Vector3(2.2, 0, 6.0), PI / 2.0, 0.85)
	if chunk._r(1662) < 0.5:
		_mall_rack(Vector3(2.6, 0, 9.7), chunk._r(1663) * TAU, 1664)
	# Keep the abandoned cart bank clear of the optional sofa grouping.
	_mall_shopping_cart(Vector3(9.8, 0, 2.0), PI - 0.18, true)
	if chunk._r(1666) < 0.65:
		_mall_shopping_cart(Vector3(8.55, 0, 2.0), PI + 0.12, false)


func _mall_food_table(p: Vector3, salt: int) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, 0.0, "mall_food_table")
	# The authored set arrives as a pedestal table with its two chairs already
	# pulled up to it, so the generated top, column and ring of stools go with
	# it. Its chairs sit along local Z, hence the free yaw.
	var set_yaw = chunk._r(salt + 3) * TAU
	# `v` already stands at `p`, so the set is placed at its origin. Passing
	# `p` again would put it at twice the distance from the chunk.
	var authored = chunk._attributed_floor_prop(chunk.FOOD_COURT_SET_PATH, Vector3.ZERO,
		set_yaw, chunk.FOOD_COURT_SET_SCALE, chunk.FOOD_COURT_SET_CENTRE,
		"mall_food_table", v)
	if authored != null:
		# One box on the set's own footprint rather than a cylinder around it:
		# the pair is half again as long as it is wide, so a circle would put
		# an invisible bubble either side of the table.
		chunk._collider_yaw_box(p + Vector3(0, 0.46, 0),
			Vector3(0.78, 0.92, 1.86), set_yaw)
	else:
		chunk._mcyl(v, Vector3(0, 0.72, 0), 0.72, 0.08, Mats.sch_white())
		chunk._mcyl(v, Vector3(0, 0.35, 0), 0.08, 0.7, Mats.mall_trim())
		chunk._collider_cyl(p + Vector3(0, 0.45, 0), 0.74, 0.9)
		for i in 3:
			var a = TAU * float(i) / 3.0 + chunk._r(salt) * 0.3
			var cp = p + Vector3(cos(a), 0, sin(a)) * 1.1
			var chair = chunk._cc0_prop("bar_chair_round_01", cp, -a + PI / 2.0, 0.85)
			chunk._adopt_local(v, chair)
			chunk._collider_cyl(cp + Vector3(0, 0.42, 0), 0.30, 0.84)
	# Trays, wax cups and collapsed takeout cartons leave a human-scale trace.
	# Both tops land within a centimetre of 0.76m, so the clutter sits on
	# either version without moving.
	if chunk._r(salt + 20) < 0.78:
		var tray_yaw = (chunk._r(salt + 21) - 0.5) * 0.5
		var tray = chunk._mrbox(v, Vector3(-0.12, 0.79, 0.10),
			Vector3(0.46, 0.035, 0.31), Mats.velvet_rust(), 0.018)
		tray.rotation.y = tray_yaw
		chunk._mcyl(v, Vector3(0.09, 0.91, 0.03), 0.045, 0.22, Mats.box_white())
		chunk._mrbox(v, Vector3(-0.16, 0.86, 0.12), Vector3(0.18, 0.10, 0.15),
			Mats.box_white(), 0.018)
	chunk._bind_furnishing_colliders(v, b0)


func _mall_foodcourt() -> void:
	# six bolted tables in ranks, an aisle down the middle
	for i in 6:
		var p = Vector3(2.9 + 3.1 * float(i % 3), 0, 3.6 + 4.6 * float(i / 3))
		_mall_food_table(p, 1680 + i)
	# the serving line: counter run and dead menu boxes on the first solid wall
	for d in [3, 2, 1, 0]:
		if not _solid_wall(d):
			continue
		var yw = chunk._yaw_for(d)
		var v = Node3D.new()
		v.position = Vector3(6.0, 0, 6.0)
		v.rotation.y = yw
		v.set_meta("mall_foodcourt_vendor", true)
		chunk.add_child(v)
		chunk._mrbox(v, Vector3(0, 0.62, 4.65), Vector3(7.4, 1.24, 0.8), Mats.mall_trim(), 0.05)
		chunk._mrbox(v, Vector3(0, 1.28, 4.65), Vector3(7.6, 0.08, 0.95), Mats.sch_white(), 0.02)
		# tray slide
		for tr in 3:
			chunk._mcyl(v, Vector3(0, 0.98, 4.14 - float(tr) * 0.055), 0.016, 7.2,
				Mats.chrome()).rotation.z = PI / 2.0
		# One coherent abandoned vendor, not three unrelated restaurant names
		# pasted over whatever storefronts happened to generate behind it.
		# A continuous fascia is fixed to the wall by end brackets; the three
		# lower panels are menu boards belonging to that same business.
		chunk._mrbox(v, Vector3(0, 2.72, 5.27),
			Vector3(7.05, 0.62, 0.16), Mats.mall_sign_face(), 0.035)
		for sx in [-3.42, 3.42]:
			chunk._mbox(v, Vector3(sx, 2.16, 5.34),
				Vector3(0.12, 1.55, 0.34), Mats.mall_trim())
		var brand = Label3D.new()
		brand.text = chunk.MALL_FOOD[
			WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 1690) % chunk.MALL_FOOD.size()]
		brand.font_size = 78
		var brand_font = ThemeDB.fallback_font
		var brand_px = brand_font.get_string_size(brand.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, brand.font_size).x
		brand.pixel_size = minf(0.0027, 5.8 / maxf(brand_px + 24.0, 1.0))
		brand.width = ceili(brand_px + 28.0)
		brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		brand.autowrap_mode = TextServer.AUTOWRAP_OFF
		brand.modulate = Color(0.34, 0.29, 0.24)
		brand.position = Vector3(0, 2.72, 5.175)
		brand.rotation.y = PI
		brand.set_meta("mall_foodcourt_brand", true)
		v.add_child(brand)
		for si in 3:
			var sx = -2.35 + float(si) * 2.35
			chunk._mrbox(v, Vector3(sx, 2.05, 5.25),
				Vector3(1.92, 0.72, 0.12), Mats.charcoal(), 0.025)
			for line_idx in 4:
				var line_w = lerpf(0.72, 1.45,
					WorldGen.hr01(WorldGen.h(chunk.wseed, chunk.cell.x + si,
						chunk.cell.y + line_idx, 1694), 2))
				chunk._mbox(v, Vector3(sx - 0.18, 2.25 - float(line_idx) * 0.14,
					5.178), Vector3(line_w, 0.025, 0.012),
					Mats.mall_sign_face())
				chunk._mbox(v, Vector3(sx + 0.68, 2.25 - float(line_idx) * 0.14,
					5.176), Vector3(0.16, 0.025, 0.012), Mats.brass())
		chunk._cc0_prop_local(v, "CashRegister_01",
			Vector3(2.85, 1.32, 4.40), PI, 0.68)
		v.set_meta("enrichment_prop", "CashRegister_01")
		chunk._collider_yaw_box(chunk._wp(Vector3(6, 0, 6), Vector3(0, 0.65, 4.65), yw),
			Vector3(7.6, 1.3, 0.95), yw)
		break
	# A stranded cart out on the seating floor, wheeled away from the line it
	# was never part of. Its awning clears the 4m gallery ceiling comfortably.
	if chunk._r(1696) < 0.55:
		var hp = Vector3(9.4, 0, 9.6)
		var hyaw = chunk._r(1697) * TAU
		if chunk._attributed_floor_prop(chunk.MALL_HOTDOG_PATH, hp, hyaw,
				chunk.MALL_HOTDOG_SCALE, chunk.MALL_HOTDOG_CENTRE, "hotdog_stand") != null:
			chunk._collider_yaw_box(hp + Vector3(0, 0.55, 0),
				Vector3(1.95, 1.10, 0.85), hyaw)
	if chunk._r(1688) < 0.65:
		chunk._cc0_prop("CoffeeCart_01", Vector3(10.1, 0, 2.3), PI * 0.5, 1.0)
		chunk._collider_yaw_box(Vector3(10.1, 0.65, 2.3), Vector3(1.8, 1.3, 0.85), PI * 0.5)
	# stacked chairs someone left in a corner
	if chunk._r(1689) < 0.5:
		for st in 3:
			chunk._cc0_prop("bar_chair_round_01", Vector3(1.5 + float(st) * 0.32, 0, 10.4),
				0.3 * float(st), 0.85)
	if chunk._r(1694) < 0.55:
		_mall_shopping_cart(Vector3(10.3, 0, 6.0),
			PI + (chunk._r(1695) - 0.5) * 0.45, false)


func _mall_atrium() -> void:
	# Spawn and portals own the centre. The dead fountain sits off-axis so the
	# first movement in this floor is always possible.
	var fc = Vector3(8.25, 0, 7.85)
	var fountain_b0 = chunk.body.get_child_count()
	var fountain = chunk._furnishing_pivot(fc, 0.0, "mall_fountain")
	chunk._mcyl(fountain, Vector3(0, 0.25, 0), 1.65, 0.50, Mats.marble_photo())
	chunk._mcyl(fountain, Vector3(0, 0.49, 0), 1.38, 0.08, Mats.mall_glass())
	chunk._mcyl(fountain, Vector3(0, 0.67, 0), 0.20, 0.36, Mats.brass())
	chunk._collider_cyl(fc + Vector3(0, 0.28, 0), 1.65, 0.56)
	# The former near-black puddle looked like polished plastic. A top-only
	# circular surface now uses the Poolrooms' animated refraction/ripples,
	# without adding a water collider or enabling Poolrooms wading behavior.
	var water := MeshInstance3D.new()
	water.mesh = _mall_fountain_water_disc(1.30, 64)
	water.material_override = Mats.mall_fountain_water()
	water.position = Vector3(0, 0.51, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("mall_fountain_water", true)
	water.set_meta("mall_fountain_water_radius", 1.30)
	water.set_meta("mall_fountain_water_visual_only", true)
	fountain.add_child(water)
	chunk._bind_furnishing_colliders(fountain, fountain_b0)
	chunk._planter(Vector3(2.2, 0, 8.8))
	_mall_bench(Vector3(3.2, 0, 3.0), PI / 4.0)
	_mall_bench(Vector3(8.25, 0, 5.3), PI)
	_mall_directory_pylon(Vector3(3.6, 0, 6.4), chunk._r(1710) * TAU)
	if _solid_wall(1):
		_mall_payphone_bank(1, 3)
	if chunk.ceil_h > 5.5:
		# False mezzanine: visible high above, deliberately not traversable.
		for side in [-1.0, 1.0]:
			chunk._box(Vector3(6, 3.45, 6 + side * 5.25), Vector3(11, 0.18, 0.70),
				Mats.mall_trim(), false)
			for i in 9:
				chunk._box(Vector3(1.6 + float(i) * 1.1, 3.9, 6 + side * 4.95),
					Vector3(0.045, 0.9, 0.045), Mats.brass(), false)
	if chunk._r(1718) < 0.72:
		_mall_shopping_cart(Vector3(9.8, 0, 2.2),
			-PI / 2.0 + (chunk._r(1719) - 0.5) * 0.35, chunk._r(1720) < 0.3)


func _mall_fountain_water_disc(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in maxi(segments, 12):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		# Reverse the XZ winding so the top face points +Y under back-face
		# culling. The shader derives ripple UVs from world position.
		for p in [Vector3.ZERO, p1, p0]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(
				p.x / (radius * 2.0) + 0.5,
				p.z / (radius * 2.0) + 0.5))
			st.add_vertex(p)
	return st.commit()


func _mall_service() -> void:
	chunk._cc0_prop("steel_frame_shelves_01", Vector3(9.4, 0, 6.0), -PI / 2.0, 0.1)
	chunk._collider_yaw_box(Vector3(9.4, 0.9, 6), Vector3(2.0, 1.8, 0.7), -PI / 2.0)
	for i in 4:
		var p = Vector3(2.2 + float(i % 2) * 1.1, 0, 7.5 + float(i / 2) * 1.0)
		chunk._cc0_prop("wooden_crate_01" if i % 2 == 0 else "plastic_crate_03",
			p, chunk._r(1690 + i) * TAU, 0.8)
	if chunk._r(1698) < 0.4:
		chunk._cc0_prop("trashbag", Vector3(8.8, 0, 2.0), chunk._r(1699) * TAU)
	chunk._cc0_floor_prop("hand_truck", Vector3(2.0, 0, 3.0),
		0.22, 0.92, "mall_service_hand_truck",
		Vector3(0.62, 1.32, 0.62), Vector3(0, 0.66, 0))
	chunk._cc0_floor_prop("industrial_storage_cart", Vector3(6.1, 0, 9.7),
		PI, 0.72, "mall_service_storage_cart",
		Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))
	if chunk._r(1701) < 0.75:
		chunk._cc0_floor_prop("metal_trash_can", Vector3(9.6, 0, 2.1),
			PI / 2.0, 0.68, "mall_service_refuse",
			Vector3(1.28, 0.64, 0.44), Vector3(-0.06, 0.32, 0))
	if chunk._r(1702) < 0.65:
		_mall_shopping_cart(Vector3(3.6, 0, 9.4), PI - 0.24, true)


## One island kiosk: counter ring, canopy on poles, a small name sign.


func _mall_kiosk(p: Vector3, yaw: float, salt: int) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, yaw, "mall_kiosk")
	chunk._mrbox(v, Vector3(0, 0.62, 0), Vector3(2.6, 1.24, 1.5), Mats.mall_trim(), 0.08)
	chunk._mrbox(v, Vector3(0, 1.28, 0), Vector3(2.85, 0.12, 1.75), Mats.sch_white(), 0.035)
	for cx in [-1.25, 1.25]:
		for cz in [-0.72, 0.72]:
			chunk._mcyl(v, Vector3(cx, 2.0, cz), 0.03, 1.5, Mats.brass())
	chunk._mrbox(v, Vector3(0, 2.82, 0), Vector3(3.1, 0.28, 2.0), Mats.mall_trim(), 0.06)
	var nm: String = chunk.MALL_NAMES[WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, salt) % chunk.MALL_NAMES.size()]
	for sside in [-1.0, 1.0]:
		var lab = Label3D.new()
		lab.text = nm
		lab.font_size = 56
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.34, 0.30, 0.25)
		lab.position = Vector3(0, 2.82, sside * 1.02)
		lab.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lab)
	chunk._cc0_prop_local(v, "CashRegister_01", Vector3(0.68, 1.34, -0.18),
		PI, 0.66)
	v.set_meta("enrichment_prop", "CashRegister_01")
	# A handful of boxed impulse items beneath the dead canopy.
	for pi in 4:
		var px = -0.82 + float(pi) * 0.42
		chunk._mrbox(v, Vector3(px, 1.43, 0.34), Vector3(0.26, 0.22, 0.18),
			Mats.sch_chair(chunk._r(salt + 10 + pi)), 0.025)
	chunk._collider_yaw_box(p + Vector3(0, 0.72, 0), Vector3(2.9, 1.44, 1.8), yaw)
	chunk._bind_furnishing_colliders(v, b0)


func _mall_kiosks() -> void:
	# abandoned islands strung down the concourse
	_mall_kiosk(Vector3(3.4, 0, 3.8), chunk._r(1720) * 0.4, 1721)
	_mall_kiosk(Vector3(8.4, 0, 8.2), PI / 2.0 + chunk._r(1722) * 0.4, 1723)
	if chunk._r(1724) < 0.5:
		_mall_kiosk(Vector3(8.8, 0, 3.0), chunk._r(1725) * TAU, 1726)
	_mall_bench(Vector3(2.8, 0, 8.6), PI / 2.0)
	if chunk._r(1727) < 0.5:
		chunk._planter(Vector3(5.9, 0, 10.2))


func _mall_cinema() -> void:
	var counter = Vector3(6, 0, 8.9)
	var counter_b0 = chunk.body.get_child_count()
	var cv = chunk._furnishing_pivot(counter, 0.0, "mall_cinema_counter")
	chunk._mrbox(cv, Vector3(0, 0.68, 0), Vector3(5.8, 1.36, 0.72),
		Mats.mall_trim(), 0.06)
	chunk._mbox(cv, Vector3(0, 1.1, -0.39), Vector3(5.4, 0.34, 0.035),
		Mats.mall_glass())
	for rx in [-1.65, 1.65]:
		chunk._cc0_prop_local(cv, "CashRegister_01", Vector3(rx, 1.39, -0.12),
			PI, 0.68)
	cv.set_meta("enrichment_prop", "CashRegister_01")
	chunk._collider_yaw_box(counter + Vector3(0, 0.7, 0), Vector3(5.8, 1.4, 0.78), 0)
	chunk._bind_furnishing_colliders(cv, counter_b0)
	# the marquee: navy brick surround, bulb rows, one bulb still blinking
	var marquee = chunk._furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_marquee", false)
	var surround = chunk._box(Vector3(6, 2.9, 9.55), Vector3(7.0, 1.7, 0.25),
		Mats.mall_brick(), false)
	chunk._adopt_local(marquee, surround)
	# Narrow pilasters bridge the concession counter to the heavy masonry
	# marquee. Without them the entire blue surround reads as a floating slab.
	for mx in [3.0, 9.0]:
		var pier = chunk._box(Vector3(mx, 1.70, 9.55), Vector3(0.22, 0.72, 0.25),
			Mats.mall_trim(), false)
		chunk._adopt_local(marquee, pier)
	var cinema_sign = _mall_sign(Vector3(6, 2.9, 9.38), PI,
		"CINEMAS  1-6", 0.16, false)
	chunk._adopt_local(marquee, cinema_sign)
	for bi in 14:
		var bx = 2.9 + float(bi % 7) * 1.05
		var by = 2.28 if bi < 7 else 3.52
		var bulb = chunk._sphere(Vector3(bx, by, 9.40), 0.045,
			Mats.bulb() if bi == 3 else Mats.chrome())
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk._adopt_local(marquee, bulb)
	# red carpet approach between velvet queue ropes
	chunk._box(Vector3(6, 0.015, 5.4), Vector3(2.2, 0.02, 6.4), Mats.carpet_red(), false)
	var queue_b0 = chunk.body.get_child_count()
	var queue = chunk._furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_queue")
	for i in 2:
		var rz = 3.2 + chunk.ROPE_BARRIER_PITCH * (float(i) + 0.5)
		for rx in [4.6, 7.4]:
			var barrier = chunk._rope_barrier(Vector3(rx, 0, rz), PI / 2.0,
				"mall_cinema_rope")
			if barrier != null:
				chunk._adopt_local(queue, barrier)
	chunk._bind_furnishing_colliders(queue, queue_b0)
	for x in [2.4, 9.6]:
		_mall_poster_stand(Vector3(x, 0, 2.0))
	if chunk._r(1734) < 0.72:
		chunk._cc0_floor_prop("metal_trash_can", Vector3(10.0, 0, 8.1),
			PI / 2.0, 0.64, "mall_cinema_refuse",
			Vector3(1.20, 0.60, 0.42), Vector3(-0.06, 0.30, 0))


func _mall_poster_stand(p: Vector3) -> void:
	var b0 = chunk.body.get_child_count()
	var v = chunk._furnishing_pivot(p, 0.0, "mall_poster_stand")
	chunk._mrbox(v, Vector3(0, 1.2, 0), Vector3(1.2, 2.1, 0.15),
		Mats.mall_trim(), 0.04)
	chunk._mbox(v, Vector3(0, 1.2, -0.09), Vector3(1.03, 1.9, 0.025),
		Mats.sch_chair(0.04 + chunk._r(1704) * 0.48))
	chunk._mrbox(v, Vector3(0, 0.05, 0), Vector3(1.38, 0.10, 0.52),
		Mats.mall_trim(), 0.025)
	chunk._collider_yaw_box(p + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.22), 0)
	chunk._bind_furnishing_colliders(v, b0)


# --- island prison -----------------------------------------------------------
