extends SceneTree
## Capture the real wall -> viewfinder -> photograph -> glowing passage flow.
## godot --path . --audio-driver Dummy --script tools/capture_photo_doorway.gd \
##   -- --mode=descent --nologo --seed=21
var out := "/tmp/liminal-photo-doorway"
var game: Node3D
var view: SubViewport

func _init() -> void:
	call_deferred("run")

func draw(frames := 4) -> void:
	for i in frames:
		await process_frame

func shot(label: String) -> void:
	await draw()
	view.get_texture().get_image().save_png(out.path_join(label + ".png"))

func run() -> void:
	Engine.max_fps = 60
	if CliOptions.parse().first_obstruction:
		out = "/tmp/liminal-photo-obstruction/floor-%02d" % CliOptions.parse().descent_floor
	DirAccess.make_dir_recursive_absolute(out)
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
	var topology: DescentTopology = game.descent_route.topology
	assert(not topology.photo_doorways().is_empty(), "seed has no photo doorway")
	var records := topology.photo_doorways()
	if CliOptions.parse().first_obstruction:
		records = records.filter(func(r: Dictionary): return bool(r.get("obstruction", false)))
	var record: Dictionary = records[0]
	var at: Vector2i = record["cell"]
	var dir := DescentTopology.edge_dir(record)
	var other: Vector2i = at + WorldGen.DIRV[dir]
	game.player.teleport(Vector3(at.x * 12.0 + 6, 0.15, at.y * 12.0 + 6))
	game.cm.stream_focus = game.player.global_position
	game.cm.warm_up(at)
	game.cm.warm_up(other)
	await draw(20)
	game.cm.set_process(false)
	game._photo_director._register_photo_doors()
	var witness: Vector2i = record.get("approach_cell", at)
	var chunk: Chunk = game.cm.chunk_at(witness)
	var seal: PhotoDoorSeal = chunk.photo_door_seals()[0]
	assert(seal.preview_ready, "door approach failed clearance")
	var cam: Camera3D = game.player.cam
	var target := seal.to_global(seal.centre) + Vector3.UP * 1.3
	var direction: Vector2i = WorldGen.DIRV[seal.dir]
	cam.global_position = target - Vector3(direction.x, 0, direction.y) * 5.8 + Vector3.UP * 0.3
	cam.look_at(target)
	cam.fov = 74
	var camera: PhotoCamera = game._photo_camera
	camera.set_process(false)
	await shot("01-boxes" if seal.obstruction else "01-wall")
	camera._raise(true)
	cam.fov = 58.0
	await shot("02-viewfinder")
	var captured := camera._captured_anomalies()
	var has_door := false
	for node in captured:
		has_door = has_door or node.id == seal.photo_id
	assert(has_door, "doorway not framed")
	await camera._take_photo()
	assert(not seal.opened, "door opened behind print")
	if seal.obstruction:
		var entries: Array = game._photo_album_store.entries
		assert(not entries.is_empty(), "obstruction photo missing from album")
		assert(str(entries[-1]["caption"]).contains(PhotoObstruction.description(seal.theme)),
			"obstruction album description missing")
	await shot("03-photograph")
	camera._pending_risk = false # isolate the reveal for this presentation audit
	camera._review_left = 0.01
	camera._process(0.02)
	assert(seal.opened, "photo did not open passage")
	cam.fov = 77.0
	await shot("04-reveal")
	await draw(165)
	await shot("05-open")
	game._post_process.set_enabled(true)
	await shot("06-open-tape")
	print("PHOTO DOOR CAPTURE PASS: " + out + " " + str(record))
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
