class_name RoundedBox
## Chamfered box meshes: six inset faces, twelve 45-degree edge bevels, eight
## corner facets. The bevel catches specular highlights the way real objects
## do. Winding is auto-corrected per triangle, meshes cached by size+bevel.

static var _cache := {}


static func mesh(size: Vector3, r: float, max_edge_length := 0.0) -> ArrayMesh:
	var rr := minf(r, minf(size.x, minf(size.y, size.z)) * 0.45)
	var key := "%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, size.z, rr]
	if max_edge_length > 0.0: key += ":edge=%s" % max_edge_length
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# six inset faces
	for axis in 3:
		var j := (axis + 1) % 3
		var k := (axis + 2) % 3
		for s in [-1.0, 1.0]:
			var pts: Array = []
			for cj in [-1.0, 1.0]:
				for ck in [-1.0, 1.0]:
					var v := Vector3.ZERO
					v[axis] = s * h[axis]
					v[j] = cj * (h[j] - rr)
					v[k] = ck * (h[k] - rr)
					pts.append(v)
			_quad_auto(st, pts[0], pts[1], pts[3], pts[2], max_edge_length)
	# twelve edge bevels
	for axis in 3:
		var j := (axis + 1) % 3
		var k := (axis + 2) % 3
		for sj in [-1.0, 1.0]:
			for sk in [-1.0, 1.0]:
				var a1 := Vector3.ZERO
				a1[j] = sj * h[j]
				a1[k] = sk * (h[k] - rr)
				a1[axis] = h[axis] - rr
				var a2 := a1
				a2[axis] = -(h[axis] - rr)
				var b1 := Vector3.ZERO
				b1[j] = sj * (h[j] - rr)
				b1[k] = sk * h[k]
				b1[axis] = h[axis] - rr
				var b2 := b1
				b2[axis] = -(h[axis] - rr)
				_quad_auto(st, a1, a2, b2, b1, max_edge_length)
	# eight corner facets
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var px := Vector3(sx * h.x, sy * (h.y - rr), sz * (h.z - rr))
				var py := Vector3(sx * (h.x - rr), sy * h.y, sz * (h.z - rr))
				var pz := Vector3(sx * (h.x - rr), sy * (h.y - rr), sz * h.z)
				_tri_auto(st, px, py, pz)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m


## Godot front faces wind clockwise seen from outside, so for a convex
## origin-centered solid the right-hand cross normal of a front-facing
## triangle points TOWARD the origin; flip if not.
static func _tri_auto(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(a + b + c) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _quad_auto(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, max_edge_length := 0.0) -> void:
	if max_edge_length > 0.0:
		var columns := maxi(1, ceili(maxf(a.distance_to(b), d.distance_to(c)) / max_edge_length))
		var rows := maxi(1, ceili(maxf(a.distance_to(d), b.distance_to(c)) / max_edge_length))
		for y in rows:
			for x in columns:
				var u0 := float(x) / columns
				var u1 := float(x + 1) / columns
				var v0 := float(y) / rows
				var v1 := float(y + 1) / rows
				_quad_auto(st, a.lerp(b, u0).lerp(d.lerp(c, u0), v0),
					a.lerp(b, u1).lerp(d.lerp(c, u1), v0),
					a.lerp(b, u1).lerp(d.lerp(c, u1), v1),
					a.lerp(b, u0).lerp(d.lerp(c, u0), v1))
		return
	_tri_auto(st, a, b, c)
	_tri_auto(st, a, c, d)
