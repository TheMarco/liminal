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
