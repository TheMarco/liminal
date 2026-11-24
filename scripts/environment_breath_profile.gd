extends RefCounted
## Geometry targets are prepared once. Runtime motion changes GPU blend weights.
static func targets(kind: String, size: Vector2, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == "travel":
		for i in 7:
			out.append({"center": Vector2(lerpf(-0.19, 0.19, i / 6.0) * size.x, 0),
				"size": size * Vector2(0.60, 0.90), "depth": depth, "angle": 0.0})
	else:
		out.append({"center": Vector2.ZERO, "size": size, "depth": depth, "angle": 0.0})
	return out

## (height, derivative across, derivative up), with a flat boundary.
static func sample(target: Dictionary, point: Vector2) -> Vector3:
	var q := (point - (target.center as Vector2)).rotated(-float(target.angle))
	var size: Vector2 = target.size
	var u := q.x / size.x + 0.5
	var v := q.y / size.y + 0.5
	if u <= 0 or u >= 1 or v <= 0 or v >= 1: return Vector3.ZERO
	var sx := sin(PI * u)
	var sy := sin(PI * v)
	var d: float = target.depth
	var g := Vector2(d * PI * sin(TAU * u) * sy * sy / size.x,
		d * PI * sin(TAU * v) * sx * sx / size.y).rotated(float(target.angle))
	return Vector3(d * sx * sx * sy * sy, g.x, g.y)

## Physics needs only height on a row-major rectangular grid. The authored
## bows are axis-aligned, so each row and column needs its sine only once.
static func grid_heights(target: Dictionary, points: PackedVector3Array, columns: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(points.size())
	if target.angle != 0.0:
		for i in points.size():
			heights[i] = sample(target, Vector2(points[i].x, points[i].y)).x
		return heights
	var center: Vector2 = target.center
	var size: Vector2 = target.size
	var depth: float = target.depth
	var by_column := PackedFloat64Array()
	by_column.resize(columns)
	for x in columns:
		var offset := Vector2(points[x].x, points[x].y) - center
		var sx := _grid_sine(offset.x, size.x)
		by_column[x] = depth * sx * sx
	for row in range(0, points.size(), columns):
		var offset := Vector2(points[row].x, points[row].y) - center
		var sy := _grid_sine(offset.y, size.y)
		for x in columns:
			heights[row + x] = by_column[x] * sy * sy
	return heights

static func _grid_sine(offset: float, span: float) -> float:
	var u := offset / span + 0.5
	return sin(PI * u) if u > 0.0 and u < 1.0 else 0.0

static func weights(kind: String, phase: float) -> PackedFloat32Array:
	var p := clampf(phase, 0.0, 1.0)
	var envelope := smoothstep(0.0, 0.24, p) * (1.0 - smoothstep(0.68, 1.0, p))
	if kind == "travel":
		var result := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
		var at := smoothstep(0.12, 0.88, p) * 6.0
		var lo := mini(5, floori(at))
		result[lo] = envelope * (1.0 - (at - lo))
		result[lo + 1] = envelope * (at - lo)
		return result
	return PackedFloat32Array([pow(sin(PI * p), 2.0)])

static func duration(kind: String) -> float:
	return 9.0 if kind == "travel" else 7.0
