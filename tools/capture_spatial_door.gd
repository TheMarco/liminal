extends SceneTree
## Capture the migrating-door A/B contrast on the Office floor: aperture A
## open, both open, then aperture B open. Headed run (needs a renderer).
## godot --path . --audio-driver Dummy --script tools/capture_spatial_door.gd \
##   -- --mode=descent --nologo --seed=1 --descent-floor=3
var out := "/tmp/liminal-spatial-door"
var game: Node3D
var view: SubViewport

func _init() -> void:
	call_deferred("run")

func draw(frames := 4) -> void:
	for i in frames:
		await process_frame

func _unpause() -> void:
	# Clicking away from the capture window focus-pauses the game and the
	# settings menu photobombs the shot. Force it closed before settling
	# leaves and before every shot.
	var menu: Node = game.get("_pause_menu")
	if is_instance_valid(menu):
		menu.queue_free()
		game.set("_pause_menu", null)
	paused = false
	await draw(2)


func shot(label: String) -> void:
	await _unpause()
	await draw()
	view.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURED ", out.path_join(label + ".png"))

func run() -> void:
	Engine.max_fps = 60
	var seed := CliOptions.parse().world_seed
	if seed <= 0:
		seed = 1
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = seed
	view.add_child(game)
	await draw(60)
	game._set_presence(game.Presence.SILENT)
	game.run.set_process(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._post_process.set_enabled(false)
	game._osd_layer.visible = false
	if game.get("_descent_hud") != null:
		game._descent_hud.set_active(false)
	var director: Node = game.get("_spatial_director")
	if director != null:
		director.set_physics_process(false)
	var topology: DescentTopology = game.descent_route.topology
	print("CAPTURE specs=", topology.site_specs.size())
	if topology.site_specs.is_empty():
		print("CAPTURE FAIL: no site on Office floor for seed ", seed)
		quit(1)
		return
	var spec: SpatialSiteSpec = topology.site_specs[0]
	var frame: Dictionary = SpatialSitePlanner.junction_frame(spec)
	var junction: Vector2i = frame["cell"]
	var site: MigratingDoorSite = null
	for child in game.level_root.get_children():
		if child is MigratingDoorSite:
			site = child
			break
	if site == null or not site.is_prepared():
		print("CAPTURE FAIL: site node missing or unprepared")
		quit(1)
		return
	var floor_h := Chunk.cell_floor_h(seed, junction, 1)
	var origin := Vector3(junction.x * 12.0, floor_h, junction.y * 12.0)
	var dirs: Array = frame["dirs"]
	var anchor := SpatialSitePlanner.anchor_spot(origin, int(dirs[0]),
		int(dirs[1]), floor_h)
	var end_a: Transform3D = spec.endpoints["a"]
	var end_b: Transform3D = spec.endpoints["b"]
	var mid := (end_a.origin + end_b.origin) * 0.5 + Vector3(0, 1.4, 0)
	var center := origin + Vector3(6.0, 0.0, 6.0)
	var to_center := center - anchor
	to_center.y = 0.0
	# Poses are player FEET: the eye sits 1.377 above the player origin,
	# and the office ceiling is at 3.0, so eye-height values here would
	# park the camera inside the ceiling.
	var corner_cam := anchor + to_center.normalized() * 1.5 \
		+ Vector3(0, 0.05, 0)
	var close_a := end_a.origin + end_a.basis.z * 3.5 + Vector3(0, 0.05, 0)
	var close_b := end_b.origin + end_b.basis.z * 3.5 + Vector3(0, 0.05, 0)
	var aim_a := end_a.origin + Vector3(0, 1.4, 0)
	var aim_b := end_b.origin + Vector3(0, 1.4, 0)
	print("CAPTURE anchor=", anchor, " mid=", mid)
	print("CAPTURE end_a=", end_a.origin, " end_b=", end_b.origin)
	# Force-build the junction rooms before any teleport: shooting into
	# unbuilt chunks renders the void.
	var cm: ChunkManager = game.cm
	var near := [junction, junction + WorldGen.DIRV[int(dirs[0])],
		junction + WorldGen.DIRV[int(dirs[1])]]
	for cell in near:
		for member in WorldGen.owning_room_members(cm.world_seed, cell,
			cm.theme):
			if cm.chunk_at(member) == null:
				cm._build(member)
	for i in 90:
		await draw()
		if cm.chunk_at(junction) != null:
			break
	print("CAPTURE junction_built=", cm.chunk_at(junction) != null)
	site.set_targets(1.0, 0.0)
	await _settle(site)
	await _pose(corner_cam, mid)
	await shot("corner_a")
	await _pose(close_a, aim_a)
	await shot("door_a_open")
	site.set_targets(0.0, 1.0)
	await _settle(site)
	await _pose(close_a, aim_a)
	await shot("door_a_closed")
	await _pose(close_b, aim_b)
	await shot("door_b_open")
	await _pose(corner_cam, mid)
	await shot("corner_b")
	print("CAPTURE done openness=", site.current_clearance().openness)
	quit()


func _pose(cam_pos: Vector3, target: Vector3) -> void:
	game.player.global_position = cam_pos
	await draw(2)
	game.player.cam.look_at(target)
	await draw(2)
	print("CAPTURE pose cam=", cam_pos, " target=", target)

func _settle(site: MigratingDoorSite) -> void:
	await _unpause()
	for i in 240:
		var res: MigratingDoorSite.PhaseResult = site.advance_physics(1.0 / 60.0, [])
		await process_frame
		if res.targets_reached:
			return
