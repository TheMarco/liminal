class_name WorldMutation
extends RefCounted
## Complete typed mutation proposal: generated topology/furniture reality plus
## stable runtime-object presence and player-driven state.

var id := ""
var topology: TopologyDelta
var affected_cells: Array[Vector2i] = []
var before_runtime := ChunkRuntimeState.new()
var after_runtime := ChunkRuntimeState.new()
var before_present: Dictionary = {}
var after_present: Dictionary = {}
var object_deltas: Array[RuntimeObjectDelta] = []


func _init(p_topology: TopologyDelta = null,
		p_cells: Array[Vector2i] = [],
		p_before_runtime: ChunkRuntimeState = null,
		p_before_present: Dictionary = {}) -> void:
	topology = p_topology
	affected_cells = p_cells.duplicate()
	affected_cells.sort_custom(func(a: Vector2i, b: Vector2i):
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	if p_before_runtime != null:
		before_runtime = p_before_runtime.copy()
	before_present = p_before_present.duplicate(true)
	id = _stable_id()


func is_empty() -> bool:
	return topology == null or topology.is_empty() or affected_cells.is_empty()


func reconcile_after(runtime: ChunkRuntimeState,
		present: Dictionary) -> void:
	after_runtime = runtime.copy() if runtime != null else ChunkRuntimeState.new()
	after_present = present.duplicate(true)
	object_deltas.clear()
	var all_keys := {}
	for key in before_present:
		all_keys[str(key)] = true
	for key in after_present:
		all_keys[str(key)] = true
	for key in before_runtime.keys():
		all_keys[key] = true
	for key in after_runtime.keys():
		all_keys[key] = true
	var sorted: Array[String] = []
	for key in all_keys:
		sorted.append(str(key))
	sorted.sort()
	for key in sorted:
		var kind := str(after_present.get(key,
			before_present.get(key, after_runtime.kind_for(key))))
		if kind.is_empty():
			kind = before_runtime.kind_for(key)
		var delta := RuntimeObjectDelta.new(key, kind,
			before_present.has(key), after_present.has(key),
			before_runtime.payload_for(key), after_runtime.payload_for(key))
		if delta.changed():
			object_deltas.append(delta)


func copy() -> WorldMutation:
	var out := WorldMutation.new(topology.copy() if topology != null else null,
		affected_cells, before_runtime, before_present)
	out.id = id
	out.after_runtime = after_runtime.copy()
	out.after_present = after_present.duplicate(true)
	for delta in object_deltas:
		out.object_deltas.append(delta.copy())
	return out


func _stable_id() -> String:
	if topology == null:
		return "world:none"
	var cell_ids: PackedStringArray = []
	for cell in affected_cells:
		cell_ids.append("%d,%d" % [cell.x, cell.y])
	return "world:v1:%d>%d:%s" % [topology.from_state,
		topology.to_state, ";".join(cell_ids)]
