extends SceneTree
## Observe the real source encounter clock after the visit returns a reward.
var game: Node3D
var spawned := 0

func _init() -> void:
	call_deferred("run_test")

func snapshot(second: int) -> void:
	var post: PostProcessController = game._post_process
	print("RETURN SNAPSHOT ", second, "s: passive=", game._figures.passive,
		" suspended=", game._figures.suspended, " directed=", game._figures.directed_only,
		" timer=", game._figures._t, " grace=", game.run.arrival_grace,
		" run_physics=", game.run.is_physics_processing(), " spawned=", spawned,
		" director=", game._director.snapshot(), " tape_hold=", post._tape_hold,
		" mode=", post._mode, " corruption=", post._signal_corruption,
		" tracking=", post._found_footage_material.get_shader_parameter("tracking_error"),
		" slip=", post._found_footage_material.get_shader_parameter("vertical_slip"))

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(75.0, true).timeout.connect(func():
		push_error("RETURN AUDIT TIMEOUT")
		quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	game.run.resume_rules(0.0)
	game.run.arrival_grace = 0.0
	game.run._blackout_due = 300.0
	for anomaly in game._photo_director._live_doors.values():
		if anomaly.id == visit.seal.photo_id:
			game._photo_director.mark_documented(anomaly.id)
			anomaly.resolve()
			break
	var source_encounter_timer: float = game._figures._t
	game._figures.force_encounter(2.2)
	await visit.enter()
	assert(is_equal_approx(game._figures._t, source_encounter_timer), "visit reset the source encounter clock")
	assert(is_equal_approx(game._figures._forced_left, 2.2), "visit erased a pending source encounter")
	visit.set_process(false)
	visit.threats.suspended = true
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	game._photo_album_store.configure(game.world_seed, false)
	assert(game._photo_album_store.add_photo(image, {"anomaly_ids": [visit.bounty_id]}) == OK)
	visit.bounty.resolve()
	game._post_process.set_presence(1.0)
	await create_timer(0.3).timeout
	visit.elapsed = RealmExcursion.DURATION
	await visit.collapse()
	assert(game.player.emergency_flash_held)
	assert(is_equal_approx(game._figures._t, source_encounter_timer), "source clock advanced in the other realm")
	game.player.set_physics_process(false)
	game._figures.spawned.connect(func():
		spawned += 1
		for figure in game._figures.active_figures():
			figure.set_process(false)
			figure.set_physics_process(false))
	snapshot(0)
	for second in 22:
		await create_timer(1.0).timeout
		if second in [0, 5, 9, 21]:
			snapshot(second + 1)
		if second == 5:
			assert(not game._figures.passive and not game._director.scripted_hold, "return grace never released")
	assert(not game._figures.suspended and not game._figures.passive)
	assert(spawned > 0, "normal source encounters never resumed after return")
	assert(not game._post_process._tape_hold)
	print("REALM RETURN PASS: source encounter clock and pending encounter preserved; grace expires; ghosts spawn with the reward held")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
