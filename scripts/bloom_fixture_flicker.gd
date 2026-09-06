class_name BloomFixtureFlicker
extends Node
## One ballast drives every visible tube and fixture-mounted spotlight in a
## Bloom cell. Keeping this as a controller (rather than a hidden OmniLight3D)
## lets the illumination originate at the authored ceiling hardware.

var lights: Array[Light3D] = []
var base_energies := PackedFloat32Array()
var mats: Array[StandardMaterial3D] = []
var rng_seed := 0
var buzz: AudioStreamPlayer3D

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _target := 1.0


func _ready() -> void:
	_rng.seed = rng_seed
	if base_energies.size() != lights.size():
		base_energies.resize(lights.size())
		for i in lights.size():
			base_energies[i] = lights[i].light_energy


func _process(dt: float) -> void:
	if GameSettings.flashing_reduced():
		_target = 1.0
		for i in lights.size():
			if is_instance_valid(lights[i]):
				lights[i].light_energy = base_energies[i]
		for mat in mats:
			if is_instance_valid(mat):
				mat.emission_energy_multiplier = 2.7
		if buzz != null:
			buzz.volume_db = -26.0
		return
	_t -= dt
	if _t <= 0.0:
		if _rng.randf() < 0.75:
			_target = 1.0
			_t = _rng.randf_range(0.3, 2.5)
		else:
			_target = _rng.randf_range(0.0, 0.35)
			_t = _rng.randf_range(0.03, 0.15)
	for i in lights.size():
		if is_instance_valid(lights[i]):
			var light_target := lerpf(lights[i].light_energy,
				base_energies[i] * _target, minf(1.0, dt * 30.0))
			if lights[i].light_energy != light_target:
				lights[i].light_energy = light_target
	var emission_energy := 2.7 * clampf(_target, 0.12, 1.0)
	for mat in mats:
		if is_instance_valid(mat):
			if mat.emission_energy_multiplier != emission_energy:
				mat.emission_energy_multiplier = emission_energy
	if buzz != null:
		var buzz_volume := lerpf(-13.0, -26.0, clampf(_target, 0.0, 1.0))
		if buzz.volume_db != buzz_volume:
			buzz.volume_db = buzz_volume
