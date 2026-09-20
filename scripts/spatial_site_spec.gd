class_name SpatialSiteSpec
extends RefCounted
## Immutable planned facts for one spatial mutation site. Produced pure by the
## site planner ( Package 2 fixture or bounded Office placement); consumed by
## scene construction, the transaction, and persistence. Never keyed by scene
## instance ids or stream order.

enum Kind {
	MIGRATING_DOOR,
	RETURN_LOOP,
	GROWING_CORRIDOR,
}

const SCHEMA_VERSION := 1
const MAX_COLLECTION_SIZE := 128
const MAX_COORDINATE := 1000000
const MAX_ID_LENGTH := 192
const _ID_CHARS := \
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-/.:"

var id := ""
var schema_version := SCHEMA_VERSION
var generation_version := 0
var theme := -1
var kind := Kind.MIGRATING_DOOR
## Cells owned by the site (navigation + geometry reserved, streaming leased).
var cells: Array[Vector2i] = []
var anchor_ids: Array[String] = []
## Named endpoint transforms in floor space (e.g. "door_a", "door_b").
var endpoints := {}
var allowed_phases: Array[String] = []
## Swept volumes in floor space that must stay clear during motion.
var swept_bounds: Array[AABB] = []
## Witness features: stable id -> {"position": Vector3, "extents": Vector2}.
var witness_points := {}
## Protected routes that must stay connected through every intermediate phase.
var protected_routes: Array[String] = []
var signature := ""


static func make_door(p_id: String, p_theme: int, p_generation: int,
		p_cells: Array[Vector2i], p_anchors: Array[String],
		p_endpoints: Dictionary, p_phases: Array[String],
		p_swept: Array[AABB], p_witness: Dictionary,
		p_routes: Array[String]) -> SpatialSiteSpec:
	var spec := SpatialSiteSpec.new()
	spec.id = p_id
	spec.theme = p_theme
	spec.generation_version = p_generation
	spec.kind = Kind.MIGRATING_DOOR
	spec.cells = p_cells.duplicate()
	spec.anchor_ids = p_anchors.duplicate()
	spec.endpoints = p_endpoints.duplicate(true)
	spec.allowed_phases = p_phases.duplicate()
	spec.swept_bounds = p_swept.duplicate()
	spec.witness_points = p_witness.duplicate(true)
	spec.protected_routes = p_routes.duplicate()
	spec.signature = spec.compute_signature()
	return spec


func compute_signature() -> String:
	# Length-prefixed canonical fields avoid delimiter ambiguity. Dictionary
	# keys and set-like arrays are sorted, while every numeric component uses
	# its serialized float bytes so rotation/bounds changes cannot alias.
	var parts: Array[String] = [
		_field("schema", str(schema_version)),
		_field("generation", str(generation_version)),
		_field("kind", str(int(kind))),
		_field("theme", str(theme)),
		_field("id", id),
	]
	var cell_parts: Array[String] = []
	for at in cells:
		cell_parts.append("%d,%d" % [at.x, at.y])
	cell_parts.sort()
	# Owned cells are a set, but cells[0] is also the semantic junction used by
	# builders. Hash both facts so reordering ordinary members is harmless while
	# changing which cell is the junction invalidates an old saved state.
	var junction := "%d,%d" % [cells[0].x, cells[0].y] \
		if not cells.is_empty() else ""
	parts.append(_field("junction", junction))
	parts.append(_field("cells", _sequence(cell_parts)))
	var anchors := anchor_ids.duplicate()
	anchors.sort()
	parts.append(_field("anchors", _sequence(anchors)))
	var end_parts: Array[String] = []
	for key in endpoints.keys():
		var t: Transform3D = endpoints[key]
		end_parts.append(_field(str(key), _transform_token(t)))
	end_parts.sort()
	parts.append(_field("endpoints", _sequence(end_parts)))
	var phases := allowed_phases.duplicate()
	phases.sort()
	parts.append(_field("phases", _sequence(phases)))
	var swept_parts: Array[String] = []
	for bounds in swept_bounds:
		swept_parts.append(_vector3_token(bounds.position)
			+ _vector3_token(bounds.size))
	swept_parts.sort()
	parts.append(_field("swept", _sequence(swept_parts)))
	var witness_parts: Array[String] = []
	for raw_key in witness_points.keys():
		var key := str(raw_key)
		var point: Dictionary = witness_points[raw_key]
		witness_parts.append(_field(key,
			_vector3_token(point["position"])
			+ _vector2_token(point["extents"])))
	witness_parts.sort()
	parts.append(_field("witness", _sequence(witness_parts)))
	var routes := protected_routes.duplicate()
	routes.sort()
	parts.append(_field("routes", _sequence(routes)))
	return "spatial-spec-v%d:%s" % [SCHEMA_VERSION,
		_sequence(parts).sha256_text()]


## Structural validity only; placement/overlap rules live in the planner.
func is_valid() -> bool:
	if not _valid_id(id) or schema_version != SCHEMA_VERSION:
		return false
	if generation_version < 0 or generation_version > 1000000000 \
			or theme < 0 or theme > 1024 \
			or int(kind) < int(Kind.MIGRATING_DOOR) \
			or int(kind) > int(Kind.GROWING_CORRIDOR):
		return false
	if cells.is_empty() or cells.size() > MAX_COLLECTION_SIZE \
			or allowed_phases.is_empty() \
			or allowed_phases.size() > MAX_COLLECTION_SIZE:
		return false
	var unique_cells := {}
	for at in cells:
		if absi(at.x) > MAX_COORDINATE or absi(at.y) > MAX_COORDINATE \
				or unique_cells.has(at):
			return false
		unique_cells[at] = true
	if not _valid_id_array(anchor_ids) or not _valid_id_array(allowed_phases) \
			or not _valid_id_array(protected_routes):
		return false
	if endpoints.is_empty() or endpoints.size() > MAX_COLLECTION_SIZE:
		return false
	for raw_key in endpoints.keys():
		if not raw_key is String or not _valid_id(raw_key) \
				or not endpoints[raw_key] is Transform3D \
				or not _valid_transform(endpoints[raw_key]):
			return false
	if swept_bounds.is_empty() \
			or swept_bounds.size() > MAX_COLLECTION_SIZE:
		return false
	for bounds in swept_bounds:
		if not _valid_vector3(bounds.position) \
				or not _valid_vector3(bounds.size) \
				or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
				or bounds.size.z <= 0.0:
			return false
	if witness_points.is_empty() \
			or witness_points.size() > MAX_COLLECTION_SIZE:
		return false
	for raw_key in witness_points.keys():
		if not raw_key is String or not _valid_id(raw_key):
			return false
		var raw_point: Variant = witness_points[raw_key]
		if not raw_point is Dictionary:
			return false
		var point := raw_point as Dictionary
		if not point.get("position") is Vector3 \
				or not point.get("extents") is Vector2:
			return false
		var extents: Vector2 = point["extents"]
		if not _valid_vector3(point["position"]) \
				or not _valid_vector2(extents) \
				or extents.x <= 0.0 or extents.y <= 0.0:
			return false
	if kind == Kind.MIGRATING_DOOR:
		if not endpoints.has("a") or not endpoints.has("b"):
			return false
		var phases := allowed_phases.duplicate()
		phases.sort()
		if phases != ["a_open", "b_open", "both_open"]:
			return false
	if signature != compute_signature():
		return false
	return true


static func _valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var text := value as String
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for i in text.length():
		if _ID_CHARS.find(text.substr(i, 1)) < 0:
			return false
	return true


static func _valid_id_array(values: Array) -> bool:
	if values.size() > MAX_COLLECTION_SIZE:
		return false
	var unique := {}
	for value in values:
		if not _valid_id(value) or unique.has(value):
			return false
		unique[value] = true
	return true


static func _valid_transform(value: Transform3D) -> bool:
	return _valid_vector3(value.basis.x) \
		and _valid_vector3(value.basis.y) \
		and _valid_vector3(value.basis.z) \
		and _valid_vector3(value.origin) \
		and absf(value.basis.determinant()) > 0.000001


static func _valid_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _valid_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _field(name: String, value: String) -> String:
	return "%d:%s%d:%s" % [name.length(), name, value.length(), value]


static func _sequence(values: Array[String]) -> String:
	var out := ""
	for value in values:
		out += "%d:%s" % [value.length(), value]
	return out


static func _float_token(value: float) -> String:
	return var_to_bytes(value).hex_encode()


static func _vector2_token(value: Vector2) -> String:
	return _float_token(value.x) + _float_token(value.y)


static func _vector3_token(value: Vector3) -> String:
	return _float_token(value.x) + _float_token(value.y) \
		+ _float_token(value.z)


static func _transform_token(value: Transform3D) -> String:
	return _vector3_token(value.basis.x) \
		+ _vector3_token(value.basis.y) \
		+ _vector3_token(value.basis.z) \
		+ _vector3_token(value.origin)
