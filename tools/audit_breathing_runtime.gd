extends "res://tools/lib/audit_base.gd"
## Real Main startup, gating, actor approach and streamed-room cleanup.
const Placement := preload("res://scripts/environment_breath_placement.gd")

func run() -> void:
	var game := await boot_game(980712989)
	var director: Node = game._breathing
	expect(director != null and director.pacing == game._director, "startup lost pacing authority")
	expect(game._architectural_events != null and director.managed \
		and game._native_doorways.managed,
		"normal play did not assign both effects to one scheduler")
	# This audit exercises the director's lower-level safety contract directly.
	# The scheduler has its own focused timing/variety contract.
	game._architectural_events.set_physics_process(false)
	director.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var choice: Dictionary = {}
	var chunk: Chunk
	for candidate_chunk: Chunk in game.cm.chunks.values():
		var options := Placement.candidates(candidate_chunk)
		if not options.is_empty():
			chunk = candidate_chunk
			choice = options[0]
			break
	if choice.is_empty():
		fail("fixture has no clear wall")
		await teardown_game(game)
		finish()
		return
	var normal: Vector3 = chunk.global_basis * choice.face.normal
	var focus: Vector3 = chunk.to_global(choice.center)
	game.player.global_position = focus + normal * 4.0
	game.player.global_position.y = chunk.global_position.y + chunk._floor_h() + 0.15
	game.player.velocity = Vector3.ZERO
	game.player.cam.global_position = game.player.global_position + Vector3.UP * 1.5
	game.player.cam.look_at(focus)
	await physics_frame
	expect(game._breathing_allowed(), "normal Wander exploration is blocked")
	expect(Placement.visible(choice, chunk, game.player.cam), "clear visible wall was rejected")
	var scheduler: Node = game._architectural_events
	scheduler.cooldown = 0.0
	scheduler._door_ready_at = INF
	for scan in 18:
		scheduler._physics_process(0.016)
		if is_instance_valid(director.active): break
	expect(is_instance_valid(director.active) and scheduler._pending == "breath",
		"shared scheduler did not hand a visible wall to the effect director")
	if is_instance_valid(director.active):
		finish_preparing(director)
		director._physics_process(0.016)
		scheduler._physics_process(0.016)
		expect(scheduler.events_started == 0 and scheduler._pending == "breath",
			"barely started motion consumed the full sighting cooldown")
		game._photo_camera._raised = true
		director._physics_process(0.016)
		game._photo_camera._raised = false
		scheduler._physics_process(0.016)
		expect(scheduler.cooldown <= 3.0 and director._last_mesh_id == 0,
			"unseen cancellation spent the wall or long cooldown")
		expect(director.try_kind_at_cell("breath", chunk.cell),
			"cancelled wall cannot be selected again by the ordinary search")
		if is_instance_valid(director.active):
			scheduler._pending = "breath"
			finish_preparing(director)
			game.player.cam.rotate_y(PI)
			director._physics_process(2.0)
			scheduler._physics_process(0.016)
			expect(scheduler.events_started == 0,
				"offscreen wall motion consumed the sighting cooldown")
			game.player.cam.rotate_y(-PI)
			director._physics_process(0.11)
			scheduler._physics_process(0.016)
		expect(scheduler.events_started == 1 \
			and scheduler.history.back() == "breath" \
			and scheduler.cooldown >= 6.0 and scheduler.cooldown <= 10.0,
			"shared scheduler did not record a completed live sighting")
		director.cancel()
	director.managed = false
	director._last_mesh_id = 0
	await physics_frame
	# Route actual key events through the viewport, including logical-key-only
	# events. Missing flags and gameplay gates must explain themselves on HUD.
	var notices: Array[String] = []
	director.debug_notice.connect(func(message: String): notices.append(message))
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	key.pressed = true
	director.debug_controls = false
	root.push_input(key)
	expect(not notices.is_empty() and notices.back().contains("PREVIEW OFF"), "disabled F6 has no explanation")
	expect(game._event_hint.text.contains("PREVIEW OFF"), "F6 feedback did not reach HUD")
	director.debug_controls = true
	game._dying = true
	root.push_input(key)
	expect(notices.back().contains("blocked"), "blocked F6 has no explanation")
	game._dying = false
	root.push_input(key)
	expect(director._debug_kind == "breath" and notices.back().contains("searching"), "F6 did not request a wall breath")
	director._debug_kind = ""
	director.debug_controls = false
	# Exercise the actual automatic search, not only the direct debug entry.
	director.cooldown = 0.0
	for scan in 10:
		director._physics_process(1.01)
		if is_instance_valid(director.active): break
	expect(is_instance_valid(director.active) and director.kind == "breath", "automatic visible-wall search did not start the first breath")
	director.cancel()
	await check_ceiling(game, director)
	game.player.global_position = focus + normal * 4.0 - Vector3.UP * 0.6
	game.player.velocity = Vector3.ZERO
	for flag in ["_dying", "_quitting", "_descent_preparing"]:
		game.set(flag, true)
		expect(not game._breathing_allowed(), flag + " did not suppress architecture")
		game.set(flag, false)
	game._set_presence(game.Presence.SILENT)
	expect(not director.start_event(chunk, choice), "silent presentation allowed event")
	game._set_presence(game.Presence.WANDER)
	expect(director.start_event(chunk, choice), "event did not start")
	if not is_instance_valid(director.active):
		await teardown_game(game)
		finish()
		return
	var surface: Node = director.active
	expect(not surface.prepared and surface.originals_restored(), "preparation touched the visible wall early")
	expect(not director.start_event(chunk, choice), "event stacked")
	finish_preparing(director)
	director._physics_process(2.0)
	expect(director.elapsed > 0 and surface.weights[0] > 0, "active event did not advance")
	game.player.global_position = focus + normal * 0.8 - Vector3.UP * 0.6
	director._physics_process(0.016)
	expect(director.active == null and surface.originals_restored(), "close actor was not protected by withdrawal")
	await physics_frame
	game.player.global_position = focus + normal * 4.0 - Vector3.UP * 0.6
	expect(director.start_event(chunk, choice, "travel"), "travelling event did not start")
	surface = director.active
	if is_instance_valid(surface):
		finish_preparing(director)
		director._physics_process(3.0)
		game._photo_camera._raised = true
		director._physics_process(0.016)
		expect(director.active == null and surface.originals_restored(), "photo aiming did not restore surface")
		game._photo_camera._raised = false
	await physics_frame
	expect(director.start_event(chunk, choice), "event did not restart after capture")
	if is_instance_valid(director.active):
		finish_preparing(director)
		director._physics_process(2.0)
		director.cancel()
		expect(director.start_event(chunk, choice, "travel"), "preparation restart failed")
		director._physics_process(0.016)
		expect(not director.active.prepared, "fixture finished preparation too early")
		# Stream deletion also cleans up partially prepared morph resources.
		game.cm.chunks.erase(chunk.cell)
		chunk.queue_free()
		await process_frame
		director._physics_process(0.016)
		expect(not is_instance_valid(director.active), "room unload retained effect")
	var old_director: Node = director
	game._jump_to(1, Vector3(6, 0.15, 2), false)
	await await_until(func(): return not game._switching, 12000)
	expect(not is_instance_valid(old_director), "floor transition retained old director")
	expect(is_instance_valid(game._breathing) and game._breathing.manager == game.cm, "new floor lacks configured director")
	expect(game._architectural_events.breathing == game._breathing \
		and game._breathing.managed and game._native_doorways.managed,
		"new floor did not reconnect the shared architecture scheduler")
	await teardown_game(game)
	finish("breathing runtime: pacing, visibility, gates, actor withdrawal and teardown")

func finish_preparing(director: Node) -> void:
	for step in 100:
		if not is_instance_valid(director.active) or director.active.prepared: break
		director._physics_process(0.016)
	expect(is_instance_valid(director.active) and director.active.prepared, "incremental preparation failed")
	print("Preparation max step ms: ", director.max_prepare_step_ms)

func check_ceiling(game: Node, director: Node) -> void:
	var choice: Dictionary = {}
	var chunk: Chunk
	for candidate_chunk: Chunk in game.cm.chunks.values():
		var options := Placement.candidates(candidate_chunk, "ceiling")
		if not options.is_empty():
			chunk = candidate_chunk
			choice = options[0]
			break
	expect(not choice.is_empty(), "runtime fixture has no clear ceiling")
	if choice.is_empty(): return
	var focus: Vector3 = chunk.to_global(choice.center)
	game.player.global_position = Vector3(focus.x, chunk.global_position.y + chunk._floor_h() + 0.15, focus.z)
	game.player.velocity = Vector3.ZERO
	game.player.cam.global_position = game.player.global_position + Vector3.UP * 1.5
	game.player.cam.look_at(focus + Vector3(0.05, 0, 0))
	await physics_frame
	expect(Placement.visible(choice, chunk, game.player.cam), "visible ceiling was rejected")
	director._debug_kind = "ceiling"
	director.cooldown = 0.0
	for scan in 10:
		director._physics_process(1.01)
		if is_instance_valid(director.active): break
	expect(is_instance_valid(director.active) and director.kind == "ceiling", "live search did not start ceiling breath")
	if not is_instance_valid(director.active): return
	var surface: Node = director.active
	finish_preparing(director)
	director._physics_process(3.5)
	expect(surface.weights[0] > 0.9, "ceiling did not reach peak")
	game.player.velocity = Vector3.UP * 8.0
	director._physics_process(0.016)
	expect(director.active == null and surface.originals_restored(), "ceiling failed swept-head withdrawal")
	game.player.velocity = Vector3.ZERO
	await physics_frame
