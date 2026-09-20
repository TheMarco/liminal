class_name EnemyTraversal
extends RefCounted
## Physical traversal shared by every pursuer. Water is empty space above a
## real basin floor, not forbidden terrain. Climbing uses the player's actual
## ladder volumes; slopes use the same capsule envelope and 45-degree limit.

const SKIN := 0.04
const SAMPLE := 0.20
const MAX_DROP := 8.0
const CLIMB_STEP := 0.10
var player: Player
var query := PhysicsShapeQueryParameters3D.new()

func _init(p: Player) -> void:
	player = p
	var shape := CapsuleShape3D.new()
	shape.radius = Player.BODY_RADIUS
	shape.height = Player.BODY_HEIGHT
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	query.margin = 0.001

func body_clear(from: Vector3, to: Vector3, ignored: RID = RID()) -> bool:
	var excluded: Array[RID] = [player.get_rid()]
	if ignored.is_valid(): excluded.append(ignored)
	query.exclude = excluded
	query.transform = Transform3D(Basis.IDENTITY, to + Vector3.UP * (Player.BODY_HEIGHT * 0.5 + SKIN))
	query.motion = Vector3.ZERO
	var space := player.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	if from.is_equal_approx(to): return true
	query.transform.origin = from + Vector3.UP * (Player.BODY_HEIGHT * 0.5 + SKIN)
	query.motion = to - from
	return space.cast_motion(query)[0] >= 1.0

func ladder_area(at: Vector3) -> Area3D:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at + Vector3.UP * (Player.BODY_HEIGHT * 0.5)
	q.collision_mask = Player.LADDER_LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in player.get_world_3d().direct_space_state.intersect_point(q, 8):
		var area := hit.collider as Area3D
		if area != null:
			return area
	return null

func ladder(at: Vector3) -> bool:
	return ladder_area(at) != null

## Pool ladders author one unambiguous dry-side landing. Returning that point
## lets pursuers finish the whole climb before replanning instead of reaching
## lip height on the wet side, choosing a downward edge, and bobbing beside it.
## Other ladder volumes deliberately retain their existing free-form behavior.
func ladder_landing(at: Vector3) -> Vector3:
	var area := ladder_area(at)
	if area == null or not area.has_meta("enemy_ladder_landing_local"):
		return Vector3.INF
	var local_landing: Vector3 = area.get_meta("enemy_ladder_landing_local")
	return area.to_global(local_landing)

func ladder_climb_point(at: Vector3) -> Vector3:
	var area := ladder_area(at)
	if area == null or not area.has_meta("enemy_ladder_climb_local"):
		return Vector3.INF
	var local_climb: Vector3 = area.get_meta("enemy_ladder_climb_local")
	return area.to_global(local_climb)

func ladder_facing(at: Vector3) -> Vector3:
	var area := ladder_area(at)
	if area == null or not area.has_meta("enemy_ladder_facing_local"):
		return Vector3.ZERO
	var local_facing: Vector3 = area.get_meta("enemy_ladder_facing_local")
	var world_facing := area.global_basis * local_facing
	world_facing.y = 0.0
	return world_facing.normalized() if world_facing.length_squared() > 0.0001 \
		else Vector3.ZERO

func belt_velocity(at: Vector3) -> Vector3:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at + Vector3.UP * (Player.BODY_HEIGHT * 0.5)
	q.collision_mask = 1
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in player.get_world_3d().direct_space_state.intersect_point(q):
		if hit.collider is Travelator:
			return hit.collider.dirv * hit.collider.speed
	return Vector3.ZERO

## Cast the full capsule onto the floor, so a slope supports the rounded foot
## exactly as it supports the player's CharacterBody, rather than clipping its
## uphill side or assuming the root stays at the ray's centre height.
func ground(at: Vector3, rise := 0.3) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var top := at + Vector3.UP * rise
	var ray := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.06,
		at - Vector3.UP * MAX_DROP, 1, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	var resting := Vector3.INF
	if not hit.is_empty() and (hit.normal as Vector3).y >= cos(PI / 4.0) - 0.001:
		resting = Vector3(at.x, (hit.position as Vector3).y \
			+ Player.BODY_RADIUS * (1.0 / (hit.normal as Vector3).y - 1.0), at.z)
		if body_clear(resting, resting): return resting
	query.exclude = [player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, top + Vector3.UP * (Player.BODY_HEIGHT * 0.5 + SKIN))
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty(): return Vector3.INF
	query.motion = Vector3.DOWN * (rise + MAX_DROP)
	var fractions := space.cast_motion(query)
	var fraction: float = fractions[0]
	if fraction >= 1.0: return Vector3.INF
	var foot := top + query.motion * fraction
	# Confirm a floor below the centre, rather than treating a wall's rounded
	# contact with the capsule as a staircase onto furniture.
	if hit.is_empty() or (hit.normal as Vector3).y < cos(PI / 4.0) - 0.001:
		# At a ramp end the centre ray can hit its bevel while the capsule is
		# supported by the walkable slope beside it. Use the actual body contact.
		query.transform.origin = top + Vector3.UP * (Player.BODY_HEIGHT * 0.5 + SKIN) \
			+ query.motion * float(fractions[1]) - Vector3.UP * 0.01
		query.motion = Vector3.ZERO
		var rest := space.get_rest_info(query)
		if rest.is_empty() or (rest.normal as Vector3).y < cos(PI / 4.0) - 0.001:
			return Vector3.INF
		return foot + Vector3.UP * SKIN
	foot.y = maxf(foot.y + SKIN, resting.y)
	return foot

func project(from: Vector3, at: Vector3) -> Vector3:
	var distance := Vector2(at.x - from.x, at.z - from.z).length()
	var floor_point := ground(Vector3(at.x, from.y, at.z), minf(0.6, distance + 0.06))
	if floor_point != Vector3.INF and floor_point.y <= from.y + distance + 0.065:
		return floor_point
	# A ladder can support an airborne body, but only inside the same volumes
	# that enable player climbing. No generic wall-climbing fallback.
	var level := Vector3(at.x, from.y, at.z)
	if ladder(from) and ladder(level) and body_clear(from, level): return level
	return Vector3.INF

func extra_neighbors(from: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = player.traversal_neighbors(from)
	if ladder(from):
		for sign_y: float in [-1.0, 1.0]:
			var next := from + Vector3.UP * CLIMB_STEP * sign_y
			if ladder(next) and body_clear(from, next): result.append(next)
	return result

## A checked polyline is used both by planning and locomotion. In particular
## a drop goes over the lip before descending; smoothing cannot cut diagonally
## through the solid deck. Unsupported horizontal travel is never accepted.
func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var flat := Vector2(to.x - from.x, to.z - from.z).length()
	if flat < 0.001:
		if from.distance_to(to) < 0.02: return [to]
		if ladder(from) and ladder(to) and body_clear(from, to): return [to]
		return result
	var count := maxi(1, ceili(flat / SAMPLE))
	var previous := from
	for index in range(1, count + 1):
		var target := from.lerp(to, float(index) / count)
		var next := project(previous, target)
		if next == Vector3.INF: return []
		if next.y < previous.y - 0.12:
			var lip := Vector3(next.x, previous.y, next.z)
			if not body_clear(previous, lip) or not body_clear(lip, next): return []
			result.append(lip)
		elif not body_clear(previous, next):
			return []
		result.append(next)
		previous = next
	if absf(previous.y - to.y) > 0.13:
		# Same XZ above/below a deck is not the same destination.
		return []
	return result

func clear(from: Vector3, to: Vector3) -> bool:
	return not path(from, to).is_empty()
