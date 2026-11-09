extends "res://tools/lib/audit_base.gd"
## Native blackout onset and staged-commit timing for the reported Annex run.
## -- --test-mode --descent-floor=9 --seed=395572981 --no-video-effects
## Optional --time-streaming separately times the existing streamer callback.
## Normal measurements leave it scheduled by the engine. No forced draws or
## readbacks occur in either measurement, and campaign/settings are not saved.
const HOST = preload("res://scripts/ntscrt_video_host.gd")
var game: Node
var phases := {}
var output := "res://build/blackout-freeze/runtime-before.json"
var stream_samples := []
var measuring := false
var time_streaming := false

func next_frame() -> void:
	# Focus changes while inspecting the profile must not pause streaming or
	# leave the world-mutation transaction waiting indefinitely.
	if is_instance_valid(game) and is_instance_valid(game._pause_menu):
		game._close_settings()
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--time-streaming": time_streaming = true
	var host := HOST.new()
	root.add_child(host)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 395572981
	host.attach(game)
	expect(not game._progress_enabled,"profile must not write campaign saves")
	game.player.set_physics_process(false)
	game.run.suspended = true
	game.run.set_process(false)
	game.run.set_physics_process(false)
	game._figures.suspended = true
	game._director.set_scripted_hold(false)
	for key in ["_events","_architectural_events","_breathing","_native_doorways","_self_return_door"]:
		var controller: Node = game.get(key)
		if is_instance_valid(controller): controller.process_mode = Node.PROCESS_MODE_DISABLED
	var path: Array[Vector2i] = game.descent_route.path_from_origin()
	var at := path[4]
	game.player.position = Vector3(at.x*12+6,0.15,at.y*12+6)
	game.run._cell = at
	game.run.visited.clear()
	for index in 5: game.run.visited[path[index]] = true
	game.cm.stream_focus = Vector3.INF
	game.cm.warm_up(at)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 300: await next_frame()
	var deadline := Time.get_ticks_msec() + 15000
	while (not game.cm.queued.is_empty() or game.cm._pending_chunk != null) and Time.get_ticks_msec() < deadline:
		await next_frame()
	expect(game.cm.queued.is_empty() and game.cm._pending_chunk == null, "streaming did not settle")
	# Time the existing streamer once per normal process tick, independently
	# of the renderer's completion signal.
	game.cm.set_process(not time_streaming)
	process_frame.connect(func():
		if not time_streaming or not is_instance_valid(game): return
		var staged: int = game.cm._staged_cells.size()
		var t := Time.get_ticks_usec()
		game.cm._process(0.0)
		if measuring:
			stream_samples.append({"staged":staged,"ms":(Time.get_ticks_usec()-t)/1000.0}))
	game.run.blackout_mutation_ranker = Callable()
	game.run.blackout_mutation_fallback_ranker = Callable()
	game.run.blackout_changed.disconnect(game._on_descent_blackout)
	game.run.blackout_changed.connect(func(on: bool):
		var t := Time.get_ticks_usec()
		game._on_descent_blackout(on)
		phases["lights_off_ms" if on else "lights_on_ms"] = (Time.get_ticks_usec()-t)/1000.0)
	game.run.blackout_mutation_requested.disconnect(game._on_blackout_mutation)
	game.run.blackout_mutation_requested.connect(func(proposal: TopologyDelta, assistance: bool):
		var t := Time.get_ticks_usec()
		game._on_blackout_mutation(proposal,assistance)
		phases["stage_request_ms"] = (Time.get_ticks_usec()-t)/1000.0)
	var report := {"seed":game.world_seed,"theme":game.active_level,"cell":str(at),
		"renderer":DisplayServer.get_name(),"manual_stream_timing":time_streaming,
		"display":str(root.size),"samples":[],
		"quality_preset":game._settings.get_value("quality_preset"),
		"render_resolution":game._settings.get_value("render_resolution"),
		"method":"Normally scheduled frames; settled stationary player at path[4], ambient events suspended, camera-witness ranker relaxed, live mutation safety retained. Two actual blackout/atomic-commit/restore cycles; frames include synchronous onset. Timer suspended to repeat the same test duration."}
	for repeat in 2:
		phases = {}
		stream_samples = []
		measuring = true
		var frames := []
		var previous := Time.get_ticks_usec()
		var started := previous
		game.run._begin_blackout()
		phases["begin_ms"] = (Time.get_ticks_usec()-started)/1000.0
		if game.cm._staged_ready.is_valid():
			var ready: Callable = game.cm._staged_ready
			game.cm._staged_ready = func():
				var t := Time.get_ticks_usec()
				var result: bool = ready.call()
				phases["commit_topology_ms"] = (Time.get_ticks_usec()-t)/1000.0
				return result
			var committed: Callable = game.cm._staged_committed
			game.cm._staged_committed = func():
				var t := Time.get_ticks_usec()
				committed.call()
				phases["finish_commit_ms"] = (Time.get_ticks_usec()-t)/1000.0
		expect(game.run.blackout,"blackout did not start")
		for index in 120:
			await next_frame()
			var now := Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			previous = now
		var restored_frames := []
		previous = Time.get_ticks_usec()
		game.run._end_blackout()
		for i in 30:
			await next_frame()
			var now := Time.get_ticks_usec()
			restored_frames.append((now-previous)/1000.0)
			previous = now
		measuring = false
		var transaction: DescentMutationTransaction = game._mutation_coordinator.last_transaction
		expect(transaction != null and transaction.phase == DescentMutationTransaction.Phase.COMMITTED,
			"mutation did not commit: " + (transaction.failure_reason if transaction != null else "no transaction"))
		var record := {"repeat":repeat,"phases":phases.duplicate(),"frames_ms":frames,
			"restored_frames_ms":restored_frames,
			"stream_ticks":stream_samples.duplicate(),
			"resident_chunks":game.cm.chunks.size(),"state":game.descent_route.topology.current_state_id()}
		report.samples.append(record)
		print("BLACKOUT_RUNTIME repeat=%d state=%d chunks=%d max_ms=%.3f restored_max_ms=%.3f phases=%s" % [
			repeat,record.state,record.resident_chunks,frames.max(),restored_frames.max(),JSON.stringify(phases)])
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await teardown_game(game)
	finish("blackout runtime profile")
