class_name TraversalLinkFixture
extends Node3D
## Deterministic dry-traversal proving ground: distant identical
## passageways (2.4m wide, 2.7m high) with a marked debug plane at each
## seam. Supplies a straight link, a quarter-turn link, and a deliberately
## mismatched site whose destination band carries an extra collider.

const SEP := 200.0
const TURN_LANE := 50.0
const MISMATCH_LANE := -50.0
const CORRIDOR_HALF := 9.2

var site_straight: HiddenLinkSite
var site_turn: HiddenLinkSite
var site_mismatch: HiddenLinkSite
var link_straight: TraversalLink
var link_turn: TraversalLink
## Seam marker quads. Physics audits keep them; visual validation clears
## them before shooting (Package 3 exit gate).
var debug_marks := true


func build() -> TraversalLinkFixture:
	# B-side geometry carries the extra half-turn H (spec 14.2), so the
	# checker phase matches through M. Endpoint frames are untouched:
	# only the paired-geometry yaw changes, and centered boxes collide
	# identically at either yaw.
	_passageway(Vector3.ZERO, 0.0)
	_passageway(Vector3(SEP, 0, 0), PI)
	_passageway(Vector3(0, 0, TURN_LANE), 0.0)
	_passageway(Vector3(SEP, 0, TURN_LANE), PI * 1.5)
	_passageway(Vector3(0, 0, MISMATCH_LANE), 0.0)
	_passageway(Vector3(SEP, 0, MISMATCH_LANE), PI)
	_mismatch_box()
	site_straight = _make_site("link:straight",
		Transform3D(Basis(), Vector3.ZERO),
		Transform3D(Basis(), Vector3(SEP, 0, 0)))
	site_turn = _make_site("link:turn",
		Transform3D(Basis(), Vector3(0, 0, TURN_LANE)),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(SEP, 0, TURN_LANE)))
	site_mismatch = _make_site("link:mismatch",
		Transform3D(Basis(), Vector3(0, 0, MISMATCH_LANE)),
		Transform3D(Basis(), Vector3(SEP, 0, MISMATCH_LANE)))
	link_straight = site_straight.link
	link_turn = site_turn.link
	return self


func admit_all() -> void:
	var space := get_world_3d().direct_space_state
	for site in [site_straight, site_turn, site_mismatch]:
		site.admit(space)


## Real approach halves and ports, including both bends. Continuations
## are never registered as authoritative walkable regions.
func graph_for(site: HiddenLinkSite) -> TraversalGraph:
	var graph := TraversalGraph.new()
	var bounds := AABB(Vector3(-6.2, -0.5, -0.05), Vector3(7.4, 4.0, 9.25))
	graph.register_link(site.link, site.link.endpoint_a * bounds,
		site.link.endpoint_b * bounds)
	for region in [site.link.region_a, site.link.region_b]:
		var frame := site.link.endpoint_a if region == site.link.region_a else site.link.endpoint_b
		var path: Array[Vector3] = [frame * Vector3(0, 0, 1),
			frame * Vector3(0, 0, 8), frame * Vector3(-6.0, 0, 8)]
		graph.register_port(region, frame * Vector3(-8.0, 0, 8), path)
	return graph


func _make_site(id: String, a: Transform3D, b: Transform3D) -> HiddenLinkSite:
	var site := HiddenLinkSite.new()
	add_child(site)
	var prepared := site.prepare(id, a, b)
	assert(prepared["ok"], "fixture site must prepare: %s" % prepared)
	return site


## Connected S-shaped passage with unmatched rooms beyond two opaque
## bends. Only perimeter edges receive walls; both exterior ports are open.
func _passageway(origin: Vector3, yaw: float) -> void:
	var root := StaticBody3D.new()
	root.transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	root.collision_layer = 1
	add_child(root)
	var xs := [-6.2, -1.2, 1.2, 6.2]
	var zs := [-9.2, -6.8, 6.8, 9.2]
	var h := HiddenLinkSite.PASSAGE_H
	var wall_mat := _flat_material(Color(0.62, 0.58, 0.52))
	var ceiling_mat := _flat_material(Color(0.36, 0.36, 0.38))
	for xi in 3:
		for zi in 3:
			var occupied := (xi == 1) or (xi == 0 and zi == 2) or (xi == 2 and zi == 0)
			if not occupied:
				continue
			var x0: float = xs[xi]
			var x1: float = xs[xi + 1]
			var z0: float = zs[zi]
			var z1: float = zs[zi + 1]
			_solid(root, Vector3((x0 + x1) * 0.5, -0.1, (z0 + z1) * 0.5),
				Vector3(x1 - x0, 0.2, z1 - z0), _floor_material())
			_solid(root, Vector3((x0 + x1) * 0.5, h + 0.1, (z0 + z1) * 0.5),
				Vector3(x1 - x0, 0.2, z1 - z0), ceiling_mat)
			for edge in 4:
				var nx := xi + (1 if edge == 1 else -1 if edge == 3 else 0)
				var nz := zi + (1 if edge == 0 else -1 if edge == 2 else 0)
				var adjacent := nx >= 0 and nx < 3 and nz >= 0 and nz < 3 \
					and ((nx == 1) or (nx == 0 and nz == 2) or (nx == 2 and nz == 0))
				if adjacent:
					continue
				if (xi == 0 and zi == 2 and edge == 3) or (xi == 2 and zi == 0 and edge == 1):
					continue
				var along_x := edge == 0 or edge == 2
				var centre := Vector3((x0 + x1) * 0.5, h * 0.5, z1 + 0.1 if edge == 0 else z0 - 0.1 if edge == 2 else (z0 + z1) * 0.5)
				var size := Vector3(x1 - x0 + 0.4, h, 0.2) if along_x else Vector3(0.2, h, z1 - z0 + 0.4)
				if edge == 1: centre.x = x1 + 0.1
				if edge == 3: centre.x = x0 - 0.1
				_solid(root, centre, size, wall_mat)
	_add_room(root, Vector3(-9.2, 0, 8.0), Vector3(6.0, 2.8, 6.0), yaw, 0)
	_add_room(root, Vector3(9.2, 0, -8.0), Vector3(6.0, 2.8, 6.0), yaw, 1)
	if not debug_marks:
		return
	var marker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, h)
	marker.mesh = quad
	marker.position = Vector3(0, h * 0.5, 0)
	marker.set_meta("traversal_debug_plane", true)
	root.add_child(marker)


func _add_room(root: Node, centre: Vector3, room_size: Vector3, yaw: float, variant: int) -> void:
	var room_mat := _flat_material(Color(0.24, 0.42, 0.58) if variant == 0 else Color(0.58, 0.30, 0.22))
	room_mat.albedo_color = room_mat.albedo_color.lightened(fmod(absf(yaw), TAU) / TAU * 0.18)
	var floor := _floor_material()
	var room_h := HiddenLinkSite.PASSAGE_H
	_solid(root, Vector3(centre.x, -0.1, centre.z), Vector3(room_size.x, 0.2, room_size.z), floor)
	_solid(root, Vector3(centre.x, 2.8, centre.z), Vector3(room_size.x, 0.2, room_size.z), room_mat)
	_solid(root, Vector3(centre.x, 1.35, centre.z - room_size.z * 0.5 - 0.1), Vector3(room_size.x, room_h, 0.2), room_mat)
	_solid(root, Vector3(centre.x, 1.35, centre.z + room_size.z * 0.5 + 0.1), Vector3(room_size.x, room_h, 0.2), room_mat)
	# The side facing the dogleg has a 2.4m matching opening; retain the
	# remaining wall segments as real layer-1 colliders.
	var side_x := centre.x + room_size.x * 0.5 + 0.1 if variant == 0 else centre.x - room_size.x * 0.5 - 0.1
	var side_z0 := centre.z - room_size.z * 0.5
	var side_z1 := centre.z + room_size.z * 0.5
	var gap0 := centre.z - 1.2
	var gap1 := centre.z + 1.2
	if side_z0 < gap0:
		_solid(root, Vector3(side_x, 1.35, (side_z0 + gap0) * 0.5), Vector3(0.2, room_h, gap0 - side_z0), room_mat)
	if gap1 < side_z1:
		_solid(root, Vector3(side_x, 1.35, (gap1 + side_z1) * 0.5), Vector3(0.2, room_h, side_z1 - gap1), room_mat)
	var far_x := centre.x - room_size.x * 0.5 - 0.1 if variant == 0 else centre.x + room_size.x * 0.5 + 0.1
	_solid(root, Vector3(far_x, 1.35, centre.z), Vector3(0.2, room_h, room_size.z), room_mat)


func exterior_samples(origin: Vector3, yaw: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in [Vector3(-10.0, 1.0, 8.0), Vector3(10.0, 1.0, -8.0), Vector3(-6.0, 1.0, 8.0), Vector3(6.0, 1.0, -8.0)]:
		out.append(Transform3D(Basis(Vector3.UP, yaw), origin) * p)
	return out


## Checkerboard floor in object space (spec 14.2): checker cells must
## align across the crossing. Shared by every corridor, so any phase jump
## at the seam is the mapping's fault, never the material's.
static var _floor_material_cache: ShaderMaterial


func _floor_material() -> ShaderMaterial:
	if _floor_material_cache == null:
		var shader := Shader.new()
		shader.code = "shader_type spatial;\n" \
			+ "render_mode diffuse_lambert, specular_disabled;\n" \
			+ "varying vec3 object_at;\n" \
			+ "void vertex() { object_at = VERTEX; }\n" \
			+ "void fragment() {\n" \
			+ "\tfloat cx = step(0.5, fract(object_at.x / 0.4));\n" \
			+ "\tfloat cz = step(0.5, fract(object_at.z / 0.4));\n" \
			+ "\tfloat v = abs(cx - cz);\n" \
			+ "\tALBEDO = mix(vec3(0.78), vec3(0.22), v);\n" \
			+ "\tROUGHNESS = 0.95;\n}\n"
		_floor_material_cache = ShaderMaterial.new()
		_floor_material_cache.shader = shader
	return _floor_material_cache


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


func _solid(parent: Node, centre: Vector3, size: Vector3,
		material: Material = null) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	parent.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.position = centre
	if material != null:
		mesh.set_surface_override_material(0, material)
	parent.add_child(mesh)


## Extra collider strictly inside the mismatch destination band.
func _mismatch_box() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(SEP, 0.5, MISMATCH_LANE - 1.0)
	body.collision_layer = 1
	add_child(body)
	_solid(body, Vector3.ZERO, Vector3(1, 1, 1))
