extends "res://scripts/levels/chunk_level_builder.gd"
## Theme 11 — The Bloom.
##
## A dead civic campus remains legible beneath a wet vascular organism. Cold
## fluorescent fixtures describe the playable building; red is emitted only by
## visible wounds, incubators, and the storm outside. Cell-local surface growth
## is built with the structure pass so merged rooms never leave bare quadrants.

const BLOOM_PULSE_SCRIPT := preload("res://scripts/bloom_pulse.gd")
const BLOOM_FIXTURE_FLICKER_SCRIPT := preload(
	"res://scripts/bloom_fixture_flicker.gd")

const PASSAGE_HALF_WIDTH := 1.90
const PASSAGE_HEIGHT := 3.20
const PASSAGE_WALL_T := 0.18
const OPENING_HEAD := 2.55
const FIXTURE_SCALE := 1.34
const FIXTURE_VARIANTS := [
	"Fluorescent Lamp - Lowpoly 01",
	"Fluorescent Lamp - Lowpoly 02",
	"Fluorescent Lamp - Lowpoly 03",
	"Fluorescent Lamp - Lowpoly 04",
]
const FIXTURE_CENTRES := [
	Vector3(0.4000, 0.0, 0.5000),
	Vector3(-0.4500, 0.0, 0.0000),
	Vector3(0.4000, 0.0, -0.4000),
	Vector3(-0.1000, 0.0, 0.0000),
]
## Combined imported bounds. Keeping these offsets beside the placement code
## makes the CC BY scenes behave like authored modular props instead of staged
## Sketchfab dioramas with unpredictable origins.
const VINES_CENTRE := Vector3(0.593594, 2.021460, -0.205125)
const FLESH_FLOOR_OFFSET := Vector3(0.204127, 0.295808, -0.004298)

static var _vine_cylinder: CylinderMesh
static var _pine_roots_prototype: Node3D


func _vine_mesh() -> CylinderMesh:
	if _vine_cylinder == null:
		_vine_cylinder = CylinderMesh.new()
		_vine_cylinder.radial_segments = 7
		_vine_cylinder.rings = 1
		_vine_cylinder.height = 2.0
		_vine_cylinder.top_radius = 0.34
		_vine_cylinder.bottom_radius = 0.5
	return _vine_cylinder


func _vine_segment(parent: Node3D, a: Vector3, b: Vector3, radius: float,
		mat: Material = null) -> MeshInstance3D:
	var d := b - a
	if d.length_squared() < 0.0004:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _vine_mesh()
	mi.material_override = Mats.bloom_growth() if mat == null else mat
	mi.position = (a + b) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())
	mi.scale = Vector3(radius / 0.5, d.length() / 2.0, radius / 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.set_meta("bloom_growth", true)
	parent.add_child(mi)
	return mi


func _vine_path(parent: Node3D, points: Array[Vector3], radius: float,
		taper := 0.72, mat: Material = null) -> void:
	for i in range(points.size() - 1):
		var t := float(i) / maxf(1.0, float(points.size() - 2))
		_vine_segment(parent, points[i], points[i + 1],
			radius * lerpf(1.0, taper, t), mat)


func _growth_root(tag: String) -> Node3D:
	var root := Node3D.new()
	root.name = tag
	root.set_meta("bloom_growth_root", true)
	chunk.add_child(root)
	return root


func _bloom_floor_ceiling() -> void:
	chunk._box(Vector3(6.0, -0.16, 6.0), Vector3(12.0, 0.32, 12.0),
		Mats.bloom_floor())
	chunk._box(Vector3(6.0, chunk.ceil_h + 0.18, 6.0),
		Vector3(12.0, 0.36, 12.0), Mats.bloom_ceiling())
	# Patchy standing water keeps the references' wet reflections without
	# changing locomotion or turning every room into a perfect mirror.
	if chunk.style != WorldGen.BLOOM_PASSAGE:
		var puddle_x := 2.3 + chunk._r(3100) * 5.4
		var puddle_z := 2.0 + chunk._r(3101) * 5.8
		var puddle := chunk._box(
			Vector3(6.0 + (chunk._r(3102) - 0.5) * 2.4, 0.012,
				6.0 + (chunk._r(3103) - 0.5) * 2.4),
			Vector3(puddle_x, 0.018, puddle_z), Mats.bloom_wet(), false)
		puddle.set_meta("bloom_puddle", true)
	# A biased canopy: one strong ceiling silhouette, then only a few secondary
	# strands. All reachable clearances remain above 2.25m.
	var root := _growth_root("BloomCanopy")
	var side := -1.0 if chunk._r(3110) < 0.5 else 1.0
	var corner_x := 1.0 if side < 0.0 else 11.0
	var corner_z := 1.0 if chunk._r(3111) < 0.5 else 11.0
	var y := maxf(2.30, chunk.ceil_h - 0.34)
	_vine_path(root, [
		Vector3(corner_x, y - 0.35, corner_z),
		Vector3(lerpf(corner_x, 6.0, 0.36), y + 0.04,
			lerpf(corner_z, 6.0, 0.18)),
		Vector3(lerpf(corner_x, 6.0, 0.70), y - 0.07,
			lerpf(corner_z, 6.0, 0.42)),
		Vector3(6.0 + side * 1.35, y + 0.08,
			6.0 + (chunk._r(3112) - 0.5) * 2.0),
	], 0.19 + chunk._r(3113) * 0.11)
	for i in 3:
		var start := Vector3(corner_x, y - 0.10,
			clampf(corner_z + (float(i) - 1.0) * 0.55, 0.7, 11.3))
		var end := Vector3(clampf(corner_x + side * -1.0 * (1.6 + i * 0.75),
			0.7, 11.3), y - 0.12 - i * 0.05,
			clampf(corner_z + (chunk._r(3120 + i) - 0.5) * 2.8, 0.7, 11.3))
		_vine_path(root, [start, (start + end) * 0.5 + Vector3(0, 0.13, 0), end],
			0.055 + i * 0.012, 0.56)
	# A single real thorn canopy is the visual anchor; the small generated
	# strands above merely stitch it into the room. Large merged rooms instance
	# it only on their furnishing anchor so it never repeats per quadrant.
	if chunk.style != WorldGen.BLOOM_PASSAGE and chunk.is_room_anchor \
			and chunk._r(3136) < 0.72:
		_authored_vines(Vector3(6.0, chunk.ceil_h - 0.42, 6.0),
			Vector3(PI, chunk._r(3137) * TAU, 0.0),
			0.24 + chunk._r(3138) * 0.06, "ceiling_canopy")


func _bloom_wall_growth(dir: int, plane: float) -> void:
	var root := _growth_root("BloomWallGrowth%d" % dir)
	var inward := -1.0 if dir == 0 or dir == 2 else 1.0
	var face := plane + inward * (chunk.T * 0.5 + 0.045)
	var along0 := 1.3 + chunk._r(3160 + dir * 17) * 9.4
	var along1 := clampf(along0 + (chunk._r(3161 + dir * 17) - 0.5) * 4.0,
		0.75, 11.25)
	var p0 := Vector3(face, 0.08, along0) if dir < 2 \
		else Vector3(along0, 0.08, face)
	var p1 := Vector3(face, minf(chunk.ceil_h - 0.24, 2.15), along1) if dir < 2 \
		else Vector3(along1, minf(chunk.ceil_h - 0.24, 2.15), face)
	var p2 := Vector3(face, chunk.ceil_h - 0.18,
		clampf(along1 + (chunk._r(3162 + dir * 17) - 0.5) * 2.2, 0.6, 11.4)) \
		if dir < 2 else Vector3(
			clampf(along1 + (chunk._r(3162 + dir * 17) - 0.5) * 2.2, 0.6, 11.4),
			chunk.ceil_h - 0.18, face)
	var bend := (p0 + p1) * 0.5
	if dir < 2:
		bend.x += inward * 0.10
	else:
		bend.z += inward * 0.10
	_vine_path(root, [p0, bend, p1, p2], 0.105 + chunk._r(3163 + dir) * 0.10)
	for branch in 2:
		var by := 0.72 + branch * 0.72
		var bp := Vector3(face, by, along1) if dir < 2 else Vector3(along1, by, face)
		var bend_along := clampf(along1 + (-1.0 if branch == 0 else 1.0) \
			* (1.15 + chunk._r(3170 + dir * 7 + branch) * 1.8), 0.55, 11.45)
		var ep := Vector3(face, by + 0.24, bend_along) if dir < 2 \
			else Vector3(bend_along, by + 0.24, face)
		_vine_path(root, [bp, (bp + ep) * 0.5 + Vector3(0, 0.14, 0), ep],
			0.045, 0.54)
	# Familiar architecture swallowed by the organism. This is a sealed facade
	# on a wall, never a navigation cue.
	if chunk._r(3190 + dir) < 0.11:
		var door_p := Vector3(face + inward * 0.04, 0.0, 6.0) if dir < 2 \
			else Vector3(6.0, 0.0, face + inward * 0.04)
		_bloom_annex_door_at(door_p, chunk._wall_facing(dir))


func _passage_box(pos: Vector3, size: Vector3, part: String,
		collide := true) -> MeshInstance3D:
	var mesh := chunk._box(pos, size, Mats.bloom_wall(), collide)
	mesh.set_meta("bloom_passage_part", part)
	return mesh


func _bloom_passage() -> void:
	var along_x := WorldGen.corridor(chunk.wseed, chunk.cell) != 2
	var lid_size := Vector3(12.0, 0.22, PASSAGE_HALF_WIDTH * 2.0) if along_x \
		else Vector3(PASSAGE_HALF_WIDTH * 2.0, 0.22, 12.0)
	_passage_box(Vector3(6.0, PASSAGE_HEIGHT + 0.11, 6.0), lid_size,
		"ceiling")
	var side_data: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var dir := (3 if side < 0.0 else 2) if along_x \
			else (1 if side < 0.0 else 0)
		var info := chunk._edge_info(chunk.cell, dir)
		_passage_side(along_x, side, dir, info)
		side_data.append({"side": side, "wall": bool(info["wall"])})
	var preferred := 0 if chunk._r(3204) < 0.5 else 1
	for attempt in 2:
		var entry: Dictionary = side_data[(preferred + attempt) % 2]
		if bool(entry["wall"]):
			_passage_lockers(along_x, float(entry["side"]))
			break
	if chunk._r(3207) < 0.42:
		var roots := _pine_roots(
			Vector3(6.0, PASSAGE_HEIGHT - 0.02, 6.0 + \
				(-1.0 if chunk._r(3208) < 0.5 else 1.0) * 0.72) if along_x \
			else Vector3(6.0 + (-1.0 if chunk._r(3208) < 0.5 else 1.0) * 0.72,
				PASSAGE_HEIGHT - 0.02, 6.0),
			chunk._r(3209) * TAU, 2.45)
		if roots != null:
			roots.rotation.x = PI
			roots.set_meta("bloom_passage_authored_roots", true)
	# The real thorn cluster breaks the old tube-spline silhouette. It is
	# centred high enough to preserve a 2.25m traversal envelope.
	if chunk._r(3206) < 0.78:
		var thorn_pos := Vector3(6.0, PASSAGE_HEIGHT - 0.30,
			6.0 + (-1.0 if chunk._r(3205) < 0.5 else 1.0) * 0.52) \
			if along_x else Vector3(
				6.0 + (-1.0 if chunk._r(3205) < 0.5 else 1.0) * 0.52,
				PASSAGE_HEIGHT - 0.30, 6.0)
		_authored_vines(thorn_pos,
			Vector3(PI, chunk._r(3203) * TAU, 0.0), 0.17,
			"passage_thorns")
	# Dense ribs produce a real tunnel rhythm. Tendrils stay above eye line.
	for i in 6:
		var t := 0.75 + float(i) * 2.10
		var p := Vector3(t, PASSAGE_HEIGHT - 0.12, 6.0) if along_x \
			else Vector3(6.0, PASSAGE_HEIGHT - 0.12, t)
		var s := Vector3(0.12, 0.18, PASSAGE_HALF_WIDTH * 2.0) if along_x \
			else Vector3(PASSAGE_HALF_WIDTH * 2.0, 0.18, 0.12)
		_passage_box(p, s, "ceiling_rib", false)
	var growth := _growth_root("BloomPassageVeins")
	var wall_side := -1.0 if chunk._r(3210) < 0.5 else 1.0
	var points: Array[Vector3] = []
	for i in 7:
		var t := float(i) * 2.0
		var sway := (chunk._r(3214 + i) - 0.5) * 0.44
		points.append(Vector3(t, 2.55 + sin(float(i) * 1.4) * 0.20,
			6.0 + wall_side * (1.58 + sway)) if along_x else
			Vector3(6.0 + wall_side * (1.58 + sway),
				2.55 + sin(float(i) * 1.4) * 0.20, t))
	_vine_path(growth, points, 0.095, 0.52)
	for i in 6:
		var start: Vector3 = points[i]
		var across := -wall_side * (0.65 + chunk._r(3230 + i) * 1.25)
		var end := start + (Vector3(0.45 + chunk._r(3240 + i) * 0.8,
			0.46 + chunk._r(3250 + i) * 0.24, across) if along_x else
			Vector3(across, 0.46 + chunk._r(3250 + i) * 0.24,
				0.45 + chunk._r(3240 + i) * 0.8))
		end.y = minf(PASSAGE_HEIGHT - 0.10, end.y)
		_vine_path(growth, [start,
			(start + end) * 0.5 + Vector3(0, 0.12, 0), end],
			0.030 + chunk._r(3260 + i) * 0.028, 0.44)


func _passage_lockers(along_x: bool, side: float) -> void:
	# One continuous locker wall makes the tunnel a corrupted school rather
	# than an abstract service passage. It is only placed on a solid side.
	var plane := 6.0 + side * PASSAGE_HALF_WIDTH
	var centre_across := plane - side * 0.24
	var facing := -side
	var yaw := (0.0 if facing > 0.0 else PI) if along_x else \
		(PI * 0.5 if facing > 0.0 else -PI * 0.5)
	for i in 5:
		var t := 1.06 + float(i) * chunk.LOCKERS_RUN_W
		var p := Vector3(t, 0, centre_across) if along_x \
			else Vector3(centre_across, 0, t)
		var b0 := chunk.body.get_child_count()
		var bank := chunk._attributed_floor_prop(chunk.LOCKERS_PATH, p, yaw,
			chunk.LOCKERS_SCALE, chunk.LOCKERS_CENTRE,
			"bloom_locker_bank", null, true)
		if bank == null:
			continue
		bank.set_meta("bloom_corrupted_lockers", true)
		var size := Vector3(chunk.LOCKERS_RUN_W, 1.85, 0.48) if along_x \
			else Vector3(0.48, 1.85, chunk.LOCKERS_RUN_W)
		chunk._collider_box(p + Vector3(0, 0.925, 0), size)
		chunk._bind_furnishing_colliders(bank, b0)


func _passage_side(along_x: bool, side: float, _dir: int,
		info: Dictionary) -> void:
	var plane := 6.0 + side * PASSAGE_HALF_WIDTH
	if bool(info["wall"]):
		_passage_box(
			Vector3(6.0, PASSAGE_HEIGHT * 0.5, plane) if along_x \
				else Vector3(plane, PASSAGE_HEIGHT * 0.5, 6.0),
			Vector3(12.0, PASSAGE_HEIGHT, PASSAGE_WALL_T) if along_x \
				else Vector3(PASSAGE_WALL_T, PASSAGE_HEIGHT, 12.0), "side_wall")
		return
	var width := clampf(float(info["w"]), 1.85, 3.35)
	var centre := clampf(float(info["t"]), width * 0.5 + 0.42,
		12.0 - width * 0.5 - 0.42)
	var a := centre - width * 0.5
	var b := centre + width * 0.5
	for interval in [[0.0, a], [b, 12.0]]:
		var lo := float(interval[0])
		var hi := float(interval[1])
		if hi - lo < 0.02:
			continue
		_passage_box(
			Vector3((lo + hi) * 0.5, PASSAGE_HEIGHT * 0.5, plane) if along_x \
				else Vector3(plane, PASSAGE_HEIGHT * 0.5, (lo + hi) * 0.5),
			Vector3(hi - lo, PASSAGE_HEIGHT, PASSAGE_WALL_T) if along_x \
				else Vector3(PASSAGE_WALL_T, PASSAGE_HEIGHT, hi - lo), "side_wall")
	var hh := PASSAGE_HEIGHT - OPENING_HEAD
	_passage_box(
		Vector3(centre, OPENING_HEAD + hh * 0.5, plane) if along_x \
			else Vector3(plane, OPENING_HEAD + hh * 0.5, centre),
		Vector3(width, hh, PASSAGE_WALL_T) if along_x \
			else Vector3(PASSAGE_WALL_T, hh, width), "opening_header")
	var outer := 12.0 - chunk.T if side > 0.0 else chunk.T
	var depth := absf(outer - plane)
	var mid := (outer + plane) * 0.5
	for edge in [a, b]:
		_passage_box(
			Vector3(edge, PASSAGE_HEIGHT * 0.5, mid) if along_x \
				else Vector3(mid, PASSAGE_HEIGHT * 0.5, edge),
			Vector3(PASSAGE_WALL_T, PASSAGE_HEIGHT, depth) if along_x \
				else Vector3(depth, PASSAGE_HEIGHT, PASSAGE_WALL_T), "return")
	_passage_box(
		Vector3(centre, PASSAGE_HEIGHT + 0.10, mid) if along_x \
			else Vector3(mid, PASSAGE_HEIGHT + 0.10, centre),
		Vector3(width, 0.20, depth) if along_x \
			else Vector3(depth, 0.20, width), "return_ceiling")


func _bloom_fixture(at: Vector3, yaw: float, variant: int,
		dead: bool, flicker: bool,
		emission_mats: Array[StandardMaterial3D],
		fixture_lights: Array[Light3D]) -> Node3D:
	variant = clampi(variant, 0, 3)
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = yaw
	pivot.set_meta("bloom_fluorescent_fixture", true)
	chunk.add_child(pivot)
	var centre: Vector3 = FIXTURE_CENTRES[variant]
	var inst := chunk._attributed_prop_local(pivot, chunk.BRUTAL_LIGHT_PATH,
		Vector3(-centre.x * FIXTURE_SCALE, 0.0, -centre.z * FIXTURE_SCALE),
		0.0, Vector3.ONE * FIXTURE_SCALE)
	if inst == null:
		chunk._mbox(pivot, Vector3.ZERO, Vector3(2.35, 0.06, 0.22),
			Mats.panel_dead() if dead else Mats.bloom_panel())
	else:
		var selected: Node3D
		for i in FIXTURE_VARIANTS.size():
			var candidate := inst.find_child(FIXTURE_VARIANTS[i], true, false) as Node3D
			if candidate == null:
				continue
			candidate.visible = i == variant
			if i == variant:
				selected = candidate
		if selected != null and (dead or flicker):
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
					local.emission_energy_multiplier = 0.0 if dead else 2.7
					mesh_node.set_surface_override_material(surface, local)
					if flicker:
						emission_mats.append(local)
	if not dead:
		# The only routine Bloom light lives inside this visible tube housing.
		# Its wide, short falloff overlaps neighboring fixtures without producing
		# the old hard-edged pools from detached room lights.
		var light := OmniLight3D.new()
		light.position = Vector3(0.0, -0.075, 0.0)
		light.light_color = Color(0.68, 0.80, 0.94)
		light.light_energy = 1.54
		light.omni_range = 8.2
		light.omni_attenuation = 0.72
		light.shadow_enabled = true
		light.light_volumetric_fog_energy = 0.36
		light.set_meta("bloom_fixture_light", true)
		light.set_meta("visible_source", "fluorescent_fixture")
		pivot.add_child(light)
		fixture_lights.append(light)
	return pivot


func _bloom_lighting() -> void:
	var dead := chunk.cell != Vector2i.ZERO and chunk._r(3300) < 0.08
	var flicker := not dead and chunk.cell != Vector2i.ZERO \
		and chunk._r(3301) < 0.14
	var emission_mats: Array[StandardMaterial3D] = []
	var fixture_lights: Array[Light3D] = []
	var passage := chunk.style == WorldGen.BLOOM_PASSAGE
	var axis_x := WorldGen.corridor(chunk.wseed, chunk.cell) != 2
	var y := PASSAGE_HEIGHT - 0.02 if passage else chunk.ceil_h - 0.025
	var fixture_positions: Array[Vector3] = []
	if passage:
		for t in [2.0, 6.0, 10.0]:
			fixture_positions.append(Vector3(t, y, 6.0) if axis_x \
				else Vector3(6.0, y, t))
	else:
		# Corner-weighted layout keeps a central flesh mass from swallowing the
		# entire room's illumination, and every pool still has a visible housing.
		for xz in [Vector2(3.0, 3.0), Vector2(9.0, 3.0),
				Vector2(3.0, 9.0), Vector2(9.0, 9.0)]:
			fixture_positions.append(Vector3(xz.x, y, xz.y))
	var fixture_pivots: Array[Node3D] = []
	for i in fixture_positions.size():
		var p: Vector3 = fixture_positions[i]
		fixture_pivots.append(_bloom_fixture(p,
			PI * 0.5 if axis_x else 0.0,
			posmod(i + int(chunk._r(3305 + i) * 4.0), 4),
			dead, flicker, emission_mats, fixture_lights))
	# Four overlapping shadowed omni lights multiply this room's geometry into
	# thousands of shadow draws. One real shadow source preserves contact and
	# silhouette depth; the remaining visible fixtures still provide fill.
	if fixture_lights.size() > 1:
		var shadow_index := 1 if passage else int(chunk._r(3317) \
			* float(fixture_lights.size())) % fixture_lights.size()
		for i in fixture_lights.size():
			fixture_lights[i].shadow_enabled = i == shadow_index
	if flicker and not emission_mats.is_empty():
		var controller = BLOOM_FIXTURE_FLICKER_SCRIPT.new()
		controller.mats = emission_mats
		controller.lights = fixture_lights
		controller.rng_seed = WorldGen.h(chunk.wseed,
			chunk.cell.x, chunk.cell.y, 3318)
		var buzz := AudioStreamPlayer3D.new()
		buzz.stream = SoundBank.buzz()
		buzz.unit_size = 3.0
		buzz.max_distance = 15.0
		buzz.volume_db = -26.0
		buzz.bus = SoundBank.HALL_BUS
		buzz.autoplay = true
		buzz.position = fixture_pivots[0].position if not fixture_pivots.is_empty() \
			else Vector3(6.0, y, 6.0)
		chunk.add_child(buzz)
		controller.buzz = buzz
		chunk.add_child(controller)
	# There are no free-standing Bloom lights. Each routine light is parented to
	# a visible fluorescent fixture so the illumination can never lose its source.
	_bloom_spores()


func _bloom_spores() -> void:
	_bloom_particle_layer("bloom_micro_flakes",
		96 if chunk.style == WorldGen.BLOOM_PASSAGE else \
			(190 if chunk.room_n >= 4 else 156),
		0.032, 0.08, 0.55, 0.025, 0.095, 58.0)
	_bloom_particle_layer("bloom_spores",
		42 if chunk.style == WorldGen.BLOOM_PASSAGE else \
			(86 if chunk.room_n >= 4 else 68),
		0.060, 0.12, 1.05, 0.030, 0.105, 42.0)
	_bloom_particle_layer("bloom_flakes",
		12 if chunk.style == WorldGen.BLOOM_PASSAGE else \
			(26 if chunk.room_n >= 4 else 19),
		0.205, 0.18, 2.55, 0.018, 0.075, 18.0)


func _bloom_particle_layer(tag: String, amount: int, quad_size: float,
		scale_min: float, scale_max: float, speed_min: float, speed_max: float,
		spin: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 14.0
	particles.randomness = 0.88
	particles.visibility_aabb = AABB(Vector3(-6, -3, -6),
		Vector3(12, chunk.ceil_h + 6.0, 12))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(5.4, maxf(1.0, chunk.ceil_h * 0.42), 5.4)
	process.direction = Vector3(0.12, -0.32, 0.08)
	process.spread = 180.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = Vector3(0, -0.010, 0)
	process.damping_min = 0.012
	process.damping_max = 0.040
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -spin
	process.angular_velocity_max = spin
	process.anim_offset_min = 0.0
	process.anim_offset_max = 1.0
	process.anim_speed_min = 0.0
	process.anim_speed_max = 0.0
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * quad_size
	quad.material = Mats.bloom_spore()
	particles.draw_pass_1 = quad
	particles.position = Vector3(6.0, chunk.ceil_h * 0.48, 6.0)
	particles.set_meta(tag, true)
	chunk.add_child(particles)


func _bloom_annex_door_at(pos: Vector3, yaw: float) -> bool:
	var pivot := chunk._furnishing_pivot(pos, yaw,
		"bloom_annex_exit_door", true)
	pivot.set_meta("bloom_swallowed_door", true)
	pivot.set_meta("locked_facade", true)
	var authored := chunk._attributed_prop_local(pivot,
		chunk.ANNEX_EXIT_DOOR_PATH, Vector3.ZERO, 0.0)
	if authored == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return false
	authored.set_meta("authored_model", "bloom_annex_exit_door")
	return true


func _pine_roots(pos: Vector3, yaw: float, scale: float) -> Node3D:
	var started := Time.get_ticks_usec()
	if _pine_roots_prototype == null:
		var ps := chunk._prop_scene(chunk.BLOOM_ROOT_PATH)
		if ps == null:
			return null
		_pine_roots_prototype = ps.instantiate() as Node3D
		if _pine_roots_prototype == null:
			return null
		for found in _pine_roots_prototype.find_children(
				"*", "MeshInstance3D", true, false):
			(found as MeshInstance3D).material_override = Mats.bloom_growth()
	var inst := _pine_roots_prototype.duplicate() as Node3D
	if inst == null:
		return null
	inst.position = pos
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * scale
	inst.set_meta("cc0_asset", "pine_roots")
	inst.set_meta("bloom_hero_roots", true)
	chunk.add_child(inst)
	chunk._profile_stage("bloom_pine_roots", started)
	return inst


static func clear_runtime_cache() -> void:
	if _pine_roots_prototype != null:
		_pine_roots_prototype.free()
	_pine_roots_prototype = null


func _authored_vines(pos: Vector3, rotation: Vector3, scale: float,
		tag: String) -> Node3D:
	var started := Time.get_ticks_usec()
	var pivot := Node3D.new()
	pivot.name = "AuthoredThornMass"
	pivot.position = pos
	pivot.rotation = rotation
	pivot.set_meta("bloom_authored_vines", tag)
	chunk.add_child(pivot)
	var inst := chunk._attributed_prop_local(pivot, chunk.BLOOM_VINES_PATH,
		-VINES_CENTRE * scale, 0.0, Vector3.ONE * scale)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	inst.set_meta("authored_model", "modular_vines")
	for found in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		mesh_node.material_override = Mats.bloom_growth()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk._profile_stage("bloom_authored_vines:" + tag, started)
	return pivot


func _authored_flesh_blob(pos: Vector3, yaw: float, scale: float,
		tag: String, phase: float) -> Node3D:
	# The source scene contains staging floor/wall meshes around its creature.
	# Hide only those two nodes, preserve the actual three-material blob, and
	# keep its four morph tracks running. A tiny outer scale pulse supplies a
	# second, slower beat without overpowering the authored deformation.
	var pulse := BLOOM_PULSE_SCRIPT.new() as Node3D
	pulse.name = "AuthoredFleshBlob"
	pulse.position = pos
	pulse.rotation.y = yaw
	pulse.scale = Vector3.ONE * scale
	pulse.rate = 0.82 + fmod(phase, 0.28)
	pulse.amplitude = 0.018
	pulse.phase = phase
	pulse.set_meta("bloom_authored_flesh", tag)
	chunk.add_child(pulse)
	var inst := chunk._attributed_prop_local(pulse,
		chunk.BLOOM_FLESH_BLOB_PATH, FLESH_FLOOR_OFFSET, 0.0)
	if inst == null:
		pulse.get_parent().remove_child(pulse)
		pulse.free()
		return null
	inst.set_meta("authored_model", "flesh_blob")
	for staged_name in ["Plane_0", "Plane_001_2"]:
		var staged := inst.find_child(staged_name, true, false) as Node3D
		if staged != null:
			staged.visible = false
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation("MorphBake"):
		var morph := player.get_animation("MorphBake")
		if morph != null:
			morph.loop_mode = Animation.LOOP_LINEAR
		player.play("MorphBake", -1.0, 0.72 + fmod(phase, 0.22))
		player.seek(fmod(phase * 1.37, 5.9), true)
	return pulse


func _root_column(pos: Vector3, height: float, radius := 0.34) -> void:
	chunk._box(pos + Vector3(0, height * 0.5, 0),
		Vector3(0.55, height, 0.55), Mats.bloom_wall())
	var growth := _growth_root("BloomRootColumn")
	for i in 5:
		var ang := float(i) * TAU / 5.0 + chunk._r(3400 + i) * 0.4
		var foot := pos + Vector3(cos(ang), 0.04, sin(ang)) * (0.48 + i * 0.04)
		var top := pos + Vector3(cos(ang + 0.7), height - 0.08,
			sin(ang + 0.7)) * (0.30 + i * 0.025)
		_vine_path(growth, [foot,
			lerp(foot, top, 0.48) + Vector3(cos(ang + 1.3), 0, sin(ang + 1.3)) * 0.22,
			top], radius * (0.55 + i * 0.08), 0.70)


func _bloom_commons() -> void:
	# Arrival and portal style: a 4x4m centre stays absolutely clear.
	for p in [Vector3(1.35, 0, 1.35), Vector3(10.65, 0, 1.35),
			Vector3(1.35, 0, 10.65), Vector3(10.65, 0, 10.65)]:
		_root_column(p, chunk.ceil_h, 0.22)
	for z in [1.05, 10.95]:
		chunk._box(Vector3(6.0, 0.32, z), Vector3(3.2, 0.18, 0.58),
			Mats.bloom_metal())
		for x in [4.65, 7.35]:
			chunk._box(Vector3(x, 0.16, z), Vector3(0.12, 0.32, 0.48),
				Mats.bloom_metal())


func _bloom_classroom() -> void:
	# Four displaced school desks preserve an institutional read while leaving
	# the centre lane and every doorway approach clear.
	for data in [
		[Vector3(2.0, 0, 2.0), 0.24], [Vector3(9.8, 0, 2.2), -0.38],
		[Vector3(2.2, 0, 9.8), PI + 0.22], [Vector3(9.7, 0, 9.6), PI - 0.28],
	]:
		var p: Vector3 = data[0]
		var b0 := chunk.body.get_child_count()
		var pivot := chunk._attributed_floor_prop(chunk.SCH_DESK_PATH, p,
			float(data[1]) + chunk.SCH_DESK_YAW_FIX, chunk.SCH_DESK_SCALE,
			chunk.SCH_DESK_CENTRE, "bloom_school_desk", null, chunk.descent)
		if pivot != null:
			pivot.set_meta("bloom_displaced_furniture", true)
			if chunk.descent:
				chunk._collider_yaw_box(p + Vector3(0, 0.42, 0),
					Vector3(0.80, 0.84, 0.96), float(data[1]))
				chunk._bind_furnishing_colliders(pivot, b0)
	var board := chunk._box(Vector3(6.0, 1.62, 11.72),
		Vector3(5.4, 1.50, 0.09), Mats.bloom_metal(), false)
	board.set_meta("bloom_infected_board", true)
	var seam := chunk._box(Vector3(6.0, 1.60, 11.65),
		Vector3(3.8, 0.045, 0.025), Mats.bloom_red(), false)
	seam.set_meta("bloom_red_seam", true)


func _incubator_pod(pos: Vector3, scale: Vector3, phase: float) -> void:
	var pulse := BLOOM_PULSE_SCRIPT.new() as Node3D
	pulse.position = pos
	pulse.scale = scale
	pulse.rate = 1.35 + phase * 0.17
	pulse.amplitude = 0.035
	pulse.phase = phase
	pulse.set_meta("bloom_incubator", true)
	chunk.add_child(pulse)
	chunk._mellipsoid(pulse, Vector3(0, 0.88, 0), Vector3(0.52, 0.88, 0.52),
		Mats.bloom_flesh())
	chunk._mellipsoid(pulse, Vector3(0, 0.93, 0), Vector3(0.34, 0.61, 0.34),
		Mats.bloom_red())
	for i in 5:
		var a := float(i) * TAU / 5.0
		chunk._mbeam(pulse,
			Vector3(cos(a) * 0.56, 0.05, sin(a) * 0.56),
			Vector3(cos(a) * 0.44, 1.72, sin(a) * 0.44), 0.026,
			Mats.bloom_metal())


func _bloom_incubator() -> void:
	var table := chunk._attributed_floor_prop(chunk.SCH_CHEMISTRY_TABLE_PATH,
		Vector3(2.2, 0, 6.0), PI * 0.5, chunk.SCH_CHEMISTRY_TABLE_SCALE,
		chunk.SCH_CHEMISTRY_TABLE_CENTRE, "bloom_lab_table")
	if table != null:
		table.set_meta("bloom_abandoned_lab", true)
	_incubator_pod(Vector3(9.6, 0, 2.1), Vector3.ONE * 1.05, 0.3)
	_incubator_pod(Vector3(9.3, 0, 9.5), Vector3.ONE * 0.86, 1.9)
	if chunk.room_n >= 2:
		_incubator_pod(Vector3(6.0, 0, 10.2), Vector3.ONE * 0.74, 3.2)
	_authored_flesh_blob(Vector3(11.05, 0.02, 6.2), -PI * 0.5, 0.27,
		"lab_wall_lesion", chunk._r(3492) * TAU)


func _bloom_nest() -> void:
	var root := _growth_root("BloomSporeNest")
	for i in 9:
		var ang := float(i) * TAU / 9.0 + chunk._r(3500 + i) * 0.34
		var rad := 2.7 + chunk._r(3520 + i) * 1.45
		var top := Vector3(6.0 + cos(ang) * rad, chunk.ceil_h - 0.12,
			6.0 + sin(ang) * rad)
		var hang := 0.34 + chunk._r(3540 + i) * minf(1.45, chunk.ceil_h - 2.20)
		var end := top - Vector3(0, hang, 0)
		_vine_path(root, [top, end], 0.035 + chunk._r(3560 + i) * 0.045, 0.62)
		var pulse := BLOOM_PULSE_SCRIPT.new() as Node3D
		pulse.position = end
		pulse.scale = Vector3.ONE * (0.55 + chunk._r(3580 + i) * 0.45)
		pulse.rate = 0.8 + chunk._r(3590 + i) * 0.8
		pulse.phase = chunk._r(3600 + i) * TAU
		pulse.amplitude = 0.045
		chunk.add_child(pulse)
		chunk._mellipsoid(pulse, Vector3.ZERO, Vector3(0.28, 0.42, 0.28),
			Mats.bloom_flesh())
		if i % 3 == 0:
			chunk._mellipsoid(pulse, Vector3(0, -0.04, 0), Vector3(0.13, 0.22, 0.13),
				Mats.bloom_red())
	_authored_vines(Vector3(6.0, chunk.ceil_h - 0.46, 6.0),
		Vector3(PI, chunk._r(3610) * TAU, 0.0), 0.31, "spore_nest_crown")


func _bloom_atrium() -> void:
	# A black flooded basin with a readable dry causeway and a root forest at
	# the corners. In a 2x2 room the anchor pass is shifted to the true centre.
	chunk._box(Vector3(6.0, 0.025, 6.0), Vector3(9.3, 0.035, 7.4),
		Mats.bloom_wet(), false)
	chunk._box(Vector3(6.0, 0.09, 6.0), Vector3(2.15, 0.15, 10.2),
		Mats.bloom_wall())
	for edge_x in [4.94, 7.06]:
		chunk._box(Vector3(edge_x, 0.175, 6.0), Vector3(0.035, 0.022, 9.8),
			Mats.bloom_panel(), false)
	for p in [Vector3(1.65, 0, 1.65), Vector3(10.35, 0, 1.65),
			Vector3(1.65, 0, 10.35), Vector3(10.35, 0, 10.35)]:
		_root_column(p, chunk.ceil_h, 0.42)
	_pine_roots(Vector3(6.0, 0.02, 6.0), chunk._r(3650) * TAU, 2.35)
	_authored_flesh_blob(Vector3(6.0, 0.02, 10.72), PI, 0.56,
		"atrium_wall_mass", chunk._r(3651) * TAU)
	_authored_vines(Vector3(6.0, chunk.ceil_h - 0.65, 7.4),
		Vector3(PI, chunk._r(3652) * TAU, 0.0), 0.36, "atrium_crown")


func _bleachers(base: Vector3, yaw: float, swallowed: bool) -> void:
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	root.set_meta("bloom_bleachers", true)
	chunk.add_child(root)
	for i in 5:
		chunk._mbox(root, Vector3(0, 0.16 + i * 0.24, i * 0.42),
			Vector3(6.8, 0.14, 0.52), Mats.bloom_metal())
	if swallowed:
		for i in 5:
			_vine_path(root, [Vector3(-3.2 + i * 1.55, 0, -0.28),
				Vector3(-2.7 + i * 1.35, 1.0, 0.78),
				Vector3(-2.2 + i * 1.08, 1.65, 1.15)],
				0.075 + i * 0.018, 0.64)


func _basketball_hoop(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	root.set_meta("bloom_hoop", true)
	chunk.add_child(root)
	chunk._mbox(root, Vector3(0, 2.3, 0), Vector3(0.10, 4.6, 0.10),
		Mats.bloom_metal())
	chunk._mbox(root, Vector3(0, 4.05, 0.42), Vector3(1.55, 0.95, 0.08),
		Mats.bloom_wall())
	var rim := TorusMesh.new()
	rim.inner_radius = 0.28
	rim.outer_radius = 0.33
	var mi := MeshInstance3D.new()
	mi.mesh = rim
	mi.material_override = Mats.bloom_red()
	mi.position = Vector3(0, 3.75, 0.92)
	root.add_child(mi)


func _bloom_gym() -> void:
	var court := chunk._box(Vector3(6.0, 0.018, 6.0), Vector3(10.4, 0.026, 10.4),
		Mats.bloom_wet(), false)
	court.set_meta("bloom_drowned_court", true)
	# Dim court markings still read through the water.
	for z in [1.15, 6.0, 10.85]:
		chunk._box(Vector3(6.0, 0.042, z), Vector3(10.0, 0.012, 0.045),
			Mats.bloom_panel(), false)
	_bleachers(Vector3(6.0, 0, 1.05), 0.0, true)
	_bleachers(Vector3(6.0, 0, 10.95), PI, false)
	_basketball_hoop(Vector3(6.0, 0, 2.15), 0.0)
	_basketball_hoop(Vector3(6.0, 0, 9.85), PI)
	_authored_flesh_blob(Vector3(2.05, 0.02, 1.62), 0.26, 0.38,
		"bleacher_overgrowth", chunk._r(3690) * TAU)
	_authored_vines(Vector3(7.4, 1.15, 1.82), Vector3(0.0, -0.18, 0.0),
		0.23, "swallowed_bleachers")


func _bloom_heart() -> void:
	var heart_body := _authored_flesh_blob(Vector3(6.0, 0.03, 6.0),
		chunk._r(3699) * TAU, 0.62, "heart_body", chunk._r(3700) * TAU)
	if heart_body != null:
		heart_body.set_meta("bloom_heart", true)
	var heart_core := Vector3(6.0, minf(1.82, chunk.ceil_h * 0.34), 5.72)
	var roots := _growth_root("BloomHeartCage")
	for i in 8:
		var ang := float(i) * TAU / 8.0
		var floor_p := Vector3(6.0 + cos(ang) * 3.35, 0.05,
			6.0 + sin(ang) * 3.35)
		var shoulder := Vector3(6.0 + cos(ang + 0.32) * 1.75,
			minf(2.2, chunk.ceil_h * 0.42), 6.0 + sin(ang + 0.32) * 1.75)
		var heart_p := heart_core + Vector3(cos(ang) * 0.82,
			(chunk._r(3710 + i) - 0.5) * 0.85, sin(ang) * 0.70)
		_vine_path(roots, [floor_p, shoulder, heart_p], 0.20, 0.56)
	_pine_roots(Vector3(6.0, 0.02, 6.0), chunk._r(3740) * TAU, 1.85)
	_authored_vines(Vector3(7.7, chunk.ceil_h - 0.62, 6.7),
		Vector3(PI, chunk._r(3741) * TAU, 0.0), 0.30, "heart_canopy")


func _bloom_storm_aperture() -> void:
	# A sealed false exterior, framed as an architectural wound. Its collider
	# is an explicit wall in front of the emissive plane, so red never promises
	# a route the player can take.
	var frame := Node3D.new()
	frame.position = Vector3(6.0, 0.0, 9.75)
	frame.set_meta("bloom_storm_aperture", true)
	chunk.add_child(frame)
	# Four deep growth masses make a true aperture; the first pass used one
	# solid slab here and hid the storm surface it was supposed to frame.
	chunk._mbox(frame, Vector3(-3.72, 3.25, 0), Vector3(0.76, 6.5, 0.52),
		Mats.bloom_growth())
	chunk._mbox(frame, Vector3(3.72, 3.25, 0), Vector3(0.76, 6.5, 0.52),
		Mats.bloom_growth())
	chunk._mbox(frame, Vector3(0, 6.12, 0), Vector3(6.8, 0.76, 0.52),
		Mats.bloom_growth())
	chunk._mbox(frame, Vector3(0, 0.38, 0), Vector3(6.8, 0.76, 0.52),
		Mats.bloom_growth())
	chunk._mbox(frame, Vector3(0, 3.25, 0.12), Vector3(6.8, 4.7, 0.035),
		Mats.bloom_storm())
	for i in 7:
		var y := 0.72 + float(i) * 0.84
		for side in [-1.0, 1.0]:
			chunk._mellipsoid(frame,
				Vector3(side * (3.43 + sin(float(i) * 1.7) * 0.18), y,
					-0.18 + cos(float(i)) * 0.08),
				Vector3(0.44 + (i % 2) * 0.15, 0.55, 0.42),
				Mats.bloom_growth())
	for i in 6:
		var x := -2.75 + float(i) * 1.10
		for top_side in [0.0, 1.0]:
			chunk._mellipsoid(frame,
				Vector3(x + sin(float(i) * 2.1) * 0.16,
					0.58 if top_side < 0.5 else 5.92, -0.16),
				Vector3(0.72, 0.44 + (i % 3) * 0.08, 0.43),
				Mats.bloom_growth())
	# Sparse diagonal intrusions enter from the frame. The previous evenly
	# spaced vertical strands read as prison bars and flattened the vista.
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var y0 := 1.25 + float(i % 2) * 2.65
		var start := Vector3(side * 3.46, y0, -0.42)
		var end := Vector3(side * (1.70 + float(i % 2) * 0.34),
			y0 + (0.72 if i % 2 == 0 else -0.58), -0.47)
		_vine_path(frame, [start,
			(start + end) * 0.5 + Vector3(0, 0.24, -0.04), end],
			0.070, 0.42)
	# Real animated tissue forms the sill, while paired thorn clusters break the
	# rectangular frame into a deep irregular wound rather than a flat screen.
	_authored_flesh_blob(Vector3(2.55, 0.02, 9.30), 0.34, 0.30,
		"storm_sill_left", chunk._r(3830) * TAU)
	_authored_flesh_blob(Vector3(9.55, 0.02, 9.31), PI - 0.28, 0.25,
		"storm_sill_right", chunk._r(3831) * TAU)
	_authored_vines(Vector3(2.40, 3.35, 9.25),
		Vector3(0.0, 0.18, PI * 0.5), 0.29, "storm_frame_left")
	_authored_vines(Vector3(9.60, 3.45, 9.25),
		Vector3(0.0, -0.18, -PI * 0.5), 0.29, "storm_frame_right")
	chunk._collider_box(Vector3(6.0, 3.25, 9.40), Vector3(8.4, 6.5, 0.42))
	chunk._box(Vector3(6.0, 0.05, 5.8), Vector3(2.25, 0.08, 7.0),
		Mats.bloom_wall())
