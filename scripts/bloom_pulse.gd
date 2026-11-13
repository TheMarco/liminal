class_name BloomPulse
extends Node3D
## Slow organic scale change for the Bloom's hearts and incubator sacs. Geometry
## does not deform in the material shader, so silhouettes and collision remain
## stable; only deliberately non-colliding set pieces receive this node.

@export var rate := 1.75
@export var amplitude := 0.055
@export var phase := 0.0

var _base_scale := Vector3.ONE
var _time := 0.0


func _ready() -> void:
	_base_scale = scale
	_freeze_shadows.call_deferred()


## A shadow caster that changes scale every frame forces every fixture light in
## range to re-render its shadow map every frame. The beat is a few percent:
## cast the shadow from a still twin and let only the visible mesh breathe.
func _freeze_shadows() -> void:
	var host := get_parent() as Node3D
	if host == null or not is_inside_tree():
		return
	for found in find_children("*", "MeshInstance3D", true, false):
		var source := found as MeshInstance3D
		if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or source.mesh == null or source.skin != null:
			continue
		var twin := MeshInstance3D.new()
		twin.name = "StillShadow"
		twin.mesh = source.mesh
		twin.material_override = source.material_override
		twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		twin.layers = source.layers
		twin.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		host.add_child(twin)
		twin.global_transform = source.global_transform
		source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A removed or resolved set piece must not leave its shadow behind.
		source.tree_exiting.connect(twin.queue_free)


func _process(delta: float) -> void:
	_time += delta
	var beat := sin(_time * rate + phase)
	beat += maxf(0.0, sin(_time * rate * 2.0 + phase + 0.65)) * 0.32
	scale = _base_scale * (1.0 + beat * amplitude)

