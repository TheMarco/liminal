extends "res://tools/lib/audit_base.gd"
## Runtime contract for Wander's pressure-free level browsing: every floor can be
## walked with a live soundscape and nothing hunting the player.
## docs/DESCENT.md calls this the project's most important invariant.
##
## Run: godot --headless --path . --script tools/audit_wander_mode.gd -- --nologo
##
## The --nologo matters. Started with the title card up, main correctly leaves
## whispers suspended until the player picks a mode, so without the flag the
## soundscape check fails for the wrong reason.

const SEED := 405195947


func run() -> void:
	var game := await boot_game(SEED)

	expect(not game.descent, "default startup did not select Wander")
	expect(game._figures.suspended,
		"Wander startup enabled hostile shadow figures")
	expect(not game._whispers.suspended,
		"Wander startup left ambient whispers suspended")

	game._show_return_prompt()
	game._cancel_return_to_title()
	expect(game._figures.suspended,
		"cancelling the return prompt enabled Wander figures")

	game._on_start(false)
	await process_frame
	expect(not game.descent, "Wander title start selected Descent")
	expect(game._figures.suspended,
		"Wander title start enabled hostile shadow figures")

	# A signal already queued before a mode transition must also be harmless.
	game._on_figure_reached_player()
	expect(not game._dying,
		"a stale figure signal triggered a Wander death")

	await teardown_game(game)
	finish("shadow figures remain disabled")
