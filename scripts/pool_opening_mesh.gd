class_name PoolOpeningMesh
extends RefCounted
## Smooth, truly cut Poolrooms wall openings. Local X runs along the wall,
## local Y is height, and local Z crosses the 30cm wall thickness.

static var _mesh_cache := {}
static var _mesh_cache_order: Array[String] = []

static func clear_runtime_cache() -> void:
	_mesh_cache.clear()
	_mesh_cache_order.clear()

static func _cached(key_args: Array, builder: Callable) -> ArrayMesh:
	var key := var_to_bytes(key_args).hex_encode()
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: ArrayMesh = builder.call()
	_mesh_cache[key] = mesh
	_mesh_cache_order.append(key)
	if _mesh_cache_order.size() > 128:
		_mesh_cache.erase(_mesh_cache_order.pop_front())
	return mesh

static func rounded_door_profile(width: float, top: float, radius: float,
		segments: int = 8) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var half := width * 0.5
	var r := clampf(radius, 0.08, half - 0.02)
	var count := maxi(segments, 3)
	var left_center := Vector2(-half + r, top - r)
	for i in range(count + 1):
		var angle := lerpf(PI, PI * 0.5, float(i) / float(count))
		points.append(left_center + Vector2(cos(angle), sin(angle)) * r)
	var right_center := Vector2(half - r, top - r)
	if right_center.x - left_center.x > 0.02:
		points.append(Vector2(right_center.x, top))
	for i in range(1, count + 1):
		var angle := lerpf(
			PI * 0.5, 0.0, float(i) / float(count))
		points.append(right_center + Vector2(cos(angle), sin(angle)) * r)
	return points


static func arched_door_profile(width: float, top: float, rise: float,
		segments: int = 16) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var half := width * 0.5
	var arch_rise := clampf(rise, 0.20, top - 0.20)
	var spring := top - arch_rise
	var count := maxi(segments, 6)
	for i in range(count + 1):
		var angle := lerpf(PI, 0.0, float(i) / float(count))
		points.append(Vector2(
			cos(angle) * half,
			spring + sin(angle) * arch_rise))
	return points


static func doorway_header(profile: Array[Vector2], depth: float,
		wall_top: float) -> ArrayMesh:
	return _cached(
		["doorway_header", profile, depth, wall_top],
		func(): return _doorway_header_build(profile, depth, wall_top))

static func _doorway_header_build(profile: Array[Vector2], depth: float,
		wall_top: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if profile.size() < 2:
		return st.commit()
	var half_depth := depth * 0.5
	for i in range(profile.size() - 1):
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var front0 := Vector3(p0.x, p0.y, half_depth)
		var front1 := Vector3(p1.x, p1.y, half_depth)
		var front0_top := Vector3(p0.x, wall_top, half_depth)
		var front1_top := Vector3(p1.x, wall_top, half_depth)
		var back0 := Vector3(p0.x, p0.y, -half_depth)
		var back1 := Vector3(p1.x, p1.y, -half_depth)
		var back0_top := Vector3(p0.x, wall_top, -half_depth)
		var back1_top := Vector3(p1.x, wall_top, -half_depth)
		_quad_flat(st, front0, front1, front1_top, front0_top, Vector3.BACK)
		_quad_flat(st, back1, back0, back0_top, back1_top, Vector3.FORWARD)

		var n0_2 := _opening_normal(profile, i)
		var n1_2 := _opening_normal(profile, i + 1)
		var n0 := Vector3(n0_2.x, n0_2.y, 0.0)
		var n1 := Vector3(n1_2.x, n1_2.y, 0.0)
		_quad(st, back0, back1, front1, front0, n0, n1, n1, n0)

	var left := profile[0].x
	var right := profile[profile.size() - 1].x
	_quad_flat(st,
		Vector3(left, wall_top, half_depth),
		Vector3(right, wall_top, half_depth),
		Vector3(right, wall_top, -half_depth),
		Vector3(left, wall_top, -half_depth),
		Vector3.UP)
	return st.commit()


static func circular_aperture_panel(radius: float, depth: float,
		wall_top: float, center_y: float,
		segments: int = 24) -> ArrayMesh:
	return _cached(
		["circular_aperture_panel", radius, depth, wall_top, center_y,
		segments],
		func(): return _circular_aperture_panel_build(
			radius, depth, wall_top, center_y, segments))

static func _circular_aperture_panel_build(radius: float, depth: float,
		wall_top: float, center_y: float,
		segments: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(segments, 12)
	var half_depth := depth * 0.5
	for i in count:
		var a0 := lerpf(PI, 0.0, float(i) / float(count))
		var a1 := lerpf(PI, 0.0, float(i + 1) / float(count))
		var x0 := cos(a0) * radius
		var x1 := cos(a1) * radius
		var upper0 := center_y + sin(a0) * radius
		var upper1 := center_y + sin(a1) * radius
		var lower0 := center_y - sin(a0) * radius
		var lower1 := center_y - sin(a1) * radius
		_panel_face_strip(st, x0, x1, 0.0, 0.0, lower0, lower1,
			half_depth, Vector3.BACK)
		_panel_face_strip(st, x0, x1, upper0, upper1,
			wall_top, wall_top, half_depth, Vector3.BACK)
		_panel_face_strip(st, x1, x0, 0.0, 0.0, lower1, lower0,
			-half_depth, Vector3.FORWARD)
		_panel_face_strip(st, x1, x0, upper1, upper0,
			wall_top, wall_top, -half_depth, Vector3.FORWARD)

	for i in count * 2:
		var angle0 := TAU * float(i) / float(count * 2)
		var angle1 := TAU * float(i + 1) / float(count * 2)
		var radial0 := Vector2(cos(angle0), sin(angle0))
		var radial1 := Vector2(cos(angle1), sin(angle1))
		var p0 := Vector2(0.0, center_y) + radial0 * radius
		var p1 := Vector2(0.0, center_y) + radial1 * radius
		var n0 := Vector3(-radial0.x, -radial0.y, 0.0)
		var n1 := Vector3(-radial1.x, -radial1.y, 0.0)
		_quad(st,
			Vector3(p0.x, p0.y, -half_depth),
			Vector3(p1.x, p1.y, -half_depth),
			Vector3(p1.x, p1.y, half_depth),
			Vector3(p0.x, p0.y, half_depth),
			n0, n1, n1, n0)

	_quad_flat(st,
		Vector3(-radius, wall_top, half_depth),
		Vector3(radius, wall_top, half_depth),
		Vector3(radius, wall_top, -half_depth),
		Vector3(-radius, wall_top, -half_depth),
		Vector3.UP)
	_quad_flat(st,
		Vector3(-radius, 0.0, -half_depth),
		Vector3(radius, 0.0, -half_depth),
		Vector3(radius, 0.0, half_depth),
		Vector3(-radius, 0.0, half_depth),
		Vector3.DOWN)
	return st.commit()


static func _panel_face_strip(st: SurfaceTool,
		x0: float, x1: float,
		bottom0: float, bottom1: float,
		top0: float, top1: float,
		z: float, normal: Vector3) -> void:
	if maxf(top0 - bottom0, top1 - bottom1) < 0.01:
		return
	_quad_flat(st,
		Vector3(x0, bottom0, z),
		Vector3(x1, bottom1, z),
		Vector3(x1, top1, z),
		Vector3(x0, top0, z),
		normal)


static func _opening_normal(profile: Array[Vector2], index: int) -> Vector2:
	var before := profile[maxi(index - 1, 0)]
	var after := profile[mini(index + 1, profile.size() - 1)]
	var tangent := (after - before).normalized()
	return Vector2(tangent.y, -tangent.x).normalized()


static func _quad_flat(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3) -> void:
	_quad(st, a, b, c, d, normal, normal, normal, normal)


## Godot's spatial front face is clockwise.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var avg := (na + nb + nc).normalized()
	if (b - a).cross(c - a).dot(avg) > 0.0:
		var swap_vertex := b
		b = c
		c = swap_vertex
		var swap_normal := nb
		nb = nc
		nc = swap_normal
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
		nc: Vector3, nd: Vector3) -> void:
	_tri(st, a, b, c, na, nb, nc)
	_tri(st, a, c, d, na, nc, nd)
