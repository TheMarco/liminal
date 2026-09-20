extends SceneTree
## Frame-by-frame seam validation for the Package 3 exit gate: approach,
## straddle, crossing, look-back, reverse side, figure crossing, astride
## turn, two-enemy meeting, torch on/off. Headed run (needs a renderer).
## godot --path . --audio-driver Dummy \
##   --script tools/capture_hidden_link.gd
var out := "/tmp/liminal-hidden-link-hardened"
var view: SubViewport
var fixture: TraversalLinkFixture
var graph: TraversalGraph
var trav: SpatialTraversal
var player: Player
var figure: ShadowFigure


func _init() -> void:
	call_deferred("run")


func draw(frames := 4) -> void:
	for i in frames:
		await process_frame


func shot(label: String) -> void:
	await draw()
	# Explicitly draw the offscreen viewport: a minimized desktop window
	# may stop emitting frame_post_draw while process frames keep ticking.
	RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("CAPTURED ", out.path_join(label + ".png"), " camera=", player.cam.global_transform)


func run() -> void:
	Engine.max_fps = 60
	print("CAPTURE start")
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(640, 400)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	world.name = "CaptureWorld"
	view.add_child(world)
	_light(world)
	fixture = TraversalLinkFixture.new()
	fixture.debug_marks = false
	world.add_child(fixture)
	fixture.build()
	await draw(8)
	fixture.admit_all()
	graph = fixture.graph_for(fixture.site_straight)
	trav = SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	player = Player.new()
	player.position = Vector3(0, 0.05, 4.5)
	world.add_child(player)
	trav.bind_actor(player)
	await draw(8)
	player.rotation.y = PI
	figure = ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	world.add_child(figure)
	trav.bind_actor(figure)
	figure.global_position = Vector3(0, 0.05, 5.5)
	await draw(20)
	await _face(0.0)
	await shot("seam_ahead")
	await _face(PI)
	await shot("lookback_pursuer")
	await _cross_player()
	figure.global_position = Vector3(0, 0.05, 1.5)
	await _face(0.0)
	await shot("crossed_lookback")
	await _cross_figure()
	await _astride_turn()
	await _two_enemy()
	player.flashlight.visible = true
	await _face(0.0)
	await shot("torch_on_lookback")
	player.flashlight.visible = false
	player.cam.fov = 90.0
	await _face(0.0)
	await shot("fov_wide_lookback")
	player.cam.fov = 75.0
	await _room_views()
	print("CAPTURE done")
	quit()


func _room_views() -> void:
	for side in [0, 1]:
		var offset := Vector3(200.0 * side, 0, 0)
		for n in 3:
			player.teleport(offset + [Vector3(-9, 0.05, 8),
				Vector3(-4, 0.05, 8), Vector3(0, 0.05, 7)][n])
			await _face(-PI * 0.5 if n < 2 else 0.0)
			await shot("room_%d_bend_%d" % [side, n])


## Face a yaw (0 looks down -Z toward the seam from +Z).
func _face(yaw: float) -> void:
	player.rotation.y = yaw
	player.set("_pitch", 0.0)
	player._process(0.0)
	await draw(2)


## Walk the player through the seam frame by frame, transferring live.
## Steps follow the body's own facing so the walk survives the crossing
## yaw flip: absolute A-side positions would teleport back out of B after
## every transfer and the series would never actually cross.
func _cross_player() -> void:
	player.rotation.y = 0.0
	player.global_position = Vector3(0, 0.05, 0.5)
	await draw(2)
	var n := 0
	for i in 11:
		var pre := player.global_position
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		player.global_position = pre + fwd.normalized() * 0.1
		trav.step(1.0 / 60.0, [{"body": player, "from": pre,
			"allow": true}])
		await draw(2)
		await shot("cross_%02d" % n)
		n += 1


## Walk the pursuer through the seam with full AI, shooting the span.
## A fresh figure: the opening one may have spent its door budget or
## started a give-up fade while chasing through the player crossing,
## which once dissolved it mid-span and broke this loop and the meeting.
func _cross_figure() -> void:
	if is_instance_valid(figure):
		figure.queue_free()
	figure = ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	figure.grace = 0.0
	view.get_child(0).add_child(figure)
	trav.bind_actor(figure)
	figure.get("_walker").set_manifestation(1.0)
	figure.global_position = Vector3(0, 0.05, 1.2)
	player.global_position = Vector3(200, 0.05, 5.5)
	player.rotation.y = 0.0
	await draw(2)
	var n := 0
	for tick in 72:
		if not is_instance_valid(figure):
			break
		await physics_frame
		if not is_instance_valid(figure):
			break
		if tick % 9 == 0:
			await draw(2)
			await shot("figure_cross_%02d" % n)
			n += 1


## Stand astride the plane and turn 180 degrees in quarters.
func _astride_turn() -> void:
	player.global_position = Vector3(200, 0.05, 0.1)
	player.rotation.y = 0.0
	await draw(2)
	for n in 5:
		player.rotation.y = PI * float(n) / 4.0
		await draw(2)
		await shot("astride_%02d" % n)


## Two enemies posed converging on the seam from opposite sides. AI
## holds still (proxies stay live): placement, not pursuit, is the shot.
## Same local x on both sides: the half-turn mirrors the twin across the
## sightline, so the pair reads separated instead of self-occluding.
func _two_enemy() -> void:
	if not is_instance_valid(figure):
		figure = ShadowFigure.new()
		figure.player = player
		figure.traversal_graph = graph
		figure.set("_seen", true)
		view.get_child(0).add_child(figure)
		figure.get("_walker").set_manifestation(1.0)
	var other := ShadowFigure.new()
	other.player = player
	other.traversal_graph = graph
	other.set("_seen", true)
	other.walker_model_index = 4
	view.get_child(0).add_child(other)
	other.get("_walker").set_manifestation(1.0)
	figure.set_physics_process(false)
	other.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 4.5)
	player.rotation.y = 0.0
	for n in 4:
		var z := 1.5 - 0.4 * float(n)
		figure.global_position = Vector3(-0.55, 0.05, z)
		other.global_position = Vector3(200.0 - 0.55, 0.05, z)
		figure.get("_walker").rotation.y = PI
		other.get("_walker").rotation.y = PI
		await draw(3)
		print("MEETING %d cam=%s a=%s b=%s pa=%s pb=%s" % [n,
			player.cam.global_transform.origin,
			figure.global_position if is_instance_valid(figure)
				else "<gone>",
			other.global_position if is_instance_valid(other)
				else "<gone>",
			(figure.get("_seam_proxy") as Node3D).global_position
				if is_instance_valid(figure)
				and is_instance_valid(figure.get("_seam_proxy"))
				else "<none>",
			(other.get("_seam_proxy") as Node3D).global_position
				if is_instance_valid(other)
				and is_instance_valid(other.get("_seam_proxy"))
				else "<none>"])
		await shot("meeting_%02d" % n)
	other.queue_free()
	figure.set_physics_process(true)


func _light(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	for x in [0.0, 200.0]:
		for z in [-3.0, 3.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.2, z)
			lamp.light_energy = 1.6
			lamp.omni_range = 9.0
			lamp.shadow_enabled = false
			world.add_child(lamp)
