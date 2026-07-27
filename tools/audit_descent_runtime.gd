extends SceneTree
## Runtime contract for the opt-in mode boundary and the first complete floor
## transition. Invoke with Descent CLI flags so main follows its production
## startup path.
## Run: godot --headless --path . --script tools/audit_descent_runtime.gd \
##        -- --mode=descent --nologo

const SEED := 405195947


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	game.world_seed = SEED
	get_root().add_child(game)
	await physics_frame
	await process_frame

	_expect(game.descent, "Descent CLI mode was not selected", failures)
	_expect(game.run != null, "run state was not constructed", failures)
	_expect(game.active_level == DescentRun.ORDER[0],
		"run did not start on the casino", failures)
	_expect(not game.player.allow_sprint, "sprint remains enabled", failures)
	_expect(game.cm.descent and game.cm.descent_route == game.descent_route,
		"explicit route config did not reach ChunkManager", failures)
	_expect(game._saved_pos.is_empty(),
		"Descent unexpectedly owns Wander saved positions", failures)
	_expect(not game.player.flashlight.visible,
		"flashlight did not start switched off", failures)
	_expect(game._music_track_for(game.active_level) \
			== game.MUSIC_TRACKS[game.active_level],
		"early Descent did not preserve the floor soundtrack", failures)
	var starting_floor_idx: int = game.run.floor_idx
	game.run.floor_idx = DescentRun.ORDER.size() - 2
	_expect(game._music_track_for(game.active_level) == game.DESCENT_LATE_TRACK,
		"late Descent escalation track was not selected", failures)
	game.run.floor_idx = starting_floor_idx
	game.player.set_flashlight(true)
	_expect(game.player.flashlight.visible,
		"flashlight could not be enabled in Descent", failures)
	game.player.set_flashlight(false)
	_expect(not game.player.flashlight.visible,
		"flashlight could not be switched off", failures)
	for ch in game.cm.chunks.values():
		_expect((ch as Chunk).portal_dest < 0,
			"Descent chunk built a Wander portal", failures)
		_expect((ch as Chunk).find_children(
			"DescentArrow", "", true, false).is_empty(),
			"Descent still placed an in-world route arrow", failures)
	_expect(is_instance_valid(game._descent_hud),
		"Descent HUD route needle was not constructed", failures)
	if is_instance_valid(game._descent_hud):
		_expect(game._descent_hud.route == game.descent_route,
			"HUD route needle does not own the active route", failures)
		game._descent_hud._process(0.016)
		_expect(game._descent_hud._needle.visible,
			"HUD route needle is hidden during an active floor", failures)

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
	_expect(target.portal_dest < 0, "objective room built a portal", failures)
	_expect(target.has_node("DescentElevator"),
		"target did not build the Descent elevator", failures)
	_expect(target.find_children("*", "Area3D", true, false).size() >= 2,
		"objective car is missing call/commit interaction areas", failures)
	var lift_call: Interactable
	for node in target.find_children("*", "Interactable", true, false):
		var candidate := node as Interactable
		if candidate.prompt_text == "E — call lift":
			lift_call = candidate
			break
	_expect(lift_call != null,
		"objective lift has no usable call button", failures)
	if lift_call != null:
		# Calling the lift must NOT open it. The car is somewhere else and the
		# wait is the floor's most exposed stretch; the run owns its clock so it
		# survives the target room streaming out during it.
		lift_call.interact(game.player)
		await create_timer(0.35).timeout
		_expect(not lift_call.enabled,
			"call button did not lock after being pressed", failures)
		_expect(not target.get_node("DescentElevator").has_meta("opened"),
			"lift opened immediately instead of making the player wait", failures)
		_expect(game.run.lift_called and game.run.lift_wait_left > 1.0,
			"call did not start the run-owned lift wait", failures)
		_expect(game.run.lift_wait_left <= DescentRun.LIFT_WAIT_LAST + 0.01,
			"lift wait exceeded its authored range", failures)
		_expect(DescentRun.lift_wait_for(DescentRun.ORDER.size() - 2) \
				> DescentRun.lift_wait_for(0),
			"lift wait does not lengthen with depth", failures)
		# Only the arrival, not the press, opens the doors.
		target.open_descent_lift()
		await create_timer(0.1).timeout
		_expect(target.get_node("DescentElevator").has_meta("opened"),
			"arrival did not open the objective car", failures)
	target.queue_free()
	await process_frame

	# The arrival car: the player rides in, so a floor's origin room owns a
	# sealed car and the player starts standing inside it facing shut doors.
	_expect(route.origin_wall >= 0,
		"floor has no wall-backed arrival room", failures)
	_expect(route.origin != route.target,
		"arrival room and objective are the same cell", failures)
	if route.origin_wall >= 0:
		var arrival_chunk: Chunk = game.cm.chunk_at(route.origin)
		_expect(arrival_chunk != null,
			"arrival room was not streamed in at startup", failures)
		if arrival_chunk != null:
			_expect(arrival_chunk.has_node("DescentArrival"),
				"arrival room did not build the car the player rides in on",
				failures)
			_expect(arrival_chunk.has_descent_arrival(),
				"arrival car is not in a usable state at floor start", failures)
		var seat: Dictionary = Chunk.car_interior_point(route.origin,
			route.origin_wall)
		_expect(game.player.global_position.distance_to(
			seat["position"]) < 1.0,
			"player did not start inside the arrival car", failures)
		_expect(ArrivalSafety.is_clear(game.get_world_3d(), seat["position"],
			[game.player.get_rid()]),
			"arrival car interior is not clear for the player capsule", failures)

	# The two post-launch themes must satisfy the complete runtime objective
	# contract, not merely appear in ORDER or pass the topology-only route
	# audit. Construct their authored targets exactly as ChunkManager does and
	# require the usable lift shell, interaction areas and portal suppression.
	for added_theme in [7, 8]:
		var added_idx := DescentRun.ORDER.find(added_theme)
		_expect(added_idx >= 0,
			"theme %d is missing from DescentRun.ORDER" % added_theme, failures)
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
		_expect(added_target.portal_dest < 0,
			"theme %d objective built a Wander portal" % added_theme, failures)
		_expect(added_target.has_node("DescentElevator"),
			"theme %d objective did not build a Descent elevator" % added_theme,
			failures)
		_expect(added_target.find_children(
			"*", "Area3D", true, false).size() >= 2,
			"theme %d objective is missing lift interaction areas" % added_theme,
			failures)
		var added_call := false
		for added_node in added_target.find_children(
				"*", "Interactable", true, false):
			if (added_node as Interactable).prompt_text == "E — call lift":
				added_call = true
				break
		_expect(added_call,
			"theme %d objective has no usable lift call" % added_theme, failures)
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
	_expect(final_target.has_node("DescentExit"),
		"final floor did not build the OUT passage", failures)
	_expect(final_target.find_children("*", "Area3D", true, false).size() >= 2,
		"OUT passage is missing approach/finish triggers", failures)
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
		_expect(not dead_light.visible and dead_light.light_energy == 0.0,
			"dead-cell anomaly revived after blackout", failures)
	dead_chunk.free()

	# Blackout restoration must preserve both a working and intentionally dead
	# fixture instead of turning every light on.
	var lights: Array[Node] = game.level_root.find_children(
		"*", "Light3D", true, false)
	_expect(not lights.is_empty(), "floor has no lights to audit", failures)
	if not lights.is_empty():
		var light := lights[0] as Light3D
		light.visible = false
		light.light_energy = 0.217
		game.cm.set_blackout(true)
		_expect(not light.visible, "blackout left a fixture visible", failures)
		game.cm.set_blackout(false)
		_expect(not light.visible and is_equal_approx(light.light_energy, 0.217),
			"blackout did not restore exact fixture state", failures)

	# Number-key/floor API is a Wander operation and must be inert here.
	var before: int = game.active_level
	game._switch_level(1)
	_expect(game.active_level == before and not game._switching,
		"Descent accepted a Wander floor switch", failures)

	# Q confirmation suspends every system that could punish the player while
	# deciding. Cancelling resumes the same run with a short reaction grace.
	game._show_return_prompt()
	_expect(is_instance_valid(game._return_prompt),
		"return-to-title confirmation was not constructed", failures)
	_expect(game.run.suspended and game._figures.suspended,
		"return confirmation did not suspend Descent threats", failures)
	_expect(game._return_prompt.descent,
		"return confirmation did not receive Descent-specific context", failures)
	game._cancel_return_to_title()
	_expect(not game.run.suspended and game.run.arrival_grace >= 1.0,
		"cancelling return did not safely resume Descent", failures)
	_expect(game._return_prompt == null,
		"cancelled return confirmation remained in the tree", failures)

	# The ride is the one part of a run that happens to the player rather than
	# being done by them, and it is a chain of awaits — if it ever fails to
	# return, the run is unrecoverable. Exercise the real sequence on a detached
	# car: `_descent_ride` drives presentation only, so it cannot advance a floor
	# on its own the way `_descent_commit` does.
	var ride_target := Chunk.new(game._level_seed(game.active_level),
		route.target, game.active_level, target_config)
	get_root().add_child(ride_target)
	var ride_rig: Dictionary = ride_target._descent_lift_rig
	_expect(not ride_rig.is_empty(), "objective car exposed no rig", failures)
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
		_expect(ride_done[0],
			"lift ride never completed — a run would be stuck in the car",
			failures)
		_expect(peak_rumble > 0.5,
			"lift ride never drove the camera rumble (peak %.2f)" % peak_rumble,
			failures)
		_expect(ride_ms > 3000 and ride_ms < 12000,
			"lift ride took %d ms, outside its authored window" % ride_ms,
			failures)
		_expect(game.player._rumble < 0.35,
			"lift ride left the camera shaking after deceleration", failures)
		var ride_display: Label3D = ride_rig["display"]
		_expect(ride_display.text.contains("02"),
			"ride indicator did not land on the floor below, got '%s'" \
				% ride_display.text, failures)
	ride_target.queue_free()
	game.player.set_rumble(0.0)
	await process_frame

	# The needle degrades with depth: exact doorways early, a bearing in the
	# middle, held readings late, nothing at the bottom.
	_expect(DescentHUD.FLOOR_GUIDE.size() == DescentRun.ORDER.size(),
		"guidance table does not cover every floor", failures)
	_expect(DescentHUD.FLOOR_GUIDE[0] == DescentHUD.Guide.EXACT,
		"first floor does not name real doorways", failures)
	_expect(DescentHUD.FLOOR_GUIDE[DescentRun.ORDER.size() - 1] \
		== DescentHUD.Guide.NONE,
		"last floor still hands out route guidance", failures)
	if is_instance_valid(game._descent_hud):
		game.run.blackout = true
		game._descent_hud._process(0.016)
		_expect(not game._descent_hud._needle.visible,
			"route needle survived a blackout", failures)
		game.run.blackout = false
		game._descent_hud._process(0.016)

	# The real async lift callback must rebuild the next floor at the origin,
	# keep the same run and advance in the authored order.
	await game._on_descent_lift()
	_expect(game.run.floor_idx == 1, "lift did not advance run floor", failures)
	_expect(game.active_level == DescentRun.ORDER[1],
		"lift did not reach the mall", failures)
	_expect(game.cm.descent and game.cm.descent_floor_idx == 1,
		"new floor lost Descent chunk configuration", failures)
	_expect(not game._switching and game._fade.color.a <= 0.001,
		"floor transition returned before its fade completed", failures)
	_expect(game.run.threat() >= DescentRun.FLOOR_PRESSURE[1],
		"second floor did not gain its authored pressure", failures)
	var next_arrival: Dictionary = game._descent_arrival(game.active_level)
	_expect(game.player.global_position.distance_to(
		next_arrival["position"]) < 1.0,
		"Descent floor did not arrive inside its car", failures)
	_expect(game.descent_route.origin_wall < 0 \
		or game.cm.chunk_at(game.descent_route.origin) != null,
		"new floor did not stream in its arrival room", failures)
	_expect(not game.run.lift_called and not game.run.lift_open \
		and not game.run.arrival_used,
		"new floor inherited the previous floor's lift state", failures)
	_expect(game.descent_route.min_dist > DescentRoute.MIN_DIST_FIRST,
		"second floor did not lengthen its objective route", failures)

	# Rule episodes: one continuous stop counts once, while attention increases.
	game.run.arrival_grace = 0.0
	game.player.velocity = Vector3.ZERO
	var prior_violations: int = game.run.violations
	var prior_attention: float = game.run.attention
	for i in 7:
		game.run._physics_process(1.0)
	_expect(game.run.violations == prior_violations + 1,
		"continuous stop did not count as exactly one episode", failures)
	_expect(game.run.attention > prior_attention,
		"stop episode did not raise attention", failures)
	_expect(game._event_hint.text == "RULE BROKEN — KEEP MOVING",
		"stop violation did not identify the broken rule", failures)

	# Confirming the same dialog cleanly destroys Descent state and rebuilds
	# the casino title world. --nologo suppresses only the visual title layer.
	game.player.set_flashlight(true)
	game._show_return_prompt()
	await game._confirm_return_to_title()
	_expect(not game.descent and game.run == null,
		"confirmed return left Descent state alive", failures)
	_expect(game.active_level == 0 and not game.player.flashlight.visible,
		"confirmed return did not restore the unlit casino title world", failures)
	_expect(game._figures.suspended,
		"title world left haunt timers active behind its rule card", failures)

	print("descent runtime audit: seed=%d arrive=%s/%d target=%s distance=%d" % [
		SEED, route.origin, route.origin_wall, route.target,
		route.graph_distance])
	if failures.is_empty():
		print("  PASS — arrival car, HUD guidance, lift wait, pressure, rules and transition hold")
	else:
		for failure in failures:
			print("FAIL ", failure)
	_stop_audio(game)
	game.free()
	Chunk.finish_prop_preloads()
	SoundBank._c.clear()
	Sfx._c.clear()
	await process_frame
	await physics_frame
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String,
		failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
