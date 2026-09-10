extends SceneTree
## Real timed-return branch: restore the retained source behind black, rebuild
## it in reverse, and only then resume its rules and player controls.

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(45.0, true).timeout.connect(func():
		push_error("REASSEMBLY AUDIT TIMEOUT")
		quit(1))
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	for anomaly in game._photo_director._live_doors.values():
		if anomaly.id == visit.seal.photo_id:
			game._photo_director.mark_documented(anomaly.id)
			anomaly.resolve()
			break
	assert(visit.seal.opened)
	var source: Node = game.level_root
	var cm: Node = game.cm
	var run: Node = game.run
	var evidence: Array = game._photo_director.documented_ids().duplicate()
	await visit.enter()
	assert(visit.phase == RealmExcursion.Phase.VISITING)
	visit.set_process(false)
	visit.threats.suspended = true
	visit.elapsed = RealmExcursion.DURATION
	visit._process(0.0) # Same deadline path as an ordinary completed encounter.
	assert(visit.phase == RealmExcursion.Phase.RETURNING)
	var frames_checked := 0
	while visit._rebuild_effect == null:
		await process_frame
		if source.is_inside_tree():
			assert(game._fade.color.a > 0.99, "plain source world exposed before reverse effect")
		frames_checked += 1
	var rebuild: RealmWireframeCollapse = visit._rebuild_effect
	assert(rebuild.rebuilding and is_equal_approx(rebuild.progress, 1.0))
	assert(game._fade.color.a > 0.99, "reassembly did not start behind black")
	assert(source.is_inside_tree() and game.level_root == source and game.cm == cm)
	assert(rebuild.voxel_count > 0 and rebuild.voxel_count <= rebuild.MAX_VOXELS)
	assert((rebuild._material.get_shader_parameter("scan_origin") as Vector3).distance_to(game.player.cam.global_position) < 0.001)
	assert(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]))
	var previous := 1.0
	var paused_once := false
	while visit.phase == RealmExcursion.Phase.RETURNING:
		assert(game.run == run and run.suspended and not run.is_physics_processing(), "source rules resumed during rebuild")
		assert(game._switching and not game.player.is_physics_processing(), "player released before rebuild completed")
		assert(not game._photo_camera.enabled and not game._events.is_processing(), "source actions/events resumed during rebuild")
		if is_instance_valid(rebuild):
			assert(rebuild.progress <= previous + 0.0001, "reassembly did not run in reverse")
			previous = rebuild.progress
			if not paused_once and rebuild.progress < 0.65:
				paused = true
				var held := rebuild.progress
				await create_timer(0.18, true).timeout
				assert(is_equal_approx(rebuild.progress, held), "tree pause advanced reconstruction")
				paused = false
				paused_once = true
		await process_frame
	await process_frame
	assert(paused_once and frames_checked > 0)
	assert(visit.phase == RealmExcursion.Phase.SPENT and not is_instance_valid(rebuild))
	assert(visit._rebuild_effect == null and not game._switching)
	assert(game.player.is_physics_processing() and game._photo_camera.enabled and run.is_physics_processing())
	assert(game.level_root == source and game.cm == cm and game.run == run and run.floor_idx == 0)
	assert(game._photo_director.documented_ids() == evidence)
	assert(game._fade.color.a < 0.001)
	print("REALM REASSEMBLY PASS: source hidden at handoff, reverse progress, supported source geometry, held rules/input/events, pause, cleanup and unchanged run")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
