extends "res://tools/capture_airport_ceiling.gd"
## Production lighting, actual reported seed, looking across the belts.
## Run with -- --test-mode --descent-floor=4 --nologo.

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--descent-floor=4") and OS.get_cmdline_user_args().has("--test-mode"))
	var output := "res://build/airport-passage-review"
	DirAccess.make_dir_recursive_absolute(output)
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 1913359303
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	await draw(60)
	assert(game.active_level == 4)
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	game._osd_hidden_camera = true
	game._sync_osd_visible()
	game._descent_hud.visible = false
	game.set_process_unhandled_input(false)
	var camera := Camera3D.new()
	camera.fov = 100
	view.add_child(camera)
	camera.current = true
	for sample in [
		["concourse-crossing", Vector2i(36, 44), Vector3(6, 1.65, 0.9), Vector3(6, 1.0, 9)],
		["transit-crossing", Vector2i(34, 47), Vector3(0.9, 1.65, 6), Vector3(9, 1.0, 6)]]:
		var cell: Vector2i = sample[1]
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				game.cm._build(cell + Vector2i(dx, dz))
		var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
		camera.look_at_from_position(origin + sample[2], origin + sample[3])
		game._post_process.set_enabled(false)
		await draw(50)
		assert(view.get_texture().get_image().save_png(output.path_join(sample[0] + "-clean.png")) == OK)
		game._post_process.set_enabled(true)
		await draw(30)
		assert(view.get_texture().get_image().save_png(output.path_join(sample[0] + "-tape.png")) == OK)
		print("AIRPORT_PASSAGE_CAPTURE ", sample[0], " cell=", cell)
	for node in game.find_children("*", "AudioStreamPlayer", true, false):
		node.stop()
	for node in game.find_children("*", "AudioStreamPlayer3D", true, false):
		node.stop()
	for tween in get_processed_tweens():
		tween.kill()
	await process_frame
	game.free()
	view.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
