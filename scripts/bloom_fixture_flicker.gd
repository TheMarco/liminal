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
var _settled_target := -1.0
var _settled_reduced := false


func _ready() -> void:
	_rng.seed = rng_seed
	if base_energies.size() != lights.size():
		base_energies.resize(lights.size())
		for i in lights.size():
			base_energies[i] = lights[i].light_energy


func _process(dt: float) -> void:
	var reduced := GameSettings.flashing_reduced()
	if reduced:
		_target = 1.0
	else:
		_t -= dt
		if _t <= 0.0:
			if _rng.randf() < 0.75:
				_target = 1.0
				_t = _rng.randf_range(0.3, 2.5)
			else:
				_target = _rng.randf_range(0.0, 0.35)
				_t = _rng.randf_range(0.03, 0.15)
	if buzz != null:
		var buzz_volume := lerpf(-13.0, -26.0, _target)
		if not is_equal_approx(buzz.volume_db, buzz_volume):
			buzz.volume_db = buzz_volume
	# The room owns its light channels and lens materials until power returns.
	var room := get_parent() as Chunk
	if room != null and room._blackout:
		_settled_target = -1.0
		return
	# A ballast usually holds one brightness for many frames between dropouts.
	if _settled_target == _target and _settled_reduced == reduced:
		return
	var settled := true
	var blend := minf(1.0, dt * 30.0)
	for i in lights.size():
		if not is_instance_valid(lights[i]):
			continue
		var light := lights[i]
		var current := light.light_energy
		var desired := base_energies[i] * _target
		if reduced:
			# The authored energies are already stored at the light's precision.
			if current != desired:
				light.light_energy = desired
		elif not is_equal_approx(current, desired):
			var energy := lerpf(current, desired, blend)
			if is_equal_approx(energy, desired):
				energy = desired
			else:
				settled = false
			light.light_energy = energy
	var emission_energy := 2.7 * clampf(_target, 0.12, 1.0)
	for mat in mats:
		if is_instance_valid(mat) and not is_equal_approx(mat.emission_energy_multiplier, emission_energy):
			mat.emission_energy_multiplier = emission_energy
	_settled_target = _target if settled else -1.0
	_settled_reduced = reduced
