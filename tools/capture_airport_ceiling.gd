extends SceneTree
## Production Airport rooms, looking up at the real Main ceiling.
## Run with --test-mode --descent-floor=4 --nologo.
var view: SubViewport
var game: Node3D
const OUT := "res://build/airport-ceiling-review"

func _init() -> void:
	call_deferred("run")

func draw(count: int) -> void:
	for i in count:
		# A minimized review renderer must not photograph the focus-loss menu.
		if is_instance_valid(game._pause_menu):
			game._close_settings()
		game.player.set_physics_process(false)
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func cells() -> Dictionary:
	var found := {}
	var ws := WorldGen.level_seed(game.world_seed, 4)
	for radius in range(1, 15):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, 4)
				var height := Chunk.cell_ceil_h(ws, cell, 4)
				if height >= 6.2 and style != WorldGen.AIR_TRANSIT and cell != Vector2i.ZERO \
						and WorldGen.r01(ws, cell.x, cell.y, 8) < 0.04 and not found.has("grand-unlit"):
					found["grand-unlit"] = cell
				var key := ""
				if style == WorldGen.AIR_CONCOURSE:
					key = "concourse"
				if style == WorldGen.AIR_GATE:
					key = "AIR_GATE"
				if height >= 6.0:
					key = "grand-hall"
				elif height >= 4.39 and style != WorldGen.AIR_ESCALATOR:
					key = "regular-room-4.4m"
				if style == WorldGen.AIR_TRANSIT:
					var dir := WorldGen.corridor(ws, cell)
					var along := dir == 1 if dir != 0 else WorldGen.r01(ws, 0, cell.y, 511) < 0.5
					key = "AIR_TRANSIT-x" if along else "AIR_TRANSIT-z"
				if key != "" and not found.has(key):
					found[key] = cell
		if found.size() == 7:
			break
	return found

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--descent-floor=4") and OS.get_cmdline_user_args().has("--test-mode"))
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
	assert(game.active_level == 4 and game.cm.theme == 4, "Airport jump failed")
	await draw(30)
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	game._descent_hud.visible = false
	game.set_process_unhandled_input(false)
	var camera := Camera3D.new()
	camera.fov = 82
	view.add_child(camera)
	camera.current = true
	var cases := cells()
	assert(cases.size() == 7)
	for key in cases:
		var cell: Vector2i = cases[key]
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				game.cm._build(cell + Vector2i(dx, dz))
		var chunk: Chunk = game.cm.chunk_at(cell)
		var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
		assert(chunk.theme == 4)
		var from := Vector3(2.3, 1.5, 2.7)
		var target := Vector3(6, chunk.ceil_h, 6)
		if chunk.style == WorldGen.AIR_TRANSIT:
			target.y = 3.5
		if key == "AIR_TRANSIT-x":
			from = Vector3(1.0, 1.5, 6)
		if key == "AIR_TRANSIT-z":
			from = Vector3(6, 1.5, 1.0)
		camera.look_at_from_position(origin + from, origin + target)
		game._post_process.set_enabled(false)
		await draw(50)
		assert(view.get_texture().get_image().save_png(OUT.path_join(key + "-clean.png")) == OK)
		game._post_process.set_enabled(true)
		await draw(30)
		assert(view.get_texture().get_image().save_png(OUT.path_join(key + "-tape.png")) == OK)
		print("AIRPORT_CEILING_CAPTURE ", key, " cell=", cell)
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
