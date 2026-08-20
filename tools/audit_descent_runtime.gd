extends "res://tools/lib/audit_base.gd"
## Runtime contract for the opt-in mode boundary and the first complete floor
## transition. Invoke with Descent CLI flags so main follows its production
## startup path.
## Run: godot --headless --path . --script tools/audit_descent_runtime.gd \
##        -- --mode=descent --nologo

const SEED := 405195947


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


func run() -> void:
	var game := await boot_game(SEED)

	expect(game.descent, "Descent CLI mode was not selected")
	expect(game.run != null, "run state was not constructed")
	expect(game.active_level == DescentRun.FIXED_ORDER[0],
		"run did not start on the casino")
	expect(DescentRun.order_for(SEED) == DescentRun.FIXED_ORDER \
		and DescentRun.order_for(SEED + 1) == DescentRun.FIXED_ORDER,
		"Descent story order still varies with the seed")
	var cadence := DescentRun.new()
	cadence.world_seed = SEED
	cadence.floor_idx = 0
	get_root().add_child(cadence)
	cadence.prepare_floor()
	# Floor 1 breathes: the base window is scaled by the 1.9x depth easing
	# added 2026-08-19 (photo hunt lengthened floors; flat cadence returns
	# by floor 4).
	expect(cadence._blackout_due >= DescentRun.FIRST_BLACKOUT_MIN \
			and cadence._blackout_due <= DescentRun.FIRST_BLACKOUT_MAX * 1.9,
		"first blackout is outside its eased floor-opening window")
	expect(DescentRun.FIRST_BLACKOUT_PROGRESS_CELLS <= 5 \
			and DescentRun.FIRST_BLACKOUT_PROGRESS_SECONDS <= 16.0 \
			and DescentRun.FIRST_BLACKOUT_PROGRESS_DUE <= 2.0,
		"fast route progress no longer forces an early first blackout")
	cadence.floor_elapsed = DescentRun.FIRST_BLACKOUT_PROGRESS_SECONDS
	cadence._blackout_due = DescentRun.FIRST_BLACKOUT_MAX
	for i in DescentRun.FIRST_BLACKOUT_PROGRESS_CELLS:
		cadence.visited[Vector2i(i, 0)] = true
	cadence._accelerate_first_blackout_for_progress()
	expect(cadence._blackout_due <= DescentRun.FIRST_BLACKOUT_PROGRESS_DUE,
		"five-room route progress did not clamp the live first-blackout timer")
	cadence._blackouts_this_floor = 1
	cadence._schedule_blackout()
	expect(cadence._blackout_due >= DescentRun.REPEAT_BLACKOUT_MIN \
			and cadence._blackout_due <= DescentRun.REPEAT_BLACKOUT_MAX * 1.9,
		"repeat blackout is outside its eased window")
	# Depth easing must expire: floor 4+ runs the authored flat cadence.
	var deep := DescentRun.new()
	deep.world_seed = SEED
	deep.floor_idx = 4
	get_root().add_child(deep)
	deep.prepare_floor()
	expect(deep._blackout_due >= DescentRun.FIRST_BLACKOUT_MIN \
			and deep._blackout_due <= DescentRun.FIRST_BLACKOUT_MAX,
		"floor 5 first blackout should run the flat authored window")
	deep.queue_free()
	cadence.queue_free()
	expect(game.run.blackout_mutation_ranker.is_valid() \
			and game.run.blackout_mutation_fallback_ranker.is_valid(),
		"production run lacks strict/frustum blackout mutation rankers")
	var game_bus := AudioServer.get_bus_index(SoundBank.GAME_BUS)
	var hall_bus := AudioServer.get_bus_index(SoundBank.HALL_BUS)
	expect(game_bus >= 0 and hall_bus >= 0,
		"Game/Hall audio bus boundary was not constructed")
	if game_bus >= 0 and hall_bus >= 0:
		expect(AudioServer.get_bus_send(hall_bus) == SoundBank.GAME_BUS,
			"Hall no longer feeds the VCR-mutable Game bus")
		var was_muted := AudioServer.is_bus_mute(game_bus)
		AudioServer.set_bus_mute(game_bus, false)
		game._set_tape_audio_hold(true)
		expect(AudioServer.is_bus_mute(game_bus),
			"VCR watch did not mute the complete game mix")
		game._set_tape_audio_hold(false)
		expect(not AudioServer.is_bus_mute(game_bus),
			"VCR watch did not restore an initially audible game mix")
		AudioServer.set_bus_mute(game_bus, true)
		game._set_tape_audio_hold(true)
		game._set_tape_audio_hold(false)
		expect(AudioServer.is_bus_mute(game_bus),
			"VCR release overrode a pre-existing game mute")
		AudioServer.set_bus_mute(game_bus, was_muted)
	expect(game.player._walk_p.bus == SoundBank.GAME_BUS \
			and game.player._wade_p.bus == SoundBank.GAME_BUS \
			and game.ambience.bus == SoundBank.GAME_BUS \
			and game._music.bus == SoundBank.GAME_BUS,
		"a persistent background/movement source bypasses the Game bus")
	# Exercise entry selection against an isolated checkpoint file. The CLI run
	# itself keeps persistence disabled and never touches the player's save.
	var test_progress := DescentProgress.new(
		"user://audit_descent_runtime_progress.cfg")
	test_progress.clear_from_disk()
	test_progress.start_new(24681)
	test_progress.reach_floor(24681, 6)
	game._descent_progress = test_progress
	game._progress_enabled = true
	expect(game._apply_descent_entry(TitleScreen.DescentEntry.CONTINUE) == 6 \
		and game.world_seed == 24681,
		"Continue did not restore the deepest floor and saved seed")
	expect(game._apply_descent_entry(TitleScreen.DescentEntry.RESTART) == 0 \
		and test_progress.deepest_floor == 6 and game.world_seed == 24681,
		"Restart did not keep the building/deepest checkpoint")
	var old_checkpoint_seed := test_progress.run_seed
	expect(game._apply_descent_entry(TitleScreen.DescentEntry.NEW) == 0 \
		and test_progress.run_seed == old_checkpoint_seed,
		"New Descent replaced its checkpoint before the intro was viewed")
	game._commit_new_descent_checkpoint()
	expect(test_progress.run_seed == game.world_seed \
		and test_progress.run_seed != old_checkpoint_seed \
		and test_progress.deepest_floor == 0,
		"completed New Descent did not create a fresh floor-one checkpoint")
	test_progress.clear_from_disk()
	game._progress_enabled = false
	game.world_seed = SEED
	expect(game.player.allow_sprint,
		"sprint is disabled despite the Descent attention contract")
	expect(game.cm.descent and game.cm.descent_route == game.descent_route,
		"explicit route config did not reach ChunkManager")
	expect(ChunkManager.BUDGET == 1 \
		and ChunkManager.UNLOAD_R == ChunkManager.LOAD_R + 1,
		"streaming can stack chunk builds or retain an oversized end-zone ring")
	expect(game.descent_route.topology != null \
		and game.cm.descent_topology == game.descent_route.topology \
		and game.run.route == game.descent_route,
		"shared Descent topology did not reach run, route and ChunkManager")
	expect(not game.run.blackout_mutation_requested.get_connections().is_empty(),
		"blackout mutation signal is not wired to the live game")
	expect(game.descent_route.topology.is_planned() \
		and game.descent_route.topology.state_count() >= 3,
		"live floor did not generate alternate realities up front")
	expect(game._transitions.saved_position_count() == 0,
		"Descent unexpectedly owns Wander saved positions")
	expect(not game.player.flashlight.visible,
		"flashlight did not start switched off")
	expect(game._music_track_for(game.active_level) \
			== game.MUSIC_TRACKS[game.active_level],
		"early Descent did not preserve the floor soundtrack")
	var filter_before: bool = game._post_process.is_enabled()
	var video := InputEventKey.new()
	video.pressed = true
	video.physical_keycode = KEY_V
	game._unhandled_input(video)
	expect(game._post_process.is_enabled() != filter_before,
		"V did not toggle the video filter in Descent")
	game._unhandled_input(video)
	var starting_floor_idx: int = game.run.floor_idx
	game.run.floor_idx = DescentRun.FLOOR_COUNT - 2
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
		"Descent room-aware HUD was not constructed")
	if is_instance_valid(game._descent_hud):
		expect(game._descent_hud.route == game.descent_route,
			"HUD marker does not own the active route")
		game._descent_hud._process(0.016)
		expect(game._descent_hud._panel.visible,
			"HUD route marker is hidden during an active floor")

	var route: DescentRoute = game.descent_route
	var player_before_assistance: Vector3 = game.player.global_position
	test_progress.start_new(SEED)
	game._descent_progress = test_progress
	game._progress_enabled = true
	var assistance := _find_assistance_probe(route)
	expect(not assistance.is_empty(),
		"live route offered no representative assistance reality")
	if not assistance.is_empty():
		var assistance_from: Vector2i = assistance["from"]
		game.run.visited = assistance["visited"]
		game.run._cell = assistance_from
		game.cm.warm_up(assistance_from)
		var affected_cells: Array[Vector2i] = game._mutation_coordinator.rebuild_cells(
			assistance["proposal"])
		# A real player has streamed the radius-three neighbourhood before a
		# blackout. This focused probe teleports there, so explicitly resident
		# the affected rooms that ordinary movement would already have loaded.
		for at in affected_cells:
			if game.cm.chunk_at(at) == null:
				game.cm._build(at)
		_audit_visible_mutation_witness(game, assistance["proposal"])
		var occupied: Vector2i = affected_cells[0]
		game.player.global_position = Vector3(
			(float(occupied.x) + 0.5) * ChunkManager.CELL,
			Chunk.cell_floor_h(route.world_seed, occupied, route.theme),
			(float(occupied.y) + 0.5) * ChunkManager.CELL)
		expect(not game._can_commit_blackout_mutation(assistance["proposal"]),
			"mutation preflight allowed geometry around the player")
		game.player.global_position = Vector3(
			(float(assistance_from.x) + 0.5) * ChunkManager.CELL,
			Chunk.cell_floor_h(route.world_seed, assistance_from, route.theme),
			(float(assistance_from.y) + 0.5) * ChunkManager.CELL)
		expect(game._can_commit_blackout_mutation(assistance["proposal"]),
			"safe unoccupied mutation was rejected")
		var assistance_before := route.distance_from_target(assistance_from)
		var old_state := route.topology.current_state_id()
		var old_history := route.topology.state_history()
		# Exercise the explicit failure contract before the live staged commit:
		# once topology has moved, rollback must restore both identity and history.
		var rollback_probe := DescentMutationTransaction.new(
			assistance["proposal"], true, route, assistance_from,
			affected_cells)
		expect(route.topology.transition_to(
				(assistance["proposal"] as TopologyDelta).to_state),
			"transaction rollback fixture could not enter proposed state")
		route.refresh_topology()
		rollback_probe.rollback(route.topology, route, "audit rollback")
		expect(rollback_probe.phase \
				== DescentMutationTransaction.Phase.ROLLED_BACK \
			and route.topology.current_state_id() == old_state \
			and route.topology.state_history() == old_history,
			"mutation rollback did not restore exact topology state/history")
		game.run.suspended = true
		game.run.blackout = true
		game.cm.set_blackout(true)
		# Force the last fallible scene gate to reject after topology preparation.
		# Old nodes must remain installed and the transaction must compensate both
		# resolver history and runtime-object state before a real retry.
		var runtime_before_failure: Dictionary = \
			game.cm.runtime_state_snapshot().to_dictionary()
		game.cm.fail_next_staged_commit = true
		game._on_blackout_mutation(assistance["proposal"], true)
		expect(not game.cm._staged_cells.is_empty(),
			"forced-failure mutation never entered staging")
		await await_until(func():
			return game.cm._staged_cells.is_empty(), 5000)
		var failed_transaction: DescentMutationTransaction = \
			game._mutation_coordinator.last_transaction
		expect(failed_transaction != null and failed_transaction.phase \
				== DescentMutationTransaction.Phase.ROLLED_BACK \
			and route.topology.current_state_id() == old_state \
			and route.topology.state_history() == old_history \
			and game.cm.runtime_state_snapshot().to_dictionary() \
				== runtime_before_failure,
			"failed atomic scene commit did not restore exact world state")
		# The same proposal remains valid after compensation and may commit.
		game._on_blackout_mutation(assistance["proposal"], true)
		expect(route.topology.current_state_id() == old_state \
			and not game.cm._staged_cells.is_empty(),
			"blackout rebuilt every changed room synchronously")
		await await_until(func():
			return game.cm._staged_cells.is_empty(), 5000)
		game.cm.set_blackout(false)
		game.run.blackout = false
		game.run.suspended = false
		expect(route.topology.current_state_id() != old_state,
			"live assistance handler did not commit its generated reality")
		expect(game.cm._staged_cells.is_empty(),
			"committed mutation left an off-tree rebuild transaction pending")
		var committed_transaction: DescentMutationTransaction = \
			game._mutation_coordinator.last_transaction
		expect(committed_transaction != null \
			and committed_transaction.committed() \
			and committed_transaction.mutation != null \
			and not committed_transaction.mutation.id.is_empty(),
			"live commit did not produce a durable typed WorldMutation")
		for at in affected_cells:
			var rebuilt: Chunk = game.cm.chunk_at(at)
			if rebuilt != null:
				expect(rebuilt.descent_topology_state_override < 0,
					"installed mutation chunk stayed pinned to one reality")
		expect(route.distance_from_target(assistance_from) < assistance_before,
			"live assistance reality did not shorten the route to the lift")
		expect(int(test_progress.mutation_state_for_floor(
			game.run.floor_idx).get("state", -1)) \
			== route.topology.current_state_id(),
			"committed reality was not mirrored into the checkpoint")
		expect(test_progress.runtime_state_for_floor(
			game.run.floor_idx).to_dictionary() \
			== game.cm.runtime_state_snapshot().to_dictionary(),
			"committed runtime-object state was not mirrored into the checkpoint")
		expect(game._pending_mutation_reveal \
			and game._pending_mutation_reveal_at != Vector3.INF,
			"committed mutation did not preserve its exact reveal witness")
		var reveal_at: Vector3 = game._pending_mutation_reveal_at
		var reveal_descriptor: Dictionary = \
			game._pending_mutation_reveal_descriptor
		var installed_mesh: MeshInstance3D
		var reveal_nodes: Variant = reveal_descriptor.get("nodes", [])
		if reveal_nodes is Array:
			for value in reveal_nodes as Array:
				if is_instance_valid(value) and value is Node:
					installed_mesh = _first_mesh(value as Node)
					if installed_mesh != null:
						break
		var ghost: Variant = reveal_descriptor.get("ghost", null)
		var exact_edge := str(reveal_descriptor.get("kind", "")) == "door" \
			and reveal_descriptor.get("edge", {}) is Dictionary
		expect(installed_mesh != null \
			or (is_instance_valid(ghost) and ghost is Node3D) or exact_edge,
			"mutation reveal retained only a point, not exact altered geometry")
		game._on_descent_blackout(false)
		await process_frame
		var reveal_effects := get_nodes_in_group("mutation_reveal_effect")
		expect(reveal_effects.size() == 1,
			"power restoration did not create one mutation glow")
		if reveal_effects.size() == 1:
			var reveal_effect := reveal_effects[0] as Node3D
			expect(reveal_effect.global_position.distance_to(reveal_at) < 0.01,
				"mutation glow was not placed at the committed witness")
			if installed_mesh != null:
				expect(installed_mesh.material_overlay != null,
					"installed mutation geometry did not receive its outline")
	game.player.global_position = player_before_assistance
	test_progress.clear_from_disk()
	game._progress_enabled = false
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
		expect(DescentRun.lift_wait_for(DescentRun.FLOOR_COUNT - 2) \
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
		var seat_floor := Chunk.cell_floor_h(game._level_seed(game.active_level),
			route.origin, game.active_level)
		var seat: Dictionary = Chunk.car_interior_point(route.origin,
			route.origin_wall, seat_floor)
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
	var seed_order := DescentRun.order_for(SEED)
	for added_theme in [7, 8, 9, 10, 11]:
		var added_idx := seed_order.find(added_theme)
		expect(added_idx >= 0,
			"theme %d is missing from the seeded Descent order" % added_theme)
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

	var final_route := DescentRoute.build(game._level_seed(11), 11)
	var final_target := Chunk.new(game._level_seed(11), final_route.target, 11, {
		"descent": true,
		"target": true,
		"target_wall": final_route.target_wall,
		"final": true,
		"floor_idx": DescentRun.FLOOR_COUNT - 1,
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

	# Guidance remains exact on every floor and resolves the first real opening
	# out of the player's whole room, not an invisible internal cell seam.
	if is_instance_valid(game._descent_hud):
		game._descent_hud._process(0.016)
		expect(game._descent_hud._panel.visible,
			"room-aware route marker is hidden")
		var exit: Dictionary = game.descent_route.next_room_exit(
			game.descent_route.origin)
		expect(not exit.is_empty(), "arrival room has no route exit")

	# The real async lift callback must rebuild the next floor at the origin,
	# keep the same run and advance in the authored order.
	await game._on_descent_lift()
	expect(game.run.floor_idx == 1, "lift did not advance run floor")
	expect(game.active_level == DescentRun.order_for(game.world_seed)[1],
		"lift did not reach the authored second floor")
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
	expect(game.descent_route.min_dist > roundi(
			float(DescentRoute.MIN_DIST_FIRST)
			* float(DescentRoute.EARLY_SHORTEN[0])),
		"second floor did not lengthen its objective route")

	# The stop rule is retired: standing still under working lights is free.
	game.run.arrival_grace = 0.0
	game.player.velocity = Vector3.ZERO
	var prior_violations: int = game.run.violations
	for i in 7:
		game.run._physics_process(1.0)
	expect(game.run.violations == prior_violations,
		"standing still charged a violation despite the rule being retired")

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


func _find_assistance_probe(route: DescentRoute) -> Dictionary:
	var path_cells := {}
	for cell in route.path_from_origin():
		path_cells[cell] = true
	var all_visited := {}
	for key in route.scanned_cells():
		all_visited[key] = true
	for key in route.scanned_cells():
		var from: Vector2i = key
		if path_cells.has(from):
			continue
		if route.distance_from_target(from) < \
				DescentRoute.MERCY_MIN_SAVING + 2:
			continue
		var proposal := route.topology.find_transition(
			route, from, all_visited, true)
		if proposal != null and proposal.assistance:
			return {"from": from, "visited": all_visited,
				"proposal": proposal}
	return {}


## Live camera contract: a changed set-piece room can satisfy the witness gate
## without an architectural edge, the same point fails when it is behind the
## camera, and a ranker that rejects every proposal postpones the transition.
func _audit_visible_mutation_witness(game: Node,
		proposal: TopologyDelta) -> void:
	var room_probe: TopologyDelta
	var target := Vector3.INF
	for room in proposal.rooms:
		var chunk: Chunk = game.cm.chunk_at(room)
		if chunk == null:
			continue
		var target_variant: int = game.descent_route.topology \
			.furniture_variant_for_state(room, proposal.to_state)
		var points := chunk.furniture_witness_points_for_variant(target_variant)
		if points.is_empty():
			continue
		target = points[mini(1, points.size() - 1)]
		room_probe = TopologyDelta.new(proposal.from_state,
			proposal.to_state, [], [room], [room])
		break
	expect(room_probe != null and target != Vector3.INF,
		"generated mutation exposed no resident set-piece witness")
	if room_probe == null or target == Vector3.INF:
		return
	var cam: Camera3D = game.player.cam
	var saved := cam.global_transform
	var witnessed := {}
	for offset in [Vector3(2.2, 0.0, 0.0), Vector3(-2.2, 0.0, 0.0),
			Vector3(0.0, 0.0, 2.2), Vector3(0.0, 0.0, -2.2)]:
		cam.global_position = target + offset
		cam.look_at(target, Vector3.UP)
		witnessed = game._mutation_coordinator.visible_witness(room_probe)
		if not witnessed.is_empty():
			break
	expect(not witnessed.is_empty() \
			and str(witnessed.get("kind", "")) == "furniture" \
			and game._mutation_coordinator.visibility_rank(room_probe) >= 0.0,
		"visible changed room did not provide a set-piece fallback witness")
	if not witnessed.is_empty():
		var away := cam.global_position * 2.0 - target
		cam.look_at(away, Vector3.UP)
		expect(game._mutation_coordinator.visible_witness(room_probe).is_empty(),
			"set-piece behind the camera still satisfied the witness gate")
	cam.global_transform = saved
