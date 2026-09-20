class_name MigratingDoorSite
extends Node3D
## One migrating-doorway junction module. Owns its moving leaves, fixed
## header/jambs, and collision. Leaves translate parallel to the wall into
## reserved pockets; wallpaper UVs stay room-anchored so the wall appears to
## overwrite the aperture rather than slide a panel.
##
## Motion runs only through advance_physics() in physics time. Closure is
## guarded every tick by swept actor capsules against leaf sweeps and both
## approaches; malformed occupancy input fails safe (closure blocked).

class PreparationResult extends RefCounted:
	var ok := false
	var reason := ""


class Clearance extends RefCounted:
	var openness := {}
	var clear_width := {}
	var traversable := {}


class PhaseResult extends RefCounted:
	var passability_changed := false
	var traversable := {}
	var close_blocked := false
	var tokens: Array = []
	var targets_reached := false

## Tuning: aperture geometry in metres (spec 4.2).
const APERTURE_WIDTH := 3.2
const APERTURE_HEIGHT := 2.7
const LEAF_THICKNESS := 0.2
## Pocket length along the wall per side, from the aperture edge outward.
## Covers leaf travel (half the aperture width) plus construction margin.
const POCKET_DEPTH := 1.7
const LEAF_OVERLAP := 0.05
const OPEN_SECONDS := 1.2
const CLOSE_SECONDS := 1.6
## Traversal envelope derived from actual colliders: player/enemy diameter
## (EnemyTraversal uses Player.BODY_RADIUS) plus a tested margin.
const CLEAR_MARGIN := 0.3
const MAX_ACTOR_SPEED := 6.5
const APPROACH_MARGIN := 0.4
const TOKEN_DEPTH := 1.5
const GUARD_MARGIN := 0.05
const TELEPORT_STEP_MULT := 3.0

const PHASE_A := "a_open"
const PHASE_BOTH := "both_open"
const PHASE_B := "b_open"

var _spec: SpatialSiteSpec
var _ready := false
var _leaves := {}
var _closed_x := {}
## Authoritative openness per aperture. Node transforms are write-only
## mirrors: with sync_to_physics, idle-time assignments apply on the next
## physics frame, so the site never reads leaf motion back from the tree.
var _openness := {"a": 0.0, "b": 0.0}
var _stagger := {"l": -0.01, "r": 0.01}
var _travel := APERTURE_WIDTH * 0.5
var _targets := {"a": 1.0, "b": 0.0}
var _traversable := {"a": true, "b": false}
var _tokens: Array = []
var _tile_m := 0.8
var _passage := {}
var _approach := {}


static func clear_width_threshold() -> float:
	return Player.BODY_RADIUS * 2.0 + CLEAR_MARGIN


func prepare(spec: SpatialSiteSpec, state: SpatialSiteState,
		params: Dictionary) -> PreparationResult:
	var result := PreparationResult.new()
	if not is_inside_tree():
		result.reason = "site must be inside the tree to prepare"
		return result
	if _ready:
		result.reason = "site already prepared"
		return result
	if spec == null or not spec.is_valid():
		result.reason = "invalid spec"
		return result
	if state != null and not state.matches(spec):
		result.reason = "state does not match spec signature"
		return result
	if not spec.endpoints.has("a") or not spec.endpoints.has("b"):
		result.reason = "spec lacks a/b endpoints"
		return result
	var wall_material: Material = params.get("wall_material")
	var trim_material: Material = params.get("trim_material", wall_material)
	if wall_material == null:
		result.reason = "missing wall_material"
		return result
	_tile_m = float(params.get("pattern_tile_m", 0.8))
	if _tile_m <= 0.0:
		result.reason = "bad pattern_tile_m"
		return result
	_spec = spec
	for aperture in ["a", "b"]:
		var root := Node3D.new()
		root.name = "aperture_" + aperture
		root.transform = spec.endpoints[aperture]
		add_child(root)
		_build_aperture(root, aperture, wall_material, trim_material,
			float(params.get("ceiling_h", 3.0)))
		var openness := 1.0 if aperture == "a" else 0.0
		if state != null and state.door_openness.has(aperture):
			openness = clampf(float(state.door_openness[aperture]), 0.0, 1.0)
		_set_openness(aperture, openness)
		_targets[aperture] = openness
		_update_traversable(aperture)
	_compute_volumes()
	if not _swept_within_spec():
		_teardown()
		result.reason = "swept volumes exceed spec bounds"
		return result
	_ready = true
	result.ok = true
	return result


func is_prepared() -> bool:
	return _ready


func spec() -> SpatialSiteSpec:
	return _spec


func set_targets(a_open: float, b_open: float) -> void:
	_targets["a"] = clampf(a_open, 0.0, 1.0)
	_targets["b"] = clampf(b_open, 0.0, 1.0)


func current_clearance() -> Clearance:
	var out := Clearance.new()
	for aperture in ["a", "b"]:
		var openness := _openness_of(aperture)
		out.openness[aperture] = openness
		out.clear_width[aperture] = openness * APERTURE_WIDTH
		out.traversable[aperture] = _is_traversable(aperture)
	return out


func leading_edge_position(aperture: String) -> Vector3:
	var root: Node3D = _leaves.get(aperture + "_root")
	if root == null:
		return global_position
	var openness := _openness_of(aperture)
	var edge_x := openness * _travel - LEAF_OVERLAP * 0.5
	return root.global_transform * Vector3(edge_x, 1.4, 0.0)


func passage_box(aperture: String) -> AABB:
	return _passage.get(aperture, AABB())


func approach_boxes(aperture: String) -> Array:
	return (_approach.get(aperture, []) as Array).duplicate()


## Advance leaf motion one physics tick. Occupancy entries are Dictionaries
## with fixed keys: id (String), prev/curr (Vector3), radius (float).
## Prev/curr are actor ground (feet) positions; guard volumes span the full
## aperture height, which is exact for grounded actors (Package 2 scope).
func advance_physics(dt: float, occupancy: Array) -> PhaseResult:
	var out := PhaseResult.new()
	if not _ready:
		return out
	var actors := _validated_occupancy(occupancy, out)
	for aperture in ["a", "b"]:
		_release_cleared_tokens(aperture, actors)
		var current := _openness_of(aperture)
		var target: float = _targets[aperture]
		if _token_held(aperture):
			# A held token prevents closure exactly like a fresh guard
			# trip, including feeding the transaction's hold timer.
			target = 1.0
			out.close_blocked = true
		if target < current:
			# An actor already committed to the passage holds a token
			# until clear of both approaches, longer than the raw guard
			# volumes alone would block.
			_grant_passage_tokens(aperture, actors, out)
			if _closure_blocked(aperture, current, target, dt, actors, out):
				target = 1.0
				out.close_blocked = true
		var speed := 1.0 / CLOSE_SECONDS if target < current \
			else 1.0 / OPEN_SECONDS
		_set_openness(aperture, move_toward(current, target, speed * dt))
		if _update_traversable(aperture):
			out.passability_changed = true
		out.traversable[aperture] = _traversable[aperture]
		_update_leaf_uv(aperture)
	out.tokens = _tokens.duplicate(true)
	out.targets_reached = is_equal_approx(_openness_of("a"),
		_targets["a"]) and is_equal_approx(_openness_of("b"),
			_targets["b"])
	return out


func _build_aperture(root: Node3D, aperture: String, wall_material: Material,
		trim_material: Material, ceiling_h: float) -> void:
	_leaves[aperture + "_root"] = root
	var half := APERTURE_WIDTH * 0.5
	var leaf_w := half + LEAF_OVERLAP
	for side in [-1.0, 1.0]:
		var body := AnimatableBody3D.new()
		body.name = "leaf_%s" % ("l" if side < 0.0 else "r")
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = anchored_box_mesh(
			Vector3(leaf_w, APERTURE_HEIGHT, LEAF_THICKNESS), _tile_m)
		mesh_instance.material_override = _leaf_material(wall_material)
		mesh_instance.position = Vector3(0.0, APERTURE_HEIGHT * 0.5, 0.0)
		body.add_child(mesh_instance)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(leaf_w, APERTURE_HEIGHT, LEAF_THICKNESS)
		shape.shape = box_shape
		shape.position = Vector3(0.0, APERTURE_HEIGHT * 0.5, 0.0)
		body.add_child(shape)
		root.add_child(body)
		# Closed leaves overlap at the centre; stagger them in depth so
		# the overlap never z-fights. Clears jambs/skins either side.
		var stagger := -0.01 if side < 0.0 else 0.01
		_stagger[("l" if side < 0.0 else "r")] = stagger
		body.position = Vector3(side * APERTURE_WIDTH * 0.25, 0.0,
			stagger)
		var key := "%s_%s" % [aperture, ("l" if side < 0.0 else "r")]
		_leaves[key] = body
		_closed_x[key] = side * APERTURE_WIDTH * 0.25
	var header := _static_box(Vector3(APERTURE_WIDTH + 0.4,
		maxf(0.1, ceiling_h - APERTURE_HEIGHT), LEAF_THICKNESS + 0.1),
		trim_material)
	header.position = Vector3(0.0,
		APERTURE_HEIGHT + maxf(0.1, ceiling_h - APERTURE_HEIGHT) * 0.5, 0.0)
	header.name = "header"
	root.add_child(header)
	# Jamb reveals sit in front of and behind the leaf plane, covering the
	# pocket mouth without entering leaf travel (z within +/-0.1).
	for side in [-1.0, 1.0]:
		for zside in [-1.0, 1.0]:
			var jamb := _static_box(Vector3(0.15, APERTURE_HEIGHT,
				0.08), trim_material)
			jamb.position = Vector3(side * (half + 0.025),
				APERTURE_HEIGHT * 0.5, zside * 0.16)
			jamb.name = "jamb_%s_%s" % [
				"l" if side < 0.0 else "r",
				"f" if zside > 0.0 else "b"]
			root.add_child(jamb)


func _static_box(size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = anchored_box_mesh(size, _tile_m)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body


## Per-leaf material copy: uv1_offset scrolls the wallpaper against leaf
## motion so the pattern stays fixed in room space. Mesh UVs are already in
## tile units (see anchored_box_mesh), so the shared material keeps unit
## scale and a repeating texture.
func _leaf_material(wall_material: Material) -> Material:
	return wall_material.duplicate() as Material


## Box mesh with UVs in pattern-tile units instead of 0..1, identical u(x)
## orientation on both z faces (BoxMesh mirrors one face, which no single
## scroll offset can anchor). The scroll keeps each leaf's own pattern fixed
## in room space; leaf/wall phase seams hide behind jambs and depth steps,
## like wallpaper seams at a real door frame.
static func anchored_box_mesh(size: Vector3, tile_m: float) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var quads := [
		[Vector3(0, 0, 1), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz),
			Vector3(-hx, hy, hz), Vector3(hx, hy, hz), 0],
		[Vector3(0, 0, -1), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz),
			Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), 0],
		[Vector3(1, 0, 0), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz),
			Vector3(hx, hy, hz), Vector3(hx, hy, -hz), 2],
		[Vector3(-1, 0, 0), Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz),
			Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), 2],
		[Vector3(0, 1, 0), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz),
			Vector3(hx, hy, hz), Vector3(-hx, hy, hz), 0],
		[Vector3(0, -1, 0), Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz),
			Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), 0],
	]
	for quad in quads:
		var normal: Vector3 = quad[0]
		var axis: int = quad[5]
		var corners: Array = quad.slice(1, 5)
		for index in [0, 1, 2, 0, 2, 3]:
			var corner: Vector3 = corners[index]
			verts.append(corner)
			normals.append(normal)
			var u := corner.x if axis == 0 else corner.z
			uvs.append(Vector2(u / tile_m, corner.y / tile_m))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _update_leaf_uv(aperture: String) -> void:
	for side in ["l", "r"]:
		var key := "%s_%s" % [aperture, side]
		var body: AnimatableBody3D = _leaves[key]
		var mesh_instance := body.get_child(0) as MeshInstance3D
		var material := mesh_instance.material_override
		if not material is StandardMaterial3D:
			continue
		var travelled := _openness_of(aperture) * _travel
		var dx := -travelled if side == "l" else travelled
		(material as StandardMaterial3D).uv1_offset = Vector3(
			dx / _tile_m, 0.0, 0.0)


func _openness_of(aperture: String) -> float:
	return clampf(float(_openness.get(aperture, 0.0)), 0.0, 1.0)


func _set_openness(aperture: String, openness: float) -> void:
	var clamped := clampf(openness, 0.0, 1.0)
	_openness[aperture] = clamped
	var offset := clamped * _travel
	var left: AnimatableBody3D = _leaves[aperture + "_l"]
	var right: AnimatableBody3D = _leaves[aperture + "_r"]
	left.position = Vector3(float(_closed_x[aperture + "_l"]) - offset,
		0.0, float(_stagger["l"]))
	right.position = Vector3(float(_closed_x[aperture + "_r"]) + offset,
		0.0, float(_stagger["r"]))


func _is_traversable(aperture: String) -> bool:
	return _openness_of(aperture) * APERTURE_WIDTH \
		>= clear_width_threshold()


func _update_traversable(aperture: String) -> bool:
	var now := _is_traversable(aperture)
	if now == bool(_traversable[aperture]):
		return false
	_traversable[aperture] = now
	return true


func _compute_volumes() -> void:
	for aperture in ["a", "b"]:
		var root: Node3D = _leaves[aperture + "_root"]
		var xf: Transform3D = root.global_transform
		var half := APERTURE_WIDTH * 0.5
		var corners := [
			xf * Vector3(-half, 0.0, 0.0),
			xf * Vector3(half, 0.0, 0.0),
			xf * Vector3(-half, APERTURE_HEIGHT, 0.0),
			xf * Vector3(half, APERTURE_HEIGHT, 0.0),
		]
		var passage := AABB(corners[0], Vector3.ZERO)
		for corner in corners:
			passage = passage.expand(corner)
		_passage[aperture] = passage
		# Token-release volumes: fixed generous depth. Conservative release
		# only delays closure, which is the safe direction.
		var normal := (xf.basis * Vector3(0.0, 0.0, 1.0)).normalized()
		var sides := []
		for sign in [1.0, -1.0]:
			var corner_a: Vector3 = xf * Vector3(-half, 0.0, 0.0)
			var corner_b: Vector3 = xf * Vector3(half, 0.0, 0.0) \
				+ normal * sign * TOKEN_DEPTH
			var corner_c: Vector3 = xf * Vector3(-half, 0.0, 0.0) \
				+ normal * sign * TOKEN_DEPTH
			var corner_d: Vector3 = xf * Vector3(half, 0.0, 0.0)
			var low := corner_a.min(corner_b).min(corner_c).min(corner_d)
			low.y = minf(low.y, xf.origin.y)
			var high := corner_a.max(corner_b).max(corner_c).max(corner_d)
			high.y = maxf(high.y, xf.origin.y + APERTURE_HEIGHT)
			sides.append(AABB(low, high - low))
		_approach[aperture] = sides


func _swept_within_spec() -> bool:
	if _spec.swept_bounds.is_empty():
		return true
	for aperture in ["a", "b"]:
		var root: Node3D = _leaves[aperture + "_root"]
		var xf: Transform3D = root.global_transform
		var reach := APERTURE_WIDTH * 0.5 + _travel + LEAF_OVERLAP
		var local := AABB(Vector3(-reach, 0.0, -LEAF_THICKNESS),
			Vector3(reach * 2.0, APERTURE_HEIGHT, LEAF_THICKNESS * 2.0))
		var swept := AABB(xf * local.position, Vector3.ZERO)
		for i in 8:
			var corner := local.position + local.size * Vector3(
				float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
			swept = swept.expand(xf * corner)
		var contained := false
		for bound in _spec.swept_bounds:
			if (bound as AABB).encloses(swept):
				contained = true
				break
		if not contained:
			return false
	return true


func _validated_occupancy(occupancy: Array, out: PhaseResult) -> Array:
	var actors := []
	for entry in occupancy:
		if not entry is Dictionary:
			out.close_blocked = true
			push_error("MigratingDoorSite: malformed occupancy entry")
			continue
		var actor := entry as Dictionary
		if not actor.get("id") is String \
				or not actor.get("prev") is Vector3 \
				or not actor.get("curr") is Vector3 \
				or not actor.get("radius") is float:
			out.close_blocked = true
			push_error("MigratingDoorSite: malformed occupancy entry")
			continue
		actors.append(actor)
	return actors


func _closure_blocked(aperture: String, current: float, target: float,
		dt: float, actors: Array, out: PhaseResult) -> bool:
	var volumes := _guard_volumes(aperture, current, target, dt)
	for actor in actors:
		var prev: Vector3 = actor["prev"]
		var curr: Vector3 = actor["curr"]
		var radius := float(actor["radius"])
		if prev.distance_to(curr) > MAX_ACTOR_SPEED * dt * TELEPORT_STEP_MULT \
				+ radius:
			prev = curr
		for volume in volumes:
			if (volume as AABB).grow(radius).intersects_segment(prev, curr):
				return true
	return out.close_blocked


func _guard_volumes(aperture: String, current: float, target: float,
		dt: float) -> Array:
	var volumes := []
	var root: Node3D = _leaves[aperture + "_root"]
	var xf: Transform3D = root.global_transform
	var extents := Vector3(APERTURE_WIDTH * 0.5 + LEAF_OVERLAP,
		APERTURE_HEIGHT, LEAF_THICKNESS) * 0.5
	for side in ["l", "r"]:
		var key := "%s_%s" % [aperture, side]
		var sign := -1.0 if side == "l" else 1.0
		var swept := _world_box(xf, Vector3(
			float(_closed_x[key]) + sign * current * _travel,
			APERTURE_HEIGHT * 0.5, float(_stagger[side])), extents)
		swept = swept.merge(_world_box(xf, Vector3(
			float(_closed_x[key]) + sign * target * _travel,
			APERTURE_HEIGHT * 0.5, float(_stagger[side])), extents))
		volumes.append(swept.grow(GUARD_MARGIN))
	volumes.append((_passage[aperture] as AABB).grow(GUARD_MARGIN))
	var depth := MAX_ACTOR_SPEED * dt + Player.BODY_RADIUS + APPROACH_MARGIN
	volumes.append(_scaled_approach(aperture, depth))
	return volumes


func _scaled_approach(aperture: String, depth: float) -> AABB:
	var root: Node3D = _leaves[aperture + "_root"]
	var xf: Transform3D = root.global_transform
	var half := APERTURE_WIDTH * 0.5
	var box := AABB(xf * Vector3(-half, 0.0, -depth), Vector3.ZERO)
	box = box.expand(xf * Vector3(half, 0.0, -depth))
	box = box.expand(xf * Vector3(-half, APERTURE_HEIGHT, depth))
	box = box.expand(xf * Vector3(half, APERTURE_HEIGHT, depth))
	var tangent := (xf.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	box = box.expand(box.position + tangent * depth)
	box = box.expand(box.position + box.size - tangent * depth)
	return box.grow(GUARD_MARGIN)


## Axis-aligned world box for a local center/extents pair. Corner
## expansion keeps yawed endpoints exact.
static func _world_box(xf: Transform3D, center: Vector3,
		extents: Vector3) -> AABB:
	var box := AABB(xf * (center - extents), Vector3.ZERO)
	for i in 8:
		var corner := center + Vector3(
			extents.x if i & 1 else -extents.x,
			extents.y if i & 2 else -extents.y,
			extents.z if i & 4 else -extents.z)
		box = box.expand(xf * corner)
	return box


func _grant_passage_tokens(aperture: String, actors: Array,
		out: PhaseResult) -> void:
	var passage: AABB = _passage[aperture]
	for actor in actors:
		var curr: Vector3 = actor["curr"]
		var radius := float(actor["radius"])
		if passage.grow(radius).has_point(curr) \
				and not _token_held_for(aperture, str(actor["id"])):
			_tokens.append({"actor": str(actor["id"]),
				"aperture": aperture})
			out.close_blocked = true


func _release_cleared_tokens(aperture: String, actors: Array) -> void:
	var kept := []
	for token in _tokens:
		if str(token["aperture"]) != aperture:
			kept.append(token)
			continue
		var actor := _actor_by_id(actors, str(token["actor"]))
		if actor.is_empty():
			continue
		var curr: Vector3 = actor["curr"]
		var radius := float(actor["radius"])
		var clear := true
		var volumes := [passage_box(aperture)] + approach_boxes(aperture)
		for volume in volumes:
			if (volume as AABB).grow(radius).has_point(curr):
				clear = false
				break
		if not clear:
			kept.append(token)
	_tokens = kept


func _token_held(aperture: String) -> bool:
	for token in _tokens:
		if str(token["aperture"]) == aperture:
			return true
	return false


func _token_held_for(aperture: String, actor_id: String) -> bool:
	for token in _tokens:
		if str(token["aperture"]) == aperture \
				and str(token["actor"]) == actor_id:
			return true
	return false


func _actor_by_id(actors: Array, actor_id: String) -> Dictionary:
	for actor in actors:
		if str(actor["id"]) == actor_id:
			return actor
	return {}


func _teardown() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_leaves.clear()
	_closed_x.clear()
	_passage.clear()
	_approach.clear()
	_tokens.clear()
	_targets = {"a": 1.0, "b": 0.0}
	_ready = false
