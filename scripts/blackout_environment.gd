extends RefCounted
## A world-local power overlay, not a screen fade. The torch keeps its normal
## exposure and direct lighting; residual daylight/GI/fog cannot light the room.
## Retain the Environment itself so a floor change never restores into another
## floor's resource. Repeated apply/restore calls are safe.
const OFF := {
	"ambient_light_energy": 0.002,
	"sdfgi_energy": 0.0,
	"fog_light_energy": 0.002,
	"background_color": Color(0.0005, 0.0007, 0.001),
	"background_energy_multiplier": 0.0,
	"volumetric_fog_emission": Color.BLACK,
	"volumetric_fog_gi_inject": 0.0,
}
var _environment: Environment
var _before := {}

func apply(environment: Environment) -> void:
	if environment == _environment:
		return
	restore()
	if environment == null:
		return
	_environment = environment
	for key in OFF:
		_before[key] = environment.get(key)
		environment.set(key, OFF[key])

func restore() -> void:
	if is_instance_valid(_environment):
		for key in _before:
			_environment.set(key, _before[key])
	_before.clear()
	_environment = null
