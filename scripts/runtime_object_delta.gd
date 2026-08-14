class_name RuntimeObjectDelta
extends RefCounted
## One stable runtime object's presence/state difference across a world
## mutation. Payloads are allowlisted by the owning object kind.

var key := ""
var kind := ""
var before_present := false
var after_present := false
var before_payload: Dictionary = {}
var after_payload: Dictionary = {}


func _init(p_key := "", p_kind := "", p_before_present := false,
		p_after_present := false, p_before_payload: Dictionary = {},
		p_after_payload: Dictionary = {}) -> void:
	key = p_key
	kind = p_kind
	before_present = p_before_present
	after_present = p_after_present
	before_payload = p_before_payload.duplicate(true)
	after_payload = p_after_payload.duplicate(true)


func changed() -> bool:
	return before_present != after_present \
		or before_payload != after_payload


func copy() -> RuntimeObjectDelta:
	return RuntimeObjectDelta.new(key, kind, before_present, after_present,
		before_payload, after_payload)
