class_name PoolCornerMesh
extends RefCounted
## One watertight quarter-annulus used where two Pool Rooms walls turn through
## 90 degrees.  The mesh deliberately has no end caps: the two straight wall
## prisms already close those tangent planes, so a second face there would be
## coplanar and could flicker at distance.


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
