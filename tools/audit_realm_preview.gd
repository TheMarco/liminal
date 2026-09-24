extends SceneTree
## Rendered regression for initial realm frames and recorded doors after streaming.
## godot --path . --audio-driver Dummy --script tools/audit_realm_preview.gd -- --test-mode --seed=1021555651 --descent-floor=2
var game: Node3D
var view: SubViewport
const OUT := "/tmp/liminal-realm-preview"

func _init() -> void:
	call_deferred("run_test")

func _keep_audit_running() -> void:
	# A rendered audit must survive the desktop returning focus to Codex.
	if is_instance_valid(game) and is_instance_valid(game._pause_menu):
		game._pause_menu.free()
		game._pause_menu = null
		paused = false

func _check_aperture_projection(visit: RealmExcursion) -> void:
	var aperture := (visit.window.mesh as QuadMesh).size
	for corner in [Vector2(-0.5, 0.5), Vector2(0.5, -0.5)]:
		var source := visit.window.to_global(Vector3(corner.x * aperture.x, corner.y * aperture.y, 0.0))
		var destination := visit.destination_position + visit._rotation * (source - visit.source_centre)
		var pixel := visit.preview_camera.unproject_position(destination)
		var expected := Vector2(corner.x + 0.5, 0.5 - corner.y) * Vector2(visit.preview.size)
		assert(pixel.distance_to(expected) < 1.0, "realm view slides or stretches across the aperture")
	var camera := visit.preview_camera
	assert(not camera.is_position_in_frustum(camera.global_position - camera.global_basis.z * (camera.near * 0.5)),
		"destination geometry before the entrance is not clipped")

func _check_office_detail(image: Image) -> void:
	var darkest := INF
	var lightest := 0.0
	for x in range(6, 18):
		for y in range(6, 18):
			var color := image.get_pixel(image.get_width() * x / 24, image.get_height() * y / 24)
			var value := (color.r + color.g + color.b) / 3.0
			darkest = minf(darkest, value)
			lightest = maxf(lightest, value)
	assert(lightest - darkest > 0.15, "Office shelves disappeared behind a flat destination wall")

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(60.0).timeout.connect(func(): push_error("Realm preview timed out"); quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	process_frame.connect(_keep_audit_running)
	game.run.set_physics_process(false)
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var visit: RealmExcursion = game._realm_visit
	var cam: Camera3D = game.player.cam
	game.player.teleport(visit.source_centre - visit.source_forward * 5.8 + Vector3.UP * 0.15)
	cam.global_position = visit.source_centre - visit.source_forward * 5.8 + Vector3.UP * 1.6
	cam.look_at(visit.source_centre + Vector3.UP * 1.35)
	game.cm.stream_focus = game.player.global_position
	var camera: PhotoCamera = game._photo_camera
	camera.set_process(false)
	while visit.phase == RealmExcursion.Phase.PREPARING or not is_instance_valid(visit.window):
		await process_frame
	var id := visit.seal.photo_id
	assert(not visit.seal.opened, "fresh doorway opened without a photograph")
	assert((visit.window.layers & cam.cull_mask) == 0, "fresh doorway visible without camera")
	camera._raise(true)
	cam.fov = PhotoCamera.AIM_FOV
	for frame in 3:
		await process_frame
		RenderingServer.force_draw()
		view.get_texture().get_image().save_png(OUT.path_join("lens-%02d.png" % frame))
	for stance: Vector2 in [Vector2(12.0, 0.0), Vector2(20.0, 0.0), Vector2(5.8, 3.0), Vector2(12.0, -4.0), Vector2(0.6, 0.0)]:
		var distance := stance.x
		var lateral := visit.source_forward.cross(Vector3.UP) * stance.y
		game.player.teleport(visit.source_centre - visit.source_forward * distance + lateral + Vector3.UP * 0.15)
		cam.global_position = visit.source_centre - visit.source_forward * distance + lateral + Vector3.UP * 1.6
		cam.look_at(visit.source_centre + Vector3.UP * 1.35)
		visit._process(0.0)
		for frame in 3:
			await process_frame
			RenderingServer.force_draw()
		_check_aperture_projection(visit)
		var label := "%02d-%+02d" % [int(distance), int(stance.y)]
		view.get_texture().get_image().save_png(OUT.path_join("approach-" + label + ".png"))
		var destination_image := visit.preview.get_texture().get_image()
		destination_image.save_png(OUT.path_join("destination-" + label + ".png"))
		if stance == Vector2(20.0, 0.0):
			_check_office_detail(destination_image)
		camera._lower()
		visit._process(0.0)
		assert(not visit.window.visible and not visit.seal.opened, "unphotographed realm exposed without camera")
		camera._raise(true)
	game.player.teleport(visit.source_centre - visit.source_forward * 5.8 + Vector3.UP * 0.15)
	cam.global_position = visit.source_centre - visit.source_forward * 5.8 + Vector3.UP * 1.6
	cam.look_at(visit.source_centre + Vector3.UP * 1.35)
	visit._process(0.0)
	await process_frame
	assert(camera._captured_anomalies().any(func(a: PhotoAnomaly): return a.id == id), "visible realm not capturable")
	var before: int = game._photo_director.documented_count()
	RenderingServer.force_draw.call_deferred()
	await camera._take_photo()
	assert(game._photo_director.documented_count() == before + 1, "first photo did not count")
	assert(not visit.seal.opened, "door opened before review")
	camera._pending_risk = false
	camera._review_left = 0.01
	camera._process(0.02)
	assert(visit.seal.opened, "review did not open doorway")
	camera._lower()
	await process_frame
	assert((visit.window.layers & cam.cull_mask) != 0, "documented opening hidden from eye")
	# Retire subjects as streaming does, then register against the retained
	# topology and evidence. Recorded doors must still be identifiable in film.
	for subject in game._photo_director._live_doors.values():
		if is_instance_valid(subject): subject.free()
	game._photo_director._live_doors.clear()
	game._photo_director._register_photo_doors()
	camera._raise(true)
	assert(camera.viewfinder_feedback().text == "ALREADY DOCUMENTED", "recorded realm lost recognition after streaming")
	assert(not camera._captured_anomalies().any(func(a: PhotoAnomaly): return a.id == id), "repeat doorway awards credit")
	RenderingServer.force_draw.call_deferred()
	await camera._take_photo()
	assert(game._photo_director.documented_count() == before + 1, "repeat photo changed evidence")
	assert(id in game._photo_album_store.entries[-1].anomaly_ids, "repeat photo lost doorway caption")
	# An opened door must still render when first approached from beyond the
	# old cue radius. Resize also invalidates the previous texture's frame.
	camera._lower()
	game.player.teleport(visit.source_centre - visit.source_forward * 20.0 + Vector3.UP * 0.15)
	cam.global_position = game.player.global_position + Vector3.UP * 1.4
	cam.look_at(visit.source_centre + Vector3.UP * 1.35)
	visit.preview.size = Vector2i(32, 32)
	visit._process(0.0)
	assert(visit.preview.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "visible distant opening is not rendering")
	assert(not visit.window.visible, "resized preview exposed before its first frame")
	RenderingServer.force_draw()
	assert(visit.window.visible, "rendered opening stayed hidden")
	print("REALM PREVIEW PASS: near/far/oblique projection, distant room detail, camera-only discovery, first photo, streamed recognition, no repeat credit; " + OUT)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
