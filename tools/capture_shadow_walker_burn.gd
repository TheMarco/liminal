extends SceneTree
## GPU timing review for the intact-flash -> solid fragments -> diffuse tail.


func _initialize() -> void:
	call_deferred(&"_run")


func _box(host: Node, at: Vector3, size: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	node.material_override = material
	node.position = at
	host.add_child(node)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Shadow walker burn capture requires a GPU renderer")
		quit(2)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 900)
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
	environment.background_color = Color(0.009, 0.009, 0.010)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.23, 0.24)
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.16
	environment.glow_enabled = true
	environment.glow_intensity = 0.26
	environment.glow_bloom = 0.018
	world_environment.environment = environment
	scene.add_child(world_environment)
	_box(scene, Vector3(0, -0.08, 0), Vector3(7, 0.16, 7), Color(0.10, 0.095, 0.09))
	_box(scene, Vector3(0, 1.45, -1.3), Vector3(7, 2.9, 0.14), Color(0.14, 0.135, 0.13))
	# In-frame luminance reference: the production Annex troffer material under
	# the production Annex exposure/glow values. The fragment core should resolve
	# at least as hot as this visible fixture face.
	var annex_reference := MeshInstance3D.new()
	var annex_mesh := BoxMesh.new()
	annex_mesh.size = Vector3(0.72, 0.035, 0.72)
	annex_reference.mesh = annex_mesh
	annex_reference.material_override = Mats.annex_panel()
	annex_reference.position = Vector3(-1.05, 2.15, -0.25)
	scene.add_child(annex_reference)

	var player := Player.new()
	player.position = Vector3(2.25, 0, 3.25)
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.flashlight.visible = false
	player.cam.global_position = player.global_position + Vector3(0, Player.CAM_H, 0)
	player.cam.look_at(Vector3(0, 1.05, 0))
	player.cam.current = true

	var figure := ShadowFigure.new()
	figure.player = player
	figure.walker_model_index = 2
	figure.position = Vector3.ZERO
	figure.suppressed = true
	scene.add_child(figure)
	figure.set_physics_process(false)
	figure._walker.appear(0.0)
	figure._walker.set_manifestation(1.0)
	figure._walker.face_world_position(player.cam.global_position, 1.0)
	for frame in 3:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	viewport.get_texture().get_image().save_png(
		"/tmp/liminal-walker-burn-black.png")
	figure._ignite(false, false)

	var frames := {5: "flash", 11: "handoff", 22: "breakup", 38: "diffuse", 62: "dissolve"}
	for frame in 63:
		if is_instance_valid(figure):
			figure._physics_process(1.0 / 60.0)
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
		if frames.has(frame):
			viewport.get_texture().get_image().save_png(
				"/tmp/liminal-walker-burn-%s.png" % frames[frame])
	print("CAPTURE walker burn /tmp/liminal-walker-burn-{flash,handoff,breakup,diffuse,dissolve}.png")
	viewport.free()
	quit(0)
