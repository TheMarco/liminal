extends SceneTree
## Persistence contract for Continue / Restart / New Descent. Uses its own
## temporary file so this audit can never inspect or alter a player's checkpoint.
## Run: godot --headless --path . --script tools/audit_descent_progress.gd

const TEST_PATH := "/tmp/liminal_audit_descent_progress.cfg"

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
	var randoms := VhsTapeLibrary.random_paths()
	var beginnings := VhsTapeLibrary.beginning_paths()
	progress.record_short_tape(randoms[0])
	progress.record_short_tape(randoms[0])
	progress.record_short_tape(randoms[1])
	progress.record_beginning_tapes_completed(3)
	progress.record_mutation_state(6, 4, [0, 1, 4], "state-four",
		["base", "state-one", "state-four"])
	_expect(progress.deepest_floor == 6,
		"starting an earlier floor lowered the deepest checkpoint")
	_expect(progress.seen_short_tapes.size() == 2,
		"optional tape history did not de-duplicate")
	_expect(progress.completed_beginning_tapes == 3,
		"ordered beginning progress did not advance")
	_expect(int(progress.mutation_state_for_floor(6).get("state", -1)) == 4,
		"floor reality state did not record")

	var loaded := DescentProgress.new(TEST_PATH)
	_expect(loaded.has_checkpoint() and loaded.run_seed == 111,
		"run seed did not survive relaunch")
	_expect(loaded.deepest_floor == 6,
		"deepest floor did not survive relaunch")
	_expect(loaded.seen_short_tapes == progress.seen_short_tapes,
		"optional tape cycle did not survive relaunch")
	_expect(loaded.completed_beginning_tapes == 3,
		"ordered beginning progress did not survive relaunch")
	var restored_mutation := loaded.mutation_state_for_floor(6)
	_expect(int(restored_mutation.get("state", -1)) == 4 \
		and restored_mutation.get("visited", []) == [0, 1, 4] \
		and int(restored_mutation.get("generation", 0)) \
			== DescentTopology.GENERATION_VERSION \
		and str(restored_mutation.get("signature", "")) == "state-four",
		"floor reality state did not survive relaunch")

	# A signature is the authority, not an old numeric slot. Reordering or
	# changing planned states must resolve the identity or fall back to base.
	var topology := DescentTopology.new(1, 0)
	topology._states.append(TopologyState.new(
		1, "fixture", {}, {Vector2i.ZERO: 2}))
	var fixture_signature := topology.state_signature(1)
	_expect(topology.restore_signatures(fixture_signature, [fixture_signature]) \
		and topology.current_state_id() == 1,
		"matching topology signature did not restore its state")
	_expect(not topology.restore_signatures("obsolete-state-signature") \
		and topology.current_state_id() == 0,
		"unknown topology signature was reinterpreted instead of falling back")

	# A same-seed restart never lowers the checkpoint; a new seed resets it.
	loaded.reach_floor(111, 0)
	_expect(loaded.deepest_floor == 6,
		"same-building restart erased the deeper unlock")
	loaded.start_new(222)
	_expect(loaded.run_seed == 222 and loaded.deepest_floor == 0,
		"New Descent did not establish a fresh floor-one checkpoint")
	_expect(loaded.seen_short_tapes.is_empty(),
		"New Descent inherited the old optional-tape cycle")
	_expect(loaded.completed_beginning_tapes == 0,
		"New Descent inherited ordered beginning progress")
	_expect(loaded.mutation_states.is_empty(),
		"New Descent inherited the old building realities")

	# Restoring exclusions into a recreated run must deal an unseen short.
	if randoms.size() >= 3 and not beginnings.is_empty():
		loaded.record_short_tape(randoms[0])
		loaded.record_short_tape(randoms[1])
		loaded.record_beginning_tapes_completed(beginnings.size())
		var run := DescentRun.new()
		run.world_seed = loaded.run_seed
		run.restore_short_tape_cycle(loaded.seen_short_tapes,
			loaded.completed_beginning_tapes)
		var draw := run.tape_for_setup("restored:optional", false)
		_expect(draw != randoms[0] and draw != randoms[1] and randoms.has(draw),
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
