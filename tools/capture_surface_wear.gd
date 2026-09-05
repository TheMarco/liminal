extends SceneTree
## Inspection camera for one actual generated room, without player/HUD motion.
## --theme=ID --style=ID --cause=SUBSTRING --out=/tmp/view.png [--clean]
## With a cause, finds a room containing that mark and frames its real support.
## Clean mode uses the decorated camera but rebuilds the same seed without wear.

var theme := 2
var style := -1
var cause := ""
var output := "/tmp/surface-wear.png"
var clean := false
var support_only := false
var support: Node = null
const SEED := 980712989


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): theme = int(arg.trim_prefix("--theme="))
		if arg.begins_with("--style="): style = int(arg.trim_prefix("--style="))
		if arg.begins_with("--cause="): cause = arg.trim_prefix("--cause=" )
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=" )
		if arg == "--clean": clean = true
		if arg == "--support-only": support_only = true
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	var ws := WorldGen.level_seed(SEED, theme)
	var selected: Chunk = null
	var focus := Vector3(6, 1.4, 8)
	var normal := Vector3.FORWARD
	var width := 3.0
	for r in range(0, 13):
		if selected != null: break
		for x in range(-r, r + 1):
			if selected != null: break
			for z in range(-r, r + 1):
				var cell := Vector2i(x, z)
				if r > 0 and abs(x) != r and abs(z) != r: continue
				if style >= 0 and WorldGen.cell_style(ws, cell, theme) != style: continue
				var room := WorldGen.annex_room_id(ws, cell) if theme == 2 else WorldGen.room_id(ws, cell)
				if room != cell and cell != Vector2i.ZERO: continue
				var chunk := Chunk.new(ws, cell, theme)
				if cause.is_empty():
					selected = chunk
					break
				for node in chunk.find_children("*", "MeshInstance3D", true, false):
					if str(node.get_meta("surface_wear_cause", "")).contains(cause):
						focus = node.get_meta("surface_wear_center")
						normal = node.get_meta("surface_wear_normal")
						var size_: Vector2 = node.get_meta("surface_wear_size")
						width = maxf(size_.x, size_.y)
						selected = chunk
						support = node.get_parent()
						break
				if selected != null: break
				chunk.free()
	if selected == null:
		printerr("No room matches theme/style/cause")
		quit(1)
		return
	var cell := selected.cell
	print("WEAR_VIEW theme=%d style=%d cell=%s cause=%s summary=%s" % [
		theme, selected.style, cell, cause, selected.get_meta("surface_wear_summary", {})])
	var world := Node3D.new()
	root.add_child(world)
	if clean:
		selected.free()
		SurfaceWear.enabled = false
		selected = Chunk.new(ws, cell, theme)
	world.add_child(selected)
	if support_only and not clean and support != null:
		for mesh in selected.find_children("*", "GeometryInstance3D", true, false):
			if mesh != support and not support.is_ancestor_of(mesh):
				mesh.visible = false
	var we := WorldEnvironment.new()
	we.environment = EnvBuilder.build(theme)
	world.add_child(we)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 68
	camera.near = 0.06
	var distance_ := clampf(width * 1.3, 1.3, 4.0)
	if absf(normal.y) > 0.5:
		camera.position = focus + Vector3(0, 1.55, -1.5)
	else:
		camera.position = focus + normal * distance_ + Vector3.UP * 0.15
	camera.position.y = clampf(camera.position.y, 0.4, selected.ceil_h - 0.2)
	camera.look_at(focus, Vector3.UP)
	camera.current = true
	if support_only:
		# Neutral inspection light makes grout alignment readable even when the
		# selected room has dead fixtures. This is never part of gameplay.
		var fill := OmniLight3D.new()
		fill.position = camera.position
		fill.light_energy = 1.2
		fill.omni_range = 12.0
		fill.shadow_enabled = false
		world.add_child(fill)
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	for mark in selected.find_children("*", "MeshInstance3D", true, false):
		if not mark.has_meta("surface_wear_parameters") or not mark.material_override is ShaderMaterial:
			continue
		var applied: Dictionary = mark.get_meta("surface_wear_parameters")
		for parameter: String in applied:
			var actual: Variant = mark.get_instance_shader_parameter(parameter)
			if actual == null or actual != applied[parameter]:
				printerr("Wear GPU parameter mismatch: %s on %s" % [parameter, mark.name])
				quit(1)
				return
	var result := root.get_texture().get_image().save_png(output)
	print("WEAR_CAPTURE %s error=%d" % [output, result])
	world.queue_free()
	await process_frame
	Chunk.clear_runtime_caches()
	Mats.clear_runtime_caches()
	await process_frame
	quit(result)
