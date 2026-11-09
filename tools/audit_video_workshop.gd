extends SceneTree
const IO = preload("res://scripts/video_preset_io.gd")
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr(label)
func _initialize() -> void: _run.call_deferred()
func frames(count := 8) -> void:
	for index in count: await process_frame
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	check(OS.get_cmdline_user_args().has("--nologo"),"Requires isolated --nologo launch")
	change_scene_to_file("res://scenes/startup.tscn")
	var game: Node
	for index in 240:
		await process_frame
		game = get_first_node_in_group("level_manager")
		if game!=null and game.get("_post_process")!=null: break
	if game==null: check(false,"Game startup"); quit(1); return
	var host: Control = game.get_meta("ntscrt_video_host")
	game._settings._path = "/tmp/liminal-workshop-native-%d.cfg" % OS.get_process_id()
	game._settings.values = GameSettings.DEFAULTS.duplicate(true)
	game._settings.values.fullscreen = false
	game._settings.values.hdr_enabled = false
	game._settings.changed.emit()
	check(not game._progress_enabled,"Audit changed campaign progress")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,800)
	await frames(20)
	game._open_settings()
	game._pause_menu._select_tab("Visual Effects")
	game._pause_menu.preset_workshop_requested.emit()
	await frames(16)
	check(paused and not game._pause_menu.visible,"Workshop did not replace pause overlay")
	var workshop: CanvasLayer = game._video_workshop
	check(workshop!=null and workshop.custom_viewport==root,"Workshop UI does not target crisp root viewport")
	var panel: Control = workshop.panel
	panel.profile.crt_model = 6
	panel.profile.quality = 2
	panel._crt_controls["lcd_gamma"].value = 3.0
	panel.profile.tape_damage = 0.41
	panel.profile.receiver_enabled = false
	await frames(14)
	check(host.presenter.preset_name=="royale","Game did not switch CRT model")
	check(is_equal_approx(host.presenter.parameters.lcd_gamma,3.0),"Game CRT knob not applied")
	check(host.presenter.signal_settings==panel.profile.signal_settings(),"Game signal differs from portable profile")
	check(host.presenter.receiver_settings==panel.profile.receiver_settings(),"Game receiver differs from portable profile")
	panel._name.text = "Game reference"
	panel.store_reference()
	panel.profile.crt_model = 1
	panel.show_reference(true)
	await frames()
	check(host.presenter.preset_name=="royale","Game A/B reference did not apply")
	var directory := "/tmp/liminal-workshop-review"
	DirAccess.make_dir_recursive_absolute(directory)
	panel._tabs.current_tab = 1
	root.get_texture().get_image().save_png(directory.path_join("workshop.png"))
	var captured: Dictionary = await panel.capture_preset(directory.path_join("preset"))
	check(captured.error.is_empty(),"Game capture failed")
	check(captured.image_size==root.get_texture().get_image().get_size(),"Game capture cropped scene or included only subview")
	var loaded := IO.load_json(directory.path_join("preset/preset.json"))
	check(loaded.error.is_empty() and loaded.profile.crt_model==6,"Game capture did not save visible A")
	check(loaded.capture.game=="liminal" and loaded.capture.game_settings.has("hdr_brightness"),"Game context absent")
	panel.show_reference(false)
	await frames()
	check(host.presenter.preset_name=="aperture","Game A/B did not restore B")
	panel.load_preset(directory.path_join("preset/preset.json"))
	await frames()
	check(host.presenter.preset_name=="royale" and panel._controls.crt_model.selected==6,"Game load did not restore renderer and UI")
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--import-preset="): continue
		panel.load_preset(argument.trim_prefix("--import-preset="))
		await frames(8)
		check(host.presenter.signal_settings==panel.profile.signal_settings(),"Imported standalone signal differs in game")
		check(host.presenter.receiver_settings==panel.profile.receiver_settings(),"Imported standalone receiver differs in game")
	panel.close()
	await frames(4)
	check(game._video_workshop==null and game._pause_menu.visible and paused,"Done did not return to paused settings")
	game._close_settings()
	await frames(3)
	check(not paused and host.presenter.last_error.is_empty(),"Leaving workshop broke gameplay or renderer")
	current_scene.queue_free()
	await frames(5)
	print("VIDEO_WORKSHOP_AUDIT ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
