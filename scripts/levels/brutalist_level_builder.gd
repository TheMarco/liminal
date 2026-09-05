extends "res://scripts/levels/chunk_level_builder.gd"
## Theme 10 — the Data Center.
##
## The monumental civic concrete shell remains, but it has been occupied by an
## impossible machine estate: hot/cold aisles, operations consoles, cooling
## plants, cable risers and dense server banks repeat through the structure.

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

# Imported-space centres are (visual centre X, visual minimum Y, visual centre Z).
# Keeping the measurements beside their placement scales makes every instance
# floor-centred without hiding source-unit corrections in call sites.
const CONSOLE_SCALE := 0.40
const CONSOLE_CENTRE := Vector3(0.689082, 0.002568, -0.020504)
const CONSOLE_SIZE := Vector3(1.3513, 2.0608, 0.6898)
const RACK_BANK_SCALE := 0.021
const RACK_BANK_CENTRE := Vector3(-0.15934, 0.0, 7.42196)
const RACK_BANK_SIZE := Vector3(3.9690, 2.0162, 1.0191)
const SERVER_RACK_SCALE := 0.90
const SERVER_RACK_CENTRE := Vector3(0.0, -0.000464, -0.024479)
const SERVER_RACK_SIZE := Vector3(0.5400, 2.2506, 0.7672)
const NETWORK_RACK_SCALE := 1.0
const NETWORK_RACK_CENTRE := Vector3(0.036023, -0.011138, 0.472491)
const NETWORK_RACK_SIZE := Vector3(1.1151, 1.8309, 2.0999)
const DETAILED_RACK_SCALE := 1.0
const DETAILED_RACK_CENTRE := Vector3(0.0, 0.136780, 0.002161)
const DETAILED_RACK_SIZE := Vector3(0.7994, 2.0656, 1.1384)
const GLASS_SERVER_SCALE := 0.158
const GLASS_SERVER_CENTRE := Vector3(4.992994, 0.0, 6.671851)
const GLASS_SERVER_SIZE := Vector3(0.6335, 2.1995, 0.6335)
const AZURE_SERVER_SCALE := 1.0
const AZURE_SERVER_CENTRE := Vector3(-0.000005, 0.0, 0.0)
const AZURE_SERVER_SIZE := Vector3(0.9311, 1.7581, 0.9393)
const AC_SCALE := 0.008
const AC_SIZES := [
	Vector3(1.3124, 1.0160, 1.6942),
	Vector3(1.7624, 1.1282, 1.3124),
	Vector3(1.6900, 1.0132, 1.3124),
]


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
	# Data Center's routes or silhouette at room scale.
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


func _data_center_asset(path: String, at: Vector3, yaw: float, scl: float,
		centre: Vector3, size: Vector3, kind: String,
		disable_shadows := false) -> Node3D:
	var body0 := scene.collider_mark()
	var pivot := scene.attributed_floor_prop(path, at, yaw, scl, centre,
		kind, null, true)
	if pivot == null:
		return null
	pivot.set_meta("data_center_infrastructure", true)
	pivot.set_meta("data_center_kind", kind)
	if kind.contains("rack") or kind.contains("console") \
			or kind.contains("control"):
		pivot.set_meta("data_center_rack", true)
	if kind.contains("cooling"):
		pivot.set_meta("data_center_cooling", true)
	if disable_shadows:
		scene.disable_shadows(pivot)
	scene.collider_yaw_box(at + Vector3(0.0, size.y * 0.5, 0.0), size, yaw)
	scene.bind_furnishing_colliders(pivot, body0)
	return pivot


func _network_rack(at: Vector3, yaw: float) -> Node3D:
	# This three-cabinet bank is authored with its service fronts on +X. Rotate
	# that axis onto the +Z convention shared by every single-rack wrapper, so a
	# row can give all variants one logical yaw without exposing random backs.
	return _data_center_asset(Chunk.DATA_CENTER_NETWORK_RACK_PATH, at,
		yaw - PI * 0.5,
		NETWORK_RACK_SCALE, NETWORK_RACK_CENTRE, NETWORK_RACK_SIZE,
		"data_center_network_rack", true)


func _server_rack(at: Vector3, yaw: float) -> Node3D:
	return _data_center_asset(Chunk.DATA_CENTER_RACK_PATH, at, yaw,
		SERVER_RACK_SCALE, SERVER_RACK_CENTRE, SERVER_RACK_SIZE,
		"data_center_server_rack")


func _detailed_server_rack(at: Vector3, yaw: float) -> Node3D:
	# This exceptionally detailed 459-mesh rack is a hero prop, never a row
	# filler. Keeping it to the core vault avoids multiplying its scene cost.
	return _data_center_asset(Chunk.DATA_CENTER_DETAILED_RACK_PATH, at, yaw,
		DETAILED_RACK_SCALE, DETAILED_RACK_CENTRE, DETAILED_RACK_SIZE,
		"data_center_detailed_server_rack", true)


func _glass_server_rack(at: Vector3, yaw: float) -> Node3D:
	# The authored glass door faces backward in imported space.
	return _data_center_asset(Chunk.DATA_CENTER_GLASS_SERVER_PATH, at, yaw + PI,
		GLASS_SERVER_SCALE, GLASS_SERVER_CENTRE, GLASS_SERVER_SIZE,
		"data_center_glass_server_rack")


func _azure_server_rack(at: Vector3, yaw: float) -> Node3D:
	return _data_center_asset(Chunk.DATA_CENTER_AZURE_SERVER_PATH, at, yaw,
		AZURE_SERVER_SCALE, AZURE_SERVER_CENTRE, AZURE_SERVER_SIZE,
		"data_center_azure_server_rack")


func _console_rack(at: Vector3, yaw: float) -> Node3D:
	return _data_center_asset(Chunk.DATA_CENTER_CONSOLE_PATH, at, yaw,
		CONSOLE_SCALE, CONSOLE_CENTRE, CONSOLE_SIZE,
		"data_center_console_rack")


func _control_bank(at: Vector3, yaw: float) -> Node3D:
	return _data_center_asset(Chunk.DATA_CENTER_RACK_BANK_PATH, at, yaw,
		RACK_BANK_SCALE, RACK_BANK_CENTRE, RACK_BANK_SIZE,
		"data_center_control_bank", true)


func _cooling_unit(at: Vector3, yaw: float, variant: int) -> Node3D:
	# Lora's source is a collection. Each extracted scene is one complete floor
	# condenser, so a placement always selects exactly one unit rather than
	# instancing the collection as though it were a single prop.
	variant = posmod(variant, Chunk.DATA_CENTER_AC_PATHS.size())
	var size: Vector3 = AC_SIZES[variant]
	var unit_at := at + Vector3(0.0, 0.09, 0.0)
	var unit := _data_center_asset(Chunk.DATA_CENTER_AC_PATHS[variant],
		unit_at, yaw,
		AC_SCALE, Vector3.ZERO, AC_SIZES[variant],
		"data_center_cooling_unit", true)
	if unit != null:
		unit.set_meta("data_center_cooling_variant", variant)
		var pad := scene.model_box(unit, Vector3(0.0, -0.045, 0.0),
			Vector3(size.x + 0.18, 0.09, size.z + 0.18),
			Mats.brutal_structure())
		pad.set_meta("data_center_cooling_pad", true)
	return unit


func _aisle_floor_guides(axis_x: bool, centre: float = 6.0,
		long_span: float = 12.0) -> void:
	var guide_length := maxf(3.0, long_span - 1.5)
	for offset in [-0.58, 0.58]:
		var lane: float = centre + float(offset)
		var p := Vector3(6.0, 0.022, lane) if axis_x \
			else Vector3(lane, 0.022, 6.0)
		var s := Vector3(guide_length, 0.026, 0.07) if axis_x \
			else Vector3(0.07, 0.026, guide_length)
		var guide := scene.box(p, s, Mats.data_center_floor_mark(), false)
		guide.set_meta("data_center_aisle_guide", true)
	# Short luminous thresholds identify the cold aisle without reintroducing a
	# glossy floor finish.
	var edge := long_span * 0.5 - 0.85
	for end in [6.0 - edge, 6.0 + edge]:
		var p2 := Vector3(end, 0.038, centre) if axis_x \
			else Vector3(centre, 0.038, end)
		var s2 := Vector3(0.055, 0.018, 1.05) if axis_x \
			else Vector3(1.05, 0.018, 0.055)
		scene.box(p2, s2, Mats.data_center_status(), false)


func _overhead_busways(axis_x: bool, lanes: Array, height: float,
		long_span: float = 12.0) -> void:
	var bus_length := maxf(3.0, long_span - 1.2)
	for lane in lanes:
		var p := Vector3(6.0, height, float(lane)) if axis_x \
			else Vector3(float(lane), height, 6.0)
		var s := Vector3(bus_length, 0.12, 0.48) if axis_x \
			else Vector3(0.48, 0.12, bus_length)
		var tray := scene.box(p, s, Mats.brutal_steel(), false)
		tray.set_meta("data_center_overhead_busway", true)
		var glow_p := p - Vector3(0.0, 0.075, 0.0)
		var glow_s := Vector3(bus_length - 0.35, 0.025, 0.065) if axis_x \
			else Vector3(0.065, 0.025, bus_length - 0.35)
		scene.box(glow_p, glow_s, Mats.data_center_status(), false)
		# Two readable cable looms sit above each ladder tray.
		for side in [-0.13, 0.13]:
			var cp := p + (Vector3(0.0, 0.09, side) if axis_x \
				else Vector3(side, 0.09, 0.0))
			var cs := Vector3(bus_length - 0.20, 0.045, 0.055) if axis_x \
				else Vector3(0.055, 0.045, bus_length - 0.20)
			scene.box(cp, cs, Mats.data_center_cable(), false)
		var t := 6.0 - long_span * 0.5 + 0.8
		var last := 6.0 + long_span * 0.5 - 0.8
		while t <= last + 0.01:
			var rp := Vector3(t, height + 0.08, float(lane)) if axis_x \
				else Vector3(float(lane), height + 0.08, t)
			var rs := Vector3(0.055, 0.055, 0.58) if axis_x \
				else Vector3(0.58, 0.055, 0.055)
			scene.box(rp, rs, Mats.brutal_steel(), false)
			t += 1.70


func _machine_room_light(at: Vector3, energy := 2.0) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(at.x,
		minf(ctx.ceiling_height - 1.05, 3.35), at.z)
	light.light_color = Color(0.42, 0.72, 0.92)
	light.light_energy = energy
	light.omni_range = 10.5
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	light.set_meta("data_center_aisle_light", true)
	scene.add_node(light)


func _rack_aisle(axis_x: bool) -> void:
	var span := scene.room_span()
	var long_span := span.x if axis_x else span.y
	var cross_span := span.y if axis_x else span.x
	var rack_lanes: Array[float] = []
	if cross_span > 18.0:
		# A 24m hall is one machine floor, not two sparse 12m islands. Ten rows
		# continue across the merge seam at an even 2m rhythm.
		var lane := 6.0 - cross_span * 0.5 + 2.70
		var last := 6.0 + cross_span * 0.5 - 2.70
		while lane <= last + 0.01:
			rack_lanes.append(lane)
			lane += 2.0
	else:
		rack_lanes.assign([2.70, 4.70, 7.30, 9.30])
	for row_index in rack_lanes.size():
		var lane: float = rack_lanes[row_index]
		# Rows close to the four concrete hall columns begin beyond the column
		# footprint; the other rows can use the whole dense run.
		var near_column := absf(lane - 1.70) < 0.95 \
			or absf(lane - 10.30) < 0.95
		_dense_rack_row(axis_x, lane, row_index % 2, long_span,
			3.25 if near_column else 1.25)
	# Guide and light every facing pair; the continuous transverse break through
	# all rows remains the cross-route even in ten-row merged rooms.
	for pair_start in range(0, rack_lanes.size() - 1, 2):
		var aisle_lane: float = (rack_lanes[pair_start] \
			+ rack_lanes[pair_start + 1]) * 0.5
		_aisle_floor_guides(axis_x, aisle_lane, long_span)
		_machine_room_light(
			Vector3(6.0, 0.0, aisle_lane) if axis_x \
			else Vector3(aisle_lane, 0.0, 6.0), 2.15)
	var cable_y := minf(ctx.ceiling_height - 1.05, 3.55)
	_overhead_busways(axis_x, rack_lanes, cable_y, long_span)


func _dense_rack_row(axis_x: bool, lane: float, side: int,
		long_span: float, end_inset := 1.25) -> void:
	# Four clusters plus two closed racks make each 12m row read almost
	# continuous. The deliberate 4m break around t=6 is the transverse service
	# aisle, so higher density never turns the room into an impassable wall.
	var rack_yaw := 0.0 if axis_x else PI * 0.5
	if side == 1:
		rack_yaw += PI
	var limits := [
		Vector2(6.0 - long_span * 0.5 + end_inset, 4.40),
		Vector2(7.60, 6.0 + long_span * 0.5 - end_inset),
	]
	for limit in limits:
		var points: Array[float] = []
		var t: float = float(limit.x)
		while t <= float(limit.y) + 0.01:
			var p := Vector3(t, 0.0, lane) if axis_x \
				else Vector3(lane, 0.0, t)
			_network_rack(p, rack_yaw)
			points.append(t)
			t += 3.05
		# The slim enclosed rack precisely fills the safe gap between the wider
		# three-frame network clusters, adding density and visible variation.
		for i in maxi(0, points.size() - 1):
			var middle: float = (points[i] + points[i + 1]) * 0.5
			var sp := Vector3(middle, 0.0, lane) if axis_x \
				else Vector3(lane, 0.0, middle)
			var variant := posmod(WorldGen.h(ctx.world_seed,
				ctx.cell.x + int(round(middle * 10.0)),
				ctx.cell.y + side, 2260), 3)
			match variant:
				0:
					_server_rack(sp, rack_yaw)
				1:
					_glass_server_rack(sp, rack_yaw)
				_:
					_azure_server_rack(sp, rack_yaw)


func _compact_server_field() -> void:
	# Huge edge openings can leave no perimeter safe from the generic doorway
	# approach cull. Build a compact machine island in the protected centre
	# instead. Its shared x=6 break is also the safe-arrival path on the zero cell,
	# so the player materializes among racks without materializing in one.
	var lanes := [4.10, 5.10, 6.10, 7.10, 8.10]
	var positions := [4.25, 5.25, 6.75, 7.75]
	for row_index in lanes.size():
		var lane: float = float(lanes[row_index])
		# Alternating pairs face their cold aisle. The fifth bank has no sixth
		# partner, so face it back toward the interior guide instead of presenting
		# four blank rear panels to the room.
		var yaw := PI if row_index % 2 == 1 \
			or row_index == lanes.size() - 1 else 0.0
		for position_index in positions.size():
			var t: float = float(positions[position_index])
			var p := Vector3(t, 0.0, lane)
			var variant := posmod(WorldGen.h(ctx.world_seed,
				ctx.cell.x + position_index, ctx.cell.y + row_index, 2280), 3)
			match variant:
				0:
					_server_rack(p, yaw)
				1:
					_glass_server_rack(p, yaw)
				_:
					_azure_server_rack(p, yaw)
	for guide_lane in [4.60, 6.60, 7.60]:
		_aisle_floor_guides(true, float(guide_lane), 5.6)
	_overhead_busways(true, lanes,
		minf(ctx.ceiling_height - 1.05, 3.55), 5.6)
	_machine_room_light(Vector3(6.0, 0.0, 4.60), 2.35)
	_machine_room_light(Vector3(6.0, 0.0, 7.60), 2.10)


func _emergency_beacon(at: Vector3) -> void:
	var y := minf(ctx.ceiling_height - 0.62, 3.45)
	var housing := scene.cylinder(Vector3(at.x, y, at.z), 0.18, 0.24,
		Mats.data_center_warning(), false)
	housing.set_meta("data_center_emergency_beacon", true)
	var light := OmniLight3D.new()
	light.position = Vector3(at.x, y - 0.10, at.z)
	light.light_color = Color(1.0, 0.045, 0.018)
	light.light_energy = 1.15
	light.omni_range = 6.5
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 16.0
	light.distance_fade_length = 6.0
	scene.add_node(light)


func _passage_server_rows(along_x: bool, side_data: Array[Dictionary]) -> void:
	# Passage cells are data aisles too: enclosed rack models form both walls,
	# with explicit cuts around every real side opening. Their shallow footprints
	# leave at least 1.4m clear through the middle of the 3.3m concrete shell.
	var base_yaw := 0.0 if along_x else PI * 0.5
	for entry in side_data:
		var side := float(entry["side"])
		var info: Dictionary = entry["info"]
		var segments: Array = [[0.58, WorldGen.CELL_SIZE - 0.58]]
		if not bool(info["wall"]):
			var width := clampf(float(info["w"]), 2.25, 3.40)
			var centre := clampf(float(info["t"]), width * 0.5 + 0.45,
				WorldGen.CELL_SIZE - width * 0.5 - 0.45)
			segments = scene.cut_segments(segments,
				centre - width * 0.5 - 0.42,
				centre + width * 0.5 + 0.42)
		var lane := 6.0 + side * 1.17
		var yaw := base_yaw + (PI if side > 0.0 else 0.0)
		for segment in segments:
			var t := float(segment[0]) + 0.48
			var last := float(segment[1]) - 0.48
			while t <= last + 0.01:
				var p := Vector3(t, 0.0, lane) if along_x \
					else Vector3(lane, 0.0, t)
				var variant := posmod(WorldGen.h(ctx.world_seed,
					ctx.cell.x + int(round(t * 10.0)),
					ctx.cell.y + (0 if side < 0.0 else 31), 2270), 3)
				var rack: Node3D
				match variant:
					0:
						rack = _server_rack(p, yaw)
					1:
						rack = _glass_server_rack(p, yaw)
					_:
						rack = _azure_server_rack(p, yaw)
				if rack != null:
					rack.set_meta("data_center_passage_rack", true)
					rack.set_meta("data_center_passage_side", int(signf(side)))
				t += 1.02


func _data_center_tunnel_dressing(along_x: bool) -> void:
	var cable_y := TUNNEL_HEIGHT - 0.45
	_overhead_busways(along_x, [5.28, 6.72], cable_y)


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
		side_data.append({
			"side": side,
			"dir": dir,
			"wall": bool(info["wall"]),
			"info": info,
		})
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
	_passage_server_rows(along_x, side_data)
	_data_center_tunnel_dressing(along_x)
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
	var axis_x := ctx.random01(2143) < 0.5
	_rack_aisle(axis_x)
	if ctx.random01(2140) < 0.58:
		_upper_gallery(ctx.random01(2141) < 0.5, -1.0 if ctx.random01(2142) < 0.5 else 1.0,
			minf(ctx.ceiling_height * 0.58, ctx.ceiling_height - 2.5))


func _brutal_gallery() -> void:
	_perimeter_columns()
	_maybe_brutal_annex_door(2204, 0.50)
	var axis_x := ctx.random01(2150) < 0.5
	_rack_aisle(axis_x)
	_upper_gallery(axis_x, -1.0, minf(3.65, ctx.ceiling_height - 2.2))
	if ctx.ceiling_height > 8.0:
		_upper_gallery(axis_x, 1.0, minf(6.9, ctx.ceiling_height - 2.2))


func _brutal_atrium() -> void:
	_perimeter_columns()
	_maybe_brutal_annex_door(2208, 0.34)
	if ctx.cell == Vector2i.ZERO:
		# Start inside the machine estate, not in a ceremonial empty lobby. Every
		# row shares the x=6 transverse break, which keeps the safe-arrival sweep
		# and a straight route out of the spawn while surrounding it with racks.
		_compact_server_field()
	else:
		_rack_aisle(ctx.random01(2161) < 0.5)
	var axis_x := ctx.random01(2160) < 0.5
	_upper_gallery(axis_x, -1.0, minf(3.8, ctx.ceiling_height - 2.4))
	_upper_gallery(not axis_x, 1.0, minf(7.1, ctx.ceiling_height - 2.4))
	_emergency_beacon(Vector3(6.0, 0.0, 6.0))


func _brutal_water_court() -> void:
	_maybe_brutal_annex_door(2212, 0.38)
	# The former reflecting court is now a server hall with cooling on its
	# service spine, never a room made exclusively from condensers. The normal
	# A compact room gets five rows; a merged hall gets ten full rack rows.
	var span := scene.room_span()
	if span.x > 18.0 or span.y > 18.0:
		_rack_aisle(true)
	else:
		_compact_server_field()
	# Two individual condenser variants sit at the room ends. Both clear the
	# nearest rack row while using the common x=6 transverse service break.
	var cross_min := 6.0 - span.y * 0.5
	var cross_max := 6.0 + span.y * 0.5
	_cooling_unit(Vector3(6.0, 0.0, cross_min + 1.18), 0.0, 0)
	_cooling_unit(Vector3(6.0, 0.0, cross_max - 1.18), PI, 2)
	_emergency_beacon(Vector3(6.0, 0.0, 6.0))


func _brutal_ramp() -> void:
	# This room used to contain nine ascending concrete blocks that resembled a
	# staircase but reached nothing. It is now a dense switching floor: continuous
	# server rows, a transverse service gap and overhead cable feeds.
	var along_x := ctx.random01(2170) < 0.5
	_rack_aisle(along_x)
	_emergency_beacon(Vector3(6.0, 0.0, 6.0))
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
	# Service rooms are still server rooms; the high pipe mains distinguish them
	# without sacrificing the floor to two token cabinets and empty concrete.
	_rack_aisle(axis_x)
	_machine_room_light(Vector3(6.0, 0.0, 6.0), 2.10)
	_emergency_beacon(Vector3(6.0, 0.0, 6.0))
	_maybe_brutal_annex_door(2220, 0.58)


func _brutal_sanctum() -> void:
	_maybe_brutal_annex_door(2224, 0.42)
	_rack_aisle(true)
	# One expensive hero rack anchors the far wall; the ordinary field does the
	# visual work everywhere else. The central transverse break keeps it clear.
	_detailed_server_rack(Vector3(6.0, 0.0, 10.90), PI)
	_machine_room_light(Vector3(6.0, 0.0, 6.0), 2.35)
	_emergency_beacon(Vector3(6.0, 0.0, 6.0))
	if ctx.ceiling_height > 8.2:
		_upper_gallery(true, -1.0, 4.0)
		_upper_gallery(true, 1.0, 7.2)
