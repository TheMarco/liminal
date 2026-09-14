extends "res://tools/lib/audit_base.gd"
## Rendered A/B check with the real game, fog, lighting and CRT at 1440x900.
## The same resident geometry/camera sweep is used in both runs; only chunk
## visibility changes. This measures rendering cost, not build/allocation cost
## (use profile_streaming.gd for that). Never reads/writes real progress.
## godot --path . --script tools/profile_draw_distance.gd -- \
##   --test-mode --descent-floor=4 --seed=240721 --nologo
const OUT := "res://build/draw-distance-review"
var game: Node3D
var view: SubViewport

func frame() -> void:
	if is_instance_valid(game._pause_menu):
		game._close_settings()
	game.run.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._set_presence(game.Presence.SILENT)
	await process_frame

func settle() -> void:
	for i in 90:
		await frame()

func sweep(label: String) -> void:
	var samples: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	var yaw: float = game.player.rotation.y
	for i in 240:
		game.player.rotation.y = yaw + TAU * float(i) / 240.0
		var start := Time.get_ticks_usec()
		await frame()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	game.player.rotation.y = yaw
	var total := 0.0
	for ms in samples:
		total += ms
	samples.sort()
	draws.sort()
	primitives.sort()
	print("DRAW_DISTANCE %s theme=%d frames=%d avg=%.2f p95=%.2f max=%.2f draws_median=%.0f primitives_median=%.0f resident=%d" % [
		label, game.cm.theme, samples.size(), total / samples.size(), samples[227], samples[-1],
		draws[120], primitives[120], game.cm.chunks.size()])

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--test-mode"))
	create_timer(120.0, true).timeout.connect(func(): quit(1))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	# Warm all queued core scenery and finish the independently budgeted doorway.
	for i in 600:
		await frame()
		if i > 180 and game.cm.queued.is_empty() and game.cm._pending_chunk == null \
				and (not is_instance_valid(game._realm_visit) or game._realm_visit.phase != RealmExcursion.Phase.PREPARING):
			break
	if game.cm.theme == 9:
		# Floor eight starts inside a tiled lift. Measure actual water/reflection
		# scenery instead of accidentally timing four close-up lift walls.
		var water: MeshInstance3D
		var nearest := INF
		for node in game.cm.find_children("*", "MeshInstance3D", true, false):
			if node.has_meta("pool_water_surface"):
				var distance: float = node.global_position.distance_squared_to(game.player.global_position)
				if distance < nearest:
					nearest = distance
					water = node
		expect(water != null, "Poolrooms profile found no water")
		if water != null:
			var size: Vector2 = water.get_meta("pool_water_size")
			var centre := water.global_position
			var from := centre + Vector3(size.x * 0.35,
				Chunk.POOL_DECK_Y + 0.05 - centre.y, size.y * 0.5 + 0.7)
			game.player.teleport(from)
			var forward := centre - from
			game.player.rotation.y = atan2(-forward.x, -forward.z)
			game.player.cam.rotation = Vector3(-0.15, 0, 0)
			for i in 240:
				await frame()
	game.cm.set_process(false)
	var pc := Vector2i(floori(game.player.global_position.x / ChunkManager.CELL),
		floori(game.player.global_position.z / ChunkManager.CELL))
	var old_cells: Dictionary = game.cm._room_complete_cells(pc, 2)
	var new_cells: Dictionary = game.cm._room_complete_cells(pc)
	for cell in new_cells:
		expect(game.cm.chunks.has(cell), "profile did not finish loading %s" % cell)
	for label in ["legacy-5x5", "extended-7x7"]:
		var visible_count := 0
		for cell in game.cm.chunks:
			game.cm.chunks[cell].visible = label == "extended-7x7" or old_cells.has(cell)
			if game.cm.chunks[cell].visible:
				visible_count += 1
		print("DRAW_DISTANCE %s visible=%d" % [label, visible_count])
		await settle()
		await sweep(label)
		await settle()
		RenderingServer.force_draw(false, 1.0 / 60.0)
		view.get_texture().get_image().save_png(OUT.path_join("floor-%d-%s.png" % [game.cm.theme, label]))
	await teardown_game(game)
	view.free()
	finish("draw distance rendered comparison")
