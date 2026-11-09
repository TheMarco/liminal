extends "res://tools/lib/audit_base.gd"
## Native integration check: real game, recorded video, window-resolution counter.
## godot --path . --script tools/audit_fps_counter.gd -- --nologo --level=6
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const OUT := "res://build/fps-counter/"

func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU and --nologo")
		finish()
		return
	root.size = Vector2i(1280, 720)
	var host := HOST.new()
	root.add_child(host)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	var path := "/tmp/liminal-fps-counter-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	game.player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stop_audio(game)
	var counter: CanvasLayer = game._fps_counter
	expect(counter.custom_viewport == root, "FPS counter is processed by the video effects")
	game._open_settings()
	game._pause_menu._controls["show_fps"].button_pressed = true
	game._pause_menu._resume_button.pressed.emit()
	expect(GameSettings.new(path).get_value("show_fps"), "menu did not save FPS preference")
	# Explicit draws make the measurement deterministic even if macOS stops
	# automatic drawing while this test's window is behind another application.
	for frame in 90:
		await process_frame
		RenderingServer.force_draw()
	expect(counter.visible and counter._label.text.contains(" FPS · ")
		and not counter._label.text.begins_with("0 FPS"), "rendered FPS did not update")
	var panel: Control = counter._label.get_parent()
	expect(root.get_visible_rect().encloses(panel.get_global_rect()), "FPS panel outside window")
	DirAccess.make_dir_recursive_absolute(OUT)
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: image.linear_to_srgb()
	image.save_png(OUT + "gameplay.png")
	game._open_settings()
	expect(counter.can_process(), "FPS counter stopped in the pause menu")
	game._pause_menu._scroll.ensure_control_visible(game._pause_menu._controls["show_fps"])
	for frame in 4: await process_frame
	RenderingServer.force_draw()
	image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: image.linear_to_srgb()
	image.save_png(OUT + "settings.png")
	game._pause_menu._controls["show_fps"].button_pressed = false
	expect(not counter.visible and not counter.is_processing()
		and not RenderingServer.frame_post_draw.is_connected(counter._count_draw),
		"disabled FPS counter still samples or draws")
	game._close_settings()
	await teardown_game(game)
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
	finish("FPS counter: draw sampling, video bypass, menu toggle, persistence and disabled idle")
