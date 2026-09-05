extends Node3D
## Visual-QA stage for the apparition shader.
##
## A ghost in the world can only be looked at by playing until one arrives and
## then killing it, which takes about a minute per frame you want to judge and
## never gives you the same frame twice. This stages one ghost against a lit wall
## and pins its shader state, so the burn can be stepped through and compared
## shot for shot.
##
## It builds the layered visual the way ShadowFigure does — same material, same instance
## uniforms — so what it shows is the shader the game runs, not a copy.
##
## Run: godot --path . tools/preview_ghost.tscn -- \
##   --sheet=wraith5 --ignite=0.45 --screenshot=/tmp/burn.png
##
##   --sheet=NAME    any key of ShadowFigure.BODY (default wraith5)
##   --frame=N       sprite-sheet frame, default 0
##   --burn=0..1     torch charge, the ember heat before a kill
##   --ignite=0..1   consumption progress; implies the kill path
##   --wall=0..1     how brightly lit the wall behind it is, default 0.55
##   --screenshot=PATH  where to write the frame

const CELL := 1.0


func _ready() -> void:
	var sheet := "wraith5"
	var shot := "/tmp/liminal-ghost.png"
	var frame := 0.0
	var burn := 0.0
	var torch := 0.0
	var ignite := -1.0
	var wall := 0.55
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sheet="):
			sheet = arg.substr(8)
		elif arg.begins_with("--frame="):
			frame = float(arg.substr(8))
		elif arg.begins_with("--burn="):
			burn = float(arg.substr(7))
		elif arg.begins_with("--torch="):
			torch = float(arg.substr(8))
		elif arg.begins_with("--ignite="):
			ignite = float(arg.substr(9))
		elif arg.begins_with("--wall="):
			wall = float(arg.substr(7))
		elif arg.begins_with("--screenshot="):
			shot = arg.substr(13)
	if not ShadowFigure.BODY.has(sheet):
		push_error("unknown sheet %s" % sheet)
		get_tree().quit(1)
		return

	_stage(wall)
	_figure(sheet, frame, burn, ignite, torch)

	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	print("%s frame=%d burn=%.2f ignite=%.2f -> %s"
		% [sheet, int(frame), burn, ignite, shot])
	get_tree().quit()


## A lit wall and a floor. The shader multiplies whatever is behind it, so a
## preview against an empty viewport would show nothing at all — the backdrop
## is the subject as much as the figure is.
func _stage(wall_lit: float) -> void:
	# The game's own environment, not an approximation of it. Tone mapping,
	# exposure and above all the glow curve decide what a hot ember looks like,
	# and tuning the burn against a preview that blooms harder than the game
	# would produce a kill that is correct nowhere.
	var env := WorldEnvironment.new()
	var e := EnvBuilder.build(0)
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.025)
	e.fog_enabled = false
	e.volumetric_fog_enabled = false
	env.environment = e
	add_child(env)

	# A checked wall: the whole point of an absorbing body is that structure
	# behind it survives at a fraction of its brightness, and a flat backdrop
	# cannot show whether that is happening.
	var checker := GradientTexture2D.new()
	var grid := StandardMaterial3D.new()
	grid.albedo_color = Color(wall_lit, wall_lit * 0.93, wall_lit * 0.84)
	grid.roughness = 0.9
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(8.0, 5.0, 0.2)
	back.mesh = bm
	back.material_override = grid
	back.position = Vector3(0, 1.6, -1.6)
	add_child(back)

	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(wall_lit * 0.35, wall_lit * 0.3, wall_lit * 0.26)
	for i in 9:
		var bar := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(0.16, 5.0, 0.04)
		bar.mesh = bmesh
		bar.material_override = stripe
		bar.position = Vector3(-3.2 + float(i) * 0.8, 1.6, -1.48)
		add_child(bar)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.20, 0.10, 0.10)
	floor_mat.roughness = 0.95
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(8.0, 0.1, 6.0)
	fl.mesh = fm
	fl.material_override = floor_mat
	fl.position = Vector3(0, -0.05, 0)
	add_child(fl)

	var key := OmniLight3D.new()
	key.light_energy = 2.2
	key.omni_range = 12.0
	key.light_color = Color(1.0, 0.93, 0.82)
	key.position = Vector3(1.6, 2.6, 1.4)
	add_child(key)

	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	# look_at needs the node in the tree to have a global transform to work from.
	cam.look_at_from_position(Vector3(0, 1.15, 2.6), Vector3(0, 1.05, 0),
		Vector3.UP)
	cam.current = true


## The same quad ShadowFigure builds, at the same proportions, with its shader
## state pinned instead of driven.
func _figure(sheet: String, frame: float, burn: float, ignite: float,
		torch: float) -> void:
	var body: Array = ShadowFigure.BODY[sheet]
	var h := 2.05
	var qh: float = h / (float(body[2]) - float(body[1]))
	var w: float = qh * float(body[0])
	var quad := ShadowFigure.make_visual(sheet)
	quad.scale = Vector3(w, qh, 1.0)
	quad.position = Vector3(0, qh * (0.5 - float(body[1])), 0)
	quad.set_instance_shader_parameter("flip_frame", frame)
	quad.set_instance_shader_parameter("burn", clampf(burn, 0.0, 1.0))
	quad.set_instance_shader_parameter("torch", clampf(torch, 0.0, 1.0))
	quad.set_instance_shader_parameter("dissolve_seed", 0.37)
	quad.set_instance_shader_parameter("sway", 0.0)
	# `ignite` latches the kill and `fade` drives how far it has run, exactly as
	# ShadowFigure does: the front hangs off the one-way fade, not off a clock.
	if ignite >= 0.0:
		quad.set_instance_shader_parameter("ignite", 1.0)
		quad.set_instance_shader_parameter("fade", 1.0 - clampf(ignite, 0.0, 1.0))
	else:
		quad.set_instance_shader_parameter("ignite", 0.0)
		quad.set_instance_shader_parameter("fade", 1.0)
	add_child(quad)
