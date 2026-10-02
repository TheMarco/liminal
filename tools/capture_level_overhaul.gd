extends SceneTree
## Production geometry and lighting, repeatable clean/tape views.
## Run with -- --nologo --level=8 --styles=81 --out=/tmp/level-review
var view: SubViewport
var game: Node3D
var output := "res://build/four-level-overhaul"
var styles: Array[int] = []
var theme := 8

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): theme = int(arg.trim_prefix("--level="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--styles="):
			styles.clear()
			for value in arg.trim_prefix("--styles=").split(","): styles.append(int(value))
	if styles.is_empty():
		styles.assign({5: [50,51,52,53,54,55,56,57], 8: [80,81,82,83,84,85,86,87,88], 10: [100,101,102,103,104,105,106,107], 11: [110,111,112,113,114,115,116,117,118]}[theme])
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
	assert(theme in [5, 8, 10, 11])
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
	game.cm.set_process(false)
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
		if found.size() == styles.size(): break
	assert(found.size() == styles.size())
	for style in styles:
		var cell: Vector2i = found[style]
		for dx in range(-1, 3):
			for dz in range(-1, 3): game.cm._build(cell + Vector2i(dx, dz))
		var chunk: Chunk = game.cm.chunk_at(cell)
		var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
		var from := Vector3(1.35, 1.72, 2.0)
		var target := Vector3(8.0, 2.25, 7.7)
		if style in [80, 56, 100, 110]:
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
		elif style == 57:
			var centre := WorldGen.room_centre(ws, chunk.room_root)
			var c := Vector3(centre.x, 0, centre.y) - origin
			from = c + Vector3(0.0, 1.72, 8.0)
			target = c + Vector3(0, 2.2, -6.8)
		camera.look_at_from_position(origin + from, origin + target)
		game._post_process.set_enabled(false)
		view.scaling_3d_scale = 1.0
		await draw(45)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-clean.png" % style)) == OK)
		game._post_process.set_enabled(true)
		view.scaling_3d_scale = 480.0 / 900.0
		await draw(20)
		assert(view.get_texture().get_image().save_png(output.path_join("room-%d-tape.png" % style)) == OK)
		print("LEVEL_CAPTURE style=", style, " cell=", cell, " height=", chunk.ceil_h)
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
