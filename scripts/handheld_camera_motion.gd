class_name HandheldCameraMotion
extends RefCounted
## Smooth, deterministic found-footage camera motion.
##
## The calm layer is always subtle: a camera operator's breathing, grip and
## weight shifting rather than gameplay recoil. Scary events add a short fear
## envelope with faster movement. Both layers use continuous waves so a high
## refresh rate never turns the effect into random one-pixel jitter.

const DEFAULT_STRENGTH := 0.55
const LOOK_ROTATION_LIMIT := 0.075
const LOOK_ROTATION_SPEED_LIMIT := 1.8
const LOOK_POSITION_LIMIT := 0.035
const LOOK_POSITION_SPEED_LIMIT := 0.45

var enabled := true
var strength := DEFAULT_STRENGTH
## Continuous locomotion supplied by the player controller: 0 while standing,
## roughly 0.55 at a normal walk and 1 at a full sprint.
var activity := 0.0

var _clock := 0.0
var _gait_clock := 0.0
var _activity_blend := 0.0
var _fear := 0.0
var _fear_target := 0.0
var _fear_hold_left := 0.0
var _fear_release_rate := 1.0
var _look_rotation := Vector3.ZERO
var _look_rotation_velocity := Vector3.ZERO
var _look_position := Vector3.ZERO
var _look_position_velocity := Vector3.ZERO


## Add or reinforce a fear pulse. `amount` is normalized; the hold gives the
## attack time to land and release_seconds controls the return to calm drift.
func trigger_scare(amount: float = 1.0, hold_seconds: float = 0.10,
		release_seconds: float = 1.6) -> void:
	if not enabled or strength <= 0.0 or not is_finite(amount):
		return
	var next := clampf(amount, 0.0, 1.0)
	if next <= 0.0:
		return
	var replaces_peak := next >= maxf(_fear_target, _fear)
	_fear = maxf(_fear, next * 0.18)
	_fear_target = maxf(_fear_target, next)
	_fear_hold_left = maxf(_fear_hold_left, maxf(0.0, hold_seconds))
	var next_release := next / maxf(0.1, release_seconds)
	if replaces_peak or _fear_release_rate <= 0.0:
		_fear_release_rate = next_release
	else:
		# A smaller follow-up may prolong a scare, but may not abruptly cut short
		# the stronger envelope already in flight.
		_fear_release_rate = minf(_fear_release_rate, next_release)


## Feed the real, already-applied mouse-look delta into a secondary camera-body
## spring. Aim moves immediately in Player; this layer only supplies the small
## counter-motion, turn-in roll and settling overshoot of a camera with mass.
func note_look_delta(yaw_delta: float, pitch_delta: float) -> void:
	if not enabled or strength <= 0.0 \
			or not is_finite(yaw_delta) or not is_finite(pitch_delta):
		return
	var magnitude := Vector2(yaw_delta, pitch_delta).length()
	if magnitude <= 0.0001:
		return
	# Slow framing corrections barely disturb the operator. A fast pan or tilt
	# transfers most of its angular impulse into the handheld spring.
	var response := lerpf(0.18, 1.0,
		smoothstep(0.008, 0.12, minf(magnitude, 0.12)))
	_look_rotation_velocity += Vector3(
		-pitch_delta * 2.0,
		-yaw_delta * 1.6,
		yaw_delta * 1.2) * response
	_look_position_velocity += Vector3(
		-yaw_delta * 0.32,
		pitch_delta * 0.30,
		0.0) * response
	_look_rotation_velocity = _look_rotation_velocity.limit_length(
		LOOK_ROTATION_SPEED_LIMIT)
	_look_position_velocity = _look_position_velocity.limit_length(
		LOOK_POSITION_SPEED_LIMIT)


## Return local-space position and Euler rotation offsets for this frame.
func advance(dt: float) -> Dictionary:
	var step := clampf(dt, 0.0, 0.1)
	_clock += step
	if not enabled or strength <= 0.0:
		reset()
		return _zero_sample()
	_advance_fear(step)
	_advance_look_spring(step)
	var activity_target := clampf(activity, 0.0, 1.0)
	_activity_blend = move_toward(_activity_blend, activity_target,
		step * (4.5 if activity_target > _activity_blend else 6.0))
	# Keep a continuous gait phase while letting cadence accelerate with speed.
	# Advancing a phase is important here: multiplying the whole elapsed clock
	# by a changing speed would visibly jump whenever the player accelerated.
	_gait_clock += step * lerpf(0.85, 1.25, _activity_blend)
	var gain := clampf(strength, 0.0, 1.0)
	var fear_gain := _fear * (0.35 + 0.65 * _fear)
	# The operator's slow body sway remains present while moving, but yields to
	# gait motion instead of stacking until sprinting becomes seasickening.
	var calm_mix := lerpf(1.0, 0.60, _activity_blend)
	return {
		"position": (_calm_position(_clock) * calm_mix
			+ _movement_position(_gait_clock) * _activity_blend
			+ _fear_position(_clock) * fear_gain
			+ _look_position) * gain,
		"rotation": (_calm_rotation(_clock) * calm_mix
			+ _movement_rotation(_gait_clock) * _activity_blend
			+ _fear_rotation(_clock) * fear_gain
			+ _look_rotation) * gain,
		"fear": _fear,
		"activity": _activity_blend,
	}


func reset_fear() -> void:
	_fear = 0.0
	_fear_target = 0.0
	_fear_hold_left = 0.0
	_fear_release_rate = 1.0


func reset() -> void:
	reset_fear()
	activity = 0.0
	_activity_blend = 0.0
	_look_rotation = Vector3.ZERO
	_look_rotation_velocity = Vector3.ZERO
	_look_position = Vector3.ZERO
	_look_position_velocity = Vector3.ZERO


func fear_level() -> float:
	return _fear


func _advance_fear(dt: float) -> void:
	if _fear_hold_left > 0.0:
		_fear_hold_left = maxf(0.0, _fear_hold_left - dt)
		# Quick but eased onset: enough snap to register the fright without a
		# discontinuous camera transform on the exact signal frame.
		_fear = lerpf(_fear, _fear_target, 1.0 - exp(-18.0 * dt))
		return
	_fear_target = 0.0
	_fear = move_toward(_fear, 0.0, _fear_release_rate * dt)


func _advance_look_spring(dt: float) -> void:
	if dt <= 0.0:
		return
	# Small substeps keep the under-damped follow-through stable through a frame
	# hitch without replacing it with a first-order ease that cannot overshoot.
	var count := maxi(1, ceili(dt * 120.0))
	var step := dt / float(count)
	for i in count:
		_look_rotation_velocity += (-_look_rotation * 62.0
			- _look_rotation_velocity * 11.5) * step
		_look_rotation += _look_rotation_velocity * step
		_look_position_velocity += (-_look_position * 70.0
			- _look_position_velocity * 14.0) * step
		_look_position += _look_position_velocity * step
		_look_rotation = _look_rotation.limit_length(LOOK_ROTATION_LIMIT)
		_look_position = _look_position.limit_length(LOOK_POSITION_LIMIT)
	if _look_rotation.length_squared() < 0.00000001 \
			and _look_rotation_velocity.length_squared() < 0.00000001:
		_look_rotation = Vector3.ZERO
		_look_rotation_velocity = Vector3.ZERO
	if _look_position.length_squared() < 0.00000001 \
			and _look_position_velocity.length_squared() < 0.00000001:
		_look_position = Vector3.ZERO
		_look_position_velocity = Vector3.ZERO


func _calm_position(t: float) -> Vector3:
	return Vector3(
		0.038 * sin(t * 0.83 + 0.20) + 0.013 * sin(t * 1.71 + 2.10),
		0.060 * sin(t * 1.03 + 1.20) + 0.015 * sin(t * 2.07 + 0.35),
		0.021 * sin(t * 0.59 + 2.75) + 0.008 * sin(t * 1.37 + 0.70))


func _calm_rotation(t: float) -> Vector3:
	return Vector3(
		0.045 * sin(t * 0.73 + 1.10) + 0.0120 * sin(t * 1.61 + 0.30),
		0.034 * sin(t * 0.57 + 2.40) + 0.0130 * sin(t * 1.43 + 1.20),
		0.014 * sin(t * 0.91 + 0.50) + 0.0060 * sin(t * 1.87 + 2.60))


func _fear_position(t: float) -> Vector3:
	return Vector3(
		0.040 * sin(t * 8.3 + 0.40) + 0.018 * sin(t * 12.7 + 2.10),
		0.055 * sin(t * 7.1 + 1.30) + 0.022 * sin(t * 15.1 + 0.20),
		0.030 * sin(t * 9.7 + 2.60) + 0.014 * sin(t * 13.9 + 0.80))


func _movement_position(t: float) -> Vector3:
	return Vector3(
		0.035 * sin(t * 6.0 + 0.60) + 0.010 * sin(t * 12.0 + 2.00),
		0.075 * sin(t * 11.8 + 1.40) + 0.020 * sin(t * 23.6 + 0.20),
		0.025 * sin(t * 11.8 + 2.70) + 0.008 * sin(t * 17.7 + 0.90))


func _movement_rotation(t: float) -> Vector3:
	return Vector3(
		0.050 * sin(t * 11.8 + 1.70) + 0.012 * sin(t * 23.6 + 1.90),
		0.028 * sin(t * 6.0 + 2.10) + 0.008 * sin(t * 12.0 + 0.50),
		0.026 * sin(t * 6.0 + 1.10) + 0.009 * sin(t * 12.0 + 2.70))


func _fear_rotation(t: float) -> Vector3:
	return Vector3(
		0.045 * sin(t * 7.9 + 0.10) + 0.020 * sin(t * 13.1 + 1.80),
		0.050 * sin(t * 8.7 + 2.20) + 0.022 * sin(t * 11.9 + 0.60),
		0.062 * sin(t * 7.3 + 1.00) + 0.025 * sin(t * 14.3 + 2.90))


func _zero_sample() -> Dictionary:
	return {"position": Vector3.ZERO, "rotation": Vector3.ZERO,
		"fear": 0.0, "activity": 0.0}
