class_name DescentProgress
extends RefCounted
## The one persistent Descent checkpoint. It is deliberately small: the seed
## reproduces the building and route, deepest_floor chooses the arrival lift,
## and seen_short_tapes preserves the optional-video no-repeat cycle.

const SAVE_PATH := "user://descent_progress.cfg"
const SECTION := "descent"
const VERSION := 2
const LEGACY_VERSION := 1

var run_seed := 0
var deepest_floor := -1
var seen_short_tapes: Array[String] = []
var completed_beginning_tapes := 0
## Current generated reality per floor. State ids are deterministic for a
## seed/theme/floor; visited ids keep mutation-back pacing coherent after a
## Continue without serializing geometry or compromising WorldGen purity.
var mutation_states := {}
var _save_path := SAVE_PATH


func _init(custom_save_path := "") -> void:
	if not custom_save_path.is_empty():
		_save_path = custom_save_path
	load_from_disk()


func has_checkpoint() -> bool:
	return run_seed > 0 and deepest_floor >= 0


func start_new(seed: int) -> void:
	run_seed = maxi(1, seed)
	deepest_floor = 0
	seen_short_tapes.clear()
	completed_beginning_tapes = 0
	mutation_states.clear()
	save_to_disk()


## Same-seed starts can revisit earlier floors without erasing the highest
## unlocked one. A different seed is a genuinely new Descent.
func reach_floor(seed: int, floor_idx: int) -> void:
	if seed <= 0:
		return
	var floor := clampi(floor_idx, 0, DescentRun.FLOOR_COUNT - 1)
	if run_seed != seed or deepest_floor < 0:
		run_seed = seed
		deepest_floor = floor
		seen_short_tapes.clear()
		completed_beginning_tapes = 0
		mutation_states.clear()
	else:
		deepest_floor = maxi(deepest_floor, floor)
	save_to_disk()


func record_short_tape(path: String) -> void:
	if not has_checkpoint() or path.is_empty() or seen_short_tapes.has(path):
		return
	seen_short_tapes.append(path)
	save_to_disk()


func reset_short_tape_cycle() -> void:
	if not has_checkpoint() or seen_short_tapes.is_empty():
		return
	seen_short_tapes.clear()
	save_to_disk()


func record_beginning_tapes_completed(count: int) -> void:
	if not has_checkpoint():
		return
	var clamped := clampi(count, 0, VhsTapeLibrary.beginning_paths().size())
	if clamped <= completed_beginning_tapes:
		return
	completed_beginning_tapes = clamped
	save_to_disk()


func record_mutation_state(floor_idx: int, state_id: int,
		visited_states: Array[int], state_signature: String,
		visited_signatures: Array[String]) -> void:
	if not has_checkpoint():
		return
	var floor := clampi(floor_idx, 0, DescentRun.FLOOR_COUNT - 1)
	var visited: Array[int] = []
	for value in visited_states:
		var state := maxi(0, int(value))
		if not visited.has(state):
			visited.append(state)
	visited.sort()
	mutation_states[str(floor)] = {
		"state": maxi(0, state_id),
		"visited": visited,
		"generation": DescentTopology.GENERATION_VERSION,
		"signature": state_signature,
		"visited_signatures": visited_signatures.duplicate(),
	}
	save_to_disk()


func mutation_state_for_floor(floor_idx: int) -> Dictionary:
	var value: Variant = mutation_states.get(str(clampi(
		floor_idx, 0, DescentRun.FLOOR_COUNT - 1)), {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func save_to_disk() -> Error:
	if not has_checkpoint():
		return ERR_UNCONFIGURED
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", VERSION)
	config.set_value(SECTION, "run_seed", run_seed)
	config.set_value(SECTION, "deepest_floor", deepest_floor)
	config.set_value(SECTION, "seen_short_tapes",
		PackedStringArray(seen_short_tapes))
	config.set_value(SECTION, "completed_beginning_tapes",
		completed_beginning_tapes)
	config.set_value(SECTION, "mutation_states", mutation_states)
	return config.save(_save_path)


func load_from_disk() -> bool:
	run_seed = 0
	deepest_floor = -1
	seen_short_tapes.clear()
	completed_beginning_tapes = 0
	mutation_states.clear()
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		return false
	var saved_version := int(config.get_value(SECTION, "version", 0))
	if saved_version != VERSION and saved_version != LEGACY_VERSION:
		return false
	var saved_seed := int(config.get_value(SECTION, "run_seed", 0))
	var saved_floor := int(config.get_value(SECTION, "deepest_floor", -1))
	if saved_seed <= 0 or saved_floor < 0 \
			or saved_floor >= DescentRun.FLOOR_COUNT:
		return false
	run_seed = saved_seed
	deepest_floor = saved_floor
	var paths: Variant = config.get_value(SECTION, "seen_short_tapes",
		PackedStringArray())
	var random_library := VhsTapeLibrary.random_paths()
	if paths is Array or paths is PackedStringArray:
		for value in paths:
			var path := str(value)
			if random_library.has(path) and not seen_short_tapes.has(path):
				seen_short_tapes.append(path)
	completed_beginning_tapes = clampi(int(config.get_value(
		SECTION, "completed_beginning_tapes", 0)), 0,
		VhsTapeLibrary.beginning_paths().size())
	var saved_mutations: Variant = config.get_value(
		SECTION, "mutation_states", {})
	if saved_mutations is Dictionary:
		for raw_key in saved_mutations:
			var floor := int(str(raw_key))
			var raw_state: Variant = saved_mutations[raw_key]
			if floor < 0 or floor >= DescentRun.FLOOR_COUNT \
					or not raw_state is Dictionary:
				continue
			var entry := raw_state as Dictionary
			var visited: Array[int] = []
			var raw_visited: Variant = entry.get("visited", [])
			if raw_visited is Array or raw_visited is PackedInt32Array:
				for raw_value in raw_visited:
					var state := maxi(0, int(raw_value))
					if not visited.has(state):
						visited.append(state)
			visited.sort()
			var visited_signatures: Array[String] = []
			var raw_signatures: Variant = entry.get("visited_signatures", [])
			if raw_signatures is Array or raw_signatures is PackedStringArray:
				for raw_signature in raw_signatures:
					var signature := str(raw_signature)
					if not visited_signatures.has(signature):
						visited_signatures.append(signature)
			mutation_states[str(floor)] = {
				"state": maxi(0, int(entry.get("state", 0))),
				"visited": visited,
				"generation": int(entry.get("generation", 0)) \
					if saved_version == VERSION else 0,
				"signature": str(entry.get("signature", "")) \
					if saved_version == VERSION else "",
				"visited_signatures": visited_signatures \
					if saved_version == VERSION else [],
			}
	return true


## Test helper. Runtime starts overwrite checkpoints through start_new().
func clear_from_disk() -> void:
	var absolute := ProjectSettings.globalize_path(_save_path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	run_seed = 0
	deepest_floor = -1
	seen_short_tapes.clear()
	completed_beginning_tapes = 0
	mutation_states.clear()
