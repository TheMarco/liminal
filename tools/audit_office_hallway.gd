extends "res://tools/lib/audit_base.gd"
## Office Descent hallway, ordinary scheduler and real walking.
## --script tools/audit_office_hallway.gd -- --test-mode --seed=1021555651 --descent-floor=3

func run() -> void:
	Engine.max_fps = 60
	seed(1021555651)
	var game := await boot_game(1021555651)
	var resume_capture := func():
		if paused and is_instance_valid(game._pause_menu): game._close_settings()
	process_frame.connect(resume_capture)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_process_unhandled_input(false)
	game._photo_camera.set_process(false)
	game._architectural_events.set_physics_process(false)
	game.cm.set_process(false)
	game.run.set_physics_process(false)
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
		DirAccess.make_dir_recursive_absolute("/tmp/liminal-office-walk-frames")
	var last_capture := 0
	var capture_count := 0
	var cell := Vector2i(18, 46)
	game.cm.warm_up(cell)
	game.player.teleport(Vector3(220, 0.15, 558))
	game.player.rotation.y = -PI / 2.0
	game.player.cam.rotation = Vector3.ZERO
	game.player.set_physics_process(true)
	game.player.set_process(true)
	game.cm.stream_focus = game.player.global_position
	game.cm.set_process(true)
	game.run.set_physics_process(true)
	game._architectural_events.set_physics_process(true)
	var scheduler: Node = game._architectural_events
	var breath: Node = game._breathing
	var began := Time.get_ticks_msec()
	var next_log := 0
	var moving := 0.0
	var walk_yaw := -PI / 2.0
	while Time.get_ticks_msec() - began < 85000:
		if game.run.ended or not is_instance_valid(breath):
			fail("Office walk ended in an encounter before the cadence check completed")
			break
		var elapsed_ms := Time.get_ticks_msec() - began
		if game.player.global_position.x > 249.0: walk_yaw = PI / 2.0
		if game.player.global_position.x < 219.0: walk_yaw = -PI / 2.0
		game.player.rotation.y = walk_yaw
		game.player.dev_walk = not game.run.blackout and not game.run.watching
		# Keep the real encounter system enabled. A test walker must use the
		# ordinary torch response instead of dying mid-sample without reacting.
		var threat: ShadowFigure
		var closest := 16.0
		for figure: ShadowFigure in game._figures.active_figures():
			var distance: float = figure.global_position.distance_to(game.player.global_position)
			if distance < closest and figure._clear_line(game.player.cam.global_position,
					figure.global_position + Vector3.UP * figure._eye_h):
				closest = distance
				threat = figure
		if game.player.flashlight.visible != (threat != null):
			game.player.set_flashlight(threat != null)
		if threat != null:
			var toward: Vector3 = threat.global_position - game.player.global_position
			game.player.rotation.y = atan2(-toward.x, -toward.z)
			game.player.dev_walk = false
		if game.player.velocity.length() > 1.0: moving += 1.0 / 60.0
		if elapsed_ms >= next_log:
			print("WALK t=", elapsed_ms/1000.0, " pos=", game.player.global_position, " gate=", game._breathing_allowed(), " pending=", scheduler._pending, " active=", is_instance_valid(breath.active), " kind=", breath.kind, " prep=", breath._prepare_elapsed, " phase=", breath.elapsed, " cancellation=", breath.last_cancel_reason, " seen=", scheduler.events_started, " pacing=", game._director.snapshot())
			next_log += 10000
		if capture and is_instance_valid(breath.active) and breath.elapsed > 1.5 and breath._effect_in_view() and elapsed_ms - last_capture >= 400:
			last_capture = elapsed_ms
			await process_frame
			if not is_instance_valid(breath): break
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/liminal-office-walk-frames/%03d-%s.png" % [capture_count, breath.kind])
			capture_count += 1
		await physics_frame
	game.player.dev_walk = false
	print("WALK sightings=", scheduler.counts, " moving seconds=", moving)
	expect(scheduler.events_started >= 2, "ordinary Office hallway walking did not show two effects in 85 seconds")
	process_frame.disconnect(resume_capture)
	await teardown_game(game)
	finish("Office hallway: automatic effects during walking")
