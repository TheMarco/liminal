extends "res://tools/lib/audit_base.gd"
## Regression coverage for dynamic objective interaction copy.

func run() -> void:
	var game := await boot_game(7)
	expect(not game._progress_enabled and game.descent, "audit must use --mode=descent --nologo")
	game._set_presence(game.Presence.SILENT)
	game.run.set_process(false)
	game.player.set_physics_process(false)
	await _settle_realm(game)
	if is_instance_valid(game._figures):
		game._figures.set_process(false)
	if is_instance_valid(game._passers):
		game._passers.set_process(false)
	var at: Vector2i = game.descent_route.target
	var around := Vector3(at.x * 12.0 + 6, 0.15, at.y * 12.0 + 6)
	game.player.teleport(around)
	game.level_root.free()
	game._build_level(0, around)
	await process_frame
	var chunk: Chunk = game.cm.chunk_at(at)
	expect(chunk != null, "target chunk was not built")
	if chunk == null:
		await teardown_game(game)
		finish("objective prompt audit")
		return
	var ritual := chunk.get_node_or_null("DescentRitual") as VhsRitual
	expect(ritual != null, "target ritual missing")
	if ritual != null:
		expect(ritual._hit.get_prompt().to_lower().contains("photographs"), "initial ritual prompt lacks photo quota")
		expect(ritual._hit.get_prompt().to_lower().contains("tape locked"), "initial ritual prompt lacks tape lock")
		var ids: Array = game._photo_director.plan.keys()
		var quota: int = game._photo_director.required_count()
		for i in range(mini(quota - 1, ids.size())):
			var cell: Vector2i = ids[i]
			game._photo_director.mark_documented(str(game._photo_director.plan[cell]["id"]))
		expect(game._photo_director.documented_count() == quota - 1, "photo count did not reach quota-1")
		expect(ritual._hit.get_prompt().to_lower().contains("tape locked"), "tape unlocked before quota")
		for i in range(quota - 1, ids.size()):
			var cell: Vector2i = ids[i]
			game._photo_director.mark_documented(str(game._photo_director.plan[cell]["id"]))
		expect(game.descent_photo_requirement_met(), "planned photo quota did not complete")
		expect(ritual._hit.get_prompt().to_lower().contains("play the tape"), "ritual prompt did not unlock")
	var lift := chunk.find_child("DescentLiftCall", true, false) as Interactable
	expect(lift != null, "descent lift interactable missing")
	if lift != null:
		expect(lift.get_prompt() == "E — call lift · WATCH THE TAPE TO LEAVE", "lift prompt lacks tape prerequisite")
	var fallback := Interactable.new()
	expect(fallback.get_prompt() == "E — interact", "generic interactable fallback changed")
	fallback.free()
	if ritual != null:
		ritual._playback_state = IntroPlaybackState.new("/tmp/liminal-objective-unseen-%d.cfg" % OS.get_process_id())
		ritual._on_activated(game.player)
		await process_frame
		expect(ritual._playing and ritual._video != null, "objective tape did not start")
		if ritual._video != null:
			expect(ritual._video.bus == SoundBank.DIALOGUE_BUS, "ritual playback uses wrong audio bus")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		expect(paused and is_instance_valid(game._pause_menu) and ritual._playing,
			"Escape did not pause the actual TV flow")
		game._close_settings()
		await process_frame
		var stop := InputEventKey.new()
		stop.keycode = KEY_E
		stop.physical_keycode = KEY_E
		stop.pressed = true
		root.push_input(stop)
		expect(not ritual._playing and not ritual._done, "E did not stop and rewind first viewing")
		ritual._on_activated(game.player)
		ritual._finish_tape(false)
		expect(game.run.tape_watched, "completion did not update run")
		if lift != null:
			expect(lift.get_prompt() == "E — call lift", "lift prompt did not unlock")
		ritual._on_activated(game.player)
		ritual.reset_tape()
		expect(ritual._hit.get_prompt().to_lower().contains("replay"), "completed replay prompt unavailable")
	for frame in 6:
		await process_frame
	await _settle_realm(game)
	await teardown_game(game)
	finish("objective prompts and dynamic unlocks")

func _settle_realm(game: Node) -> void:
	var realm: RealmExcursion = game._realm_visit
	if not is_instance_valid(realm):
		return
	# Do not free a real streamed preview while its coroutine is still building.
	if realm._building:
		expect(await await_until(func(): return realm.phase != RealmExcursion.Phase.PREPARING, 20000), "realm preview did not settle")
	else:
		realm.set_process(false)
		expect(await await_until(func(): return realm._preview_resources_ready, 20000), "realm preload did not settle")
