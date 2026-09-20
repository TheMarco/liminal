class_name SpatialQuery
extends RefCounted
## Bounded one-link perception across hidden seams (spec 6.4). Every query
## tries the direct physical path first, then valid one-link paths; at most
## one nonlocal seam ever participates, by construction rather than by depth
## limit. Only enabled links answer, so admission gates perception.
##
## A one-link sight line maps the target into the observer's side space,
## intersects that segment with the seam plane, and verifies both halves as
## real rays: observer to crossing in source space, mapped crossing to
## target in destination space. Range is always the summed segment length,
## never the straight-line distance through unloaded space.

## Direct-or-link visibility. Returns {visible, via_link, apparent,
## distance, crossing}: apparent is the target as seen from the observer
## (mapped across the link when linked), crossing the seam point or INF.
static func sight(space: PhysicsDirectSpaceState3D, observer: Vector3,
		target: Vector3, links: Array, mask := 1,
		exclude: Array[RID] = []) -> Dictionary:
	var direct := observer.distance_to(target)
	if _ray_clear(space, observer, target, mask, exclude):
		return {"visible": true, "via_link": "", "apparent": target,
			"distance": direct, "crossing": Vector3.INF}
	var best := {"visible": false, "via_link": "", "apparent": target,
		"distance": INF, "crossing": Vector3.INF}
	for link in links:
		var l := link as TraversalLink
		if l == null or not l.enabled:
			continue
		_candidate(space, observer, target, l, true, mask, exclude,
			best)
		_candidate(space, observer, target, l, false, mask, exclude,
			best)
	if not bool(best["visible"]):
		best["distance"] = direct
	return best


## One attempt with the given end as the observer-side frame. M maps
## source space to destination space; N maps the target back for the
## aperture test and the apparent pose.
static func _candidate(space: PhysicsDirectSpaceState3D, observer: Vector3,
		target: Vector3, l: TraversalLink, from_a: bool, mask: int,
		exclude: Array[RID], best: Dictionary) -> void:
	var frame := l.endpoint_a if from_a else l.endpoint_b
	var m := l.mapping() if from_a else l.inverse_mapping()
	var n := l.inverse_mapping() if from_a else l.mapping()
	var inv := frame.affine_inverse()
	var o_l: Vector3 = inv * observer
	var t_l: Vector3 = inv * (n * target)
	# Opposite sides put the seam between observer and apparent target.
	# Coincident points are already touching through the seam; the
	# crossing is then the plane point facing the observer.
	var opposed := o_l.z > 0.0 and t_l.z < 0.0
	var coincident := o_l.distance_to(t_l) < 0.001
	if not opposed and not coincident:
		return
	var cross_l := o_l.lerp(t_l, o_l.z / (o_l.z - t_l.z)) if opposed \
		else Vector3(o_l.x, o_l.y, 0.0)
	var half := l.aperture_width * 0.5
	if absf(cross_l.x) > half or cross_l.y < -0.1 \
			or cross_l.y > HiddenLinkSite.PASSAGE_H + 0.1:
		return
	var crossing: Vector3 = frame * cross_l
	if not _ray_clear(space, observer, crossing, mask, exclude):
		return
	var exit: Vector3 = m * crossing
	if not _ray_clear(space, exit, target, mask, exclude):
		return
	# The crossing lies on the observer-to-apparent segment and M is
	# rigid, so the summed halves equal the apparent distance exactly.
	var distance := observer.distance_to(n * target)
	if distance < float(best["distance"]):
		best["visible"] = true
		best["via_link"] = l.id
		best["apparent"] = n * target
		best["distance"] = distance
		best["crossing"] = crossing


## Catch/ward conditions in one frame. Touching needs range plus a verified
## path, direct or linked. presentation is where the other party appears
## from here: its real position, or its mapped position across the seam.
static func contact(space: PhysicsDirectSpaceState3D, here: Vector3,
		there: Vector3, reach: float, links: Array, mask := 1,
		exclude: Array[RID] = []) -> Dictionary:
	var seen := sight(space, here, there, links, mask, exclude)
	if bool(seen["visible"]) and float(seen["distance"]) <= reach:
		return {"touching": true, "via_link": str(seen["via_link"]),
			"presentation": seen["apparent"]}
	return {"touching": false, "via_link": "", "presentation": there}


## Where a peer reads from here, without raycasts. Peer separation is
## positional in the legacy code too; mapping the position across an open
## seam keeps that contract while both actors share the paired volume.
## The basis maps the peer's velocity the same way (identity when direct).
static func apparent_pose(observer: Vector3, target: Vector3,
		links: Array) -> Dictionary:
	var best := {"position": target, "basis": Basis.IDENTITY,
		"via_link": ""}
	var best_distance := observer.distance_to(target)
	for link in links:
		var l := link as TraversalLink
		if l == null or not l.enabled:
			continue
		for from_a in [true, false]:
			var frame := l.endpoint_a if from_a else l.endpoint_b
			var n := l.inverse_mapping() if from_a else l.mapping()
			var inv := frame.affine_inverse()
			var o_l: Vector3 = inv * observer
			var t_l: Vector3 = inv * (n * target)
			var opposed := o_l.z > 0.0 and t_l.z < 0.0
			var coincident := o_l.distance_to(t_l) < 0.001
			if not opposed and not coincident:
				continue
			var cross_l := o_l.lerp(t_l, o_l.z / (o_l.z - t_l.z)) \
				if opposed else Vector3(o_l.x, o_l.y, 0.0)
			if absf(cross_l.x) > l.aperture_width * 0.5 \
					or cross_l.y < -0.1 \
					or cross_l.y > HiddenLinkSite.PASSAGE_H + 0.1:
				continue
			var mapped: Vector3 = n * target
			var distance := observer.distance_to(mapped)
			if distance < best_distance:
				best_distance = distance
				best = {"position": mapped, "basis": n.basis,
					"via_link": l.id}
	return best


static func apparent_position(observer: Vector3, target: Vector3,
		links: Array) -> Vector3:
	return apparent_pose(observer, target, links)["position"]


static func mapped_distance(observer: Vector3, target: Vector3,
		links: Array) -> float:
	return observer.distance_to(apparent_position(observer, target, links))


## Shortest audible direct or one-link path. Returns {position, distance,
## via_link}: the apparent emitter position and total path length. When no
## path verifies, the direct line is still returned, matching legacy
## unoccluded audio rather than inventing silence.
static func audio_path(space: PhysicsDirectSpaceState3D, listener: Vector3,
		emitter: Vector3, links: Array, mask := 1,
		exclude: Array[RID] = []) -> Dictionary:
	var seen := sight(space, listener, emitter, links, mask, exclude)
	if bool(seen["visible"]):
		return {"position": seen["apparent"],
			"distance": float(seen["distance"]),
			"via_link": str(seen["via_link"])}
	return {"position": emitter, "distance": listener.distance_to(emitter),
		"via_link": ""}


static func _ray_clear(space: PhysicsDirectSpaceState3D, a: Vector3,
		b: Vector3, mask: int, exclude: Array[RID]) -> bool:
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, mask, exclude)
	return space.intersect_ray(q).is_empty()
