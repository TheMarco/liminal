extends SceneTree
## Persistence contract for Continue / Restart / New Descent. Uses its own
## user:// file so this audit can never inspect or alter a player's checkpoint.
## Run: godot --headless --path . --script tools/audit_descent_progress.gd

const TEST_PATH := "user://audit_descent_progress.cfg"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var progress := DescentProgress.new(TEST_PATH)
	progress.clear_from_disk()
	_expect(not progress.has_checkpoint(), "cleared progress still has a checkpoint")

	progress.start_new(111)
	progress.reach_floor(111, 6)
	progress.reach_floor(111, 2)
	progress.record_short_tape("res://videos/tapes/a.ogv")
	progress.record_short_tape("res://videos/tapes/a.ogv")
	progress.record_short_tape("res://videos/tapes/b.ogv")
	_expect(progress.deepest_floor == 6,
		"starting an earlier floor lowered the deepest checkpoint")
	_expect(progress.seen_short_tapes.size() == 2,
		"optional tape history did not de-duplicate")

	var loaded := DescentProgress.new(TEST_PATH)
	_expect(loaded.has_checkpoint() and loaded.run_seed == 111,
		"run seed did not survive relaunch")
	_expect(loaded.deepest_floor == 6,
		"deepest floor did not survive relaunch")
	_expect(loaded.seen_short_tapes == progress.seen_short_tapes,
		"optional tape cycle did not survive relaunch")

	# A same-seed restart never lowers the checkpoint; a new seed resets it.
	loaded.reach_floor(111, 0)
	_expect(loaded.deepest_floor == 6,
		"same-building restart erased the deeper unlock")
	loaded.start_new(222)
	_expect(loaded.run_seed == 222 and loaded.deepest_floor == 0,
		"New Descent did not establish a fresh floor-one checkpoint")
	_expect(loaded.seen_short_tapes.is_empty(),
		"New Descent inherited the old optional-tape cycle")

	# Restoring exclusions into a recreated run must deal an unseen short.
	var shorts := VhsTapeLibrary.paths(false)
	if shorts.size() >= 3:
		loaded.record_short_tape(shorts[0])
		loaded.record_short_tape(shorts[1])
		var run := DescentRun.new()
		run.world_seed = loaded.run_seed
		run.restore_short_tape_cycle(loaded.seen_short_tapes)
		var draw := run.tape_for_setup("restored:optional", false)
		_expect(draw != shorts[0] and draw != shorts[1],
			"restored run replayed a short before pool exhaustion")
		run.free()
	else:
		failures.append("not enough short recordings to audit restored exclusions")

	loaded.clear_from_disk()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("descent progress audit: PASS — seed, deepest floor and tape cycle persist")
		quit()
	else:
		quit(1)
