class_name FlashBoltMesh
extends RefCounted

## Builds a centered, closed extrusion of the flash-bolt silhouette.
static func build(height: float, width: float, depth: float) -> ArrayMesh:
	var polygon := PackedVector2Array([
		Vector2(0.88, 1.0), Vector2(0.0, 0.43), Vector2(0.42, 0.43),
		Vector2(0.12, 0.0), Vector2(1.0, 0.61), Vector2(0.58, 0.61),
	])
	for i in polygon.size():
		polygon[i] = Vector2((polygon[i].x - 0.5) * width,
			(polygon[i].y - 0.5) * height)

	var indices := Geometry2D.triangulate_polygon(polygon)
	var front_z := depth * 0.5
	var back_z := -front_z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_normal := Vector3.BACK
	var back_normal := Vector3.FORWARD
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i + 1]]
		var c := polygon[indices[i + 2]]
		_add_triangle(st, Vector3(a.x, a.y, front_z), Vector3(c.x, c.y, front_z),
			Vector3(b.x, b.y, front_z), front_normal)
		_add_triangle(st, Vector3(a.x, a.y, back_z), Vector3(b.x, b.y, back_z),
			Vector3(c.x, c.y, back_z), back_normal)

	var clockwise := Geometry2D.is_polygon_clockwise(polygon)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var edge := b - a
		var outward := Vector2(-edge.y, edge.x) if clockwise else Vector2(edge.y, -edge.x)
		var normal := Vector3(outward.x, outward.y, 0.0).normalized()
		_add_quad(st, Vector3(a.x, a.y, back_z), Vector3(b.x, b.y, back_z),
			Vector3(b.x, b.y, front_z), Vector3(a.x, a.y, front_z), normal)
	return st.commit()

static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3) -> void:
	# Godot front faces wind clockwise when viewed from their outward normal.
	var vertices := [a, c, b] if (b - a).cross(c - a).dot(normal) > 0.0 else [a, b, c]
	for vertex in vertices:
		st.set_normal(normal)
		st.add_vertex(vertex)

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3) -> void:
	_add_triangle(st, a, b, c, normal)
	_add_triangle(st, a, c, d, normal)
