class_name DescentProgress
extends RefCounted
## The one persistent Descent checkpoint. It is deliberately small: the seed
## reproduces the building and route, deepest_floor chooses the arrival lift,
## and seen_short_tapes preserves the optional-video no-repeat cycle.

const SAVE_PATH := "user://descent_progress.cfg"
const SECTION := "descent"
const VERSION := 1

var run_seed := 0
var deepest_floor := -1
var seen_short_tapes: Array[String] = []
var completed_beginning_tapes := 0
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
	return config.save(_save_path)


func load_from_disk() -> bool:
	run_seed = 0
	deepest_floor = -1
	seen_short_tapes.clear()
	completed_beginning_tapes = 0
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		return false
	if int(config.get_value(SECTION, "version", 0)) != VERSION:
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
