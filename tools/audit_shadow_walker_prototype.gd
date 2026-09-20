extends SceneTree
## godot --headless --path . --script tools/audit_shadow_walker_prototype.gd

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	expect(ShadowWalkerVisual.model_count() == 12,
		"walker roster does not contain all supplied monsters")

	var ordinary := ShadowFigure.new()
	root.add_child(ordinary)
	ordinary.set_physics_process(false)
	expect(ordinary._walker != null,
		"ShadowFigure did not build its animated walker")

	var alternate := ShadowFigure.new()
	root.add_child(alternate)
	alternate.set_physics_process(false)
	expect(alternate._walker != null,
		"second ShadowFigure did not build its animated walker")
	var visual := alternate._walker as ShadowWalkerVisual
	expect(visual._materials.size() == 1,
		"the supplied one-surface walker did not produce one runtime material")
	expect(visual._halo_materials.size() == 5,
		"the supplied walker did not produce its Gaussian defocus kernel")
	expect(visual.animation_player() != null,
		"the supplied walker has no AnimationPlayer")
	if visual.animation_player() != null:
		expect(visual.animation_player().has_animation(&"runtime/walk"),
			"the authored Walking clip was not installed as a runtime loop")
		expect(visual.animation_player().current_animation == &"runtime/walk",
			"the authored walk is not playing")
	var material := visual._materials[0] if not visual._materials.is_empty() else null
	if material != null:
		expect(material.get_shader_parameter(&"albedo_tex") != null,
			"the model's authored charcoal texture was not retained")
	for index in range(1, ShadowWalkerVisual.model_count()):
		var roster_visual := ShadowWalkerVisual.new()
		roster_visual.model_index = index
		root.add_child(roster_visual)
		expect(roster_visual._materials.size() == 1,
			"roster model %d did not produce one runtime material" % index)
		var shells := 4 if ShadowWalkerVisual.GHOST_RENDER[index] else 5
		expect(roster_visual._halo_materials.size() == shells,
			"roster model %d did not produce its defocus kernel" % index)
		expect(roster_visual.animation_player() != null and
			roster_visual.animation_player().has_animation(&"runtime/walk"),
			"roster model %d did not install its walking loop" % index)
		if index == ShadowFigure.POOL_GIRL_MODEL_INDEX:
			expect(roster_visual.has_run_cycle(),
				"pool girl did not install the supplied running loop")
			roster_visual.set_ground_speed(ShadowFigure.POOL_GIRL_DECK_SPEED, true)
			expect(roster_visual.locomotion_clip() == &"run" and
				roster_visual.animation_player().current_animation == &"runtime/run",
				"pool girl did not switch to running on dry deck")
			roster_visual.set_ground_speed(ShadowFigure.POOL_GIRL_WATER_SPEED, false)
			expect(roster_visual.locomotion_clip() == &"walk" and
				roster_visual.animation_player().current_animation == &"runtime/walk",
				"pool girl did not switch back to walking in water")
		var roster_surface := roster_visual.burn_surface_points(320)
		expect(roster_surface.size() == 320,
			"roster model %d cannot provide its skinned burn surface" % index)
		roster_visual.free()
	expect(visual.animation_player().callback_mode_process ==
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"walk clip is not driven by the locomotion update")
	visual.set_manifestation(1.0)
	for frame in 60:
		visual.face_world_position(Vector3.RIGHT * 5.0, 1.0 / 60.0)
	expect(visual.global_basis.z.normalized().dot(Vector3.RIGHT) > 0.99,
		"walker authored front did not turn toward the player")
	var alignment := 0.0
	for frame in 60:
		alignment = visual.face_world_direction(Vector3.FORWARD, 1.0 / 60.0)
	expect(alignment > 0.99 and visual.global_basis.z.normalized().dot(
		Vector3.FORWARD) > 0.99,
		"walker authored front did not turn into its actual travel direction")
	ordinary.global_position = Vector3.ZERO
	alternate.global_position = Vector3(10.0, 0.0, 0.0)
	expect(not alternate._peer_clear(Vector3(1.0, 0.0, 0.0)),
		"moving walkers can still enter another figure's occupied space")
	expect(alternate._peer_clear(Vector3(2.0, 0.0, 0.0)),
		"moving walker separation blocks actors that are safely apart")
	var manager := ShadowFigures.new()
	root.add_child(manager)
	manager.set_physics_process(false)
	manager._figs.assign([ordinary, alternate])
	expect(not manager._can_add_figure(),
		"ordinary campaign manager still permits paired stalkers")
	manager.allow_reinforcements = true
	expect(manager._can_add_figure(),
		"explicit multi-enemy space cannot opt into its authored escalation")
	manager.allow_reinforcements = false
	expect(not manager._spawn_separated(Vector3(3.0, 0.0, 0.0)),
		"runtime spawns can still appear too close to an existing figure")
	expect(manager._spawn_separated(Vector3(5.0, 0.0, 0.0)),
		"runtime spawn separation rejects a safely distant position")
	var scout := Player.new()
	scout.level_theme = 0
	manager.player = scout
	manager._dark_bag.clear()
	var picked := {}
	for draw in ShadowFigures.DARK_ROSTER.size():
		picked[manager._next_spawn_model()] = true
	expect(picked.size() == ShadowFigures.DARK_ROSTER.size()
		and not picked.has(-1),
		"dark bag repeated a design before the black roster completed")
	scout.free()
	visual.set_instance_shader_parameter(&"burn", 0.65)
	visual.set_ground_speed(1.25)
	var phase_before := visual.animation_player().current_animation_position
	visual.animate(0.1, true)
	var baseline_rate := visual.animation_player().speed_scale
	expect(is_equal_approx(baseline_rate, 1.25 / visual.walk_cycle_speed()),
		"walk rate does not use measured stride calibration")
	expect(is_equal_approx(visual.animation_player().current_animation_position - phase_before,
		0.1 * baseline_rate), "walking phase did not advance by travelled distance")
	visual.set_ground_speed(1.25 * 1.3)
	visual.animate(0.1, false)
	expect(is_equal_approx(visual.animation_player().speed_scale, baseline_rate * 1.3),
		"animation did not match level-scaled physical movement")
	visual.begin_motion_frame()
	phase_before = visual.animation_player().current_animation_position
	visual.animate(0.1, false)
	expect(is_zero_approx(visual.animation_player().speed_scale),
		"stationary walker kept walking in place")
	expect(is_equal_approx(visual.animation_player().current_animation_position, phase_before),
		"stationary walk phase advanced on an independent clock")
	expect(is_equal_approx(float(visual._parameters[&"burn"]), 0.65),
		"torch-burn value did not reach the 3D walker")
	if not visual._halo_materials.is_empty():
		expect(is_equal_approx(float(visual._halo_materials[0].get_shader_parameter(
			&"burn")), 0.65), "torch-burn value did not reach the halo")
	visual.set_closeup_mode(true)
	visual.animate(0.1, false)
	expect(visual.is_closeup_mode(),
		"caught-sequence close-up mode was not retained")
	if not visual._halo_materials.is_empty():
		expect(is_equal_approx(float(visual._halo_materials[0].get_shader_parameter(
			&"effect_strength")), 0.46), "caught sequence did not calm the halo")
	expect(visual.animation_player() == null or
		is_equal_approx(visual.animation_player().speed_scale, 0.16),
		"caught sequence did not calm the walk animation")
	visual.set_manifestation(0.0)
	expect(not visual._presentation.visible,
		"zero manifestation left visible walker geometry")
	expect(not alternate._wisps.visible,
		"zero manifestation left detached wisps visible")
	expect(is_zero_approx((alternate._gloom.material as FogMaterial).density),
		"zero manifestation left the local spectral fog visible")

	# Exercise the terminal effect, not just its shader parameters: the body
	# must become the visible light source and a sibling particle silhouette
	# must survive long enough to complete the disintegration after actor free.
	visual.set_manifestation(1.0)
	var surface_points := visual.burn_surface_points(560)
	expect(surface_points.size() == 560,
		"walker burn did not sample the requested number of actual mesh vertices")
	var point_bounds := AABB(surface_points[0], Vector3.ZERO) \
		if not surface_points.is_empty() else AABB()
	for point in surface_points:
		point_bounds = point_bounds.expand(point)
	expect(point_bounds.size.y > 1.75 and point_bounds.size.x > 0.45,
		"walker burn surface points do not span the visible animated mesh")
	var surface_samples := visual.burn_surface_samples(2400)
	var sampled_points: PackedVector3Array = surface_samples.get(
		"points", PackedVector3Array())
	var sampled_normals: PackedVector3Array = surface_samples.get(
		"normals", PackedVector3Array())
	expect(sampled_points.size() == 2400
		and sampled_normals.size() == sampled_points.size(),
		"walker burn did not build area-weighted 3D surface samples")
	alternate._walker.rotation.y = 0.73
	var burn_facing := alternate._walker.global_basis.z.normalized()
	alternate._ignite(false, false)
	expect(alternate._burn_disintegration_started,
		"walker ignition did not schedule its mesh disintegration")
	await create_timer(0.14).timeout
	expect(alternate._burn_particles != null
		and alternate._burn_particles.fragment_count >= 2200,
		"walker ignition did not emit the sampled mesh surface as particles")
	expect(alternate._flash != null
		and alternate._flash.get_meta("visible_source", "")
			== "walker_burning_body_and_particles",
		"walker burn light is not contracted to its visible body and particles")
	expect(not alternate._wisps.visible,
		"dark ambient wisps stayed visible over the bright disintegration")
	if is_instance_valid(alternate._burn_particles):
		var burn_mesh := alternate._burn_particles.multimesh.mesh
		var burn_material := alternate._burn_particles.material_override as ShaderMaterial
		expect(burn_material != null and burn_material.shader != null,
			"walker burn particles have no HDR-capable material")
		expect(burn_mesh is ArrayMesh and burn_mesh is not QuadMesh,
			"walker burn fragments are still camera-facing cards")
		expect(alternate._walker._parameters.get(&"fragmented", 0.0) == 1.0,
			"intact walker remained visible under its fragment body")
		expect(alternate._burn_particles.global_basis.z.normalized().dot(
			burn_facing) > 0.999,
			"fragment handoff dropped or mirrored the walker's current facing")
	# Allow both one-shot timers and the detached death sound to release their
	# captured resources before the SceneTree audit exits.
	await create_timer(1.45).timeout
	await process_frame
	for child in root.get_children():
		if child is AudioStreamPlayer3D:
			child.free()

	ordinary.free()
	alternate.free()
	manager.free()
	if failures.is_empty():
		print("PASS shadow_walker_prototype")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
