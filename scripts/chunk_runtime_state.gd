class_name ChunkRuntimeState
extends RefCounted
## Allowlisted, serializable player-driven state for mutable chunk objects.
## Generated geometry and topology are deliberately absent: a seed plus the
## selected TopologyState reconstructs those. This object only carries state
## that reconstruction must not rewind, such as a swing door's open angle.

const SCHEMA_VERSION := 1

var _objects: Dictionary = {}


func put(key: String, kind: String, payload: Dictionary) -> bool:
	if key.is_empty() or kind.is_empty() or not key.begins_with("cell:"):
		return false
	_objects[key] = {
		"kind": kind,
		"payload": payload.duplicate(true),
	}
	return true


func has(key: String) -> bool:
	return _objects.has(key)


func kind_for(key: String) -> String:
	var record: Variant = _objects.get(key, {})
	return str((record as Dictionary).get("kind", "")) \
		if record is Dictionary else ""


func payload_for(key: String) -> Dictionary:
	var record: Variant = _objects.get(key, {})
	if not record is Dictionary:
		return {}
	var payload: Variant = (record as Dictionary).get("payload", {})
	return (payload as Dictionary).duplicate(true) \
		if payload is Dictionary else {}


func keys() -> Array[String]:
	var out: Array[String] = []
	for key in _objects:
		out.append(str(key))
	out.sort()
	return out


func size() -> int:
	return _objects.size()


func is_empty() -> bool:
	return _objects.is_empty()


func merge(other: ChunkRuntimeState, overwrite := true) -> void:
	if other == null:
		return
	for key in other.keys():
		if overwrite or not _objects.has(key):
			put(key, other.kind_for(key), other.payload_for(key))


func subset_for_cells(cells: Array[Vector2i]) -> ChunkRuntimeState:
	var out := ChunkRuntimeState.new()
	var prefixes: Array[String] = []
	for cell in cells:
		prefixes.append(cell_prefix(cell))
	for key in keys():
		for prefix in prefixes:
			if key.begins_with(prefix):
				out.put(key, kind_for(key), payload_for(key))
				break
	return out


func copy() -> ChunkRuntimeState:
	var out := ChunkRuntimeState.new()
	out.merge(self)
	return out


func to_dictionary() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"objects": _objects.duplicate(true),
	}


static func from_dictionary(value: Dictionary) -> ChunkRuntimeState:
	var out := ChunkRuntimeState.new()
	if int(value.get("schema", 0)) != SCHEMA_VERSION:
		return out
	var objects: Variant = value.get("objects", {})
	if not objects is Dictionary:
		return out
	for raw_key in objects:
		var key := str(raw_key)
		var record: Variant = objects[raw_key]
		if not record is Dictionary:
			continue
		var kind := str((record as Dictionary).get("kind", ""))
		var payload: Variant = (record as Dictionary).get("payload", {})
		if payload is Dictionary:
			out.put(key, kind, payload as Dictionary)
	return out


static func cell_prefix(cell: Vector2i) -> String:
	return "cell:%d:%d/" % [cell.x, cell.y]


static func object_key(cell: Vector2i, kind: String,
		local_id: String) -> String:
	return "%s%s:%s" % [cell_prefix(cell), kind, local_id]
