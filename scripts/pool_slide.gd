class_name PoolSlide
extends Area3D
## A narrow entry trigger and the authored chute path. Only the player samples
## this data; installed slides do no per-frame work of their own.
const ENTRY_LAYER := 16
const START_SPEED := 1.2
const MAX_SPEED := 4.5
const FOOT_CLEARANCE := 0.14
var points := PackedVector3Array()
var distances := PackedFloat32Array()
var length := 0.0
var collision_body: StaticBody3D

func configure(samples: Array) -> void:
	collision_layer = ENTRY_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	for value: Array in samples:
		points.append(Vector3(float(value[0]), float(value[1]), float(value[2])))
		distances.append(length)
		if points.size() > 1:
			length += points[-1].distance_to(points[-2])
			distances[-1] = length
	var tangent := (points[1] - points[0]).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.64, 0.60, 0.62)
	var trigger := CollisionShape3D.new()
	trigger.shape = shape
	trigger.position = points[0] + tangent * 0.16 + Vector3.UP * 0.23
	trigger.rotation.y = atan2(tangent.x, tangent.z)
	add_child(trigger)

func point_at(distance: float) -> Vector3:
	var d := clampf(distance, 0.0, length)
	for i in range(1, points.size()):
		if distances[i] >= d:
			var weight := inverse_lerp(distances[i - 1], distances[i], d)
			return to_global(points[i - 1].lerp(points[i], weight))
	return to_global(points[-1])

func tangent_at(distance: float) -> Vector3:
	return (point_at(minf(length, distance + 0.10)) \
		- point_at(maxf(0.0, distance - 0.10))).normalized()

func can_board(feet: Vector3) -> bool:
	var local := to_local(feet) - points[0]
	# The ladder, ground beneath the slide and the outside of a side wall
	# must never pull the player onto the chute.
	return absf(local.y) < 0.28 and Vector2(local.x, local.z).length() < 0.48

func entry_distance(feet: Vector3) -> float:
	var local := to_local(feet) - Vector3.UP * FOOT_CLEARANCE
	var best := INF
	var distance := 0.0
	for i in range(1, points.size()):
		if distances[i - 1] > 0.6: break
		var delta := points[i] - points[i - 1]
		var weight := clampf((local - points[i - 1]).dot(delta) / delta.length_squared(), 0.0, 1.0)
		var separation := local.distance_squared_to(points[i - 1] + delta * weight)
		if separation < best:
			best = separation
			distance = lerpf(distances[i - 1], distances[i], weight)
	return distance
