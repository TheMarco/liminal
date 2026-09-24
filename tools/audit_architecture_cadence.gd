extends "res://tools/lib/audit_base.gd"
## Real automatic scheduling: no timer overrides, F6, or direct event starts.
## godot --headless --path . --script tools/audit_architecture_cadence.gd -- --nologo --level=7
const Placement := preload("res://scripts/environment_breath_placement.gd")

func run() -> void:
	Engine.max_fps = 60
	var game := await boot_game(1021555651)
	var scheduler: Node = game._architectural_events
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._photo_camera.set_process(false)
	var found := false
	for chunk: Chunk in game.cm.chunks.values():
		for candidate in Placement.candidates(chunk):
			var focus: Vector3 = chunk.to_global(candidate.center)
			var normal: Vector3 = chunk.global_basis * candidate.face.normal
			game.player.global_position = focus + normal * 4.0
			game.player.global_position.y = chunk.global_position.y + chunk._floor_h() + 0.15
			game.player.cam.global_position = game.player.global_position + Vector3.UP * 1.5
			game.player.cam.look_at(focus)
			if Placement.visible(candidate, chunk, game.player.cam):
				found = true
				break
		if found: break
	expect(found, "fixture has no visible breathing wall")
	if not found:
		await teardown_game(game)
		finish()
		return
	# Camera use spends the first wait but cannot start the effect. Lowering
	# it should take the next safe opportunity, without another full delay.
	game._photo_camera._raised = true
	await create_timer(15.0).timeout
	expect(scheduler.events_started == 0 and not is_instance_valid(game._breathing.active),
		"camera hold allowed an architectural effect")
	expect(scheduler.cooldown == 0.0, "camera use prevented the initial wait from expiring")
	game._photo_camera._raised = false
	var began := Time.get_ticks_msec()
	expect(await await_until(func(): return scheduler.events_started > 0, 8000),
		"automatic architecture did not become visible after the camera lowered")
	print("Automatic first sighting after camera lowered: %.2fs" % ((Time.get_ticks_msec() - began) / 1000.0))
	# Remain in the same ordinary room: a previously used clear wall and
	# recent kind are preferences, not permanent exclusions. The quiet gap
	# should now be audible in play, without silencing effects entirely.
	var first: int = scheduler.events_started
	began = Time.get_ticks_msec()
	await create_timer(20.0).timeout
	expect(scheduler.events_started == first,
		"architectural sight repeated before the intended quiet gap")
	expect(await await_until(func(): return scheduler.events_started > first, 30000),
		"visible room did not receive a second automatic sighting within the moderated cadence")
	print("Automatic repeat sighting: %.2fs" % ((Time.get_ticks_msec() - began) / 1000.0))
	await teardown_game(game)
	finish("automatic architecture cadence: camera hold, first sighting and repeat")
