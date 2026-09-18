extends SceneTree
## GPU lineup for every production monster visual.

func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Shadow-walker roster capture requires a GPU renderer")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.use_taa = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.020, 0.022)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.69, 0.68)
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	scene.add_child(world_environment)

	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(18.0, 8.0)
	floor_mesh.mesh = floor
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.075, 0.078, 0.077)
	floor_material.roughness = 0.94
	floor_mesh.material_override = floor_material
	scene.add_child(floor_mesh)

	var key := DirectionalLight3D.new()
	key.light_color = Color(0.90, 0.93, 0.90)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	scene.add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.25, 11.5)
	camera.fov = 51.0
	camera.near = 0.05
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.current = true

	var roster_count := ShadowWalkerVisual.model_count()
	for index in roster_count:
		var visual := ShadowWalkerVisual.new()
		visual.model_index = index
		visual.position = Vector3(
			(float(index) - float(roster_count - 1) * 0.5) * 1.8, 0.0, 0.0)
		scene.add_child(visual)
		visual.appear(0.0)
		visual.set_manifestation(1.0)
		visual.set_instance_shader_parameter(&"torch", 0.72)

	for frame in 45:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	viewport.get_texture().get_image().save_png(
		"/tmp/liminal-shadow-walker-roster.png")
	print("CAPTURE shadow-walker roster /tmp/liminal-shadow-walker-roster.png")
	viewport.free()
	quit(0)
