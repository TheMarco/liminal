extends SceneTree
## Production office rooms, looking up at the actual ceiling/fixtures.
## godot --path . --audio-driver Dummy --script tools/capture_office_ceiling.gd -- --nologo
var view: SubViewport
var game: Node3D
const OUT := "res://build/office-ceiling-review"


func _init() -> void:
	call_deferred("run")


func draw(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)


func cells() -> Dictionary:
	var found := {}
	var ws := WorldGen.level_seed(240721, 1)
	for radius in range(1, 15):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, 1)
				var key := ""
				if style == WorldGen.OFFICE_EMPTY: key = "room"
				if style == WorldGen.OFFICE_CORRIDOR:
					key = "corridor-z" if WorldGen.corridor(ws, cell) == 2 else "corridor-x"
				if key != "" and not found.has(key): found[key] = cell
		if found.size() == 3: break
	return found


func run() -> void:
	assert(OS.get_cmdline_user_args().has("--nologo"))
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	await draw(30)
	game._switch_level(1)
	while game._switching: await draw(1)
	await draw(30)
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	var camera := Camera3D.new()
	camera.fov = 82
	view.add_child(camera)
	camera.current = true
	var cases := cells()
	assert(cases.size() == 3)
	for key in cases:
		var cell: Vector2i = cases[key]
		for dx in range(-1, 2):
			for dz in range(-1, 2): game.cm._build(cell + Vector2i(dx, dz))
		var chunk: Chunk = game.cm.chunk_at(cell)
		var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
		var from := Vector3(2.3, 1.5, 2.7)
		var target := Vector3(6, chunk.ceil_h, 6)
		if key == "corridor-x": from = Vector3(1.0, 1.5, 6)
		if key == "corridor-z": from = Vector3(6, 1.5, 1.0)
		camera.look_at_from_position(origin + from, origin + target)
		game._post_process.set_enabled(false)
		await draw(50)
		assert(view.get_texture().get_image().save_png(OUT.path_join(key + "-clean.png")) == OK)
		game._post_process.set_enabled(true)
		await draw(30)
		assert(view.get_texture().get_image().save_png(OUT.path_join(key + "-tape.png")) == OK)
		print("OFFICE_CEILING_CAPTURE ", key, " cell=", cell)
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
