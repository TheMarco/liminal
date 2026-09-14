extends "res://tools/lib/audit_base.gd"
## Production wiring; all writes target unique temporary files, never a profile.
func run() -> void:
	var game := await boot_game(21)
	expect(not game._progress_enabled, "runtime audit must disable player saves")
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	game.run.suspend_rules()
	if is_instance_valid(game._realm_visit):
		game._realm_visit.set_process(false)
		expect(await await_until(func(): return game._realm_visit._preview_resources_ready, 20000), "preloads did not settle")
	var prefix := "/tmp/liminal-focus-save-%d" % OS.get_process_id()
	var settings := GameSettings.new(prefix + "-settings.cfg")
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game.player.toggle_sprint = true
	game.player._sprint_toggle_active = true
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(paused and is_instance_valid(game._pause_menu), "focus loss did not pause")
	expect(not game.player._sprint_toggle_active, "focus loss retained sprint")
	var elapsed: float = game.run.floor_elapsed
	for frame in 6:
		await process_frame
	expect(is_equal_approx(game.run.floor_elapsed, elapsed), "run timer advanced while paused")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	expect(paused, "focus gain automatically resumed")
	game._close_settings()
	expect(not paused and not game.player.is_physics_processing(), "resume changed existing player gates")
	# Existing paused surfaces must not gain another hidden pause menu.
	paused = true
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(not is_instance_valid(game._pause_menu), "focus loss nested an existing pause")
	paused = false
	game._descent_intro = DescentIntro.new(false)
	game.add_child(game._descent_intro)
	# The dummy renderer cannot reliably initialize decoded video textures.
	# Always verify the process gate; exercise playback time on a real renderer.
	var rendered := DisplayServer.get_name() != "headless"
	if rendered:
		await create_timer(0.2).timeout
	var movie_position: float = game._descent_intro._video.stream_position
	if rendered:
		expect(movie_position > 0.0, "intro playback did not start before pause check")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(paused and not game._pause_menu.allow_return_to_title, "first intro pause can abandon mandatory viewing")
	expect(not game._descent_intro._video.can_process(), "intro can process while paused")
	if rendered:
		await create_timer(0.2).timeout
		expect(is_equal_approx(game._descent_intro._video.stream_position, movie_position), "intro kept playing while unfocused")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	expect(paused, "intro resumed automatically")
	game._close_settings()
	expect(not game._descent_intro.skip_available(), "pause unlocked first intro skip")
	expect(game._descent_intro._video.can_process(), "intro remains paused after resume")
	if rendered:
		await create_timer(0.2).timeout
		expect(game._descent_intro._video.stream_position > movie_position, "intro failed to resume playback")
	game._descent_intro.free()
	game._descent_intro = null
	# Real gameplay labels, including the portrait-width regression.
	game.run.suspended = false
	game._descent_hud.set_active(true)
	game._descent_hud.evidence_target = Vector3(300, 0, 300)
	game._descent_hud.set_photo_progress(12, 5)
	game._interact_hint.text = "E — WATCH RECORDING (ALREADY WATCHED — HOLD TO SKIP)"
	game._interact_panel.visible = true
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		for frame in 6: await process_frame
		for control in [game._descent_hud._photo, game._descent_hud._photo_warn, game._interact_hint]:
			expect(Rect2(Vector2.ZERO, Vector2(extent)).encloses(control.get_global_rect()), "gameplay text clips at %s: %s" % [extent, control.get_global_rect()])
	game.run.suspend_rules()
	# A failed photograph stays visible above its opaque review card.
	game._on_photo_raised(true)
	game._on_album_photograph(null, {})
	expect(game._save_notice.visible and game._save_notice.layer > game._photo_camera.layer
		and game._save_notice._messages.has("Photograph"), "failed photo warning hidden behind print")
	game._save_notice.clear_failure("Photograph")
	game._on_photo_raised(false)
	# Bad directory does not exist: exercise real ConfigFile errors, not mocked signals.
	var progress := DescentProgress.new(prefix + "-missing/checkpoint.cfg")
	game._descent_progress = progress
	game._progress_enabled = true
	progress.start_new(game.world_seed)
	expect(is_instance_valid(game._save_notice) and game._save_notice.visible
		and game._save_notice._messages.has("Progress"), "failed checkpoint is silent")
	expect(not paused, "checkpoint failure interrupted gameplay/transition")
	settings._path = prefix + "-missing/settings.cfg"
	game._open_settings(false)
	game._pause_menu._close_resume()
	expect(not paused and game._save_notice._messages.has("Settings"), "settings failure was silent or trapped pause")
	settings._path = prefix + "-settings.cfg"
	expect(settings.save_to_disk() == OK, "settings recovery save failed")
	expect(not game._save_notice._messages.has("Settings")
		and game._save_notice._messages.has("Progress"), "one store's recovery cleared the other's warning")
	progress._save_path = prefix + "-progress.cfg"
	expect(progress.save_to_disk() == OK, "checkpoint recovery save failed")
	expect(not game._save_notice.visible, "successful save left stale warning")
	var state_key := "cell:999,999:audit_door"
	game.cm._runtime_state.put(state_key, "swing_door", {"angle": 1.2})
	expect(game._save_before_exit() == OK, "normal exit preparation failed")
	var exit_save := DescentProgress.new(progress._save_path)
	expect(exit_save.runtime_state_for_floor(game.run.floor_idx).has(state_key), "exit omitted mutable world state")
	settings._path = prefix + "-missing/settings.cfg"
	game._request_quit()
	for frame in 6: await process_frame
	expect(game._quitting and is_instance_valid(game._quit_prompt), "failed exit save did not ask before quitting")
	if is_instance_valid(game._quit_prompt):
		game._quit_prompt._no.pressed.emit()
	for frame in 6: await process_frame
	expect(not game._quitting and is_instance_valid(game._pause_menu) and game._pause_menu.visible, "cancel quit did not return to usable pause menu")
	settings._path = prefix + "-settings.cfg"
	game._pause_menu._close_resume()
	# Check the notice's two-category layout, including live shrinking.
	game._report_save_failure("Progress", ERR_FILE_CANT_WRITE)
	game._report_save_failure("Settings", ERR_FILE_CANT_WRITE)
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(3840, 2160), Vector2i(640, 480)]:
		root.size = extent
		for frame in 6:
			await process_frame
		var rect: Rect2 = game._save_notice._panel.get_global_rect()
		expect(Rect2(Vector2.ZERO, Vector2(extent)).encloses(rect), "save warning clips at %s: %s" % [extent, rect])
		if extent == Vector2i(640, 480):
			expect(rect.end.y < 100.0, "save warning covers the first settings control")
		expect(game._save_notice._panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "warning blocks interaction")
	var return_floor: int = game.run.floor_idx
	game.cm._runtime_state.put(state_key, "swing_door", {"angle": 0.7})
	await game._leave_descent()
	var return_save := DescentProgress.new(progress._save_path)
	expect(is_equal_approx(return_save.runtime_state_for_floor(return_floor).payload_for(state_key).get("angle", -1.0), 0.7), "Return to Title omitted latest mutable world state")
	expect(is_instance_valid(game._title), "Return to Title did not restore title")
	game._progress_enabled = false
	await teardown_game(game)
	DirAccess.remove_absolute(prefix + "-settings.cfg")
	DirAccess.remove_absolute(prefix + "-progress.cfg")
	DirAccess.remove_absolute(prefix + "-progress.cfg.bak")
	finish("focus-loss pause, explicit resume, intro protection, failed/recovered saves and warning layout")
