extends SceneTree
## Verifies the realm collapse presentation in isolation.

var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	Engine.max_fps = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	var deadline := Time.get_ticks_msec() + 15000
	while visit.phase == RealmExcursion.Phase.PREPARING and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING, "realm visit did not prepare")
	visit.collapse_style = "fracture" # This audit specifically covers the shelved particle version.
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.player.set_process_input(false)
	game.player.set_process_unhandled_input(false)

	# Resolve the genuine photographic doorway using the production callback.
	var id: String = visit.seal.photo_id
	for anomaly in game._photo_director._live_doors.values():
		if is_instance_valid(anomaly) and anomaly.id == id:
			game._photo_director.mark_documented(id)
			anomaly.resolve()
			break
	assert(visit.seal.opened, "production doorway did not resolve")
	var source_root: Node = game.level_root
	var source_cm: Node = game.cm
	var source_floor: Node = game.level_root
	var source_collision_rid := visit.seal.barrier.get_rid()

	await visit.enter()
	assert(visit.phase == RealmExcursion.Phase.VISITING, "realm visit did not enter")
	visit.set_process(false)
	visit.threats.suspended = true
	game.player.set_physics_process(false)
	var effect: RealmCollapseEffect = visit._collapse_effect
	assert(is_instance_valid(effect), "collapse effect missing")
	assert(effect.progress == 0.0 and not effect.sampled, "effect not initially idle")
	assert(not effect._screen.visible, "collapse screen visible before progress")

	effect.set_progress(0.2)
	assert(effect.sampled, "surface sampling did not occur")
	assert(effect.shard_count > 0 and effect.shard_count <= RealmCollapseEffect.MAX_SHARDS,
		"invalid shard count")
	assert(effect._screen.visible, "collapse screen did not become visible")
	assert(is_equal_approx(float(effect._material.get_shader_parameter("collapse")), 0.2),
		"shader progress mismatch")
	var first_count := effect.shard_count
	var particles: RealmCollapseParticles = effect._particles
	assert(particles.spark_count == first_count * RealmCollapseParticles.SPARKS_PER_SURFACE,
		"spark showers did not seed from actual surfaces")
	assert(particles.dust_count == first_count * RealmCollapseParticles.DUST_PER_SURFACE,
		"dust clouds did not seed from actual surfaces")
	effect.set_progress(0.65)
	assert(effect.shard_count == first_count, "surface resampled during collapse")
	assert(particles.spark_count == first_count * RealmCollapseParticles.SPARKS_PER_SURFACE,
		"particle allocation grew during collapse")
	for shard_index in range(effect.shard_count):
		var at := effect._shards.multimesh.get_instance_transform(shard_index)
		assert(at.origin.is_finite() and at.basis.is_finite(), "shard transform became non-finite")

	var prior_reduced := bool(GameSettings.current.values.get("reduced_flashing", false))
	GameSettings.current.values["reduced_flashing"] = true
	effect.set_progress(0.85)
	assert(effect.reduced, "reduced flashing was not observed")
	assert(bool(effect._material.get_shader_parameter("reduced_flashing")),
		"reduced flashing shader parameter missing")
	assert(bool(particles._spark_material.get_shader_parameter("reduced_flashing"))
		and bool(particles._dust_material.get_shader_parameter("reduced_flashing")),
		"particles ignored reduced flashing")
	assert(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position,
		[game.player.get_rid()]), "collapse removed destination floor support")
	# Looking elsewhere must not pull debris into a new camera-centred vortex.
	var shard_before := effect._shards.multimesh.get_instance_transform(0)
	var camera_before: Transform3D = game.player.cam.global_transform
	game.player.cam.global_position += Vector3(7, 3, -5)
	effect.set_progress(0.85)
	assert(shard_before.is_equal_approx(effect._shards.multimesh.get_instance_transform(0)),
		"debris motion depends on camera position")
	game.player.cam.global_transform = camera_before
	effect.set_hold(true)
	assert(effect._hum.stream_paused and effect._creak.stream_paused and effect._impact.stream_paused
		and effect._fracture.stream_paused, "collapse audio did not pause")
	effect.set_hold(false)
	assert(not effect._hum.stream_paused and not effect._creak.stream_paused and not effect._impact.stream_paused
		and not effect._fracture.stream_paused, "collapse audio did not resume")

	# Exercise the actual quit-dialog hold during the visible collapse.
	visit.elapsed = RealmExcursion.DURATION - 1.0
	visit.set_process(true)
	visit._process(0.0)
	game._show_return_prompt()
	var elapsed_before: float = visit.elapsed
	var progress_before: float = effect.progress
	shard_before = effect._shards.multimesh.get_instance_transform(0)
	await create_timer(0.15).timeout
	assert(is_equal_approx(visit.elapsed, elapsed_before) and is_equal_approx(effect.progress, progress_before),
		"quit dialog did not freeze collapse progress")
	assert(shard_before.is_equal_approx(effect._shards.multimesh.get_instance_transform(0)),
		"quit dialog did not freeze debris")
	assert(is_equal_approx(particles.progress, progress_before)
		and is_equal_approx(float(particles._spark_material.get_shader_parameter("collapse")), progress_before)
		and is_equal_approx(float(particles._dust_material.get_shader_parameter("collapse")), progress_before),
		"quit dialog did not freeze particle animation")
	assert(effect._hum.stream_paused and effect._fracture.stream_paused, "quit dialog did not pause sound")
	game._cancel_return_to_title()
	visit.set_process(false)
	visit._process(0.05)
	assert(effect.progress > progress_before and not effect._hum.stream_paused, "collapse did not resume")
	game.player.set_physics_process(false)
	visit.threats.suspended = true
	effect.set_progress(1.0)
	assert(effect._shards.multimesh.visible_instance_count == 0,
		"fragments were still submitted after complete disintegration")
	assert(particles._sparks.multimesh.visible_instance_count == 0
		and particles._dust.multimesh.visible_instance_count == 0,
		"particle batches survived complete disintegration")

	# The source world and its collision remain intact while visiting.
	assert(source_root.get_parent() == null, "source world not detached")
	assert(game.cm == source_cm, "chunk manager changed during visit")
	assert(source_floor != null and is_instance_valid(source_floor), "source floor was lost")
	visit.set_process(false)
	visit.elapsed = RealmExcursion.DURATION - 0.8
	visit._process(0.0)
	assert(visit.threats.passive, "threats not passive during terminal collapse")

	await visit.collapse(false)
	await process_frame
	await process_frame
	assert(visit.phase == RealmExcursion.Phase.SPENT, "visit did not complete")
	assert(not is_instance_valid(effect), "collapse effect was not freed")
	assert(not is_instance_valid(particles), "particle layer was not freed")
	assert(game.level_root == source_root and game.cm == source_cm, "source world not restored")
	assert(is_instance_valid(source_floor), "source floor missing after return")
	assert(visit.seal.barrier.get_rid() == source_collision_rid, "source collision RID changed")
	assert(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position,
		[game.player.get_rid()]), "return has no floor support")
	assert(game.run.floor_idx == 0, "collapse advanced the floor")
	GameSettings.current.values["reduced_flashing"] = prior_reduced
	print("REALM COLLAPSE PASS: sampling, camera-independent debris, terminal disappearance, shader, reduced flashing, quit hold, terminal passive state, source restoration")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
