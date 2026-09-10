class_name RealmDoorLeak
extends Node3D
## A small piece of the sealed wall pulses with code and retains a faint trace.
## It begins on approach, including when the player is looking elsewhere.
## The real opening
## remains a camera discovery; the cue has no collision or objective marker.

const DURATION := 1.8
const REPEAT_GAP := 6.0
const SHADER := preload("res://shaders/realm_door_leak.gdshader")
var active := false
var elapsed := 0.0
var cooldown := 0.0
var pulses := 0
var _patch: MeshInstance3D
var _light: OmniLight3D
var _material: ShaderMaterial


func configure(centre: Vector3, forward: Vector3, world_seed: int) -> void:
	global_position = centre - forward * 0.16 + Vector3.UP * 1.55
	look_at(global_position - forward)
	_patch = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.5, 1.65)
	_patch.mesh = quad
	_patch.layers = PhotoAnomaly.EYE_ONLY_LAYER
	_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("seed", float(posmod(world_seed, 10000)))
	_patch.material_override = _material
	add_child(_patch)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0, -0.35)
	_light.light_color = Color(0.20, 0.36, 1.0)
	_light.omni_range = 3.0
	_light.shadow_enabled = true
	add_child(_light)
	visible = false


## The environmental signal must invite a glance, not require one to start.
## The controller separately grants the first-view grace when actually seen.
func update_cue(dt: float, eligible: bool, held: bool) -> bool:
	if held:
		return false
	if not eligible:
		visible = false
		active = false
		_light.light_energy = 0.0
		return false
	cooldown = maxf(0.0, cooldown - dt)
	var started := false
	if not active and cooldown <= 0.0:
		active = true
		elapsed = 0.0
		pulses += 1
		started = true
	if active:
		elapsed += dt
		if elapsed >= DURATION:
			active = false
			cooldown = REPEAT_GAP
	# A player turning between pulses should still find something wrong.
	visible = true
	var amount := clampf(elapsed / DURATION, 0.0, 1.0)
	var comfort := 0.45 if GameSettings.flashing_reduced() else 1.0
	_material.set_shader_parameter("progress", amount)
	_material.set_shader_parameter("strength", comfort)
	_light.light_energy = (0.12 + (sin(amount * PI) * 0.65 if active else 0.0)) * comfort
	return started


func finish() -> void:
	active = false
	visible = false
	_light.light_energy = 0.0
