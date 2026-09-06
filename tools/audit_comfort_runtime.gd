extends "res://tools/lib/audit_base.gd"

const SEED := 405195947
const SettingsType = preload("res://scripts/game_settings.gd")

func run() -> void:
	var game := await boot_game(SEED)
	expect(game.descent and game.player != null, "Descent game did not boot")
	var settings = SettingsType.new("/tmp/liminal-comfort-audit.cfg")
	game._settings = settings
	SettingsType.current = settings
	settings.changed.connect(game._apply_game_settings)
	settings.reset_defaults()
	game._apply_game_settings()
	settings.set_value("sensitivity", 2.0)
	settings.set_value("field_of_view", 90.0)
	settings.set_value("head_bob", 0.0)
	expect(is_equal_approx(game.player.sensitivity_multiplier, 2.0), "sensitivity not applied")
	expect(is_equal_approx(game.player.base_fov, 90.0), "FOV not applied")
	expect(is_equal_approx(game.player.head_bob_strength, 0.0), "head bob not applied")

	game.run.resume_rules()
	await physics_frame
	await physics_frame
	var old_mouse := Input.mouse_mode
	var elapsed_before: float = game.run.floor_elapsed
	game._open_settings(false)
	var old_position: Vector3 = game.player.global_position
	for i in 6:
		await process_frame
	expect(game.player.global_position == old_position, "player moved while paused")
	expect(paused, "pause menu did not pause the scene tree")
	expect(is_instance_valid(game._pause_menu), "pause menu was not instantiated")
	expect(is_equal_approx(game.run.floor_elapsed, elapsed_before), "run elapsed while paused")
	game._close_settings()
	expect(not paused and Input.mouse_mode == old_mouse,
		"resume did not restore pause state and mouse mode")

	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	game._open_settings(false)
	await process_frame
	game._close_settings()
	expect(not game.player.is_processing_unhandled_input() and not game.player.is_physics_processing(),
		"resume changed tape-watch player gates")
	game.player.set_process_unhandled_input(true)
	game.player.set_physics_process(true)
	game._open_settings(true)
	await process_frame
	expect(game._pause_menu.options_only, "options-only menu was not selected")
	game._close_settings()

	var music_bus := AudioServer.get_bus_index("Music")
	var game_bus := AudioServer.get_bus_index(SoundBank.GAME_BUS)
	var was_muted := AudioServer.is_bus_mute(game_bus)
	settings.set_value("music_volume", 0.3)
	settings.set_value("effects_volume", 0.6)
	expect(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.3)), "music volume not applied")
	expect(is_equal_approx(AudioServer.get_bus_volume_db(game_bus), linear_to_db(0.6)), "effects volume not applied")
	AudioServer.set_bus_mute(game_bus, true)
	settings.set_value("effects_volume", 0.4)
	expect(AudioServer.is_bus_mute(game_bus), "effects setting overrode existing mute")
	AudioServer.set_bus_mute(game_bus, was_muted)

	var material: ShaderMaterial = game._post_process._found_footage_material
	settings.set_value("vhs_distortion", 0.0)
	var raw: Dictionary = material.get_meta("_comfort_raw_uniforms", {})
	expect(float(material.get_shader_parameter("jitter_amount")) == 0.0
		and float(material.get_shader_parameter("tear_amount")) == 0.0,
		"VHS distortion zero did not clear live material")
	settings.reset_defaults()
	expect(is_equal_approx(float(material.get_shader_parameter("jitter_amount")), float(raw.get("jitter_amount", 0.0))),
		"VHS reset did not restore raw jitter")
	settings.set_value("reduced_flashing", true)
	game._post_process.glitch_burst()
	game._post_process.damage_hit(0.5)
	game._post_process.update()
	for key: String in ["flicker_amount", "signal_loss", "rf_noise"]:
		expect(float(material.get_shader_parameter(key)) == 0.0,
			"reduced flashing left " + key)

	var television := PostProcessController.make_found_footage_material()
	settings.set_value("vhs_distortion", 0.0)
	expect(float(television.get_shader_parameter("ghost_amount")) == 0, "existing TV ignored live distortion settings")
	settings.reset_defaults()
	expect(is_equal_approx(float(television.get_shader_parameter("ghost_amount")), 0.16), "TV settings reset compounded uniform strength")
	await _exercise_menu_inputs(game)
	DirAccess.remove_absolute("/tmp/liminal-comfort-audit.cfg")
	await teardown_game(game)
	finish("comfort settings: live controls, pause/resume, audio holds, VHS scaling and multi-resolution input")


func _exercise_menu_inputs(game: Node) -> void:
	var original := root.size
	for extent in [Vector2i(1280, 720), Vector2i(640, 480), Vector2i(1920, 1080),
			Vector2i(2560, 1440), Vector2i(3456, 2186), Vector2i(3840, 2160)]:
		root.size = extent
		game._open_settings(false)
		await process_frame
		await process_frame
		var menu: PauseMenu = game._pause_menu
		var rect := menu._panel.get_global_rect()
		expect(rect.position.x >= 20 and rect.end.x <= extent.x - 20 and rect.position.y >= 20 and rect.end.y <= extent.y - 20,
			"pause panel exceeds viewport at %s: %s" % [extent, rect])
		expect(rect.size.x >= minf(500.0, float(extent.x) * 0.4)
			and rect.size.y >= float(extent.y) * 0.65,
			"pause panel is too small at %s: %s" % [extent, rect])
		var slider: HSlider = menu._controls["sensitivity"][0]
		var before := slider.value
		slider.grab_focus()
		var key := InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.physical_keycode = KEY_RIGHT
		key.pressed = true
		root.push_input(key)
		await process_frame
		expect(slider.value > before, "keyboard input did not reach pause slider")
		key.pressed = false
		root.push_input(key)
		var button := menu._resume_button
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = button.global_position + button.size * 0.5
			click.pressed = pressed
			root.push_input(click)
		await process_frame
		expect(not paused and not is_instance_valid(game._pause_menu), "Resume mouse click failed to unpause game")
	root.size = original
