class_name TopologyState
extends RefCounted
## One complete generated reality. Edges and rooms remain keyed collections,
## but their ownership and required top-level fields are typed and centralized.

var id := 0
var state_name := "base"
var edges: Dictionary = {}
var rooms: Dictionary = {}


func _init(p_id := 0, p_name := "base", p_edges: Dictionary = {},
		p_rooms: Dictionary = {}) -> void:
	id = p_id
	state_name = p_name
	edges = p_edges.duplicate(true)
	rooms = p_rooms.duplicate(true)


func copy() -> TopologyState:
	return TopologyState.new(id, state_name, edges, rooms)


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": state_name,
		"edges": edges.duplicate(true),
		"rooms": rooms.duplicate(true),
	}


static func from_dictionary(value: Dictionary) -> TopologyState:
	return TopologyState.new(int(value.get("id", 0)),
		str(value.get("name", "base")),
		value.get("edges", {}) as Dictionary,
		value.get("rooms", {}) as Dictionary)
