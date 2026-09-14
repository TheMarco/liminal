extends SceneTree
## Native visual fixture for album compare panes; never boots Main or writes a profile.
var failures: Array[String] = []

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	for frame in 8: await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.07, 0.065, 0.045)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.5, 4)
	camera.look_at(Vector3(0, 1.3, 0))
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.scale = Vector3(8, 4, 0.2)
	wall.position = Vector3(0, 2, -1)
	world.add_child(wall)
	var door := MeshInstance3D.new()
	door.mesh = BoxMesh.new()
	door.scale = Vector3(1.3, 2.3, 0.1)
	door.position = Vector3(0, 1.15, -0.85)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.19, 0.13, 0.08)
	door.material_override = paint
	world.add_child(door)
	var number := Label3D.new()
	number.text = "104"
	number.position = Vector3(0, 1.7, -0.78)
	number.font = VhsOsd.FONT
	number.font_size = 96
	number.pixel_size = 0.003
	world.add_child(number)
	await settle()
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	number.text = "106"
	await settle()
	await RenderingServer.frame_post_draw
	var second := root.get_texture().get_image()
	world.free()
	var store := PhotoAlbumStore.new()
	store.configure(104, false)
	check(store.add_photo(first, {"floor": 1, "theme": "ROOM", "caption": "104"}) == OK, "first fixture photo failed")
	check(store.add_photo(second, {"floor": 1, "theme": "ROOM", "caption": "106"}) == OK, "second fixture photo failed")
	var album := PhotoAlbum.new()
	album.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(album)
	album.open(store)
	await settle()
	album._toggle_pin()
	var pinned: Texture2D = album._pinned_view.image.texture
	album.show_photo(0)
	check(album._pinned_view.image.texture == pinned and album._pinned_view.caption == "PINNED · PHOTO 02", "fixture pin changed")
	album._current_view.zoom_by(2.0)
	album._current_view.pan_by(Vector2(20, 10))
	check(album._current_view.zoom == 2.0 and album._pinned_view.zoom == 1.0, "fixture compare state not independent")
	for pair in [[Vector2i(1280, 720), "album-1280.png"], [Vector2i(640, 480), "album-640.png"], [Vector2i(720, 1280), "album-portrait.png"]]:
		root.size = pair[0]
		await settle()
		await RenderingServer.frame_post_draw
		var dir := "/tmp/liminal-round4-visuals"
		DirAccess.make_dir_recursive_absolute(dir)
		root.get_texture().get_image().save_png(dir.path_join(pair[1]))
		check(not album._current_view.get_global_rect().intersects(album._pinned_view.get_global_rect()), "fixture panes overlap")
	check(store.image_at(0).get_pixel(0, 0).is_equal_approx(first.get_pixel(0, 0)), "fixture source image mutated")
	album.free()
	print("Album visual fixture: %s" % [failures])
	quit(0 if failures.is_empty() else 1)
