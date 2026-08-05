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


func _process(delta: float) -> void:
	_time += delta
	var beat := sin(_time * rate + phase)
	beat += maxf(0.0, sin(_time * rate * 2.0 + phase + 0.65)) * 0.32
	scale = _base_scale * (1.0 + beat * amplitude)

