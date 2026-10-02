extends RefCounted
## Smooth, tapered vascular meshes. A whole ceiling shares one draw surface;
## branch roots and tips are continuous rather than stacks of capped cylinders.
## Finite shared growth modules are retained for the active floor.
static var _structural_cache: Dictionary = {}

## Shared ring vertices avoid sending six copies of each triangle corner to
## SurfaceTool. Indices preserve the same winding, normals and silhouette.
class TubeMesh:
	extends RefCounted
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

static func clear_runtime_cache() -> void:
	_structural_cache.clear()

static func canopy(height: float, variant: int, narrow: bool) -> ArrayMesh:
	var key := "%.3f_%d_%s" % [height, variant, narrow]
	if _structural_cache.has(key): return _structural_cache[key]
	var st := TubeMesh.new()
	var span := 1.95 if narrow else 5.98
	var sag := minf(0.90, maxf(0.20, height - 2.80))
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := 1.25 + float(i) * 3.0
			var phase := float(variant) * 0.78 + float(i) * 1.82
			var points := PackedVector3Array([
				Vector3(6 + side * span, height - sag, z),
				Vector3(6 + side * span * 0.79, height - sag * 0.46, z + sin(phase) * 0.52),
				Vector3(6 + side * span * 0.31, height - 0.17, z + 0.75),
				Vector3(6 - side * 0.42, height - 0.27, minf(11.8, z + 1.55))])
			_tube(st, points, 0.18 if narrow else 0.28, 0.028, phase)
			for j in 3:
				var along := float(j) / 3.0
				var a := points[1].lerp(points[2], along)
				var b := a + Vector3(side * span * 0.18, -0.13, -0.42)
				var c := a + Vector3(side * span * 0.33, -0.20, -1.1)
				_tube(st, PackedVector3Array([a, b, c, c + Vector3(side * 0.25, 0.1, -0.25)]), 0.065, 0.007, phase + j)
	# A twisted central bundle ties the ribs together across chunk boundaries.
	for side in [-1.0, 1.0]:
		_tube(st, PackedVector3Array([Vector3(6 + side * 0.11, height - 0.23, 0),
			Vector3(6 + side * 0.22, height - 0.37, 4), Vector3(6 - side * 0.22, height - 0.24, 8),
			Vector3(6 + side * 0.11, height - 0.23, 12)]), 0.12, 0.12, variant)
	var mesh := st.commit()
	_structural_cache[key] = mesh
	return mesh

static func wall(width: float, height: float, variant: int) -> ArrayMesh:
	var key := "wall_%.3f_%.3f_%d" % [width, height, variant]
	if _structural_cache.has(key): return _structural_cache[key]
	var st := TubeMesh.new()
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 - 0.22)
		var points := PackedVector3Array([Vector3(x, 0.04, 0),
			Vector3(x - side * 0.20, height * 0.27, 0.10),
			Vector3(x - side * minf(0.5, width * 0.15), height * 0.65, 0.02),
			Vector3(x - side * minf(0.8, width * 0.22), height, 0)])
		_tube(st, points, 0.12, 0.042, variant + side)
		for j in 3:
			var y := height * (0.24 + float(j) * 0.22)
			var w := minf(width * 0.38, 1.75)
			_tube(st, PackedVector3Array([Vector3(x - side * 0.15, y, 0.05),
				Vector3(x - side * w * 0.35, y + 0.1, 0.07),
				Vector3(x - side * w * 0.75, y - 0.20, 0.02),
				Vector3(x - side * w, y - 0.38, 0.0)]), 0.045, 0.005, variant + j)
	var mesh := st.commit()
	_structural_cache[key] = mesh
	return mesh

static func _tube(st: TubeMesh, points: PackedVector3Array, base: float,
		tip: float, phase: float) -> void:
	var offset := st.vertices.size()
	var samples := (points.size() - 1) * 8
	for i in samples + 1:
		var t := float(i) / float(samples)
		var centre := _sample(points, t)
		var tangent := (_sample(points, minf(1.0, t + 0.003)) - _sample(points, maxf(0.0, t - 0.003))).normalized()
		var side := tangent.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.1: side = tangent.cross(Vector3.UP).normalized()
		var up := tangent.cross(side).normalized()
		for j in 10:
			var a := float(j) * TAU / 10.0
			var n := side * cos(a) + up * sin(a)
			var r := lerpf(base, tip, t) * (1.0 + 0.09 * sin(t * 24.0 + phase + a * 3.0))
			st.vertices.append(centre + n * r)
			st.normals.append(n)
			st.uvs.append(Vector2(float(j) / 10.0, float(i) / 8.0))
	for i in samples:
		for j in 10:
			var k := (j + 1) % 10
			for v in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i,k), Vector2i(i,k), Vector2i(i+1,j), Vector2i(i+1,k)]:
				st.indices.append(offset + v.x * 10 + v.y)
	# Close branch ends; their broad roots can remain visible at open room joins.
	for end in [0,samples]:
		var centre := points[0] if end == 0 else points[points.size()-1]
		var normal := (points[0]-points[1]).normalized() if end == 0 else (points[points.size()-1]-points[points.size()-2]).normalized()
		var cap := st.vertices.size()
		st.vertices.append(centre)
		st.normals.append(normal)
		st.uvs.append(Vector2.ZERO)
		for j in 10:
			st.vertices.append(st.vertices[offset + end * 10 + j])
			st.normals.append(normal)
			st.uvs.append(Vector2.ZERO)
		for j in 10:
			var k := (j+1)%10
			st.indices.append(cap)
			st.indices.append(cap + 1 + (j if end == 0 else k))
			st.indices.append(cap + 1 + (k if end == 0 else j))

static func _sample(points: PackedVector3Array, t: float) -> Vector3:
	var f := t * float(points.size() - 1)
	var i := mini(int(f), points.size() - 2)
	return points[i].cubic_interpolate(points[i+1], points[maxi(0,i-1)], points[mini(points.size()-1,i+2)], f - float(i))

static func pool(size: Vector2, variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		for index in [i, i + 1]:
			var a := float(index) * TAU / 64.0
			var r := 0.43 + sin(a * 3.0 + variant) * 0.045 + cos(a * 7.0) * 0.025
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(cos(a) * size.x * r, 0, sin(a) * size.y * r))
	return st.commit()


static func membranes(height: float, variant: int, narrow: bool) -> ArrayMesh:
	var key := "membrane_%.3f_%d_%s" % [height,variant,narrow]
	if _structural_cache.has(key): return _structural_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := 1.50 if narrow else 5.4
	var drop := minf(1.4,maxf(0.18,height-2.65))
	for side in [-1.0,1.0]:
		for z in [2.0,8.0]:
			var vertices: Array[Vector3] = []
			for j in 5:
				var v := float(j)/4.0
				for i in 49:
					var u := float(i)/48.0
					var bottom := sin(u*PI)*0.65+0.18+sin(u*PI*5.0+variant)*0.07
					vertices.append(Vector3(6+side*(span-u*0.38)+sin(u*TAU*2.0+v)*0.08,
						height-0.12-v*drop*bottom,z+u*2.6-1.3))
			for j in 4:
				for i in 48:
					var a := j*49+i
					for index in [a,a+49,a+1,a+1,a+49,a+50]:
						st.set_normal(Vector3.RIGHT*side)
						st.set_uv(Vector2(float(index%49)/48.0,float(index/49)/4.0))
						st.add_vertex(vertices[index])
	st.index()
	var mesh := st.commit()
	_structural_cache[key] = mesh
	return mesh


## Keep the ceiling contact at its true elevation. Only the sag is quantized
## (at most 5 cm); taller rooms translate the same fully sagged module.
static func canopy_height(height: float) -> float:
	return clampf(snappedf(height,0.1),3.1,3.7)

static func membrane_height(height: float) -> float:
	return clampf(snappedf(height,0.1),3.1,4.05)

static func wall_width(width: float) -> float:
	for span in [1.25,2.0,3.0,4.6,6.0,12.0]:
		if width <= span: return span
	return 12.0

## Called during the opaque floor load, never on the movement critical path.
static func prewarm() -> void:
	for variant in 6:
		canopy(3.1,variant,true)
		membranes(3.1,variant,true)
		for tenth in range(32,38): canopy(float(tenth)/10.0,variant,false)
		for tenth in range(32,41): membranes(float(tenth)/10.0,variant,false)
		membranes(4.05,variant,false)
		for span in [1.25,2.0,3.0,4.6,6.0,12.0]: wall(span,4.0,variant)
