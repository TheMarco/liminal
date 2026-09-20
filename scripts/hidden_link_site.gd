class_name HiddenLinkSite
extends Node3D
## One hidden-traversal link site: paired endpoint frames plus admission.
## Owns endpoint A/B nodes (+Z outward toward each approach) and the paired
## geometry placeholder under B pre-rotated by exactly one half-turn H.
## Endpoint frames never include a mesh half-turn; actors receive M once.
##
## Admission proves upright frames, equal floor height, a verified mapping,
## and collision-overlap equivalence between the two bands before the link
## may enable. A mismatched collider rejects the site; nothing half-opens.

const PASSAGE_W := 2.4
const PASSAGE_H := 2.7
const BAND_HALF := 2.0
const BAND_MARGIN := 0.3
const SUPPORTED_MAX_DT := 0.1
const HYSTERESIS := 0.05
const FLOOR_EPSILON := 0.01
## Matched passage, including opaque bends; not merely the transfer band.
const ENVELOPE_HALF_X := 6.4
const ENVELOPE_HALF_Z := 9.4

var link: TraversalLink
var endpoint_a: Node3D
var endpoint_b: Node3D
var paired_geometry: Node3D

var _admitted := false
var _admit_reason := ""
## Fault history: {reason, at} records, newest last. Unresolved loss is a
## reported invariant failure, never permission to relocate actors.
var _faults: Array = []
## Set while suspended: traversals and perception stop, but the last valid
## scene is retained and its floor stays leased.
var _suspended := ""


func prepare(p_id: String, a_global: Transform3D,
		b_global: Transform3D) -> Dictionary:
	if not TraversalLink.frames_valid(a_global, b_global):
		return {"ok": false, "reason": "endpoint frames not upright rigid"}
	link = TraversalLink.new(p_id, "site:%s/approach_a" % p_id,
		"site:%s/approach_b" % p_id, a_global, b_global, PASSAGE_W)
	endpoint_a = Node3D.new()
	endpoint_a.name = "EndpointA"
	endpoint_a.transform = a_global
	add_child(endpoint_a)
	endpoint_b = Node3D.new()
	endpoint_b.name = "EndpointB"
	endpoint_b.transform = b_global
	add_child(endpoint_b)
	# Paired template geometry hangs here, pre-rotated once. Campaign
	# templates attach in later packages; the node reserves the contract.
	paired_geometry = Node3D.new()
	paired_geometry.name = "PairedGeometry"
	paired_geometry.transform = Transform3D(TraversalLink.HALF_TURN,
		Vector3.ZERO)
	endpoint_b.add_child(paired_geometry)
	return {"ok": true, "reason": ""}


func admitted() -> bool:
	return _admitted


func admit_reason() -> String:
	return _admit_reason


func overlap_half_depth() -> float:
	return BAND_HALF


func aperture_fits(radius: float) -> bool:
	return radius * 2.0 <= PASSAGE_W


## Full admission: mapping identities, equal floors, and sampled
## collision-overlap equivalence across both bands. Failed admission leaves
## the link disabled with a recorded reason. Occupants (actor positions)
## refuse admission: bodies in the bands would corrupt the equivalence
## sampling, so the driver admits only an unoccupied installation.
func admit(space: PhysicsDirectSpaceState3D,
		occupants: Array = []) -> Dictionary:
	_admitted = false
	if link == null:
		_admit_reason = "site not prepared"
		return {"ok": false, "reason": _admit_reason}
	if occupied_by(occupants):
		_admit_reason = "site occupied"
		return {"ok": false, "reason": _admit_reason}
	if not link.verify_mapping():
		_admit_reason = "mapping identities failed"
		return {"ok": false, "reason": _admit_reason}
	if absf(endpoint_a.global_position.y
			- endpoint_b.global_position.y) > FLOOR_EPSILON:
		_admit_reason = "endpoint floors differ"
		return {"ok": false, "reason": _admit_reason}
	if not _overlap_equivalent(space):
		_admit_reason = "overlap bands differ under M"
		return {"ok": false, "reason": _admit_reason}
	_admitted = true
	_admit_reason = ""
	link.enabled = true
	return {"ok": true, "reason": ""}


func _overlap_equivalent(space: PhysicsDirectSpaceState3D) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = Player.BODY_RADIUS
	shape.height = Player.BODY_HEIGHT
	var m := link.mapping()
	for lx in [-0.8, 0.0, 0.8]:
		for lz in [-1.5, -0.5, 0.5, 1.5]:
			for cy in [0.5, 1.5]:
				var local := Vector3(lx, cy, lz)
				var at_a: Vector3 = endpoint_a.global_transform * local
				var at_b: Vector3 = m * at_a
				if _capsule_hits(space, shape, at_a) \
						!= _capsule_hits(space, shape, at_b):
					return false
	return true


## Hit counts, not booleans: identical floors already overlap the low
## samples on both sides, which would mask an extra box under a boolean.
func _capsule_hits(space: PhysicsDirectSpaceState3D, shape: Shape3D,
		centre: Vector3) -> int:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), centre)
	params.collision_mask = 1
	return space.intersect_shape(params, 4).size()


## Cells the driver must lease before this connection becomes traversable:
## both endpoint footprints with their approach and exit bands. Based on
## the site footprint, never on the player-centred load radius.
func streaming_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if link == null:
		return cells
	var frames: Array[Transform3D] = [endpoint_a.global_transform,
		endpoint_b.global_transform]
	for frame in frames:
		var bounds := frame * AABB(Vector3(-ENVELOPE_HALF_X, 0, -ENVELOPE_HALF_Z),
			Vector3(ENVELOPE_HALF_X * 2, PASSAGE_H, ENVELOPE_HALF_Z * 2))
		var first := TraversalGraph.world_cell(bounds.position)
		var last := TraversalGraph.world_cell(bounds.end)
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells.append(cell)
	return cells


## True while any of the given world positions stands inside either
## endpoint envelope (band plus a one-metre working margin).
func occupied_by(positions: Array) -> bool:
	if link == null:
		return false
	var frames: Array[Transform3D] = [endpoint_a.global_transform,
		endpoint_b.global_transform]
	for frame in frames:
		var inv := frame.affine_inverse()
		for position in positions:
			var local: Vector3 = inv * position
			if absf(local.x) <= ENVELOPE_HALF_X \
					and absf(local.z) <= ENVELOPE_HALF_Z \
					and local.y >= -0.5 \
					and local.y <= PASSAGE_H + 0.5:
				return true
	return false


func suspended() -> String:
	return _suspended


func faults() -> Array:
	return _faults.duplicate()


## A required resource was lost after admission. The link stops (no
## crossing, no perception) but the last valid scene is retained: floor
## stays leased, geometry stays admitted, actors stay where they are.
func note_resource_lost(reason: String) -> void:
	# The faults record is the report channel: this degradation is fully
	# handled (retained scene, stopped link), so it logs no engine error.
	# push_error stays reserved for genuinely unresolvable inconsistency,
	# which cannot occur while the driver honors occupied_by and leases.
	_faults.append({"reason": reason,
		"at": Time.get_ticks_msec() / 1000.0})
	suspend(reason)


## Stop traversal and perception, retaining everything for recovery.
func suspend(reason: String) -> void:
	_suspended = reason
	if link != null:
		link.enabled = false


## Re-verify and resume after a suspension. Recovery re-proves the bands;
## it never re-enables a link whose geometry changed underneath it, and it
## waits for occupants to leave rather than sampling through them.
func resume(space: PhysicsDirectSpaceState3D,
		occupants: Array = []) -> Dictionary:
	if link == null:
		return {"ok": false, "reason": "site not prepared"}
	if _suspended.is_empty():
		return {"ok": true, "reason": ""}
	var result := admit(space, occupants)
	if bool(result["ok"]):
		_suspended = ""
	return result


## Full teardown. Refused while occupied; on success the driver may drop
## the leased cells, knowing no actor stands on them.
func request_release(positions: Array) -> Dictionary:
	if link == null:
		return {"ok": false, "reason": "site not prepared"}
	if occupied_by(positions):
		return {"ok": false, "reason": "site occupied"}
	_admitted = false
	_admit_reason = ""
	_suspended = ""
	link.enabled = false
	return {"ok": true, "reason": ""}
