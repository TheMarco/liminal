extends "res://tools/lib/audit_base.gd"
## Presets, legacy/custom persistence, authored-floor restoration and real menu
## layout/input. --capture-ui saves native renders without opening Codex panels.
const QUALITY = preload("res://scripts/graphics_quality.gd")
const REALM = preload("res://scripts/realm_excursion.gd")

func settle() -> void:
	for i in 6:
		await process_frame

func tap(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)

func capture_crt_modes(settings: GameSettings) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capture-crt"):
		return
	root.title = "Liminal — CRT resolution check"
	root.size = Vector2i(1920,1080)
	settings.apply_quality_preset(2)
	settings.set_value("render_resolution", 4)
	for mode in [["crt", false, true], ["clean", false, false], ["vhs", true, false], ["vhs-crt", true, true]]:
		settings.set_value("vhs_enabled", mode[1])
		settings.set_value("crt_enabled", mode[2])
		await settle()
		var source_height := root.get_visible_rect().size.y * root.scaling_3d_scale
		expect(is_equal_approx(source_height, 480.0 if mode[2] else root.get_visible_rect().size.y), "wrong native capture resolution: " + mode[0])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/crt-480p/%s.png" % mode[0])
		print("CRT_CAPTURE %s source_height=%.1f saved_resolution=1440p" % [mode[0], source_height])
	root.size = Vector2i(1280,720)
	await settle()

func run() -> void:
	var path := "/tmp/liminal-quality-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	var notifications: Array[int] = []
	settings.changed.connect(func(): notifications.append(1))
	settings.set_value("vhs_enabled", false)
	settings.set_value("handheld_camera", false)
	settings.set_value("reduced_flashing", true)
	settings.set_binding("interact", KEY_T)
	for preset in 4:
		notifications.clear()
		settings.apply_quality_preset(preset)
		expect(notifications.size() == 1, "preset was not one atomic change")
		expect(settings.matching_quality_preset() == preset, "preset fields do not match")
		expect(not settings.get_value("vhs_enabled") and not settings.get_value("handheld_camera")
			and settings.get_value("reduced_flashing") and settings.get_binding("interact") == KEY_T,
			"preset changed presentation, comfort or bindings")
		expect(settings.save_to_disk() == OK, "preset save failed")
		var restored := GameSettings.new(path)
		expect(restored.values == settings.values, "preset did not roundtrip")
	settings.set_value("render_resolution", 3)
	expect(settings.get_value("quality_preset") == 4, "override did not select Custom")
	settings.save_to_disk()
	expect(GameSettings.new(path).values == settings.values, "Custom did not roundtrip")
	var before := settings.values.duplicate()
	for invalid in [-1, 99, NAN, INF, 1.5, true, "2"]:
		settings.set_value("global_illumination", invalid)
	settings.apply_quality_preset(99)
	expect(settings.values == before, "invalid enum changed settings")
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "sensitivity", 1.72)
	legacy.set_value("settings", "film_grain", 0.83)
	legacy.set_value("settings", "quality_preset", 99)
	legacy.set_value("settings", "shadow_quality", -1)
	legacy.set_value("settings", "frame_limit", INF)
	legacy.save(path)
	var migrated := GameSettings.new(path)
	expect(is_equal_approx(migrated.get_value("sensitivity"), 1.72)
		and is_equal_approx(migrated.get_value("film_grain"), 0.83)
		and migrated.get_value("quality_preset") == 1 and migrated.get_value("frame_limit") == 60,
		"legacy/corrupt migration lost preferences or safe defaults")
	DirAccess.remove_absolute(path)
	for theme in WorldGen.THEMES:
		var environment := EnvBuilder.build(int(theme))
		var authored := {}
		for key in QUALITY.AUTHORED_KEYS:
			authored[key] = environment.get(key)
		var exposure := environment.tonemap_exposure
		var ambient := environment.ambient_light_energy
		settings.apply_quality_preset(0)
		QUALITY.apply_environment(environment, settings)
		expect(not environment.sdfgi_enabled and not environment.ssao_enabled
			and not environment.ssr_enabled and not environment.volumetric_fog_enabled,
			"Low retained expensive passes on theme %s" % theme)
		expect(environment.fog_enabled and environment.glow_enabled,
			"Low lost authored distance fog or emissive glow")
		settings.apply_quality_preset(3)
		QUALITY.apply_environment(environment, settings)
		for key in authored:
			expect(environment.get(key) == authored[key], "Low→Ultra did not restore %s on theme %s" % [key, theme])
		expect(environment.tonemap_exposure == exposure and environment.ambient_light_energy == ambient,
			"quality changed authored exposure/fill")
	# Exercise the real startup/apply path and a cached realm source/destination.
	var game := await boot_game(1315734997)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game.player.set_physics_process(false)
	var saved_extent := root.size
	root.size = Vector2i(1280, 720)
	await settle()
	settings.set_value("crt_enabled", false)
	for preset in [0, 1, 2, 3, 0]:
		settings.apply_quality_preset(preset)
		game._apply_game_settings()
		expect(is_equal_approx(root.scaling_3d_scale, [0.5, 2.0 / 3.0, 1.0, 1.0][preset]), "preset selected wrong world resolution")
		expect(root.scaling_3d_scale <= 1.0 and root.scaling_3d_scale > 0.0, "invalid runtime resolution")
		expect(root.msaa_3d == (Viewport.MSAA_4X if preset == 3 else Viewport.MSAA_DISABLED), "runtime MSAA mismatch")
		expect(root.use_taa == (preset >= 2 and not game.opts.notaa), "runtime TAA mismatch")
		expect(game.we.environment.sdfgi_enabled == (preset >= 2), "live GI toggle mismatch")
		var destination: Environment = game._build_env(8)
		expect(destination.sdfgi_enabled == (preset >= 2), "new floor ignored quality")
		var scale := root.scaling_3d_scale
		var saved_resolution: int = settings.get_value("render_resolution")
		settings.set_value("vhs_enabled", not bool(settings.get_value("vhs_enabled")))
		expect(root.scaling_3d_scale == scale, "VHS changed graphics resolution")
		settings.set_value("crt_enabled", true)
		expect(is_equal_approx(root.scaling_3d_scale, 2.0 / 3.0), "CRT did not force a 480p source")
		settings.set_value("vhs_enabled", not bool(settings.get_value("vhs_enabled")))
		expect(is_equal_approx(root.scaling_3d_scale, 2.0 / 3.0), "VHS toggle broke the CRT cap")
		settings.set_value("crt_enabled", false)
		expect(root.scaling_3d_scale == scale and settings.get_value("render_resolution") == saved_resolution,
			"CRT toggle did not restore the saved resolution")
		expect(game.we.environment.sdfgi_enabled == (preset >= 2), "CRT changed lighting quality")
	# CLI presentation overrides must use their effective state, leaving the
	# player's saved CRT preference and resolution untouched.
	game.opts.crt_override = 1
	game._apply_game_settings()
	expect(is_equal_approx(root.scaling_3d_scale, 2.0 / 3.0), "CRT QA override missed 480p")
	game.opts.crt_override = 0
	game._apply_game_settings()
	expect(is_equal_approx(root.scaling_3d_scale, 0.5), "clean QA override retained CRT cap")
	game.opts.crt_override = -1
	game._apply_game_settings()
	await capture_crt_modes(settings)
	settings.set_value("frame_limit", 30)
	expect(Engine.max_fps == 30, "frame cap was not applied")
	settings.set_value("frame_limit", 60)
	var realm := REALM.new()
	realm._source["env"] = game._build_env(0)
	realm._preview_environment = WorldEnvironment.new()
	realm._preview_environment.environment = game._build_env(7)
	realm.preview = SubViewport.new()
	realm.preview.size = Vector2i(960,600)
	settings.apply_quality_preset(3)
	realm.refresh_graphics_quality(settings)
	expect(realm._source.env.sdfgi_enabled and realm._preview_environment.environment.sdfgi_enabled,
		"cached realm environments retained old quality")
	expect(realm.preview.msaa_3d == Viewport.MSAA_4X and realm.preview.use_taa
		and realm.preview.scaling_3d_scale == 1.0, "preview missed quality or was downscaled twice")
	realm.preview.free()
	realm._preview_environment.free()
	realm.free()
	settings.apply_quality_preset(1)
	settings.set_value("crt_enabled", true)
	game._open_settings(false)
	await settle()
	var menu: PauseMenu = game._pause_menu
	var resolution := menu._controls["render_resolution"] as OptionButton
	expect(resolution.disabled and resolution.get_selected_id() == 1, "CRT resolution selector does not show its locked 480p override")
	var expected_tabs := {"render_resolution": "Graphics", "fullscreen": "Graphics", "hdr_enabled": "Graphics",
		"vhs_enabled": "Visual Effects", "film_grain": "Visual Effects", "sensitivity": "Controls",
		"invert_y": "Controls", "dialogue_volume": "Audio", "head_bob": "Accessibility",
		"story_subtitles": "Accessibility", "reduced_flashing": "Accessibility"}
	for key in expected_tabs:
		var control: Control = menu._controls[key][0] if menu._controls[key] is Array else menu._controls[key]
		expect(menu._pages[expected_tabs[key]].is_ancestor_of(control), "wrong tab for " + key)
	for extent in [Vector2i(640,480), Vector2i(720,1280), Vector2i(1280,720), Vector2i(3456,2234), Vector2i(3840,2160)]:
		root.size = extent
		await settle()
		expect(is_equal_approx(root.get_visible_rect().size.y * root.scaling_3d_scale, 480.0), "CRT cap lost on resize")
		var bounds := Rect2(Vector2.ZERO, Vector2(extent))
		for tab: String in menu.TABS:
			menu._select_tab(tab)
			await settle()
			expect(bounds.encloses(menu._panel.get_global_rect()), "panel clips at %s / %s" % [extent, tab])
			expect(bounds.encloses(menu._resume_button.get_global_rect()), "resume clips")
			for name in menu.TABS:
				expect(menu._tab_buttons[name].is_visible_in_tree()
					and bounds.encloses(menu._tab_buttons[name].get_global_rect()), "tab inaccessible")
			var visible_pages := 0
			for page: ScrollContainer in menu._pages.values():
				visible_pages += int(page.visible)
			expect(visible_pages == 1, "tabs did not isolate one page")
			if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--capture-ui") \
					and extent in [Vector2i(640,480), Vector2i(1280,720), Vector2i(3456,2234)]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/settings-overhaul/%s-%dx%d.png" % [tab.replace(" ", "-"), extent.x, extent.y])
	root.size = Vector2i(1280,720)
	menu._select_tab("Graphics")
	await settle()
	menu._tab_buttons["Visual Effects"].grab_focus()
	tap(KEY_ENTER)
	expect(menu._current_tab == "Visual Effects", "keyboard did not switch tabs")
	menu._select_tab("Graphics")
	menu._advanced_button.grab_focus()
	tap(KEY_ENTER)
	await settle()
	expect(menu._advanced.visible, "advanced rendering did not expand")
	menu._controls["volumetric_fog"].grab_focus()
	await settle()
	expect(menu._scroll.get_global_rect().grow(1).encloses(menu._controls["volumetric_fog"].get_global_rect()), "focused advanced option was not scrolled into view")
	if DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--capture-ui"):
		menu._scroll.scroll_vertical = 0
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/settings-overhaul/Graphics-advanced.png")
	menu._preset_buttons[2].grab_focus()
	tap(KEY_ENTER)
	expect(settings.get_value("quality_preset") == 2, "keyboard did not activate preset")
	expect(resolution.disabled and resolution.get_selected_id() == 1
		and settings.get_value("render_resolution") == 2, "preset changed the CRT override or discarded saved resolution")
	settings.set_value("crt_enabled", false)
	expect(not resolution.disabled and resolution.get_selected_id() == 2, "CRT off did not unlock and restore saved resolution in UI")
	menu._controls["render_resolution"].item_selected.emit(3)
	expect(settings.get_value("quality_preset") == 4 and menu._quality_status.text.begins_with("CUSTOM"), "UI override did not mark Custom")
	menu._select_tab("Controls")
	(menu._binding_buttons["return_to_title"] as Button).grab_focus()
	await settle()
	expect(menu._scroll.get_global_rect().grow(1).encloses(menu._binding_buttons["return_to_title"].get_global_rect()), "last binding was not reachable by scrolling")
	menu._start_capture("interact")
	menu._select_tab("Audio")
	expect(menu._capturing.is_empty(), "tab switch retained hidden key capture")
	game._close_settings()
	root.size = saved_extent
	DirAccess.remove_absolute(path)
	await teardown_game(game)
	finish("graphics quality: presets, persistence, authored floors, CRT 480p / VHS-only resolution, live rendering, cached realms and five tab layouts")
