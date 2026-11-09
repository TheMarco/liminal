extends "res://tools/lib/audit_base.gd"
## Real-scene NTSCRT cost comparison, isolated settings and exact offscreen output.
## Default: validate 30-frame no-present batches for baseline + one original CRT.
## Full matrix: --full-matrix (only run when no other GPU jobs contend).
## Focused preset regression: --tape-looks compares Found footage and old/new Worn tape.
## --authored-looks compares Home video before/after and Worn with original animations.
## --quality-ladder measures real Low/Medium/High/Ultra settings, without forced world/AA overrides.
## --crt-comparison compares Home video's Aperture/Royale at real High/Ultra quality.
## godot --path . --audio-driver Dummy --quit-after 12000 --script tools/benchmark_ntscrt_game.gd -- --nologo --level=1
## Results: build/ntscrt-review/game-benchmark-{probe,full}.json

const HOST = preload("res://scripts/ntscrt_video_host.gd")
const OUTPUT := "res://build/ntscrt-review"
const SEED := 240721
const STEP := 1.0 / 60.0
const BATCH_FRAMES := 30
var game: Node
var host: Control
var source: SubViewport
var output: SubViewport
var settings: GameSettings
var camera: Camera3D
var rows: Array[Dictionary] = []
var frame_events := 0
var forced_batches_valid := true
var full_matrix := false
var production_profile := false
var tape_looks := false
var authored_looks := false
var quality_ladder := false
var crt_comparison := false
var _sequence := ""
var _sequence_phase := 0.0
var metadata: Dictionary = {}
var _profile_path := ""
var world_height := 480


func settle(count: int) -> void:
	for _frame in count:
		if is_instance_valid(game) and is_instance_valid(game._pause_menu):
			game._close_settings()
		await process_frame
		await RenderingServer.frame_post_draw


func _on_frame_drawn() -> void:
	frame_events += 1


func _ready_frames() -> int:
	return int(host.presenter.ready_frames) if is_instance_valid(host.presenter) else 0


func _presenter_active() -> bool:
	return is_instance_valid(host.presenter) and host.presenter.visible


func _stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {"mean": null, "median": null, "p95": null}
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var n := sorted.size()
	var median: float = sorted[n / 2] if n % 2 else (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5
	return {"mean": total / n, "median": median, "p95": sorted[clampi(ceili(n * 0.95) - 1, 0, n - 1)]}


func _cpu_submit_usec() -> Variant:
	if _presenter_active():
		return int(host.presenter.cpu_usec)
	return null


func _approximate_tick() -> void:
	# force_draw does not run SceneTree processing. Advance the approximate
	# receiver's normal CPU update once per submitted render, at fixed delta.
	var post: Node = game._post_process
	if is_instance_valid(post._experimental) and post._experimental.visible:
		post._experimental._process(STEP)
	if not _sequence.is_empty():
		_sequence_phase = fmod(_sequence_phase+STEP/(0.53 if _sequence=="glitch_pop" else 1.1),1.0)
		host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,{"sequence":_sequence,
			"sequence_strength":1.0,"phase":_sequence_phase,"amount":post.glitch_envelope(_sequence_phase),"kind":0})


func forced_batch(count: int) -> Dictionary:
	var before_events := frame_events
	var before_ready := _ready_frames()
	var presenter: Node = host.presenter
	var presenter_running := is_instance_valid(presenter) and presenter.is_processing()
	var clock_before := float(presenter._clock) if is_instance_valid(presenter) else 0.0
	if is_instance_valid(presenter):
		presenter.set_process(false)
	var approximate: Node = game._post_process._experimental
	var approximate_running := is_instance_valid(approximate) and approximate.is_processing()
	if is_instance_valid(approximate):
		approximate.set_process(false)
	var started := Time.get_ticks_usec()
	for _frame in count:
		if _presenter_active():
			presenter._clock += STEP
		_approximate_tick()
		RenderingServer.force_draw(false, STEP)
	var submit_done := Time.get_ticks_usec()
	# One readback fences the whole batch. No per-frame transfer/present cost.
	var image := output.get_texture().get_image()
	var ended := Time.get_ticks_usec()
	var result := {
		"frames": count, "total_ms": (ended - started) / 1000.0,
		"synchronized_ms_per_frame": (ended - started) / 1000.0 / count,
		"submission_ms_per_frame": (submit_done - started) / 1000.0 / count,
		"readback_ms": (ended - submit_done) / 1000.0,
		"amortized_readback_ms_per_frame": (ended - submit_done) / 1000.0 / count,
		"frame_post_draw_delta": frame_events - before_events,
		"presenter_ready_delta": _ready_frames() - before_ready,
		"image_width": image.get_width(), "image_height": image.get_height(),
		"image_bytes": image.get_data().size(),
		"presenter_cpu_submit_usec_last": _cpu_submit_usec(),
		"presenter_clock_advance": float(presenter._clock) - clock_before if is_instance_valid(presenter) else 0.0,
	}
	if is_instance_valid(approximate):
		approximate.set_process(approximate_running)
	if is_instance_valid(presenter):
		presenter.set_process(presenter_running)
	return result


func _valid_batch(batch: Dictionary) -> bool:
	return int(batch.frame_post_draw_delta) >= int(batch.frames) \
		and (not _presenter_active() or int(batch.presenter_ready_delta) >= int(batch.frames)) \
		and int(batch.image_width) == output.size.x and int(batch.image_height) == output.size.y


func _case(label: String, pipeline: int, vhs: bool, crt: bool, receiver := false, shader := 0) -> Dictionary:
	return {"name": label, "video_pipeline": pipeline, "vhs_enabled": vhs,
		"crt_enabled": crt, "receiver_enabled": receiver, "crt_shader": shader}


func _cases() -> Array[Dictionary]:
	if crt_comparison:
		var cases: Array[Dictionary] = []
		for tier in [2,3]:
			for model in [1,6]:
				var config := _case("home-"+GameSettings.CRT_SHADER_IDS[model]+"-"+GameSettings.QUALITY_NAMES[tier].to_lower(),2,true,true,false,model)
				config["look"] = 1
				config["graphics_quality"] = tier
				cases.append(config)
		return cases
	if quality_ladder:
		var cases: Array[Dictionary] = []
		for look in [1,3]:
			for tier in range(4):
				var config := _case(("home-" if look==1 else "worn-")+GameSettings.QUALITY_NAMES[tier].to_lower(),2,true,look==1,false,GameSettings.CRT_AUTOMATIC if look==1 else 7)
				config["look"] = look
				config["graphics_quality"] = tier
				cases.append(config)
			var before := cases[cases.size()-4].duplicate(true)
			before["name"] += "-before-video-scaling"
			before["legacy_effects"] = true
			if look==1: before["crt_shader"] = 1 # Historical Low comparison stays Aperture.
			cases.append(before)
		return cases
	if authored_looks:
		var old_home := _case("home-before",0,true,true,false,0)
		old_home["look"] = 1
		old_home["overrides"] = GameSettings.legacy_home_video_values()
		var home := _case("home-aperture",2,true,true,false,1)
		home["look"] = 1
		var worn := _case("worn-steady",2,true,false,false,7)
		worn["look"] = 3
		var pop := worn.duplicate(true)
		pop["name"] = "worn-glitch-pop"
		pop["sequence"] = "glitch_pop"
		var blips := worn.duplicate(true)
		blips["name"] = "worn-two-blips"
		blips["sequence"] = "two_blips"
		return [old_home,home,worn,pop,blips]
	if tape_looks:
		var found := _case("look-found-footage",2,true,false,false,7)
		found["look"] = 2
		var old_worn := _case("look-worn-before",2,true,false,true,7)
		old_worn["look"] = 2
		old_worn["overrides"] = GameSettings.legacy_worn_tape_values()
		var worn := _case("look-worn-gpu",2,true,false,false,7)
		worn["look"] = 3
		return [found, old_worn, worn]
	var cases: Array[Dictionary] = [
		_case("no-effects", 0, false, false),
		_case("old-vhs-only", 0, true, false),
		_case("old-crt-only", 0, false, true),
		_case("old-combined", 0, true, true),
		_case("approximate-signal-only", 1, true, false),
		_case("approximate-combined", 1, true, true),
		_case("full-ntsc-only", 2, true, false),
		_case("receiver-only", 2, false, false, true),
		_case("full-ntsc-receiver", 2, true, false, true),
	]
	for shader in range(1, 8):
		var label: String = GameSettings.CRT_SHADER_IDS[shader]
		cases.append(_case("clean-crt-" + label, 0, false, true, false, shader))
		cases.append(_case("full-receiver-crt-" + label, 2, true, true, true, shader))
	var efficient := _case("full-receiver-efficient",2,true,false,true)
	efficient["quality"] = 0
	cases.append(efficient)
	var history := _case("full-receiver-field-history",2,true,false,true)
	history["history"] = true
	cases.append(history)
	var source_first := _case("full-receiver-source-resolution",2,true,false,true)
	source_first["source_resolution"] = true
	source_first["filter"] = 3
	cases.append(source_first)
	for kernel in range(1,7):
		var resampled := _case("full-receiver-filter-"+["nearest","nearest-plus","bilinear","bicubic","lanczos","area"][kernel-1],2,true,false,true)
		resampled["filter"] = kernel
		cases.append(resampled)
	for scaling in [1,2]:
		var supersampled := _case("full-aperture-"+("supersampled" if scaling == 1 else "integer-fit"),2,true,true,true,1)
		supersampled["scaling"] = scaling
		cases.append(supersampled)
	if production_profile:
		var selected: Array[Dictionary] = []
		for config in cases:
			if config.name in ["no-effects","old-combined","full-ntsc-only","receiver-only","full-receiver-crt-aperture","full-receiver-crt-sim","full-receiver-efficient","full-receiver-source-resolution"]: selected.append(config)
		return selected
	return cases


func apply_case(config: Dictionary) -> bool:
	_sequence = str(config.get("sequence",""))
	_sequence_phase = 0.0
	if config.has("look"):
		settings.apply_video_look(int(config.look))
	if config.has("graphics_quality"):
		settings.apply_quality_preset(int(config.graphics_quality))
	settings.set_value("ntsc_quality",int(config.get("quality",1)))
	settings.set_value("ntscrs_field_history",bool(config.get("history",false)))
	settings.set_video_parameter("ntscrs","use_field",0 if bool(config.get("history",false)) else 4)
	settings.set_value("ntscrs_source_resolution",bool(config.get("source_resolution",false)))
	settings.set_value("ntscrt_downscale_filter",int(config.get("filter",0)))
	settings.set_value("ntscrt_scale_mode",int(config.get("scaling",0)))
	for key: String in ["video_pipeline", "vhs_enabled", "crt_enabled", "crt_shader"]:
		settings.set_value(key, config[key])
	if settings.values.has("receiver_enabled"):
		settings.set_value("receiver_enabled", config.receiver_enabled)
	elif bool(config.receiver_enabled):
		fail("Receiver integration is not available for " + str(config.name))
		return false
	for key: String in config.get("overrides", {}):
		settings.set_value(key, config.overrides[key])
	if crt_comparison and int(config.crt_shader)==6:
		settings.set_value("crt_shader_parameters",GameSettings.HOME_CRT_PARAMETERS)
	for key: String in ["video_pipeline", "vhs_enabled", "crt_enabled", "crt_shader"]:
		if settings.get_value(key) != config[key]:
			fail("Settings integration rejected " + key + " for " + str(config.name))
			return false
	# Crucial fairness override: use the same 480-line world in every case,
	# matching the game default. --world-height=N selects a separate workload.
	if not quality_ladder:
		source.scaling_3d_scale = clampf(float(world_height) / output.size.y, 0.05, 1.0)
		source.use_taa = false
		source.msaa_3d = Viewport.MSAA_DISABLED
		source.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if bool(config.get("legacy_effects",false)):
		# Same Low world and lighting, but the former full-size tape/output work.
		var before := settings.values.duplicate(true)
		before["quality_preset"] = 3
		host.configure_video(before,2,true,bool(config.crt_enabled),true,false)
	game._post_process._minor_at = 1e30
	game._post_process._major_at = 1e30
	game._post_process._glitch_active = false
	return true


func _memory() -> Dictionary:
	var report := {"video_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mib": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mib": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"static_cpu_mib": OS.get_static_memory_usage() / 1048576.0}
	# Metal's texture counter can underflow when shared mip views are retired.
	# Preserve unavailable counters as null, never as enormous memory usage.
	for key in report:
		if float(report[key]) < 0.0 or float(report[key]) > 1048576.0: report[key] = null
	return report


func benchmark(config: Dictionary, round_index: int, batches: int) -> void:
	if not apply_case(config):
		return
	await settle(60 if full_matrix and not tape_looks and not authored_looks and not quality_ladder else 20)
	if _presenter_active(): expect(host.presenter.last_error.is_empty(),str(config.name)+": "+host.presenter.last_error)
	var samples: Array[float] = []
	var submits: Array[float] = []
	var render_cpu: Array[float] = []
	var render_gpu: Array[float] = []
	var detail: Array[Dictionary] = []
	var method := "no-present synchronized batch"
	if forced_batches_valid:
		for _batch in batches:
			var result := forced_batch(BATCH_FRAMES)
			detail.append(result)
			if not _valid_batch(result):
				forced_batches_valid = false
				break
			samples.append(float(result.synchronized_ms_per_frame))
			if result.presenter_cpu_submit_usec_last != null:
				submits.append(float(result.presenter_cpu_submit_usec_last) / 1000.0)
			var measured_cpu := RenderingServer.viewport_get_measured_render_time_cpu(source.get_viewport_rid())
			var measured_gpu := RenderingServer.viewport_get_measured_render_time_gpu(source.get_viewport_rid())
			if measured_cpu > 0.0: render_cpu.append(measured_cpu)
			if measured_gpu > 0.0: render_gpu.append(measured_gpu)
			# Yield outside measured intervals to apply deferred texture publication.
			await settle(1)
	if not forced_batches_valid:
		method = "normal uncapped process-frame wall time; compositor cap may remain"
		samples.clear()
		submits.clear()
		var before := Time.get_ticks_usec()
		for _frame in (90 if full_matrix else 30):
			await settle(1)
			var now := Time.get_ticks_usec()
			samples.append((now - before) / 1000.0)
			before = now
			if _cpu_submit_usec() != null:
				submits.append(float(_cpu_submit_usec()) / 1000.0)
			var cpu_time := RenderingServer.viewport_get_measured_render_time_cpu(source.get_viewport_rid())
			var gpu_time := RenderingServer.viewport_get_measured_render_time_gpu(source.get_viewport_rid())
			if cpu_time > 0.0: render_cpu.append(cpu_time)
			if gpu_time > 0.0: render_gpu.append(gpu_time)
	var row := {"case": config.name, "round": round_index, "configuration": config.duplicate(true),
		"output": [output.size.x, output.size.y], "source": [source.size.x, source.size.y],
		"world_scale": source.scaling_3d_scale, "world_height": world_height, "method": method, "sample_count": samples.size(),
		"sample_unit": "30-frame batch mean" if method.begins_with("no-present") else "frame",
		"frame_ms": _stats(samples), "presenter_cpu_submit_ms": _stats(submits),
		"viewport_cpu_ms": _stats(render_cpu), "viewport_gpu_ms": _stats(render_gpu),
		"gpu_timestamp_note": "Unavailable values remain null; wall time is not pure GPU duration",
		"memory": _memory(), "diagnostic_batches": detail,
		"exact_settings": settings.values.duplicate(true)}
	row["actual_world_height"] = source.size.y*source.scaling_3d_scale
	if quality_ladder: row["world_height"] = row["actual_world_height"]
	row["effective_signal_size"] = [host.presenter.signal_extent.x,host.presenter.signal_extent.y] if _presenter_active() else null
	row["effective_output_height_limit"] = host.presenter.output_height_limit if _presenter_active() else null
	row["effective_crt_model"] = host.presenter.preset_name if _presenter_active() else null
	row["effective_taa"] = source.use_taa
	row["effective_msaa"] = source.msaa_3d
	if _presenter_active() and not host.presenter.timestamp_samples.is_empty():
		var raw_timestamps: Dictionary = host.presenter.timestamp_samples.back()
		var available := false
		for timestamp: Variant in raw_timestamps.values():
			if float(timestamp) > 0.0: available = true
		row["gpu_timestamps_last"] = raw_timestamps if available else null
		row["gpu_timestamp_status"] = "available_raw_timestamps" if available else "all_zero_unavailable"
	else:
		row["gpu_timestamps_last"] = null
		row["gpu_timestamp_status"] = "unavailable"
	rows.append(row)
	print("NTSCRT_BENCHMARK ", JSON.stringify(row))
	_write_result()


func _write_result() -> void:
	var document := {"metadata": metadata, "forced_batches_valid": forced_batches_valid,
		"rows": rows, "failures": failures}
	var path := OUTPUT.path_join("game-benchmark-full.json" if full_matrix else "game-benchmark-probe.json")
	if production_profile: path = OUTPUT.path_join("game-benchmark-production.json")
	if tape_looks: path = OUTPUT.path_join("game-benchmark-tape-looks.json")
	if authored_looks: path = OUTPUT.path_join("game-benchmark-authored-looks.json")
	if quality_ladder: path = OUTPUT.path_join("game-benchmark-quality-ladder.json")
	if crt_comparison: path = OUTPUT.path_join("game-benchmark-crt-comparison.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(document, "\t"))


func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU and --nologo to isolate campaign progress")
		finish()
		return
	tape_looks = OS.get_cmdline_user_args().has("--tape-looks")
	authored_looks = OS.get_cmdline_user_args().has("--authored-looks")
	crt_comparison = OS.get_cmdline_user_args().has("--crt-comparison")
	quality_ladder = OS.get_cmdline_user_args().has("--quality-ladder") or crt_comparison
	production_profile = OS.get_cmdline_user_args().has("--production") or tape_looks or authored_looks or quality_ladder
	full_matrix = OS.get_cmdline_user_args().has("--full-matrix") or production_profile
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--world-height="):
			world_height = clampi(int(argument.get_slice("=", 1)), 120, 4320)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(640, 360)
	root.title = "Liminal — fixed-scene NTSCRT benchmark"
	root.use_hdr_2d = production_profile
	output = SubViewport.new()
	output.size = Vector2i(1920, 1080)
	output.use_hdr_2d = production_profile
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var preview := TextureRect.new()
	preview.texture = output.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	host = HOST.new()
	output.add_child(host)
	source = host.source
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = SEED
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	host.attach(game)
	# Install the isolated profile before the first await/menu-close opportunity.
	if game._progress_enabled:
		fail("Benchmark must not write campaign progress")
		await teardown_game(game)
		finish()
		return
	_profile_path = "/tmp/liminal-ntscrt-benchmark-%d.cfg" % OS.get_process_id()
	settings = GameSettings.new(_profile_path)
	for key: String in ["hdr_enabled", "vsync", "handheld_camera"]:
		settings.set_value(key, false)
	settings.set_value("frame_limit", 0)
	settings.set_value("render_resolution", 5)
	settings.set_value("anti_aliasing", 1)
	settings.set_value("ntsc_auto_faults", false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	await settle(30)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.cm.set_process(false)
	game.set_process(false)
	stop_audio(game)
	seed(SEED)
	camera = Camera3D.new()
	camera.fov = 77.0
	source.add_child(camera)
	camera.global_transform = game.player.cam.global_transform
	camera.current = true
	RenderingServer.viewport_set_measure_render_time(source.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(output.get_viewport_rid(), true)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	metadata = {"seed": SEED, "level": game.active_level, "camera_transform": str(camera.global_transform),
		"camera_fov": camera.fov, "engine": Engine.get_version_info(), "os": OS.get_name(),
		"device": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"world_height": world_height, "profile": _profile_path, "preview": [640, 360], "full_matrix": full_matrix,
		"rendering_method":RenderingServer.get_current_rendering_method(), "hdr_2d":production_profile,
		"notes": ["No-present batch includes CPU submission plus GPU completion and amortized single image readback.",
			"Batch percentiles describe 30-frame averages, not individual GPU frame latency.",
			"Normal fallback may retain OS display pacing despite disabled VSync and frame limit.",
			"Effect clocks advance by1/60 per force_draw; automatic glitches are disabled.",
			"World height is fixed identically across all cases (default480), independently of output dimensions."]}
	if quality_ladder:
		metadata["world_height"] = null
		metadata["notes"][-1] = "Quality ladder uses each preset's real world resolution, antialiasing and lighting; no forced 480-line workload."
	var baseline := _case("no-effects", 0, false, false)
	var shader := _case("clean-crt-aperture", 0, false, true, false, 1)
	await benchmark(baseline, 0, 1)
	await benchmark(shader, 0, 1)
	if OS.get_cmdline_user_args().has("--full-probe"):
		await benchmark(_case("full-ntsc-receiver",2,true,false,true),0,2)
	if full_matrix:
		# Probe rows are retained as evidence, then both full rounds use one method.
		for extent: Vector2i in [Vector2i(1920, 1080), Vector2i(3840, 2160)]:
			output.size = extent
			await settle(4)
			for round_index in 2:
				var cases := _cases()
				if round_index == 1: cases.reverse()
				for config: Dictionary in cases:
					await benchmark(config, round_index, 3 if tape_looks or authored_looks or quality_ladder else 6)
	_write_result()
	await teardown_game(game)
	output.queue_free()
	DirAccess.remove_absolute(_profile_path)
	finish("fixed-scene NTSCRT benchmark " + ("matrix" if full_matrix else "mechanism probe"))
