extends SceneTree
## Natural generated rooms, with production Poolrooms lighting and water.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
##   --script tools/capture_pool_equipment.gd
const CASES := [
	{"kind": "diving_board", "seed": 1029384756, "cell": Vector2i(-9, 4)},
	{"kind": "slide_straight", "seed": 1029384756, "cell": Vector2i(-10, -6)},
	{"kind": "slide_spiral", "seed": 1029384756, "cell": Vector2i(-10, 9)},
]
var output := "res://build/pool-equipment-review"
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	call_deferred("run")
func draw(frames: int) -> void:
	for i in frames:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(1440, 960)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_taa = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(9)
	view.add_child(env)
	var camera := Camera3D.new()
	camera.fov = 68
	view.add_child(camera)
	camera.current = true
	var failures := 0
	for entry: Dictionary in CASES:
		var cell: Vector2i = entry["cell"]
		var stage := Node3D.new()
		view.add_child(stage)
		var center: Chunk
		for x in range(cell.x-1, cell.x+2):
			for z in range(cell.y-1, cell.y+2):
				var chunk := Chunk.new(int(entry["seed"]), Vector2i(x, z), 9)
				chunk.position = Vector3((x-cell.x)*12, 0, (z-cell.y)*12)
				stage.add_child(chunk)
				if Vector2i(x,z) == cell: center = chunk
		var prop: Node3D
		for node in center.get_children():
			if node.get_meta("pool_equipment", "") == entry["kind"]:
				prop = node; break
		if prop == null:
			printerr("Expected naturally generated %s missing at %s" % [entry["kind"],cell])
			failures += 1; stage.free(); continue
		var board: bool = entry["kind"] == "diving_board"
		for reverse in [false, true]:
			var offset := Vector3(-3.4 if reverse else 3.0, 2.2, 4.3)
			if board: offset = Vector3(-1.5 if reverse else 1.7, 1.65, 2.6)
			camera.position = prop.position + offset.rotated(Vector3.UP, prop.rotation.y)
			camera.position.x = clampf(camera.position.x, .7, 11.3)
			camera.position.z = clampf(camera.position.z, .7, 11.3)
			camera.look_at(prop.position + Vector3(.15, .35 if board else 1.2, -.6).rotated(Vector3.UP, prop.rotation.y), Vector3.UP)
			await draw(100 if not reverse else 40)
			var name := "pool-" + str(entry["kind"]).replace("_", "-") + "-room" + ("-reverse" if reverse else "")
			view.get_texture().get_image().save_png(output.path_join(name + ".png"))
			print("CAPTURE %s seed=%d cell=%s" % [name, entry["seed"],cell])
		stage.free()
		await process_frame
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("POOL EQUIPMENT CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
