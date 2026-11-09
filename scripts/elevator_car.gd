class_name ElevatorCar
extends Node3D
## Supplied GLB in the game's car space: back at Z=0, corridor toward +Z.
## Chunk owns travel, sounds and occupancy. This node only presents its state.

const MODEL_PATH := "res://models/provided/elevator/Elevator.glb"
const THRESHOLD_Z := 2.56
const FLOOR_LIFT := 0.008
const DOORS := [
	["Door_Left", 0.922, 0.464],
	["Door_Left_Outer", 0.460, 0.468],
	["Door_Right", -0.922, 0.464],
	["Door_Right_Outer", -0.460, 0.468],
]

var doors: Array[Dictionary] = []
var call_button: MeshInstance3D
var display: Label3D
var light: OmniLight3D
var _call_ring: StandardMaterial3D
var _call_rest: Vector3
var openness := 0.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		for entry in doors:
			var door: AnimatableBody3D = entry["body"]
			door.position = entry["rest"] + Vector3(float(entry["travel"]) * openness, 0, 0)


func _init(scene: PackedScene = null) -> void:
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI
	model.position = Vector3(0, FLOOR_LIFT, THRESHOLD_Z)
	model.set_meta("attributed_asset", MODEL_PATH)
	add_child(model)
	# The game can reverse a closing arrival door. One continuous value drives
	# all leaves and their collision instead of restarting baked animation clips.
	for animation in model.find_children("*", "AnimationPlayer", true, false):
		animation.get_parent().remove_child(animation)
		animation.free()
	for spec in DOORS:
		var mesh := model.find_child(spec[0], true, false) as MeshInstance3D
		assert(mesh != null, "Missing supplied elevator leaf: " + str(spec[0]))
		var parent := mesh.get_parent()
		var rest := mesh.transform
		var door := AnimatableBody3D.new()
		door.name = str(spec[0]) + "_Physics"
		door.sync_to_physics = false # Only physics-mode tweens move these bodies.
		mesh.owner = null
		parent.remove_child(mesh)
		parent.add_child(door)
		door.transform = rest
		door.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		_add_box(door, Vector3(0, 1.147, 0), Vector3(float(spec[2]), 2.262, 0.086))
		doors.append({"body": door, "rest": rest.origin, "travel": spec[1]})
	_build_collision(model)
	call_button = model.find_child("Call_Button", true, false) as MeshInstance3D
	_call_rest = call_button.position
	for surface in call_button.mesh.get_surface_count():
		var material := call_button.get_active_material(surface) as StandardMaterial3D
		if material != null and material.resource_name.begins_with("09"):
			_call_ring = material.duplicate() as StandardMaterial3D
			call_button.set_surface_override_material(surface, _call_ring)
	# Keep the supplied indicator frame/glass; replace its fixed caret with the
	# live floor/wait readout in exactly that opening, below the lowest ceiling.
	var indicator := model.find_child("Down_Indicator", true, false) as MeshInstance3D
	var indicator_mesh := indicator.mesh.duplicate() as ArrayMesh
	for surface in range(indicator_mesh.get_surface_count() - 1, -1, -1):
		if indicator_mesh.surface_get_material(surface).resource_name.begins_with("09"):
			indicator_mesh.surface_remove(surface)
	indicator.mesh = indicator_mesh
	indicator.set_meta("elevator_indicator_header", true)
	indicator.set_meta("elevator_indicator_top", 2.577 + FLOOR_LIFT)
	display = Label3D.new()
	display.name = "FloorDisplay"
	display.font_size = 52
	display.pixel_size = 0.0013
	display.modulate = Color(1.0, 0.56, 0.18)
	display.position = Vector3(0, 2.486 + FLOOR_LIFT, THRESHOLD_Z + 0.114)
	display.set_meta("elevator_indicator_label", true)
	add_child(display)
	light = OmniLight3D.new()
	light.name = "CabinLight"
	light.position = Vector3(0, 2.25, THRESHOLD_Z - 1.32)
	light.light_color = Color(1.0, 0.82, 0.62)
	light.light_energy = 1.25
	light.omni_range = 6.5
	light.shadow_enabled = false
	light.set_meta("visible_source", "elevator_ceiling_panel")
	add_child(light)


func _build_collision(model: Node3D) -> void:
	var shell := StaticBody3D.new()
	shell.name = "CabinCollision"
	model.add_child(shell)
	# Same metre-scale boxes as the supplied collision manifest. The floor is
	# raised 8mm with the model to keep room flooring from showing through it.
	_add_box(shell, Vector3(0, -0.08, 1.178), Vector3(2.84, 0.16, 2.56))
	_add_box(shell, Vector3(0, 1.23, 2.37), Vector3(2.32, 2.46, 0.14))
	_add_box(shell, Vector3(0, 2.452, 1.33), Vector3(2.30, 0.102, 2.075))
	_add_box(shell, Vector3(0, 2.495, 0.124), Vector3(2.879, 0.428, 0.473))
	for side in [-1.0, 1.0]:
		_add_box(shell, Vector3(side * 1.153, 1.225, 1.335), Vector3(0.076, 2.45, 2.08))
		_add_box(shell, Vector3(side * 1.163, 1.30, 0.122), Vector3(0.535, 2.60, 0.46))
		_add_box(shell, Vector3(side * 1.405, 1.30, 1.25), Vector3(0.068, 2.60, 2.57))
	_add_box(shell, Vector3(0, 1.30, 2.47), Vector3(2.84, 2.60, 0.09))


func _add_box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	parent.add_child(collider)


func move_doors(open: bool, seconds: float) -> Tween:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "openness", 1.0 if open else 0.0, seconds)
	return tween


func press_call() -> void:
	var tween := create_tween()
	tween.tween_property(call_button, "position", _call_rest + Vector3(0, 0, 0.003), 0.08)
	tween.tween_property(call_button, "position", _call_rest, 0.14)


func set_call_lit(on: bool) -> void:
	if _call_ring != null:
		_call_ring.emission_energy_multiplier = 4.0 if on else 0.6
