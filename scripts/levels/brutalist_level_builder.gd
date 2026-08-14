extends "res://scripts/levels/chunk_level_builder.gd"
## Theme 10 — the Monolith.
##
## The visual language comes from monumental civic brutalism rather than a
## furnished building: structure is the prop. Repeating board-form concrete,
## deep ceiling beams, stacked galleries, light wells and reflecting courts
## produce scale without putting clutter in the player's route.

const TUNNEL_HALF_WIDTH := 1.65
const TUNNEL_HEIGHT := 3.45
const TUNNEL_WALL_T := 0.22
const FIXTURE_SCALE := 1.36
const FIXTURE_VARIANTS := [
	"Fluorescent Lamp - Lowpoly 01",
	"Fluorescent Lamp - Lowpoly 02",
	"Fluorescent Lamp - Lowpoly 03",
	"Fluorescent Lamp - Lowpoly 04",
]
# Combined imported-space centres measured from the four source variants. The
# top of every housing is y=0, so only plan offsets are corrected at mounting.
const FIXTURE_CENTRES := [
	Vector3(0.4000, 0.0, 0.5000),
	Vector3(-0.4500, 0.0, 0.0000),
	Vector3(0.4000, 0.0, -0.4000),
	Vector3(-0.1000, 0.0, 0.0000),
]
const INCURSION_VINES_CENTRE := Vector3(0.593594, 2.021460, -0.205125)
const WALL_THICKNESS := 0.15
const BRUTAL_DOOR_TOP := 3.15
const BRUTAL_LIGHT_PATH := "res://models/cc_by/fluorescent_light_fixtures/fluorescent_light_fixtures.glb"
const BLOOM_VINES_PATH := "res://models/cc_by/modular_vines/modular_vines.glb"
const ANNEX_EXIT_DOOR_PATH := "res://models/cc_by/backrooms_vr_exit_door/backrooms_exit_door.scn"


func _brutalist_floor_ceiling() -> void:
	scene.box(Vector3(WorldGen.CELL_SIZE * 0.5, -0.18, WorldGen.CELL_SIZE * 0.5),
		Vector3(WorldGen.CELL_SIZE, 0.36, WorldGen.CELL_SIZE), Mats.brutal_floor())
	scene.box(Vector3(WorldGen.CELL_SIZE * 0.5, ctx.ceiling_height + 0.24, WorldGen.CELL_SIZE * 0.5),
		Vector3(WorldGen.CELL_SIZE, 0.48, WorldGen.CELL_SIZE), Mats.brutal_structure())
	# Deep coffers turn every ceiling into load-bearing mass, not a flat lid.
	var axis_x := WorldGen.r01(ctx.world_seed, ctx.room_root.x,
		ctx.room_root.y, 2100) < 0.5
	for t in [1.4, 4.45, 7.55, 10.6]:
		var p := Vector3(6.0, ctx.ceiling_height - 0.32, t) if axis_x \
			else Vector3(t, ctx.ceiling_height - 0.32, 6.0)
		var s := Vector3(12.0, 0.62, 0.48) if axis_x \
			else Vector3(0.48, 0.62, 12.0)
		scene.box(p, s, Mats.brutal_structure(), false)
	# A few rooms open to a cold, unreachable light well.
	if ctx.style == WorldGen.BRUTAL_ATRIUM \
			or ctx.style == WorldGen.BRUTAL_SANCTUM:
		scene.box(Vector3(6.0, ctx.ceiling_height - 0.018, 6.0),
			Vector3(4.6, 0.025, 3.0), Mats.brutal_panel(), false)
		for x in [3.62, 8.38]:
			scene.box(Vector3(x, ctx.ceiling_height - 0.08, 6.0),
				Vector3(0.20, 0.16, 3.35), Mats.brutal_steel(), false)
	_monolith_incursion()


## The Bloom is beginning to cross the boundary, but it has not claimed this
## place. Most cells remain entirely clean. In the rare selected cell a single
## ceiling corner carries a small, non-colliding trace: something the player
## can miss on the first pass and recognize only after visiting the Bloom.
func _monolith_incursion() -> void:
	if ctx.cell == Vector2i.ZERO:
		return
	var chance := 0.075 if ctx.style == WorldGen.BRUTAL_PASSAGE else 0.125
	if ctx.random01(2230) >= chance:
		return
	var root := Node3D.new()
	root.name = "MonolithEarlyIncursion"
	root.set_meta("monolith_organic_trace", true)
	root.set_meta("incursion_stage", "trace")
	scene.add_node(root)

	var corner := posmod(WorldGen.h(ctx.world_seed, ctx.cell.x,
		ctx.cell.y, 2231), 4)
	var sx := -1.0 if corner == 0 or corner == 2 else 1.0
	var sz := -1.0 if corner < 2 else 1.0
	var trace_y := ctx.ceiling_height - 0.34
	if ctx.style == WorldGen.BRUTAL_PASSAGE:
		trace_y = minf(trace_y, TUNNEL_HEIGHT - 0.30)
	var centre := Vector3(6.0 + sx * 4.55, trace_y, 6.0 + sz * 4.55)
	var spread := 0.62 + ctx.random01(2232) * 0.34
	_monolith_tendril(root, centre,
		centre + Vector3(-sx * spread, -0.18, sz * 0.16), 0.045)
	_monolith_tendril(root, centre + Vector3(-sx * 0.10, 0.0, -sz * 0.08),
		centre + Vector3(sx * 0.12, -0.66 - ctx.random01(2233) * 0.34,
			-sz * 0.25), 0.032)

	# Roughly one trace in three gets a small authored knot. It stays tucked at
	# the ceiling and carries no collision, so the incursion never changes the
	# Monolith's routes or silhouette at room scale.
	if ctx.random01(2234) < 0.34:
		var pivot := Node3D.new()
		pivot.name = "MonolithVineKnot"
		pivot.position = centre + Vector3(-sx * 0.16, -0.08, -sz * 0.12)
		pivot.rotation = Vector3(0.0, ctx.random01(2235) * TAU, PI * 0.5)
		pivot.scale = Vector3.ONE * (0.16 + ctx.random01(2236) * 0.05)
		pivot.set_meta("monolith_authored_incursion", true)
		root.add_child(pivot)
		var inst := scene.attributed_prop_local(pivot, BLOOM_VINES_PATH,
			-INCURSION_VINES_CENTRE, 0.0)
		if inst == null:
			pivot.get_parent().remove_child(pivot)
			pivot.free()
		else:
			inst.set_meta("authored_model", "monolith_modular_vine_trace")
			for found in inst.find_children("*", "MeshInstance3D", true, false):
				var mesh_node := found as MeshInstance3D
				mesh_node.material_override = Mats.bloom_growth()
				mesh_node.cast_shadow = \
					GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _monolith_tendril(parent: Node3D, a: Vector3, b: Vector3,
		radius: float) -> void:
	var d := b - a
	if d.length_squared() < 0.0004:
		return
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.height = 2.0
	mesh.top_radius = 0.31
	mesh.bottom_radius = 0.5
	var tendril := MeshInstance3D.new()
	tendril.mesh = mesh
	tendril.material_override = Mats.bloom_growth()
	tendril.position = (a + b) * 0.5
	tendril.quaternion = Quaternion(Vector3.UP, d.normalized())
	tendril.scale = Vector3(radius / 0.5, d.length() * 0.5, radius / 0.5)
	tendril.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tendril.set_meta("monolith_organic_tendril", true)
	parent.add_child(tendril)


func _brutalist_lighting() -> void:
	var dead := ctx.cell != Vector2i.ZERO and ctx.random01(2120) < 0.055
	var flicker := not dead and ctx.cell != Vector2i.ZERO and ctx.random01(2121) < 0.13
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.brutal_panel()
	if flicker:
		lens = Mats.brutal_panel().duplicate()
	var corridor_axis := WorldGen.corridor(ctx.world_seed, ctx.cell)
	var along_x := corridor_axis != 2
	var emission_mats: Array[StandardMaterial3D] = []
	# Mark Peters' four real fixture designs replace the former glowing boxes.
	# Passage cells get a single-file rhythm below their lower tunnel lid;
	# monumental rooms use a sparse two-by-two ceiling field.
	if ctx.style == WorldGen.BRUTAL_PASSAGE:
		var fixture_y := TUNNEL_HEIGHT - 0.015
		for i in 4:
			var along := 1.5 + float(i) * 3.0
			var p := Vector3(along, fixture_y, 6.0) if along_x \
				else Vector3(6.0, fixture_y, along)
			_brutal_fluorescent_fixture(p, PI * 0.5 if along_x else 0.0,
				[1, 3, 2, 1][i], dead, flicker, emission_mats)
	else:
		var fixture_y := ctx.ceiling_height - 0.025
		var fi := 0
		for x in [3.7, 8.3]:
			for z in [3.7, 8.3]:
				var variant := posmod(
					int(ctx.random01(2124 + fi) * 3.99) + fi, 4)
				_brutal_fluorescent_fixture(Vector3(x, fixture_y, z),
					PI * 0.5 if along_x else 0.0, variant,
					dead, flicker, emission_mats)
				fi += 1
	if dead:
		return
	var huge := ctx.style == WorldGen.BRUTAL_ATRIUM \
		or ctx.style == WorldGen.BRUTAL_SANCTUM \
		or ctx.style == WorldGen.BRUTAL_WATER_COURT
	var passage := ctx.style == WorldGen.BRUTAL_PASSAGE
	var light := scene.main_light(flicker, lens,
		1.55 if passage else (2.35 if huge else 1.75))
	if light is FlickerLight and not emission_mats.is_empty():
		(light as FlickerLight).mats = emission_mats
	light.light_color = Color(0.70, 0.82, 0.90)
	light.omni_range = 10.5 if passage else (18.0 if huge else 14.0)
	light.position = Vector3(6.0,
		TUNNEL_HEIGHT - 0.62 if passage else ctx.ceiling_height - 1.15, 6.0)
	light.shadow_enabled = huge
	light.distance_fade_enabled = true
	light.distance_fade_begin = 28.0
	light.distance_fade_length = 10.0
	scene.add_node(light)
	if huge and ctx.ceiling_height > 7.0:
		var shaft := SpotLight3D.new()
		shaft.light_color = Color(0.62, 0.78, 0.90)
		shaft.light_energy = 4.0
		shaft.spot_range = ctx.ceiling_height + 3.0
		shaft.spot_angle = 38.0
		shaft.position = Vector3(6.0, ctx.ceiling_height - 0.35, 6.0)
		shaft.rotation.x = -PI * 0.5
		shaft.shadow_enabled = true
		shaft.distance_fade_enabled = true
		shaft.distance_fade_begin = 30.0
		shaft.distance_fade_length = 12.0
		scene.add_node(shaft)


## Select one of the four fixtures contained in the supplied Sketchfab scene,
## re-centre that variant and preserve its authored PBR/emission material. Dead
## and flickering rooms receive per-instance material duplicates so one cell's
## ballast state can never alter every fixture sharing the cached mesh.
func _brutal_fluorescent_fixture(at: Vector3, yaw: float, variant: int,
		dead: bool, flicker: bool,
		emission_mats: Array[StandardMaterial3D]) -> void:
	variant = clampi(variant, 0, FIXTURE_VARIANTS.size() - 1)
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = yaw
	pivot.set_meta("brutal_fluorescent_fixture", true)
	pivot.set_meta("brutal_fixture_variant", variant + 1)
	scene.add_node(pivot)
	var centre: Vector3 = FIXTURE_CENTRES[variant]
	var inst := scene.attributed_prop_local(pivot, BRUTAL_LIGHT_PATH,
		Vector3(-centre.x * FIXTURE_SCALE, 0.0,
			-centre.z * FIXTURE_SCALE), 0.0, Vector3.ONE * FIXTURE_SCALE)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	inst.set_meta("authored_model", "monolith_fluorescent_fixture")
	var selected: Node3D
	for i in FIXTURE_VARIANTS.size():
		var candidate := inst.find_child(FIXTURE_VARIANTS[i], true, false) as Node3D
		if candidate == null:
			continue
		candidate.visible = i == variant
		if i == variant:
			selected = candidate
	if selected == null or (not dead and not flicker):
		return
	for found in selected.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(surface) \
				as StandardMaterial3D
			if source == null or not source.emission_enabled:
				continue
			var local := source.duplicate() as StandardMaterial3D
			local.emission_energy_multiplier = 0.0 if dead else 2.6
			mesh_node.set_surface_override_material(surface, local)
			if flicker:
				emission_mats.append(local)


func _brutalist_wall_detail(dir: int, plane: float) -> void:
	# Recessed horizontal pour joints and sparse tie holes make a twelve-metre
	# procedural wall read as cast board-form concrete at human distance.
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var face := plane + n * WALL_THICKNESS * 0.5
	for y in [1.18, 2.38, 3.58]:
		if y > ctx.ceiling_height - 0.4:
			continue
		var p := Vector3(face + n * 0.008, y, 6.0) if dir < 2 \
			else Vector3(6.0, y, face + n * 0.008)
		var s := Vector3(0.018, 0.025, 11.5) if dir < 2 \
			else Vector3(11.5, 0.025, 0.018)
		scene.box(p, s, Mats.brutal_steel(), false)
	for along in [2.0, 4.65, 7.35, 10.0]:
		for y2 in [0.72, 2.88]:
			if y2 > ctx.ceiling_height - 0.35:
				continue
			var bp := Vector3(face + n * 0.015, y2, along) if dir < 2 \
				else Vector3(along, y2, face + n * 0.015)
			var bolt := scene.cylinder(bp, 0.038, 0.012,
				Mats.brutal_steel(), false)
			bolt.rotation.x = PI * 0.5 if dir >= 2 else 0.0
			bolt.rotation.z = PI * 0.5 if dir < 2 else 0.0


func _column(p: Vector3, height: float, wide := 0.72) -> void:
	scene.box(p + Vector3(0, height * 0.5, 0),
		Vector3(wide, height, wide), Mats.brutal_structure())
	scene.box(p + Vector3(0, height - 0.32, 0),
		Vector3(wide + 0.42, 0.64, wide + 0.42),
		Mats.brutal_structure(), false)


func _perimeter_columns() -> void:
	for p in [Vector3(1.7, 0, 1.7), Vector3(10.3, 0, 1.7),
			Vector3(1.7, 0, 10.3), Vector3(10.3, 0, 10.3)]:
		_column(p, ctx.ceiling_height)


func _upper_gallery(axis_x: bool, side: float, height: float) -> void:
	var p := Vector3(6.0, height, 6.0 + side * 4.45) if axis_x \
		else Vector3(6.0 + side * 4.45, height, 6.0)
	var slab := Vector3(10.8, 0.28, 2.15) if axis_x \
		else Vector3(2.15, 0.28, 10.8)
	scene.box(p, slab, Mats.brutal_structure(), false)
	var edge := p + (Vector3(0, 0.72, -side * 1.02) if axis_x \
		else Vector3(-side * 1.02, 0.72, 0))
	var rail := Vector3(10.2, 0.10, 0.10) if axis_x \
		else Vector3(0.10, 0.10, 10.2)
	scene.box(edge, rail, Mats.brutal_steel(), false)
	for t in [-4.8, -3.2, -1.6, 0.0, 1.6, 3.2, 4.8]:
		var rp := edge + (Vector3(t, -0.36, 0) if axis_x else Vector3(0, -0.36, t))
		scene.box(rp, Vector3(0.055, 0.78, 0.055), Mats.brutal_steel(), false)


func _black_court(cross_walk := true) -> void:
	if cross_walk:
		for x in [2.25, 9.75]:
			for z in [2.25, 9.75]:
				scene.box(Vector3(x, 0.022, z), Vector3(3.25, 0.028, 3.25),
					Mats.brutal_black_water(), false)
	else:
		scene.box(Vector3(6.0, 0.022, 6.0), Vector3(7.4, 0.028, 4.2),
			Mats.brutal_black_water(), false)


func _brutal_passage() -> void:
	var along_x := WorldGen.corridor(ctx.world_seed, ctx.cell) != 2
	# A complete, colliding concrete shell: 3.3m clear width and a 3.45m lid.
	# Side connections become short return-walled vestibules to the real edge
	# openings, so the player can never walk around a decorative facade.
	var lid_size := Vector3(WorldGen.CELL_SIZE, 0.30,
		TUNNEL_HALF_WIDTH * 2.0 + TUNNEL_WALL_T) if along_x \
		else Vector3(TUNNEL_HALF_WIDTH * 2.0 + TUNNEL_WALL_T,
			0.30, WorldGen.CELL_SIZE)
	_tunnel_box(Vector3(6.0, TUNNEL_HEIGHT + 0.15, 6.0),
		lid_size, "ceiling")
	var side_data: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var dir := (3 if side < 0.0 else 2) if along_x \
			else (1 if side < 0.0 else 0)
		var info: Dictionary = scene.edge_info(ctx.cell, dir)
		_brutal_tunnel_side(along_x, side, dir, info)
		side_data.append({"side": side, "dir": dir, "wall": bool(info["wall"])})
	# Close-spaced transverse ribs and one visible cable tray reinforce the
	# change from monumental room to compressed service tunnel.
	for t in [1.0, 3.5, 6.0, 8.5, 11.0]:
		var rib_p := Vector3(t, TUNNEL_HEIGHT - 0.09, 6.0) if along_x \
			else Vector3(6.0, TUNNEL_HEIGHT - 0.09, t)
		var rib_s := Vector3(0.28, 0.18,
			TUNNEL_HALF_WIDTH * 2.0) if along_x \
			else Vector3(TUNNEL_HALF_WIDTH * 2.0, 0.18, 0.28)
		_tunnel_box(rib_p, rib_s, "rib", false)
	var tray_p := Vector3(6.0, TUNNEL_HEIGHT - 0.32, 5.0) if along_x \
		else Vector3(5.0, TUNNEL_HEIGHT - 0.32, 6.0)
	var tray_s := Vector3(WorldGen.CELL_SIZE, 0.08, 0.34) if along_x \
		else Vector3(0.34, 0.08, WorldGen.CELL_SIZE)
	_tunnel_box(tray_p, tray_s, "cable_tray", false, Mats.brutal_steel())
	# A long sealed wall gets one familiar Annex double door. It is a real
	# authored facade backed by solid tunnel structure, never a fake route.
	if ctx.random01(2190) < 0.72:
		var solid_sides: Array[Dictionary] = []
		for entry in side_data:
			if bool(entry["wall"]):
				solid_sides.append(entry)
		if not solid_sides.is_empty():
			var pick := mini(int(ctx.random01(2191) * solid_sides.size()),
				solid_sides.size() - 1)
			var chosen: Dictionary = solid_sides[pick]
			var side := float(chosen["side"])
			var plane := 6.0 + side * TUNNEL_HALF_WIDTH
			var p := Vector3(6.0, 0.0, plane - side * 0.13) if along_x \
				else Vector3(plane - side * 0.13, 0.0, 6.0)
			_brutal_annex_door_at(p, scene.wall_facing(int(chosen["dir"])),
				"tunnel")


func _tunnel_box(pos: Vector3, size: Vector3, part: String,
		collide := true, mat: Material = null) -> MeshInstance3D:
	var use_mat: Material = Mats.brutal_structure() if mat == null else mat
	var mesh := scene.box(pos, size, use_mat, collide)
	mesh.set_meta("brutal_tunnel_part", part)
	mesh.set_meta("brutal_tunnel_height", TUNNEL_HEIGHT)
	mesh.set_meta("brutal_tunnel_width", TUNNEL_HALF_WIDTH * 2.0)
	return mesh


func _brutal_tunnel_side(along_x: bool, side: float, _dir: int,
		info: Dictionary) -> void:
	var plane := 6.0 + side * TUNNEL_HALF_WIDTH
	if bool(info["wall"]):
		var solid_pos := Vector3(6.0, TUNNEL_HEIGHT * 0.5, plane) if along_x \
			else Vector3(plane, TUNNEL_HEIGHT * 0.5, 6.0)
		var solid_size := Vector3(WorldGen.CELL_SIZE, TUNNEL_HEIGHT,
			TUNNEL_WALL_T) if along_x \
			else Vector3(TUNNEL_WALL_T, TUNNEL_HEIGHT, WorldGen.CELL_SIZE)
		_tunnel_box(solid_pos, solid_size, "side_wall")
		return
	var width := clampf(float(info["w"]), 2.25, 3.40)
	var centre := clampf(float(info["t"]), width * 0.5 + 0.45,
		WorldGen.CELL_SIZE - width * 0.5 - 0.45)
	var a := centre - width * 0.5
	var b := centre + width * 0.5
	for bounds in [[0.0, a], [b, WorldGen.CELL_SIZE]]:
		var lo := float(bounds[0])
		var hi := float(bounds[1])
		if hi - lo <= 0.02:
			continue
		var pos := Vector3((lo + hi) * 0.5, TUNNEL_HEIGHT * 0.5,
			plane) if along_x else Vector3(plane,
				TUNNEL_HEIGHT * 0.5, (lo + hi) * 0.5)
		var size := Vector3(hi - lo, TUNNEL_HEIGHT,
			TUNNEL_WALL_T) if along_x else Vector3(TUNNEL_WALL_T,
				TUNNEL_HEIGHT, hi - lo)
		_tunnel_box(pos, size, "side_wall")
	var header_h := TUNNEL_HEIGHT - BRUTAL_DOOR_TOP
	var header_p := Vector3(centre,
		BRUTAL_DOOR_TOP + header_h * 0.5, plane) if along_x \
		else Vector3(plane, BRUTAL_DOOR_TOP + header_h * 0.5, centre)
	var header_s := Vector3(width, header_h,
		TUNNEL_WALL_T) if along_x else Vector3(TUNNEL_WALL_T,
		header_h, width)
	_tunnel_box(header_p, header_s, "opening_header")
	# The opening's two returns bridge from the tunnel shell to the canonical
	# cell-edge wall. Their ceiling continues the lower tunnel datum.
	var outer := WorldGen.CELL_SIZE - WALL_THICKNESS if side > 0.0 else WALL_THICKNESS
	var depth := absf(outer - plane)
	var mid := (outer + plane) * 0.5
	for edge in [a, b]:
		var return_p := Vector3(edge, TUNNEL_HEIGHT * 0.5, mid) if along_x \
			else Vector3(mid, TUNNEL_HEIGHT * 0.5, edge)
		var return_s := Vector3(TUNNEL_WALL_T, TUNNEL_HEIGHT,
			depth) if along_x else Vector3(depth, TUNNEL_HEIGHT,
				TUNNEL_WALL_T)
		_tunnel_box(return_p, return_s, "vestibule_return")
	var soffit_p := Vector3(centre, TUNNEL_HEIGHT + 0.15, mid) if along_x \
		else Vector3(mid, TUNNEL_HEIGHT + 0.15, centre)
	var soffit_s := Vector3(width, 0.30, depth) if along_x \
		else Vector3(depth, 0.30, width)
	_tunnel_box(soffit_p, soffit_s, "vestibule_ceiling")


func _brutal_annex_door_at(pos: Vector3, yaw: float, context: String) -> bool:
	var pivot := scene.furnishing_pivot(
		pos, yaw, "monolith_annex_exit_door", true)
	pivot.set_meta("attributed_furnishing", "monolith_annex_exit_door")
	pivot.set_meta("monolith_annex_door", true)
	pivot.set_meta("monolith_annex_door_context", context)
	pivot.set_meta("locked_facade", true)
	var authored := scene.attributed_prop_local(
		pivot, ANNEX_EXIT_DOOR_PATH, Vector3.ZERO, 0.0)
	if authored == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return false
	authored.set_meta("authored_model", "monolith_annex_exit_door")
	return true


func _maybe_brutal_annex_door(salt: int, chance := 0.44) -> bool:
	# Multi-cell room set pieces are shifted to the room centre after building;
	# a facade must stay on the wall that owns it, so use this room-wall version
	# only in single-cell chambers. Tunnels have their own cell-local mount.
	if ctx.room_size != 1 or ctx.random01(salt) >= chance:
		return false
	var start := posmod(
		WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt + 1), 4)
	for step in 4:
		var dir := (start + step) % 4
		if not scene.solid_wall(dir):
			continue
		var along := 3.25 if ctx.random01(salt + 2) < 0.5 else 8.75
		var p := scene.wall_point(dir, along, 0.13)
		return _brutal_annex_door_at(
			p, scene.wall_facing(dir), "room_wall")
	return false


func _brutal_hall() -> void:
	_perimeter_columns()
	_maybe_brutal_annex_door(2200)
	if ctx.random01(2140) < 0.58:
		_upper_gallery(ctx.random01(2141) < 0.5, -1.0 if ctx.random01(2142) < 0.5 else 1.0,
			minf(ctx.ceiling_height * 0.58, ctx.ceiling_height - 2.5))


func _brutal_gallery() -> void:
	_perimeter_columns()
	_maybe_brutal_annex_door(2204, 0.50)
	var axis_x := ctx.random01(2150) < 0.5
	_upper_gallery(axis_x, -1.0, minf(3.65, ctx.ceiling_height - 2.2))
	if ctx.ceiling_height > 8.0:
		_upper_gallery(axis_x, 1.0, minf(6.9, ctx.ceiling_height - 2.2))


func _brutal_atrium() -> void:
	_perimeter_columns()
	_black_court(true)
	_maybe_brutal_annex_door(2208, 0.34)
	var axis_x := ctx.random01(2160) < 0.5
	_upper_gallery(axis_x, -1.0, minf(3.8, ctx.ceiling_height - 2.4))
	_upper_gallery(not axis_x, 1.0, minf(7.1, ctx.ceiling_height - 2.4))


func _brutal_water_court() -> void:
	_black_court(false)
	_maybe_brutal_annex_door(2212, 0.38)
	for p in [Vector3(1.55, 0, 1.55), Vector3(10.45, 0, 1.55),
			Vector3(1.55, 0, 10.45), Vector3(10.45, 0, 10.45)]:
		_column(p, ctx.ceiling_height, 0.54)


func _brutal_ramp() -> void:
	# A massive ascending procession seen from the room, deliberately kept
	# outside the central cross-lane so it never becomes mandatory traversal.
	var along_x := ctx.random01(2170) < 0.5
	var side := -1.0 if ctx.random01(2171) < 0.5 else 1.0
	for i in 9:
		var rise := 0.16 + float(i) * 0.30
		var run := 1.35 + float(i) * 0.82
		var p := Vector3(run, rise * 0.5, 6.0 + side * 3.65) if along_x \
			else Vector3(6.0 + side * 3.65, rise * 0.5, run)
		var s := Vector3(0.86, rise, 2.25) if along_x \
			else Vector3(2.25, rise, 0.86)
		scene.box(p, s, Mats.brutal_structure())
	_maybe_brutal_annex_door(2216, 0.48)


func _brutal_service() -> void:
	var axis_x := ctx.random01(2180) < 0.5
	for side in [-1.0, 1.0]:
		for y in [ctx.ceiling_height - 1.1, ctx.ceiling_height - 1.55]:
			var p := Vector3(6.0, y, 6.0 + side * 2.85) if axis_x \
				else Vector3(6.0 + side * 2.85, y, 6.0)
			var pipe := scene.cylinder(p, 0.11, 11.5, Mats.brutal_steel(), false)
			pipe.rotation.z = PI * 0.5 if axis_x else 0.0
			pipe.rotation.x = 0.0 if axis_x else PI * 0.5
	for p2 in [Vector3(2.0, 0, 2.0), Vector3(10.0, 0, 10.0)]:
		if ctx.descent:
			# These service plinths are equipment, not structure. In Descent keep
			# each visual and solid body atomic so a reality may move it safely.
			var b0 := scene.collider_mark()
			var plinth := scene.furnishing_pivot(
				p2, 0.0, "monolith_service_plinth")
			scene.model_box(plinth, Vector3(0, 1.25, 0),
				Vector3(1.25, 2.5, 1.25), Mats.brutal_structure())
			scene.collider_box(p2 + Vector3(0, 1.25, 0),
				Vector3(1.25, 2.5, 1.25))
			scene.bind_furnishing_colliders(plinth, b0)
		else:
			scene.box(p2 + Vector3(0, 1.25, 0),
				Vector3(1.25, 2.5, 1.25), Mats.brutal_structure())
	_maybe_brutal_annex_door(2220, 0.58)


func _brutal_sanctum() -> void:
	_black_court(true)
	_maybe_brutal_annex_door(2224, 0.42)
	for x in [1.35, 3.25, 8.75, 10.65]:
		_column(Vector3(x, 0, 6.0), ctx.ceiling_height, 0.52)
	if ctx.ceiling_height > 8.2:
		_upper_gallery(true, -1.0, 4.0)
		_upper_gallery(true, 1.0, 7.2)
