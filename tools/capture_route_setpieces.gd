extends SceneTree
## Small, isolated construction/render fixture; no Main or profile writes.
const CASES := {1: Vector2i(37, 32), 2: Vector2i(26, 56), 4: Vector2i(37, 32),
	5: Vector2i(35, 24), 6: Vector2i(26, 24), 7: Vector2i(41, 44),
	8: Vector2i(26, 24), 9: Vector2i(39, 42), 10: Vector2i(44, 48), 11: Vector2i(36, 24)}
func _init() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.04, 0.04, 0.04)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.45
	viewport.add_child(environment)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 25
	lamp.light_energy = 1.8
	viewport.add_child(lamp)
	DirAccess.make_dir_recursive_absolute("/tmp/liminal-round4-visuals")
	for theme in CASES:
		var spec := ChunkBuildSpec.new()
		spec.descent = true
		spec.route_landmark = RouteSetpieces.NAMES[theme]
		var chunk := Chunk.new(21, CASES[theme], theme, spec)
		viewport.add_child(chunk)
		var floor_y := Chunk.cell_floor_h(21, CASES[theme], theme)
		camera.position = Vector3(9.8, floor_y + 2.4, 10.1)
		camera.look_at(Vector3(6, floor_y + 1.2, 6))
		lamp.position = Vector3(6, floor_y + 2.5, 7)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("/tmp/liminal-round4-visuals/landmark-%d.png" % theme)
		chunk.free()
		await process_frame
	viewport.free()
	print("Route setpiece captures complete")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
