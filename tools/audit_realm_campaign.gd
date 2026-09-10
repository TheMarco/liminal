extends SceneTree
## Production path: no --realm-visit. Real source and destination collision.
var game: Node3D
func _init() -> void:
	call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("CAMPAIGN REALM FAIL: " + message)
		quit(1)
		assert(ok, message)
func run_test() -> void:
	Engine.max_fps = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	check(not game.opts.realm_visit, "must exercise normal production startup")
	check(game.descent, "run with --mode=descent --seed=21")
	var visit: RealmExcursion = game._realm_visit
	if game.run.is_last_floor():
		check(visit == null, "last floor has no onward realm")
		print("CAMPAIGN REALM PASS: final floor guarded")
		game.free()
		quit()
		return
	check(visit != null, "normal floor has controller")
	# Exercise real checkpoint I/O without touching the player's save.
	var save_path := "/tmp/realm-campaign-%d-%d.cfg" % [game.world_seed, game.run.floor_idx]
	game._descent_progress = DescentProgress.new(save_path)
	game._descent_progress.start_new(game.world_seed)
	game._progress_enabled = true
	game.run.set_physics_process(false)
	game.run.arrival_grace = 0.0
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	var record := game.descent_route.realm_door_hint as Dictionary
	var at: Vector2i = record.cell
	var other: Vector2i = at + WorldGen.DIRV[DescentTopology.edge_dir(record)]
	game.cm.stream_focus = visit.return_position
	for endpoint in [at, other]:
		for member in WorldGen.owning_room_members(game.cm.world_seed, endpoint, game.active_level):
			if not game.cm.chunks.has(member):
				game.cm._build(member)
	game.player.teleport(visit.return_position)
	var deadline := Time.get_ticks_msec() + 60000
	while (visit.phase == RealmExcursion.Phase.PREPARING or not is_instance_valid(visit.window)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(visit.phase == RealmExcursion.Phase.WAITING and is_instance_valid(visit.window), "resident realm preview ready")
	check(is_instance_valid(visit.bounty), "next realm has a reachable flash")
	check(ArrivalSafety.is_clear(visit.preview.find_world_3d(), visit.destination_position), "preview destination capsule clear")
	check(visit.bounty.visible_from_entry, "bounty is visible from entry")
	# The environmental signal starts on approach, even during arrival grace
	# or when looking away. Only an actual view grants the fresh-spawn hold.
	game.player.teleport(visit.return_position)
	game.player.rotation.y = visit.return_yaw + PI
	game.player.cam.rotation.y = game.player.rotation.y
	game.player.force_update_transform()
	game.player.cam.force_update_transform()
	visit._door_leak.finish()
	visit._door_leak.cooldown = 0.0
	visit._discovery_started = false
	game._figures._new_spawn_hold = 0.0
	game.run.arrival_grace = 4.0
	var pulses := visit._door_leak.pulses
	visit._process(0.05)
	check(visit._door_leak.visible and visit._door_leak.pulses == pulses + 1, "approach signal requires player to look first")
	check(not visit._discovery_started and game._figures._new_spawn_hold == 0.0, "unseen signal spent first-view grace")
	check(is_instance_valid(visit._entrance_hum) and not visit._entrance_hum.stream_paused, "nearby entrance has no directional cue")
	game.player.rotation.y = visit.return_yaw
	game.player.cam.rotation.y = game.player.rotation.y
	game.player.force_update_transform()
	game.player.cam.force_update_transform()
	visit._process(0.05)
	check(visit._door_leak.active and visit._door_leak.pulses == pulses + 1, "visible sealed wall has no glyph leak")
	check(game._figures._new_spawn_hold > 0.0, "first leak did not hold new arrivals")
	game.run.arrival_grace = 0.0
	game._photo_camera._raise(true)
	visit._process(0.05)
	check(not visit._door_leak.visible, "leak overlays the real lens doorway")
	game._photo_camera._lower()
	# Exercise actual streaming: leave the region, then let the same controller
	# bind a newly generated copy of its seal and anomaly.
	var old_seal_id := visit.seal.get_instance_id()
	game.player.teleport(visit.return_position + Vector3(120.0, 0, 120.0))
	game.cm.stream_focus = game.player.global_position
	await create_timer(0.8).timeout
	check(visit.phase == RealmExcursion.Phase.WAITING, "stream-out keeps visit available")
	check(visit._entrance_hum.stream_paused, "distant doorway hum stayed active")
	check(not visit._door_leak.visible, "wall leak followed player out of its room")
	check(not is_instance_valid(visit.seal) or not visit.seal.is_inside_tree(), "source seal streamed out")
	game.cm.stream_focus = visit.return_position
	game.player.teleport(visit.return_position)
	deadline = Time.get_ticks_msec() + 20000
	while (not is_instance_valid(visit.window) or not is_instance_valid(visit.seal)
			or not visit.seal.is_inside_tree()) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(is_instance_valid(visit.window) and is_instance_valid(visit.seal), "window restored after streaming")
	check(visit.seal.get_instance_id() != old_seal_id, "bound a new seal instance")
	var source: Node = game.level_root
	var floor_idx: int = game.run.floor_idx
	var id: String = record.id
	var subject: PhotoAnomaly
	for candidate in game._photo_director._live_doors.values():
		if candidate.id == id:
			subject = candidate
			break
	check(subject != null, "normal camera can photograph entrance")
	game._photo_director.mark_documented(id)
	subject.resolve()
	await physics_frame
	visit._process(0.01)
	check(visit.preview.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "photographed doorway no longer renders with camera lowered")
	await visit.enter()
	check(visit.phase == RealmExcursion.Phase.VISITING, "normal entrance enters")
	check(not visit._entrance_hum.playing, "source doorway hum followed into realm")
	check(game._realm_visit_used(floor_idx), "visit consumed on committed entry")
	check(game.player.level_theme == DescentRun.FIXED_ORDER[floor_idx + 1], "correct next world")
	check(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]), "destination support")
	visit.bounty.resolve()
	visit.elapsed = RealmExcursion.DURATION
	await visit.collapse()
	check(visit.phase == RealmExcursion.Phase.SPENT, "completed return")
	check(game.level_root == source and source.is_inside_tree(), "original floor retained")
	check(game.run.floor_idx == floor_idx, "visit does not advance campaign")
	check(game.player.emergency_flash_held, "survival banks the flash")
	check(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]), "return support")
	game._realm_used.clear()
	game._descent_progress = DescentProgress.new(save_path)
	game._prepare_realm_visit()
	check(game._realm_visit == null, "cannot replay spent event")
	# Continue rebuilds the floor through the real lifecycle hooks.
	await game._resume_descent_at(floor_idx)
	check(game._realm_visit == null, "checkpoint retry cannot replay spent event")
	if floor_idx + 1 < DescentRun.FLOOR_COUNT - 1:
		await game._resume_descent_at(floor_idx + 1)
		check(is_instance_valid(game._realm_visit), "next floor installs its own visit")
	await game._leave_descent()
	check(game._realm_visit == null and not game.descent, "title disposes floor visit")
	print("CAMPAIGN REALM PASS: floor=%d next=%d flash=%s" % [floor_idx + 1, DescentRun.FIXED_ORDER[floor_idx + 1], true])
	game._descent_progress.clear_from_disk()
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
