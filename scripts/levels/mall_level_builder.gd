extends "res://scripts/levels/chunk_level_builder.gd"

const MallPalm := preload("res://scripts/props/mall_palm.gd")
static var _painted_sign_materials: Array[StandardMaterial3D] = []
static var _fountain_meshes: Dictionary = {}

static func clear_runtime_cache() -> void:
	_painted_sign_materials.clear()
	_fountain_meshes.clear()
	MallPalm.clear_runtime_cache()


## Prepare finite gallery, shop-sign and poster families behind the floor fade.
static func prewarm_resources() -> void:
	Mats.mall_brick()
	for index in Chunk.MALL_SIGN_FACES.size():
		_painted_sign_material(index)
	for path in Chunk.POSTER_MALL:
		Mats.wall_art_texture(path)
	var holder := Node3D.new()
	for bays in range(1, 5):
		_attach_upper_gallery(holder, bays)
	holder.free()


static func _painted_sign_material(index: int) -> StandardMaterial3D:
	while _painted_sign_materials.size() < Chunk.MALL_SIGN_FACES.size():
		_painted_sign_materials.append(null)
	if _painted_sign_materials[index] != null:
		return _painted_sign_materials[index]
	var path := Chunk.MALL_SIGN_DIR + "sign_%s.webp" % Chunk.MALL_SIGN_FACES[index][0]
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.86
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_painted_sign_materials[index] = mat
	return mat


## Architectural modules use baked detail meshes, keeping repeated mouldings,
## joints and mullions to one draw per material rather than one per element.
func _mall_floor_ceiling() -> void:
	var service := ctx.style == WorldGen.MALL_SERVICE
	var floor_material: Material = Mats.concrete_floor() if service else Mats.mall_floor()
	if ctx.style == WorldGen.MALL_STORE: floor_material = Mats.mall_shop_floor()
	scene.box(Vector3(6, -0.15, 6), Vector3(12, 0.3, 12),
		floor_material)
	scene.box(Vector3(6, ctx.ceiling_height + 0.15, 6), Vector3(12, 0.3, 12), Mats.mall_ceiling())
	var architecture := Node3D.new()
	architecture.name = "MallArchitecture"
	architecture.set_meta("mall_architecture", true)
	scene.add_node(architecture)
	if service:
		# Back of house keeps exposed services and a plain concrete floor.
		architecture.position.y = ctx.ceiling_height
		ProceduralDetails.attach(architecture, "mall_service_ceiling_template", func(d: ProceduralDetails):
			for x in [2.5, 3.0]:
				d.tube(Vector3(x, -0.22, 0),
					Vector3(x, -0.22, 12), 0.055, Mats.mall_trim())
			for z in [1.5, 4.5, 7.5, 10.5]:
				d.box(Vector3(2.75, -0.32, z), Vector3(0.9, 0.06, 0.08), Mats.metal_gray())
		, true)
		return
	var along_x := WorldGen.corridor(ctx.world_seed, ctx.cell) != 2
	var cor := ctx.style == WorldGen.MALL_CORRIDOR
	var sky := ctx.style == WorldGen.MALL_ATRIUM and ctx.ceiling_height > 5.5
	var h := 0.0
	ProceduralDetails.attach(architecture, "mall_floor_inlays_%s_%s" % [along_x, cor], func(d: ProceduralDetails):
		# Flush stone ribbons and fine brass divider strips follow the public
		# gallery; cross galleries continue on the same twelve-metre grid.
		for t in [1.45, 10.55]:
			var p := Vector3(6, 0.006, t) if along_x else Vector3(t, 0.006, 6)
			var size := Vector3(12, 0.008, 0.44) if along_x else Vector3(0.44, 0.008, 12)
			d.box(p, size, Mats.mall_rose_stone())
			for offset in [-0.25, 0.25]:
				var q := p + (Vector3(0, 0.002, offset) if along_x else Vector3(offset, 0.002, 0))
				d.box(q, Vector3(12, 0.008, 0.022) if along_x else Vector3(0.022, 0.008, 12), Mats.mall_brass())
			var j := p + (Vector3(0, 0.001, 0.36) if along_x else Vector3(0.36, 0.001, 0))
			d.box(j, Vector3(12, 0.008, 0.12) if along_x else Vector3(0.12, 0.008, 12), Mats.mall_jade_stone())
		if not cor:
			for x in [1.45, 10.55]:
				d.box(Vector3(x, 0.006, 6), Vector3(0.44, 0.008, 8.66), Mats.mall_rose_stone())
				for side in [-0.25, 0.25]:
					d.box(Vector3(x + side, 0.008, 6), Vector3(0.022, 0.008, 8.66), Mats.mall_brass())
			# A diamond medallion is a flush inlay, never a platform.
			d.box(Vector3(6, 0.011, 6), Vector3(1.15, 0.009, 1.15), Mats.mall_jade_stone(), 0, Vector3(0, PI / 4, 0))
			d.box(Vector3(6, 0.016, 6), Vector3(0.88, 0.008, 0.88), Mats.mall_rose_stone(), 0, Vector3(0, PI / 4, 0))
	, true)
	# Public rooms keep a plain ceiling: a cross-room coffer grid cuts
	# through the corridor's fluorescent panels. The atrium laylight has
	# its own perimeter fixtures and can retain its fitted glazing frame.
	if not sky:
		return
	var ceiling := Node3D.new()
	ceiling.name = "MallCeilingModules"
	ceiling.position.y = ctx.ceiling_height
	architecture.add_child(ceiling)
	ProceduralDetails.attach(ceiling, "mall_atrium_laylight", func(d: ProceduralDetails):
		# Glazed laylight over the atrium, with three stepped perimeter frames.
		d.box(Vector3(6, h - 0.035, 6), Vector3(7.8, 0.04, 7.8), Mats.mall_skylight())
		for tier in 3:
			var span := 8.1 + float(tier) * 0.46
			var y := h - 0.14 - float(tier) * 0.16
			for side in [-1.0, 1.0]:
				d.box(Vector3(6 + side * span * 0.5, y, 6), Vector3(0.24, 0.20, span + 0.24), Mats.mall_wall())
				d.box(Vector3(6, y, 6 + side * span * 0.5), Vector3(span, 0.20, 0.24), Mats.mall_wall())
		for t in [2.1, 4.05, 6.0, 7.95, 9.9]:
			d.box(Vector3(t, h - 0.09, 6), Vector3(0.065, 0.12, 7.8), Mats.mall_trim())
			d.box(Vector3(6, h - 0.09, t), Vector3(7.8, 0.12, 0.065), Mats.mall_trim())
	, true)


## Segment-based finishes respect real openings and merged-room boundaries.
func _mall_wall_finish(dir: int, plane: float, from: float, to: float,
		y0: float, y1: float) -> void:
	if ctx.style == WorldGen.MALL_SERVICE: return
	var width := to - from
	if width < 0.08: return
	var c := (from + to) * 0.5
	if y0 <= 0.01:
		scene.surface_facing_box(dir, plane, 0.035, c, 0.61, width, 1.08, 0.055, Mats.mall_ceramic())
		scene.surface_facing_box(dir, plane, 0.068, c, 1.16, width, 0.065, 0.11, Mats.mall_rose_stone())
	if y1 >= ctx.ceiling_height - 0.01:
		scene.surface_facing_box(dir, plane, 0.11, c, y1 - 0.19, width, 0.30, 0.22, Mats.mall_wall())
		scene.surface_facing_box(dir, plane, 0.225, c, y1 - 0.34, width, 0.04, 0.03, Mats.mall_brass())
		if ctx.style == WorldGen.MALL_ATRIUM and y1 > 5.5 and width > 3.0:
			_mall_upper_gallery(dir, plane, c, width)


func _mall_storefront_detail(dir: int, plane: float, uc: float, w: float,
		gt: float, top: float, state: int) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var inner := plane + n * Chunk.T * 0.5
	var v := Node3D.new()
	v.position = Vector3(inner, 0, uc) if dir < 2 else Vector3(uc, 0, inner)
	v.rotation.y = scene.wall_facing(dir)
	v.set_meta("mall_storefront_detail", true)
	scene.add_node(v)
	ProceduralDetails.attach(v, "mall_shopfront_%.3f_%.3f_%d" % [w, top, state], func(d: ProceduralDetails):
		for side in [-1.0, 1.0]:
			var x: float = side * (w * 0.5 - 0.12)
			d.box(Vector3(x, top * 0.5, 0.51), Vector3(0.24, top, 0.16), Mats.mall_rose_stone(), 0.025)
			d.box(Vector3(x, 0.14, 0.51), Vector3(0.30, 0.28, 0.18), Mats.mall_jade_stone(), 0.025)
			d.box(Vector3(x - side * 0.15, gt * 0.5, 0.55), Vector3(0.04, gt, 0.06), Mats.mall_brass())
		d.box(Vector3(0, top + 0.065, 0.45), Vector3(w + 0.10, 0.15, 0.74), Mats.mall_wall(), 0.025)
		d.box(Vector3(0, top - 0.035, 0.74), Vector3(w, 0.028, 0.04), Mats.mall_brass())
		d.box(Vector3(0, 0.035, 0.60), Vector3(w - 0.30, 0.06, 0.32), Mats.mall_jade_stone(), 0.01)
	)
	if state < 2:
		var bottom := 0.15 if state == 0 else 1.14
		var blades: Array[Transform3D] = []
		for i in maxi(1,floori((gt-bottom)/0.085)):
			blades.append(Transform3D(Basis.from_scale(Vector3((w-0.53)/6.0,1,1)),
				Vector3(0,bottom+(float(i)+0.5)*0.085,0.553)))
		ProceduralDetails.attach_instances(v, "mall_shutter_blade_module", func(d: ProceduralDetails):
			d.box(Vector3.ZERO,Vector3(6.0,0.076,0.035),Mats.mall_shutter_slat(),0.009)
		, blades)
		var handles := Node3D.new()
		handles.position.y = bottom
		v.add_child(handles)
		ProceduralDetails.attach(handles, "mall_shutter_handles", func(d: ProceduralDetails):
			for x in [-0.5,0.5]:
				d.box(Vector3(x,0.16,0.58),Vector3(0.12,0.035,0.035),Mats.mall_brass(),0.009)
		, true)
	if state == 2:
		scene.model_box(v, Vector3(0, 1.57, 0.56), Vector3(0.58, 0.32, 0.014), Mats.mall_sign_face())
		_mall_lettering(v, "C L O S E D", Vector3(0, 1.61, 0.571), 0.00085, 0.50, 0, Color(0.2, 0.22, 0.18))
		_mall_lettering(v, "THANK YOU FOR VISITING", Vector3(0, 1.49, 0.572), 0.00030, 0.50, 0, Color(0.2, 0.22, 0.18))


func _mall_payphone_bank(dir: int, count: int) -> bool:
	var facing = scene.wall_facing(dir)
	# Retail wall decoration was built before room props. A storefront occupies
	# the run and leaves no honest place for a phone bank, so try another wall.
	var wall_fixture_roll := ctx.random01(40 + dir)
	if wall_fixture_roll < 0.52:
		return false
	# Poster cases use this exact deterministic position. Put the bank at the
	# farther endpoint, guaranteeing that the two fixtures never intersect.
	var along := 3.3 if ctx.random01(1641 + dir) < 0.5 else 8.7
	if wall_fixture_roll < 0.96:
		var poster_along := lerpf(3.3, 8.7, ctx.random01(1610 + dir))
		along = 3.3 if absf(poster_along - 3.3) > absf(poster_along - 8.7) else 8.7
	var origin = scene.wall_point(dir, along, 0.0)
	var pv = Node3D.new()
	pv.position = origin
	pv.rotation.y = facing
	pv.set_meta("mall_payphone_dir", dir)
	pv.set_meta("mall_payphone_along", along)
	scene.add_node(pv)
	# The cabinet overlays the brass rail like an installed wall fixture. This
	# puts the handset's visual centre just below the player's natural eye line.
	var mount := Chunk.MALL_PAYPHONE_MOUNT
	var span := 1.45
	pv.set_meta("mall_payphone_span", span)
	for ph in count:
		var px = (float(ph) - float(count - 1) * 0.5) * span
		var authored = scene.attributed_prop_local(pv, Chunk.MALL_PAYPHONE_PATH,
			Vector3(px, mount, 0.0), 0.0,
			Vector3.ONE * Chunk.MALL_PAYPHONE_SCALE)
		if authored != null:
			# The authored housing is its own backboard; the charcoal panel the
			# generated bank needed would only read as a slab behind it.
			authored.set_meta("authored_model", "payphone")
		else:
			scene.model_box(pv, Vector3(px, 1.45, -0.25), Vector3(0.72, 0.85, 0.5),
				Mats.charcoal())
			scene.model_box(pv, Vector3(px, 1.38, 0.08), Vector3(0.30, 0.44, 0.14),
				Mats.metal_gray())
			scene.model_box(pv, Vector3(px - 0.11, 1.38, 0.15),
				Vector3(0.05, 0.24, 0.05), Mats.charcoal())
	# The rebuilt handset and armored cord project 0.378m from the mounting
	# plane. Follow that visible depth instead of letting the player clip through
	# the new silhouette; the bank remains a single conservative wall collider.
	var forward = Vector3(sin(facing), 0, cos(facing))
	scene.collider_yaw_box(origin + forward * 0.19 + Vector3(0, mount + 0.258, 0),
		Vector3(span * float(maxi(count - 1, 0)) + 0.32, 0.80, 0.40), facing)
	return true


## Freestanding concourse directory. The authored board is a readable front face
## with no base and blank sides, so the plinth and edge frame around it are
## generated — they carry the collision and hide the edges the source never
## modelled. The board's own five floors of listings do the rest.


func _mall_directory_pylon(p: Vector3, yaw: float) -> void:
	var b0 = scene.collider_mark()
	var pylon = scene.furnishing_pivot(p, yaw, "mall_directory")
	var board = scene.attributed_prop_local(pylon, Chunk.MALL_DIRECTORY_PATH,
		Vector3(-Chunk.MALL_DIRECTORY_CENTRE.x * Chunk.MALL_DIRECTORY_SCALE, 0.42,
			-Chunk.MALL_DIRECTORY_CENTRE.z * Chunk.MALL_DIRECTORY_SCALE - 0.055),
		0.0, Vector3.ONE * Chunk.MALL_DIRECTORY_SCALE)
	if board == null:
		# generated lightbox, as before the authored board existed
		scene.model_rounded_box(pylon, Vector3(0, 1.15, 0), Vector3(1.35, 2.3, 0.22),
			Mats.mall_trim(), 0.04)
		scene.model_box(pylon, Vector3(0, 1.32, -0.115), Vector3(1.1, 1.55, 0.02),
			Mats.mall_sign_face())
	else:
		board.set_meta("authored_model", "mall_directory")
		# plinth, then a steel edge frame closing the blank sides and back
		scene.model_rounded_box(pylon, Vector3(0, 0.21, 0), Vector3(1.12, 0.42, 0.30),
			Mats.mall_trim(), 0.03)
		scene.model_rounded_box(pylon, Vector3(0, 1.30, 0.085), Vector3(1.06, 1.83, 0.09),
			Mats.mall_trim(), 0.02)
		for fx in [-0.515, 0.515]:
			scene.model_box(pylon, Vector3(fx, 1.30, 0.02), Vector3(0.05, 1.83, 0.16),
				Mats.mall_trim())
		scene.model_box(pylon, Vector3(0, 2.20, 0.02), Vector3(1.11, 0.06, 0.16),
			Mats.mall_trim())
		var dl = Label3D.new()
		dl.text = "DIRECTORY"
		dl.font_size = 52
		dl.pixel_size = 0.0019
		dl.modulate = Color(0.32, 0.28, 0.24)
		dl.position = Vector3(0, 2.31, -0.07)
		# The directory's authored face is on local -Z. Label3D faces +Z by
		# default, so the old header exposed its mirrored back above the panel.
		dl.rotation.y = PI
		dl.double_sided = false
		dl.set_meta("mall_directory_label", true)
		pylon.add_child(dl)
		# The CC model only paints its +Z face. This is a freestanding concourse
		# pylon, so its reverse cannot remain a glaring blank lightbox. Give local
		# -Z a restrained generated directory; all copy faces the same way as the
		# corrected header and stays depth-tested/single-sided.
		var reverse_rows := [
			"1   MAIN CONCOURSE",
			"2   DEPARTMENT STORES",
			"3   FOOD COURT",
			"4   CINEMAS",
			"5   PARKING",
		]
		for row_index in reverse_rows.size():
			var row := Label3D.new()
			row.text = reverse_rows[row_index]
			row.font_size = 38
			row.pixel_size = 0.00145
			row.width = 600
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.modulate = Color(0.20, 0.17, 0.13)
			row.position = Vector3(0, 1.83 - float(row_index) * 0.27, -0.20)
			row.rotation.y = PI
			row.double_sided = false
			row.set_meta("mall_directory_listing", row_index + 1)
			pylon.add_child(row)
	scene.collider_yaw_box(p + Vector3(0, 1.15, 0), Vector3(1.2, 2.3, 0.34), yaw)
	scene.bind_furnishing_colliders(pylon, b0)


## Bank of steel filing cabinets, one drawer always left open.


func _mall_lighting() -> void:
	var dead = ctx.cell != Vector2i.ZERO and ctx.random01(1600) < 0.10
	var flicker = not dead and ctx.cell != Vector2i.ZERO and ctx.random01(1601) < 0.14
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.mall_panel()
	if flicker:
		lens = Mats.mall_panel().duplicate()
	var cor = ctx.style == WorldGen.MALL_CORRIDOR
	var cdir = WorldGen.corridor(ctx.world_seed, ctx.cell)
	var source := Vector3(3.0, ctx.ceiling_height - 0.65, 3.0)
	if cor:
		var along_x = cdir != 2
		source = Vector3(4.6, ctx.ceiling_height - 0.65, 6.0) if along_x \
			else Vector3(6.0, ctx.ceiling_height - 0.65, 4.6)
		for t in [-4.2, -1.4, 1.4, 4.2]:
			var p = Vector3(6.0 + t, 0, 6.0) if along_x else Vector3(6.0, 0, 6.0 + t)
			scene.troffer(p, Vector2(1.65, 0.24) if along_x else Vector2(0.24, 1.65),
				lens, Mats.mall_trim())
	else:
		var inset := 1.1 if ctx.style == WorldGen.MALL_ATRIUM and ctx.ceiling_height > 5.5 else 3.0
		source.x = inset
		source.z = inset
		for p in [Vector2(inset, inset), Vector2(12 - inset, inset),
				Vector2(inset, 12 - inset), Vector2(12 - inset, 12 - inset)]:
			if ctx.style == WorldGen.MALL_FOODCOURT:
				var pendant_y := minf(3.35, ctx.ceiling_height - 0.55)
				_mall_pendant(Vector3(p.x, pendant_y, p.y), lens)
				source.y = pendant_y - 0.15
			else:
				scene.troffer(Vector3(p.x, 0, p.y), Vector2(1.25, 0.3), lens, Mats.mall_trim())
	if dead:
		return
	var light = scene.fixture_light(flicker, lens, 1.08 if cor else 1.22,
		source, "mall_troffer")
	light.light_color = Color(1.0, 0.88, 0.71)
	light.omni_range = 13.5
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 8.0
	scene.add_node(light)
	if ctx.style == WorldGen.MALL_ATRIUM and ctx.ceiling_height > 5.5:
		var skylight := OmniLight3D.new()
		skylight.position = Vector3(6, ctx.ceiling_height - 0.5, 6)
		skylight.light_color = Color(0.47, 0.69, 0.88)
		skylight.light_energy = 1.8
		skylight.omni_range = 11.0
		skylight.omni_attenuation = 0.65
		skylight.shadow_enabled = false
		skylight.distance_fade_enabled = true
		skylight.distance_fade_begin = 25.0
		skylight.distance_fade_length = 8.0
		skylight.set_meta("visible_source", "mall_laylight")
		scene.add_node(skylight)


func _mall_pendant(p: Vector3, lens: StandardMaterial3D) -> void:
	var v := Node3D.new()
	v.position = p
	scene.add_node(v)
	var drop := ctx.ceiling_height - p.y
	ProceduralDetails.attach(v, "mall_pendant_%.3f" % drop, func(d: ProceduralDetails):
		d.tube(Vector3(0, 0.08, 0), Vector3(0, drop, 0), 0.018, Mats.mall_brass())
		d.ring(Vector3(0, 0.01, 0), 0.42, 0.055, Mats.mall_brass())
		d.ring(Vector3(0, 0.12, 0), 0.32, 0.035, Mats.mall_trim())
	)
	scene.model_cylinder(v, Vector3(0, -0.035, 0), 0.40, 0.08, lens)


func _mall_poster_case(dir: int, plane: float) -> void:
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var inner = plane + n * (Chunk.T * 0.5 + 0.04)
	var along = lerpf(3.3, 8.7, ctx.random01(1610 + dir))
	var pos = Vector3(inner, 1.65, along) if dir < 2 else Vector3(along, 1.65, inner)
	var frame_size = Vector3(0.10, 1.75, 1.14) if dir < 2 else Vector3(1.14, 1.75, 0.10)
	scene.box(pos, frame_size, Mats.mall_trim(), false)
	var paper_pos = pos + (Vector3(n * 0.06, 0, 0) if dir < 2 else Vector3(0, 0, n * 0.06))
	var paper_size = Vector3(0.012, 1.58, 0.97) if dir < 2 else Vector3(0.97, 1.58, 0.012)
	scene.box(paper_pos, paper_size,
		Mats.sch_chair(0.48 if ctx.random01(1614 + dir) < 0.5 else 0.08), false)
	var out = Vector3(n, 0, 0) if dir < 2 else Vector3(0, 0, n)
	var art_pos = paper_pos + out * 0.006
	var yaw = (PI / 2.0 if n > 0.0 else -PI / 2.0) if dir < 2 \
		else (0.0 if n > 0.0 else PI)
	var cased := scene.wall_art_mount(art_pos, yaw, dir, scene.wall_art_path(1622 + dir * 9),
		Vector2(0.91, 1.50), 0.0)
	# The frame, paper and glass around this mount are intentional: the
	# overlap audit must not read the case as a fixture collision.
	cased.set_meta("wall_art_cased", true)
	var glass_pos = paper_pos + out * 0.035
	scene.box(glass_pos, paper_size, Mats.mall_glass(), false)


## A box on the room side of a wall. `off` is the distance from the wall's
## inner face to the box CENTRE, `along` the position down the wall, `w` its
## width along the wall, `h` height, `d` depth off the wall.


func _mall_storefront(dir: int, plane: float) -> void:
	for ui in 2:
		_mall_unit(dir, plane, 3.15 if ui == 0 else 8.85, 4.8, 1700 + ui * 40 + dir)
	# masonry pier between the two units
	scene.surface_facing_box(dir, plane, 0.28, 6.0, 1.8, 0.9, 3.6, 0.56, Mats.mall_wall(), true)


func _mall_unit(dir: int, plane: float, uc: float, w: float, salt: int) -> void:
	var giv = WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt)
	var rs = WorldGen.hr01(giv, 1)
	var state = 0          # 0 shutter down, 1 three-quarters, 2 dead glass
	if rs > 0.55: state = 1
	if rs > 0.80: state = 2
	var top = minf(3.6, ctx.ceiling_height - 0.22)
	var gt = top - 0.62    # glass / shutter head height under the fascia
	# end piers and soffit lid
	for side in [-1.0, 1.0]:
		scene.surface_facing_box(dir, plane, 0.28, uc + side * (w / 2.0 - 0.10), top / 2.0,
			0.20, top, 0.56, Mats.mall_trim(), true)
	scene.surface_facing_box(dir, plane, 0.30, uc, top + 0.03, w, 0.06, 0.60, Mats.mall_trim())
	# Sign fascia with the store's name on it. A painted board needs a dark
	# backing: the lightbox face is pale and faintly emissive, so it shows past
	# the artwork's own edges as two lit strips.
	var painted = _mall_painted_sign_index(giv)
	scene.surface_facing_box(dir, plane, 0.28, uc, top - 0.29, w - 0.4, 0.50, 0.50,
		Mats.mall_sign_board() if painted >= 0 else Mats.mall_sign_face())
	_mall_unit_sign(dir, plane, uc, giv, top - 0.29, painted)
	# black interior behind whatever closes the front
	scene.surface_facing_box(dir, plane, 0.24, uc, gt / 2.0, w - 0.5, gt, 0.44, Mats.charcoal())
	# floor bulkhead riser
	scene.surface_facing_box(dir, plane, 0.47, uc, 0.175, w - 0.4, 0.35, 0.12, Mats.mall_trim())
	var shutter: Node3D
	if state == 0:
		shutter = scene.surface_facing_box(dir, plane, 0.50, uc, (0.06 + gt) / 2.0, w - 0.5, gt - 0.06, 0.05,
			Mats.mall_shutter())
		shutter.set_meta("surface_wear_prop", "mall_shutter")
		scene.surface_facing_box(dir, plane, 0.50, uc, 0.10, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	elif state == 1:
		# stuck three-quarters down: a black gap breathes underneath
		shutter = scene.surface_facing_box(dir, plane, 0.50, uc, (1.1 + gt) / 2.0, w - 0.5, gt - 1.1, 0.05,
			Mats.mall_shutter())
		shutter.set_meta("surface_wear_prop", "mall_shutter")
		scene.surface_facing_box(dir, plane, 0.50, uc, 1.06, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	else:
		# dead glass over the dark: three bays, mullions, a push-bar door
		var bw = (w - 0.5) / 3.0
		var glazing: Node3D
		for b in 3:
			var bc = uc - (w - 0.5) / 2.0 + bw * (float(b) + 0.5)
			glazing = scene.surface_facing_box(dir, plane, 0.50, bc, 0.35 + (gt - 0.35) / 2.0, bw - 0.06,
				gt - 0.35, 0.02, Mats.mall_glass())
			glazing.set_meta("surface_wear_prop", "glazing")
		for mx in [-1.5, -0.5, 0.5, 1.5]:
			scene.surface_facing_box(dir, plane, 0.50, uc + mx * bw, gt / 2.0 + 0.175, 0.06,
				gt - 0.35, 0.07, Mats.mall_trim())
		scene.surface_facing_box(dir, plane, 0.53, uc, 1.05, bw - 0.3, 0.05, 0.03, Mats.brass())
	# shutter housing above the head
	scene.surface_facing_box(dir, plane, 0.44, uc, gt + 0.14, w - 0.4, 0.26, 0.30, Mats.charcoal())
	_mall_storefront_detail(dir, plane, uc, w, gt, top, state)
	# one solid collider across the unit
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	var p = plane + n * (Chunk.T * 0.5 + 0.30)
	if dir < 2:
		scene.collider_box(Vector3(p, top / 2.0, uc), Vector3(0.60, top, w))
	else:
		scene.collider_box(Vector3(uc, top / 2.0, p), Vector3(w, top, 0.60))


## An original painted sign face, fitted to the generated fascia at its authored
## aspect so it is never stretched. Missing artwork falls back to MALL_NAMES.
## Which painted fascia this unit gets, or -1 for generated lettering. Decided
## before the fascia is built, because the two want different backing — and the
## texture is confirmed present here so the dark board can never end up hosting
## the generated lettering, which would be unreadable on it.


func _mall_painted_sign_index(giv: int) -> int:
	if WorldGen.hr01(giv, 7) >= 0.55:
		return -1
	var index: int = giv % Chunk.MALL_SIGN_FACES.size()
	if not ResourceLoader.exists(Chunk.MALL_SIGN_DIR + "sign_%s.webp"
			% Chunk.MALL_SIGN_FACES[index][0]):
		return -1
	return index


func _mall_painted_sign(dir: int, plane: float, uc: float, index: int,
		y: float) -> bool:
	var entry: Array = Chunk.MALL_SIGN_FACES[index]
	var mat := _painted_sign_material(index)
	if mat == null:
		return false
	var aspect: float = entry[1]
	# Fit to whichever bound binds first, never stretching the artwork.
	var h: float = minf(Chunk.MALL_SIGN_MAX_H, Chunk.MALL_SIGN_MAX_W / aspect)
	var w: float = h * aspect
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing's front face stands 0.665m off the plane. Anything
	# shallower than that has its lower half swallowed by the housing, which is
	# exactly the bug the generated lettering was moved to 0.70 to escape.
	var p = plane + n * (Chunk.T * 0.5 + 0.70)
	var quad = MeshInstance3D.new()
	quad.mesh = Chunk.QUAD
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
	scene.add_node(quad)
	return true


func _mall_unit_sign(dir: int, plane: float, uc: float, giv: int, y: float,
		painted = -1) -> void:
	if painted >= 0 and _mall_painted_sign(dir, plane, uc, painted, y):
		return
	var text: String = Chunk.MALL_NAMES[giv % Chunk.MALL_NAMES.size()]
	var lit = WorldGen.hr01(giv, 2) < 0.18
	var n = -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing projects 0.665m from the wall. The old lettering sat
	# at 0.620m, so its lower strokes were literally behind that geometry.
	# Bring it to the actual front face and fit the full name to the fascia.
	var p = plane + n * (Chunk.T * 0.5 + 0.70)
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
	scene.add_node(lab)
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
		l.set_meta("visible_source", "lit_store_sign")
		scene.add_node(l)


## Mall regression hook: storefront lettering must fit its fascia, and exit
## housings must overlap the solid wall above an opening rather than float
## below the lintel.


func _mall_sign(pos: Vector3, yaw: float, text: String, size = 0.12,
		suspended = true) -> Node3D:
	var v = scene.furnishing_pivot(pos, yaw, "mall_sign", false)
	var sign_w = maxf(1.25, text.length() * 0.13)
	scene.model_rounded_box(v, Vector3.ZERO,
		Vector3(sign_w, 0.48, 0.08),
		Mats.mall_trim(), 0.03)
	# Directional signs are ceiling-hung in real malls. Two thin rods keep
	# these from reading as unexplained floating rectangles in tall galleries.
	var hanger_h = ctx.ceiling_height - (pos.y + 0.24)
	if suspended and hanger_h > 0.10:
		for hx in [-sign_w * 0.34, sign_w * 0.34]:
			scene.model_cylinder(v, Vector3(hx, 0.24 + hanger_h * 0.5, 0),
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


## Supplied shopping cart with the handle already on local +Z, matching the
## placement pivot's facing convention, so no turn is needed. Existing room
## yaws and loaded-cart contents therefore keep exactly the same facing.


func _mall_shopping_cart(p: Vector3, yaw: float, loaded = false) -> void:
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(p, yaw, "mall_shopping_cart")
	v.set_meta("enrichment_prop", "shopping_cart")
	v.set_meta("mall_cart_loaded", loaded)
	var model_yaw = 0.0
	var source_centre = Chunk.MALL_SHOPPING_CART_CENTRE.rotated(
		Vector3.UP, model_yaw)
	var authored = scene.attributed_prop_local(v, Chunk.MALL_SHOPPING_CART_PATH,
		-source_centre * Chunk.MALL_SHOPPING_CART_SCALE, model_yaw,
		Vector3.ONE * Chunk.MALL_SHOPPING_CART_SCALE)
	if authored == null:
		v.get_parent().remove_child(v)
		v.free()
		return
	v.set_meta("attributed_furnishing", "mall_shopping_cart")
	authored.set_meta("authored_model", "mall_shopping_cart")
	if loaded:
		scene.cc0_prop_local(v, "long_life_food", Vector3(-0.10, 0.62, -0.04),
			0.18, 1.0)
		scene.model_rounded_box(v, Vector3(0.12, 0.68, 0.12), Vector3(0.26, 0.18, 0.32),
			Mats.box_white(), 0.02)
	scene.collider_yaw_box(scene.world_point(p, Vector3(0, 0.51, 0), yaw),
		Vector3(0.58, 1.02, 1.05), yaw)
	scene.bind_furnishing_colliders(v, b0)


## Slatted concourse bench. `yaw` is the direction the sitter faces, matching
## the authored model's local +Z.


func _mall_bench(p: Vector3, yaw: float) -> void:
	var b0 = scene.collider_mark()
	var pivot = scene.attributed_floor_prop(Chunk.CITY_BENCH_PATH, p, yaw,
		Chunk.CITY_BENCH_SCALE, Chunk.CITY_BENCH_CENTRE, "mall_bench", null, true)
	if pivot == null:
		_mrbox_bench_fallback(p, yaw)
		return
	# Collide the seat block only. The backrest is behind it and the cast-iron
	# ends are thin enough that a box around the whole footprint would read as
	# an invisible wall at the edges.
	scene.collider_yaw_box(p + Vector3(0, 0.42, -0.1), Vector3(1.89, 0.85, 0.5), yaw)
	scene.bind_furnishing_colliders(pivot, b0)


func _mrbox_bench_fallback(p: Vector3, yaw: float) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	scene.add_node(v)
	scene.model_rounded_box(v, Vector3(0, 0.49, 0), Vector3(2.1, 0.16, 0.58), Mats.sch_desk(), 0.06)
	scene.model_rounded_box(v, Vector3(0, 0.92, -0.25), Vector3(2.1, 0.58, 0.12), Mats.sch_desk(), 0.04)
	for x in [-0.82, 0.82]:
		scene.model_box(v, Vector3(x, 0.23, 0), Vector3(0.09, 0.46, 0.50), Mats.mall_trim())
	scene.collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.1, 1.04, 0.62), yaw)


func _mall_corridor() -> void:
	var along_x = WorldGen.corridor(ctx.world_seed, ctx.cell) != 2
	var yaw = 0.0 if along_x else PI / 2.0
	# seating island down the middle of the gallery: benches back-to-back
	_mall_bench(Vector3(6.0, 0, 7.35) if along_x else Vector3(7.35, 0, 6.0), yaw)
	if ctx.random01(1634) < 0.7:
		_mall_bench(Vector3(6.0, 0, 6.55) if along_x else Vector3(6.55, 0, 6.0), yaw + PI)
	if ctx.random01(1635) < 0.6:
		var bp = Vector3(3.6, 0, 6.95) if along_x else Vector3(6.95, 0, 3.6)
		if scene.waste_bin(bp, ctx.random01(1636) * TAU, "mall_bin") == null:
			# a mall bin: brick-red cylinder with a black swing lid
			var bin_b0 = scene.collider_mark()
			var bin = scene.furnishing_pivot(bp, 0.0, "mall_bin")
			scene.model_cylinder(bin, Vector3(0, 0.42, 0), 0.30, 0.84, Mats.velvet_rust())
			scene.model_cylinder(bin, Vector3(0, 0.89, 0), 0.26, 0.10, Mats.charcoal())
			scene.collider_cylinder(bp + Vector3(0, 0.45, 0), 0.32, 0.95)
			scene.bind_furnishing_colliders(bin, bin_b0)
	if ctx.random01(1630) < 0.72:
		var plant_pos = Vector3(2.1, 0, 4.4) if along_x else Vector3(4.4, 0, 2.1)
		MallPalm.build(scene, plant_pos, ctx.random01(1631) * TAU)
	if ctx.random01(1631) < 0.35:
		scene.cc0_prop("WetFloorSign_01",
			Vector3(9.4, 0, 5.0) if along_x else Vector3(5.0, 0, 9.4), yaw, 0.9)
	var sign_p = Vector3(6.0, minf(3.35, ctx.ceiling_height - 0.5), 5.1) if along_x \
		else Vector3(5.1, minf(3.35, ctx.ceiling_height - 0.5), 6.0)
	_mall_sign(sign_p, yaw, "ORCHARD GALLERIA")
	if ctx.random01(1636) < 0.58:
		var cart_p = Vector3(8.8, 0, 2.3) if along_x \
			else Vector3(2.3, 0, 8.8)
		_mall_shopping_cart(cart_p, yaw + (ctx.random01(1637) - 0.5) * 0.55,
			ctx.random01(1638) < 0.28)
	# One payphone on a solid concourse wall. Keep the fixture common enough to
	# encounter while exploring, but never form the implausible side-by-side
	# banks that made an otherwise sparse prop feel duplicated.
	if ctx.random01(1639) < 0.85:
		for dir in 4:
			if _solid_wall(dir) and _mall_payphone_bank(dir, 1):
				break


func _mall_display_table(p: Vector3, yaw: float, salt: int) -> void:
	var mark = scene.collider_mark()
	var v = scene.attributed_floor_prop(Chunk.MALL_DISPLAY_PATH, p, yaw, 1.0,
		Vector3.ZERO, "mall_merchandise_display", null, true)
	if v != null:
		v.set_meta("merchandise_variant", salt)
		scene.collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.2, 1.04, 0.92), yaw)
		scene.bind_furnishing_colliders(v, mark)


func _solid_wall(dir: int) -> bool:
	return scene.edge_info(ctx.cell, dir)["wall"]


## Wall shelving for a raided retail unit: brackets, mostly-bare boards, the
## odd carton nobody wanted. Only on genuinely solid walls, so a run can
## never seal a doorway.


func _mall_shelves(dir: int, salt: int) -> void:
	if not _solid_wall(dir):
		return
	var v = Node3D.new()
	v.position = Vector3(6.0, 0, 6.0)
	v.rotation.y = scene.yaw_for(dir)
	scene.add_node(v)
	# local +z faces the wall: boards hang at z 5.42, run 7m along x
	for ux in [-3.5, -1.75, 0.0, 1.75, 3.5]:
		scene.model_box(v, Vector3(ux, 1.1, 5.47), Vector3(0.05, 2.2, 0.05), Mats.mall_trim())
	for b in 4:
		var by = 0.42 + float(b) * 0.55
		scene.model_box(v, Vector3(0, by, 5.36), Vector3(7.1, 0.04, 0.34), Mats.sch_white())
	ProceduralDetails.attach(v, "mall_wall_shelves_brackets_price_lips_710_034_v1", func(d: ProceduralDetails):
		for ux in [-3.25, -1.65, 0.0, 1.65, 3.25]:
			for by in [0.42, 0.97, 1.52, 2.07]:
				d.box(Vector3(ux, by - 0.07, 5.48), Vector3(0.06, 0.14, 0.18), Mats.mall_trim(), 0.008)
		for by in [0.42, 0.97, 1.52, 2.07]:
			d.box(Vector3(0, by + 0.025, 5.18), Vector3(7.08, 0.055, 0.025), Mats.sch_white(), 0.004)
	)
	for b2 in 3:
		if WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + b2), 3) < 0.4:
			var bx = lerpf(-3.2, 3.2, WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + b2), 4))
			scene.model_box(v, Vector3(bx, 0.62 + float(b2) * 0.55, 5.36),
				Vector3(0.42, 0.30, 0.30), Mats.box_white())
	# A few recognisable pantry products among the anonymous cartons.
	for si in 2:
		if WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + 20 + si), 8) < 0.72:
			var sx = -2.1 + float(si) * 3.9
			scene.cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.99 + float(si) * 0.55, 5.15),
				PI + 0.08 * float(si), 0.9)
	scene.collider_yaw_box(scene.world_point(Vector3(6, 0, 6), Vector3(0, 1.1, 5.42), scene.yaw_for(dir)),
		Vector3(7.1, 2.2, 0.45), scene.yaw_for(dir))


## White powder-coated retail rack with a shelf and deterministic outfits.


func _mall_rack(p: Vector3, yaw: float, salt: int) -> void:
	var ps = scene.prop_scene(Chunk.MALL_GARMENT_RACK_PATH)
	if ps == null:
		push_error("Missing authored mall garment rack: " + Chunk.MALL_GARMENT_RACK_PATH)
		return
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(p, yaw, "mall_garment_rack")
	var rack := ps.instantiate() as Node3D
	v.add_child(rack)
	rack.name = "GarmentRack"
	rack.set_meta("authored_asset", Chunk.MALL_GARMENT_RACK_PATH)
	var casual := WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt) % 2 == 1
	var remove_name := "ClothesFormal" if casual else "ClothesCasual"
	var remove_mesh := rack.find_child(remove_name, true, false)
	if remove_mesh != null:
		remove_mesh.get_parent().remove_child(remove_mesh)
		remove_mesh.free()
	v.set_meta("mall_garment_rack", true)
	v.set_meta("garment_style", "casual" if casual else "formal")
	scene.collider_yaw_box(p + Vector3(0, 0.97, 0), Vector3(1.60, 1.94, 0.64), yaw)
	scene.bind_furnishing_colliders(v, b0)


## Checkout counter with a dead register.


func _mall_counter(p: Vector3, yaw: float) -> void:
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(p, yaw, "mall_checkout_counter")
	v.set_meta("enrichment_prop", "CashRegister_01")
	scene.model_rounded_box(v, Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.75), Mats.mall_trim(), 0.05)
	scene.model_rounded_box(v, Vector3(0, 1.02, 0), Vector3(2.35, 0.06, 0.9), Mats.sch_white(), 0.02)
	ProceduralDetails.attach(v, "mall_checkout_counter_panel_toekick_lip_220_100_075_v1", func(d: ProceduralDetails):
		d.box(Vector3(0, 0.52, -0.381), Vector3(1.92, 0.68, 0.025), Mats.mall_trim(), 0.025)
		d.box(Vector3(0, 0.09, -0.39), Vector3(2.02, 0.18, 0.06), Mats.charcoal(), 0.012)
		d.box(Vector3(0, 1.045, -0.47), Vector3(2.32, 0.035, 0.08), Mats.sch_white(), 0.008)
	)
	scene.cc0_prop_local(v, "CashRegister_01", Vector3(-0.58, 1.05, -0.02),
		PI, 0.78)
	# Receipt roll, card pad and a forgotten price gun.
	scene.model_rounded_box(v, Vector3(0.28, 1.11, -0.10), Vector3(0.24, 0.09, 0.22),
		Mats.charcoal(), 0.02)
	scene.model_box(v, Vector3(0.69, 1.11, 0.05), Vector3(0.18, 0.12, 0.30),
		Mats.body_black())
	scene.collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(2.35, 1.1, 0.9), yaw)
	scene.bind_furnishing_colliders(v, b0)


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
	_mall_rack(Vector3(7.6, 0, 4.6), ctx.random01(1646) * 0.5, 1647)
	_mall_rack(Vector3(7.2, 0, 7.6), PI / 2.0 + ctx.random01(1648) * 0.5, 1649)
	_mall_counter(Vector3(3.4, 0, 9.6), PI)
	_mall_sign(Vector3(6.0, minf(3.15, ctx.ceiling_height - 0.45), 1.0), PI,
		Chunk.MALL_NAMES[WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 1641) % Chunk.MALL_NAMES.size()])
	if ctx.random01(1642) < 0.55:
		scene.cc0_prop("potted_plant_02", Vector3(2.1, 0, 9.4), ctx.random01(1643) * TAU, 0.9)
	if ctx.random01(1651) < 0.4:
		scene.cc0_prop("wooden_crate_01", Vector3(9.6, 0, 9.3), ctx.random01(1652) * TAU, 0.85)
	_mall_shopping_cart(Vector3(9.1, 0, 2.3), PI / 2.0 + ctx.random01(1654) * 0.35,
		ctx.random01(1655) < 0.5)


## Long low double-sided gondola shelving, the spine of a dead department
## store floor.


func _mall_gondola(p: Vector3, yaw: float, ln: float, salt: int) -> void:
	var v = Node3D.new()
	v.position = p
	v.rotation.y = yaw
	scene.add_node(v)
	scene.model_box(v, Vector3(0, 0.07, 0), Vector3(ln, 0.14, 1.0), Mats.mall_trim())
	scene.model_box(v, Vector3(0, 0.75, 0), Vector3(ln, 1.36, 0.16), Mats.mall_trim())
	for side in [-1.0, 1.0]:
		for b in 3:
			scene.model_box(v, Vector3(0, 0.34 + float(b) * 0.44, side * 0.28),
				Vector3(ln, 0.035, 0.42), Mats.sch_white())
	ProceduralDetails.attach(v, "mall_gondola_end_brackets_lips_ln" + str(ln), func(d: ProceduralDetails):
		for x in [-ln * 0.5 + 0.025, ln * 0.5 - 0.025]:
			d.box(Vector3(x, 0.71, 0), Vector3(0.05, 1.30, 0.92), Mats.mall_trim(), 0.012)
		for side in [-1.0, 1.0]:
			for by in [0.34, 0.78, 1.22]:
				d.box(Vector3(0, by + 0.025, side * 0.49), Vector3(ln - 0.06, 0.05, 0.025),
					Mats.sch_white(), 0.004)
				for x in [-ln * 0.42, 0.0, ln * 0.42]:
					d.box(Vector3(x, by - 0.06, side * 0.37), Vector3(0.05, 0.12, 0.14),
						Mats.mall_trim(), 0.006)
	)
	var nb = WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt) % 4
	for i in nb:
		var bx = lerpf(-ln * 0.4, ln * 0.4, WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + i), 6))
		var side2 = -1.0 if WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + i), 7) < 0.5 else 1.0
		scene.model_box(v, Vector3(bx, 0.52, side2 * 0.28), Vector3(0.4, 0.3, 0.3), Mats.box_white())
	for stock in 2:
		if WorldGen.hr01(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + 30 + stock), 4) < 0.7:
			var sx = -ln * 0.24 + float(stock) * ln * 0.48
			var sz = -0.29 if stock == 0 else 0.29
			scene.cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.80 + float(stock) * 0.43, sz),
				0.0 if stock == 0 else PI, 0.78)
	scene.collider_yaw_box(p + Vector3(0, 0.72, 0), Vector3(ln, 1.44, 1.0), yaw)


func _mall_anchor() -> void:
	for p in [Vector3(3, 0, 3), Vector3(9, 0, 3), Vector3(3, 0, 9), Vector3(9, 0, 9)]:
		scene.cylinder(p + Vector3(0, ctx.ceiling_height * 0.5, 0), 0.26, ctx.ceiling_height, Mats.mall_trim())
	# gondola rows down the sales floor, aisles between
	_mall_gondola(Vector3(6.0, 0, 4.3), 0, 5.2, 1660)
	_mall_gondola(Vector3(6.0, 0, 7.7), 0, 5.2, 1665)
	_mall_display_table(Vector3(6, 0, 1.9), 0, 1670)
	# checkout lane by one clear corner
	_mall_counter(Vector3(9.8, 0, 10.0), -PI / 2.0)
	_mall_sign(Vector3(6.0, minf(3.3, ctx.ceiling_height - 0.4), 10.9), 0.0, "HOUSE & HOME")
	if ctx.random01(1661) < 0.7:
		scene.cc0_prop("sofa_03", Vector3(2.2, 0, 6.0), PI / 2.0, 0.85)
	if ctx.random01(1662) < 0.5:
		_mall_rack(Vector3(2.6, 0, 9.7), ctx.random01(1663) * TAU, 1664)
	# Keep the abandoned cart bank clear of the optional sofa grouping.
	_mall_shopping_cart(Vector3(9.8, 0, 2.0), PI - 0.18, true)
	if ctx.random01(1666) < 0.65:
		_mall_shopping_cart(Vector3(8.55, 0, 2.0), PI + 0.12, false)


func _mall_food_table(p: Vector3, salt: int) -> void:
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(p, 0.0, "mall_food_table")
	# The authored set arrives as a pedestal table with its two chairs already
	# pulled up to it, so the generated top, column and ring of stools go with
	# it. Its chairs sit along local Z, hence the free yaw.
	var set_yaw = ctx.random01(salt + 3) * TAU
	# `v` already stands at `p`, so the set is placed at its origin. Passing
	# `p` again would put it at twice the distance from the chunk.
	var authored = scene.attributed_floor_prop(Chunk.FOOD_COURT_SET_PATH, Vector3.ZERO,
		set_yaw, Chunk.FOOD_COURT_SET_SCALE, Chunk.FOOD_COURT_SET_CENTRE,
		"mall_food_table", v)
	if authored != null:
		# One box on the set's own footprint rather than a cylinder around it:
		# the pair is half again as long as it is wide, so a circle would put
		# an invisible bubble either side of the table.
		scene.collider_yaw_box(p + Vector3(0, 0.46, 0),
			Vector3(0.78, 0.92, 1.86), set_yaw)
	else:
		scene.model_cylinder(v, Vector3(0, 0.72, 0), 0.72, 0.08, Mats.sch_white())
		scene.model_cylinder(v, Vector3(0, 0.35, 0), 0.08, 0.7, Mats.mall_trim())
		scene.collider_cylinder(p + Vector3(0, 0.45, 0), 0.74, 0.9)
		for i in 3:
			var a = TAU * float(i) / 3.0 + ctx.random01(salt) * 0.3
			var cp = p + Vector3(cos(a), 0, sin(a)) * 1.1
			var chair = scene.cc0_prop("bar_chair_round_01", cp, -a + PI / 2.0, 0.85)
			scene.adopt_local(v, chair)
			scene.collider_cylinder(cp + Vector3(0, 0.42, 0), 0.30, 0.84)
	# Trays, wax cups and collapsed takeout cartons leave a human-scale trace.
	# Both tops land within a centimetre of 0.76m, so the clutter sits on
	# either version without moving.
	if ctx.random01(salt + 20) < 0.78:
		var tray_yaw = (ctx.random01(salt + 21) - 0.5) * 0.5
		var tray = scene.model_rounded_box(v, Vector3(-0.12, 0.79, 0.10),
			Vector3(0.46, 0.035, 0.31), Mats.velvet_rust(), 0.018)
		tray.rotation.y = tray_yaw
		scene.model_cylinder(v, Vector3(0.09, 0.91, 0.03), 0.045, 0.22, Mats.box_white())
		scene.model_rounded_box(v, Vector3(-0.16, 0.86, 0.12), Vector3(0.18, 0.10, 0.15),
			Mats.box_white(), 0.018)
	scene.bind_furnishing_colliders(v, b0)


func _mall_foodcourt() -> void:
	# six bolted tables in ranks, an aisle down the middle
	for i in 6:
		var p = Vector3(2.9 + 3.1 * float(i % 3), 0, 3.6 + 4.6 * float(i / 3))
		_mall_food_table(p, 1680 + i)
	# the serving line: counter run and dead menu boxes on the first solid wall
	for d in [3, 2, 1, 0]:
		if not _solid_wall(d):
			continue
		var yw = scene.yaw_for(d)
		var v = Node3D.new()
		v.position = Vector3(6.0, 0, 6.0)
		v.rotation.y = yw
		v.set_meta("mall_foodcourt_vendor", true)
		scene.add_node(v)
		var food_counter = scene.model_rounded_box(v, Vector3(0, 0.62, 4.65), Vector3(7.4, 1.24, 0.8), Mats.mall_trim(), 0.05)
		food_counter.set_meta("surface_wear_prop", "mall_food_counter")
		scene.model_rounded_box(v, Vector3(0, 1.28, 4.65), Vector3(7.6, 0.08, 0.95), Mats.sch_white(), 0.02)
		ProceduralDetails.attach(v, "mall_food_vendor_counter740_124_080_panels_toe_lip_v1", func(detail: ProceduralDetails):
			for x in [-2.45, 0.0, 2.45]:
				detail.box(Vector3(x, 0.64, 4.238), Vector3(2.14, 0.86, 0.025),
					Mats.mall_trim(), 0.025)
			# Glazed tile faces, stone cap and a ribbed, wall-mounted canopy.
			detail.box(Vector3(0, 0.65, 4.205), Vector3(7.15, 0.90, 0.03), Mats.mall_ceramic())
			detail.box(Vector3(0, 1.28, 4.60), Vector3(7.60, 0.08, 0.95), Mats.mall_rose_stone(), 0.02)
			detail.box(Vector3(0, 3.13, 4.98), Vector3(7.60, 0.22, 1.0), Mats.mall_wall(), 0.04)
			detail.box(Vector3(0, 3.00, 4.47), Vector3(7.62, 0.05, 0.05), Mats.mall_brass())
			for rib in 31:
				detail.box(Vector3(-3.6 + float(rib) * 0.24, 3.06, 4.45),
					Vector3(0.12, 0.21, 0.10), Mats.mall_trim(), 0.015)
			detail.box(Vector3(0, 0.10, 4.22), Vector3(7.10, 0.20, 0.06), Mats.charcoal(), 0.012)
			detail.box(Vector3(0, 1.315, 4.14), Vector3(7.55, 0.045, 0.09), Mats.sch_white(), 0.008)
		)
		# tray slide
		for tr in 3:
			scene.model_cylinder(v, Vector3(0, 0.98, 4.14 - float(tr) * 0.055), 0.016, 7.2,
				Mats.chrome()).rotation.z = PI / 2.0
		# One coherent abandoned vendor, not three unrelated restaurant names
		# pasted over whatever storefronts happened to generate behind it.
		# A continuous fascia is fixed to the wall by end brackets; the three
		# lower panels are menu boards belonging to that same business.
		scene.model_rounded_box(v, Vector3(0, 2.72, 5.27),
			Vector3(7.05, 0.62, 0.16), Mats.mall_sign_face(), 0.035)
		for sx in [-3.42, 3.42]:
			scene.model_box(v, Vector3(sx, 2.16, 5.34),
				Vector3(0.12, 1.55, 0.34), Mats.mall_trim())
		var brand = Label3D.new()
		brand.text = Chunk.MALL_FOOD[
			WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 1690) % Chunk.MALL_FOOD.size()]
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
			scene.model_rounded_box(v, Vector3(sx, 2.05, 5.25),
				Vector3(1.92, 0.72, 0.12), Mats.charcoal(), 0.025)
			_mall_lettering(v, ["F A V O U R I T E S", "L U N C H   S P E C I A L", "C O L D   D R I N K S"][si],
				Vector3(sx, 2.24, 5.178), 0.00065, 1.60, PI)
			_mall_lettering(v, ["CLASSIC COMBO   4.95\nSIDE ORDER   1.50\nEXTRA SAUCE   .25", "SERVED UNTIL 3 PM\nMEAL + DRINK   5.95\nKIDS MEAL   2.95", "FOUNTAIN SODA   .95\nFRESH LEMONADE   1.25\nICED TEA   .95"][si],
				Vector3(sx, 1.98, 5.178), 0.0005, 1.52, PI)
		scene.cc0_prop_local(v, "CashRegister_01",
			Vector3(2.85, 1.32, 4.40), PI, 0.68)
		v.set_meta("enrichment_prop", "CashRegister_01")
		scene.collider_yaw_box(scene.world_point(Vector3(6, 0, 6), Vector3(0, 0.65, 4.65), yw),
			Vector3(7.6, 1.3, 0.95), yw)
		break
	# A stranded cart out on the seating floor, wheeled away from the line it
	# was never part of. Its awning clears the 4m gallery ceiling comfortably.
	if ctx.random01(1696) < 0.55:
		var hp = Vector3(9.4, 0, 9.6)
		var hyaw = ctx.random01(1697) * TAU
		if scene.attributed_floor_prop(Chunk.MALL_HOTDOG_PATH, hp, hyaw,
				Chunk.MALL_HOTDOG_SCALE, Chunk.MALL_HOTDOG_CENTRE, "hotdog_stand") != null:
			scene.collider_yaw_box(hp + Vector3(0, 0.6, 0),
				Vector3(1.8, 1.2, 1.05), hyaw)
	if ctx.random01(1688) < 0.65:
		scene.cc0_prop("CoffeeCart_01", Vector3(10.1, 0, 2.3), PI * 0.5, 1.0)
		scene.collider_yaw_box(Vector3(10.1, 0.65, 2.3), Vector3(1.8, 1.3, 0.85), PI * 0.5)
	# stacked chairs someone left in a corner
	if ctx.random01(1689) < 0.5:
		for st in 3:
			scene.cc0_prop("bar_chair_round_01", Vector3(1.5 + float(st) * 0.32, 0, 10.4),
				0.3 * float(st), 0.85)
	if ctx.random01(1694) < 0.55:
		_mall_shopping_cart(Vector3(10.3, 0, 6.0),
			PI + (ctx.random01(1695) - 0.5) * 0.45, false)


func _mall_atrium() -> void:
	# Spawn and portals own the centre. The dead fountain sits off-axis so the
	# first movement in this floor is always possible.
	var fc = Vector3(8.25, 0, 7.85)
	var fountain_b0 = scene.collider_mark()
	var fountain = scene.furnishing_pivot(fc, 0.0, "mall_fountain")
	# Turned stone plinth, tiled basin and a wide bullnose coping. Every piece
	# remains inside the original 1.65m collision radius and 0.56m rim height.
	scene.model_cylinder(fountain, Vector3(0, 0.08, 0), 1.65, 0.16, Mats.mall_rose_stone())
	scene.model_cylinder(fountain, Vector3(0, 0.29, 0), 1.56, 0.36, Mats.mall_ceramic(true))
	scene.model_cylinder(fountain, Vector3(0, 0.45, 0), 1.36, 0.08, Mats.mall_jade_stone())
	var coping := MeshInstance3D.new()
	coping.mesh = _mall_lathe(PackedVector2Array([
		Vector2(1.32, 0.46), Vector2(1.32, 0.52), Vector2(1.36, 0.56),
		Vector2(1.61, 0.56), Vector2(1.65, 0.52), Vector2(1.65, 0.46), Vector2(1.32, 0.46)]))
	coping.material_override = Mats.mall_rose_stone()
	fountain.add_child(coping)
	# The dismantled central jet retains a tiered brass collar.
	scene.model_cylinder(fountain, Vector3(0, 0.67, 0), 0.20, 0.36, Mats.mall_brass())
	ProceduralDetails.attach(fountain, "mall_fountain_jet_collar_drain_r165_v1", func(d: ProceduralDetails):
		d.ring(Vector3(0, 0.87, 0), 0.10, 0.018, Mats.brass())
		d.ring(Vector3(0.82, 0.525, 0.28), 0.12, 0.012, Mats.charcoal())
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			d.box(Vector3(0.82 + cos(a) * 0.07, 0.528, 0.28 + sin(a) * 0.07),
				Vector3(0.018, 0.008, 0.018), Mats.charcoal(), 0.003)
	)
	scene.collider_cylinder(fc + Vector3(0, 0.28, 0), 1.65, 0.56)
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
	scene.bind_furnishing_colliders(fountain, fountain_b0)
	MallPalm.build(scene, Vector3(2.2, 0, 8.8), ctx.random01(1711) * TAU)
	_mall_bench(Vector3(3.2, 0, 3.0), PI / 4.0)
	_mall_bench(Vector3(8.25, 0, 5.3), PI)
	_mall_directory_pylon(Vector3(3.6, 0, 6.4), ctx.random01(1710) * TAU)
	for phone_dir in [1, 3, 0, 2]:
		if _solid_wall(phone_dir) and _mall_payphone_bank(phone_dir, 1):
			break
	if ctx.random01(1718) < 0.72:
		_mall_shopping_cart(Vector3(9.8, 0, 2.2),
			-PI / 2.0 + (ctx.random01(1719) - 0.5) * 0.35, ctx.random01(1720) < 0.3)


## Revolved architectural profile: a shared, smoothly rounded stone coping.
func _mall_lathe(profile: PackedVector2Array) -> ArrayMesh:
	var key := "lathe:" + str(profile)
	if _fountain_meshes.has(key): return _fountain_meshes[key]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(Mats.mall_rose_stone())
	for j in range(profile.size() - 1):
		var tangent := (profile[j + 1] - profile[j]).normalized()
		for i in 64:
			# Godot uses clockwise front faces: the geometric cross product
			# points opposite to the outward shading normal.
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
					Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var a := TAU * float(i + corner.x) / 64.0
				var p := profile[j + corner.y]
				surface.set_normal(Vector3(-cos(a) * tangent.y, tangent.x, -sin(a) * tangent.y))
				surface.set_uv(Vector2(float(i + corner.x) / 64.0, p.y))
				surface.add_vertex(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	var mesh := surface.commit()
	_fountain_meshes[key] = mesh
	return mesh


func _mall_upper_gallery(dir: int, plane: float, along: float, width: float) -> void:
	# Built with the actual wall segment, before furniture is relocated to the
	# centre of a merged room. This keeps upper galleries fixed to the shell.
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var inner := plane + n * Chunk.T * 0.5
	var v := Node3D.new()
	v.position = Vector3(inner, 0, along) if dir < 2 else Vector3(along, 0, inner)
	v.rotation.y = scene.wall_facing(dir)
	v.set_meta("mall_upper_gallery", true)
	scene.add_node(v)
	var actual_span := width - 0.12
	var bays := maxi(1, floori(actual_span / 2.4))
	v.scale.x = actual_span / (2.4 * float(bays))
	_attach_upper_gallery(v, bays)


static func _attach_upper_gallery(parent: Node3D, bays: int) -> void:
	var pitch := 2.4
	var span := pitch * float(bays)
	ProceduralDetails.attach(parent, "mall_upper_gallery_module_%d" % bays, func(d: ProceduralDetails):
		d.box(Vector3(0, 4.20, 0.38), Vector3(span, 0.28, 0.85), Mats.mall_wall(), 0.025)
		d.box(Vector3(0, 4.06, 0.80), Vector3(span, 0.045, 0.08), Mats.mall_brass())
		for b in bays:
			var x := -span * 0.5 + pitch * (float(b) + 0.5)
			d.box(Vector3(x, 5.64, 0.08), Vector3(pitch - 0.16, 2.0, 0.07), Mats.mall_trim())
			d.box(Vector3(x, 5.64, 0.125), Vector3(pitch - 0.32, 1.78, 0.035), Mats.mall_glass())
			d.box(Vector3(x, 4.76, 0.65), Vector3(pitch - 0.08, 0.77, 0.035), Mats.mall_glass())
		for b in bays + 1:
			var x := -span * 0.5 + pitch * float(b)
			d.box(Vector3(x, 4.80, 0.65), Vector3(0.06, 1.0, 0.07), Mats.mall_brass())
		d.tube(Vector3(-span * 0.5, 5.30, 0.65), Vector3(span * 0.5, 5.30, 0.65), 0.045, Mats.mall_brass())
	, true)


func _mall_lettering(parent: Node3D, text: String, p: Vector3, pixel: float,
		max_width: float, yaw := 0.0, color := Color(0.88, 0.82, 0.65)) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	label.pixel_size = minf(pixel, max_width / maxf(width, 1))
	label.width = ceili(width + 10)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.outline_size = 0
	label.double_sided = false
	label.modulate = color
	label.position = p
	label.rotation.y = yaw
	parent.add_child(label)
	return label


func _mall_fountain_water_disc(radius: float, segments: int) -> ArrayMesh:
	var key := "%s:%s" % [radius, segments]
	if _fountain_meshes.has(key):
		return _fountain_meshes[key]
	if _fountain_meshes.size() >= 64:
		_fountain_meshes.clear()
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
	var mesh := st.commit()
	_fountain_meshes[key] = mesh
	return mesh


func _mall_service() -> void:
	scene.cc0_prop("steel_frame_shelves_01", Vector3(9.4, 0, 6.0), -PI / 2.0, 0.1)
	scene.collider_yaw_box(Vector3(9.4, 0.9, 6), Vector3(2.0, 1.8, 0.7), -PI / 2.0)
	for i in 4:
		var p = Vector3(2.2 + float(i % 2) * 1.1, 0, 7.5 + float(i / 2) * 1.0)
		scene.cc0_prop("wooden_crate_01" if i % 2 == 0 else "plastic_crate_03",
			p, ctx.random01(1690 + i) * TAU, 0.8)
	if ctx.random01(1698) < 0.4:
		scene.cc0_prop("trashbag", Vector3(8.8, 0, 2.0), ctx.random01(1699) * TAU)
	scene.cc0_floor_prop("hand_truck", Vector3(2.0, 0, 3.0),
		0.22, 0.92, "mall_service_hand_truck",
		Vector3(0.62, 1.32, 0.62), Vector3(0, 0.66, 0))
	scene.cc0_floor_prop("industrial_storage_cart", Vector3(6.1, 0, 9.7),
		PI, 0.72, "mall_service_storage_cart",
		Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))
	if ctx.random01(1701) < 0.75:
		scene.cc0_floor_prop("metal_trash_can", Vector3(9.6, 0, 2.1),
			PI / 2.0, 0.68, "mall_service_refuse",
			Vector3(1.28, 0.64, 0.44), Vector3(-0.06, 0.32, 0))
	if ctx.random01(1702) < 0.65:
		_mall_shopping_cart(Vector3(3.6, 0, 9.4), PI - 0.24, true)


## One island kiosk: counter ring, canopy on poles, a small name sign.


func _mall_kiosk(p: Vector3, yaw: float, salt: int) -> void:
	var b0 = scene.collider_mark()
	var v = scene.attributed_floor_prop(Chunk.MALL_MERCHANDISE_PATH, p, yaw, 1.0,
		Vector3.ZERO, "mall_kiosk", null, true)
	if v == null:
		return
	v.set_meta("merchandise_variant", salt)
	# U-shaped shop island: preserve an accessible staff well through the rear.
	var basis = Basis(Vector3.UP, yaw)
	scene.collider_yaw_box(p + basis * Vector3(0, 0.575, 0.5945), Vector3(2.8, 1.15, 0.531), yaw)
	for sx in [-1.1345, 1.1345]:
		scene.collider_yaw_box(p + basis * Vector3(sx, 0.575, -0.2655), Vector3(0.531, 1.15, 1.189), yaw)
	scene.collider_yaw_box(p + basis * Vector3(-1.121, 0.925, -0.749), Vector3(0.44, 1.85, 0.07), yaw)
	scene.collider_yaw_box(p + basis * Vector3(0.9965, 1.345, -0.422), Vector3(0.31, 0.39, 0.34), yaw)
	scene.bind_furnishing_colliders(v, b0)


func _mall_kiosks() -> void:
	# abandoned islands strung down the concourse
	_mall_kiosk(Vector3(3.4, 0, 3.8), ctx.random01(1720) * 0.4, 1721)
	_mall_kiosk(Vector3(8.4, 0, 8.2), PI / 2.0 + ctx.random01(1722) * 0.4, 1723)
	if ctx.random01(1724) < 0.5:
		_mall_kiosk(Vector3(8.8, 0, 3.0), ctx.random01(1725) * TAU, 1726)
	_mall_bench(Vector3(2.8, 0, 8.6), PI / 2.0)
	if ctx.random01(1727) < 0.5:
		MallPalm.build(scene, Vector3(5.9, 0, 10.2), ctx.random01(1728) * TAU)


func _mall_cinema() -> void:
	var counter = Vector3(6, 0, 8.9)
	var counter_b0 = scene.collider_mark()
	var cv = scene.furnishing_pivot(counter, 0.0, "mall_cinema_counter")
	scene.model_rounded_box(cv, Vector3(0, 0.68, 0), Vector3(5.8, 1.36, 0.72),
		Mats.mall_trim(), 0.06)
	scene.model_box(cv, Vector3(0, 1.1, -0.39), Vector3(5.4, 0.34, 0.035),
		Mats.mall_glass())
	ProceduralDetails.attach(cv, "mall_cinema_counter580_136_072_panels_toe_lip_v1", func(d: ProceduralDetails):
		for x in [-1.9, 0.0, 1.9]:
			d.box(Vector3(x, 0.65, -0.371), Vector3(1.58, 0.78, 0.025), Mats.mall_trim(), 0.025)
		d.box(Vector3(0, 0.10, -0.38), Vector3(5.46, 0.20, 0.06), Mats.charcoal(), 0.012)
		d.box(Vector3(0, 1.37, -0.43), Vector3(5.72, 0.06, 0.12), Mats.sch_white(), 0.01)
		for rib in 43:
			d.box(Vector3(-2.7 + float(rib) * 0.129, 0.70, -0.40),
				Vector3(0.028, 1.04, 0.045), Mats.mall_brass(), 0.007)
	)
	_mall_lettering(cv, "T I C K E T S", Vector3(0, 0.91, -0.441), 0.0016, 1.50, PI)
	for rx in [-1.65, 1.65]:
		scene.cc0_prop_local(cv, "CashRegister_01", Vector3(rx, 1.39, -0.12),
			PI, 0.68)
	cv.set_meta("enrichment_prop", "CashRegister_01")
	scene.collider_yaw_box(counter + Vector3(0, 0.7, 0), Vector3(5.8, 1.4, 0.78), 0)
	scene.bind_furnishing_colliders(cv, counter_b0)
	# the marquee: navy brick surround, bulb rows, one bulb still blinking
	var marquee = scene.furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_marquee", false)
	var surround = scene.box(Vector3(6, 2.9, 9.55), Vector3(7.0, 1.7, 0.25),
		Mats.mall_cinema_velvet(), false)
	scene.adopt_local(marquee, surround)
	# Narrow pilasters bridge the concession counter to the heavy masonry
	# marquee. Without them the entire blue surround reads as a floating slab.
	for mx in [3.0, 9.0]:
		var pier = scene.box(Vector3(mx, 1.70, 9.55), Vector3(0.22, 0.72, 0.25),
			Mats.mall_trim(), false)
		scene.adopt_local(marquee, pier)
	ProceduralDetails.attach(marquee, "mall_cinema_marquee_v2", func(d: ProceduralDetails):
		# Stepped Deco crown, brass reveal, and an opal-glass letterboard.
		d.box(Vector3(6, 2.89, 9.39), Vector3(6.35, 1.12, 0.10), Mats.mall_sign_face(), 0.035)
		for y in [2.27, 3.51]:
			d.box(Vector3(6, y, 9.32), Vector3(6.55, 0.055, 0.08), Mats.mall_brass(), 0.012)
		for y in [3.65, 3.79]:
			d.box(Vector3(6, y, 9.52), Vector3(7.25 if y < 3.7 else 6.9, 0.12, 0.55), Mats.mall_trim(), 0.025)
		for i in 25:
			var x := 2.92 + float(i) * 0.257
			for y in [2.27, 3.51]:
				d.box(Vector3(x, y, 9.245), Vector3(0.055, 0.055, 0.05),
					Mats.chrome() if i % 7 == 0 else Mats.mall_cove(), 0.022)
	)
	_mall_lettering(marquee, "O R C H A R D", Vector3(6, 3.12, 9.325), 0.0047, 5.45, PI, Color(0.17, 0.21, 0.19))
	_mall_lettering(marquee, "C I N E M A S   1 - 6", Vector3(6, 2.74, 9.325), 0.0021, 4.4, PI, Color(0.28, 0.20, 0.16))
	var marquee_light := OmniLight3D.new()
	marquee_light.position = Vector3(6, 3.0, 9.0)
	marquee_light.light_color = Color(1.0, 0.80, 0.55)
	marquee_light.light_energy = 0.8
	marquee_light.omni_range = 6.5
	marquee_light.shadow_enabled = false
	marquee_light.distance_fade_enabled = true
	marquee_light.distance_fade_begin = 22.0
	marquee_light.distance_fade_length = 8.0
	marquee_light.set_meta("visible_source", "mall_cinema_marquee")
	marquee.add_child(marquee_light)
	# red carpet approach between velvet queue ropes
	scene.box(Vector3(6, 0.025, 5.4), Vector3(2.8, 0.02, 6.4), Mats.mall_cinema_velvet(), false)
	var queue_b0 = scene.collider_mark()
	var queue = scene.furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_queue")
	for i in 2:
		var rz = 3.2 + Chunk.ROPE_BARRIER_PITCH * (float(i) + 0.5)
		for rx in [4.6, 7.4]:
			var barrier = scene.rope_barrier(Vector3(rx, 0, rz), PI / 2.0,
				"mall_cinema_rope")
			if barrier != null:
				scene.adopt_local(queue, barrier)
	scene.bind_furnishing_colliders(queue, queue_b0)
	for x in [2.4, 9.6]:
		_mall_poster_stand(Vector3(x, 0, 2.0))
	if ctx.random01(1734) < 0.72:
		scene.cc0_floor_prop("metal_trash_can", Vector3(10.0, 0, 8.1),
			PI / 2.0, 0.64, "mall_cinema_refuse",
			Vector3(1.20, 0.60, 0.42), Vector3(-0.06, 0.30, 0))


func _mall_poster_stand(p: Vector3) -> void:
	var b0 = scene.collider_mark()
	var v = scene.furnishing_pivot(p, 0.0, "mall_poster_stand")
	scene.model_rounded_box(v, Vector3(0, 1.2, 0), Vector3(1.2, 2.1, 0.15),
		Mats.mall_trim(), 0.04)
	scene.model_box(v, Vector3(0, 1.2, -0.09), Vector3(1.03, 1.9, 0.025),
		Mats.mall_sign_board())
	# Original typeset film posters replace the former blank coloured inserts.
	var title := "THE LAST\nSUMMER" if p.x < 6.0 else "AFTER\nHOURS"
	_mall_lettering(v, "O R C H A R D   P I C T U R E S", Vector3(0, 1.97, -0.112), 0.00043, 0.90, PI)
	_mall_lettering(v, title, Vector3(0, 1.46, -0.115), 0.00185, 0.87, PI)
	_mall_lettering(v, "A PLACE YOU REMEMBER", Vector3(0, 0.92, -0.115), 0.00046, 0.88, PI)
	_mall_lettering(v, "DAILY  12:30  3:15  6:00\nALL SEATS  $4.50", Vector3(0, 0.43, -0.115), 0.00055, 0.88, PI)
	ProceduralDetails.attach(v, "mall_cinema_poster_graphic_%s" % (p.x < 6.0), func(d: ProceduralDetails):
		# Sunset disc and a stepped horizon, printed as shallow coloured shapes.
		for i in 7:
			var width := 0.65 - absf(float(i) - 3.0) * 0.055
			d.box(Vector3(0, 0.64 + float(i) * 0.024, -0.117), Vector3(width, 0.015, 0.002), Mats.mall_rose_stone())
	)
	scene.model_rounded_box(v, Vector3(0, 0.05, 0), Vector3(1.38, 0.10, 0.52),
		Mats.mall_trim(), 0.025)
	ProceduralDetails.attach(v, "mall_poster_stand120_210_inset_brace_v1", func(d: ProceduralDetails):
		for x in [-0.535, 0.535]:
			d.box(Vector3(x, 1.20, -0.105), Vector3(0.045, 1.98, 0.035), Mats.mall_trim(), 0.008)
		for y in [0.24, 2.16]:
			d.box(Vector3(0, y, -0.105), Vector3(1.11, 0.045, 0.035), Mats.mall_trim(), 0.008)
		d.tube(Vector3(0, 0.12, 0.12), Vector3(0, 1.05, 0.07), 0.025, Mats.charcoal())
	)
	scene.collider_yaw_box(p + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.22), 0)
	scene.bind_furnishing_colliders(v, b0)


# --- island prison -----------------------------------------------------------
