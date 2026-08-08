class_name PoolCornerMesh
extends RefCounted
## One watertight quarter-annulus used where two Pool Rooms walls turn through
## 90 degrees.  The mesh deliberately has no end caps: the two straight wall
## prisms already close those tangent planes, so a second face there would be
## coplanar and could flicker at distance.

static var _straight_bullnose_cache := {}


static func quarter_annulus(center: Vector2, radial_start: Vector2,
		sweep: float, inner_radius: float, outer_radius: float,
		y0: float, y1: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(segments, 2)
	var start := radial_start.normalized()
	for i in count:
		var t0 := float(i) / float(count)
		var t1 := float(i + 1) / float(count)
		var u0 := start.rotated(sweep * t0)
		var u1 := start.rotated(sweep * t1)
		var inner0 := Vector3(
			center.x + u0.x * inner_radius, y0,
			center.y + u0.y * inner_radius)
		var inner1 := Vector3(
			center.x + u1.x * inner_radius, y0,
			center.y + u1.y * inner_radius)
		var outer0 := Vector3(
			center.x + u0.x * outer_radius, y0,
			center.y + u0.y * outer_radius)
		var outer1 := Vector3(
			center.x + u1.x * outer_radius, y0,
			center.y + u1.y * outer_radius)
		var inner0_top := inner0 + Vector3.UP * (y1 - y0)
		var inner1_top := inner1 + Vector3.UP * (y1 - y0)
		var outer0_top := outer0 + Vector3.UP * (y1 - y0)
		var outer1_top := outer1 + Vector3.UP * (y1 - y0)
		var n0 := Vector3(u0.x, 0.0, u0.y)
		var n1 := Vector3(u1.x, 0.0, u1.y)

		# Smooth cylindrical outer and inner wall faces.
		_quad(st, outer0, outer1, outer1_top, outer0_top,
			n0, n1, n1, n0)
		_quad(st, inner1, inner0, inner0_top, inner1_top,
			-n1, -n0, -n0, -n1)
		# Flat top and underside complete the solid everywhere except its two
		# tangent ends, which intentionally meet the existing wall end caps.
		_quad(st, inner0_top, outer0_top, outer1_top, inner1_top,
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)
		_quad(st, inner1, outer1, outer0, inner0,
			Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return st.commit()


## A one-metre straight coping slab. Local X runs along the pool edge and local
## +Z points toward the water. The water-facing edge is a true semicircular
## bullnose; callers scale only X to make individual modular slabs.
static func straight_bullnose(width: float, height: float,
		nose_segments: int = 8) -> ArrayMesh:
	var key := "%.3f_%.3f_%d" % [width, height, nose_segments]
	if _straight_bullnose_cache.has(key):
		return _straight_bullnose_cache[key]
	var profile := _bullnose_profile(
		-width * 0.5, width * 0.5, height, nose_segments)
	var profile_center := _profile_center(profile)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		var p0 := profile[i]
		var p1 := profile[j]
		var normal2 := _profile_edge_normal(p0, p1, profile_center)
		var normal := Vector3(0.0, normal2.y, normal2.x)
		var a := Vector3(-0.5, p0.y, p0.x)
		var b := Vector3(0.5, p0.y, p0.x)
		var c := Vector3(0.5, p1.y, p1.x)
		var d := Vector3(-0.5, p1.y, p1.x)
		_quad(st, a, b, c, d, normal, normal, normal, normal)
	var left_center := Vector3(-0.5, profile_center.y, profile_center.x)
	var right_center := Vector3(0.5, profile_center.y, profile_center.x)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		var left0 := Vector3(-0.5, profile[i].y, profile[i].x)
		var left1 := Vector3(-0.5, profile[j].y, profile[j].x)
		var right0 := Vector3(0.5, profile[i].y, profile[i].x)
		var right1 := Vector3(0.5, profile[j].y, profile[j].x)
		_tri(st, left_center, left0, left1,
			Vector3.LEFT, Vector3.LEFT, Vector3.LEFT)
		_tri(st, right_center, right1, right0,
			Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT)
	var mesh := st.commit()
	_straight_bullnose_cache[key] = mesh
	return mesh


## Curved counterpart to `straight_bullnose`. `deck_radius` is the back of the
## coping on solid deck and `water_radius` its rounded leading edge; either may
## be larger, allowing the same profile to cap a concave pool corner or a
## convex island. End caps are intentional here: tiny gaps between modules are
## the visible slab joints.
static func annular_bullnose(center: Vector2, radial_start: Vector2,
		sweep: float, deck_radius: float, water_radius: float,
		y_mid: float, height: float, arc_segments: int,
		nose_segments: int = 8) -> ArrayMesh:
	var profile := _bullnose_profile(
		deck_radius, water_radius, height, nose_segments)
	var profile_center := _profile_center(profile)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(arc_segments, 2)
	var start := radial_start.normalized()
	for ai in count:
		var u0 := start.rotated(sweep * float(ai) / float(count))
		var u1 := start.rotated(sweep * float(ai + 1) / float(count))
		for pi in profile.size():
			var pj := (pi + 1) % profile.size()
			var p0 := profile[pi]
			var p1 := profile[pj]
			var normal2 := _profile_edge_normal(p0, p1, profile_center)
			var n0 := Vector3(
				u0.x * normal2.x, normal2.y, u0.y * normal2.x)
			var n1 := Vector3(
				u1.x * normal2.x, normal2.y, u1.y * normal2.x)
			var a := Vector3(
				center.x + u0.x * p0.x, y_mid + p0.y,
				center.y + u0.y * p0.x)
			var b := Vector3(
				center.x + u1.x * p0.x, y_mid + p0.y,
				center.y + u1.y * p0.x)
			var c := Vector3(
				center.x + u1.x * p1.x, y_mid + p1.y,
				center.y + u1.y * p1.x)
			var d := Vector3(
				center.x + u0.x * p1.x, y_mid + p1.y,
				center.y + u0.y * p1.x)
			_quad(st, a, b, c, d, n0, n1, n1, n0)
	var end := start.rotated(sweep)
	var direction := signf(sweep)
	var start_tangent := start.rotated(direction * PI * 0.5)
	var end_tangent := end.rotated(direction * PI * 0.5)
	var start_normal := Vector3(-start_tangent.x, 0.0, -start_tangent.y)
	var end_normal := Vector3(end_tangent.x, 0.0, end_tangent.y)
	var start_center := Vector3(
		center.x + start.x * profile_center.x,
		y_mid + profile_center.y,
		center.y + start.y * profile_center.x)
	var end_center := Vector3(
		center.x + end.x * profile_center.x,
		y_mid + profile_center.y,
		center.y + end.y * profile_center.x)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		var start0 := Vector3(
			center.x + start.x * profile[i].x,
			y_mid + profile[i].y,
			center.y + start.y * profile[i].x)
		var start1 := Vector3(
			center.x + start.x * profile[j].x,
			y_mid + profile[j].y,
			center.y + start.y * profile[j].x)
		var end0 := Vector3(
			center.x + end.x * profile[i].x,
			y_mid + profile[i].y,
			center.y + end.y * profile[i].x)
		var end1 := Vector3(
			center.x + end.x * profile[j].x,
			y_mid + profile[j].y,
			center.y + end.y * profile[j].x)
		_tri(st, start_center, start0, start1,
			start_normal, start_normal, start_normal)
		_tri(st, end_center, end1, end0,
			end_normal, end_normal, end_normal)
	return st.commit()


## Bullnose coping swept along one smooth plan path. Unlike a chain of
## annular modules, the entire cross-section shares each path sample, so both
## the rounded water nose and the square deck edge remain C1-continuous through
## an S bend. `water_side` selects which perpendicular to the path faces water.
static func path_bullnose(path: Array[Vector2], water_side: float,
		deck_span: float, water_overhang: float,
		y_mid: float, height: float, nose_segments: int = 8) -> ArrayMesh:
	if path.size() < 2:
		return ArrayMesh.new()
	var profile := _bullnose_profile(
		-deck_span, water_overhang, height, nose_segments)
	var profile_center := _profile_center(profile)
	var tangents: Array[Vector2] = []
	var water_normals: Array[Vector2] = []
	for i in path.size():
		var prev: Vector2 = path[maxi(0, i - 1)]
		var next: Vector2 = path[mini(path.size() - 1, i + 1)]
		var tangent := (next - prev).normalized()
		if tangent == Vector2.ZERO:
			tangent = Vector2.RIGHT
		tangents.append(tangent)
		water_normals.append(
			tangent.rotated(signf(water_side) * PI * 0.5).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in range(path.size() - 1):
		var wn0 := water_normals[si]
		var wn1 := water_normals[si + 1]
		for pi in profile.size():
			var pj := (pi + 1) % profile.size()
			var p0 := profile[pi]
			var p1 := profile[pj]
			var normal2 := _profile_edge_normal(
				p0, p1, profile_center)
			var n0 := Vector3(
				wn0.x * normal2.x, normal2.y,
				wn0.y * normal2.x)
			var n1 := Vector3(
				wn1.x * normal2.x, normal2.y,
				wn1.y * normal2.x)
			var a := Vector3(
				path[si].x + wn0.x * p0.x,
				y_mid + p0.y,
				path[si].y + wn0.y * p0.x)
			var b := Vector3(
				path[si + 1].x + wn1.x * p0.x,
				y_mid + p0.y,
				path[si + 1].y + wn1.y * p0.x)
			var c := Vector3(
				path[si + 1].x + wn1.x * p1.x,
				y_mid + p1.y,
				path[si + 1].y + wn1.y * p1.x)
			var d := Vector3(
				path[si].x + wn0.x * p1.x,
				y_mid + p1.y,
				path[si].y + wn0.y * p1.x)
			_quad(st, a, b, c, d, n0, n1, n1, n0)
	# End caps stay flush against the straight coping pieces. They close the
	# profile without introducing a second surface along the curved run.
	for endpoint in [0, path.size() - 1]:
		var tangent: Vector2 = tangents[endpoint]
		var cap_normal_2d := -tangent if endpoint == 0 else tangent
		var cap_normal := Vector3(
			cap_normal_2d.x, 0.0, cap_normal_2d.y)
		var wn := water_normals[endpoint]
		var cap_center := Vector3(
			path[endpoint].x + wn.x * profile_center.x,
			y_mid + profile_center.y,
			path[endpoint].y + wn.y * profile_center.x)
		for i in profile.size():
			var j := (i + 1) % profile.size()
			var p0 := profile[i]
			var p1 := profile[j]
			var v0 := Vector3(
				path[endpoint].x + wn.x * p0.x,
				y_mid + p0.y,
				path[endpoint].y + wn.y * p0.x)
			var v1 := Vector3(
				path[endpoint].x + wn.x * p1.x,
				y_mid + p1.y,
				path[endpoint].y + wn.y * p1.x)
			if endpoint == 0:
				_tri(st, cap_center, v0, v1,
					cap_normal, cap_normal, cap_normal)
			else:
				_tri(st, cap_center, v1, v0,
					cap_normal, cap_normal, cap_normal)
	return st.commit()


static func _bullnose_profile(deck_coord: float, water_coord: float,
		height: float, nose_segments: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var half_h := height * 0.5
	var water_direction := signf(water_coord - deck_coord)
	if is_zero_approx(water_direction):
		water_direction = 1.0
	var nose_center := water_coord - water_direction * half_h
	result.append(Vector2(deck_coord, -half_h))
	result.append(Vector2(deck_coord, half_h))
	result.append(Vector2(nose_center, half_h))
	var count := maxi(nose_segments, 3)
	for i in range(1, count + 1):
		var angle := lerpf(
			PI * 0.5, -PI * 0.5, float(i) / float(count))
		result.append(Vector2(
			nose_center + water_direction * cos(angle) * half_h,
			sin(angle) * half_h))
	return result


static func _profile_center(profile: Array[Vector2]) -> Vector2:
	var result := Vector2.ZERO
	for point in profile:
		result += point
	return result / float(profile.size())


static func _profile_edge_normal(a: Vector2, b: Vector2,
		profile_center: Vector2) -> Vector2:
	var edge := b - a
	var normal := Vector2(-edge.y, edge.x).normalized()
	if normal.dot((a + b) * 0.5 - profile_center) < 0.0:
		normal = -normal
	return normal


## Solid room-side fillet for a concave corner at a T or cross junction.
## `corner` is the intersection of the two existing wall faces.  The curved
## face and triangular top/bottom fans fill the wedge between that square
## corner and the tangent arc; the two omitted end caps remain buried in the
## existing straight walls, avoiding coplanar overlap.
static func quarter_cove(center: Vector2, radial_start: Vector2,
		sweep: float, radius: float, corner: Vector2,
		y0: float, y1: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(segments, 2)
	var start := radial_start.normalized()
	var corner_bottom := Vector3(corner.x, y0, corner.y)
	var corner_top := Vector3(corner.x, y1, corner.y)
	for i in count:
		var t0 := float(i) / float(count)
		var t1 := float(i + 1) / float(count)
		var u0 := start.rotated(sweep * t0)
		var u1 := start.rotated(sweep * t1)
		var arc0 := Vector3(
			center.x + u0.x * radius, y0,
			center.y + u0.y * radius)
		var arc1 := Vector3(
			center.x + u1.x * radius, y0,
			center.y + u1.y * radius)
		var arc0_top := Vector3(arc0.x, y1, arc0.z)
		var arc1_top := Vector3(arc1.x, y1, arc1.z)
		var n0 := Vector3(u0.x, 0.0, u0.y)
		var n1 := Vector3(u1.x, 0.0, u1.y)

		# The room lies toward the circle centre, so this is the same inward
		# cylindrical face used by quarter_annulus.
		_quad(st, arc1, arc0, arc0_top, arc1_top,
			-n1, -n0, -n0, -n1)
		_tri(st, corner_top, arc0_top, arc1_top,
			Vector3.UP, Vector3.UP, Vector3.UP)
		_tri(st, corner_bottom, arc1, arc0,
			Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return st.commit()


## Godot's spatial front face is clockwise.  Keep the requested outward
## normals, and reverse triangles whose right-hand cross points outward.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var avg := (na + nb + nc).normalized()
	if (b - a).cross(c - a).dot(avg) > 0.0:
		var tv := b
		b = c
		c = tv
		var tn := nb
		nb = nc
		nc = tn
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
