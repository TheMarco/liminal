extends SceneTree
## Package 3.4 gate: the pinned §1.1 behavior/visual manifest. All twelve
## walker models load with walk clips, Pool Girl carries her run clip, both
## body/halo shader families answer seam clips on every pass, the hound's
## distinct scale is pinned, and all seven behavior variants construct.
## A missing model, animation, or shader fails; nothing skips.

const EXPECTED_GHOST := [false, false, false, false, true, true, true,
	true, true, true, true, true]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _run() -> void:
	_audit_manifest_tables()
	await _audit_visuals()
	_audit_behaviors()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - spatial roster holds")
		quit()
	else:
		quit(1)


func _audit_manifest_tables() -> void:
	_expect(ShadowWalkerVisual.MODEL_PATHS.size() == 12,
		"roster is not twelve: %d"
		% ShadowWalkerVisual.MODEL_PATHS.size())
	_expect(ShadowWalkerVisual.GHOST_RENDER == EXPECTED_GHOST,
		"shader family map changed")
	for i in ShadowWalkerVisual.MODEL_PATHS.size():
		_expect(ResourceLoader.exists(
			ShadowWalkerVisual.MODEL_PATHS[i]),
			"missing model %d: %s" % [i,
				ShadowWalkerVisual.MODEL_PATHS[i]])
	_expect(ShadowWalkerVisual.RUN_MODEL_PATHS.has(10),
		"Pool Girl run clip unlisted")
	_expect(ResourceLoader.exists(
		ShadowWalkerVisual.RUN_MODEL_PATHS[10]),
		"missing Pool Girl run scene")
	_expect(ShadowWalkerVisual.RUN_CYCLE_SPEEDS.has(10),
		"Pool Girl run cadence unlisted")
	_expect(ShadowWalkerVisual.MODEL_PRESCALE[9] == 100.0,
		"hound prescale changed")
	_expect(ShadowWalkerVisual.MODEL_TARGET_HEIGHTS[9] == 1.55,
		"hound stage height changed")
	_expect(ShadowWalkerVisual.SOURCE_HEIGHTS[9] == 0.75,
		"hound authored height changed")
	for theme in ShadowFigures.THEME_WALKER:
		_expect(int(ShadowFigures.THEME_WALKER[theme]) >= 0
			and int(ShadowFigures.THEME_WALKER[theme]) < 12,
			"theme %s stages outside the roster" % theme)
	_expect(ShadowFigures.DARK_ROSTER == [0, 1, 2, 3],
		"dark roster changed")
	_expect(ShadowFigures.VARIANT_W.size() == 7,
		"variant weights are not seven")
	_expect(ShadowFigure.TUNING.size() == 7, "variant tuning is not seven")
	for v in 7:
		_expect(ShadowFigure.TUNING.has(v), "variant %d untuned" % v)


func _audit_visuals() -> void:
	for i in ShadowWalkerVisual.MODEL_PATHS.size():
		var walker := ShadowWalkerVisual.new()
		walker.model_index = i
		root.add_child(walker)
		await physics_frame
		_expect(walker.get("_model") != null,
			"model %d did not build" % i)
		_expect(walker.get("_animation_player") != null
			and (walker.get("_animation_player") as AnimationPlayer)
				.has_animation(&"runtime/walk"),
			"model %d missing walk clip" % i)
		if i == 10:
			_expect(walker.has_run_cycle(),
				"Pool Girl run cycle missing")
		else:
			_expect(not walker.has_run_cycle(),
				"model %d gained an unexpected run cycle" % i)
		var ghost := bool(ShadowWalkerVisual.GHOST_RENDER[i])
		var want_body: Shader = ShadowWalkerVisual.GHOST_SHADER \
			if ghost else ShadowWalkerVisual.BODY_SHADER
		var want_halo: Shader = ShadowWalkerVisual.GHOST_HALO_SHADER \
			if ghost else ShadowWalkerVisual.HALO_SHADER
		_expect(not (walker.get("_materials") as Array).is_empty()
			and ((walker.get("_materials") as Array)[0]
				as ShaderMaterial).shader == want_body,
			"model %d on the wrong body shader" % i)
		_expect(not (walker.get("_halo_materials") as Array).is_empty()
			and ((walker.get("_halo_materials") as Array)[0]
				as ShaderMaterial).shader == want_halo,
			"model %d on the wrong halo shader" % i)
		_expect(walker.skeleton() != null
			and walker.skeleton().get_bone_count() > 0,
			"model %d has no posable skeleton" % i)
		# Every body and halo pass answers the seam clip.
		var plane := Vector4(0, 1, 0, 5.0)
		walker.set_seam_clip(plane, true)
		for material in walker.get("_materials"):
			_expect((material as ShaderMaterial)
					.get_shader_parameter(&"clip_enabled") == 1.0,
				"model %d body pass ignores the clip" % i)
			_expect((material as ShaderMaterial)
					.get_shader_parameter(&"clip_plane") == plane,
				"model %d body pass clip misplaced" % i)
		for material in walker.get("_halo_materials"):
			_expect((material as ShaderMaterial)
					.get_shader_parameter(&"clip_enabled") == 1.0,
				"model %d halo pass ignores the clip" % i)
		walker.queue_free()
		await physics_frame


func _audit_behaviors() -> void:
	var player := Player.new()
	root.add_child(player)
	await physics_frame
	for v in 7:
		var figure := ShadowFigure.new()
		figure.player = player
		figure.variant = v
		figure.walker_model_index = 0
		figure.set("_seen", true)
		root.add_child(figure)
		await physics_frame
		_expect(figure.get("_walker") != null,
			"variant %d built no visual" % v)
		_expect(figure.get("_traversal") != null,
			"variant %d built no traversal" % v)
		figure.queue_free()
		await physics_frame
	player.queue_free()
	await physics_frame
