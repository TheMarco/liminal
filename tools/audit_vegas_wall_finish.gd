extends "res://tools/lib/audit_base.gd"
## GPU audit for Vegas wallpaper normals and the shader's timber transition.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
##   --script tools/audit_vegas_wall_finish.gd

var view: SubViewport
var board: MeshInstance3D

func _warmup() -> void:
	for _i in 8:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func _render(material: Material) -> Image:
	board.material_override = material
	await _warmup()
	return view.get_texture().get_image()

func _max_error(a: Image, b: Image, rect: Rect2i) -> int:
	if a == null or b == null or a.is_empty() or b.is_empty():
		fail("Missing GPU normal readback")
		return 999
	var maximum := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			for channel in 3:
				maximum = maxi(maximum, absi(int(ca[channel] * 255.0) - int(cb[channel] * 255.0)))
	return maximum

func _normal_clone(source: ShaderMaterial) -> ShaderMaterial:
	var clone := source.duplicate() as ShaderMaterial
	var code := source.shader.code
	expect(code.contains("ALBEDO = c;"), "wallpaper shader normal replacement anchor missing")
	var shader := Shader.new()
	shader.code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;").replace("ALBEDO = c;", "ALBEDO = wn * 0.5 + 0.5;")
	clone.shader = shader
	return clone

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Vegas wall finish audit requires a GPU renderer (omit --headless).")
		finish()
		return
	view = SubViewport.new()
	view.size = Vector2i(512, 512)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	board = MeshInstance3D.new()
	board.name = "Board"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.0, 3.2, 0.16)
	board.mesh = mesh
	board.position = Vector3(0, 1.6, 0)
	world.add_child(board)
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(4.0, 0.15, 0.22)
	rail.mesh = rail_mesh
	rail.material_override = Mats.darkwood()
	rail.position = Vector3(0, 0.075, -0.01)
	world.add_child(rail)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.position = Vector3(0, 1.6, 4.0)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.6, 0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-15, 0, 0)
	light.light_energy = 1.0
	world.add_child(light)
	await _warmup()
	for family in ["wallpaper", "hall_wallpaper"]:
		for idx in 3:
			var source := Mats.wallpaper_variant(idx) if family == "wallpaper" else Mats.hall_wallpaper_variant(idx)
			var clone := _normal_clone(source as ShaderMaterial)
			var normal := await _render(clone)
			clone.set_shader_parameter("paper_relief", 0.0)
			var flat := await _render(clone)
			var error := _max_error(normal, flat, Rect2i(20, 30, 472, 300))
			print("VEGAS_NORMAL family=%s variant=%d max_rgb_error=%d" % [family, idx, error])
			expect(error <= 4, "%s variant %d normal mismatch=%d" % [family, idx, error])
			var bound_wood: Texture2D = source.get_shader_parameter("wood_tex")
			expect(bound_wood != null and bound_wood.resource_path == "res://textures/annex/half_wall_cap_wood.png",
				"%s variant %d missing supplied wood grain" % [family, idx])
	var source0 := Mats.wallpaper_variant(0) as ShaderMaterial
	var wood_clone := _normal_clone(source0)
	var base := await _render(wood_clone)
	wood_clone.set_shader_parameter("wood_relief", 0.0)
	wood_clone.set_shader_parameter("joint_depth", 0.0)
	var relief := await _render(wood_clone)
	var changed := _max_error(base, relief, Rect2i(20, 390, 472, 85))
	print("VEGAS_WOOD max_rgb_change=%d" % changed)
	expect(changed >= 2, "wood relief produced no measurable board variation")
	var wood_tex := load("res://textures/annex/half_wall_cap_wood.png") as Texture2D
	expect(wood_tex != null and wood_tex.get_image().has_mipmaps(), "wood texture missing mipmaps")
	var uniforms := source0.shader.get_shader_uniform_list()
	for uniform in uniforms:
		expect(uniform.name != "bump_strength" and uniform.name != "col_flock", "obsolete wallpaper uniform remains: %s" % uniform.name)
	view.queue_free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("Vegas wallpaper normals and timber relief")
