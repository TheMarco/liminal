extends SceneTree
## Render every replacement on the actual production storefront geometry.
## GPU: godot --path . --audio-driver Dummy --disable-render-loop \
##   --script tools/preview_mall_signs.gd -- --out=/tmp/mall-sign-preview

var output := "res://build/mall-sign-preview"


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 960)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.08, 0.075, 0.065)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.86, 0.85, 0.79)
	world.environment.ambient_light_energy = 0.8
	view.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25.0, 155.0, 0.0)
	key.light_energy = 0.9
	view.add_child(key)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.position = Vector3(0, 1.85, -8)
	view.add_child(camera)
	camera.look_at(Vector3(0, 1.85, 0))
	camera.current = true
	var ws := WorldGen.level_seed(4242, 7)
	for index in Chunk.MALL_SIGN_FACES.size():
		var chunk := Chunk.new(ws, Vector2i.ZERO, 7)
		view.add_child(chunk)
		for existing in chunk.get_children():
			if existing is Node3D:
				existing.visible = false
		var builder = chunk._level_builder
		var salt := 0
		while builder._mall_painted_sign_index(WorldGen.h(ws, 0, 0, salt)) != index:
			salt += 1
			assert(salt < 10000, "No deterministic storefront for sign %d" % index)
		builder._mall_unit(2, 0.0, 0.0, 4.8, salt)
		for frame in 12:
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 60.0)
		var filename := "%s/sign_%s.png" % [output, Chunk.MALL_SIGN_FACES[index][0]]
		var error := view.get_texture().get_image().save_png(filename)
		assert(error == OK, "Could not save " + filename)
		print("STOREFRONT " + filename)
		chunk.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
