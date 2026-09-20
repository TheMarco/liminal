class_name SpatialDoorFixture
extends Node3D
## Deterministic flat junction for the migrating-doorway package: an 8x8m
## room with aperture A (north), aperture B (east), fixed entrance C
## (south), real neighbour rooms, anchor props, and both-side lighting.
## Supplies the site, spec, state, plan, topology overlay, occupancy
## provider, blackout driver, and persistence capture for audits.

const SITE_ID := "floor:0/site:door:0:0:0"
const TILE_M := 0.8
const CEIL_H := 3.0

const CELL_J := Vector2i(0, 0)
const CELL_NA := Vector2i(0, -1)
const CELL_NB := Vector2i(1, 0)
const CELL_EC := Vector2i(0, 1)
const CELL_NE := Vector2i(1, -1)
const CELL_SE := Vector2i(1, 1)

var site: MigratingDoorSite
var spec: SpatialSiteSpec
var topology: DescentTopology
var wall_material: StandardMaterial3D
var trim_material: StandardMaterial3D
var floor_material: StandardMaterial3D

var _lights: Array = []
var _saved_energy: Array = []
var is_dark := false
var refuse_dark := false
var _bodies := {}
var _last_pos := {}
var _scripted: Array = []
var persisted: Array = []
var graph_invalidations := 0
var furniture: Array = []


func build() -> SpatialDoorFixture:
	_make_materials()
	_build_shell()
	_build_neighbours()
	_build_props()
	_build_lights()
	topology = DescentTopology.new(1234, 1)
	spec = make_spec()
	topology.reserve_site_cells(spec.cells, spec.id)
	topology.set_site_edge(SITE_ID, CELL_J, 3, true)
	topology.set_site_edge(SITE_ID, CELL_J, 0, false)
	site = MigratingDoorSite.new()
	site.name = "MigratingDoorSite"
	add_child(site)
	var prepared := site.prepare(spec, make_state(), {
		"wall_material": wall_material,
		"trim_material": trim_material,
		"ceiling_h": CEIL_H,
		"pattern_tile_m": TILE_M,
	})
	assert(prepared.ok, "fixture site must prepare: " + prepared.reason)
	return self


func make_spec() -> SpatialSiteSpec:
	var endpoints := {
		"a": Transform3D(Basis(), Vector3(0.0, 0.0, -4.0)),
		"b": Transform3D(Basis(Vector3(0, 1, 0), -PI * 0.5),
			Vector3(4.0, 0.0, 0.0)),
	}
	return SpatialSiteSpec.make_door(
		SITE_ID, 1, 1, [CELL_J], ["fixture_clock"],
		endpoints,
		["a_open", "both_open", "b_open"],
		[
			AABB(Vector3(-4.0, -0.5, -5.0), Vector3(8.5, 4.0, 2.0)),
			AABB(Vector3(3.0, -0.5, -4.25), Vector3(2.0, 4.0, 8.5)),
		],
		{
			"opening_a": {"position": Vector3(0.0, 1.4, -3.5),
				"extents": Vector2(1.6, 1.35)},
			"wall_b": {"position": Vector3(3.5, 1.4, 0.0),
				"extents": Vector2(1.6, 1.35)},
			"anchor_clock": {"position": Vector3(3.3, 1.6, -3.3),
				"extents": Vector2(0.4, 0.4)},
		},
		["exit"])


func make_state() -> SpatialSiteState:
	return SpatialSiteState.for_spec(spec, "a_open")


func key_a() -> String:
	return DescentTopology.edge_key(CELL_J, 3)


func key_b() -> String:
	return DescentTopology.edge_key(CELL_J, 0)


func key_c() -> String:
	return DescentTopology.edge_key(CELL_J, 2)


func make_plan(from_phase: String, to_phase: String,
		presentation: String, hold_timeout := 6.0) -> SpatialTransitionPlan:
	var plan := SpatialTransitionPlan.new()
	plan.site_id = SITE_ID
	plan.expected_revision = topology.revision
	plan.from_phase = from_phase
	plan.to_phase = to_phase
	plan.phase_edges = {
		"a_open": {key_a(): true, key_b(): false},
		"both_open": {key_a(): true, key_b(): true},
		"b_open": {key_a(): false, key_b(): true},
	}
	var pairs_both := [
		[CELL_J, CELL_NA], [CELL_J, CELL_NB], [CELL_J, CELL_EC],
		[CELL_NA, CELL_NB], [CELL_NA, CELL_EC], [CELL_NB, CELL_EC],
	]
	plan.phase_pairs = {
		"a_open": [[CELL_J, CELL_NA], [CELL_J, CELL_EC],
			[CELL_NA, CELL_EC]],
		"both_open": pairs_both,
		"b_open": [[CELL_J, CELL_NB], [CELL_J, CELL_EC],
			[CELL_NB, CELL_EC]],
	}
	plan.aperture_edges = {
		"a": {"cell": CELL_J, "dir": 3},
		"b": {"cell": CELL_J, "dir": 0},
	}
	plan.presentation = presentation
	plan.hold_timeout = hold_timeout
	return plan


func base_probe(cell: Vector2i, dir: int) -> bool:
	var key := DescentTopology.edge_key(cell, dir)
	return key in [
		key_c(),
		DescentTopology.edge_key(CELL_NA, 0),
		DescentTopology.edge_key(CELL_NE, 2),
		DescentTopology.edge_key(CELL_NB, 2),
		DescentTopology.edge_key(CELL_EC, 0),
	]


func scanned_cells() -> Array:
	# The two extra cells model the surrounding floor loop. Either aperture may
	# close without marooning its neighbour, matching the generated-site gate.
	return [CELL_J, CELL_NA, CELL_NB, CELL_EC, CELL_NE, CELL_SE]


## Occupancy provider for the director/transaction. Real bodies report
## previous-to-current swept motion; scripted entries cover low-rate and
## teleport cases directly.
func occupancy() -> Array:
	var out := []
	for id in _bodies.keys():
		var body: Node3D = _bodies[id]
		var curr: Vector3 = body.global_position
		var prev: Vector3 = _last_pos.get(id, curr)
		_last_pos[id] = curr
		out.append({"id": id, "prev": prev, "curr": curr,
			"radius": Player.BODY_RADIUS})
	for entry in _scripted:
		out.append((entry as Dictionary).duplicate())
	return out


func add_body(id: String, body: SpatialTestBody) -> void:
	add_child(body)
	_bodies[id] = body
	_last_pos[id] = body.global_position


func set_scripted(entries: Array) -> void:
	_scripted = entries


func persist(state: SpatialSiteState) -> Error:
	var snapshot := SpatialSiteState.from_disk(state.to_disk())
	if snapshot == null:
		return ERR_INVALID_DATA
	persisted.append(snapshot)
	return OK


func note_graph_invalidated() -> void:
	graph_invalidations += 1


func darken() -> bool:
	if refuse_dark:
		return false
	if is_dark:
		return true
	_saved_energy.clear()
	for light in _lights:
		_saved_energy.append((light as OmniLight3D).light_energy)
		(light as OmniLight3D).light_energy = 0.03
	is_dark = true
	return true


func restore() -> void:
	for i in _lights.size():
		(_lights[i] as OmniLight3D).light_energy = _saved_energy[i]
	is_dark = false


func _make_materials() -> void:
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_texture = _stripe_texture()
	wall_material.roughness = 0.9
	trim_material = StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.75, 0.72, 0.66)
	trim_material.roughness = 0.8
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_texture = _checker_texture()
	floor_material.roughness = 0.95


func _stripe_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var stripe := 0.72 if posmod(x / 8, 2) == 0 else 0.62
			var shade := stripe * (0.97 + 0.03 * float(y) / 64.0)
			image.set_pixel(x, y, Color(shade, shade * 0.96, shade * 0.88))
	return ImageTexture.create_from_image(image)


func _checker_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var light := posmod(x / 32, 2) == posmod(y / 32, 2)
			var shade := 0.55 if light else 0.35
			image.set_pixel(x, y, Color(shade, shade, shade))
	return ImageTexture.create_from_image(image)


func _box(parent: Node, center: Vector3, size: Vector3,
		material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = MigratingDoorSite.anchored_box_mesh(size, TILE_M)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


## One aperture wall in local frame: spans local X, aperture 3.2 wide and
## 2.7 high at the origin, pockets each side, 0.4 thick.
func _aperture_wall(parent: Node, center: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation.y = yaw
	parent.add_child(root)
	var t := 0.4
	# Solid end segments: start clear of pocket ends (leaf reach 3.225).
	for side in [-1.0, 1.0]:
		_box(root, Vector3(side * 3.825, 1.5, 0.0),
			Vector3(1.15, 3.0, t), wall_material)
	# Pocket skins and above-void filler.
	for side in [-1.0, 1.0]:
		var px: float = side * 2.4
		_box(root, Vector3(px, 1.5, 0.155), Vector3(1.7, 3.0, 0.09),
			wall_material)
		_box(root, Vector3(px, 1.5, -0.155), Vector3(1.7, 3.0, 0.09),
			wall_material)
		_box(root, Vector3(px, 2.85, 0.0), Vector3(1.7, 0.3, 0.22),
			wall_material)
		_box(root, Vector3(side * 3.275, 1.35, 0.0),
			Vector3(0.1, 2.7, 0.22), wall_material)


func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "shell"
	add_child(shell)
	# Floor and ceiling.
	_box(shell, Vector3(0, -0.1, 0), Vector3(8.6, 0.2, 8.6),
		floor_material)
	_box(shell, Vector3(0, 3.1, 0), Vector3(8.6, 0.2, 8.6),
		trim_material)
	_aperture_wall(shell, Vector3(0, 0, -4), 0.0)
	_aperture_wall(shell, Vector3(4, 0, 0), -PI * 0.5)
	# South wall with fixed entrance C (1.8 wide at x = 0).
	_box(shell, Vector3(-2.55, 1.5, 4), Vector3(3.3, 3.0, 0.3),
		wall_material)
	_box(shell, Vector3(2.55, 1.5, 4), Vector3(3.3, 3.0, 0.3),
		wall_material)
	_box(shell, Vector3(0, 2.7, 4), Vector3(1.8, 0.6, 0.3),
		wall_material)
	# West wall, solid.
	_box(shell, Vector3(-4, 1.5, 0), Vector3(0.3, 3.0, 8.6),
		wall_material)


func _build_neighbours() -> void:
	var outer := Node3D.new()
	outer.name = "neighbours"
	add_child(outer)
	# Room A beyond the north wall.
	_box(outer, Vector3(0, -0.1, -7.2), Vector3(8.6, 0.2, 6.4),
		floor_material)
	_box(outer, Vector3(0, 3.1, -7.2), Vector3(8.6, 0.2, 6.4),
		trim_material)
	_box(outer, Vector3(0, 1.5, -10.2), Vector3(8.6, 3.0, 0.3),
		wall_material)
	_box(outer, Vector3(-4.15, 1.5, -7.2), Vector3(0.3, 3.0, 6.4),
		wall_material)
	_box(outer, Vector3(4.15, 1.5, -7.2), Vector3(0.3, 3.0, 6.4),
		wall_material)
	# Room B beyond the east wall.
	_box(outer, Vector3(7.2, -0.1, 0), Vector3(6.4, 0.2, 8.6),
		floor_material)
	_box(outer, Vector3(7.2, 3.1, 0), Vector3(6.4, 0.2, 8.6),
		trim_material)
	_box(outer, Vector3(10.2, 1.5, 0), Vector3(0.3, 3.0, 8.6),
		wall_material)
	_box(outer, Vector3(7.2, 1.5, -4.15), Vector3(6.4, 3.0, 0.3),
		wall_material)
	_box(outer, Vector3(7.2, 1.5, 4.15), Vector3(6.4, 3.0, 0.3),
		wall_material)
	# Entrance corridor beyond the south wall.
	_box(outer, Vector3(0, -0.1, 7.2), Vector3(3.2, 0.2, 6.4),
		floor_material)
	_box(outer, Vector3(0, 3.1, 7.2), Vector3(3.2, 0.2, 6.4),
		trim_material)
	_box(outer, Vector3(-1.6, 1.5, 7.2), Vector3(0.3, 3.0, 6.4),
		wall_material)
	_box(outer, Vector3(1.6, 1.5, 7.2), Vector3(0.3, 3.0, 6.4),
		wall_material)
	_box(outer, Vector3(0, 1.5, 10.2), Vector3(3.5, 3.0, 0.3),
		wall_material)


func _build_props() -> void:
	var props := Node3D.new()
	props.name = "props"
	add_child(props)
	# Fixed clock pillar with a simple face and hands.
	var pillar := _box(props, Vector3(3.3, 1.5, -3.3),
		Vector3(0.5, 3.0, 0.5), trim_material)
	furniture.append(pillar)
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.25
	disc.bottom_radius = 0.25
	disc.height = 0.05
	face.mesh = disc
	face.material_override = trim_material
	face.position = Vector3(3.3, 1.9, -3.02)
	face.rotation.x = PI * 0.5
	props.add_child(face)
	furniture.append(face)
	for hand in [[0.02, 0.16, 0.0], [0.02, 0.11, 0.9]]:
		var hand_mesh := MeshInstance3D.new()
		hand_mesh.mesh = MigratingDoorSite.anchored_box_mesh(
			Vector3(hand[0], hand[1], 0.02), TILE_M)
		hand_mesh.material_override = trim_material
		hand_mesh.position = Vector3(3.3, 1.9, -2.99)
		hand_mesh.rotation.z = hand[2]
		props.add_child(hand_mesh)
		furniture.append(hand_mesh)
	# Crooked chair, motionless.
	var chair := Node3D.new()
	chair.position = Vector3(-2.5, 0, -2.0)
	chair.rotation.y = 0.4
	props.add_child(chair)
	_box(chair, Vector3(0, 0.45, 0), Vector3(0.45, 0.06, 0.45),
		trim_material)
	_box(chair, Vector3(0, 0.75, -0.2), Vector3(0.45, 0.6, 0.06),
		trim_material)
	furniture.append(chair)
	# Table stain on the floor.
	var stain := MeshInstance3D.new()
	stain.mesh = MigratingDoorSite.anchored_box_mesh(
		Vector3(0.5, 0.012, 0.5), TILE_M)
	var stain_material := StandardMaterial3D.new()
	stain_material.albedo_color = Color(0.2, 0.12, 0.08)
	stain.material_override = stain_material
	stain.position = Vector3(1.5, 0.006, 2.0)
	props.add_child(stain)
	furniture.append(stain)


func _build_lights() -> void:
	for at in [Vector3(0, 2.6, 0), Vector3(0, 2.6, -7.2),
			Vector3(7.2, 2.6, 0), Vector3(0, 2.6, 7.2)]:
		var light := OmniLight3D.new()
		light.position = at
		light.omni_range = 12.0
		light.light_energy = 1.0
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
