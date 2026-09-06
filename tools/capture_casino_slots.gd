extends SceneTree
## Capture the new machines in an actual generated Level 1 casino room.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
## --script tools/capture_casino_slots.gd -- --nologo --level=0 --seed=4242

var view: SubViewport
var game: Node3D


func _init() -> void:
	call_deferred("run")


func draw(frames: int) -> void:
	for i in frames:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)


func run() -> void:
	Engine.max_fps = 120
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.world_seed = 4242
	view.add_child(game)
	await draw(100)
	game.player.set_physics_process(false)
	var ws := WorldGen.level_seed(4242, 0)
	var cell := Vector2i.ZERO
	var found := false
	for radius in range(1, 14):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var c := Vector2i(x, z)
				if WorldGen.room_id(ws, c) != c or WorldGen.cell_style(ws, c, 0) != WorldGen.STYLE_SLOTS:
					continue
				var probe := Chunk.new(ws, c, 0)
				var count := probe.slot_machine_count()
				probe.free()
				if count >= 8:
					cell = c
					found = true
					break
			if found: break
		if found: break
	assert(found, "No full casino bank found")
	var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
	var position := origin + Vector3(6, .15, 10.9)
	game.player.teleport(position)
	game.player.rotation.y = 0.0
	game.player._pitch = 0.0
	game.cm.stream_focus = position
	game.cm.warm_up(cell)
	await draw(120)
	game.player.set_process(false)
	var room: Chunk = game.cm.chunk_at(cell)
	var bank: Array[Node3D] = []
	var forward := Vector3.ZERO
	for node in room.get_children():
		if node is Node3D and node.has_meta("slot_machine"):
			var front: Vector3 = node.global_basis.z.normalized()
			if forward == Vector3.ZERO:
				forward = front
			if front.dot(forward) > .99:
				bank.append(node)
	assert(not bank.is_empty())
	var centre := Vector3.ZERO
	for node in bank: centre += node.global_position
	centre /= bank.size()
	var camera: Camera3D = game.player.cam
	camera.fov = 76.0
	camera.global_position = centre + forward * 3.55 + Vector3.UP * 1.76
	camera.look_at(centre + Vector3.UP * 1.36)
	camera.current = true
	game._osd_layer.visible = false
	game._post_process.set_enabled(false)
	view.scaling_3d_scale = 1.0
	await draw(32)
	var out := "res://build/procedural-review/after"
	DirAccess.make_dir_recursive_absolute(out)
	view.get_texture().get_image().save_png(out.path_join("vegas-slots-in-game.png"))
	game._post_process.set_enabled(true)
	await draw(32)
	view.get_texture().get_image().save_png(out.path_join("vegas-slots-in-game-tape.png"))
	print("CASINO_CAPTURE: cell=%s seed=4242, two production-lighting views" % cell)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
