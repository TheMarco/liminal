extends SceneTree
## GPU-only deterministic captures of the Vegas wallpaper and hall finish variants.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
##   --script tools/capture_vegas_wall_finish.gd -- --out-dir=/tmp/liminal-vegas-finish

var out_dir := "/tmp/liminal-vegas-finish"
var view: SubViewport
var world: Node3D
var wall: MeshInstance3D
var camera: Camera3D

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	call_deferred("_capture")

func _box(size: Vector3, material: Material, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	world.add_child(node)
	return node

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Vegas wall finish capture requires a GPU renderer (omit --headless).")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	view = SubViewport.new()
	view.size = Vector2i(1280, 900)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.025, 0.021, 0.018)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.40, 0.34, 0.28)
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	_box(Vector3(7.0, 0.08, 5.0), _floor_material(), Vector3(0, -0.04, 0))
	wall = _box(Vector3(4.0, 3.2, 0.16), Mats.wallpaper_variant(0), Vector3(0, 1.6, 0))
	_box(Vector3(4.0, 0.15, 0.22), Mats.darkwood(), Vector3(0, 0.075, -0.01))
	_box(Vector3(4.0, 0.08, 0.22), Mats.darkwood(), Vector3(0, 1.0, -0.01))
	camera = Camera3D.new()
	camera.position = Vector3(2.4, 1.65, 3.8)
	camera.fov = 52.0
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.45, 0.08), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -34, 0)
	light.light_color = Color(1.0, 0.70, 0.43)
	light.light_energy = 1.15
	light.shadow_enabled = true
	world.add_child(light)
	# Let detail-noise textures and the GPU shader pipeline settle before readback.
	for _warmup in 12:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	for family in ["wallpaper", "hall_wallpaper"]:
		for idx in 3:
			wall.material_override = Mats.wallpaper_variant(idx) if family == "wallpaper" else Mats.hall_wallpaper_variant(idx)
			var path := "%s/vegas_%s_variant_%d.png" % [out_dir, family, idx]
			if not await _save(path):
				quit(1)
				return
			# Keep the scene warm between material swaps.
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 60.0)
	# A close board framing shows the paper-to-darkwood transition.
	wall.material_override = Mats.wallpaper_variant(0)
	camera.position = Vector3(1.0, 0.95, 1.65)
	camera.look_at(Vector3(0, 0.9, 0.08), Vector3.UP)
	for _warmup in 12:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	if not await _save("%s/vegas_variant0_wood_paper_transition.png" % out_dir):
		quit(1)
		return
	print("VEGAS_FINISH_CAPTURE out_dir=%s" % out_dir)
	world.queue_free()
	view.queue_free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0)

func _floor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.050, 0.045)
	material.roughness = 0.92
	return material

func _save(path: String) -> bool:
	await process_frame
	RenderingServer.force_draw(false, 1.0 / 60.0)
	var image := view.get_texture().get_image()
	var data := image.get_data()
	if data.is_empty():
		printerr("GPU readback was empty: %s" % path)
		return false
	var error := image.save_png(path)
	if error != OK:
		printerr("Could not save %s (error=%d)" % [path, error])
		return false
	print(path)
	return true
