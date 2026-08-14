extends "res://tools/lib/audit_base.gd"
## Reproduces the reported airport run: the exact seed/path must admit a safe
## natural blackout even while a hostile encounter owns the pacing director,
## and baggage-number labels must never outlive their physical totems.
## Run: godot --headless --path . --script tools/audit_airport_runtime.gd \
##        -- --mode=descent --descent-floor=4 --nologo

const REPORTED_SEED := 1641596671


func run() -> void:
	var game := await boot_game(REPORTED_SEED)
	expect(game.descent and game.run != null,
		"reported run did not boot in Descent")
	expect(game.active_level == 4 and game.run.floor_idx == 3,
		"reported run did not boot directly into the airport")
	if game.run == null or game.descent_route == null:
		await teardown_game(game)
		finish()
		return

	# Own the clock explicitly. Streaming is warmed synchronously at each route
	# probe so candidate safety sees the same resident neighbourhood as play.
	game.run.set_physics_process(false)
	game.cm.set_process(false)
	game._director.set_physics_process(false)
	game.run.arrival_grace = 0.0
	game.run.suspended = false
	game._director.set_scripted_hold(false)
	game.run.visited.clear()
	var path: Array[Vector2i] = game.descent_route.path_from_origin()
	var baggage_roots := {}
	for route_cell in path:
		if WorldGen.cell_style(game._level_seed(4), route_cell, 4) \
				== WorldGen.AIR_BAGGAGE:
			baggage_roots[WorldGen.room_id(
				game._level_seed(4), route_cell)] = true
	var blackout_cell := Vector2i(1 << 30, 1 << 30)
	var pure_choices := 0
	var safe_choices := 0
	for i in path.size():
		var at := path[i]
		game.cm.warm_up(at)
		game.player.teleport(Vector3(
			(float(at.x) + 0.5) * WorldGen.CELL_SIZE,
			game.player.global_position.y,
			(float(at.y) + 0.5) * WorldGen.CELL_SIZE))
		game.run._cell = at
		game.run._pending_cell = at
		game.run.visited[at] = true
		if i < DescentRun.FIRST_BLACKOUT_PROGRESS_CELLS:
			continue
		# The third selector pass is deliberately free of camera preference. It
		# must skip any delta whose expanded rebuild room contains the player and
		# choose another safe precomputed state instead of retrying it forever.
		game.run._blackout_visibility_retries = 2
		game.run._blackout_due = 0.0
		game._director.set_hostile_count(3, false)
		var pure: TopologyDelta = game.descent_route.topology.find_transition(
			game.descent_route, at, game.run.visited, false)
		if pure != null:
			pure_choices += 1
		var safe: TopologyDelta = game.descent_route.topology.find_transition(
			game.descent_route, at, game.run.visited, false, Callable(),
			game.run.blackout_mutation_validator)
		if safe != null:
			safe_choices += 1
		game.run._begin_blackout()
		if game.run.blackout:
			blackout_cell = at
			break
	expect(game.run.blackout,
		"reported airport path admitted no safe natural blackout")
	expect(blackout_cell.x != (1 << 30),
		"airport blackout did not identify a safe route cell")
	if game.run.blackout:
		game.cm.set_process(true)
		await await_until(func(): return game.cm._staged_cells.is_empty(), 5000)
		expect(game.descent_route.topology.current_state_id() != 0,
			"airport blackout began but its safe reality did not commit")
		game.run._end_blackout()

	var supported_numbers := 0
	for root_value in baggage_roots:
		var root := root_value as Vector2i
		if game.cm.chunk_at(root) == null:
			game.cm._build(root)
		var chunk: Chunk = game.cm.chunk_at(root)
		if chunk == null:
			continue
		for label_node in chunk.find_children(
				"BaggageCarouselNumber", "Label3D", true, false):
			var label := label_node as Label3D
			var owner := label.get_parent() as Node3D
			var meshes := owner.find_children(
				"*", "MeshInstance3D", true, false) if owner != null else []
			expect(owner != null and bool(owner.get_meta(
				"airport_baggage_number_totem", false)) and meshes.size() >= 2,
				"reported baggage number survived without pole/backing")
			supported_numbers += 1
	expect(not baggage_roots.is_empty(),
		"reported airport path no longer exercises baggage claim")
	expect(supported_numbers > 0,
		"reported baggage route retained no complete numbered totem")

	print("airport runtime audit: blackout at %s, pure/safe choices=%d/%d, baggage rooms=%d, supported numbers=%d" % [
		blackout_cell, pure_choices, safe_choices, baggage_roots.size(),
		supported_numbers])
	await teardown_game(game)
	finish("reported airport path blacked out and retained supported claim signs")
