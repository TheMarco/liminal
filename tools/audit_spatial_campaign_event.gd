extends "res://tools/lib/audit_base.gd"
## Full campaign smoke gate for Package 2's live spatial event. This boots Main,
## uses the player's actual camera and physics raycasts, and waits for Main's
## five-second polling path to admit the event; it never feeds tracker samples
## or requests the transaction directly.
##
## Run with:
##   godot --headless --path . --script tools/audit_spatial_campaign_event.gd \
##     -- --mode=descent --nologo --seed=900393 --descent-floor=3

const SEED := 900393
const FLOOR_NUMBER := 3
const EVENT_TIMEOUT_MS := 30000


func run() -> void:
	var game := await boot_game(SEED)
	expect(game.descent, "Descent CLI mode was not selected")
	expect(game.run != null and game.descent_route != null,
		"campaign run or route was not constructed")
	if game.run == null or game.descent_route == null:
		await teardown_game(game)
		finish()
		return
	expect(game.run.floor_idx == FLOOR_NUMBER - 1,
		"campaign did not start on requested Office floor 3")
	var director: SpatialMutationDirector = game.get("_spatial_director")
	expect(director != null, "live spatial director was not installed")
	if director == null:
		await teardown_game(game)
		finish()
		return
	expect(not game.descent_route.topology.site_specs.is_empty(),
		"campaign seed did not admit a spatial site")
	if game.descent_route.topology.site_specs.is_empty():
		await teardown_game(game)
		finish()
		return

	var spec: SpatialSiteSpec = game.descent_route.topology.site_specs[0]
	var frame := SpatialSitePlanner.junction_frame(spec)
	var junction: Vector2i = frame["cell"]
	var dirs: Array = frame["dirs"]
	expect(dirs.size() == 2, "campaign site has no two-aperture frame")
	if dirs.size() != 2:
		await teardown_game(game)
		finish()
		return

	# Isolate a quiet admission window without changing the spatial tracker,
	# selector, plan, or transaction. These are ordinary valid campaign states;
	# unrelated ambient systems must not make this reachability gate flaky.
	game.run.arrival_grace = 0.0
	game.run.suspended = false
	game.run.set("_blackout_due", 1000.0)
	game._figures.directed_only = true
	game._figures.despawn()
	game._passers.suspended = true
	game._corner_apparitions.suspended = true
	game._director.reset_floor()
	game._director.enabled = true
	expect(game._spatial_mode_ready(),
		"quiet campaign state did not satisfy the spatial mode gate")

	# The center of the authored junction is normal walkable player space and
	# exposes all three landmarks from one coherent composition.
	var floor_h := Chunk.cell_floor_h(game.descent_route.world_seed, junction,
		game.active_level)
	var center := Vector3(
		(float(junction.x) + 0.5) * ChunkManager.CELL,
		floor_h + 0.05,
		(float(junction.y) + 0.5) * ChunkManager.CELL)
	game.player.teleport(center)
	game.cm.stream_focus = center
	game.cm.warm_up(junction)
	for _frame in 120:
		await physics_frame
		await process_frame

	# Give each real witness a sustained, unobstructed view through the player
	# camera. The tracker remains entirely live; only the player's pose changes.
	for feature_id in director.site_witness_ids(spec.id):
		var point: Vector3 = spec.witness_points[feature_id]["position"]
		var eye: Vector3 = game.player.global_position \
			+ Vector3(0.0, Player.CAM_H, 0.0)
		var delta := point - eye
		game.player.rotation.y = atan2(-delta.x, -delta.z)
		game.player.set("_pitch",
			-atan2(delta.y, Vector2(delta.x, delta.z).length()))
		for _frame in 140:
			await physics_frame
			await process_frame
		expect(director.tracker.witness_eligible(feature_id),
			"real campaign camera could not witness %s" % feature_id)
	# Schedule Main's normal polling path immediately after the live witness
	# window, so its eight-second witness history cannot age out first.
	game.set("_spatial_poll", 0.0)
	for _frame in 10:
		await physics_frame
		await process_frame
	var deadline := Time.get_ticks_msec() + 12000
	var started := not director.last_event.is_empty() \
		and str(director.last_event.get("site", "")) == spec.id
	while not started and Time.get_ticks_msec() < deadline:
		await process_frame
		started = not director.last_event.is_empty() \
			and str(director.last_event.get("site", "")) == spec.id
	expect(started, "Main polling never started the witnessed campaign event")

	deadline = Time.get_ticks_msec() + EVENT_TIMEOUT_MS
	var finished := not director.is_active() \
		and str(director.last_event.get("outcome", "")) == "completed_b_open"
	while not finished and Time.get_ticks_msec() < deadline:
		await process_frame
		finished = not director.is_active() \
			and str(director.last_event.get("outcome", "")) == "completed_b_open"
	expect(finished, "campaign event did not finish completed_b_open")
	expect(str(director.last_event.get("outcome", "")) == "completed_b_open",
		"campaign event outcome was %s" % director.last_event.get("outcome", ""))
	expect(bool(director.last_event.get("committed", false)),
		"campaign event did not report a durable committed state")
	expect(str(director.last_event.get("settled_phase", "")) == "b_open",
		"campaign event did not settle at b_open")
	var state := director.site_state(spec.id)
	expect(state != null and state.stable_phase == "b_open" and state.completed,
		"live campaign site state was not durably committed as completed b_open")

	await teardown_game(game)
	# `finish()` quits immediately; release local RefCounted handles first.
	state = null
	spec = null
	director = null
	game = null
	await process_frame
	finish("live Main campaign event completed A-to-B on Office floor 3")
