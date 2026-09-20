extends SceneTree
## GPU framing check for the real floor-level CaughtSequence and animated walker.

const CAUGHT_SEQUENCE := preload("res://scripts/caught_sequence.gd")


func _initialize() -> void:
	call_deferred(&"_run")


func _box(host: Node, at: Vector3, size: Vector3, colour: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh_node.material_override = material
	mesh_node.position = at
	host.add_child(mesh_node)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Shadow walker caught capture requires a GPU renderer")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.use_taa = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.013, 0.014)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.64, 0.63)
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	scene.add_child(world_environment)
	_box(scene, Vector3(0, -0.08, 0), Vector3(8, 0.16, 8), Color(0.12, 0.11, 0.10))
	_box(scene, Vector3(0, 1.5, -1.6), Vector3(8, 3, 0.15), Color(0.18, 0.17, 0.15))
	var light := OmniLight3D.new()
	light.position = Vector3(1.7, 2.3, 1.4)
	light.light_energy = 3.0
	light.omni_range = 7.0
	light.light_color = Color(0.86, 0.89, 0.82)
	scene.add_child(light)

	var player := Player.new()
	player.position = Vector3(0, 0, 2.3)
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.cam.global_position = player.global_position + Vector3(0, Player.CAM_H, 0)
	player.cam.look_at(Vector3(0, 1.25, 0))
	player.cam.current = true

	var figure := ShadowFigure.new()
	figure.player = player
	figure.position = Vector3.ZERO
	scene.add_child(figure)
	figure.set_physics_process(false)
	figure._walker.appear(0.0)
	figure._walker.face_world_position(player.cam.global_position, 1.0)

	var caught := CAUGHT_SEQUENCE.new()
	viewport.add_child(caught)
	caught.begin(player, figure)
	caught.set_process(false)
	caught._sample(1.58)
	for i in 34:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	viewport.get_texture().get_image().save_png("/tmp/liminal-shadow-walker-caught.png")
	print("CAPTURE shadow_walker caught /tmp/liminal-shadow-walker-caught.png")
	caught.restore()
	viewport.free()
	quit(0)
