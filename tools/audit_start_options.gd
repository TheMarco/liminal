extends "res://tools/lib/audit_base.gd"
## Exercise dispatched input, not just direct calls to Main's handlers.

func key(code: Key, physical_only := false, down := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = KEY_NONE if physical_only else code
	event.pressed = down
	event.echo = echo
	root.push_input(event)

func run() -> void:
	var plain_options := CliOptions.parse_args(PackedStringArray())
	expect(plain_options.vhs_override == -1 and plain_options.crt_override == -1,
		"plain launch unexpectedly overrides saved video preferences")
	var legacy_tape := CliOptions.parse_args(PackedStringArray(["--found-footage"]))
	expect(legacy_tape.vhs_override == 1 and legacy_tape.crt_override == 1,
		"legacy found-footage flag does not request the combined pipeline")
	var crt_only := CliOptions.parse_args(PackedStringArray(["--crt-mode"]))
	expect(crt_only.vhs_override == 0 and crt_only.crt_override == 1,
		"CRT-only QA flag does not isolate the CRT stage")
	var vhs_only := CliOptions.parse_args(PackedStringArray(["--vhs-only"]))
	expect(vhs_only.vhs_override == 1 and vhs_only.crt_override == 0,
		"VHS-only QA flag does not isolate the VHS stage")
	var clean := CliOptions.parse_args(PackedStringArray(["--nocrt"]))
	expect(clean.vhs_override == 0 and clean.crt_override == 0,
		"clean QA flag did not disable both video stages")
	var game := await boot_game(240721)
	expect(not game._progress_enabled, "audit must isolate real progress")
	game.player.set_physics_process(false)
	var path := "/tmp/liminal-start-options-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	settings.apply_quality_preset(3)
	game._apply_game_settings()
	expect(is_equal_approx(root.scaling_3d_scale, minf(480.0 / root.get_visible_rect().size.y, 1.0)),
		"CRT on did not force its 480p source at Ultra")
	game._build_title(true)
	await process_frame
	var title: TitleScreen = game._title
	var title_text := ""
	for button in title._pages[TitleScreen.Page.MAIN].find_children(
			"*", "Button", true, false):
		title_text += str(button.text) + "\n"
	expect(not title_text.contains("VHS EFFECT") and not title_text.contains("CRT EFFECT"),
		"title still exposes video-effect switches")
	expect(game._post_process.is_vhs_enabled() and game._post_process.is_crt_enabled(),
		"default did not restore the combined VHS + CRT presentation")
	expect(not game._post_process.is_curvature_enabled(),
		"default flat CRT preference did not reach the display stage")
	settings.set_value("crt_curvature", true)
	game._apply_game_settings()
	expect(game._post_process.is_crt_enabled()
		and game._post_process.is_curvature_enabled(),
		"curved CRT preference did not apply while CRT stayed on")
	settings.set_value("crt_curvature", false)
	game._apply_game_settings()
	expect(not game._post_process.is_curvature_enabled(),
		"flat CRT preference did not reapply while CRT stayed on")
	settings.set_value("crt_enabled", false)
	settings.save_to_disk()
	game._apply_game_settings()
	expect(game._post_process.is_vhs_enabled() and not game._post_process.is_crt_enabled()
		and game._post_enabled, "saved CRT switch did not isolate VHS")
	expect(is_equal_approx(root.scaling_3d_scale, 1.0), "VHS-only did not restore selected Ultra resolution")
	expect(not bool(GameSettings.new(path).get_value("crt_enabled")),
		"CRT choice was not persisted")
	settings.set_value("vhs_enabled", false)
	var graphics_scale := root.scaling_3d_scale
	settings.save_to_disk()
	game._apply_game_settings()
	expect(not game._post_process.is_vhs_enabled() and not game._post_process.is_crt_enabled()
		and not game._post_enabled, "saved VHS switch did not apply independently")
	expect(is_equal_approx(root.scaling_3d_scale, graphics_scale),
		"disabling effects changed the selected graphics resolution")
	expect(not bool(GameSettings.new(path).get_value("vhs_enabled")), "VHS choice was not persisted")
	settings.set_value("crt_enabled", true)
	settings.save_to_disk()
	game._apply_game_settings()
	expect(not game._post_process.is_vhs_enabled() and game._post_process.is_crt_enabled()
		and game._post_enabled, "saved CRT switch did not apply independently")
	expect(is_equal_approx(root.scaling_3d_scale, minf(480.0 / root.get_visible_rect().size.y, 1.0)),
		"CRT-only did not force 480p while VHS stayed off")
	expect(bool(GameSettings.new(path).get_value("crt_enabled")),
		"CRT choice was not persisted")
	expect(not game._post_process.is_curvature_enabled()
		and not bool(GameSettings.new(path).get_value("crt_curvature")),
		"flat CRT choice was lost while toggling CRT")
	game._open_settings(true)
	expect(game._pause_menu._controls.has("vhs_enabled")
		and game._pause_menu._controls.has("crt_enabled")
		and game._pause_menu._controls.has("crt_curvature"),
		"settings omitted independent video options")
	game._close_settings()
	await process_frame
	# Activate Wander through its focused button, not an action-specific shortcut.
	var wander: Button
	for button in title._pages[TitleScreen.Page.MAIN].find_children("*", "Button", true, false):
		if button.text == "WANDER":
			wander = button
	expect(wander != null, "plain Wander button missing")
	wander.grab_focus()
	key(KEY_SPACE)
	key(KEY_SPACE, false, false)
	expect(await await_until(func(): return not is_instance_valid(game._title)), "focused Wander button did not enter Wander")
	await create_timer(0.6).timeout
	for physical_only in [false, true]:
		key(KEY_ESCAPE, physical_only)
		key(KEY_ESCAPE, physical_only, false)
		await process_frame
		expect(paused and is_instance_valid(game._pause_menu) and game._pause_menu.visible,
			"Escape did not show Wander pause (physical_only=%s)" % physical_only)
		if is_instance_valid(game._pause_menu):
			expect(game._pause_menu._controls.has("vhs_enabled")
				and game._pause_menu._controls.has("crt_enabled")
				and game._pause_menu._controls.has("crt_curvature"),
				"gameplay settings omitted independent video options")
		key(KEY_ESCAPE, physical_only, true, true)
		expect(paused, "held Escape immediately dismissed pause")
		key(KEY_ESCAPE, physical_only)
		key(KEY_ESCAPE, physical_only, false)
		await process_frame
		expect(not paused and not is_instance_valid(game._pause_menu), "Escape failed to resume")
	key(KEY_V)
	key(KEY_V, false, false)
	key(KEY_B)
	key(KEY_B, false, false)
	expect(not game._post_process.is_vhs_enabled() and game._post_process.is_crt_enabled(),
		"gameplay hotkey changed saved video preferences")
	game._update_flashlight_hud()
	expect(game._charger_distance.visible and game._charger_distance.text.begins_with("CHARGER"),
		"Wander omitted charger distance")
	game._close_settings()
	await teardown_game(game)
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	finish("settings-only VHS/CRT preferences, Wander settings, and charger HUD")
