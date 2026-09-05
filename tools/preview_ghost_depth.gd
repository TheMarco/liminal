extends Node3D
## Lightweight art-direction prototype, isolated from the game's enemies.
## Restored layered baseline. D: darkness. V: VHS. Space: pause. Drag: orbit.
## --screenshot=PATH saves a frame and exits; otherwise the preview stays open.

const PROTOTYPE := preload("res://shaders/ghost_depth_preview.gdshader")
var _camera: Camera3D
var _depth: Node3D
var _materials: Array[ShaderMaterial] = []
var _post: CanvasLayer
var _label: Label
var _environment: WorldEnvironment
var _lights: Array[OmniLight3D] = []
var _time := 0.0
var _pause := false
var _angle := 0.0
var _auto_orbit := true
var _dark := false
var _shot := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): _shot = arg.trim_prefix("--screenshot=")
		if arg == "--dark": _dark = true
	DisplayServer.window_set_title("Ghost baseline — D: darkness · V: VHS")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_environment = WorldEnvironment.new()
	add_child(_environment)
	_box(Vector3(0,-.08,0), Vector3(8,.16,16), Mats.annex_carpet())
	_box(Vector3(0,3.25,0), Vector3(8,.15,16), Mats.annex_ceiling())
	for side in [-1.0,1.0]:
		_box(Vector3(side*3.7,1.6,0), Vector3(.2,3.2,16), Mats.annex_wall_variant(3))
		_box(Vector3(side*2.25,1.6,-1.8), Vector3(2.8,3.2,.16), Mats.annex_wall_variant(3))
		_box(Vector3(side*3.54,.06,0), Vector3(.05,.12,16), Mats.annex_baseboard())
	_box(Vector3(0,1.6,-6), Vector3(8,3.2,.2), Mats.annex_wall_variant(3))
	for z in [-4.0,2.5]:
		var light := OmniLight3D.new()
		light.position = Vector3(.5,2.8,z)
		light.light_color = Color(1.0,.94,.73)
		light.light_energy = 1.1
		light.omni_range = 8
		add_child(light)
		_lights.append(light)
	_update_lighting()
	_camera = Camera3D.new()
	_camera.fov = 59
	add_child(_camera)
	_camera.current = true
	var art := load("res://textures/ghosts/wraith5.webp") as Texture2D
	_depth = Node3D.new()
	add_child(_depth)
	for i in 4:
		var layer := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.orientation = PlaneMesh.FACE_Z
		quad.size = Vector2(1.39,2.23)
		quad.subdivide_width = 18
		quad.subdivide_depth = 28
		layer.mesh = quad
		layer.position = Vector3(0,1.0,[0.0,-.22,.14,-.10][i])
		var material := ShaderMaterial.new()
		material.shader = PROTOTYPE
		material.set_shader_parameter("artwork",art)
		material.set_shader_parameter("noise_tex",Mats.detail_noise())
		material.set_shader_parameter("layer",float(i))
		layer.material_override = material
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_materials.append(material)
		_depth.add_child(layer)
	_post = CanvasLayer.new()
	add_child(_post)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = PostProcessController.make_live_found_footage_material()
	_post.add_child(overlay)
	PostProcessController.add_crt_display_pass(_post)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_label = Label.new()
	_label.position = Vector2(22,18)
	_label.add_theme_font_size_override("font_size",16)
	ui.add_child(_label)
	_update_view()
	if not _shot.is_empty():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()


func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)


func _process(dt: float) -> void:
	if not _pause: _time += dt
	if _auto_orbit: _angle = sin(_time*.35)*.20
	_camera.position = Vector3(sin(_angle)*4.2,1.65,cos(_angle)*4.2)
	_camera.look_at(Vector3(0,1.08,0))
	for material in _materials: material.set_shader_parameter("elapsed",_time)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D:
			_dark = not _dark
			_update_lighting()
		if event.keycode == KEY_V:
			_post.visible = not _post.visible
		if event.keycode == KEY_SPACE: _pause = not _pause
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		_update_view()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_auto_orbit = false
		_angle = clampf(_angle+event.relative.x*.004,-.42,.42)


func _update_lighting() -> void:
	var env := EnvBuilder.build(2)
	if _dark:
		# Lower actual room illumination, leaving camera exposure and the
		# ghost material unchanged so darkness cannot cheat its visibility.
		env.ambient_light_energy *= 0.04
		env.background_color *= 0.025
		env.fog_light_energy *= 0.06
		env.volumetric_fog_emission *= 0.025
		env.sdfgi_enabled = false
	_environment.environment = env
	for light in _lights:
		light.light_energy = 0.028 if _dark else 1.1


func _update_view() -> void:
	_label.text = "LAYERED GHOST BASELINE" \
		+ ("  /  DARK ROOM" if _dark else "  /  LIT ROOM") \
		+ "\nD: darkness   V: VHS   Space: pause   Drag: orbit"
