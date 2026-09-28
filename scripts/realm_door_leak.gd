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
var _doorway_outline := false


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
	_light.position = Vector3.ZERO
	_light.light_color = Color(0.20, 0.36, 1.0)
	_light.omni_range = 3.0
	_light.shadow_enabled = true
	_light.set_meta("visible_source", "realm_leak_patch")
	add_child(_light)
	visible = false


## Keep the same data-glyph/light cue around an open doorway without painting
## over the live view in its centre. The ordinary sealed-wall leak is unchanged.
func configure_doorway_outline(centre: Vector3, forward: Vector3,
		world_seed: int, opening: Vector2) -> void:
	configure(centre, forward, world_seed)
	_doorway_outline = true
	global_position = centre - forward * 0.16 + Vector3.UP * opening.y * 0.5
	# Keep the effect close to the threshold. A wide patch reads as a rectangular
	# projection screen on the wall rather than light escaping from the gap.
	var patch_size := opening + Vector2(0.5, 0.5)
	(_patch.mesh as QuadMesh).size = patch_size
	_material.set_shader_parameter("patch_size", patch_size)
	_material.set_shader_parameter("opening_size", opening)
	_light.omni_range = 3.0
	_light.shadow_enabled = false


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
	_light.light_energy = ((0.24 if _doorway_outline else 0.12)
		+ (sin(amount * PI) * (0.48 if _doorway_outline else 0.65)
			if active else 0.0)) * comfort
	return started


func finish() -> void:
	active = false
	visible = false
	_light.light_energy = 0.0
