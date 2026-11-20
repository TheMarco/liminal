extends SceneTree
## Native GPU regression: real room, authored lighting, and first-use events.
## godot --path . --audio-driver Dummy --script tools/audit_encounter_warmup.gd
## -- --theme=7 --preset=1 also checks the ghost roster / Medium path.
const Warmup := preload("res://scripts/encounter_render_warmup.gd")
const Effect := preload("res://scripts/reality_aftershock.gd")
const Power := preload("res://scripts/blackout_environment.gd")
const Surface := preload("res://scripts/environment_breath_surface.gd")
var failures: Array[String] = []
var report := {}
var theme := 0
var preset := 3

func _init() -> void:
	call_deferred("run")

func counters() -> Dictionary:
	return {"canvas": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		"mesh": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		"draw": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		"surface": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		"specialization": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))}

func frames(n: int) -> void:
	for i in n: await RenderingServer.frame_post_draw

func check_event(event: String, trigger: Callable) -> void:
	var before := counters()
	var started := Time.get_ticks_usec()
	trigger.call()
	var cpu_ms := (Time.get_ticks_usec() - started) / 1000.0
	var worst_ms := 0.0
	var process_ms := 0.0
	var frame_times: Array[float] = []
	var focused := DisplayServer.window_is_focused()
	var last := started
	for i in 8:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now - last) / 1000.0)
		frame_times.append((now - last) / 1000.0)
		process_ms = maxf(process_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		last = now
	var after := counters()
	var delta := {}
	for key in before: delta[key] = after[key] - before[key]
	report[event] = {"cpu_ms": cpu_ms, "worst_frame_ms": worst_ms, "pipelines": delta,
		# Performance's process monitor refreshes less often than every frame;
		# retain it as context, not as the CPU time of this particular event.
		"process_monitor_ms": process_ms, "frames_ms": frame_times, "focused": focused}
	print("ENCOUNTER_EVENT ", event, " ", report[event])
	# Specializations are asynchronous optimizations, not blocking compilations.
	# Record them, but enforce all four potentially blocking pipeline sources.
	for key in ["canvas", "mesh", "surface", "draw"]:
		if delta[key] != 0: failures.append("%s compiled %d new %s pipelines" % [event, delta[key], key])
	if worst_ms >= 100.0: failures.append("%s stalled %.1f ms" % [event, worst_ms])

func check_corner_apparition(rooms: Node3D) -> void:
	for key: String in CornerApparitions.LOOKS:
		var points: PackedVector3Array = CornerApparitions._smoke_shapes.get(key, PackedVector3Array())
		if points.size() != CornerApparitions.SMOKE_PARTICLE_COUNT or not ShadowFigure._layered_mats.has(key):
			failures.append("corner look %s was not prepared during floor loading" % key)
	var corner := CornerApparitions.new()
	rooms.add_child(corner)
	corner.set_physics_process(false)
	corner.configure(992421325, theme)
	var existing_tweens := get_processed_tweens()
	var scare_tweens: Array[Tween] = []
	await check_event("corner_reveal", func():
		corner._show(Vector3(4, 0, 4))
		# Advance the actual two-second hold separately so each phase gets
		# its own first draw, timing window and pipeline counters.
		for tween in get_processed_tweens():
			if not existing_tweens.has(tween):
				tween.pause()
				scare_tweens.append(tween))
	await check_event("corner_dissolve", func():
		for tween in scare_tweens:
			tween.custom_step(CornerApparitions.HOLD_SECONDS + 0.05))
	if not is_instance_valid(corner._live) or not corner._live.has_node("SilhouetteSmokePuff"):
		failures.append("corner dissolve did not exercise the live smoke emitter")
	corner.free()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Encounter warm-up audit requires a native renderer")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): theme = int(arg.trim_prefix("--theme="))
		if arg.begins_with("--preset="): preset = int(arg.trim_prefix("--preset="))
	root.title = "Encounter warmup regression"
	root.size = Vector2i(960, 540)
	# macOS suspends drawing a fully occluded window. The audit must observe
	# actual GPU frames even while its launching terminal has focus.
	root.always_on_top = true
	root.use_hdr_2d = true
	var settings := GameSettings.new()
	settings.apply_quality_preset(preset)
	settings.values.frame_limit = 60
	GraphicsQuality.apply_viewport(root, settings)
	GraphicsQuality.apply_global(settings)
	var rooms := Node3D.new()
	root.add_child(rooms)
	var world := WorldEnvironment.new()
	world.environment = EnvBuilder.build(theme)
	GraphicsQuality.apply_environment(world.environment, settings)
	rooms.add_child(world)
	var chunks := ChunkManager.new()
	chunks.world_seed = WorldGen.level_seed(992421325, theme)
	chunks.theme = theme
	rooms.add_child(chunks)
	chunks.set_process(false)
	chunks.warm_up(Vector2i.ZERO)
	var chunk := chunks.chunk_at(Vector2i.ZERO)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.mesh.size = Vector3(2, 2, 0.1)
	for mesh in chunk.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is BoxMesh and mesh.material_override is Material:
			wall.material_override = mesh.material_override
			break
	wall.position = Vector3(4, 1.5, 5)
	rooms.add_child(wall)
	var camera := Camera3D.new()
	rooms.add_child(camera)
	camera.look_at_from_position(Vector3(2, 1.7, 2), Vector3(7, 1.3, 7))
	camera.current = true
	var torch := SpotLight3D.new()
	camera.add_child(torch)
	torch.shadow_enabled = true
	torch.spot_range = 18.0
	torch.spot_angle = 32.0
	torch.visible = false
	await frames(12)
	var source_state := source_snapshot(rooms, world.environment)
	var memory_before := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var warmer := Warmup.new()
	root.add_child(warmer)
	var started := Time.get_ticks_usec()
	warmer.prepare(root, theme, rooms)
	await warmer.completed
	await frames(12)
	report["warmup_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	report["warmup_retained_mib"] = (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - memory_before) / (1024.0 * 1024.0)
	report["samples"] = {"meshes": warmer.blackout_mesh_count, "labels": warmer.blackout_label_count}
	if warmer.blackout_mesh_count == 0: failures.append("warmup did not collect floor meshes")
	if warmer.blackout_label_count == 0: failures.append("fixture did not exercise Label3D blackout variants")
	if source_snapshot(rooms, world.environment) != source_state:
		failures.append("warmup changed the live room or environment")
	if is_instance_valid(warmer._view): failures.append("warmup retained its GPU viewport")
	await check_event("idle_control", func(): pass)
	await check_corner_apparition(rooms)
	var effect := Effect.new()
	root.add_child(effect)
	effect.set_process(false)
	for model_index in warmer.model_indices:
		var actor := ShadowFigure.new()
		actor.walker_model_index = model_index
		actor.announce = false
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.position = Vector3(4, 0, 4)
		await check_event("monster_%d" % model_index, func():
			rooms.add_child(actor)
			actor._walker.disappear(0.0)
			actor._walker.set_manifestation(1.0)
			effect._material.set_shader_parameter("strength", 0.7)
			effect.visible = true)
		await check_event("monster_burn_%d" % model_index, func():
			actor._ignite(false, false)
			actor._burn_particles.set_process(false)
			actor._flash.light_energy = 1.0)
		actor._burn_particles.free()
		actor.free()
	effect.visible = false
	await frames(4)
	var face := SurfaceWear.Face.new()
	face.mesh = wall
	face.transform = wall.transform
	face.u = Vector3.RIGHT
	face.v = Vector3.UP
	face.normal = Vector3.BACK
	var surface := Surface.new()
	rooms.add_child(surface)
	if not surface.setup({"face": face, "center": wall.position,
			"size": Vector2(1.5, 1.5), "depth": 0.2, "companions": []}, "breath"):
		failures.append("live breathing surface failed preparation")
	await check_event("breathing", func(): surface.pose(PackedFloat32Array([0.5])))
	surface.restore()
	var power := Power.new()
	await check_event("blackout", func():
		chunks.set_blackout(true)
		power.apply(world.environment))
	await check_event("blackout_torch", func(): torch.visible = true)
	await check_event("power_restored", func():
		chunks.set_blackout(false)
		power.restore())
	var reveal := MutationRevealEffect.new()
	var ghost := DescentMutationCoordinator.new()._snapshot_visuals([chunk])
	await check_event("mutation_reveal", func():
		rooms.add_child(reveal)
		reveal.configure({"kind": "door", "position": Vector3(5, 0, 5),
			"nodes": [chunk], "ghost": ghost, "edge": {"dir": 2, "after": {"w": 3.0}}})
		reveal.set_process(false))
	for tween in get_processed_tweens(): tween.kill()
	reveal.free()
	effect.free()
	rooms.free()
	var retained: Node = warmer._retained
	warmer.free()
	if is_instance_valid(retained): failures.append("floor teardown leaked warmup resource owners")
	ShadowWalkerVisual.clear_runtime_caches()
	preload("res://scripts/environment_breath_surface.gd").clear_runtime_cache()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	await frames(4)
	DirAccess.make_dir_recursive_absolute("res://build/encounter-warmup-review")
	var file := FileAccess.open("res://build/encounter-warmup-review/theme-%d-preset-%d.json" % [theme, preset], FileAccess.WRITE)
	file.store_string(JSON.stringify({"theme": theme, "preset": preset, "results": report, "failures": failures}, "\t"))
	file.close()
	print("ENCOUNTER RENDER PROBE: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func source_snapshot(rooms: Node3D, environment: Environment) -> Array:
	var state: Array = []
	for key in Power.OFF: state.append(environment.get(key))
	for node in rooms.find_children("*", "MeshInstance3D", true, false):
		state.append([node.mesh, node.material_override, node.material_overlay])
		if node.mesh != null:
			for i in node.mesh.get_surface_count(): state.append(node.get_active_material(i))
	for light in rooms.find_children("*", "Light3D", true, false): state.append(light.visible)
	for label in rooms.find_children("*", "Label3D", true, false): state.append(label.shaded)
	return state
