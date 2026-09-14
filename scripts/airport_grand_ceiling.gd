class_name AirportGrandCeiling
extends RefCounted
## Sculpted 3m terminal coffers, reserved for the tallest 6.2m halls.
## Intermediate 4.4m rooms retain the regular acoustic panels.
## Four batched, shared meshes per 12m cell;
## no new shadow lights, colliders, imports or per-coffer scene nodes.
const MIN_HEIGHT := 6.2
const BAY := 3.0
const COUNT := 4
const COFFERS := COUNT * COUNT
static var _mesh_cache: Dictionary = {}


static func applies(height: float, style: int) -> bool:
	return height >= MIN_HEIGHT - 0.001 and style != WorldGen.AIR_TRANSIT


static func depth(height: float, style: int) -> float:
	# The escalator's 2.25m landing needs standing headroom beneath its ceiling.
	if style == WorldGen.AIR_ESCALATOR:
		return 0.20
	return 0.76 if height >= 6.0 else 0.42


static func clear_runtime_cache() -> void:
	_mesh_cache.clear()


static func attach(parent: Node3D, height: float, style: int,
		lamp_material: Material) -> void:
	if not applies(height, style):
		return
	var drop := depth(height, style)
	var key := roundi(drop * 1000.0)
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _build_meshes(drop)
	parent.position.y = height
	parent.set_meta("airport_grand_ceiling", true)
	parent.set_meta("coffer_count", COFFERS)
	parent.set_meta("coffer_depth", drop)
	var materials := [Mats.air_coffer_shell(), Mats.air_coffer_rib(),
		Mats.air_coffer_inset(), lamp_material]
	var names := ["SlopedShells", "StructuralRibs", "RecessedInsets", "CoveLights"]
	for i in materials.size():
		var mesh := MeshInstance3D.new()
		mesh.name = names[i]
		mesh.mesh = _mesh_cache[key][i]
		mesh.material_override = materials[i]
		parent.add_child(mesh)


static func _build_meshes(drop: float) -> Array[ArrayMesh]:
	var surfaces: Array[SurfaceTool] = []
	for i in 4:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(st)
	for x in COUNT:
		for z in COUNT:
			var centre := Vector3((float(x) + 0.5) * BAY, 0, (float(z) + 0.5) * BAY)
			var rim := _square(centre, 1.50, -drop)
			var mouth := _square(centre, 1.37, -drop)
			var throat := _square(centre, 1.04, -0.08)
			var lens_inner := _square(centre, 0.94, -0.08)
			var inset := _square(centre, 0.94, -0.035)
			for side in 4:
				var next := (side + 1) % 4
				# Broad chamfered shell, narrow continuous structural grid,
				# then a warm luminous rim high inside the recess, not hung below.
				_quad(surfaces[0], mouth[side], mouth[next], throat[next], throat[side])
				_quad(surfaces[1], rim[side], rim[next], mouth[next], mouth[side])
				_quad(surfaces[3], throat[side], throat[next], lens_inner[next], lens_inner[side])
			_quad(surfaces[2], inset[0], inset[1], inset[2], inset[3])
			# Hardwood-lined recesses have slightly darker timber cross-bars,
			# with the pale shell and luminous rim left exposed around them.
			for slat in 6:
				var sz := centre.z + (float(slat) - 2.5) * 0.28
				_quad(surfaces[1], Vector3(centre.x - 0.91, -0.047, sz - 0.014),
					Vector3(centre.x + 0.91, -0.047, sz - 0.014),
					Vector3(centre.x + 0.91, -0.047, sz + 0.014),
					Vector3(centre.x - 0.91, -0.047, sz + 0.014))
	var result: Array[ArrayMesh] = []
	for st in surfaces:
		result.append(st.commit())
	return result


static func _square(centre: Vector3, half: float, y: float) -> Array[Vector3]:
	return [centre + Vector3(-half, y, -half), centre + Vector3(half, y, -half),
		centre + Vector3(half, y, half), centre + Vector3(-half, y, half)]


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y > 0:
		normal = -normal
	_triangle(st, a, b, c, normal)
	_triangle(st, a, c, d, normal)


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, normal: Vector3) -> void:
	# Godot's clockwise front-face convention, as in PoolOpeningMesh.
	if (b - a).cross(c - a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	for point in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(point)
