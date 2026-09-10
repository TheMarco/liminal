extends SceneTree
## Actual game scene, generated rooms, production lighting and tape shader.
## Run with -- --nologo so the title card cannot cover the capture.
var view: SubViewport
var game: Node3D
var camera: Camera3D
var output := "res://build/hero-prop-review/rooms"
const CASES := [
	[7, -1, "nostalgia_prop", 0, "photo-booth", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[7, -1, "nostalgia_prop", 1, "rocket-ride", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[0, WorldGen.STYLE_HALLWAY, "nostalgia_prop", 2, "ice-machine", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[0, WorldGen.STYLE_GRAND, "nostalgia_prop", 3, "bellhop-cart", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[0, -1, "nostalgia_prop", 4, "cigarette-machine", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[1, -1, "nostalgia_prop", 5, "coffee-machine", Vector3(1.4, 1.55, 2.6), Vector3(0, .9, 0)],
	[6, -1, "nostalgia_prop", 6, "overhead-projector", Vector3(.7, .8, 1.0), Vector3(0, .35, 0)],
	[0, -1, "attributed_furnishing", "casino_change_machine", "change-machine", Vector3(1.35, 1.55, 2.3), Vector3(0, .87, 0)],
	[4, WorldGen.AIR_TRANSIT, "atomic_furnishing", "airport_travelator", "walkway", Vector3(-6.8, 2.3, 1.4), Vector3(-.6, .45, 0)],
	[4, WorldGen.AIR_ESCALATOR, "atomic_furnishing", "airport_escalator", "escalator", Vector3(3.5, 2.8, -3.4), Vector3(0, 1.5, 0.8)],
	[6, WorldGen.SCH_CAFETERIA, "atomic_furnishing", "school_servery", "servery", Vector3(3.2, 2, 3.3), Vector3(0, .9, 0)],
	[6, WorldGen.SCH_CORRIDOR, "atomic_furnishing", "school_trophy_case", "trophy-case", Vector3(1.8, 1.7, 2.8), Vector3(0, 1.2, .18)],
	[6, WorldGen.SCH_GYM, "atomic_furnishing", "school_bleachers", "bleachers", Vector3(3, 2.3, 3.4), Vector3(0, .8, -1)],
	[6, WorldGen.SCH_CAFETERIA, "atomic_furnishing", "school_cafeteria_table", "cafeteria-table", Vector3(2.5, 1.8, 2.3), Vector3(0, .4, 0)],
	[8, WorldGen.PRISON_SHOWER, "atomic_furnishing", "prison_shower_fixture", "shower-panel", Vector3(1, 1.8, -1.9), Vector3(0, 1.65, 0)],
	[8, WorldGen.PRISON_MESS, "atomic_furnishing", "prison_mess_table", "mess-table", Vector3(2.2, 1.8, 2.2), Vector3(0, .4, 0)],
	[6, WorldGen.SCH_CLASSROOM, "atomic_furnishing", "school_cupboard", "cupboard", Vector3(1.8, 1.7, 2.2), Vector3(0, 1, 0)],
	[4, WorldGen.AIR_GATE, "atomic_furnishing", "airport_gate_desk", "gate-desk", Vector3(2.3, 1.7, -2.8), Vector3(0, 0.82, 0)],
	[4, WorldGen.AIR_BAGGAGE, "atomic_furnishing", "airport_baggage_carousel", "airport", Vector3(3.8, 1.8, 4.0), Vector3(0, 0.95, 0)],
	[5, WorldGen.ASY_TREATMENT, "attributed_furnishing", "asylum_restraint_table", "asylum", Vector3(2.5, 1.6, 2.8), Vector3(0.5, 0.75, 0)],
	[7, WorldGen.MALL_KIOSKS, "attributed_furnishing", "mall_kiosk", "mall", Vector3(2.7, 1.7, 2.7), Vector3(0, 0.9, 0)],
	[8, WorldGen.PRISON_GUARD, "terminal_body", true, "terminal", Vector3(0.60, 1.38, 1.0), Vector3(-0.04, 0.94, 0.10)],
	[11, WorldGen.BLOOM_INCUBATOR, "bloom_incubator", true, "incubator", Vector3(0.8, 1.7, 2.8), Vector3(0, 1.15, 0)],
]


func _init() -> void:
	call_deferred("run")


func draw(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)


func find_fixture(theme: int, style: int, key: String, value: Variant) -> Node3D:
	var ws := WorldGen.level_seed(240721, theme)
	for radius in 25:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell or (style >= 0 and WorldGen.cell_style(ws, cell, theme) != style):
					continue
				game.cm._build(cell)
				var chunk: Chunk = game.cm.chunk_at(cell)
				if chunk == null:
					continue
				for node in chunk.find_children("*", "Node3D", true, false):
					if node.has_meta(key) and node.get_meta(key) == value:
						return node
	return null


func run() -> void:
	assert(OS.get_cmdline_user_args().has("--nologo"), "Room captures require --nologo")
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="): filter = arg.trim_prefix("--filter=")
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 120
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
	camera = Camera3D.new()
	camera.fov = 62
	view.add_child(camera)
	for entry in CASES:
		if not filter.is_empty() and not entry[4] in filter.split(","): continue
		game.player.set_physics_process(true)
		game.cm.set_process(true)
		if game.active_level != entry[0]:
			game._switch_level(entry[0])
			while game._switching: await draw(1)
		await draw(30)
		game.cm.set_process(false)
		game.player.set_physics_process(false)
		var fixture := find_fixture(entry[0], entry[1], entry[2], entry[3])
		assert(fixture != null, "No live authored fixture for " + entry[4])
		var start: Vector3 = fixture.global_transform * entry[5]
		var target: Vector3 = fixture.global_transform * entry[6]
		# The review camera can cross the chunk that owns the fixture. Load its
		# neighbours too, so missing streamed walls do not appear as black voids.
		var camera_cell := Vector2i(floori(start.x / WorldGen.CELL_SIZE), floori(start.z / WorldGen.CELL_SIZE))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				game.cm._build(camera_cell + Vector2i(dx, dz))
		game._osd_hidden_camera = true
		game._sync_osd_visible()
		camera.look_at_from_position(start, target, Vector3.UP)
		camera.current = true
		# Use the actual player torch to inspect an unlit hotel corridor.
		var review_torch: SpotLight3D = null
		if entry[4] == "ice-machine":
			review_torch = game.player.flashlight.duplicate() as SpotLight3D
			camera.add_child(review_torch)
			review_torch.visible = true
		game._post_process.set_enabled(false)
		await draw(60)
		assert(view.get_texture().get_image().save_png(output.path_join(entry[4] + "-clean.png")) == OK)
		game._post_process.set_enabled(true)
		await draw(24)
		assert(view.get_texture().get_image().save_png(output.path_join(entry[4] + "-tape.png")) == OK)
		if review_torch != null: review_torch.free()
		print("HERO_ROOM_CAPTURE ", entry[4], " camera=", start, " target=", target)
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
