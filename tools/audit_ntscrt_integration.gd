extends "res://tools/lib/audit_base.gd"
## Exercises the real saved settings, menu and Main wiring. No player saves.
## godot --headless --path . --script tools/audit_ntscrt_integration.gd -- --nologo

var change_count := 0

func run() -> void:
	root.size = Vector2i(1280, 720)
	var path := "/tmp/liminal-ntscrt-settings-%d.cfg" % OS.get_process_id()
	var settings := GameSettings.new(path)
	settings.changed.connect(func(): change_count += 1)
	expect(settings.matching_video_look() == 1 and settings.get_value("crt_shader") == GameSettings.CRT_AUTOMATIC,
		"fresh settings must use the complete Home video preset with automatic CRT quality")
	settings.set_value("video_pipeline", 1)
	settings.set_value("vhs_enabled", false)
	settings.set_value("reduced_flashing", true)
	settings.set_value("film_grain", 0.27)
	var before := settings.values.duplicate()
	change_count = 0
	settings.apply_ntscrt_preset(2)
	expect(change_count == 1, "a preset must apply as one settings transaction")
	for key: String in before:
		if not key.begins_with("ntsc_"):
			expect(settings.values[key] == before[key], "preset changed unrelated setting " + key)
	var worn := settings.values.duplicate()
	settings.apply_ntscrt_preset(2)
	expect(change_count == 1, "unchanged preset emitted another transaction")
	settings.apply_ntscrt_preset(-1)
	expect(settings.values == worn, "invalid preset changed settings")
	expect(settings.save_to_disk() == OK, "experimental settings could not save")
	var restored := GameSettings.new(path)
	for key: String in worn:
		expect(restored.values[key] == worn[key], "saved setting did not roundtrip: " + key)
	restored.set_value("ntsc_horizontal_hold", -9.0)
	restored.set_value("ntsc_signal_strength", NAN)
	restored.set_value("ntsc_decoder", 88)
	restored.set_value("ntsc_auto_faults", "false")
	expect(restored.get_value("ntsc_horizontal_hold") == -1.0, "hold value did not clamp")
	expect(restored.get_value("ntsc_signal_strength") == worn.ntsc_signal_strength,
		"nonfinite signal strength was accepted")
	expect(restored.get_value("ntsc_decoder") == worn.ntsc_decoder,
		"invalid decoder was accepted")
	expect(restored.get_value("ntsc_auto_faults") == worn.ntsc_auto_faults,
		"invalid boolean was accepted")
	for args in [["--ntscrt", "--crt-mode"], ["--crt-mode", "--ntscrt"]]:
		var options := CliOptions.parse_args(PackedStringArray(args))
		expect(options.video_pipeline_override == 1 and options.vhs_override == 0
			and options.crt_override == 1, "pipeline CLI flag changed stage choices")
	expect(CliOptions.parse_args(PackedStringArray(["--ntscrt", "--classic-video"])).video_pipeline_override == 0,
		"last pipeline CLI override did not win")
	expect(CliOptions.parse_args(PackedStringArray(["--full-ntscrt"])).video_pipeline_override == 2,
		"full signal CLI flag must select ntsc-rs")
	expect(not CliOptions.parse_args([]).video_lab and CliOptions.parse_args(["--video-lab"]).video_lab,
		"video lab must require an explicit developer launch option")
	# Player-facing looks are complete, atomic and isolated from other preferences.
	var saved_before_looks := settings.values.duplicate(true)
	for index in GameSettings.VIDEO_LOOK_NAMES.size():
		settings.set_value("ntscrs_source_resolution", true)
		settings.set_value("ntscrt_scale_mode", 2)
		settings.set_video_parameter("ntscrs", "luma_smear", 0.9)
		settings.set_crt_parameter("sim", "Tuning_Persistence_R", 0.73)
		change_count = 0
		settings.apply_video_look(index)
		expect(change_count == 1, "look must apply atomically")
		expect(settings.matching_video_look() == index, "selected look not recognized")
		expect(not settings.get_value("ntscrs_source_resolution") and settings.get_value("ntscrt_scale_mode") == 0,
			"look retained expensive source/supersampling options")
		for key: String in saved_before_looks:
			if not GameSettings.video_look_values(index).has(key):
				expect(settings.values[key] == saved_before_looks[key], "look changed unrelated setting " + key)
		expect(settings.get_value("vhs_enabled") == (index != 0), "look tape gate")
		expect(settings.get_value("crt_enabled") == (index == 1), "each look must own its TV treatment")
		expect(not settings.get_value("receiver_enabled"), "simple looks must avoid costly receiver timing")
		expect(settings.get_value("video_pipeline") == (0 if index == 0 else 2), "look pipeline")
		settings.set_value("vhs_distortion", 0.23)
		expect(settings.matching_video_look() == index, "simple adjustments lost the chosen look")
		expect(settings.save_to_disk() == OK, "look save failed")
		var loaded := GameSettings.new(path)
		expect(loaded.values == settings.values and loaded.matching_video_look() == index, "look did not roundtrip")
		settings.set_value("crt_enabled", not settings.get_value("crt_enabled"))
		expect(settings.matching_video_look() == -1, "a TV override must not masquerade as a complete preset")
		settings.apply_video_look(index)
		expect(settings.matching_video_look() == index and settings.get_value("crt_enabled") == (index == 1),
			"reselecting a look must restore its TV treatment")
		settings.set_video_parameter("ntscrs", "luma_smear", 0.8)
		expect(settings.matching_video_look() == -1, "advanced edits must show Custom")
	settings.values.merge(GameSettings.legacy_worn_tape_values(), true)
	settings.set_value("vhs_distortion", 0.73)
	settings.set_value("film_grain", 0.31)
	settings.set_value("crt_enabled", true)
	settings.save_to_disk()
	var upgraded := GameSettings.new(path)
	expect(upgraded.get_value("ntscrs_settings") == GameSettings.video_look_values(3).ntscrs_settings and not upgraded.get_value("receiver_enabled"),
		"saved legacy Worn tape must upgrade to GPU tape wear")
	expect(upgraded.matching_video_look() == -1, "preserved legacy TV/grain overrides must be identified as custom")
	for key: String in settings.values:
		if not GameSettings.video_look_values(3).has(key) or key in GameSettings.LEGACY_VIDEO_ADJUSTMENTS:
			expect(upgraded.values[key] == settings.values[key], "Worn upgrade changed preference " + key)
	settings.set_video_parameter("receiver", "ghost_level", 0.2)
	settings.save_to_disk()
	var custom := GameSettings.new(path)
	expect(custom.values == settings.values, "Worn upgrade must preserve a custom receiver configuration")
	settings.values.merge(GameSettings.legacy_home_video_values(),true)
	settings.set_value("vhs_distortion",0.27)
	settings.save_to_disk()
	var home_upgrade := GameSettings.new(path)
	expect(home_upgrade.matching_video_look() == 1 and home_upgrade.get_value("vhs_distortion") == 0.27,
		"legacy Home video should upgrade its renderer while keeping tape damage")
	settings.values.merge(GameSettings.legacy_aperture_home_video_values(),true)
	settings.set_value("vhs_distortion",0.31)
	settings.save_to_disk()
	home_upgrade = GameSettings.new(path)
	expect(home_upgrade.matching_video_look()==1 and home_upgrade.get_value("crt_shader")==GameSettings.CRT_AUTOMATIC
		and home_upgrade.get_value("vhs_distortion")==0.31,"Aperture Home upgrade lost its look or tape damage")
	settings.set_crt_parameter("aperture","GAMMA_OUTPUT",2.7)
	settings.save_to_disk()
	expect(GameSettings.new(path).values==settings.values,"Home upgrade replaced custom Aperture calibration")
	settings.set_value("crt_shader",6)
	settings.save_to_disk()
	expect(GameSettings.new(path).values == settings.values,"Home video migration changed a custom CRT")
	# Player tape and CRT controls are independent, including persistence and
	# automatic quality after turning CRT on from an old Worn tape profile.
	settings.apply_video_look(3)
	settings.set_value("vhs_distortion",0.41)
	for crt in [true,false]:
		var tape_before := settings.values.duplicate(true)
		change_count = 0
		settings.apply_crt_screen(crt)
		expect(change_count==1,"CRT screen must apply atomically")
		for key: String in GameSettings.tape_look_values(3):
			expect(settings.values[key]==tape_before[key],"CRT screen changed tape setting " + key)
		expect(settings.matching_tape_look()==3,"CRT switch lost Worn tape selection")
		for index in GameSettings.TAPE_LOOK_NAMES.size():
			var screen_before := settings.values.duplicate(true)
			change_count = 0
			settings.apply_tape_look(index)
			expect(change_count==1,"tape look must apply atomically")
			expect(settings.get_value("crt_enabled")==crt,"tape look toggled CRT")
			expect(settings.matching_tape_look()==index,"tape selection not recognized")
			for key: String in screen_before:
				if not GameSettings.tape_look_values(index).has(key):
					expect(settings.values[key]==screen_before[key],"tape changed unrelated setting " + key)
			settings.save_to_disk()
			var loaded := GameSettings.new(path)
			expect(loaded.values==settings.values and loaded.matching_tape_look()==index,
				"independent tape/CRT combination did not roundtrip")
	settings.values = saved_before_looks

	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	root.add_child(game)
	expect(not game._progress_enabled, "integration audit must not touch player progress")
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	await process_frame
	settings.set_value("video_pipeline", 0)
	settings.set_value("crt_shader",0)
	game._apply_game_settings()
	var post: PostProcessController = game._post_process
	var before_menu := settings.values.duplicate(true)
	game._open_settings(true)
	var menu: PauseMenu = game._pause_menu
	for key in ["video_pipeline", "receiver_enabled", "crt_curvature", "ntscrt_signal_width"]:
		expect(not menu._controls.has(key), "developer control exposed in player settings: " + key)
	expect(not is_instance_valid(menu._video_advanced) and not is_instance_valid(menu._full_video_controls),
		"player settings must not construct the developer video lab")
	expect(menu._look_select.item_count==21 and menu._controls.has("vhs_distortion") and menu._controls.has("crt_enabled"),
		"player settings must offer presets alongside direct tape/CRT controls")
	expect(settings.values == before_menu, "opening simplified settings changed a saved custom look")
	menu._look_select.item_selected.emit(10)
	expect(menu._look_select.selected==10 and settings.get_value("video_fault_rate")==8.0,
		"archive recording did not apply its complete signal and defects")
	menu._look_select.item_selected.emit(15)
	expect(settings.get_value("crt_enabled") and settings.get_value("vhs_enabled") and settings.get_value("crt_shader")==6,
		"living-room look did not combine recording and CRT")
	menu._look_select.item_selected.emit(1)
	expect(not settings.get_value("crt_enabled") and not settings.get_value("vhs_enabled") and menu._look_select.selected==1,
		"Clean reference did not clear both effects")
	settings.values = before_menu
	settings.changed.emit()
	game._close_settings()
	await process_frame
	game.opts.video_lab = true
	game._open_settings(true)
	menu = game._pause_menu
	expect(not menu._video_advanced.visible, "technical controls must start collapsed")
	expect(menu._video_advanced.is_ancestor_of(menu._controls["video_pipeline"]), "pipeline leaked into the simple view")
	expect(menu._video_advanced.is_ancestor_of(menu._full_video_controls), "original controls leaked into the simple view")
	expect(menu._look_select.item_count==21, "main view must offer complete looks")
	expect(not menu._controls["crt_curvature"].disabled, "lab curvature should be available with the original game TV on")
	settings.set_value("crt_enabled",false)
	expect(menu._controls["crt_curvature"].disabled, "lab curvature should be disabled with TV off")
	settings.set_value("crt_enabled",true)
	var grain_slider := menu._controls["film_grain"][0] as HSlider
	expect(grain_slider.editable, "lab grain must remain available with VHS off")
	grain_slider.value = 0.72
	expect(is_equal_approx(settings.get_value("film_grain"),0.72), "lab grain slider did not apply")
	expect(not menu._ntscrt_group.visible, "Classic shows experimental controls")
	var selector := menu._controls["video_pipeline"] as OptionButton
	selector.item_selected.emit(selector.get_item_index(1))
	expect(settings.get_value("video_pipeline") == 1 and menu._ntscrt_group.visible,
		"menu did not select and reveal the experimental pipeline")
	var experiment = post._experimental
	expect(experiment != null and experiment.visible, "menu selection did not reach Main's compositor")
	expect(not post._overlay.visible and not post._tube_display.visible and not post._scene_copy.visible,
		"Classic passes are still drawing under NTSCRT")
	expect(not experiment._signal and experiment._crt, "CRT-only inherited tape processing")
	(menu._controls["ntsc_quality"] as OptionButton).item_selected.emit(0)
	expect(experiment.buffer_size == Vector2i(360, 240), "detail selector did not resize signal buffers: %s in %s" % [experiment.buffer_size, root.get_visible_rect().size])
	(menu._controls["ntsc_chroma_delay"][0] as HSlider).value = -2.0
	expect(experiment._materials[1].get_shader_parameter("chroma_delay") == -2.0,
		"menu slider did not reach the decoder")
	(menu._controls["vhs_enabled"] as CheckButton).button_pressed = true
	expect(experiment._signal, "VHS switch did not enable experimental signal")
	(menu._controls["crt_enabled"] as CheckButton).button_pressed = false
	expect(not experiment._crt and experiment._signal, "VHS-only did not bypass the tube")
	(menu._controls["reduced_flashing"] as CheckButton).button_pressed = false
	expect(not experiment._reduced, "comfort preference did not refresh")
	settings.set_value("reduced_flashing", true)
	expect(experiment._reduced and experiment._materials[2].get_shader_parameter("reduced"),
		"reduced flashing did not reach experimental transport")
	settings.set_value("vhs_enabled", false)
	expect(not experiment.visible and post._grain_overlay.visible,
		"disabling video stages did not leave only the independent grain")
	post.set_tape_playback(true)
	expect(experiment.visible and experiment._signal and not experiment._crt,
		"ritual playback did not retain its required signal processing")
	post.set_tape_playback(false)
	expect(not experiment.visible, "ritual playback failed to restore disabled stages")
	settings.set_value("vhs_enabled", true)
	post.set_enabled(false)
	expect(not experiment.visible and not post._grain_overlay.visible,
		"temporary presentation gate left an experimental pass visible")
	post.set_enabled(true)
	expect(experiment.visible, "presentation gate did not restore experimental mode")
	post.set_corruption(0.7)
	post.set_entity_halo(Vector2(0.3, 0.4), 0.2, 0.6)
	post.damage_hit(0.8)
	post.update()
	expect(experiment._stress >= 0.8 and experiment._entity_amount == 0.6
		and experiment._entity_pos == Vector2(0.3, 0.4),
		"gameplay damage/corruption and spatial entity interference did not reach the experiment")
	settings.set_value("video_pipeline", 0)
	expect(not experiment.visible and post._overlay.visible and not menu._ntscrt_group.visible,
		"returning to Classic left experimental processing active")
	# Menu intent wins over temporary launch flags, even if a saved value is unchanged.
	game.opts.video_pipeline_override = 2
	game.opts.vhs_override = 0
	game.opts.crt_override = 1
	menu.video_overrides = {"video_pipeline": 2, "vhs_enabled": false, "crt_enabled": true}
	menu._refresh_controls()
	expect(selector.get_selected_id() == 2 and not menu._controls["vhs_enabled"].button_pressed,
		"menu must reflect the active launch overrides without saving them")
	menu._look_select.item_selected.emit(15)
	expect(game._video_pipeline_requested() == 2 and game.opts.video_pipeline_override == -1 and game.opts.vhs_override == -1 and game.opts.crt_override == -1,
		"complete look must release all video launch overrides")
	expect(menu._look_select.selected==15,"complete look did not synchronize the selector")
	menu._set_menu_value("crt_enabled",false)
	expect(game.opts.crt_override==-1 and settings.get_value("vhs_enabled"),
		"developer CRT switch lost recording state")
	settings.set_value("video_pipeline",0)
	game.opts.video_pipeline_override = 2
	menu.video_overrides["video_pipeline"] = 2
	selector.item_selected.emit(selector.get_item_index(0))
	expect(game._video_pipeline_requested() == 0 and post._overlay.visible,
		"selecting the already-saved pipeline did not override the launch flag")
	menu._look_select.item_selected.emit(1)
	expect(not post._overlay.visible and not post._grain_overlay.visible and not post._tube_display.visible,
		"Tape Off left recording stages on with CRT already off")
	expect(not (menu._controls["vhs_distortion"][0] as HSlider).editable,
		"Tape Off should explain disabled tape wear")
	settings.set_value("receiver_enabled", true)
	expect((menu._controls["vhs_distortion"][0] as HSlider).editable,
		"receiver-only tape wear must remain adjustable")
	menu._look_select.item_selected.emit(15)
	settings.apply_crt_screen(true)
	var recording_before: Dictionary = settings.get_value("ntscrs_settings").duplicate(true)
	for tier in [0,2,3,1]:
		settings.apply_quality_preset(tier)
		var active_model := 1 if tier<2 else 6
		expect(menu._crt_parameter_model==active_model,"developer controls did not follow the automatic CRT")
		expect((menu._controls["crt_shader"] as OptionButton).get_selected_id()==GameSettings.CRT_AUTOMATIC,
			"developer selector lost its explicit automatic mode")
		expect(settings.get_value("ntscrs_settings")==recording_before,"quality switching changed the selected recording")
	settings.set_value("crt_shader",1)
	settings.apply_quality_preset(3)
	expect(menu._crt_parameter_model==1,"explicit Aperture did not remain selected on Ultra")
	game._close_settings()
	await process_frame
	await teardown_game(game)
	DirAccess.remove_absolute(path)
	finish("NTSCRT saved settings, CLI, menu, stage/playback/comfort gates and gameplay feedback")
