extends SceneTree
## Run externally against an exported Mac PCK or Windows/Linux embedded-PCK executable:
## godot --headless --main-pack <pack> --script /absolute/path/to/this/script
## The editor/source project must NOT supply res:// during this check.

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_verify")

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)

func _verify() -> void:
	_expect(not FileAccess.file_exists("res://export_presets.cfg"), "source tree leaked into pack check")
	for path in ["res://scripts/main.gd", "res://scripts/caught_sequence.gd",
			"res://scripts/levels/school_level_builder.gd", "res://scripts/levels/brutalist_level_builder.gd",
			"res://textures/annex/half_wall_cap_wood.png", "res://scenes/main.tscn"]:
		_expect(ResourceLoader.exists(path), "missing packed runtime resource: " + path)
	_expect(FileAccess.file_exists("res://models/authored/pool_equipment/collision.json"),
		"pool-equipment collision data absent")
	_expect(FileAccess.file_exists("res://THIRD_PARTY_ASSETS.md"), "asset credits absent")
	var walker_script = load("res://scripts/shadow_walker_visual.gd")
	_expect(walker_script != null, "animated monster presentation absent")
	if walker_script != null:
		_expect(walker_script.MODEL_PATHS.size() == 12, "supplied shadow walker roster incomplete")
		for path in walker_script.MODEL_PATHS:
			_expect(ResourceLoader.exists(path), "monster GLB missing from pack: " + path)
		for path in walker_script.RUN_MODEL_PATHS.values():
			_expect(ResourceLoader.exists(path), "monster run GLB missing from pack: " + path)
		_expect(walker_script.WALK_CYCLE_SPEEDS == [1.98, 1.98, 1.98, 1.965,
			1.85, 1.65, 1.82, 1.72, 1.72, 1.98, 1.755, 1.72],
			"measured monster stride calibration missing or stale")
		_expect(walker_script.RUN_CYCLE_SPEEDS == {10: 1.73},
			"measured Pool Girl run calibration missing or stale")
	_expect(ResourceLoader.exists("res://shaders/shadow_walker.gdshader"),
		"animated monster shader absent")
	var options = load("res://scripts/cli_options.gd").parse_args([])
	_expect(not options.test_mode,
		"release defaults do not start with test mode off")
	var pursuer = load("res://scripts/shadow_figure.gd").new()
	pursuer.completed_levels = 1
	_expect(is_equal_approx(pursuer.pursuit_speed(true, 10.0), 1.25 * 1.03),
		"per-floor enemy speed progression missing")
	pursuer.walker_model_index = 10
	_expect(is_equal_approx(pursuer.pursuit_speed(true, 10.0), 2.1 * 1.03),
		"halved Pool Girl deck run speed missing")
	pursuer.free()
	for folder in ["res://art/ending_outside", "res://deliverables/ending_cutscene_final_kit",
			"res://models/cc_by_nc", "res://textures/cc_by_nc", "res://prototypes_shelved",
			"res://tools"]:
		_expect(not DirAccess.dir_exists_absolute(folder), "development/deprecated resources bundled: " + folder)
	for i in range(1, 6):
		_expect(ResourceLoader.exists("res://paintings/runtime/painting%d-vegas.webp" % i),
			"Vegas portrait missing from pack")
	var chunk_script = load("res://scripts/chunk.gd")
	_expect(chunk_script != null and is_equal_approx(chunk_script.SCH_DESK_COL_PITCH, 2.0)
		and is_equal_approx(chunk_script.SCH_DESK_ROW_PITCH, 2.0), "old school desk spacing in binary")
	var sequence_script = load("res://scripts/caught_sequence.gd")
	_expect(sequence_script != null and is_equal_approx(sequence_script.DURATION, 2.50)
		and is_equal_approx(sequence_script.FLOOR_EYE_HEIGHT, 0.23)
		and is_equal_approx(sequence_script.LEAN, 0.42),
		"caught sequence missing or stale")
	_expect(is_equal_approx(chunk_script.CASINO_SLOT_SCALE, 0.82)
		and is_equal_approx(chunk_script.CASINO_SLOT_SIGN_HEADROOM, 0.76),
		"slot-machine scale/sign clearance is stale")
	var mats_script = load("res://scripts/mats.gd")
	var source_material := StandardMaterial3D.new()
	source_material.emission_enabled = true
	source_material.emission_energy_multiplier = 2.0
	var standby = mats_script.casino_slot_standby(source_material)
	_expect(standby != source_material and is_equal_approx(standby.emission_energy_multiplier, 0.36),
		"slot-machine standby material is stale")
	root.size = Vector2i(1280, 720)
	var run_script = load("res://scripts/descent_run.gd")
	_expect(run_script.death_explanation(run_script.DeathCause.FIGURE) ==
		"IT HAS YOU NOW.\nKEEP DISTANCE AND USE THE TORCH.", "old caught message in binary")
	var summary = load("res://scripts/descent_summary.gd").new()
	summary.elapsed = 39.0
	root.add_child(summary)
	_expect(summary._labels[1][0].text == "00:39", "obsolete rule-break count in binary")
	summary.free()
	var title = load("res://scripts/title.gd").new()
	root.add_child(title)
	_expect(title._primary_button.text == "DESCENT", "old title shortcut labels in binary")
	title._select_descent()
	_expect(title._descent_start_button.disabled, "Descent start lacks preparation gate")
	title.set_descent_ready()
	_expect(title._descent_start_button.text == "DESCEND" and not title._descent_start_button.disabled,
		"rule screen lacks the new start button")
	title.free()
	var ghost: Shader = load("res://shaders/ghost_layered.gdshader")
	_expect(ghost != null and ghost.code.contains("dark_readability"), "old ghost visibility shader in binary")
	var wallpaper: Shader = load("res://shaders/wallpaper.gdshader")
	_expect(wallpaper != null and wallpaper.code.contains("wood_tex")
		and not wallpaper.code.contains("bump_strength"), "old Vegas wallpaper in binary")
	var worldgen = load("res://scripts/world_gen.gd")
	var ws: int = worldgen.level_seed(918273, 10)
	var station_cells := 0
	for x in 3:
		for z in 3:
			var chunk = chunk_script.new(ws, Vector2i(x, z), 10)
			station_cells += int(chunk._is_charging_station_cell())
			chunk.free()
	_expect(station_cells == 2, "extra Data Center charging point missing from exported code")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_expect(main_scene != null, "packed main scene does not load")
	chunk_script.clear_runtime_caches()
	load("res://scripts/mats.gd").clear_runtime_caches()
	load("res://scripts/sound_bank.gd")._c.clear()
	load("res://scripts/sfx.gd")._c.clear()
	await process_frame
	await create_timer(0.1).timeout
	for issue in failures:
		printerr("PACK_VERIFY FAIL: " + issue)
	if failures.is_empty():
		print("PACK_VERIFY PASS: latest compiled gameplay, shaders, assets and export exclusions")
	quit(0 if failures.is_empty() else 1)
