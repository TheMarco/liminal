extends "res://tools/lib/audit_base.gd"
## Completion restores through the production floor builder and actual ritual.
## Uses an isolated checkpoint; never reads/writes the player's progress.
## godot --headless --path . --script tools/audit_recording_replay.gd -- --mode=descent --nologo
const PATH := "/tmp/liminal-recording-replay.cfg"

func run() -> void:
	var game := await boot_game(7)
	var progress := DescentProgress.new(PATH)
	progress.start_new(7)
	game._descent_progress = progress
	game._progress_enabled = true
	game._set_presence(game.Presence.SILENT)
	game.run.set_process(false)
	expect(not game.run.tape_watched, "unseen recording was completed at startup")
	game.descent_tape_finished()
	expect(progress.objective_tape_completed(0), "finishing recording did not persist completion")
	var loaded := DescentProgress.new(PATH)
	expect(loaded.objective_tape_completed(0), "completion was lost on disk reload")
	game._descent_progress = loaded
	game.run.prepare_floor()
	expect(not game.run.tape_watched, "test did not reset transient floor state")
	game.level_root.free()
	var at: Vector2i = game.descent_route.target
	var around := Vector3(at.x * 12.0 + 6, 0.15, at.y * 12.0 + 6)
	game.player.teleport(around)
	game._build_level(0, around)
	await process_frame
	expect(game.run.tape_watched and game.cm.descent_tape_watched,
		"production floor rebuild did not restore completed objective")
	var chunk: Chunk = game.cm.chunk_at(at)
	expect(chunk != null and chunk.descent_lift_ready(), "completed recording did not open the lift gate on retry")
	if chunk != null:
		var ritual: VhsRitual = chunk.get_node("DescentRitual")
		expect(ritual._done and ritual._hit.enabled, "completed TV was not available for replay")
		expect(ritual._hit.prompt_text.to_lower().contains("replay"), "completed TV does not advertise optional replay")
		# The restored floor has no photos in this fixture. Replay must bypass
		# the first-viewing proof gate, and interruption must retain completion.
		expect(not game.descent_photo_requirement_met(), "fixture unexpectedly has photo proof")
		ritual._on_activated(game.player)
		expect(ritual._playing, "completed TV refused optional replay")
		ritual.reset_tape()
		expect(ritual._done and game.run.tape_watched and loaded.objective_tape_completed(0),
			"interrupting replay erased objective completion")
		game.player.set_physics_process(false)
	game._progress_enabled = false
	loaded.clear_from_disk()
	await teardown_game(game)
	finish("objective recording: completion, retry, lift access, optional replay and interruption")
