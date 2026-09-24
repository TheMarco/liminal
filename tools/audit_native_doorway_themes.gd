extends "res://tools/lib/audit_base.gd"
## One originally solid, seed-prepared wall per playable theme. Proves stable
## wall/open endpoints and route collision. --capture also records the look.

const Director := preload("res://scripts/native_doorway_director.gd")


func run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			fail("--capture needs a rendered Godot window")
			finish()
			return
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute("/tmp/liminal-native-doorway-themes")
	var theme_filter := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): theme_filter = int(arg.substr(8))
	for theme: int in DescentRun.FIXED_ORDER:
		if theme_filter >= 0 and theme != theme_filter: continue
		await _check_theme(theme)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("latent doorway: prepared sites and reversible collision" \
		+ (" in all 11 themes" if theme_filter < 0 else " in theme %d" % theme_filter))


func _check_theme(theme: int) -> void:
	var ws := WorldGen.level_seed(20260807, theme)
	var descent_check := "--descent" in OS.get_cmdline_user_args()
	var topology: DescentTopology
	var route: DescentRoute
	if descent_check:
		route = DescentRoute.build(ws, theme,
			DescentRun.FIXED_ORDER.find(theme) + 1)
		topology = DescentTopology.new(ws, theme)
		route.set_topology(topology)
		topology.plan_floor(route)
	var world := Node3D.new()
	root.add_child(world)
	if "--capture" in OS.get_cmdline_user_args():
		var atmosphere := WorldEnvironment.new()
		atmosphere.environment = EnvBuilder.build(theme)
		world.add_child(atmosphere)
	var manager := ChunkManager.new()
	manager.world_seed = ws
	manager.theme = theme
	manager.descent = descent_check
	manager.descent_route = route
	manager.descent_topology = topology
	manager.native_doorway_plan = NativeDoorwayPlan.new()
	manager.native_doorway_plan.configure(ws, theme, topology)
	var arrival: Vector3 = LevelTransitionController.safe_arrival_for_seed(theme,
		Vector2i.ZERO, Vector3(6.0, 0.15, 2.0), ws)
	var arrival_cell := Vector2i(floori(arrival.x / 12.0),
		floori(arrival.z / 12.0))
	var nearby_sites := 0
	var wider_sites := 0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for axis in [0, 2]:
				if not manager.native_doorway_plan.candidate(
					arrival_cell + Vector2i(dx, dz), axis).is_empty():
					wider_sites += 1
					if absi(dx) <= 2 and absi(dz) <= 2: nearby_sites += 1
	print("Theme ", theme, " arrival cell ", arrival_cell,
		" prepared edges within 2 / 3 cells: ", nearby_sites,
		" / ", wider_sites)
	world.add_child(manager)
	manager.set_process(false)
	var actor := Player.new()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	manager.player = actor
	var director := Director.new()
	world.add_child(director)
	director.configure(manager, actor, null, func() -> bool: return true)
	director.set_physics_process(false)
	director.set_process(false)
	var selected := false
	var cell := Vector2i.ZERO
	var dir := 2
	var pool_arch := theme == 9 and "--pool-arch" in OS.get_cmdline_user_args()
	var bound := 16
	for x in range(-bound, bound + 1):
		if selected: break
		for z in range(-bound, bound + 1):
			if selected: break
			for axis in [0, 2]:
				cell = Vector2i(x, z)
				dir = axis
				if manager.native_doorway_plan.candidate(cell, dir).is_empty(): continue
				if pool_arch and WorldGen.pool_doorway_kind(ws, cell, dir) \
						!= WorldGen.POOL_OPENING_ARCH: continue
				var other: Vector2i = cell + WorldGen.DIRV[dir]
				var near := Chunk.new(ws, cell, theme,
					{"native_doorway_plan": manager.native_doorway_plan,
					"descent": descent_check, "topology": topology})
				var far := Chunk.new(ws, other, theme,
					{"native_doorway_plan": manager.native_doorway_plan,
					"descent": descent_check, "topology": topology})
				var site := near.native_doorway_site(dir)
				var opposite := far.native_doorway_site(WorldGen.OPP[dir])
				if site.is_empty() or (opposite.is_empty() and not bool(site["single_owner"])):
					near.free()
					far.free()
					continue
				near.position = Vector3(cell.x * 12.0, 0.0, cell.y * 12.0)
				far.position = Vector3(other.x * 12.0, 0.0, other.y * 12.0)
				manager.add_child(near)
				manager.add_child(far)
				manager.chunks[cell] = near
				manager.chunks[other] = far
				var centre: Vector3 = director._site_centre(cell, dir,
					float(site["t"]), float(site["floor"]))
				actor.global_position = centre \
					- Vector3(float(WorldGen.DIRV[dir].x), 0.0,
					float(WorldGen.DIRV[dir].y)) * 6.0
				actor.cam.global_position = actor.global_position + Vector3.UP * Player.CAM_H
				actor.cam.look_at(centre + Vector3.UP * 1.2)
				actor.cam.make_current()
				if "--capture" in OS.get_cmdline_user_args():
					actor.flashlight.visible = true
				await physics_frame
				if director._eligible(cell, dir):
					selected = true
					break
				manager.chunks.clear()
				near.free()
				far.free()
	await physics_frame
	expect(selected, "theme %d has no eligible generated doorway" % theme)
	if selected:
		var site: Dictionary = manager.chunks[cell].native_doorway_site(dir)
		var centre: Vector3 = director._site_centre(cell, dir,
			float(site["t"]), float(site["floor"]))
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(theme, "closed")
		expect(_threshold_hit(world, centre, dir),
			"theme %d hidden wall did not block" % theme)
		expect(director.start_event(cell, dir),
			"theme %d could not start a doorway" % theme)
		if is_instance_valid(director.active):
			var surface: Node3D = director.active
			director._process(Director.MOVE_SECONDS * 0.55)
			if "--capture" in OS.get_cmdline_user_args():
				await _capture(theme, "mid")
			director._process(Director.MOVE_SECONDS * 0.55)
			director._physics_process(0.0)
			await physics_frame
			await physics_frame
			expect(surface.phase == 1.0 and not _threshold_hit(world, centre, dir),
				"theme %d appeared doorway remained blocked" % theme)
			if "--capture" in OS.get_cmdline_user_args():
				await _capture(theme, "open")
			director._process(Director.OPEN_SECONDS + 0.1)
			director._process(Director.MOVE_SECONDS * 0.95)
			if "--capture" in OS.get_cmdline_user_args():
				await _capture(theme, "late")
			director._process(Director.MOVE_SECONDS * 0.05 + 0.001)
			director._physics_process(0.0)
			await physics_frame
			await physics_frame
			expect(director.active == null and _threshold_hit(world, centre, dir),
				"theme %d did not restore native solid collision" % theme)
			expect(site["closed_nodes"][0].visible and not site["nodes"][0].visible,
				"theme %d did not restore native full wall" % theme)
			print("Theme ", theme, " site ", cell, " width ", site["w"],
				" head ", site["head"], " floor ", site["floor"])
	world.process_mode = Node.PROCESS_MODE_DISABLED
	stop_audio(world)
	world.queue_free()
	await process_frame


func _capture(theme: int, state: String, frames := 4) -> void:
	for frame in frames: await process_frame
	root.get_texture().get_image().save_png(
		"/tmp/liminal-native-doorway-themes/theme-%02d-%s.png" % [theme, state])


func _threshold_hit(world: Node3D, centre: Vector3, dir: int) -> bool:
	var offset := Vector3.RIGHT * 0.5 if dir == 0 else Vector3.BACK * 0.5
	var ray := PhysicsRayQueryParameters3D.create(
		centre + Vector3.UP * 1.2 - offset,
		centre + Vector3.UP * 1.2 + offset)
	return not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
