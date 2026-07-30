extends "res://tools/lib/audit_base.gd"
## Runtime contract for the opt-in mode boundary and the first complete floor
## transition. Invoke with Descent CLI flags so main follows its production
## startup path.
## Run: godot --headless --path . --script tools/audit_descent_runtime.gd \
##        -- --mode=descent --nologo

const SEED := 405195947


func run() -> void:
	var game := await boot_game(SEED)

	expect(game.descent, "Descent CLI mode was not selected")
	expect(game.run != null, "run state was not constructed")
	expect(game.active_level == DescentRun.ORDER[0],
		"run did not start on the casino")
	expect(not game.player.allow_sprint, "sprint remains enabled")
	expect(game.cm.descent and game.cm.descent_route == game.descent_route,
		"explicit route config did not reach ChunkManager")
	expect(game._saved_pos.is_empty(),
		"Descent unexpectedly owns Wander saved positions")
	expect(not game.player.flashlight.visible,
		"flashlight did not start switched off")
	expect(game._music_track_for(game.active_level) \
			== game.MUSIC_TRACKS[game.active_level],
		"early Descent did not preserve the floor soundtrack")
	var starting_floor_idx: int = game.run.floor_idx
	game.run.floor_idx = DescentRun.ORDER.size() - 2
	expect(game._music_track_for(game.active_level) == game.DESCENT_LATE_TRACK,
		"late Descent escalation track was not selected")
	game.run.floor_idx = starting_floor_idx
	game.player.set_flashlight(true)
	expect(game.player.flashlight.visible,
		"flashlight could not be enabled in Descent")
	game.player.set_flashlight(false)
	expect(not game.player.flashlight.visible,
		"flashlight could not be switched off")
	for ch in game.cm.chunks.values():
		expect((ch as Chunk).portal_dest < 0,
			"Descent chunk built a Wander portal")
		expect((ch as Chunk).find_children(
			"DescentArrow", "", true, false).is_empty(),
			"Descent still placed an in-world route arrow")
	expect(is_instance_valid(game._descent_hud),
		"Descent HUD route needle was not constructed")
	if is_instance_valid(game._descent_hud):
		expect(game._descent_hud.route == game.descent_route,
			"HUD route needle does not own the active route")
		game._descent_hud._process(0.016)
		expect(game._descent_hud._needle.visible,
			"HUD route needle is hidden during an active floor")

	var route: DescentRoute = game.descent_route
	var target_config := {
		"descent": true,
		"target": true,
		"target_wall": route.target_wall,
		"final": false,
		"floor_idx": 0,
	}
	var target := Chunk.new(game._level_seed(game.active_level),
		route.target, game.active_level, target_config)
	get_root().add_child(target)
	expect(target.portal_dest < 0, "objective room built a portal")
	expect(target.has_node("DescentElevator"),
		"target did not build the Descent elevator")
	expect(target.find_children("*", "Area3D", true, false).size() >= 2,
		"objective car is missing call/commit interaction areas")
	var lift_call: Interactable
	for node in target.find_children("*", "Interactable", true, false):
		var candidate := node as Interactable
		if candidate.prompt_text == "E — call lift":
			lift_call = candidate
			break
	expect(lift_call != null,
		"objective lift has no usable call button")
	if lift_call != null:
		# Calling the lift must NOT open it. The car is somewhere else and the
		# wait is the floor's most exposed stretch; the run owns its clock so it
		# survives the target room streaming out during it.
		lift_call.interact(game.player)
		await create_timer(0.35).timeout
		expect(not lift_call.enabled,
			"call button did not lock after being pressed")
		expect(not target.get_node("DescentElevator").has_meta("opened"),
			"lift opened immediately instead of making the player wait")
		expect(game.run.lift_called and game.run.lift_wait_left > 1.0,
			"call did not start the run-owned lift wait")
		expect(game.run.lift_wait_left <= DescentRun.LIFT_WAIT_LAST + 0.01,
			"lift wait exceeded its authored range")
		expect(DescentRun.lift_wait_for(DescentRun.ORDER.size() - 2) \
				> DescentRun.lift_wait_for(0),
			"lift wait does not lengthen with depth")
		# Only the arrival, not the press, opens the doors.
		target.open_descent_lift()
		await create_timer(0.1).timeout
		expect(target.get_node("DescentElevator").has_meta("opened"),
			"arrival did not open the objective car")
	target.queue_free()
	await process_frame

	# The arrival car: the player rides in, so a floor's origin room owns a
	# sealed car and the player starts standing inside it facing shut doors.
	expect(route.origin_wall >= 0,
		"floor has no wall-backed arrival room")
	expect(route.origin != route.target,
		"arrival room and objective are the same cell")
	if route.origin_wall >= 0:
		var arrival_chunk: Chunk = game.cm.chunk_at(route.origin)
		expect(arrival_chunk != null,
			"arrival room was not streamed in at startup")
		if arrival_chunk != null:
			expect(arrival_chunk.has_node("DescentArrival"),
				"arrival room did not build the car the player rides in on")
			expect(arrival_chunk.has_descent_arrival(),
				"arrival car is not in a usable state at floor start")
		var seat: Dictionary = Chunk.car_interior_point(route.origin,
			route.origin_wall)
		expect(game.player.global_position.distance_to(
			seat["position"]) < 1.0,
			"player did not start inside the arrival car")
		expect(ArrivalSafety.is_clear(game.get_world_3d(), seat["position"],
			[game.player.get_rid()]),
			"arrival car interior is not clear for the player capsule")

	# The two post-launch themes must satisfy the complete runtime objective
	# contract, not merely appear in ORDER or pass the topology-only route
	# audit. Construct their authored targets exactly as ChunkManager does and
	# require the usable lift shell, interaction areas and portal suppression.
	for added_theme in [7, 8]:
		var added_idx := DescentRun.ORDER.find(added_theme)
		expect(added_idx >= 0,
			"theme %d is missing from DescentRun.ORDER" % added_theme)
		if added_idx < 0:
			continue
		var added_route := DescentRoute.build(
			game._level_seed(added_theme), added_theme)
		var added_target := Chunk.new(game._level_seed(added_theme),
			added_route.target, added_theme, {
				"descent": true,
				"target": true,
				"target_wall": added_route.target_wall,
				"final": false,
				"floor_idx": added_idx,
			})
		get_root().add_child(added_target)
		expect(added_target.portal_dest < 0,
			"theme %d objective built a Wander portal" % added_theme)
		expect(added_target.has_node("DescentElevator"),
			"theme %d objective did not build a Descent elevator" % added_theme)
		expect(added_target.find_children(
			"*", "Area3D", true, false).size() >= 2,
			"theme %d objective is missing lift interaction areas" % added_theme)
		var added_call := false
		for added_node in added_target.find_children(
				"*", "Interactable", true, false):
			if (added_node as Interactable).prompt_text == "E — call lift":
				added_call = true
				break
		expect(added_call,
			"theme %d objective has no usable lift call" % added_theme)
		added_target.queue_free()
		await process_frame

	var final_route := DescentRoute.build(game._level_seed(2), 2)
	var final_target := Chunk.new(game._level_seed(2), final_route.target, 2, {
		"descent": true,
		"target": true,
		"target_wall": final_route.target_wall,
		"final": true,
		"floor_idx": DescentRun.ORDER.size() - 1,
	})
	expect(final_target.has_node("DescentExit"),
		"final floor did not build the OUT passage")
	expect(final_target.find_children("*", "Area3D", true, false).size() >= 2,
		"OUT passage is missing approach/finish triggers")
	final_target.free()

	var dead_chunk := Chunk.new(game._level_seed(game.active_level),
		Vector2i.ZERO, game.active_level, {
			"descent": true,
			"anomaly": 0,
			"blackout": true,
		})
	dead_chunk.set_blackout(false)
	for node in dead_chunk.find_children("*", "Light3D", true, false):
		var dead_light := node as Light3D
		expect(not dead_light.visible and dead_light.light_energy == 0.0,
			"dead-cell anomaly revived after blackout")
	dead_chunk.free()

	# Blackout restoration must preserve both a working and intentionally dead
	# fixture instead of turning every light on.
	var lights: Array[Node] = game.level_root.find_children(
		"*", "Light3D", true, false)
	expect(not lights.is_empty(), "floor has no lights to audit")
	if not lights.is_empty():
		var light := lights[0] as Light3D
		light.visible = false
		light.light_energy = 0.217
		game.cm.set_blackout(true)
		expect(not light.visible, "blackout left a fixture visible")
		game.cm.set_blackout(false)
		expect(not light.visible and is_equal_approx(light.light_energy, 0.217),
			"blackout did not restore exact fixture state")

	# Number-key/floor API is a Wander operation and must be inert here.
	var before: int = game.active_level
	game._switch_level(1)
	expect(game.active_level == before and not game._switching,
		"Descent accepted a Wander floor switch")

	# Q confirmation suspends every system that could punish the player while
	# deciding. Cancelling resumes the same run with a short reaction grace.
	game._show_return_prompt()
	expect(is_instance_valid(game._return_prompt),
		"return-to-title confirmation was not constructed")
	expect(game.run.suspended and game._figures.suspended,
		"return confirmation did not suspend Descent threats")
	expect(game._return_prompt.descent,
		"return confirmation did not receive Descent-specific context")
	game._cancel_return_to_title()
	expect(not game.run.suspended and game.run.arrival_grace >= 1.0,
		"cancelling return did not safely resume Descent")
	expect(game._return_prompt == null,
		"cancelled return confirmation remained in the tree")

	# The ride is the one part of a run that happens to the player rather than
	# being done by them, and it is a chain of awaits — if it ever fails to
	# return, the run is unrecoverable. Exercise the real sequence on a detached
	# car: `_descent_ride` drives presentation only, so it cannot advance a floor
	# on its own the way `_descent_commit` does.
	var ride_target := Chunk.new(game._level_seed(game.active_level),
		route.target, game.active_level, target_config)
	get_root().add_child(ride_target)
	var ride_rig: Dictionary = ride_target._descent_lift_rig
	expect(not ride_rig.is_empty(), "objective car exposed no rig")
	if not ride_rig.is_empty():
		var ride_started := Time.get_ticks_msec()
		# An Array is the mutable box a lambda needs: GDScript captures plain
		# locals by value, so a captured bool would never come back.
		var ride_done := [false]
		var runner := func() -> void:
			await ride_target._descent_ride(ride_rig)
			ride_done[0] = true
		runner.call()
		var peak_rumble := 0.0
		while not ride_done[0] and Time.get_ticks_msec() - ride_started < 12000:
			peak_rumble = maxf(peak_rumble, game.player._rumble)
			await process_frame
		var ride_ms := Time.get_ticks_msec() - ride_started
		expect(ride_done[0],
			"lift ride never completed — a run would be stuck in the car")
		expect(peak_rumble > 0.5,
			"lift ride never drove the camera rumble (peak %.2f)" % peak_rumble)
		expect(ride_ms > 3000 and ride_ms < 12000,
			"lift ride took %d ms, outside its authored window" % ride_ms)
		expect(game.player._rumble < 0.35,
			"lift ride left the camera shaking after deceleration")
		# The ride coroutine sets ride_done before its final indicator write has
		# necessarily been processed, so sampling the label in the same frame is a
		# race. Under load it reads the still-descending '▼' and fails a contract
		# that actually holds. One frame settles it.
		await process_frame
		var ride_display: Label3D = ride_rig["display"]
		expect(ride_display.text.contains("02"),
			"ride indicator did not land on the floor below, got '%s'" \
				% ride_display.text)
	ride_target.queue_free()
	game.player.set_rumble(0.0)
	await process_frame

	# The needle degrades with depth: exact doorways early, a bearing in the
	# middle, held readings late, nothing at the bottom.
	expect(DescentHUD.FLOOR_GUIDE.size() == DescentRun.ORDER.size(),
		"guidance table does not cover every floor")
	expect(DescentHUD.FLOOR_GUIDE[0] == DescentHUD.Guide.EXACT,
		"first floor does not name real doorways")
	expect(DescentHUD.FLOOR_GUIDE[DescentRun.ORDER.size() - 1] \
		== DescentHUD.Guide.NONE,
		"last floor still hands out route guidance")
	if is_instance_valid(game._descent_hud):
		game.run.blackout = true
		game._descent_hud._process(0.016)
		expect(not game._descent_hud._needle.visible,
			"route needle survived a blackout")
		game.run.blackout = false
		game._descent_hud._process(0.016)

	# The real async lift callback must rebuild the next floor at the origin,
	# keep the same run and advance in the authored order.
	await game._on_descent_lift()
	expect(game.run.floor_idx == 1, "lift did not advance run floor")
	expect(game.active_level == DescentRun.ORDER[1],
		"lift did not reach the mall")
	expect(game.cm.descent and game.cm.descent_floor_idx == 1,
		"new floor lost Descent chunk configuration")
	expect(not game._switching and game._fade.color.a <= 0.001,
		"floor transition returned before its fade completed")
	expect(game.run.threat() >= DescentRun.FLOOR_PRESSURE[1],
		"second floor did not gain its authored pressure")
	var next_arrival: Dictionary = game._descent_arrival(game.active_level)
	expect(game.player.global_position.distance_to(
		next_arrival["position"]) < 1.0,
		"Descent floor did not arrive inside its car")
	expect(game.descent_route.origin_wall < 0 \
		or game.cm.chunk_at(game.descent_route.origin) != null,
		"new floor did not stream in its arrival room")
	expect(not game.run.lift_called and not game.run.lift_open \
		and not game.run.arrival_used,
		"new floor inherited the previous floor's lift state")
	expect(game.descent_route.min_dist > DescentRoute.MIN_DIST_FIRST,
		"second floor did not lengthen its objective route")

	# Rule episodes: one continuous stop counts once, while attention increases.
	game.run.arrival_grace = 0.0
	game.player.velocity = Vector3.ZERO
	var prior_violations: int = game.run.violations
	var prior_attention: float = game.run.attention
	for i in 7:
		game.run._physics_process(1.0)
	expect(game.run.violations == prior_violations + 1,
		"continuous stop did not count as exactly one episode")
	expect(game.run.attention > prior_attention,
		"stop episode did not raise attention")
	expect(game._event_hint.text == "RULE BROKEN — KEEP MOVING",
		"stop violation did not identify the broken rule")

	# Confirming the same dialog cleanly destroys Descent state and rebuilds
	# the casino title world. --nologo suppresses only the visual title layer.
	game.player.set_flashlight(true)
	game._show_return_prompt()
	await game._confirm_return_to_title()
	expect(not game.descent and game.run == null,
		"confirmed return left Descent state alive")
	expect(game.active_level == 0 and not game.player.flashlight.visible,
		"confirmed return did not restore the unlit casino title world")
	expect(game._figures.suspended,
		"title world left haunt timers active behind its rule card")

	print("descent runtime audit: seed=%d arrive=%s/%d target=%s distance=%d" % [
		SEED, route.origin, route.origin_wall, route.target,
		route.graph_distance])
	await teardown_game(game)
	finish("arrival car, HUD guidance, lift wait, pressure, rules and transition hold")
