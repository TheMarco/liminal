extends SceneTree
## Capture actual photographs, then verify album browsing and resume controls.
## godot --path . --audio-driver Dummy --script tools/capture_photo_album.gd \
##   -- --mode=descent --nologo --seed=21
const OUT := "/tmp/liminal-photo-album"
var game: Node3D
var view: SubViewport

func _init() -> void:
	call_deferred("run")

func draw(frames := 4) -> void:
	for i in frames:
		await process_frame

func shot(label: String) -> void:
	await draw()
	view.get_texture().get_image().save_png(OUT.path_join(label + ".png"))

func run() -> void:
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 7
	view.add_child(game)
	await draw(30)
	game._set_presence(game.Presence.SILENT)
	game.run.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._post_process.set_enabled(false)
	game._osd_layer.visible = false
	game._descent_hud.visible = false
	var director: PhotoDirector = game._photo_director
	var at := Vector2i.ZERO
	for cell in director.plan:
		if int(director.plan[cell]["type"]) == PhotoAnomaly.Type.NUMBERED_DOOR:
			at = cell
			break
	game.cm.stream_focus = Vector3(at.x * 12 + 6, 0, at.y * 12 + 6)
	game.cm.warm_up(at)
	await draw(20)
	game.cm.set_process(false)
	var anomaly: PhotoAnomaly = director._live[at]
	var plate: Label3D = anomaly._number_plate
	var cam: Camera3D = game.player.cam
	cam.global_position = plate.global_position + plate.global_basis.z * 1.8
	cam.look_at(plate.global_position)
	cam.fov = 58
	var camera: PhotoCamera = game._photo_camera
	camera.set_process(false)
	await shot("01-eye-104")
	camera._raise(true)
	await shot("02-lens-106")
	assert(camera._captured_anomalies().has(anomaly), "number not capturable")
	await camera._take_photo()
	assert(plate.text == "104", "number changed before review closed")
	await shot("03-print-106")
	camera._pending_risk = false
	camera._review_left = 0.01
	camera._process(0.02)
	assert(plate.text == "106", "number not changed after photo")
	await shot("04-eye-106")
	camera._raise(true)
	await shot("05-lens-still-106")
	var total := director.documented_count()
	assert(not camera._captured_anomalies().has(anomaly), "repeat evidence eligible")
	await camera._take_photo()
	assert(director.documented_count() == total, "repeat credit awarded")
	assert(game._photo_album_store.entries.size() == 2, "actual shutter failed to store both photos")
	assert(game._photo_album_store.entries[0].caption == "The camera shows 106; the door reads 104.", "first-shot description wrong")
	assert(game._photo_album_store.entries[1].caption == "Door 106. It read 104 before the first photograph.", "repeat description missing")
	camera._review_left = 0.01
	camera._process(0.02)
	game.run.suspended = false
	game.run.watching = false
	game.run.blackout = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera._review_left = 1.0
	assert(not game._open_photo_album(), "album interrupted review")
	camera._review_left = 0.0
	camera._doorway_reveal_left = 1.0
	assert(not game._open_photo_album(), "album interrupted door reveal")
	camera._doorway_reveal_left = 0.0
	game.run.watching = true
	assert(not game._open_photo_album(), "album interrupted video")
	game.run.watching = false
	var open_event := InputEventKey.new()
	open_event.physical_keycode = KEY_P
	open_event.pressed = true
	view.push_input(open_event)
	assert(is_instance_valid(game._photo_album), "P did not open album")
	assert(paused, "album did not pause gameplay")
	await shot("06-album")
	game._photo_album.show_photo(0)
	await shot("07-album-first")
	view.size = Vector2i(960, 540)
	await shot("08-album-small")
	assert(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(game._photo_album._next.get_global_rect()), "album controls outside small viewport")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	view.push_input(event)
	await draw(2)
	assert(not paused and not is_instance_valid(game._photo_album), "album did not close")
	assert(not is_instance_valid(game._pause_menu), "escape opened pause behind album")
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "album did not return look controls")
	print("PHOTO ALBUM CAPTURE PASS: " + OUT)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
