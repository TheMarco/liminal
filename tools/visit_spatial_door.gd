extends SceneTree
## Manual visual check: boot the Office, pose the migrating door, teleport
## the player in front of it, and hand over control. Close the window to quit.
## godot --path . --audio-driver Dummy --script tools/visit_spatial_door.gd \
##   -- --mode=descent --nologo --seed=1 --descent-floor=3 \
##   --visit-phase=both --visit-door=a

func _init() -> void:
	call_deferred("run")

func draw(frames := 4) -> void:
	for i in frames:
		await process_frame

func _arg(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback

func run() -> void:
	Engine.max_fps = 60
	var phase := _arg("--visit-phase=", "both")
	var door := _arg("--visit-door=", "a")
	if door != "b":
		door = "a"
	var targets := {"a": [1.0, 0.0], "both": [1.0, 1.0], "b": [0.0, 1.0]}
	if not targets.has(phase):
		phase = "both"
	var seed := CliOptions.parse().world_seed
	if seed <= 0:
		seed = 1
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.world_seed = seed
	root.add_child(game)
	await draw(10)
	# Freeze main-loop polling so no director event re-poses the door
	# while you look. Player, streaming, and rendering stay live.
	game.set_process(false)
	var director: Node = game.get("_spatial_director")
	if director != null:
		director.set_physics_process(false)
	game._set_presence(game.Presence.SILENT)
	await draw(80)
	var topology: DescentTopology = game.descent_route.topology
	if topology.site_specs.is_empty():
		print("VISIT FAIL: no site for seed ", seed)
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
		print("VISIT FAIL: site node missing")
		quit(1)
		return
	var cm: ChunkManager = game.cm
	var dirs: Array = frame["dirs"]
	for cell in [junction, junction + WorldGen.DIRV[int(dirs[0])],
		junction + WorldGen.DIRV[int(dirs[1])]]:
		for member in WorldGen.owning_room_members(cm.world_seed, cell,
			cm.theme):
			if cm.chunk_at(member) == null:
				cm._build(member)
	for i in 90:
		await draw()
		if cm.chunk_at(junction) != null:
			break
	var want: Array = targets[phase]
	site.set_targets(want[0], want[1])
	for i in 240:
		var res: MigratingDoorSite.PhaseResult = site.advance_physics(
			1.0 / 60.0, [])
		await process_frame
		if res.targets_reached:
			break
	var end: Transform3D = spec.endpoints[door]
	var feet := end.origin + end.basis.z * 3.5 + Vector3(0, 0.05, 0)
	var aim := end.origin + Vector3(0, 1.4, 0)
	game.player.teleport(feet)
	var d := aim - feet
	game.player.rotation.y = atan2(-d.x, -d.z)
	game.player.set("_pitch", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await draw(4)
	print("VISIT: phase=", phase, " door=", door,
		" openness=", site.current_clearance().openness)
	print("VISIT: in your hands. WASD + mouse. Close the window to quit.")
	# No quit(): this script hands control to the human.
