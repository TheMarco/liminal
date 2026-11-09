extends "res://tools/lib/audit_base.gd"
## A won run plays the ending (videos/outro/outside.ogv) before the summary,
## and the summary then rises from black. Test mode keeps the playback state in
## its own file, never the player's.
## godot --headless --path . --script tools/audit_descent_outro.gd -- \
##   --mode=descent --descent-floor=11 --nologo --test-mode


func run() -> void:
	var game := await boot_game(424242)
	expect(game.descent and game.run != null, "audit did not boot into Descent")
	expect(ResourceLoader.exists(game.OUTRO_PATH), "ending movie is missing: " + game.OUTRO_PATH)
	var stream := load(game.OUTRO_PATH) as VideoStream
	expect(stream != null, "ending movie did not import as a VideoStream")
	var seen_before: bool = game._intro_state.has_viewed_video(game.OUTRO_PATH)

	game.run.finish(true)
	expect(await await_until(func(): return is_instance_valid(game._descent_intro), 5000),
		"won run did not start the ending")
	var outro: DescentIntro = game._descent_intro
	if is_instance_valid(outro):
		expect(outro._video.stream != null
			and outro._video.stream.resource_path == game.OUTRO_PATH,
			"ending player is not playing the ending movie")
		expect(outro._video.is_playing(), "ending movie did not begin playback")
		expect(outro.skip_available() == seen_before,
			"Skip availability does not follow this machine's ending view")
		if outro.skip_available():
			expect(outro._skip_button.text == "SKIP ENDING", "ending Skip is mislabelled")
		expect(not is_instance_valid(game._descent_summary), "summary appeared over the ending")
		outro._finish(true)
	expect(await await_until(func(): return is_instance_valid(game._descent_summary), 5000),
		"summary did not follow the ending")
	if is_instance_valid(game._descent_summary):
		expect(game._descent_summary.won, "summary after the ending is not a win")
		expect(game._descent_summary.from_black, "summary after the ending does not rise from black")
	expect(game._intro_state.has_viewed_video(game.OUTRO_PATH),
		"watching the ending to the end did not unlock Skip")
	await teardown_game(game)
	finish("a won run plays the ending, then the summary from black")
