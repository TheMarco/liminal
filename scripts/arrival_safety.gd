class_name ArrivalSafety
extends RefCounted
## Runtime landing resolver shared by portal travel and the headless audit. It
## tests the real generated collision world, not an approximation of the room
## style, and requires both standing room and at least two escape directions.

const RADIUS := 0.40
const HEIGHT := 1.80
const STANDING_CLEARANCE := 0.15
const PROBE_STEP := 0.82
const ESCAPE_STEP := 1.64

const OFFSETS := [
	Vector2(2.0, 2.0), Vector2(6.0, 2.0), Vector2(10.0, 2.0),
	Vector2(2.0, 6.0), Vector2(10.0, 6.0),
	Vector2(2.0, 10.0), Vector2(6.0, 10.0), Vector2(10.0, 10.0),
	Vector2(4.0, 4.0), Vector2(8.0, 4.0),
	Vector2(4.0, 8.0), Vector2(8.0, 8.0),
]
const DIRS := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
	Vector3(0.7071, 0, 0.7071), Vector3(-0.7071, 0, 0.7071),
	Vector3(0.7071, 0, -0.7071), Vector3(-0.7071, 0, -0.7071),
]


static func find_safe(world: World3D, desired: Vector3, cellv: Vector2i,
		exclude: Array[RID] = []) -> Vector3:
	# CharacterBody3D settles exactly onto y=0 while walking, and that is the
	# value stored for floor-number travel. A capsule tested at that exact plane
	# can count the supporting floor as an overlap. Probe and return the same
	# small standing clearance used by portal arrivals.
	var standing := desired
	standing.y = maxf(standing.y, STANDING_CLEARANCE)
	# Preserve an already-valid point. Besides respecting saved floor positions,
	# this keeps a known central corridor landing from being "improved" into a
	# clear but inaccessible service strip behind the corridor shell.
	if is_clear(world, standing, exclude) and has_floor(world, standing, exclude) \
			and escape_count(world, standing, exclude) >= 2:
		return standing
	var candidates: Array[Vector3] = [standing]
	for off in OFFSETS:
		candidates.append(Vector3(float(cellv.x) * 12.0 + off.x, standing.y,
			float(cellv.y) * 12.0 + off.y))
	var best := Vector3.INF
	var best_score := -1e9
	for p in candidates:
		if not is_clear(world, p, exclude) or not has_floor(world, p, exclude):
			continue
		var exits := escape_count(world, p, exclude)
		if exits < 2:
			continue
		# Escape count is a pass/fail safety condition, not a reason to teleport
		# across the room. Among fallbacks, remain as close as possible to the
		# intended arrival and use additional exits only as a small tie-breaker.
		var score := -p.distance_to(standing) + float(exits) * 0.05
		if score > best_score:
			best_score = score
			best = p
	return best


static func is_clear(world: World3D, p: Vector3, exclude: Array[RID] = []) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, HEIGHT * 0.5, 0))
	q.collision_mask = 1
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = exclude
	return world.direct_space_state.intersect_shape(q, 4).is_empty()


static func has_floor(world: World3D, p: Vector3, exclude: Array[RID] = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		p + Vector3(0, 0.55, 0), p + Vector3(0, -1.25, 0), 1, exclude)
	q.collide_with_areas = false
	var hit := world.direct_space_state.intersect_ray(q)
	return not hit.is_empty() and (hit["normal"] as Vector3).y > 0.72 \
		and float((hit["position"] as Vector3).y) > -0.42


static func escape_count(world: World3D, p: Vector3, exclude: Array[RID] = []) -> int:
	var count := 0
	for d in DIRS:
		if is_clear(world, p + d * PROBE_STEP, exclude) \
				and is_clear(world, p + d * ESCAPE_STEP, exclude) \
				and has_floor(world, p + d * ESCAPE_STEP, exclude):
			count += 1
	return count
