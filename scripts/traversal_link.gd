class_name TraversalLink
extends RefCounted
## One hidden-traversal connection between two endpoint frames. Pure data and
## rigid math; the site owns admission, leases, and the crossing detector.
##
## Endpoint convention (spec 6.3): rigid transforms, unit scale, local +Z
## points outward toward the approach. With the 180-degree local yaw turn H,
## M = B * H * inverse(A) maps source-space points to destination space and
## inverse(M) maps back. Endpoint frames never include a mesh half-turn;
## paired geometry hangs under B pre-rotated by H instead.

## 180-degree local yaw turn shared by every link.
const HALF_TURN := Basis(Vector3.UP, PI)
const SIDE_EPSILON := 0.05
const IDENTITY_EPSILON := 0.0001

var id := ""
var region_a := ""
var region_b := ""
var endpoint_a := Transform3D.IDENTITY
var endpoint_b := Transform3D.IDENTITY
var aperture_width := 3.2
var clearance := 3.2
var enabled := true
var reverse_id := ""
var waypoints := {}
var _force_double_h := false


func _init(p_id: String, p_region_a: String, p_region_b: String,
		p_a: Transform3D, p_b: Transform3D, p_width: float,
		p_force_double_h := false) -> void:
	id = p_id
	region_a = p_region_a
	region_b = p_region_b
	endpoint_a = p_a
	endpoint_b = p_b
	aperture_width = p_width
	clearance = p_width
	_force_double_h = p_force_double_h


## Upright yaw-only rigid frames: unit scale, +Y up, right-handed.
static func frames_valid(a: Transform3D, b: Transform3D) -> bool:
	return _frame_ok(a) and _frame_ok(b)


static func _frame_ok(t: Transform3D) -> bool:
	var e := IDENTITY_EPSILON
	var x := t.basis.x
	var y := t.basis.y
	var z := t.basis.z
	if absf(x.length() - 1.0) > e or absf(y.length() - 1.0) > e \
			or absf(z.length() - 1.0) > e:
		return false
	if y.distance_to(Vector3.UP) > e:
		return false
	if absf(x.dot(y)) > e or absf(x.dot(z)) > e or absf(y.dot(z)) > e:
		return false
	return x.cross(y).distance_to(z) < e


## Source-space to destination-space mapping. The fault-injection flag
## applies H twice so the signed assertions below must fail.
func mapping() -> Transform3D:
	var turn := HALF_TURN * HALF_TURN if _force_double_h else HALF_TURN
	return endpoint_b * Transform3D(turn, Vector3.ZERO) \
		* endpoint_a.affine_inverse()


func inverse_mapping() -> Transform3D:
	return mapping().affine_inverse()


func map_point(p: Vector3) -> Vector3:
	return mapping() * p


func map_direction(d: Vector3) -> Vector3:
	return mapping().basis * d


## Runtime detector for the 6.3 identities: signed side, crossing direction,
## round trips, and the paired-geometry identity. A double-H mapping fails
## the signed assertions even though its round trip still cancels out.
func verify_mapping() -> bool:
	if not frames_valid(endpoint_a, endpoint_b):
		return false
	var m := mapping()
	var e := IDENTITY_EPSILON
	var just_before: Vector3 = m \
		* (endpoint_a * Vector3(0, 0, -SIDE_EPSILON))
	if just_before.distance_to(
			endpoint_b * Vector3(0, 0, SIDE_EPSILON)) > e:
		return false
	var emerges: Vector3 = m.basis * (endpoint_a.basis * Vector3(0, 0, -1))
	if emerges.distance_to(endpoint_b.basis * Vector3(0, 0, 1)) > e:
		return false
	var inv := m.affine_inverse()
	for p in [Vector3(1.25, 0.5, -2.75), Vector3(-3, 1.4, 0.5),
			Vector3.ZERO]:
		if (inv * (m * p)).distance_to(p) > e:
			return false
	for q in [Vector3(-0.75, 1.1, 0.4), Vector3(0.4, 0.0, -0.9)]:
		var via_m: Vector3 = m * (endpoint_a * q)
		var via_h: Vector3 = endpoint_b * (HALF_TURN * q)
		if via_m.distance_to(via_h) > e:
			return false
	return true


func other_region(region: String) -> String:
	if region == region_a:
		return region_b
	if region == region_b:
		return region_a
	return ""
