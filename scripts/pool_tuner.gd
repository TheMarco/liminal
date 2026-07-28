class_name PoolTuner
extends CanvasLayer
## Live tuning panel for the Poolrooms. Run the game with `--tune` and every
## number that decides how the water and the light look becomes a slider you
## can drag while standing in the room.
##
## This exists because tuning a look by editing a constant, rebuilding, taking
## a screenshot and guessing again is a terrible way to find a value — it costs
## a minute a step and you never see the thing move. Here you drag until it
## looks right, press P, and the panel prints the exact GDScript lines to paste
## back into `Mats`, `Chunk` and `main`.
##
## Toggle with T. Print with P.

## Sized to actually be usable while you play, not to be unobtrusive. The
## whole point of the panel is dragging a value and watching the water, which
## you cannot do with an 11px label and a 120px slider.
const ROW_H := 40
const FONT := 19
const HEAD_FONT := 21
const PANEL_W := 720
const NAME_W := 250
const SLIDER_W := 330
const VALUE_W := 96

## name, min, max, target. Target picks which material or resource owns it.
const WATER := [
	["wave_height", 0.0, 0.30],
	["normal_scale_a", 0.02, 1.20],
	["normal_scale_b", 0.02, 2.00],
	["normal_speed_a", -0.15, 0.15],
	["normal_speed_b", -0.15, 0.15],
	["normal_strength", 0.0, 2.0],
	["depth_fade", 0.2, 8.0],
	["opacity_min", 0.0, 1.0],
	["opacity_max", 0.0, 1.0],
	["refraction", 0.0, 0.08],
	["fresnel_power", 0.5, 10.0],
	["fresnel_strength", 0.0, 1.0],
	["foam_amount", 0.0, 1.0],
	["foam_distance", 0.02, 1.50],
	["water_roughness", 0.0, 0.40],
	["water_specular", 0.0, 1.0],
]
const TILE := [
	["tex_metres", 0.20, 3.00],
	["caustic_strength", 0.0, 2.0],
	["caustic_scale", 0.05, 2.0],
	["caustic_speed", 0.0, 1.5],
	["wet_strength", 0.0, 1.0],
	["roughness_floor", 0.0, 1.0],
]
## Environment properties, driven straight onto the live Environment.
const ENV := [
	["ambient_light_energy", 0.0, 2.0],
	["glow_intensity", 0.0, 2.0],
	["glow_bloom", 0.0, 1.0],
	["fog_density", 0.0, 0.05],
	["volumetric_fog_density", 0.0, 0.08],
]

var _root: PanelContainer
var _rows := {}
var _env: Environment


func _ready() -> void:
	layer = 90
	_build()
	set_process_input(true)


func _find_env() -> Environment:
	if _env != null:
		return _env
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var we := node as WorldEnvironment
		if we.environment != null:
			_env = we.environment
			return _env
	# Fall back to whatever the camera is carrying.
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.environment != null:
		_env = cam.environment
	return _env


func _build() -> void:
	_root = PanelContainer.new()
	_root.position = Vector2(24, 56)
	_root.custom_minimum_size = Vector2(PANEL_W, 0)
	# A readable slab behind it: over pale tile and bright water, a default
	# panel leaves the labels almost invisible.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.06, 0.90)
	bg.border_color = Color(0.45, 0.72, 0.68, 0.85)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(14)
	_root.add_theme_stylebox_override("panel", bg)
	add_child(_root)
	var scroll := ScrollContainer.new()
	# Scale the whole panel with the viewport. Authored at 720p and left at a
	# fixed pixel size it is a postage stamp on a retina window, which is
	# exactly what it was.
	var vh: float = float(get_viewport().get_visible_rect().size.y)
	var k := clampf(vh / 720.0, 1.0, 3.2)
	_root.scale = Vector2(k, k)
	scroll.custom_minimum_size = Vector2(PANEL_W - 28,
		maxf(420.0, vh / k - 150.0))
	_root.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(PANEL_W - 44, 0)
	scroll.add_child(col)
	_heading(col, "POOL WATER   ·   T hide   ·   P print values")
	for spec in WATER:
		_slider(col, "water", spec)
	_heading(col, "TILE / CAUSTICS")
	for spec in TILE:
		_slider(col, "tile", spec)
	_heading(col, "ENVIRONMENT")
	for spec in ENV:
		_slider(col, "env", spec)


func _heading(col: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", HEAD_FONT)
	l.add_theme_color_override("font_color", Color(0.58, 0.95, 0.88))
	l.custom_minimum_size = Vector2(0, ROW_H + 8)
	col.add_child(l)


## A uniform that has only ever had its shader-side default reads back as null
## from the material, so every lookup has to survive that rather than trying to
## build a float out of nothing.
func _num(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if value is float or value is int:
		return float(value)
	return fallback


## The value the shader itself declares. Without this every slider that had
## never been written from GDScript would open at the middle of its range and
## lie about the current look — and nudging it would jump the water.
func _shader_default(mat: ShaderMaterial, key: String) -> Variant:
	if mat == null or mat.shader == null:
		return null
	return RenderingServer.shader_get_parameter_default(
		mat.shader.get_rid(), key)


func _from_material(mat: ShaderMaterial, key: String, fallback: float) -> float:
	var set_value: Variant = mat.get_shader_parameter(key)
	if set_value != null:
		return _num(set_value, fallback)
	return _num(_shader_default(mat, key), fallback)


func _current(kind: String, key: String, fallback: float) -> float:
	match kind:
		"water":
			return _from_material(Mats.pool_water(), key, fallback)
		"tile":
			return _from_material(Mats.pool_tile(), key, fallback)
		_:
			var e := _find_env()
			return _num(e.get(key), fallback) if e != null else fallback


func _slider(col: VBoxContainer, kind: String, spec: Array) -> void:
	var key := str(spec[0])
	var row := HBoxContainer.new()
	col.add_child(row)
	var name_label := Label.new()
	name_label.text = key
	name_label.custom_minimum_size = Vector2(NAME_W, ROW_H)
	name_label.add_theme_font_size_override("font_size", FONT)
	name_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.93))
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = float(spec[1])
	slider.max_value = float(spec[2])
	slider.step = (slider.max_value - slider.min_value) / 400.0
	slider.custom_minimum_size = Vector2(SLIDER_W, ROW_H)
	var mid := (slider.min_value + slider.max_value) * 0.5
	slider.value = clampf(_current(kind, key, mid),
		slider.min_value, slider.max_value)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_W, ROW_H)
	value_label.add_theme_font_size_override("font_size", FONT)
	value_label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.92))
	value_label.text = "%.3f" % slider.value
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float):
		value_label.text = "%.3f" % v
		_apply(kind, key, v))
	_rows[key] = [kind, slider]


func _apply(kind: String, key: String, v: float) -> void:
	match kind:
		"water":
			# The material is shared and cached, so one write repaints every
			# water surface in the streamed world at once.
			Mats.pool_water().set_shader_parameter(key, v)
		"tile":
			Mats.pool_tile().set_shader_parameter(key, v)
			Mats.pool_wall_tile().set_shader_parameter(key, v)
		_:
			var e := _find_env()
			if e != null:
				e.set(key, v)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if k.physical_keycode == KEY_T:
		_root.visible = not _root.visible
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_P:
		_print_values()
		get_viewport().set_input_as_handled()


## Dump everything as source you can paste straight back into the project.
func _print_values() -> void:
	var water := []
	var tile := []
	var env := []
	for key in _rows:
		var kind: String = _rows[key][0]
		var v: float = (_rows[key][1] as HSlider).value
		var line := 'uniform float %s = %.4f;' % [key, v]
		match kind:
			"water": water.append(line)
			"tile": tile.append(line)
			_: env.append("\t\tenv.%s = %.4f" % [key, v])
	print("\n=== shaders/pool_water.gdshader ===")
	for l in water:
		print(l)
	print("\n=== shaders/pool_tile.gdshader ===")
	for l in tile:
		print(l)
	print("\n=== main._build_env(), theme 9 ===")
	for l in env:
		print(l)
	print("")
