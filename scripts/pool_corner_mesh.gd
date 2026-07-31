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


## Thin flush surround for the drop-in jacuzzi. Both boundaries are rounded
## rectangles, so it closes the corners of the structural cutout without
## drawing another rectangular tile layer across the tub.
static func rounded_rect_ring(outer_size: Vector2, inner_size: Vector2,
		outer_radius: float, inner_radius: float, height: float,
		corner_segments: int = 8) -> ArrayMesh:
	var outer := _rounded_rect_perimeter(
		outer_size, outer_radius, corner_segments)
	var inner := _rounded_rect_perimeter(
		inner_size, inner_radius, corner_segments)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outer.size():
		var j := (i + 1) % outer.size()
		var ot0 := Vector3(outer[i].x, 0.0, outer[i].y)
		var ot1 := Vector3(outer[j].x, 0.0, outer[j].y)
		var it0 := Vector3(inner[i].x, 0.0, inner[i].y)
		var it1 := Vector3(inner[j].x, 0.0, inner[j].y)
		var ob0 := ot0 + Vector3.DOWN * height
		var ob1 := ot1 + Vector3.DOWN * height
		var ib0 := it0 + Vector3.DOWN * height
		var ib1 := it1 + Vector3.DOWN * height
		_quad(st, ot0, ot1, it1, it0,
			Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)
		_quad(st, ob1, ob0, ib0, ib1,
			Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
		var outer_n0 := Vector3(outer[i].x, 0.0, outer[i].y).normalized()
		var outer_n1 := Vector3(outer[j].x, 0.0, outer[j].y).normalized()
		var inner_n0 := -Vector3(inner[i].x, 0.0, inner[i].y).normalized()
		var inner_n1 := -Vector3(inner[j].x, 0.0, inner[j].y).normalized()
		_quad(st, ot1, ot0, ob0, ob1,
			outer_n1, outer_n0, outer_n0, outer_n1)
		_quad(st, it0, it1, ib1, ib0,
			inner_n0, inner_n1, inner_n1, inner_n0)
	return st.commit()


static func _rounded_rect_perimeter(size: Vector2, radius: float,
		corner_segments: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var half := size * 0.5
	var r := clampf(radius, 0.001, minf(half.x, half.y) - 0.001)
	var count := maxi(corner_segments, 2)
	var centers := [
		Vector2(half.x - r, -half.y + r),
		Vector2(half.x - r, half.y - r),
		Vector2(-half.x + r, half.y - r),
		Vector2(-half.x + r, -half.y + r),
	]
	for corner in 4:
		var angle0 := -PI * 0.5 + float(corner) * PI * 0.5
		for i in count:
			var angle := angle0 + PI * 0.5 * float(i) / float(count)
			result.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	return result


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


## Solid circular sector used for a rounded pool-deck corner.  As with the
## wall annulus, the radial end caps are omitted because both ends sit inside
## the two boundary walls.  That avoids duplicate coplanar faces while the
## curved water-facing edge remains a real vertical surface.
static func quarter_sector(center: Vector2, radial_start: Vector2,
		sweep: float, radius: float, y0: float, y1: float,
		segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(segments, 2)
	var start := radial_start.normalized()
	var center_bottom := Vector3(center.x, y0, center.y)
	var center_top := Vector3(center.x, y1, center.y)
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

		_quad(st, arc0, arc1, arc1_top, arc0_top,
			n0, n1, n1, n0)
		_tri(st, center_top, arc0_top, arc1_top,
			Vector3.UP, Vector3.UP, Vector3.UP)
		_tri(st, center_bottom, arc1, arc0,
			Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return st.commit()


## Subdivided water surface for the compact basin when one square corner is
## replaced by the same concave quarter-circle used by quarter_cove().
## Corner ids follow the pool layout convention: 0 NW, 1 NE, 2 SE, 3 SW.
## The three rectangular regions and the quarter disk only share boundary
## vertices, never faces, so the transparent water has no coplanar overlap.
static func rounded_rect_surface(x0: float, x1: float, z0: float, z1: float,
		corner_id: int, radius: float,
		subdivisions_per_meter: float = 2.4) -> ArrayMesh:
	var min_x := minf(x0, x1)
	var max_x := maxf(x0, x1)
	var min_z := minf(z0, z1)
	var max_z := maxf(z0, z1)
	var width := max_x - min_x
	var depth := max_z - min_z
	if width <= 0.0001 or depth <= 0.0001 or corner_id < 0 \
			or corner_id > 3 or radius <= 0.0001:
		return ArrayMesh.new()

	var r := clampf(radius, 0.0001, minf(width, depth))
	var density := maxf(subdivisions_per_meter, 0.01)
	var center := Vector2.ZERO
	var radial_start := Vector2.UP
	var sweep := 0.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	match corner_id:
		0:
			center = Vector2(min_x + r, min_z + r)
			sweep = -PI * 0.5
			_surface_rect(st, center.x, max_x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, min_x, center.x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, center.x, max_x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)
		1:
			center = Vector2(max_x - r, min_z + r)
			sweep = PI * 0.5
			_surface_rect(st, min_x, center.x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, min_x, center.x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, center.x, max_x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)
		2:
			center = Vector2(max_x - r, max_z - r)
			radial_start = Vector2.DOWN
			sweep = -PI * 0.5
			_surface_rect(st, min_x, center.x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, center.x, max_x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, min_x, center.x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)
		3:
			center = Vector2(min_x + r, max_z - r)
			radial_start = Vector2.DOWN
			sweep = PI * 0.5
			_surface_rect(st, min_x, center.x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, center.x, max_x, min_z, center.y,
				min_x, max_x, min_z, max_z, density)
			_surface_rect(st, center.x, max_x, center.y, max_z,
				min_x, max_x, min_z, max_z, density)

	_surface_quarter_disk(st, center, radial_start, sweep, r,
		min_x, max_x, min_z, max_z, density)
	st.generate_tangents()
	return st.commit()


static func _surface_rect(st: SurfaceTool, x0: float, x1: float,
		z0: float, z1: float, uv_x0: float, uv_x1: float,
		uv_z0: float, uv_z1: float, density: float) -> void:
	var width := x1 - x0
	var depth := z1 - z0
	if width <= 0.0001 or depth <= 0.0001:
		return
	var x_steps := maxi(1, ceili(width * density))
	var z_steps := maxi(1, ceili(depth * density))
	for zi in z_steps:
		var za := lerpf(z0, z1, float(zi) / float(z_steps))
		var zb := lerpf(z0, z1, float(zi + 1) / float(z_steps))
		for xi in x_steps:
			var xa := lerpf(x0, x1, float(xi) / float(x_steps))
			var xb := lerpf(x0, x1, float(xi + 1) / float(x_steps))
			var a := Vector3(xa, 0.0, za)
			var b := Vector3(xb, 0.0, za)
			var c := Vector3(xb, 0.0, zb)
			var d := Vector3(xa, 0.0, zb)
			_surface_tri(st, a, b, c,
				_surface_uv(a, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(b, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(c, uv_x0, uv_x1, uv_z0, uv_z1))
			_surface_tri(st, a, c, d,
				_surface_uv(a, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(c, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(d, uv_x0, uv_x1, uv_z0, uv_z1))


static func _surface_quarter_disk(st: SurfaceTool, center: Vector2,
		radial_start: Vector2, sweep: float, radius: float,
		uv_x0: float, uv_x1: float, uv_z0: float, uv_z1: float,
		density: float) -> void:
	var radial_steps := maxi(1, ceili(radius * density))
	var arc_steps := maxi(
		3, ceili(radius * absf(sweep) * density))
	var start := radial_start.normalized()
	var center_vertex := Vector3(center.x, 0.0, center.y)
	for ring in radial_steps:
		var outer_radius := radius * float(ring + 1) / float(radial_steps)
		if ring == 0:
			for ai in arc_steps:
				var u0 := start.rotated(
					sweep * float(ai) / float(arc_steps))
				var u1 := start.rotated(
					sweep * float(ai + 1) / float(arc_steps))
				var b := Vector3(
					center.x + u0.x * outer_radius, 0.0,
					center.y + u0.y * outer_radius)
				var c := Vector3(
					center.x + u1.x * outer_radius, 0.0,
					center.y + u1.y * outer_radius)
				_surface_tri(st, center_vertex, b, c,
					_surface_uv(center_vertex,
						uv_x0, uv_x1, uv_z0, uv_z1),
					_surface_uv(b, uv_x0, uv_x1, uv_z0, uv_z1),
					_surface_uv(c, uv_x0, uv_x1, uv_z0, uv_z1))
			continue

		var inner_radius := radius * float(ring) / float(radial_steps)
		for ai in arc_steps:
			var u0 := start.rotated(
				sweep * float(ai) / float(arc_steps))
			var u1 := start.rotated(
				sweep * float(ai + 1) / float(arc_steps))
			var a := Vector3(
				center.x + u0.x * inner_radius, 0.0,
				center.y + u0.y * inner_radius)
			var b := Vector3(
				center.x + u0.x * outer_radius, 0.0,
				center.y + u0.y * outer_radius)
			var c := Vector3(
				center.x + u1.x * outer_radius, 0.0,
				center.y + u1.y * outer_radius)
			var d := Vector3(
				center.x + u1.x * inner_radius, 0.0,
				center.y + u1.y * inner_radius)
			_surface_tri(st, a, b, c,
				_surface_uv(a, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(b, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(c, uv_x0, uv_x1, uv_z0, uv_z1))
			_surface_tri(st, a, c, d,
				_surface_uv(a, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(c, uv_x0, uv_x1, uv_z0, uv_z1),
				_surface_uv(d, uv_x0, uv_x1, uv_z0, uv_z1))


static func _surface_uv(vertex: Vector3, x0: float, x1: float,
		z0: float, z1: float) -> Vector2:
	return Vector2(
		inverse_lerp(x0, x1, vertex.x),
		inverse_lerp(z0, z1, vertex.z))


static func _surface_tri(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	if (b - a).cross(c - a).dot(Vector3.UP) > 0.0:
		var tv := b
		b = c
		c = tv
		var tuv := uv_b
		uv_b = uv_c
		uv_c = tuv
	st.set_normal(Vector3.UP)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.set_uv(uv_c)
	st.add_vertex(c)


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
