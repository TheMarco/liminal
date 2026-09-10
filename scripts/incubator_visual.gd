extends RefCounted
## Materials are shared; each vessel has its own phase and its egg alone pulses.
const PULSE := preload("res://scripts/bloom_pulse.gd")
const GLASS := preload("res://shaders/incubator_glass.gdshader")
const FLUID := preload("res://shaders/incubator_fluid.gdshader")
const BUBBLES := preload("res://shaders/incubator_bubbles.gdshader")
static var _materials: Dictionary = {}


static func configure(model: Node3D, phase: float) -> void:
	for entry in [["ContainmentGlass", GLASS, 2], ["PreservationLiquid", FLUID, 1], ["FluidBubbles", BUBBLES, 0]]:
		var mesh := model.find_child(entry[0], true, false) as MeshInstance3D
		if mesh == null:
			push_error("Incomplete authored incubator: " + String(entry[0]))
			continue
		if not _materials.has(entry[0]):
			var mat := ShaderMaterial.new()
			mat.shader = entry[1]
			mat.render_priority = entry[2]
			_materials[entry[0]] = mat
		mesh.material_override = _materials[entry[0]]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if entry[0] != "ContainmentGlass":
			mesh.set_instance_shader_parameter("phase", phase)
	var egg := model.find_child("LivingEgg", true, false) as MeshInstance3D
	if egg == null:
		push_error("Authored incubator is missing its egg")
		return
	var pulse := PULSE.new() as Node3D
	pulse.name = "LivingEggPulse"
	pulse.position = Vector3(0.23, 1.18, 0.035)
	pulse.rate = 1.35 + phase * 0.17
	pulse.amplitude = 0.022
	pulse.phase = phase
	model.add_child(pulse)
	# The imported scene owner is temporarily outside the tree during reparenting.
	egg.owner = null
	egg.reparent(pulse, false)
	egg.position = -pulse.position
	egg.set_meta("incubator_living_egg", true)
