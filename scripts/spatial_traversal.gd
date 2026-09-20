class_name SpatialTraversal
extends RefCounted
## Explicit traversal phase for hidden links. Consumes post-movement
## previous-to-result segments, solves signed plane crossings, verifies
## full-capsule aperture clearance and paired landing occupancy, then maps
## position, orientation, and velocity by M exactly once per crossing.
## Overshoot is transformed, never snapped; refusals restore a safe
## approach pose with a recorded reason. No second movement pass runs here
## movement pass follows a transfer.

var _sites: Array[HiddenLinkSite] = []
var _sides := {} # "site_id:body_id" -> +1 approach / -1 beyond
var _listener := Callable()
var _audio_bridge: SeamAudioBridge = null
var _last_refusal := ""
var _actors: Array[WeakRef] = []


## Live actors invoke this helper inside their normal movement tick, not
## from a SceneTree frame callback after history/perception has run.
func bind_actor(body: Node3D) -> void:
	_actors = _actors.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null)
	for ref in _actors:
		if ref.get_ref() == body:
			return
	_actors.append(weakref(body))
	body.set("spatial_traversal", self)
	# Player motion/transfer completes before figure contact/perception. Each
	# figure in turn publishes one complete move, never a half-mapped pose.
	body.process_physics_priority = -20 if body is Player else -10


func _motions(body: Node3D, from: Vector3) -> Array:
	var motions: Array = [{"body": body, "from": from}]
	for ref in _actors:
		var other = ref.get_ref()
		if is_instance_valid(other) and other != body:
			motions.append({"body": other, "from": other.global_position})
	return motions


func after_motion(body: Node3D, from: Vector3, _dt: float) -> void:
	# Only this actor moved in this transaction. Other actors participate in
	# occupancy but are not replayed as crossing candidates.
	var motions := _motions(body, from)
	_transfer_one(body, from, motions, body.get_world_3d().direct_space_state)


## Sweep against mapped peers before normal collision movement. Both actor
## controllers use the same capsule footprint and keep their usual terrain
## solver. A disabled/ineligible link behaves as a closed crossing plane.
func constrain_motion(body: Node3D, from: Vector3, to: Vector3, eligible := true) -> Vector3:
	var result := to
	for site in _sites:
		if not site.admitted():
			continue
		for end in ["a", "b"]:
			var frame := site.link.endpoint_a if end == "a" else site.link.endpoint_b
			var map := site.link.mapping() if end == "a" else site.link.inverse_mapping()
			var inv := frame.affine_inverse()
			var start: Vector3 = inv * from
			var finish: Vector3 = inv * result
			if start.z < -HiddenLinkSite.HYSTERESIS or start.z > site.BAND_HALF + 1.0 \
					or absf(start.x) > site.PASSAGE_W * 0.5:
				continue
			if (not site.link.enabled or not eligible) and finish.z < HiddenLinkSite.HYSTERESIS:
				finish.z = HiddenLinkSite.HYSTERESIS + 0.001
				result = frame * finish
			for ref in _actors:
				var other = ref.get_ref()
				if not is_instance_valid(other) or other == body:
					continue
				var mapped: Vector3 = map.affine_inverse() * other.global_position
				var local: Vector3 = inv * mapped
				if local.z > HiddenLinkSite.HYSTERESIS or local.z < -site.BAND_HALF - 1.0 \
						or absf(local.x) > site.PASSAGE_W * 0.5 \
						or absf(mapped.y - from.y) >= Player.BODY_HEIGHT:
					continue
				var delta := Vector2(result.x - from.x, result.z - from.z)
				var relative := Vector2(from.x - mapped.x, from.z - mapped.z)
				var radius := Player.BODY_RADIUS * 2.0 + 0.01
				if delta.length_squared() < 0.0000001 or relative.dot(delta) >= 0.0:
					continue
				var b := relative.dot(delta)
				var c := relative.length_squared() - radius * radius
				var discriminant := b * b - delta.length_squared() * c
				if discriminant < 0.0:
					continue
				var fraction := maxf(0.0, (-b - sqrt(discriminant)) / delta.length_squared())
				if fraction < 1.0:
					result = from.lerp(result, fraction)
	return result


func add_site(site: HiddenLinkSite) -> void:
	if not _sites.has(site):
		_sites.append(site)


func set_listener(listener: Callable) -> void:
	_listener = listener


## Optional crossing duck: notified with every batch that transfers at
## least one body, so drivers cannot forget the audio contract.
func set_audio_bridge(bridge: SeamAudioBridge) -> void:
	_audio_bridge = bridge


func last_refusal() -> String:
	return _last_refusal


## Transit permit for one actor and link: paired readiness (admitted,
## enabled, fitting aperture) checked up front. The motion entry may carry
## it as "permit"; the crossing revalidates the named link, so a revision
## between issue and crossing refuses loudly instead of stranding.
func issue_permit(body: Node3D, link_id: String) -> Dictionary:
	for site in _sites:
		if site.link.id != link_id:
			continue
		if not site.admitted():
			return {"ok": false, "reason": "site not admitted"}
		if not site.link.enabled:
			return {"ok": false, "reason": "link not enabled"}
		if not site.aperture_fits(Player.BODY_RADIUS):
			return {"ok": false, "reason": "aperture too narrow"}
		return {"ok": true, "body": body.get_instance_id(),
			"link": link_id}
	return {"ok": false, "reason": "unknown link"}


func _permit_for(body: Node3D, motions: Array) -> Dictionary:
	for motion in motions:
		if motion.get("body") == body:
			return motion.get("permit", {})
	return {}


## Out-of-band repositioning (teleports, spawns) is never a crossing.
func note_repositioned(body: Node3D) -> void:
	var tail := ":%d" % body.get_instance_id()
	for key in _sides.keys():
		if str(key).ends_with(tail):
			_sides.erase(key)


## One traversal phase. motions: Array of {body, from, allow?}. Reads
## each result from the body itself so callers pass pre-move positions
## only. Optional allow=false vetoes the transfer per actor (eligibility
## hook); refusals append nothing and set last_refusal().
func step(_dt: float, motions: Array) -> Array:
	var out: Array = []
	var space := _space_of(motions)
	for motion in motions:
		# Frees land during the physics the phase follows (burns,
		# catches), so a body valid at sample time may be dead by the
		# crossing check. Skip it: erroring here would abort the whole
		# phase and strand every body listed after it.
		if not is_instance_valid(motion.get("body")):
			continue
		var body: Node3D = motion["body"]
		var record := _transfer_one(body, motion["from"], motions, space)
		if not record.is_empty():
			out.append(record)
	if is_instance_valid(_audio_bridge) and not out.is_empty():
		_audio_bridge.notify_crossed()
	return out


func _space_of(motions: Array) -> PhysicsDirectSpaceState3D:
	for motion in motions:
		if not is_instance_valid(motion.get("body")):
			continue
		var body: Object = motion["body"]
		if body is CollisionObject3D:
			return (body as CollisionObject3D).get_world_3d() \
				.direct_space_state
	return null


func _transfer_one(body: Node3D, from: Vector3, motions: Array,
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var result: Vector3 = body.global_position
	var allow := true
	for motion in motions:
		if motion.get("body") == body:
			allow = bool(motion.get("allow", true))
			break
	for site in _sites:
		if not site.admitted():
			continue
		var link := site.link
		for end in ["a", "b"]:
			var frame: Transform3D
			var map: Transform3D
			if end == "a":
				frame = site.endpoint_a.global_transform
				map = link.mapping()
			else:
				frame = site.endpoint_b.global_transform
				map = link.inverse_mapping()
			var inv := frame.affine_inverse()
			var from_l: Vector3 = inv * from
			var result_l: Vector3 = inv * result
			var key := "%s:%s:%d" % [link.id, end,
				body.get_instance_id()]
			if not _poll_flip(key, site, from_l, result_l):
				continue
			if not allow:
				return _reject(body, from, frame, key, "actor ineligible")
			var permit := _permit_for(body, motions)
			if not permit.is_empty():
				if int(permit.get("body", -1)) \
						!= body.get_instance_id():
					return _reject(body, from, frame, key, "permit names another actor")
				if str(permit.get("link", "")) != link.id:
					return _reject(body, from, frame, key, "permit names another link")
				if not link.enabled:
					return _reject(body, from, frame, key, "stale permit")
			elif not link.enabled:
				return _reject(body, from, frame, key, "link not enabled")
			return _attempt(body, site, link, end, from, result, map,
				motions, space, key)
	return {}


## Schmitt trigger on the settled side: observations inside the band
## never flip, so jitter cannot chatter, while a genuine crossing flips
## on the first tick its result lands past the far edge. Only an
## approach-to-beyond flip enters the link; the reverse flip just walks
## back out on the same side. A flip additionally requires the crossing
## to pass through this end's aperture rectangle, so a far-field segment
## can never fire the wrong end's infinite plane.
func _poll_flip(key: String, site: HiddenLinkSite, from_l: Vector3,
		result_l: Vector3) -> bool:
	_remember_side(key, from_l.z)
	var before := int(_sides[key])
	var after := before
	if result_l.z > HiddenLinkSite.HYSTERESIS:
		after = 1
	elif result_l.z < -HiddenLinkSite.HYSTERESIS:
		after = -1
	else:
		return false
	_sides[key] = after
	if not (before > 0 and after < 0):
		return false
	return _through_aperture(site, from_l, result_l)


func _through_aperture(site: HiddenLinkSite, from_l: Vector3,
		result_l: Vector3) -> bool:
	var spans := (from_l.z > 0.0 and result_l.z < 0.0) \
		or (from_l.z < 0.0 and result_l.z > 0.0) \
		or (from_l.z == 0.0 and result_l.z != 0.0)
	var gate := result_l
	if spans:
		var t := from_l.z / (from_l.z - result_l.z)
		gate = from_l.lerp(result_l, t)
	else:
		if absf(result_l.z) > site.overlap_half_depth():
			return false
	return absf(gate.x) <= site.PASSAGE_W * 0.5 \
		and gate.y >= -0.1 and gate.y <= site.PASSAGE_H + 0.1


func _remember_side(key: String, from_z: float) -> void:
	if from_z > HiddenLinkSite.HYSTERESIS:
		_sides[key] = 1
	elif from_z < -HiddenLinkSite.HYSTERESIS:
		_sides[key] = -1
	elif not _sides.has(key):
		_sides[key] = 1 if from_z >= 0.0 else -1


func _attempt(body: Node3D, site: HiddenLinkSite, link: TraversalLink,
		end: String, from: Vector3, result: Vector3, map: Transform3D,
		motions: Array, space: PhysicsDirectSpaceState3D,
		key: String) -> Dictionary:
	var radius := Player.BODY_RADIUS
	var height := Player.BODY_HEIGHT
	var entry_frame := site.endpoint_a.global_transform if end == "a" else site.endpoint_b.global_transform
	if not site.aperture_fits(radius):
		return _reject(body, from, entry_frame, key, "aperture too narrow")
	var mapped: Vector3 = map * result
	var exit_frame: Transform3D = site.endpoint_b.global_transform \
		if end == "a" else site.endpoint_a.global_transform
	var exit_l: Vector3 = exit_frame.affine_inverse() * mapped
	# Same vertical margin as the entry aperture: feet-origin actors
	# rest at y≈0 with float jitter either side, and a margin-free exit
	# check refuses every crossing the entry check admits.
	if absf(exit_l.z) > site.overlap_half_depth() \
			or absf(exit_l.x) > site.PASSAGE_W * 0.5 \
			or exit_l.y < -0.1 or exit_l.y > site.PASSAGE_H + 0.1:
		return _reject(body, from, entry_frame, key, "exit outside overlap band")
	if not _landing_clear(body, mapped, radius, motions):
		return _reject(body, from, entry_frame, key, "exit occupied")
	if space != null and not _capsule_clear(space, body, mapped, radius,
			height):
		return _reject(body, from, entry_frame, key, "exit blocked")
	_apply(body, mapped, map)
	# Departure memory already holds the flipped far side; arrival memory
	# starts on the destination approach side so an immediate deliberate
	# reverse transfers instead of escaping unmapped.
	var arrival := "%s:%s:%d" % [link.id,
		"a" if end == "b" else "b", body.get_instance_id()]
	_sides[arrival] = 1
	var record := {"link": link.id, "site": site, "body": body,
		"from": from, "result": result, "mapped": mapped,
		"direction": "a_to_b" if end == "a" else "b_to_a"}
	if _listener.is_valid():
		_listener.call(record)
	return record


func _reject(body: Node3D, from: Vector3, frame: Transform3D, key: String, reason: String) -> Dictionary:
	# Race/fault fallback: return only this tick's movement to the known-safe
	# approach. Never leave a refused actor in the decorative continuation.
	var local := frame.affine_inverse() * from
	local.z = maxf(local.z, HiddenLinkSite.HYSTERESIS + 0.001)
	var safe := frame * local
	if body.has_method("reject_seam_motion"):
		body.reject_seam_motion(safe)
	else:
		body.global_position = safe
	_sides[key] = 1
	_last_refusal = reason
	return {}


## Paired landing occupancy against every other actor's current position.
## Sequential application gives natural yielding: an actor that already
## transferred this phase is tested at its mapped position.
func _landing_clear(body: Node3D, exit: Vector3, radius: float,
		motions: Array) -> bool:
	for motion in motions:
		if not is_instance_valid(motion.get("body")):
			continue
		var other: Node3D = motion["body"]
		if other == body:
			continue
		if other.global_position.distance_to(exit) < radius * 2.0:
			return false
	return true


func _capsule_clear(space: PhysicsDirectSpaceState3D, body: Node3D,
		exit: Vector3, radius: float, height: float) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	params.shape = shape
	# A standing actor's origin sits at (or a hair under) the floor
	# plane, so an unlifted capsule bottom reads resting contact as a
	# blocker. One centimetre of skin clears the floor without stepping
	# over any real obstacle.
	params.transform = Transform3D(Basis(),
		exit + Vector3(0, height * 0.5 + 0.01, 0))
	params.collision_mask = 1
	if body is CollisionObject3D:
		params.exclude = [(body as CollisionObject3D).get_rid()]
	return space.intersect_shape(params, 1).is_empty()


func _apply(body: Node3D, mapped: Vector3, map: Transform3D) -> void:
	# Actors with a seam contract rebase their own full state (movement
	# history, camera, route caches); anything else gets the rigid minimum.
	if body.has_method("apply_seam_transfer"):
		body.apply_seam_transfer(map)
		return
	body.global_position = mapped
	var basis: Basis = (map.basis * body.global_transform.basis) \
		.orthonormalized()
	body.global_transform = Transform3D(basis, mapped)
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = map.basis \
			* (body as CharacterBody3D).velocity
