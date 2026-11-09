extends "res://tools/lib/audit_base.gd"
## Focused native integration audit. Uses a temporary profile before first await.
## godot --path . --rendering-method mobile --rendering-driver metal --audio-driver Dummy --script tools/audit_ntscrt_full_pipeline.gd --quit-after 1500 -- --nologo --level=1

const HOST = preload("res://scripts/ntscrt_video_host.gd")
const SCALER = preload("res://scripts/ntscrt_preview_scaler.gd")
var game: Node
var host: Control
var output: SubViewport
var settings: GameSettings
var original_parent: Node
var profile_path: String
var snapshot: Dictionary = {}
var snapshot_ready := false
var debug_pixels := false


func settle(count := 8) -> void:
	for _frame in count:
		await process_frame
		await RenderingServer.frame_post_draw


func route(pipeline: int, signal_on: bool, receiver_on: bool, crt_on: bool, crt := 1) -> void:
	settings.set_value("video_pipeline", pipeline)
	settings.set_value("vhs_enabled", signal_on)
	settings.set_value("receiver_enabled", receiver_on)
	settings.set_value("crt_enabled", crt_on)
	settings.set_value("crt_shader", crt)


func progressing(label: String, pixels := false) -> void:
	var presenter: Node = host.presenter
	expect(is_instance_valid(presenter) and presenter.visible, label + ": presenter visible")
	if not is_instance_valid(presenter): return
	var before: int = presenter.ready_frames
	await settle()
	# Dimension changes wait for a quiet resize interval before rebuilding.
	var deadline := Time.get_ticks_msec() + 5000
	while presenter.ready_frames < before + 2 and presenter.last_error.is_empty() and Time.get_ticks_msec() < deadline:
		await settle(1)
	expect(presenter.ready_frames >= before + 2, label + ": GPU frames advance")
	expect(presenter.last_error.is_empty(), label + ": " + str(presenter.last_error))
	expect(game.get_parent() == original_parent, label + ": game not reparented")
	if pixels: await check_pixels(label)
	print("FULL_PIPELINE_CASE ", label, " ready=", presenter.ready_frames)


func check_pixels(label: String) -> void:
	var image := output.get_texture().get_image()
	expect(not image.is_empty(), label + ": output exists")
	if image.is_empty(): return
	var maximum := 0.0
	for y in range(0, image.get_height(), maxi(1, image.get_height() / 18)):
		for x in range(0, image.get_width(), maxi(1, image.get_width() / 32)):
			var colour := image.get_pixel(x, y)
			expect(is_finite(colour.r) and is_finite(colour.g) and is_finite(colour.b), label + ": finite pixel")
			maximum = maxf(maximum, maxf(colour.r, maxf(colour.g, colour.b)))
	expect(maximum > 0.005, label + ": image is not black")
	if maximum <= 0.005:
		DirAccess.make_dir_recursive_absolute("res://build/ntscrt-review")
		image.save_png("res://build/ntscrt-review/full-pipeline-dark.png")
		host.source.get_texture().get_image().save_png("res://build/ntscrt-review/full-pipeline-dark-source.png")
		print("DARK_FRAME_STATE ",label," fade=",game._fade.color," paused=",paused," menu=",is_instance_valid(game._pause_menu)," clock=",host.presenter._clock," source_size=",host.source.size)
		debug_pixels = true
		await read_snapshot()
		debug_pixels = false


func _accept_snapshot(value: Dictionary) -> void:
	snapshot = value
	snapshot_ready = true


func _render_snapshot() -> void:
	var presenter: Node = host.presenter
	if debug_pixels:
		var rd := RenderingServer.get_rendering_device()
		for key in ["_input_chain","_signal_stage","_receiver_stage","_crt_chain"]:
			var stage: RefCounted = presenter.get(key)
			if stage == null: continue
			var dims: Vector2i = stage.output_size if key.ends_with("chain") else (stage._extent if key == "_signal_stage" else stage.extent)
			var bytes := rd.texture_get_data(stage.output,0)
			Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RGBA8,bytes).save_png("res://build/ntscrt-review/debug"+key+".png")
	var result := {"signal_exists": presenter._signal_stage != null,
		"receiver_exists": presenter._receiver_stage != null,
		"downscale_exists": presenter._downscale_stage != null}
	if presenter._signal_stage != null: result["signal_extent"] = presenter._signal_stage._extent
	if presenter._crt_chain != null:
		result["crt_input"] = presenter._crt_chain.source_size
		result["crt_output"] = presenter._crt_chain.output_size
	if presenter._downscale_stage != null:
		result["downscale_input"] = presenter._downscale_stage._source_size
		result["downscale_output"] = presenter._downscale_stage._target_size
	_accept_snapshot.call_deferred(result)


func read_snapshot() -> void:
	snapshot_ready = false
	RenderingServer.call_on_render_thread(_render_snapshot)
	while not snapshot_ready: await process_frame


func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU renderer and --nologo")
		finish()
		return
	root.size = Vector2i(640, 360)
	root.use_hdr_2d = false
	root.title = "Liminal — full NTSCRT integration audit"
	output = SubViewport.new()
	output.size = Vector2i(640,360)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var preview := TextureRect.new()
	preview.texture = output.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	host = HOST.new()
	output.add_child(host)
	current_scene = output
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	original_parent = game.get_parent()
	# No await or menu close can occur while the real settings object is attached.
	profile_path = "/tmp/liminal-full-pipeline-%d.cfg" % OS.get_process_id()
	settings = GameSettings.new(profile_path)
	settings.set_value("hdr_enabled", false)
	settings.set_value("vsync", false)
	settings.set_value("frame_limit", 0)
	settings.set_value("handheld_camera", false)
	settings.set_value("ntsc_auto_faults", false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	expect(not game._progress_enabled, "Campaign progress disabled")
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	game.set_process(false)
	stop_audio(game)
	var camera := Camera3D.new()
	camera.fov = 77.0
	host.source.add_child(camera)
	camera.global_transform = game.player.cam.global_transform
	camera.current = true
	var post: Node = game._post_process
	post._minor_at = 1e30
	post._major_at = 1e30
	post._glitch_active = false
	await settle(12)

	route(2, true, true, true)
	await progressing("full signal + receiver + original CRT", true)
	expect(host.presenter.signal_enabled and host.presenter.receiver_enabled, "Both full stages enabled")
	expect(host.presenter.preset_name == "aperture", "Original CRT selected")
	await read_snapshot()
	expect(snapshot.signal_exists and snapshot.receiver_exists, "Both GPU stage objects exist")

	route(2, true, false, false)
	await progressing("signal only")
	expect(host.presenter.signal_enabled and not host.presenter.receiver_enabled and host.presenter.preset_name == "none", "Signal independent")
	route(2, false, true, false)
	await progressing("receiver only")
	expect(not host.presenter.signal_enabled and host.presenter.receiver_enabled, "Receiver independent")
	route(2, false, false, true)
	await progressing("original CRT only")
	expect(not host.presenter.signal_enabled and not host.presenter.receiver_enabled, "CRT independent")
	route(2, false, false, false)
	await settle(2)
	expect(not host.presenter.visible, "All stages off bypass presenter")

	route(0, true, true, true)
	await progressing("Classic VHS + receiver + original CRT", true)
	expect(post._overlay.visible and not host.presenter.signal_enabled and host.presenter.receiver_enabled, "Classic VHS retained before receiver")
	route(1, true, true, true)
	await progressing("approximation + receiver + original CRT")
	expect(post._experimental.visible and not host.presenter.signal_enabled and host.presenter.receiver_enabled, "Approximation retained before receiver")

	route(2, true, false, true, 8)
	await progressing("full signal + native tube")
	expect(is_instance_valid(host._native_tube) and host._native_tube.visible, "Explicit native tube visible")
	expect(host.presenter.preset_name == "none", "No original tube stacked with native")
	route(2, true, false, true, 0)
	await progressing("full signal + default tube")
	expect(is_instance_valid(host._classic_tube) and host._classic_tube.visible, "Default tube follows full signal")
	expect(not post._tube_display.visible, "No duplicate default tube")
	route(2, false, false, true, 0)
	await settle(4)
	expect(post._tube_display.visible and not host.presenter.visible, "Default CRT stays visible with full signal and receiver off")

	route(2, true, true, true)
	await progressing("bypass precondition")
	post.set_enabled(false)
	await settle(3)
	expect(not host.presenter.visible and not post._overlay.visible and not post._tube_display.visible, "Presentation gate bypasses all signal/tube stages")
	if is_instance_valid(post._experimental): expect(not post._experimental.visible, "Presentation gate bypasses approximation")
	if is_instance_valid(post._grain_overlay): expect(not post._grain_overlay.visible, "Presentation gate bypasses grain")
	if is_instance_valid(post._scene_copy): expect(not post._scene_copy.visible, "Presentation gate bypasses scene-copy effects")
	if is_instance_valid(host._native_tube): expect(not host._native_tube.visible, "Presentation gate bypasses native tube")
	if is_instance_valid(host._classic_tube): expect(not host._classic_tube.visible, "Presentation gate bypasses hosted classic tube")
	post.set_enabled(true)
	route(2, false, false, false)
	post.set_tape_playback(true)
	await progressing("tape hold")
	expect(host.presenter.signal_enabled, "Tape hold enables full signal when VHS toggle is off")
	post.set_tape_playback(false)

	route(2, true, true, true)
	settings.set_value("ntscrs_field_history", true)
	settings.set_video_parameter("receiver", "tracking", 0.8)
	settings.set_video_parameter("receiver", "head_clog", 0.8)
	settings.set_value("reduced_flashing", true)
	await progressing("reduced flashing")
	expect(not host.presenter.signal_settings.get("field_history", true), "Reduced flashing disables history")
	for key: String in ["head_switching", "tracking_noise", "vhs_edge_wave_enabled", "composite_noise", "luma_noise", "chroma_noise"]:
		expect(not bool(host.presenter.signal_settings[key]), "Reduced flashing disables " + key)
	for key: String in ["head_switch", "crinkle", "head_clog", "tracking", "dropouts", "horizontal_hold", "vertical_hold"]:
		expect(float(host.presenter.receiver_settings[key]) == 0.0, "Reduced flashing clears receiver " + key)
	settings.set_value("reduced_flashing", false)

	game.opts.video_lab = true
	game._open_settings(true)
	game._pause_menu._select_tab("Visual Effects")
	await settle(2)
	var controls: Dictionary = game._pause_menu._full_video_controls.controls
	expect(controls.size() == 79, "All 79 canonical menu controls available")
	(controls["ntscrs/luma_smear"] as SpinBox).value = 0.375
	expect(is_equal_approx(float(settings.get_value("ntscrs_settings")["luma_smear"]), 0.375), "Canonical UI edit reaches settings")
	expect(is_equal_approx(float(host.presenter.signal_settings["luma_smear"]), 0.375), "Canonical UI edit reaches presenter")
	game._close_settings()
	# Sampling checks isolate resizing from stochastic receiver transport faults.
	settings.set_value("receiver_enabled", false)

	root.size = Vector2i(800, 450)
	output.size = Vector2i(800,450)
	await progressing("resize", true)
	expect(host.source.size == Vector2i(800, 450), "Source viewport follows resize")
	expect(Vector2i(host.presenter.size) == Vector2i(800, 450), "Presenter follows resize")
	settings.set_value("ntscrt_signal_size", 1)
	settings.set_value("ntscrt_signal_width", 320)
	settings.set_value("ntscrs_source_resolution", true)
	for filter_index in 6:
		settings.set_value("ntscrt_downscale_filter", filter_index + 1)
		await progressing("source-resolution signal, resize filter %d" % filter_index, filter_index == 5)
		expect(host.presenter.source_resolution and host.presenter.downscale_method == filter_index, "Source/filter configuration forwarded")
		await read_snapshot()
		expect(snapshot.get("signal_extent") == host.source.size, "NTSC runs at source resolution")
		expect(snapshot.get("downscale_input") == host.source.size and snapshot.get("downscale_output") == Vector2i(320, 180), "Filter downsizes to custom width")
		expect(snapshot.get("crt_input") == Vector2i(320, 180), "CRT receives custom signal size")
	settings.set_value("ntscrt_scale_mode", 2)
	await progressing("original integer presentation")
	var plan := SCALER.plan(Vector2i(320, 180), Vector2i(800, 450), true)
	await read_snapshot()
	expect(snapshot.get("crt_output") == plan.render_size, "Integer scaling plan controls CRT chain output")
	expect(host.presenter.presentation_scale == 2, "Integer mode forwarded")
	var fraction: Vector2 = host.presenter.material.get_shader_parameter("display_fraction")
	expect(fraction.is_equal_approx(Vector2(plan.display_size) / Vector2(800, 450)), "Integer display fraction preserves centered letterboxing")
	expect(game.get_parent() == original_parent, "Game parent remains stable across all routes")
	await teardown_game(game)
	output.queue_free()
	DirAccess.remove_absolute(profile_path)
	finish("full NTSCRT routes, original controls, resizing, source-resolution filters and integer scaling")
