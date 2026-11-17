extends SceneTree
const LIBRARY = preload("res://scripts/video_preset_library.gd")
const IO = preload("res://scripts/video_preset_io.gd")
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); printerr(label)
func _initialize() -> void: _run.call_deferred()
func frames(count: int) -> void:
	for frame in count:
		await process_frame
		RenderingServer.force_draw()
func _run() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--nologo"):
		printerr("Native GPU and --nologo required"); quit(1); return
	change_scene_to_file("res://scenes/startup.tscn")
	var game: Node
	for frame in 240:
		await process_frame
		game = get_first_node_in_group("level_manager")
		if game!=null and game.get("_post_process")!=null: break
	if game==null: quit(1); return
	game.player.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var output := "/tmp/liminal-curated-review/office"
	var quick := false
	var selection: Array[int] = []
	var hdr := false
	var motion := OS.get_cmdline_user_args().has("--motion")
	var hud_review := OS.get_cmdline_user_args().has("--hud-review")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
		if argument=="--quick": quick = true
		if argument.begins_with("--looks="):
			for number in argument.trim_prefix("--looks=").split(","): selection.append(int(number)-1)
		if argument=="--hdr-review": hdr = true
	DirAccess.make_dir_recursive_absolute(output)
	game._settings._path = "/tmp/liminal-curated-%d.cfg" % OS.get_process_id()
	game._settings.values = GameSettings.DEFAULTS.duplicate(true)
	game._settings.values.fullscreen = false
	game._settings.values.hdr_enabled = hdr
	game._settings.values.handheld_camera = false
	game._settings.values.ntsc_auto_faults = false
	game._settings.values.video_quality_override = 2
	game._settings.changed.emit()
	check(not game._progress_enabled,"Capture must not save campaign progress")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,800)
	Engine.max_fps = 60
	await frames(50)
	if hud_review:
		# Real HUD nodes with fixed objective text, without starting a campaign.
		game.set_process(false)
		game.descent = true
		var run := DescentRun.new()
		game.add_child(run)
		run.set_process(false)
		run.suspended = false
		var hud := DescentHUD.new()
		game.add_child(hud)
		hud.configure(game.player,DescentRoute.new(),run,240721,1)
		hud.set_photo_progress(2,3)
		hud.evidence_target = game.player.global_position+Vector3(28,0,0)
		hud.set_active(true)
		game._charger_distance.text = "CHARGER 125m"
		game._charger_distance.show()
		for extent in [Vector2i(640,480),Vector2i(960,720),Vector2i(1280,800),Vector2i(1920,1080)]:
			root.size = extent
			await frames(4)
			game._apply_hud_scaling()
			await frames(4)
			for label: Label in [hud._photo,hud._photo_warn,game._charger_distance]:
				check(label.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(extent)).encloses(label.get_global_rect()),"HUD clips at %s: %s" % [extent,label.text])
			check(not hud._photo.get_global_rect().intersects(hud._photo_warn.get_global_rect()),"Evidence overlaps photos at "+str(extent))
			check(not hud._photo_warn.get_global_rect().intersects(game._charger_distance.get_global_rect()),"Charger overlaps evidence at "+str(extent))
		root.size = Vector2i(1280,800)
		await frames(8)
		game._apply_hud_scaling()
	game._open_settings()
	game._pause_menu._select_tab("Visual Effects")
	await frames(4)
	root.get_texture().get_image().save_png(output.path_join("complete-look-menu.png"))
	game._pause_menu.preset_workshop_requested.emit()
	await frames(12)
	var workshop: CanvasLayer = game._video_workshop
	var panel: Control = workshop.panel
	var host: Control = game.get_meta("ntscrt_video_host")
	check(not panel._tabs.visible,"Browser did not hide detailed controls")
	var results: Array[Dictionary] = []
	for index in LIBRARY.LOOKS.size():
		if quick and index not in [0,8,11,14,19]: continue
		if not selection.is_empty() and index not in selection: continue
		panel.select_curated(index)
		# Feedback can look correct initially, then run away over later frames.
		await frames(120 if index==19 else 22)
		check(host.presenter.last_error.is_empty(),LIBRARY.LOOKS[index].name+": "+host.presenter.last_error)
		if index in [8,14]:
			root.get_texture().get_image().save_png(output.path_join("browser-%02d.png" % (index+1)))
		var folder := output.path_join("%02d-%s" % [index+1,LIBRARY.LOOKS[index].id])
		var capture: Dictionary = await panel.capture_preset(folder)
		check(capture.error.is_empty(),"Capture failed "+str(index))
		if index==19:
			var picture := Image.load_from_file(folder.path_join("preview.png"))
			var white := 0
			var samples := 0
			for y in range(picture.get_height()/10,picture.get_height()*9/10,8):
				for x in range(picture.get_width()/10,picture.get_width()*9/10,8):
					var color := picture.get_pixel(x,y)
					if minf(color.r,minf(color.g,color.b))>0.98: white += 1
					samples += 1
			check(float(white)/maxi(samples,1)<0.9,"Security-desk CRT became a white screen")
		var restored := IO.load_json(folder.path_join("preset.json"))
		check(restored.error.is_empty() and IO.encode(restored.profile).settings==IO.encode(panel.profile).settings,"Incomplete captured look")
		results.append({"id":LIBRARY.LOOKS[index].id,"name":LIBRARY.LOOKS[index].name,"route":LIBRARY.LOOKS[index].route,"directory":folder})
		if motion:
			workshop.visible = false
			var saw_fault := false
			var start_clock: float = host.presenter._clock
			var start_usec := Time.get_ticks_usec()
			var frame := 0
			while Time.get_ticks_usec()-start_usec<3000000:
				await frames(1)
				frame += 1
				if frame<16:
					root.get_texture().get_image().save_png(folder.path_join("motion-%02d.png" % frame))
				var state: Dictionary = host.presenter.effective_game_state()
				if float(state.get("fault_amount",0.0))>0.1 and not saw_fault:
					saw_fault = true
					await frames(3)
					root.get_texture().get_image().save_png(folder.path_join("defect.png"))
			check(saw_fault==(panel.profile.ambient_fault_rate>0.0),"Unexpected ambient defect behavior: "+LIBRARY.LOOKS[index].name)
			check(not host.presenter.visible or host.presenter._clock>start_clock,"Video clock is not running in workshop")
			workshop.visible = true
		print("CAPTURED ",index+1," ",LIBRARY.LOOKS[index].name)
	panel.select_curated(0)
	await frames(8)
	check(not game._post_process._grain_overlay.visible and not host.presenter.visible,"Clean reference failed to remove prior color/CRT")
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	panel.close()
	game._close_settings()
	await frames(4)
	check(not paused,"Workshop left game paused")
	current_scene.queue_free()
	await frames(8)
	print("CURATED_GAME_CAPTURE ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
