extends SceneTree
## Real lifecycle, real generated physics, real timer; isolate enemy motion.
var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("REALM AUDIT FAIL: " + message)
		quit(1)
		assert(value, message)

func run_test() -> void:
	Engine.max_fps = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	check(visit != null, "run with --realm-visit --seed=21")
	var deadline := Time.get_ticks_msec() + 30000
	while visit.phase == RealmExcursion.Phase.PREPARING and Time.get_ticks_msec() < deadline:
		await process_frame
	check(visit.phase == RealmExcursion.Phase.WAITING, "preview ready")
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	var source_root: Node3D = game.level_root
	var source_cm: ChunkManager = game.cm
	var source_route: DescentRoute = game.descent_route
	var source_run: DescentRun = game.run
	var floor_idx: int = game.run.floor_idx
	var target: Vector2i = source_route.target
	var source_theme: int = game.active_level
	var id: String = visit.seal.photo_id
	var anomaly: PhotoAnomaly
	for candidate in game._photo_director._live_doors.values():
		if candidate.id == id:
			anomaly = candidate
			break
	check(anomaly != null, "entrance is a real photo subject")
	check(anomaly.album_description().contains("mall"), "entrance caption names foreign room")
	game._photo_director.mark_documented(id)
	anomaly.resolve()
	check(visit.seal.opened, "photo opened source aperture")
	var known: Array = game._photo_director.documented_ids().duplicate()
	var tape: bool = source_run.tape_watched
	var lift: bool = source_run.lift_called
	# Exercise the actual threshold detector, not just the controller entry API.
	visit._previous_side = -0.1
	game.player.teleport(visit.source_centre + visit.source_forward * 0.2 + Vector3.UP * 0.15)
	visit._process(0.0)
	deadline = Time.get_ticks_msec() + 10000
	while visit.phase == RealmExcursion.Phase.ENTERING and Time.get_ticks_msec() < deadline:
		await process_frame
	check(visit.phase == RealmExcursion.Phase.VISITING, "entered")
	check(game.run == source_run and game.cm == source_cm and game.descent_route == source_route, "source identity retained")
	check(not source_root.is_inside_tree(), "source collision detached")
	check(game.run.suspended and not game.run.is_physics_processing(), "normal blackout clock frozen")
	check(game.player.level_theme == 7 and game.active_level == source_theme, "only player environment changes")
	check(game._photo_camera.director.floor_idx == floor_idx + 1, "photos correctly attributed to destination")
	check(ArrivalSafety.is_clear(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]), "destination capsule clear")
	check(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]), "destination has floor")
	var elapsed_before: float = visit.elapsed
	paused = true
	await create_timer(0.25, true).timeout
	check(is_equal_approx(visit.elapsed, elapsed_before), "pause freezes visit timer")
	paused = false
	game._show_return_prompt()
	elapsed_before = visit.elapsed
	await create_timer(0.25).timeout
	check(is_equal_approx(visit.elapsed, elapsed_before), "quit prompt freezes visit timer")
	check(visit.threats.process_mode == Node.PROCESS_MODE_DISABLED, "quit prompt freezes threats")
	game._cancel_return_to_title()
	check(source_run.suspended and not source_run.is_physics_processing(), "cancel quit keeps source rules suspended")
	if OS.get_cmdline_user_args().has("--realm-test-quit"):
		game._show_return_prompt()
		await game._confirm_return_to_title()
		check(not game.descent and is_instance_valid(game._title), "quit reaches title")
		check(not is_instance_valid(visit.threats) and not is_instance_valid(visit.pocket), "quit removes excursion world and attackers")
		print("REALM AUDIT PASS: quit during visit")
		game.free()
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		quit()
		return
	var caught := OS.get_cmdline_user_args().has("--realm-test-caught")
	if caught:
		visit.threats.reached_player.emit()
	else:
		# Preserve spawn/floor/line-of-sight behavior, but prevent an unmoving
		# automated player dying. Separate caught run exercises terminal contact.
		visit.threats.spawned.connect(func():
			for figure in visit.threats.active_figures():
				figure.set_process(false)
				figure.set_physics_process(false))
	deadline = Time.get_ticks_msec() + 45000
	while visit.phase != RealmExcursion.Phase.SPENT and Time.get_ticks_msec() < deadline:
		await process_frame
	check(visit.phase == RealmExcursion.Phase.SPENT, "automatic return completed")
	await create_timer(0.8).timeout
	check(game.level_root == source_root and source_root.is_inside_tree(), "same source scene restored")
	check(game.run.floor_idx == floor_idx and game.active_level == source_theme, "no floor progression")
	check(source_route.target == target and source_run.tape_watched == tape and source_run.lift_called == lift, "objectives intact")
	check(game._photo_director.documented_ids() == known, "source evidence unchanged")
	check(not visit.window.visible, "entry is now ordinary room")
	check(not is_instance_valid(visit.threats), "no visitors follow player home")
	if not caught:
		check(visit.elapsed >= 30.0 and visit.elapsed < 31.0, "thirty-second duration")
		check(visit.total_spawned >= 2, "encounter actually escalated")
		check(game.player.global_position.distance_to(visit.return_position) < 0.2, "returned in front of entrance")
		check(not source_run.ended, "survival keeps run alive")
		check(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]), "return has support")
	else:
		check(source_run.ended, "caught follows normal death rule after source restoration")
	check(not game._progress_enabled, "prototype never writes normal checkpoint")
	print("REALM AUDIT PASS: caught=%s duration=%.2f spawns=%d" % [caught, visit.elapsed, visit.total_spawned])
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
