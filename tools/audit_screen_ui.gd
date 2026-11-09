extends "res://tools/lib/audit_base.gd"
## Native pixel/input regression: recorded gameplay HUD, crisp menus/dialogs.
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const UI = preload("res://scripts/screen_ui.gd")
const OUT := "res://build/ntscrt-review/screen-ui/"
var game: Node
var output_dir := OUT

func frames(count := 4) -> void:
	for i in count:
		await process_frame
	# A paused, unchanged menu may stop automatic redraws on macOS. Render the
	# requested capture explicitly instead of waiting forever for another draw.
	RenderingServer.force_draw()

func snapshot(label: String) -> Image:
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: image.linear_to_srgb()
	image.save_png(output_dir+label+".png")
	return image

func click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion,true)
	# Keep the synthetic click together: a real desktop pointer update between
	# down/up can otherwise cancel the button even though both test positions match.
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await process_frame

func key(code: Key, viewport: Viewport = null) -> void:
	if viewport==null: viewport = root
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		viewport.push_input(event,true)
		await process_frame

func button_named(parent: Node, label: String) -> Button:
	for button in parent.find_children("*","Button",true,false):
		if button.text == label: return button
	return null

func choose_look(menu: PauseMenu, item: int) -> void:
	# Native PopupMenu keyboard events run before Viewport.push_input, so activate
	# its public item signal here; the menu's normal OptionButton wiring applies it.
	menu._look_select.get_popup().index_pressed.emit(item)
	await frames(2)


func run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU and --nologo")
		finish()
		return
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var host := HOST.new()
	root.add_child(host)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	var settings := GameSettings.new("/tmp/liminal-screen-ui-%d.cfg" % OS.get_process_id())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--language="):
			settings.set_value("language", Localization.normalize(arg.get_slice("=", 1)))
			output_dir = OUT + Localization.current_locale() + "/"
	settings.apply_quality_preset(0)
	settings.set_value("handheld_camera",false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	expect(not game._progress_enabled,"UI audit must not save campaign progress")
	await frames(60)
	if is_instance_valid(game._pause_menu): game._close_settings()
	game.set_process(false)
	game.cm.set_process(false)
	game._figures.set_physics_process(false)
	stop_audio(game)
	DirAccess.make_dir_recursive_absolute(output_dir)
	expect(game._osd_layer.custom_viewport==null and game._osd_layer.get_viewport()==host.source,
		"gameplay HUD bypasses the recording")
	expect(game._photo_camera.custom_viewport==null and game._photo_camera.get_viewport()==host.source,
		"camera viewfinder bypasses the recording")
	var descent_hud := DescentHUD.new()
	game.add_child(descent_hud)
	expect(descent_hud.custom_viewport==null and descent_hud.get_viewport()==host.source,
		"Descent objectives bypass the recording")
	descent_hud.queue_free()
	var effect_layer: int = game._post_process._overlay.get_parent().layer
	expect(effect_layer > game._osd_layer.layer and effect_layer < 4,
		"compatibility filters must follow the HUD and precede modal screens")
	expect(game._reality_aftershock.layer < game._post_process._overlay.get_parent().layer,
		"world effects are out of order")
	# A real interaction prompt, backed by an opaque panel for an exact pixel
	# comparison that excludes the intentionally changing game world behind it.
	game._interact_hint.text = "E — query terminal"
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.02,0.025,0.03,1.0)
	game._interact_panel.add_theme_stylebox_override("panel",backing)
	game._interact_panel.show()
	await frames()
	var prompt_rect := Rect2i(game._interact_panel.get_global_rect()).grow(-2)
	var reference: PackedByteArray
	for look in [0,1,2,3]:
		settings.apply_video_look(look)
		settings.set_value("ntsc_auto_faults",false)
		await frames(12)
		var image := snapshot("game-look-%d" % look)
		var pixels := image.get_region(prompt_rect).get_data()
		if look==0: reference = pixels
		else: expect(pixels!=reference,"recording look %d bypassed gameplay text" % look)
	host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,
		{"sequence":"two_blips","sequence_strength":1.0,"phase":0.752,"amount":0.7,"kind":0})
	await frames()
	expect(snapshot("game-glitch").get_region(prompt_rect).get_data()!=reference,
		"the glitched recording bypassed gameplay text")
	# Classic and native approximation must also include the gameplay HUD.
	for pipeline in [0,1]:
		settings.set_value("video_pipeline",pipeline)
		settings.set_value("crt_shader",0)
		settings.set_value("crt_enabled",true)
		await frames(12)
		expect(snapshot("game-pipeline-%d" % pipeline).get_region(prompt_rect).get_data()!=reference,
			"pipeline %d bypassed the interaction prompt" % pipeline)
	settings.apply_quality_preset(2)
	settings.apply_video_look(1)
	await frames(20)
	expect(host.presenter.preset_name=="royale","High Home video did not activate Royale")
	expect(snapshot("game-home-royale").get_region(prompt_rect).get_data()!=reference,
		"Royale bypassed the interaction prompt")
	expect(game._post_process._using_slang() and not game._post_process._tube_display.visible,
		"automatic Royale stacked with the legacy TV effect")
	# A separately rendered photo must keep its own canvas; it is not window UI.
	var offscreen := SubViewport.new()
	game.add_child(offscreen)
	var embedded := UI.new()
	offscreen.add_child(embedded)
	expect(embedded.custom_viewport==null,"offscreen photo UI escaped into the window")
	offscreen.queue_free()
	game._build_title(true)
	game._title.set_process(false)
	await frames()
	expect(game._title.custom_viewport==root,"title is still filtered")
	expect(not game.get_node("ReadableGameText").visible, "readable HUD overlaps the title")
	# Compare opaque title UI, not the live filtered room visible behind it.
	var title_roi := Rect2i(game._title._primary_button.get_global_rect()).grow(-2)
	var title_reference: PackedByteArray
	for look in [0,1,3]:
		settings.apply_video_look(look)
		await frames(12)
		var pixels := snapshot("title-look-%d" % look).get_region(title_roi).get_data()
		if look==0: title_reference = pixels
		else: expect(pixels==title_reference,"look %d changed the title screen" % look)
	await click(button_named(game._title,"INSTRUCTIONS"))
	expect(game._title._current_page==TitleScreen.Page.INSTRUCTIONS,"title mouse input missed its canvas")
	await frames()
	snapshot("instructions")
	await key(KEY_ESCAPE)
	expect(game._title._current_page==TitleScreen.Page.MAIN,"title Escape did not return")
	var settings_button := button_named(game._title,"SETTINGS")
	settings_button.grab_focus()
	await key(KEY_ENTER)
	expect(is_instance_valid(game._pause_menu),"title keyboard activation missed its canvas")
	if is_instance_valid(game._pause_menu):
		expect(game._pause_menu.custom_viewport==root,"settings menu is still filtered")
		await frames()
		snapshot("settings")
		var menu: PauseMenu = game._pause_menu
		menu._select_tab("Visual Effects")
		await frames()
		await choose_look(menu,15)
		await frames(20)
		expect(menu._look_select.selected==15 and host.presenter.signal_enabled and host.presenter.preset_name=="royale",
			"complete living-room look did not apply both renderers")
		snapshot("settings-complete-look")
		await choose_look(menu,19)
		await frames(12)
		expect(not host.presenter.signal_enabled and host.presenter.visible and host.presenter.preset_name=="hyllian",
			"CRT viewfinder did not disable tape")
		await choose_look(menu,1)
		await frames(12)
		expect(not host.presenter.visible and menu._look_select.selected==1,
			"Clean reference left the GPU presenter active")
		await key(KEY_ESCAPE)
		expect(not is_instance_valid(game._pause_menu),"settings Escape did not close")
	expect(host.presenter.last_error.is_empty(),host.presenter.last_error)
	await teardown_game(game)
	finish("filtered gameplay HUD/prompts, crisp title/settings, offscreen ownership, mouse and keyboard")
