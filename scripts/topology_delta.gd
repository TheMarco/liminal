class_name TopologyDelta
extends RefCounted
## Typed description of one complete-reality transition.
##
## Structural fields are produced by DescentTopology. Selection metadata is
## filled by find_transition(), so the same object moves through validation,
## staging and commit without a loose Dictionary protocol.

var from_state := -1
var to_state := -1
var edges: Array[Dictionary] = []
var rooms: Array[Vector2i] = []
var cells: Array[Vector2i] = []

var distance_before := -1
var distance_after := -1
var saving := 0
var assistance := false
var nearest := 1 << 20
var score := -INF
## Live presentation rank supplied by the scene. Negative means that neither a
## changed doorway nor a changed set-piece room can currently be witnessed.
var witness_score := 0.0


func _init(p_from_state := -1, p_to_state := -1,
		p_edges: Array[Dictionary] = [], p_rooms: Array[Vector2i] = [],
		p_cells: Array[Vector2i] = []) -> void:
	from_state = p_from_state
	to_state = p_to_state
	edges = p_edges
	rooms = p_rooms
	cells = p_cells


func is_empty() -> bool:
	return from_state < 0 or to_state < 0 or cells.is_empty()


func copy() -> TopologyDelta:
	var duplicate_edges: Array[Dictionary] = []
	for edge in edges:
		duplicate_edges.append(edge.duplicate(true))
	var out := TopologyDelta.new(from_state, to_state, duplicate_edges,
		rooms.duplicate(), cells.duplicate())
	out.distance_before = distance_before
	out.distance_after = distance_after
	out.saving = saving
	out.assistance = assistance
	out.nearest = nearest
	out.score = score
	out.witness_score = witness_score
	return out
