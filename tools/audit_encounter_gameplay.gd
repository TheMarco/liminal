extends "res://tools/audit_encounter_warmup.gd"
## Full production viewport and recorded Descent seed. Never writes player saves.
## godot --path . --audio-driver Dummy --script tools/audit_encounter_gameplay.gd
## -- --test-mode --seed=992421325 --report-tag=baseline
const Host := preload("res://scripts/ntscrt_video_host.gd")
const Placement := preload("res://scripts/environment_breath_placement.gd")

func run() -> void:
	if DisplayServer.get_name() == "headless" or not CliOptions.parse().test_mode:
		push_error("Requires native rendering and --test-mode to isolate player saves")
		quit(1)
		return
	var tag := "current"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-tag="): tag = arg.trim_prefix("--report-tag=")
	root.title = "Full encounter regression"
	root.size = Vector2i(1728, 1084)
	root.always_on_top = true
	root.use_hdr_2d = true
	var host := Host.new()
	root.add_child(host)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	host.attach(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	# No interactive player exists in this controlled fixture. Reuse the
	# existing protected-presentation gate to avoid focus-loss pause menus.
	game._dying = true
	if game._progress_enabled: failures.append("Player saves enabled in regression")
	if not game._encounter_warmup.finished: await game._encounter_warmup.completed
	await process_frame # Leave the completed signal before freeing its emitter.
	# Match the report without changing the saved settings or checkpoint.
	var settings := GameSettings.new("/tmp/liminal-encounter-audit-settings.cfg")
	settings.apply_quality_preset(3)
	settings.values.merge({"fullscreen": false, "frame_limit": 60,
		"vhs_enabled": true, "crt_enabled": false, "video_pipeline": 2,
		"video_quality_override": 3, "render_resolution": 2}, true)
	game._settings = settings
	GameSettings.current = settings
	game._apply_game_settings()
	game._prepare_encounter_rendering(0)
	await game._encounter_warmup.completed
	host.set_title_covered(false)
	game._set_title_covered(false)
	game.player.position = Vector3(479.7257, 0.000941, 344.6712)
	# Player's camera is top-level and normally follows in _process. This
	# controlled fixture disables processing, so move the eye explicitly.
	game.player.cam.global_position = game.player.position + Vector3(0, Player.CAM_H, 0)
	game.player.cam.look_at(Vector3(469.4569, 1.2, 345.4451))
	game.cm.process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(240)
	game.cm.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(30)
	report["context"] = {"seed": game.world_seed, "viewport": host.source.size,
		"scale": host.source.scaling_3d_scale, "position": game.player.position,
		"camera_position": game.player.cam.global_position,
		"chunks": game.cm.chunks.size(), "warmup_models": game._encounter_warmup.model_indices}
	await check_event("idle_control", func(): pass)
	var actor := ShadowFigure.new()
	actor.walker_model_index = 0
	actor.announce = false
	actor.position = Vector3(469.4569, 0, 345.4451)
	await check_event("full_monster_presence", func():
		game.level_root.add_child(actor)
		actor._walker.disappear(0.0)
		actor._walker.set_manifestation(1.0))
	await check_event("monster_torch", func():
		game.player.flashlight.visible = true
		game.player._flash_dust.update_field()
		actor._set_visual_parameter(&"torch", 1.0))
	await check_event("monster_burn", func():
		actor._ignite(false, false)
		actor._burn_particles.set_process(false)
		actor._flash.light_energy = 1.0)
	actor._burn_particles.free()
	actor.free()
	game.player.flashlight.visible = false
	await frames(12)
	# Actual room ceiling, not the small wall proxy used by the isolated audit.
	var chunk: Chunk = game.cm.chunk_at(Vector2i(39, 27))
	var choices := Placement.candidates(chunk, "ceiling")
	if choices.is_empty():
		failures.append("Recorded room has no testable ceiling")
	else:
		var selection: Dictionary = choices[0]
		game.player.position = Vector3(475.1112, 0.000941, 328.7319)
		game.player.cam.global_position = game.player.position + Vector3(0, Player.CAM_H, 0)
		game.player.cam.look_at(chunk.to_global(selection.center))
		await frames(24)
		var surface := Surface.new()
		chunk.add_child(surface)
		surface.begin_setup(selection, "ceiling")
		var worst_prepare := 0.0
		while not surface.prepared and not surface.failed:
			var start := Time.get_ticks_usec()
			surface.prepare_step()
			worst_prepare = maxf(worst_prepare, (Time.get_ticks_usec() - start) / 1000.0)
			await frames(1)
		report["ceiling_prepare_ms"] = worst_prepare
		if surface.failed: failures.append("Ceiling preparation failed")
		await check_event("ceiling_pose", func(): surface.pose(PackedFloat32Array([0.5])))
		surface.restore()
		surface.free()
	report["failures"] = failures
	DirAccess.make_dir_recursive_absolute("res://build/encounter-gameplay-review")
	var file := FileAccess.open("res://build/encounter-gameplay-review/%s.json" % tag, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ENCOUNTER_GAMEPLAY ", JSON.stringify(report))
	for tween in get_processed_tweens(): tween.kill()
	for audio in game.find_children("*", "AudioStreamPlayer*", true, false): audio.stop()
	game.free()
	await process_frame
	GameSettings.current = null
	ShadowWalkerVisual.clear_runtime_caches()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)
