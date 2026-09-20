extends SceneTree
## Manual seam walk for the Package 3 exit gate: lit fixture corridors, a
## live pursuer behind you, and traversal stepping every physics tick.
## Walk the seam both ways, look back, watch the pursuer cross after you.
## godot --path . --audio-driver Dummy --script tools/visit_hidden_link.gd
var fixture: TraversalLinkFixture
var graph: TraversalGraph
var trav: SpatialTraversal
var player: Player
var figure: ShadowFigure


func _init() -> void:
	call_deferred("run")


func run() -> void:
	Engine.max_fps = 60
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	for x in [0.0, 200.0]:
		for z in [-3.0, 3.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.2, z)
			lamp.light_energy = 1.6
			lamp.omni_range = 9.0
			lamp.shadow_enabled = false
			root.add_child(lamp)
	fixture = TraversalLinkFixture.new()
	fixture.debug_marks = false
	root.add_child(fixture)
	fixture.build()
	for i in 8:
		await process_frame
	fixture.admit_all()
	for site in [fixture.site_straight, fixture.site_turn,
			fixture.site_mismatch]:
		print("VISIT admit %s: %s" % [site.link.id,
			"ok" if site.admitted() else site.admit_reason()])
	graph = fixture.graph_for(fixture.site_straight)
	trav = SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	trav.set_listener(func(record: Dictionary) -> void:
		var who := "player" \
			if record["body"] == player else "figure"
		print("VISIT transfer %s %s from=%s to=%s" % [who,
			record["direction"], record["result"],
			record["mapped"]]))
	player = Player.new()
	player.position = Vector3(0, 0.05, 4.5)
	root.add_child(player)
	trav.bind_actor(player)
	figure = ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	root.add_child(figure)
	trav.bind_actor(figure)
	# Keep the campaign encounter budget; the shared site is one logical
	# region even when its paired coordinates cross several seeded rooms.
	figure.global_position = Vector3(0, 0.05, 5.5)
	for i in 70:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("VISIT: in your hands. WASD + mouse. Walk to the far end and")
	print("VISIT: through the seam (z=0); look back for the pursuer.")
	print("VISIT: Close the window to quit.")
	var ticks := 0
	var last_refusal := ""
	var figure_gone := 0
	while is_instance_valid(player):
		await physics_frame
		if not is_instance_valid(player):
			break
		# One catch ends the pursuit half, so restock the stalker: same
		# side as the player, far end away, known-free spawn cells.
		if not is_instance_valid(figure):
			figure_gone += 1
			if figure_gone > 180:
				figure_gone = 0
				figure = ShadowFigure.new()
				figure.player = player
				figure.traversal_graph = graph
				root.add_child(figure)
				trav.bind_actor(figure)
				var sx := 200.0 \
					if player.global_position.x > 100.0 else 0.0
				var sz := -5.5 \
					if player.global_position.z > 0.0 else 5.5
				figure.global_position = Vector3(sx, 0.05, sz)
				print("VISIT pursuer respawned at %s"
					% figure.global_position)
		else:
			figure_gone = 0
		if str(trav.last_refusal()) != last_refusal:
			last_refusal = str(trav.last_refusal())
			print("VISIT refusal: %s" % last_refusal)
		ticks += 1
		if ticks % 120 == 0 and is_instance_valid(player):
			print("VISIT at=%s side=%s fig=%s" % [
				player.global_position,
				"B" if player.global_position.x > 100.0 else "A",
				figure.global_position
				if is_instance_valid(figure) else "<gone>"])
	# No quit(): this script hands control to the human.
