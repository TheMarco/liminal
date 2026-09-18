extends "res://tools/lib/audit_base.gd"
## GPU test: stronger dark silhouettes, unchanged bright-room treatment and
## ordinary opaque-wall occlusion. Also writes clean/VHS review images to /tmp.

var viewport: SubViewport
var figure: ShadowFigure
var wall_material: StandardMaterial3D
var blocker: MeshInstance3D
var post: CanvasLayer

func _box(host: Node, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	host.add_child(mesh)
	return mesh

func _shot(readability: float, path := "") -> Image:
	var material: ShaderMaterial = figure._quad._layers[0].material_override
	material.set_shader_parameter("dark_readability", readability)
	figure._quad.set_instance_shader_parameter("flip_frame", 5.0)
	figure._quad._process(0.0)
	for i in 12:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	var image := viewport.get_texture().get_image()
	if path != "": image.save_png(path)
	return image

func _changed(before: Image, after: Image) -> int:
	var count := 0
	for y in range(20, 450):
		for x in range(180, 460):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.008:
				count += 1
	return count

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Ghost readability pixel audit requires a GPU renderer")
		finish()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	# Compare shader output, not TAA history settling after a lighting switch.
	viewport.use_taa = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.003, 0.003)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	scene.add_child(environment)
	wall_material = StandardMaterial3D.new()
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_material.albedo_color = Color(0.018, 0.021, 0.024)
	_box(scene, Vector3(0, 1.5, -1.5), Vector3(12, 8, 0.2), wall_material)
	blocker = _box(scene, Vector3(0, 1.5, 1.2), Vector3(5, 5, 0.2), wall_material)
	blocker.visible = false
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.6, 4.0)
	camera.fov = 58
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1.15, 0))
	camera.current = true
	post = CanvasLayer.new()
	viewport.add_child(post)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.material = PostProcessController.make_live_found_footage_material()
	post.add_child(overlay)
	post.visible = false
	for variant in ShadowFigure.LOOKS:
		figure = ShadowFigure.new()
		figure.variant = variant
		scene.add_child(figure)
		figure.set_physics_process(false)
		figure._quad.set_process(false)
		figure._quad.set_instance_shader_parameter("fade", 1.0)
		figure._gloom.visible = false
		# The independent GPU particle wisps keep moving even with actor physics
		# disabled; exclude them from an exact before/after cloth comparison.
		figure._wisps.visible = false
		wall_material.albedo_color = Color(0.018, 0.021, 0.024)
		var before := await _shot(0.0, "/tmp/liminal-ghost-before-%d.png" % variant)
		var after := await _shot(1.0, "/tmp/liminal-ghost-dark-%d.png" % variant)
		var dark_changed := _changed(before, after)
		expect(dark_changed > 150, "variant %d lacks a meaningful dark-body lift (%d pixels)" % [variant, dark_changed])
		wall_material.albedo_color = Color(0.70, 0.70, 0.70)
		before = await _shot(0.0, "/tmp/liminal-ghost-bright-before-%d.png" % variant)
		after = await _shot(1.0, "/tmp/liminal-ghost-bright-after-%d.png" % variant)
		var bright_changed := _changed(before, after)
		expect(bright_changed == 0, "variant %d changed its bright-room silhouette" % variant)
		wall_material.albedo_color = Color(0.018, 0.021, 0.024)
		blocker.visible = true
		before = await _shot(0.0)
		after = await _shot(1.0)
		expect(_changed(before, after) == 0, "variant %d became visible through an opaque wall" % variant)
		blocker.visible = false
		post.visible = true
		await _shot(1.0, "/tmp/liminal-ghost-vhs-%d.png" % variant)
		post.visible = false
		print("GHOST_READABILITY variant=%d dark_pixels=%d bright_pixels=%d" % [variant, dark_changed, bright_changed])
		figure.free()
	viewport.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("all seven dark ghost silhouettes, unchanged bright rooms and wall occlusion")
