class_name SelfReturnLandmark
extends Node3D
## A single physical landmark shared by the doorway preview and the room
## reached after crossing. It is placed before the player approaches the door.

const CHAIR := preload("res://models/authored/office_chair/office_chair.glb")

var _lamp: OmniLight3D
var _panel_glow: StandardMaterial3D
var _phase := 0.0


func build(ceiling_above_floor: float, yaw: float, seed_value: int) -> void:
	var chair := Node3D.new()
	chair.name = "Overturned office chair"
	chair.rotation.y = yaw
	add_child(chair)
	var model: Node3D = CHAIR.instantiate()
	# The model is centred on its pivot and roughly 0.9 m tall. Laying it on
	# its side leaves the casters and upholstered back legible from the doorway.
	model.position.y = 0.43
	model.rotation = Vector3(0.12, 0.0, 1.48)
	chair.add_child(model)
	var body := StaticBody3D.new()
	body.name = "Fallen chair collision"
	body.position.y = 0.40
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.94, 0.78, 0.94)
	shape.shape = box
	body.add_child(shape)

	var fixture := MeshInstance3D.new()
	fixture.name = "Flickering ceiling lamp"
	var lamp_height := minf(ceiling_above_floor - 0.075, 2.65)
	fixture.position.y = lamp_height
	var panel := BoxMesh.new()
	panel.size = Vector3(1.35, 0.055, 0.55)
	fixture.mesh = panel
	_panel_glow = StandardMaterial3D.new()
	_panel_glow.albedo_color = Color(0.73, 0.81, 0.90)
	_panel_glow.emission_enabled = true
	_panel_glow.emission = Color(0.70, 0.79, 1.0)
	_panel_glow.emission_energy_multiplier = 2.6
	fixture.material_override = _panel_glow
	add_child(fixture)
	var drop := ceiling_above_floor - lamp_height
	if drop > 0.18:
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color(0.18, 0.21, 0.24)
		metal.metallic = 0.6
		for side in [-0.48, 0.48]:
			var hanger := MeshInstance3D.new()
			hanger.name = "Ceiling light hanger"
			hanger.position = Vector3(side, lamp_height + drop * 0.5, 0)
			var rod := BoxMesh.new()
			rod.size = Vector3(0.018, drop, 0.018)
			hanger.mesh = rod
			hanger.material_override = metal
			add_child(hanger)
	_lamp = OmniLight3D.new()
	_lamp.name = "Uneven fluorescent light"
	_lamp.set_meta("visible_source", "Flickering ceiling lamp")
	_lamp.position.y = lamp_height - 0.245
	_lamp.light_color = Color(0.79, 0.86, 1.0)
	_lamp.omni_range = 4.2
	_lamp.light_energy = 0.85
	add_child(_lamp)
	_phase = float(posmod(seed_value, 11)) * 0.13


func cue_recognition() -> void:
	# Restart the same fixture's pattern so it visibly stutters in the short
	# recognition beat, including if it happened to be steady on approach.
	_phase = 0.0


func _process(dt: float) -> void:
	if _lamp == null: return
	_phase = fposmod(_phase + dt, 2.7)
	var dim := 1.0
	if not GameSettings.flashing_reduced() and (
			(_phase > 0.38 and _phase < 0.48)
			or (_phase > 0.61 and _phase < 0.68)):
		dim = 0.28
	_lamp.light_energy = 0.85 * dim
	_panel_glow.emission_energy_multiplier = 2.6 * dim
