extends SceneTree
## GPU review of the supplied animated walker in bright, dark and torch-burn
## conditions. Writes PNGs under /tmp.

var viewport: SubViewport
var environment: Environment
var visual: ShadowWalkerVisual
var camera: Camera3D
var room_light: DirectionalLight3D
var flashlight: SpotLight3D


func _initialize() -> void:
	call_deferred(&"_run")


func _box(host: Node, at: Vector3, size: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.92
	node.material_override = material
	node.position = at
	host.add_child(node)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Shadow walker capture requires a GPU renderer")
		quit(2)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.use_taa = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)

	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.045, 0.043)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.83, 0.86, 0.84)
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	scene.add_child(world_environment)

	_box(scene, Vector3(0, -0.08, 0), Vector3(9, 0.16, 9), Color(0.18, 0.19, 0.18))
	for y in 6:
		for x in 10:
			var tone := 0.72 if (x + y) % 2 == 0 else 0.045
			_box(scene, Vector3((x - 4.5) * 0.46, 0.23 + y * 0.46, -1.05),
				Vector3(0.455, 0.455, 0.08), Color(tone, tone, tone))
	_box(scene, Vector3(-1.05, 1.05, 0.42), Vector3(0.30, 2.10, 0.30),
		Color(0.12, 0.105, 0.09))

	room_light = DirectionalLight3D.new()
	room_light.light_energy = 1.05
	room_light.light_color = Color(0.94, 0.89, 0.80)
	room_light.rotation_degrees = Vector3(-47, -28, 0)
	scene.add_child(room_light)

	camera = Camera3D.new()
	camera.position = Vector3(2.65, 1.42, 4.10)
	camera.fov = 56.0
	camera.near = 0.05
	camera.far = 80.0
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.02, 0))
	camera.current = true

	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.88, 0.93, 1.0)
	flashlight.light_energy = 5.0
	flashlight.spot_range = 21.0
	flashlight.spot_angle = 46.0
	flashlight.shadow_enabled = true
	scene.add_child(flashlight)
	flashlight.visible = false

	visual = ShadowWalkerVisual.new()
	scene.add_child(visual)
	visual.appear(0.0)
	visual.set_manifestation(1.0)
	camera.position = Vector3(0, 1.30, 3.55)
	camera.look_at(Vector3(0, 1.02, 0))
	visual.rotation.y = 0.0
	await _shot("/tmp/liminal-shadow-walker-authored-minus-z.png")
	visual.rotation.y = PI
	await _shot("/tmp/liminal-shadow-walker-authored-plus-z.png")
	camera.position = Vector3(2.65, 1.42, 4.10)
	camera.look_at(Vector3(0, 1.02, 0))
	visual.face_world_position(camera.global_position, 1.0)
	await _shot("/tmp/liminal-shadow-walker-bright.png")
	visual.set_manifestation(0.3)
	await _shot("/tmp/liminal-shadow-walker-arrival-early.png")
	visual.set_manifestation(0.65)
	await _shot("/tmp/liminal-shadow-walker-arrival-late.png")
	visual.set_manifestation(1.0)

	camera.position = Vector3(-2.35, 1.33, 3.65)
	camera.look_at(Vector3(0, 1.02, 0))
	visual.face_world_position(camera.global_position, 1.0)
	await _shot("/tmp/liminal-shadow-walker-side.png")

	environment.background_color = Color(0.001, 0.0012, 0.0015)
	environment.ambient_light_color = Color(0.045, 0.052, 0.058)
	environment.ambient_light_energy = 0.08
	room_light.light_energy = 0.0
	flashlight.global_transform = camera.global_transform
	flashlight.look_at(Vector3(0, 1.02, 0))
	flashlight.visible = true
	visual.set_instance_shader_parameter(&"torch", 0.85)
	await _shot("/tmp/liminal-shadow-walker-flashlight.png")

	visual.set_instance_shader_parameter(&"ignite", 1.0)
	visual.set_instance_shader_parameter(&"fade", 0.52)
	await _shot("/tmp/liminal-shadow-walker-burn.png")

	print("CAPTURE shadow_walker /tmp/liminal-shadow-walker-{bright,side,flashlight,burn}.png")
	viewport.free()
	quit(0)


func _shot(path: String) -> void:
	for i in 34:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	viewport.get_texture().get_image().save_png(path)
