extends Node3D
## A light float keeps a stable physics hull while its vinyl rides the small
## surface swell and reacts to the player's travelling water disturbances.

const WAVE_DIR_A := Vector2(0.939693, 0.342020)
const WAVE_DIR_B := Vector2(-0.422618, 0.906308)

var _body: RigidBody3D
var _water_fx
var _wake_height := 0.0
var _wake_roll := Vector2.ZERO
var _phase := 0.0
var _water_retry := 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	_phase = fmod(absf(global_position.x * 0.73 + global_position.z * 0.41), TAU)


func _physics_process(dt: float) -> void:
	if _body != null:
		var travel := Vector2(_body.linear_velocity.x, _body.linear_velocity.z)
		if travel.length() > 2.2:
			travel = travel.limit_length(2.2)
			_body.linear_velocity.x = travel.x
			_body.linear_velocity.z = travel.y
	if not is_instance_valid(_water_fx):
		_water_retry -= dt
		if _water_retry <= 0.0:
			_water_fx = get_tree().get_first_node_in_group("pool_water_interaction")
			_water_retry = 0.25
	_wake_height = 0.0
	_wake_roll = Vector2.ZERO
	if _water_fx == null or _body == null:
		return
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	var surface_y := _body.global_position.y
	for event in _water_fx.events:
		var at: Vector3 = event["at"]
		if absf(at.y - surface_y) > 0.25:
			continue
		var age: float = _water_fx.clock - float(event["born"])
		if age < 0.0 or age > 2.8:
			continue
		var delta := here - Vector2(at.x, at.z)
		var distance := delta.length()
		if distance < 0.04 or distance > 3.2:
			continue
		var ring := distance - (0.24 + age * 0.9)
		var width := 0.22 + age * 0.12
		var packet := exp(-ring * ring / (width * width))
		var fade := smoothstep(0.0, 0.065, age) \
			* (1.0 - smoothstep(1.5, 2.8, age)) / (1.0 + age * 1.9)
		var strength: float = float(event["strength"]) * packet * fade
		var outward := delta / distance
		_wake_height += sin(ring * 17.0) * strength * 0.065
		_wake_roll += outward * strength * 0.11
		_body.apply_central_force(Vector3(outward.x, 0.0, outward.y) * strength * 2.0)
	_wake_height = clampf(_wake_height, -0.075, 0.075)
	_wake_roll = _wake_roll.limit_length(0.10)


func _process(dt: float) -> void:
	if _body == null:
		return
	var here := Vector2(_body.global_position.x, _body.global_position.z)
	var t := Time.get_ticks_msec() * 0.001
	# Match the water shader's two world-space wave trains.
	var wave_a := TAU * (here.dot(WAVE_DIR_A) / 2.6 - t * 0.58)
	var wave_b := TAU * (here.dot(WAVE_DIR_B) / 1.7 - t * 0.47) + 1.83
	var target_y := (sin(wave_a) * 0.55 + sin(wave_b) * 0.45) * 0.024 \
		+ _wake_height
	var motion := Vector2(_body.linear_velocity.x, _body.linear_velocity.z)
	var target_roll := Vector2(
		cos(wave_a + _phase) * 0.024 + _wake_roll.y - motion.y * 0.015,
		sin(wave_b + _phase) * 0.024 - _wake_roll.x + motion.x * 0.015)
	position.y = lerpf(position.y, target_y, minf(1.0, dt * 11.0))
	rotation.x = lerpf(rotation.x, target_roll.x, minf(1.0, dt * 9.0))
	rotation.z = lerpf(rotation.z, target_roll.y, minf(1.0, dt * 9.0))
	rotation.y = sin(t * 0.72 + _phase) * 0.015
