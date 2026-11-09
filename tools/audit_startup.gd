extends "res://tools/lib/audit_base.gd"
## Native: godot --path . --script tools/audit_startup.gd -- --seed=240721
## Bypass: godot --headless --path . --script tools/audit_startup.gd -- --nologo --seed=240721

const OUT := "res://build/startup"


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(OUT.path_join(label + ".png")) == OK,
		"could not capture " + label)


func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	expect(scene_path == "res://scenes/startup.tscn", "project bypasses the startup video")
	var startup := (load(scene_path) as PackedScene).instantiate()
	var startup_id := startup.get_instance_id()
	var finished_at: Array[int] = []
	root.add_child(startup)
	var bypass := CliOptions.parse().skips_title() or CliOptions.parse().quick_exit()
	if not bypass:
		expect(DisplayServer.get_name() != "headless", "normal startup check needs the native renderer")
		expect(await await_until(func(): return startup._video.is_playing(), 15000),
			"startup video did not begin after preparing the title")
		var prepared := get_first_node_in_group("level_manager")
		expect(prepared != null and is_instance_valid(prepared._title),
			"title was not ready before playback")
		expect(prepared.process_mode == Node.PROCESS_MODE_DISABLED and not prepared._music.playing,
			"gameplay or title music started under the clip")
		startup._video.finished.connect(func(): finished_at.append(Time.get_ticks_msec()))
		expect(startup.layer > 101, "intro is below title or CRT processing")
		await create_timer(2.5).timeout
		var dimensions: Vector2i = startup._video.get_video_texture().get_size()
		expect(dimensions == Vector2i(1920, 1080), "intro lost its 1080p source")
		expect(startup._video.stream_position > 2.0, "startup video did not advance")
		expect(startup._video.material == null, "startup video was post-processed twice")
		await capture("video-16x9")
		root.size = Vector2i(1280, 828)
		await process_frame
		await process_frame
		var video_rect: Rect2 = startup._video.get_global_rect()
		expect(is_equal_approx(video_rect.size.x / video_rect.size.y, 16.0 / 9.0),
			"window resize stretched the video")
		await capture("video-tall")
		expect(await await_until(func(): return startup._transitioning, 6000),
			"video did not naturally finish")
		expect(prepared == get_first_node_in_group("level_manager"), "title was rebuilt after the clip")
		await create_timer(0.15).timeout
		expect(startup._presentation.modulate.a > 0.0 and startup._presentation.modulate.a < 1.0,
			"crossfade did not start immediately after the clip")
		await capture("crossfade")
	else:
		expect(await await_until(func(): return get_first_node_in_group("level_manager") != null, 10000),
			"direct launch did not load Main")
	expect(await await_until(func(): return not is_instance_id_valid(startup_id), 5000),
		"startup layer did not release title input")
	if not bypass and not finished_at.is_empty():
		var transition_ms := Time.get_ticks_msec() - finished_at[0]
		expect(transition_ms <= 1100, "title transition added a loading hold: %dms" % transition_ms)
		print("STARTUP immediate crossfade: %dms" % transition_ms)
	var game := get_first_node_in_group("level_manager")
	if game == null:
		finish("startup")
		return
	var host: Node = game.get_meta("ntscrt_video_host") if game.has_meta("ntscrt_video_host") else null
	expect(current_scene == (host if host != null else game), "startup did not select the production scene root")
	var expected_mode := Node.PROCESS_MODE_PAUSABLE if host != null or not bypass else Node.PROCESS_MODE_INHERIT
	expect(game.process_mode == expected_mode, "game processing remained disabled")
	if bypass:
		expect(not is_instance_valid(game._title), "--nologo launch unexpectedly shows the title")
	else:
		expect(is_instance_valid(game._title) and not game._title._gone,
			"startup did not reveal the normal title")
		expect(not paused and game._pause_menu == null, "startup stranded a pause/settings panel")
		expect(not game.cm.is_processing(), "opaque title kept streaming hidden rooms")
		if host != null:
			expect(await await_until(func(): return host._suspended, 5000), "title did not suspend warmed rendering")
			expect(host.source.render_target_update_mode == SubViewport.UPDATE_DISABLED, "covered viewport still rendering")
		await capture("title")
	await teardown_game(game)
	finish("startup direct-launch bypass" if bypass else
		"startup video: immediate crossfade, held audio/input, aspect ratio and normal title")
