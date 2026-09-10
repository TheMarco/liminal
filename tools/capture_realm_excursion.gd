extends SceneTree
## Capture the experimental cross-realm excursion lifecycle.
## godot --path . --audio-driver Dummy --script tools/capture_realm_excursion.gd -- --realm-visit --seed=21

const OUT := "/tmp/liminal-realm-visit"
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

func wait_until(predicate: Callable, seconds: float, message: String) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(predicate.call(), message)

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
	game.world_seed = 21
	view.add_child(game)
	await draw(30)
	var visit: RealmExcursion = game._realm_visit
	assert(visit != null, "realm visit was not enabled")
	await wait_until(func(): return visit.phase == RealmExcursion.Phase.WAITING,
		30.0, "realm preview did not prepare")
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._post_process.set_enabled(false)
	game._osd_layer.visible = false
	game._descent_hud.visible = false
	var cam: Camera3D = game.player.cam
	var target := visit.source_centre + Vector3.UP * 1.3
	var distance := 0.8 if OS.get_cmdline_user_args().has("--realm-close-entry") else 5.8
	game.player.teleport(visit.source_centre - visit.source_forward * distance + Vector3.UP * 0.15)
	game.player.rotation.y = visit.return_yaw
	cam.global_position = visit.source_centre - visit.source_forward * distance + Vector3.UP * 1.6
	cam.look_at(target)
	cam.fov = 74.0
	var camera: PhotoCamera = game._photo_camera
	camera.set_process(false)
	await shot("01-normal")
	camera._raise(true)
	cam.fov = 58.0
	await shot("02-viewfinder")
	await camera._take_photo()
	assert(not visit.seal.opened, "realm doorway opened before print review")
	await shot("03-photograph")
	camera._pending_risk = false
	camera._review_left = 0.01
	camera._process(0.02)
	assert(visit.seal.opened, "realm doorway did not open")
	await draw(4)
	await draw(165)
	await shot("04-open")
	# Exercise ordinary movement through the aperture. Calling enter() directly
	# hid the difference between seeing a window and successfully opening it.
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.dev_walk = true
	await wait_until(func(): return visit.phase == RealmExcursion.Phase.VISITING,
		8.0, "walking through photographed entrance did not enter realm")
	game.player.dev_walk = false
	game.player.set_process(false)
	game.player.set_physics_process(false)
	assert(visit.phase == RealmExcursion.Phase.VISITING, "realm entry failed")
	await shot("05-arrival")
	visit.threats.spawned.connect(func():
		for figure in visit.threats.active_figures():
			figure.suppressed = true)
	await wait_until(func(): return visit.elapsed >= 12.0 and visit.total_spawned >= 1, 15.0,
		"realm attackers did not spawn")
	await shot("06-attackers")
	camera.set_process(true)
	camera._raise(true)
	await camera._take_photo()
	var found_destination := false
	for entry in game._photo_album_store.entries:
		if int(entry.get("floor", -1)) == visit.destination_floor + 1 \
				and str(entry.get("caption", "")).contains("mall"):
			found_destination = true
			break
	assert(found_destination, "destination photo was not recorded")
	await wait_until(func(): return visit.elapsed >= RealmExcursion.DURATION - visit.collapse_seconds() * 0.6, 20.0,
		"realm did not reach collapse window")
	await shot("07-collapse")
	await wait_until(func(): return visit.phase == RealmExcursion.Phase.SPENT,
		8.0, "realm did not collapse")
	await draw(60)
	await shot("08-return")
	print("REALM VISIT CAPTURE PASS: " + OUT)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
