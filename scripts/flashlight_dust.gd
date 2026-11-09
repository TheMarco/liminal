extends MultiMeshInstance3D
## One bounded draw of world-anchored motes. The torch illuminates them; this
## node never adds lights or emission to the surrounding room. Quality changes
## reduce geometry rather than replacing the effect with a screen overlay.
const DUST_SHADER := preload("res://shaders/flashlight_dust.gdshader")
const GRID_WIDTHS := [8, 12, 18, 22]
const HALF_EXTENTS := Vector3(7.0, 3.5, 7.0)
# Casino, Office, Annex, unused, Airport, Asylum, School, Mall, Prison,
# Pool, Data Center, Bloom. Existing Bloom spores remain a separate effect.
const DENSITIES := [0.18, 0.35, 0.68, 0.0, 0.06, 0.82, 0.45, 0.13, 0.62, 0.04, 0.22, 0.26]

var quality_tier := -1
var cell_size := 1.0
var density := 0.0
var motion_time := 0.0
var _theme := -1
var _body: Node3D
var _light: SpotLight3D
var _camera: Camera3D
var _material: ShaderMaterial

func configure(body: Node3D, light: SpotLight3D, camera: Camera3D) -> void:
	name = "FlashlightDust"
	_body = body
	_light = light
	_camera = camera
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	custom_aabb = AABB(-HALF_EXTENTS-Vector3.ONE, HALF_EXTENTS*2.0+Vector3.ONE*2.0)
	_material = ShaderMaterial.new()
	_material.shader = DUST_SHADER
	material_override = _material
	# Run after the player's interpolated camera update, including head motion.
	process_priority = 1
	apply_quality(1)
	set_theme(int(body.level_theme))
	visible = false

func apply_quality(tier: int) -> void:
	tier = clampi(tier, 0, 3)
	if quality_tier == tier: return
	quality_tier = tier
	var width: int = GRID_WIDTHS[tier]
	var height: int = width / 2
	cell_size = HALF_EXTENTS.x*2.0/width
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	instances.mesh = quad
	instances.instance_count = width*height*width
	var index := 0
	for z in width:
		for y in height:
			for x in width:
				var at := Vector3(x-width/2, y-height/2, z-width/2)*cell_size
				instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
				index += 1
	multimesh = instances
	_material.set_shader_parameter("cell_size", cell_size)
	# A little more coverage keeps the sparse Low version legible at 360p.
	_material.set_shader_parameter("mote_size", [0.023, 0.019, 0.014, 0.012][tier])

func set_theme(theme: int) -> void:
	_theme = theme
	density = DENSITIES[theme] if theme >= 0 and theme < DENSITIES.size() else 0.18
	_material.set_shader_parameter("density", density)
	_material.set_shader_parameter("dust_colour", Color(0.86, 0.81, 0.70) if theme in [0,1,2,5,6] else Color(0.77,0.83,0.87))

func update_field() -> void:
	if not is_inside_tree() or not is_instance_valid(_camera): return
	if _theme != int(_body.level_theme): set_theme(int(_body.level_theme))
	var water: float = _body.water_y
	visible = _light.visible and density > 0.0 and _camera.global_position.y > water+0.08
	if not visible: return
	var eye := _camera.global_position
	# Snap only the field bounds. Hashing each world cell in the shader means
	# retained motes keep their positions when this box crosses a cell boundary.
	global_transform = Transform3D(Basis.IDENTITY, (eye/ cell_size).floor()*cell_size)
	_material.set_shader_parameter("observer_position", eye)
	_material.set_shader_parameter("light_position", _light.global_position)
	_material.set_shader_parameter("light_direction", -_light.global_basis.z)
	_material.set_shader_parameter("light_colour", _light.light_color)
	_material.set_shader_parameter("light_energy", _light.light_energy/4.5)
	_material.set_shader_parameter("cone_slope", tan(deg_to_rad(_light.spot_angle*0.48)))
	_material.set_shader_parameter("water_height", water)
	_material.set_shader_parameter("motion_time", motion_time)

func _process(dt: float) -> void:
	motion_time += dt
	update_field()
