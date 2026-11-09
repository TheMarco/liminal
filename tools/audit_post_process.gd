extends SceneTree
## Headless state audit for independent VHS-signal and CRT-display stages.

const CONTROLLER := preload("res://scripts/post_process_controller.gd")

var failures: Array[String] = []

class FaultPresenter extends TextureRect:
	var signal_enabled := true
	var signal_settings := {}
	var receiver_settings := {}
	var game_state := {}
	var _clock := 0.0

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func approx(value: Variant, expected: Variant, tolerance := 0.0001) -> bool:
	return typeof(value) == typeof(expected) and absf(float(value) - float(expected)) <= tolerance

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var controller := CONTROLLER.new()
	host.add_child(controller)
	controller.setup(host)
	controller.ensure_scene_copy()
	var full_material: ShaderMaterial = controller._found_footage_material
	expect(controller._overlay.visible, "default VHS stage is hidden")
	expect(controller._tube_display != null and controller._tube_display.visible,
		"default CRT stage is hidden")
	expect(controller._scene_copy.visible, "default VHS stage did not retain its scene copy")
	expect(not controller._grain_copy.visible and not controller._grain_overlay.visible,
		"film grain should remain off until the saved preference is applied")
	expect(controller._grain_overlay.get_index() < controller._tube_display.get_index(),
		"film grain should be part of the signal before CRT display")
	controller.set_film_grain_intensity(0.68)
	expect(controller._grain_copy.visible and controller._grain_overlay.visible,
		"film grain pass did not enable")
	expect(approx((controller._grain_overlay.material as ShaderMaterial).get_shader_parameter(
		"intensity"), 0.68), "film grain slider did not reach the shader")
	controller.set_effects(false, false)
	expect(controller._grain_overlay.visible and controller.is_enabled(),
		"film grain should work with VHS and CRT disabled")
	controller.set_film_grain_intensity(0.0)
	expect(not controller._grain_copy.visible and not controller._grain_overlay.visible,
		"zero film grain did not remove the pass")
	controller.set_video_pipeline(2,{"video_color_saturation":0.0,"video_color_shadow_lift":0.03})
	expect(controller._grain_overlay.visible and controller.is_enabled(),"Camera grading needs to work without tape, CRT or grain")
	expect(controller._grain_overlay.material.get_shader_parameter("color_saturation")==0.0,"Camera saturation did not reach shared pass")
	controller.set_enabled(false)
	expect(not controller._grain_overlay.visible,"Disabled presentation left camera grading on menus")
	controller.set_enabled(true)
	controller.set_video_pipeline(0,{})
	expect(not controller._grain_overlay.visible,"Neutral camera response did not bypass shared pass")
	controller.set_effects(true, true)
	expect(controller._tube_display.get_child_count() == 2, "tube display pass has wrong child count")
	var tube_copy: BackBufferCopy = controller._tube_display.get_child(0)
	var tube_face: ColorRect = controller._tube_display.get_child(1)
	expect(tube_copy.name == "TapeSignalCopy" and tube_face.name == "Display", "tube pass ordering or names are wrong")
	expect(tube_copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "tube copy is not viewport mode")
	expect((tube_face.material as ShaderMaterial).shader == CONTROLLER.CRT_DISPLAY_SHADER, "tube display shader mismatch")
	var tube_material := tube_face.material as ShaderMaterial
	expect(tube_material.get_shader_parameter("curvature_enabled") == false,
		"CRT curvature should default off")
	controller.set_curvature_enabled(true)
	expect(controller.is_curvature_enabled()
		and tube_material.get_shader_parameter("curvature_enabled") == true,
		"curved CRT did not enable the warp")
	controller.set_curvature_enabled(false)
	expect(not controller.is_curvature_enabled()
		and tube_material.get_shader_parameter("curvature_enabled") == false
		and controller._tube_display.visible,
		"flat CRT did not retain the display stage")
	expect(full_material.get_shader_parameter("tape_signal") == true, "full-screen tape_signal is not true")
	expect(full_material.get_shader_parameter("resolution") == CONTROLLER.FOUND_FOOTAGE_RESOLUTION, "full-screen resolution mismatch")
	var tv_material := CONTROLLER.make_found_footage_material(CONTROLLER.TV_TAPE_RESOLUTION)
	expect(tv_material.get_shader_parameter("tape_signal") == true, "TV tape_signal is not true")
	expect(tv_material.get_shader_parameter("resolution") == CONTROLLER.TV_TAPE_RESOLUTION, "TV resolution mismatch")

	controller.set_effects(false, false)
	expect(not controller._overlay.visible and not controller._tube_display.visible
		and not controller._scene_copy.visible,
		"both disabled did not reveal clean rendering")
	controller.set_effects(false, true)
	expect(not controller._overlay.visible and controller._tube_display.visible,
		"CRT-only combination is not independent")
	expect(tube_material.get_shader_parameter("curvature_enabled") == false,
		"CRT-only mode restored curvature unexpectedly")
	controller.set_effects(true, false)
	expect(controller._overlay.visible and not controller._tube_display.visible,
		"VHS-only combination is not independent")
	controller.set_effects(true, true)
	expect(controller._overlay.visible and controller._tube_display.visible,
		"combined VHS + CRT pipeline is not stacked")
	controller.set_curvature_enabled(true)
	expect(controller.is_curvature_enabled()
		and tube_material.get_shader_parameter("curvature_enabled") == true,
		"curved CRT mode did not restore the warp")
	controller.set_enabled(false)
	expect(not controller.is_enabled() and not controller._overlay.visible
		and not controller._tube_display.visible and not controller._scene_copy.visible,
		"temporary presentation gate did not hide both stages")
	expect(controller.is_vhs_enabled() and controller.is_crt_enabled(),
		"temporary presentation gate overwrote stage preferences")
	controller.set_enabled(true)
	expect(controller._overlay.visible and controller._tube_display.visible,
		"temporary presentation gate did not restore both stages")
	controller.set_tape_playback(true)
	expect(controller._overlay.visible and controller._tube_display.visible,
		"tape playback changed enabled stages")
	controller.set_tape_playback(false)
	expect(controller._overlay.visible and controller._tube_display.visible,
		"tape playback release changed enabled stages")
	controller.set_effects(false, false)
	controller.set_tape_playback(true)
	expect(controller._overlay.visible and not controller._tube_display.visible,
		"playback should force VHS without overriding the CRT preference")
	expect(controller._overlay.material == controller._found_footage_material, "playback replaced the game shader")
	expect(not controller.is_vhs_enabled() and not controller.is_crt_enabled(),
		"playback overwrote normal video preferences")
	controller.set_tape_playback(false)
	expect(not controller._overlay.visible and not controller._tube_display.visible, "playback did not restore disabled preference")
	controller.set_effects(true, false)
	var tv_parent := Control.new()
	host.add_child(tv_parent)
	var tv_display := CONTROLLER.add_crt_display_pass(tv_parent, CONTROLLER.TV_TAPE_RESOLUTION)
	expect(tv_display.get_child(0) is BackBufferCopy and tv_display.get_child(1) is ColorRect, "TV pass child types/order mismatch")
	expect((tv_display.get_child(0) as BackBufferCopy).copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "TV copy is not viewport mode")
	var tv_face_material := (tv_display.get_child(1) as ColorRect).material as ShaderMaterial
	expect(tv_face_material.shader == CONTROLLER.CRT_DISPLAY_SHADER, "TV display shader mismatch")
	expect(tv_face_material.get_shader_parameter("signal_resolution") == CONTROLLER.TV_TAPE_RESOLUTION, "TV display resolution mismatch")
	expect(tv_face_material.get_shader_parameter("curvature_enabled") == true,
		"player curvature preference changed in-world TV glass")
	expect(CONTROLLER.TV_TAPE_RESOLUTION == Vector2(344.0, 240.0), "TV tape resolution changed")
	var tv_baseline := {
		"noise_level": tv_material.get_shader_parameter("noise_level"),
		"line_noise": tv_material.get_shader_parameter("line_noise"),
		"dropout_amount": tv_material.get_shader_parameter("dropout_amount"),
		"head_switch_amount": tv_material.get_shader_parameter("head_switch_amount"),
		"tape_speckle": tv_material.get_shader_parameter("tape_speckle"),
		"rf_noise": tv_material.get_shader_parameter("rf_noise"),
		"sync_error": tv_material.get_shader_parameter("sync_error")
	}

	for p in [0.0, 0.12, 0.5, 1.0]:
		var envelope := CONTROLLER.glitch_envelope(p)
		expect(envelope == 0.0 if p == 0.0 or p == 1.0 else envelope > 0.0, "bad glitch envelope at %s" % p)
	expect(CONTROLLER.glitch_envelope(0.12) > CONTROLLER.glitch_envelope(0.5), "glitch envelope does not decay")

	var baseline_dropout := float(full_material.get_shader_parameter("dropout_amount"))
	var glitch_parameters := {
		CONTROLLER.GlitchKind.TRACKING: "tracking_error",
		CONTROLLER.GlitchKind.COLOR_UNLOCK: "chroma_loss",
		CONTROLLER.GlitchKind.DROPOUT: "dropout_amount",
		CONTROLLER.GlitchKind.RF_STATIC: "rf_noise",
		CONTROLLER.GlitchKind.SYNC_SLIP: "sync_error",
	}
	for kind in glitch_parameters:
		controller._glitch_active = true
		controller._glitch_major = true
		controller._glitch_strength = 0.8
		controller._glitch_origin = 0.5
		controller._glitch_started = Time.get_ticks_msec() * 0.001 - 0.05
		controller._glitch_until = Time.get_ticks_msec() * 0.001 + 0.20
		controller._glitch_kind = kind
		controller._apply_found_footage_state()
		var param: String = glitch_parameters[kind]
		var baseline := baseline_dropout if kind == CONTROLLER.GlitchKind.DROPOUT else 0.0
		expect(float(full_material.get_shader_parameter(param)) > baseline, "glitch kind %s did not increase %s" % [kind, param])
		var fault := controller._video_fault(Time.get_ticks_msec() * 0.001)
		expect(fault.get("kind") == kind and float(fault.get("amount",0.0)) > 0.0,
			"GPU path lost the distinct glitch kind %s" % kind)
	controller._glitch_active = false
	controller._apply_found_footage_state()
	expect(approx(full_material.get_shader_parameter("tracking_error"), 0.0), "tracking did not reset")
	expect(approx(full_material.get_shader_parameter("chroma_loss"), 0.0), "chroma loss did not reset")
	expect(approx(full_material.get_shader_parameter("vertical_slip"), 0.0), "vertical slip did not reset")
	expect(approx(full_material.get_shader_parameter("rf_noise"), 0.0), "RF noise did not reset")
	expect(approx(full_material.get_shader_parameter("sync_error"), 0.0), "sync error did not reset")

	for key in tv_baseline:
		expect(tv_material.get_shader_parameter(key) == tv_baseline[key], "TV parameter changed: %s" % key)

	controller.glitch_burst()
	expect(float(full_material.get_shader_parameter("signal_loss")) > 0.0, "burst did not apply loss")
	controller._burst_until = 0.0
	controller._apply_found_footage_state()
	expect(approx(full_material.get_shader_parameter("signal_loss"), 0.0), "burst loss did not reset")
	controller.damage_hit()
	expect(float(full_material.get_shader_parameter("tracking_error")) > 0.0, "damage did not apply tracking")
	controller._damage_until = Time.get_ticks_msec() * 0.001 - 1.0
	controller.update()
	expect(approx(full_material.get_shader_parameter("tracking_error"), 0.0), "expired damage did not clear")
	controller.set_corruption(99.0)
	expect(approx(controller._signal_corruption, 1.0), "corruption did not clamp high")
	controller.set_corruption(-1.0)
	expect(approx(controller._signal_corruption, 0.0), "corruption did not clamp low")
	var now := Time.get_ticks_msec() * 0.001
	controller._start_glitch(true, now)
	expect(controller._minor_at - now >= 5.0 and controller._minor_at - now <= 11.0, "major minor schedule out of bounds")
	expect(controller._major_at - now >= 28.0 and controller._major_at - now <= 55.0, "major schedule out of bounds")
	expect(controller._glitch_until - now >= 0.18 and controller._glitch_until - now <= 0.45, "major glitch duration out of bounds")
	controller._start_glitch(false, now)
	expect(controller._minor_at - now >= 5.0 and controller._minor_at - now <= 11.0, "minor reschedule out of bounds")
	expect(controller._glitch_until - now >= 0.08 and controller._glitch_until - now <= 0.20, "minor glitch duration out of bounds")
	controller._experiment_settings["ntsc_auto_faults"] = false
	expect(controller._video_fault(now + 0.03).is_empty(), "disabled automatic faults still reached GPU")
	controller.enemy_appearance_warning(ShadowFigures.APPEARANCE_WARNING_SECONDS)
	var warning := controller._video_fault(controller._glitch_started + 0.08)
	expect(float(warning.get("amount",0.0)) > 0.9, "encounter warning should be distinct from optional ambient faults")
	expect(controller._glitch_until - controller._glitch_started > ShadowFigures.APPEARANCE_WARNING_SECONDS,
		"warning must lead and briefly overlap manifestation")
	expect(float(controller._video_fault(controller._glitch_until).get("amount",0.0)) == 0.0, "warning did not settle")
	var gpu_host := preload("res://scripts/ntscrt_video_host.gd").new()
	var output := FaultPresenter.new()
	gpu_host.presenter = output
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,warning)
	expect(float(output.game_state.fault_amount) > 0.9, "warning did not reach GPU preparation")
	gpu_host._reduced = true
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,warning)
	expect(output.game_state.fault_amount == 0.0, "reduced flashing retained a GPU glitch")
	gpu_host._reduced = false
	output.signal_enabled = false
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,warning)
	expect(output.game_state.fault_amount == 0.0, "CRT-only output received a tape glitch")
	# Full-signal presets play selected original animations without enabling
	# the receiver or changing the persistent preset values.
	controller._video_pipeline = 2
	controller.enemy_appearance_warning(ShadowFigures.APPEARANCE_WARNING_SECONDS)
	var pop := controller._video_fault(controller._glitch_started+0.096*controller._encounter_duration)
	expect(pop.get("sequence") == "glitch_pop", "enemy warning did not select the original Glitch pop track")
	output.signal_enabled = true
	gpu_host._signal_knobs = GameSettings.FULL_SETTINGS.ntsc_defaults()
	var base_knobs: Dictionary = gpu_host._signal_knobs.duplicate(true)
	# Known upstream snapshots catch normalized timing, outgoing easing,
	# discrete toggles and integer rounding independently of game adaptation.
	var sequences = preload("res://scripts/ntscrt_glitch_sequences.gd")
	var eased: Dictionary = sequences.sample("two_blips",(0.3042892041163142+0.4351338274169184)*0.5)
	expect(is_equal_approx(float(eased.vertical_scale),1.543523704879374),"original outgoing Ease in was not retained")
	var middle: Dictionary = sequences.sample("two_blips",lerpf(0.6680248064577039,0.7518646148036254,0.6))
	expect(middle.vhs_edge_wave_detail==4,"original integer track did not round")
	expect(not sequences.sample("glitch_pop",0.15).vhs_edge_wave_enabled
		and sequences.sample("glitch_pop",0.16).vhs_edge_wave_enabled,"original toggle did not hold until its key")
	for phase in [0.0,1.0]:
		var settled := base_knobs.duplicate(true)
		sequences.apply_to(settled,"two_blips",phase,1.0)
		expect(settled==base_knobs,"sequence endpoint changed the preset")
	var zero_wear := base_knobs.duplicate(true)
	sequences.apply_to(zero_wear,"two_blips",0.75,0.0)
	expect(zero_wear==base_knobs,"zero tape damage retained an authored animation")
	var peak := base_knobs.duplicate(true)
	sequences.apply_to(peak,"two_blips",0.7518646148036254,1.0)
	expect(peak.vhs_edge_wave<=4.00001 and peak.vhs_edge_wave_detail<=3
		and peak.vertical_scale>=0.69999,"ambient animation exceeded its readable/performance limits")
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,pop)
	expect(output.signal_settings.vhs_chroma_loss>0.05 and output.signal_settings.vhs_chroma_loss<=0.10001,
		"original colour-loss pop missing or exceeded its readable limit: %s" % output.signal_settings.vhs_chroma_loss)
	expect(gpu_host._signal_knobs==base_knobs,"animation altered the preset")
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,{})
	expect(output.signal_settings==base_knobs,"animation did not restore every base setting")
	gpu_host._reduced = true
	gpu_host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,pop)
	expect(output.signal_settings==base_knobs and output.game_state.fault_amount==0.0,
		"Reduced flashing retained an authored animation")
	gpu_host._reduced = false
	controller._experiment_settings["ntsc_auto_faults"] = true
	controller._start_glitch(true,now)
	expect(controller._glitch_sequence=="two_blips" and is_equal_approx(controller._glitch_until-now,1.1),
		"rare ambient fault did not select the adapted Two blips timeline")
	controller._experiment_settings["ntsc_auto_faults"] = false
	expect(controller._video_fault(now+0.5).is_empty(),"disabled ambient faults still played the authored sequence")
	controller.set_effects(false, false)
	expect(controller._video_fault(controller._glitch_started + 0.08).is_empty(), "Clean retained a gameplay glitch")
	output.free()
	gpu_host.free()

	host.free()
	if failures.is_empty():
		print("audit_post_process: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("audit_post_process: FAIL (%d)" % failures.size())
		quit(1)
