extends SceneTree
## Production geometry and lighting, repeatable clean/tape views.
## Run with -- --nologo --level=8 --styles=81 --out=/tmp/level-review
var view: SubViewport
var game: Node3D
var output := "res://build/four-level-overhaul"
var styles: Array[int] = []
var theme := 8
var quality := -1
var measure := false
var floor_view := false
var ceiling_view := false
var ceiling_baseline := false
var office_crt := false
var reflection_diagnostic := false

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): theme = int(arg.trim_prefix("--level="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--quality="): quality = clampi(int(arg.trim_prefix("--quality=")),0,3)
		if arg == "--measure": measure = true
		if arg == "--floor-view": floor_view = true
		if arg == "--ceiling-view": ceiling_view = true
		if arg == "--ceiling-baseline": ceiling_baseline = true
		if arg == "--office-crt": office_crt = true
		if arg == "--reflection-diagnostic": reflection_diagnostic = true
		if arg.begins_with("--styles="):
			styles.clear()
			for value in arg.trim_prefix("--styles=").split(","): styles.append(int(value))
	if styles.is_empty():
		styles.assign({0: [0,1,2,3,4,5], 1: [10,11,12,13,14,15], 2: [20,21,22,23,24,25,26], 4: [40,41,42,43,44,45,46,47,141], 5: [50,51,52,53,54,55,56,57], 6: [60,61,62,63,64,65,66,67,68], 7: [70,71,72,73,74,75,76,77,174], 8: [80,81,82,83,84,85,86,87,88], 9: [90,91,92,93,94,95,96,97], 10: [100,101,102,103,104,105,106,107], 11: [110,111,112,113,114,115,116,117,118]}[theme])
	call_deferred("run")

func draw(count: int) -> void:
	for i in count:
		if is_instance_valid(game._pause_menu): game._close_settings()
		game.player.set_physics_process(false)
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func run() -> void:
	# Explicit level/nologo startup disables campaign persistence. Test mode
	# forces Descent and interprets floor numbers in story order instead.
	assert(theme in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11])
	DirAccess.make_dir_recursive_absolute(output)
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	await draw(40)
	if game.active_level != theme:
		game._switch_level(theme)
		while game._switching: await draw(1)
		await draw(40)
	assert(game.active_level == theme)
	if quality >= 0:
		game._settings._path = "/tmp/liminal-level-capture-%d.cfg" % OS.get_process_id()
		game._settings.values.hdr_enabled = false
		game._settings.values.fullscreen = false
		game._settings.values.vsync = false
		game._settings.values.frame_limit = 0
		game._settings.apply_quality_preset(quality)
		game._apply_game_settings()
	game.cm.set_process(false)
	game.cm._cancel_pending()
	game.cm.queued.clear()
	if ceiling_baseline:
		var school := Mats.sch_ceiling() as ShaderMaterial
		school.shader = load("res://build/ceiling-textures/original-school.gdshader")
		school.set_shader_parameter("stain_amount",0.10)
		school.set_shader_parameter("bump_strength",0.02)
		school.set_shader_parameter("missing_amount",0.10)
		var casino := Mats.ceiling() as ShaderMaterial
		casino.shader = load("res://build/ceiling-textures/original-casino.gdshader")
		casino.set_shader_parameter("bump_strength",0.055)
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	if is_instance_valid(game._descent_hud): game._descent_hud.visible = false
	var camera := Camera3D.new()
	camera.fov = 78
	view.add_child(camera)
	camera.current = true
	var ws := WorldGen.level_seed(game.world_seed, theme)
	var found := {}
	for radius in 45:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, theme)
				if style in styles and not found.has(style) and WorldGen.room_id(ws, cell) == cell:
					found[style] = cell
				var tall_key := 141 if theme == 4 else 174
				if tall_key in styles and not found.has(tall_key) and style == tall_key-100 \
						and Chunk.cell_ceil_h(ws,cell,theme)>5.5 and WorldGen.room_id(ws,cell)==cell:
					found[tall_key] = cell
		if found.size() == styles.size(): break
	assert(found.size() == styles.size())
	for style in styles:
		var cell: Vector2i = found[style]
		# _build is an unconditional installer. Clear all startup children, not
		# just its dictionary: older versions of this tool left duplicate chunks.
		for child in game.cm.get_children():
			if child is Chunk: child.free()
		game.cm.chunks.clear()
		var cells := {}
		for dx in range(-1,3):
			for dz in range(-1,3):
				var at := cell+Vector2i(dx,dz)
				var owner := WorldGen.annex_room_id(ws,at) if theme==2 else WorldGen.room_id(ws,at)
				for member in WorldGen.owning_room_members(ws,owner,theme): cells[member] = true
		var ordered := cells.keys()
		ordered.sort_custom(func(a: Vector2i,b: Vector2i): return a.x<b.x or (a.x==b.x and a.y<b.y))
		for at in ordered: game.cm._build(at)
		var live_chunks := 0
		for child in game.cm.get_children():
			if child is Chunk: live_chunks += 1
		assert(live_chunks==cells.size() and game.cm.chunks.size()==cells.size())
		var chunk: Chunk = game.cm.chunk_at(cell)
		var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
		var from := Vector3(1.35, 1.72, 2.0)
		var target := Vector3(8.0, 2.25, 7.7)
		if style in [5, 11, 80, 56, 100, 110]:
			from = Vector3(1.2, 1.72, 6.0)
			target = Vector3(11, 2.0, 6)
			if WorldGen.corridor(ws, cell) == 2:
				from = Vector3(6.0, 1.72, 1.2)
				target = Vector3(6, 2.0, 11)
		elif chunk.ceil_h > 6.0:
			from = Vector3(2.0, 1.72, 2.5)
			target = Vector3(8.0, 3.5, 8.0)
		# Rack rooms reserve a transverse service aisle through their true
		# centre. Corner cameras can otherwise begin inside an imported cabinet.
		if style in [101, 105, 107]:
			var centre := WorldGen.room_centre(ws, chunk.room_root)
			var c := Vector3(centre.x, 0, centre.y) - origin
			var axis_x := true if style == 107 else chunk._r(2143 if style == 101 else 2170) < 0.5
			from = c + (Vector3(0, 1.72, -3.8) if axis_x else Vector3(-3.8, 1.72, 0))
			target = c + (Vector3(0.5, 3.0, 5.0) if axis_x else Vector3(5.0, 3.0, 0.5))
		elif style == 26:
			# The flooded hall's supports occupy x/z=2,6,10. Look along
			# the clear lane between them rather than into the first pillar.
			from = Vector3(4,1.72,4)
			target = Vector3(4.6,3.0,23)
		elif style == 57:
			var centre := WorldGen.room_centre(ws, chunk.room_root)
			var c := Vector3(centre.x, 0, centre.y) - origin
			from = c + Vector3(0.0, 1.72, 8.0)
			target = c + Vector3(0, 2.2, -6.8)
		if floor_view: target.y = 0.6
		if ceiling_view: target.y = chunk.ceil_h-0.25
		if office_crt:
			assert(theme==1 and style==12)
			from = Vector3(3,1.38,3)
			target = Vector3(6.7,1.12,6.5)
			camera.fov = 50
		camera.look_at_from_position(origin + from, origin + target)
		game._post_process.set_enabled(false)
		view.scaling_3d_scale = 1.0
		if style == 141:
			var coffer_count := 0
			for light: Light3D in chunk.find_children("*","Light3D",true,false):
				if light.is_visible_in_tree() and light.get_meta("visible_source","") == "airport_grand_coffer": coffer_count += 1
			print("COFFER_SOURCES count=",coffer_count)
		await draw(45)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-clean.png" % style)) == OK)
		if reflection_diagnostic:
			await diagnose_reflections(chunk,style)
			continue
		if measure and quality >= 0:
			# Static renderer cost at the preset's real world resolution. The
			# still above stays native so the lighting itself is easy to compare.
			if is_instance_valid(game._pause_menu):
				game._pause_menu.free()
				game._pause_menu = null
			var saved_mode := game.process_mode
			game.process_mode = Node.PROCESS_MODE_DISABLED
			paused = true
			GraphicsQuality.apply_resolution(view,game._settings,false,false)
			await draw(24)
			var samples: Array[float] = []
			for batch in 6:
				var start := Time.get_ticks_usec()
				for frame in 30: RenderingServer.force_draw(false,0.0)
				var fence := view.get_texture().get_image()
				assert(not fence.is_empty())
				samples.append((Time.get_ticks_usec()-start)/30000.0)
			var record := {"theme":theme,"style":style,"quality":quality,
				"device":RenderingServer.get_video_adapter_name(),"output_size":str(view.size),
				"world_scale":view.scaling_3d_scale,"samples_ms":samples,"unique_chunks":live_chunks,"cells":str(ordered),
				"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"method":"Six batches of 30 static frames at preset world resolution. Includes CPU submission, GPU completion and amortized readback; not gameplay FPS."}
			var report := FileAccess.open(output.path_join("room-%d-performance.json"%style),FileAccess.WRITE)
			report.store_string(JSON.stringify(record,"\t"))
			report.close()
			print("LIGHTING_CAPTURE_COST ",JSON.stringify(record))
			paused = false
			game.process_mode = saved_mode
		game._post_process.set_enabled(true)
		view.scaling_3d_scale = 480.0 / 900.0
		await draw(20)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-tape.png" % style)) == OK)
		print("LEVEL_CAPTURE style=", style, " cell=", cell, " height=", chunk.ceil_h)
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()


func diagnose_reflections(chunk: Chunk, style: int) -> void:
	var saved_mode := game.process_mode
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var environment: Environment = game.we.environment
	var original_ssr := environment.ssr_enabled
	var lights := {}
	var shadows := {}
	var probes := {}
	for node in game.find_children("*","Light3D",true,false): lights[node] = node.light_specular
	for light in lights: shadows[light] = [light.shadow_enabled,light.shadow_opacity,light.distance_fade_shadow]
	for node in game.find_children("*","ReflectionProbe",true,false): probes[node] = node.visible
	for mode in ["baseline","legacy-shadows","neighbor-spec-off","ssr-off","probes-off"]:
		environment.ssr_enabled = original_ssr and mode != "ssr-off"
		for probe in probes: probe.visible = probes[probe] and mode != "probes-off"
		for light in lights:
			light.light_specular = lights[light]
			light.shadow_enabled = shadows[light][0]
			light.shadow_opacity = shadows[light][1]
			light.distance_fade_shadow = shadows[light][2]
			if mode == "legacy-shadows" and light.has_meta("practical_shadow_tier"):
				light.shadow_enabled = quality >= int(light.get_meta("practical_shadow_tier"))
				light.shadow_opacity = 0.8 if light is AreaLight3D else 1.0
				light.distance_fade_shadow = 14.0
			var owner_chunk: Node = light.get_parent()
			while owner_chunk != null and not owner_chunk is Chunk: owner_chunk = owner_chunk.get_parent()
			if mode=="neighbor-spec-off" and owner_chunk is Chunk and owner_chunk.room_root!=chunk.room_root:
				light.light_specular = 0.0
		await draw(20)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-%s.png"%[style,mode]))==OK)
		print("REFLECTION_DIAGNOSTIC ",style," ",mode)
	for light in lights:
		light.light_specular = lights[light]
		light.shadow_enabled = shadows[light][0]
		light.shadow_opacity = shadows[light][1]
		light.distance_fade_shadow = shadows[light][2]
	for probe in probes: probe.visible = probes[probe]
	environment.ssr_enabled = original_ssr
	game.process_mode = saved_mode
