extends "res://tools/lib/audit_base.gd"
const OUT := "res://build/sightline-review"
var view: SubViewport

func draw(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func capture_case(key: String, ws: int, cell: Vector2i, axis: int) -> void:
	var stage := Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = EnvBuilder.build(2)
	stage.add_child(environment)
	var cm := ChunkManager.new()
	cm.world_seed = ws
	cm.theme = 2
	stage.add_child(cm)
	cm.set_process(false)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			cm._build(cell + Vector2i(dx, dz))
	var camera := Camera3D.new()
	camera.fov = 77
	stage.add_child(camera)
	var post := PostProcessController.new()
	stage.add_child(post)
	post.setup(stage, false, false)
	var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
	var forward := Vector3.RIGHT if axis == 1 else Vector3.BACK
	var centre := origin + Vector3(6, Player.CAM_H, 6)
	for shot in ["approach", "inside"]:
		var from := centre - forward * (18.0 if shot == "approach" else 4.0)
		camera.look_at_from_position(from, centre)
		post.set_enabled(false)
		await draw(60)
		expect(view.get_texture().get_image().save_png(OUT.path_join(key + "-" + shot + "-clean.png")) == OK, "capture failed")
		post.set_enabled(true)
		await draw(4)
		view.get_texture().get_image().save_png(OUT.path_join(key + "-" + shot + "-tape.png"))
	print("SIGHTLINE_CAPTURE ", key, " cell=", cell, " seed=", ws)
	stage.free()
	await draw(2)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var cases := {}
	for seed in [240721, 4242, 1]:
		var ws := WorldGen.level_seed(seed, 2)
		for x in range(-12, 13):
			for z in range(-12, 13):
				var cell := Vector2i(x, z)
				if not WorldGen.annex_corridor_bend(ws, cell):
					continue
				var axis := WorldGen.annex_corridor_axis(ws, cell)
				var width := WorldGen.annex_horizontal_width(ws, z) if axis == 1 else WorldGen.annex_vertical_width(ws, x)
				var key := "%d-%.1fm" % [axis, width]
				if not cases.has(key):
					cases[key] = [ws, cell, axis]
	for key in cases:
		var data: Array = cases[key]
		await capture_case(key, data[0], data[1], data[2])
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("sightline captures")
