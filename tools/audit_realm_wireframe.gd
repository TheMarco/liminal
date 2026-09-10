extends SceneTree
## The new presentation shares the same visit/return contract as the shelved one.

var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(45.0).timeout.connect(func():
		push_error("WIREFRAME AUDIT TIMEOUT")
		quit(1))
	assert(CliOptions.parse_args([]).realm_collapse_style == "wireframe")
	assert(CliOptions.parse_args(["--realm-collapse=fracture"]).realm_collapse_style == "fracture")
	assert(not CliOptions.parse_args(["--realm-collapse=fracture"]).realm_visit)
	game = load("res://scenes/main.tscn").instantiate()
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
	var original_root: Node = game.level_root
	var original_cm: Node = game.cm
	var evidence: Array = game._photo_director.documented_ids().duplicate()
	await visit.enter()
	assert(visit.phase == RealmExcursion.Phase.VISITING)
	visit.set_process(false)
	visit.threats.suspended = true
	game.player.set_physics_process(false)
	var effect: RealmWireframeCollapse = visit._collapse_effect
	assert(effect != null and not effect.sampled and not effect._screen.visible)
	effect.set_progress(0.18)
	assert(effect.sampled and effect.voxel_count > 0 and effect.voxel_count <= effect.MAX_VOXELS)
	assert(effect._voxels.multimesh.visible_instance_count == 0, "cubes appeared before wireframe conversion")
	var count := effect.voxel_count
	var prior_setting := GameSettings.flashing_reduced()
	GameSettings.current.values["reduced_flashing"] = true
	effect.set_progress(0.65)
	assert(effect.voxel_count == count and effect._voxels.multimesh.visible_instance_count == count)
	assert(bool(effect._voxel_material.get_shader_parameter("reduced_flashing")))
	assert(bool(effect._material.get_shader_parameter("reduced_flashing")))
	# GPU motion only changes the presentation; the sampled world anchors and
	# collision remain fixed. With a renderer, verify the actual stored anchors.
	if DisplayServer.get_name() != "headless":
		var anchors := {}
		for i in count:
			var transform := effect._voxels.multimesh.get_instance_transform(i)
			assert(transform.origin.is_finite() and transform.basis.is_finite())
			assert(not anchors.has(transform.origin), "duplicate voxel anchor")
			anchors[transform.origin] = true
	assert(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]))
	visit.elapsed = RealmExcursion.DURATION - visit.collapse_seconds() * 0.56
	visit.set_process(true)
	visit._process(0.0)
	assert(visit.threats.passive, "attacks continued after solid visibility disappeared")
	game._show_return_prompt()
	var held_progress := effect.progress
	await create_timer(0.15).timeout
	assert(is_equal_approx(effect.progress, held_progress))
	assert(is_equal_approx(float(effect._voxel_material.get_shader_parameter("collapse")), held_progress))
	assert(effect._hum.stream_paused and effect._erase.stream_paused)
	game._cancel_return_to_title()
	visit.set_process(false)
	visit._process(0.05)
	assert(effect.progress > held_progress and not effect._hum.stream_paused)
	effect.set_progress(1.0)
	assert(effect._voxels.multimesh.visible_instance_count == 0)
	GameSettings.current.values["reduced_flashing"] = prior_setting
	await visit.collapse()
	await process_frame
	assert(visit.phase == RealmExcursion.Phase.SPENT and not is_instance_valid(effect))
	assert(game.level_root == original_root and game.cm == original_cm and game.run.floor_idx == 0)
	assert(game._photo_director.documented_ids() == evidence)
	assert(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, [game.player.get_rid()]))
	print("REALM WIREFRAME PASS: style selection, bounded surface voxels, staged visibility, comfort, pause, protection, source restoration and cleanup")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
