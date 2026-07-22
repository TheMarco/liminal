class_name Beacon
extends OmniLight3D
## Aircraft anti-collision beacon: a short red flash on a slow cycle, driving
## both the light and the lamp mesh's emission so the flash reads on the hull.

var mat: StandardMaterial3D
var phase := 0.0
var _t := 0.0


func _process(dt: float) -> void:
	_t += dt
	if _t > 1000.0:
		_t -= 1000.0
	var on := fmod(_t + phase, 1.4) < 0.12
	light_energy = 0.9 if on else 0.0
	if mat != null:
		mat.emission_energy_multiplier = 6.0 if on else 0.15
