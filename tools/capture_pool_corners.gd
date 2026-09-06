extends SceneTree

const WS := 473692151
const THEME := 9
const CASES := [
	# Ordinary Basin: water corner at local (8.150, 3.559), rounded compact
	# basin corner id 1. This separates the compact rounding from the square
	# coping arcs at the other three rectangle corners.
	{"name": "compact-rounded-corner", "cell": Vector2i(-7, -7),
	 "target": Vector3(8.15, 1.1, 3.56), "camera": Vector3(5.2,3.3,5.6)},
	{"name": "standard-basin-corner", "cell": Vector2i(-7,-7),
	 "target": Vector3(2.895,1.1,3.56), "camera": Vector3(5.2,3.3,5.6)},
	# This Basin reaches its east cell edge and joins a Channel. Its low/high
	# coping is carried across x=12 by the continuous S-bend meshes.
	{"name": "basin-channel-east-seam", "cell": Vector2i(-7, 1),
	 "target": Vector3(12.0, 1.1, 5.15)},
]
var output := "res://build/pool-corner-review/after"

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	call_deferred("run")

func draw(frames: int) -> void:
	for _i in frames:
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
	env.environment = EnvBuilder.build(THEME)
	view.add_child(env)
	var camera := Camera3D.new()
	camera.fov = 58.0
	view.add_child(camera)
	camera.current = true
	for entry: Dictionary in CASES:
		var cell: Vector2i = entry["cell"]
		var stage := Node3D.new()
		view.add_child(stage)
		for x in range(cell.x - 1, cell.x + 2):
			for z in range(cell.y - 1, cell.y + 2):
				var chunk := Chunk.new(WS, Vector2i(x, z), THEME)
				chunk.position = Vector3((x - cell.x) * 12.0, 0.0, (z - cell.y) * 12.0)
				stage.add_child(chunk)
		var target: Vector3 = entry["target"]
		for pose in [
			{"suffix": "high", "offset": Vector3(6.3, 9.6, 7.7)},
			{"suffix": "low", "offset": Vector3(4.1, 3.3, 5.4)},
		]:
			camera.position = target + pose["offset"]
			if entry.has("camera"):
				camera.position = entry["camera"] + Vector3.UP * (0.6 if pose["suffix"] == "high" else 0.0)
			camera.look_at(target, Vector3.UP)
			await draw(55)
			var name := str(entry["name"]) + "-" + str(pose["suffix"])
			view.get_texture().get_image().save_png(output.path_join(name + ".png"))
			print("CAPTURE %s ws=%d cell=%s" % [name, WS, cell])
		stage.free()
		await process_frame
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
