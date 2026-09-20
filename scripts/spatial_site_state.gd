class_name SpatialSiteState
extends RefCounted
## Mutable live state for one site, keyed by spec id/signature. Only the
## allowlisted fields below may reach disk (see DescentProgress spatial_sites).

var spec_id := ""
var spec_signature := ""
## Copied from the immutable spec. -1 is accepted only for legacy records
## written before generation was stored separately; the signature still gates
## those records against the current spec.
var generation_version := -1
var stable_phase := ""
## Bounded 0..1 animation progress while a transition runs; -1 when idle.
var progress := -1.0
var activated := false
var completed := false
## Return-loop onward exit state (Packages 4+; empty until used).
var loop_exit := ""
## Last time the changed feature was seen after visibility returned (-1 never).
var last_seen_after := -1.0
## Growing-corridor latched length in metres (-1 when not a corridor).
var corridor_length := -1.0
## Migrating-door aperture openness 0..1 by aperture name ("a", "b").
var door_openness := {}

const MAX_ID_LENGTH := 192
const MAX_SIGNATURE_LENGTH := 8192
const MAX_CORRIDOR_LENGTH := 100000.0
const MAX_TIMESTAMP := 1.0e12
const DOOR_PHASES := ["a_open", "both_open", "b_open"]
const LOOP_EXITS := ["", "entrance", "onward"]
const _ID_CHARS := \
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-/.:"


static func for_spec(spec: SpatialSiteSpec,
		initial_phase: String) -> SpatialSiteState:
	var state := SpatialSiteState.new()
	state.spec_id = spec.id
	state.spec_signature = spec.signature
	state.generation_version = spec.generation_version
	state.stable_phase = initial_phase
	return state


func matches(spec: SpatialSiteSpec) -> bool:
	return spec != null and spec.id == spec_id \
		and spec.signature == spec_signature \
		and (generation_version < 0 \
			or spec.generation_version == generation_version)


## Allowlisted disk form. Enums as strings, finite numeric ranges only.
func to_disk() -> Dictionary:
	# A save can be requested while the live leaves are in motion. Continue is
	# arrival-based, so persist the proven both-open reconstruction without
	# changing the exact in-memory phase, openness or progress used by physics.
	var active := is_finite(progress) and progress >= 0.0
	var disk_phase := "both_open" if active else stable_phase
	var disk_a := 1.0 if active else float(door_openness.get("a", -1.0))
	var disk_b := 1.0 if active else float(door_openness.get("b", -1.0))
	return {
		"spec_id": spec_id,
		"signature": spec_signature,
		"generation": generation_version,
		"phase": disk_phase,
		"activated": true if active else activated,
		"completed": false if active else completed,
		"loop_exit": loop_exit,
		"last_seen_after": last_seen_after,
		"corridor_length": corridor_length,
		"door_a": disk_a,
		"door_b": disk_b,
	}


static func from_disk(data: Variant) -> SpatialSiteState:
	if not data is Dictionary:
		return null
	var values := data as Dictionary
	if not _valid_id(values.get("spec_id")):
		return null
	if not _valid_signature(values.get("signature")):
		return null
	var raw_phase: Variant = values.get("phase")
	if not raw_phase is String or not DOOR_PHASES.has(raw_phase):
		return null
	var raw_generation: Variant = values.get("generation", -1)
	if typeof(raw_generation) != TYPE_INT or int(raw_generation) < -1 \
			or int(raw_generation) > 1000000000:
		return null
	var raw_activated: Variant = values.get("activated", false)
	var raw_completed: Variant = values.get("completed", false)
	if not raw_activated is bool or not raw_completed is bool:
		return null
	if raw_completed and not raw_activated:
		return null
	var raw_loop_exit: Variant = values.get("loop_exit", "")
	if not raw_loop_exit is String or not LOOP_EXITS.has(raw_loop_exit):
		return null
	var raw_seen: Variant = values.get("last_seen_after", -1.0)
	var raw_length: Variant = values.get("corridor_length", -1.0)
	if not _valid_number(raw_seen, -1.0, MAX_TIMESTAMP) \
			or not _valid_number(raw_length, -1.0, MAX_CORRIDOR_LENGTH):
		return null
	if float(raw_seen) < 0.0 and not is_equal_approx(float(raw_seen), -1.0):
		return null
	if float(raw_length) < 0.0 \
			and not is_equal_approx(float(raw_length), -1.0):
		return null
	var doors := {}
	var has_door_value := false
	var missing_door_value := false
	for aperture in ["a", "b"]:
		var raw_door: Variant = values.get("door_" + aperture, -1.0)
		if not _valid_number(raw_door, -1.0, 1.0):
			return null
		var openness := float(raw_door)
		if openness < 0.0:
			if not is_equal_approx(openness, -1.0):
				return null
			missing_door_value = true
		else:
			has_door_value = true
			doors[aperture] = openness
	# Door phases require an exact two-aperture record. Legacy/incomplete site
	# state is discarded in isolation instead of risking graph/geometry drift.
	if missing_door_value or not has_door_value:
		return null
	var expected: Dictionary = {
		"a_open": {"a": 1.0, "b": 0.0},
		"both_open": {"a": 1.0, "b": 1.0},
		"b_open": {"a": 0.0, "b": 1.0},
	}[raw_phase]
	for aperture in ["a", "b"]:
		if not is_equal_approx(float(doors[aperture]),
				float(expected[aperture])):
			return null
		doors[aperture] = float(expected[aperture])
	var state := SpatialSiteState.new()
	state.spec_id = values["spec_id"]
	state.spec_signature = values["signature"]
	state.generation_version = int(raw_generation)
	state.stable_phase = raw_phase
	state.activated = raw_activated
	state.completed = raw_completed
	state.loop_exit = raw_loop_exit
	state.last_seen_after = float(raw_seen)
	state.corridor_length = float(raw_length)
	state.door_openness = doors
	return state


static func _valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var id := value as String
	if id.is_empty() or id.length() > MAX_ID_LENGTH:
		return false
	for i in id.length():
		if _ID_CHARS.find(id.substr(i, 1)) < 0:
			return false
	return true


static func _valid_signature(value: Variant) -> bool:
	if not value is String:
		return false
	var signature := value as String
	if signature.is_empty() or signature.length() > MAX_SIGNATURE_LENGTH:
		return false
	for i in signature.length():
		var code := signature.unicode_at(i)
		if code < 33 or code > 126:
			return false
	return true


static func _valid_number(value: Variant, minimum: float,
		maximum: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum
