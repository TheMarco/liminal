class_name FlickerLight
extends OmniLight3D
## Fluorescent-tube style flicker: mostly steady, with short random dropouts.
## Also drives the emission of its ceiling panel material(s) so the fixture
## visually dies with the light.

var base_energy := 1.2
var mats: Array = []
var rng_seed := 0
var buzz: AudioStreamPlayer3D

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _target := 1.0


func _ready() -> void:
	_rng.seed = rng_seed


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		if _rng.randf() < 0.75:
			_target = 1.0
			_t = _rng.randf_range(0.3, 2.5)
		else:
			_target = _rng.randf_range(0.0, 0.35)
			_t = _rng.randf_range(0.03, 0.15)
	light_energy = lerpf(light_energy, base_energy * _target, minf(1.0, dt * 30.0))
	var e := 2.6 * clampf(_target, 0.12, 1.0)
	for m in mats:
		m.emission_energy_multiplier = e
	# ballast arcs louder while the tube is dropping out
	if buzz != null:
		buzz.volume_db = lerpf(-13.0, -26.0, clampf(_target, 0.0, 1.0))
