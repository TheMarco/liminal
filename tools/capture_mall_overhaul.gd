extends SceneTree
## Production mall geometry and lighting, with repeatable before/after cameras.
## godot --path . --audio-driver Dummy --disable-render-loop --script
## tools/capture_mall_overhaul.gd -- --level=7 --nologo
## --out=/tmp/mall-review [--styles=74,70]
var view: SubViewport
var game: Node3D
var output := "res://build/mall-overhaul"
var styles: Array[int] = [74, 70, 71, 72, 73, 75, 76, 77, 174]

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--styles="):
			styles.clear()
			for value in arg.trim_prefix("--styles=").split(","): styles.append(int(value))
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
	assert(OS.get_cmdline_user_args().has("--level=7"))
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
	if game.active_level != 7:
		game._switch_level(7)
		while game._switching: await draw(1)
		await draw(40)
	assert(game.active_level == 7)
	game.cm.set_process(false)
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	if is_instance_valid(game._descent_hud): game._descent_hud.visible = false
	var camera := Camera3D.new()
	camera.fov = 78
	view.add_child(camera)
	camera.current = true
	var ws := WorldGen.level_seed(game.world_seed, 7)
	var found := {}
	for radius in 25:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, 7)
				if style in styles and not found.has(style) and WorldGen.room_id(ws, cell) == cell:
					found[style] = cell
				if 174 in styles and not found.has(174) and style == WorldGen.MALL_ATRIUM \
						and Chunk.cell_ceil_h(ws, cell, 7) > 5.5 and WorldGen.room_id(ws, cell) == cell:
					found[174] = cell
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
		if style == 174:
			from = Vector3(2.0, 1.72, 3.0)
			target = Vector3(8.0, 3.25, 8.0)
		if style == WorldGen.MALL_CORRIDOR:
			from = Vector3(1.2, 1.72, 5.5)
			target = Vector3(11, 2.0, 6)
			if WorldGen.corridor(ws, cell) == 2:
				from = Vector3(5.5, 1.72, 1.2)
				target = Vector3(6, 2.0, 11)
		camera.look_at_from_position(origin + from, origin + target)
		if style == WorldGen.MALL_FOODCOURT:
			for node in chunk.find_children("*", "Node3D", true, false):
				if node.has_meta("mall_foodcourt_vendor"):
					camera.look_at_from_position(node.global_transform * Vector3(3.4, 1.72, -1.0),
						node.global_transform * Vector3(0, 2.0, 4.7))
					break
		game._post_process.set_enabled(false)
		view.scaling_3d_scale = 1.0
		await draw(45)
		assert(view.get_texture().get_image().save_png(output.path_join("mall-%d-clean.png" % style)) == OK)
		game._post_process.set_enabled(true)
		view.scaling_3d_scale = 480.0 / 900.0
		await draw(20)
		assert(view.get_texture().get_image().save_png(output.path_join("mall-%d-tape.png" % style)) == OK)
		print("MALL_CAPTURE style=", style, " cell=", cell, " height=", chunk.ceil_h)
	# Inspect authored details at their live positions, including the serving
	# counter that the wide food-court camera may see from its back wall.
	var details := [
		["vendor", "mall_foodcourt_vendor", true, Vector3(3.4, 1.72, -1.0), Vector3(0, 2.0, 4.7)],
		["fountain", "atomic_furnishing", "mall_fountain", Vector3(-2.8, 1.72, -3.0), Vector3(0, 0.45, 0)],
		["palm", "atomic_furnishing", "mall_palm_planter", Vector3(1.4, 1.60, -2.5), Vector3(0, 1.5, 0)],
		["poster", "atomic_furnishing", "mall_poster_stand", Vector3(0.9, 1.6, -2.7), Vector3(0, 1.2, 0)],
	]
	for entry in details:
		for node in game.cm.find_children("*", "Node3D", true, false):
			if node.has_meta(entry[1]) and node.get_meta(entry[1]) == entry[2]:
				camera.look_at_from_position(node.global_transform * entry[3], node.global_transform * entry[4])
				game._post_process.set_enabled(false)
				view.scaling_3d_scale = 1.0
				await draw(35)
				assert(view.get_texture().get_image().save_png(output.path_join("detail-%s.png" % entry[0])) == OK)
				print("MALL_DETAIL ", entry[0])
				break
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
