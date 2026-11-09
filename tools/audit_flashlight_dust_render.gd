extends "res://tools/audit_flashlight_beam_render.gd"
## Pixel checks for real depth occlusion, battery response and budget fallback.
const DUST_OUT := "res://build/flashlight-dust"

func capture(label: String) -> Image:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var picture := view.get_texture().get_image()
	expect(picture.save_png(DUST_OUT.path_join(label+".png")) == OK, "dust capture failed: "+label)
	return picture

func dust_pixels(before: Image, after: Image) -> Dictionary:
	var count := 0
	var total := 0.0
	var peak := 0.0
	for y in before.get_height():
		for x in before.get_width():
			var delta := after.get_pixel(x,y).get_luminance()-before.get_pixel(x,y).get_luminance()
			if delta > 0.02: count += 1
			total += maxf(delta,0.0)
			peak = maxf(peak,delta)
	return {"pixels":count,"total":total,"peak":peak}

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("dust pixel check requires a native GPU renderer")
		finish("flashlight dust pixels")
		return
	DirAccess.make_dir_recursive_absolute(DUST_OUT)
	if OS.get_cmdline_user_args().has("--capture-only"):
		await capture_real_dust()
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		finish("flashlight dust game capture")
		return
	root.title = "Liminal — airborne dust check"
	Engine.max_fps = 60
	view = SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.006,0.007,0.009)
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world.environment.volumetric_fog_enabled = false
	view.add_child(world)
	box(Vector3(8,0.1,18),Vector3(0,-0.05,-7))
	box(Vector3(8,3.5,0.1),Vector3(0,1.75,-12))
	box(Vector3(0.8,2.4,0.8),Vector3(-1.5,1.2,-4))
	player = Player.new()
	player.level_theme = 5
	view.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.cam.position = Vector3(0,Player.CAM_H,0)
	player.cam.rotation = Vector3.ZERO
	player.set_flashlight(true)
	player._flash_beam.visible = false
	var dust = player._flash_dust
	dust.set_process(false)
	dust.motion_time = 8.0
	dust.apply_quality(2)
	dust.update_field()
	dust.visible = false
	var before := await capture("high-off")
	dust.visible = true
	var after := await capture("high-on")
	var full := dust_pixels(before,after)
	expect(full.pixels >= 12 and full.peak > 0.04, "dust is not visibly caught by the torch")
	expect(full.total/float(1280*720) < 0.002, "dust lifts the whole image instead of individual grains")
	player._set_flashlight_energy(Player.FLASH_ENERGY*0.5)
	dust.update_field()
	dust.visible = false
	var dim_before := await capture("dim-off")
	dust.visible = true
	var dim := dust_pixels(dim_before, await capture("dim-on"))
	expect(dim.total > full.total*0.1 and dim.total < full.total*0.85, "dust ignores torch battery dimming")
	player._set_flashlight_energy(Player.FLASH_ENERGY)
	dust.update_field()
	var blocker := box(Vector3(8,8,0.05),Vector3(0,Player.CAM_H,-0.18))
	dust.visible = false
	var blocked_before := await capture("wall-off")
	dust.visible = true
	var blocked := dust_pixels(blocked_before, await capture("wall-on"))
	expect(blocked.pixels == 0, "dust draws over an opaque near wall")
	blocker.queue_free()
	await process_frame
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	var counts: Array[int] = []
	for tier in 4:
		dust.apply_quality(tier)
		dust.update_field()
		counts.append(dust.multimesh.instance_count)
		view.scaling_3d_scale = [0.5,2.0/3.0,1.0,1.0][tier]
		var off_stats := await render_stats(view,dust,false)
		var on_stats := await render_stats(view,dust,true)
		expect(on_stats.draw_calls == off_stats.draw_calls+1, "dust must remain one draw at every quality")
		await capture("quality-%d" % tier)
		print("DUST_QUALITY tier=%d instances=%d %s" % [tier,counts[-1],describe_stats(off_stats,on_stats)])
	expect(counts[0] < counts[1] and counts[1] < counts[2] and counts[2] < counts[3], "particle geometry does not scale down")
	var dusty: float = dust.density
	player.level_theme = 4
	dust.update_field()
	expect(dust.density < dusty*0.2, "airport is as dusty as the asylum")
	player.water_y = player.cam.global_position.y+0.2
	dust.update_field()
	expect(not dust.visible, "airborne dust remains underwater")
	player.water_y = -1.0e9
	player.set_flashlight(false)
	dust.update_field()
	expect(not dust.is_visible_in_tree(), "dust glows after the torch is off")
	print("DUST_PIXELS high=%s dim=%s occluded=%s" % [full,dim,blocked])
	view.queue_free()
	await process_frame
	if OS.get_cmdline_user_args().has("--capture-game"):
		await capture_real_dust()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("flashlight dust pixels")

func capture_real_dust() -> void:
	root.size = Vector2i(1280,720)
	var game := await boot_game(240721)
	await await_until(func(): return not game._switching, 15000)
	var settings := GameSettings.new("/tmp/liminal-dust-%d.cfg" % OS.get_process_id())
	settings.set_value("fullscreen",false)
	settings.set_value("hdr_enabled",false)
	settings.set_value("vhs_enabled",false)
	settings.set_value("crt_enabled",false)
	settings.set_value("film_grain",0.0)
	settings.set_value("vsync",false)
	settings.set_value("frame_limit",0)
	settings.apply_quality_preset(2)
	settings.set_value("render_resolution",5)
	game._settings = settings
	GameSettings.current = settings
	game._apply_game_settings()
	game._osd_layer.visible = false
	game.cm.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for chunk in game.cm.chunks.values():
		if chunk.theme == 5 and chunk.style == WorldGen.ASY_TREATMENT:
			game.player.cam.look_at_from_position(chunk.to_global(Vector3(6,1.6,10.5)),chunk.to_global(Vector3(6,1.6,2)))
			break
	game.player.set_flashlight(true)
	var dust = game.player._flash_dust
	dust.set_process(false)
	dust.motion_time = 8.0
	dust.update_field()
	for i in 24: await process_frame
	if is_instance_valid(game._pause_menu):
		game._pause_menu.free()
		game._pause_menu = null
	for layer in game.find_children("*","CanvasLayer",true,false):
		layer.visible = false
	game._post_process.set_enabled(false)
	# A frozen, paused tree also prevents the native focus-loss handler opening
	# settings halfway through an offscreen capture or timing batch.
	paused = true
	var saved_time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game._post_process.process_mode = Node.PROCESS_MODE_ALWAYS
	var timings: Array[Dictionary] = []
	for enabled in [false,true,true,false]:
		dust.visible = enabled
		for i in 12: await process_frame
		for batch in 3:
			var started := Time.get_ticks_usec()
			for frame in 30: RenderingServer.force_draw(false,0.0)
			var fence := root.get_texture().get_image()
			var elapsed := (Time.get_ticks_usec()-started)/30000.0
			expect(not fence.is_empty(),"dust timing readback failed")
			timings.append({"dust":enabled,"synchronized_ms_per_frame":elapsed})
	var record := {"engine":Engine.get_version_info().string,"device":RenderingServer.get_video_adapter_name(),
		"scene":"Asylum treatment room, real game, torch on, High world lighting, native 1280x720, Clean, fixed scene",
		"method":"Six 30-frame batches per case in opposite orders; includes submission, GPU completion and amortized image readback. Not gameplay FPS or GPU-only time.","timings":timings}
	var report := FileAccess.open(DUST_OUT.path_join("performance.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(record,"\t"))
	report.close()
	for enabled in [false,true]:
		var samples: Array[float] = []
		for sample in timings:
			if sample.dust == enabled: samples.append(sample.synchronized_ms_per_frame)
		samples.sort()
		print("DUST_GAME_TIMING enabled=%s median_ms=%.3f range=%.3f..%.3f" % [enabled,(samples[2]+samples[3])*0.5,samples[0],samples[-1]])
	for enabled in [false,true]:
		dust.visible = enabled
		for i in 24: await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png(DUST_OUT.path_join("asylum-%s.png" % ("dust" if enabled else "clear"))) == OK, "real dust capture failed")
	# A short drift sample can be viewed as a sequence or encoded for review.
	for frame in 30:
		dust.motion_time = 8.0+frame/15.0
		dust.update_field()
		await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png(DUST_OUT.path_join("drift-%03d.png" % frame)) == OK, "drift capture failed")
	Engine.time_scale = saved_time_scale
	paused = false
	await teardown_game(game)
