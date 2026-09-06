extends SceneTree
## GPU capture harness for the Poolrooms wet-room styles.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop --script tools/capture_pool_water.gd -- --out=/tmp/water

const THEME := 9
const SEED := 240721
const STYLES := [90, 91, 95, 97]
var output := "res://build/water-review"
var filter := ""
var baseline := false
var motion := false
var view: SubViewport
var stage: Node3D
var env_node: WorldEnvironment

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		elif arg.begins_with("--filter="): filter = arg.trim_prefix("--filter=")
		elif arg == "--baseline": baseline = true
		elif arg == "--motion": motion = true
	call_deferred("run")

func draw(count := 1) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func anchors() -> Dictionary:
	var ws := WorldGen.level_seed(SEED, THEME)
	var found := {}
	for radius in 16:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				if style in STYLES and not found.has(style) and WorldGen.room_id(ws, cell) == cell:
					found[style] = cell
	return found

func look(camera: Camera3D, target: Vector3) -> void:
	camera.look_at(target, Vector3.UP)

func apply_baseline() -> void:
	if not baseline: return
	# The fountain retains the original pool shader, so a clean checkout can
	# reproduce this comparison without an ignored local snapshot.
	var shader := load("res://shaders/fountain_water.gdshader") as Shader
	var material := ShaderMaterial.new()
	var normal: Texture2D = Mats.pool_water().get_shader_parameter("normal_tex") as Texture2D
	material.shader = shader
	material.set_shader_parameter("normal_tex", normal)
	Mats._c["pool_water"] = material

func capture(camera: Camera3D, prefix: String, chunks: Array, env: Environment) -> void:
	camera.current = true
	await draw(140 if prefix.ends_with("poolside") else 32)
	var image: Image = view.get_texture().get_image()
	image.save_png(output + "/" + prefix + "-bright.png")
	print("CAPTURE %s draw_calls=%d objects=%d vram=%.2fMiB" % [prefix, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	for chunk in chunks: chunk.set_blackout(true)
	env.ambient_light_energy = .003
	await draw(50)
	view.get_texture().get_image().save_png(output + "/" + prefix + "-blackout.png")
	print("CAPTURE %s-blackout draw_calls=%d objects=%d vram=%.2fMiB" % [prefix, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	for chunk in chunks: chunk.set_blackout(false)
	env.ambient_light_energy = .425
	await draw(50)

func capture_motion(camera: Camera3D, style: int) -> void:
	camera.current = true
	var material := Mats.pool_water()
	var original_shader: Shader = material.shader
	var source := original_shader.code
	var shader := Shader.new()
	var marker := source.find("shader_type spatial")
	if marker < 0:
		printerr("Motion capture skipped style %d: shader has no spatial declaration" % style)
		return
	var line_end := source.find("\n", marker)
	var declaration := "\nuniform float capture_clock = 0.0;"
	var rewritten := source.substr(0, line_end) + declaration + source.substr(line_end)
	shader.code = rewritten.replace("TIME", "capture_clock")
	material.shader = shader
	DirAccess.make_dir_recursive_absolute(output + "/motion/style-%03d" % style)
	material.set_shader_parameter("capture_clock", 12.0)
	await draw(32)
	for frame in 240:
		material.set_shader_parameter("capture_clock", 12.0 + float(frame) / 30.0)
		await draw()
		view.get_texture().get_image().save_png(output + "/motion/style-%03d/frame-%04d.png" % [style, frame])
	material.shader = original_shader
	material.set_shader_parameter("capture_clock", null)
	print("MOTION style=%d frames=240 fps=30" % style)

func run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(output)
	var ws := WorldGen.level_seed(SEED, THEME)
	apply_baseline()
	var cells := anchors()
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_taa = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	env_node = WorldEnvironment.new()
	env_node.environment = EnvBuilder.build(THEME)
	view.add_child(env_node)
	var camera := Camera3D.new()
	camera.fov = 70.0
	view.add_child(camera)
	for style in STYLES:
		if not cells.has(style) or (not filter.is_empty() and filter != str(style)): continue
		var cell: Vector2i = cells[style]
		var chunks: Array[Chunk] = []
		for x in range(cell.x - 2, cell.x + 3):
			for z in range(cell.y - 2, cell.y + 3):
				var chunk := Chunk.new(ws, Vector2i(x, z), THEME)
				chunk.position = Vector3(x * Chunk.S, 0, z * Chunk.S)
				stage.add_child(chunk)
				chunks.append(chunk)
				if baseline:
					for node in chunk.find_children("*", "ReflectionProbe", true, false):
						if node.has_meta("pool_water_reflection"): node.queue_free()
		await draw(32)
		var centre: Chunk = chunks[12]
		var water: Node = null
		for node in centre.find_children("*", "MeshInstance3D", true, false):
			if node.has_meta("pool_water_surface"): water = node; break
		if water == null:
			for chunk in chunks:
				for node in chunk.find_children("*", "MeshInstance3D", true, false):
					if node.has_meta("pool_water_surface"): water = node; break
				if water != null: break
			if water == null: printerr("No water metadata for style %d" % style); continue
		var water_center: Vector3 = water.global_position
		var size: Vector2 = water.get_meta("pool_water_size")
		var water_y: float = water_center.y
		print("SELECT style=%d cell=%s water=%s size=%s" % [style, cell, water_center, size])
		var prefix := "style-%03d" % style
		camera.position = water_center + Vector3(size.x * .35, Chunk.POOL_DECK_Y + 1.55 - water_y, size.y * .5 + .7)
		look(camera, water_center + Vector3(0, 0, -size.y * .2))
		await capture(camera, prefix + "-poolside", chunks, env_node.environment)
		camera.position = Vector3(camera.position.x, water_y + .6, water_center.z + size.y * .5 - .35)
		look(camera, water_center + Vector3(0, .1, -size.y * .4))
		await capture(camera, prefix + "-low", chunks, env_node.environment)
		if motion: await capture_motion(camera, style)
		for chunk in chunks: chunk.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("POOL WATER CAPTURE PASS")
	quit()
