extends SceneTree

const MotionType = preload("res://scripts/handheld_camera_motion.gd")
var failures: Array[String] = []


func _init() -> void:
	var motion = MotionType.new()
	motion.enabled = false
	var off: Dictionary = motion.advance(1.0 / 60.0)
	check(off.position == Vector3.ZERO and off.rotation == Vector3.ZERO,
		"disabled motion was not exactly zero")

	motion.enabled = true
	motion.strength = 0.0
	var zero: Dictionary = motion.advance(1.0 / 60.0)
	check(zero.position == Vector3.ZERO and zero.rotation == Vector3.ZERO,
		"zero strength was not exactly zero")

	motion.strength = MotionType.DEFAULT_STRENGTH
	var calm_peak := 0.0
	for i in 120:
		var sample: Dictionary = motion.advance(1.0 / 60.0)
		calm_peak = maxf(calm_peak, (sample.position as Vector3).length()
			+ (sample.rotation as Vector3).length())
	check(calm_peak > 0.0001, "enabled camera had no calm handheld drift")
	motion.strength = 1.0
	var full_strength_peak := 0.0
	var idle_vertical_peak := 0.0
	var idle_pitch_peak := 0.0
	var idle_roll_peak := 0.0
	for i in 600:
		var sample: Dictionary = motion.advance(1.0 / 60.0)
		var position := sample.position as Vector3
		var rotation := sample.rotation as Vector3
		full_strength_peak = maxf(full_strength_peak,
			position.length() + rotation.length())
		idle_vertical_peak = maxf(idle_vertical_peak, absf(position.y))
		idle_pitch_peak = maxf(idle_pitch_peak, absf(rotation.x))
		idle_roll_peak = maxf(idle_roll_peak, absf(rotation.z))
	check(full_strength_peak > 0.025,
		"maximum strength remained visually imperceptible")
	check(idle_vertical_peak > 0.045,
		"idle handheld motion has no visible breathing bob")
	check(idle_pitch_peak > idle_roll_peak * 1.5,
		"idle roll still dominates the pitch/nod motion")
	motion.activity = 1.0
	var run_peak := 0.0
	for i in 120:
		var sample: Dictionary = motion.advance(1.0 / 60.0)
		run_peak = maxf(run_peak, (sample.position as Vector3).length()
			+ (sample.rotation as Vector3).length())
	check(run_peak > calm_peak * 1.25,
		"sprinting did not intensify handheld motion")
	motion.activity = 0.0
	for i in 30:
		motion.advance(1.0 / 60.0)

	motion.trigger_scare(1.0, 0.12, 1.0)
	var scare_peak := 0.0
	for i in 24:
		var sample: Dictionary = motion.advance(1.0 / 60.0)
		scare_peak = maxf(scare_peak, (sample.position as Vector3).length()
			+ (sample.rotation as Vector3).length())
	check(scare_peak > calm_peak * 1.8,
		"scare did not materially intensify handheld motion")
	check(motion.fear_level() > 0.0, "scare envelope never rose")
	for i in 180:
		motion.advance(1.0 / 60.0)
	check(is_zero_approx(motion.fear_level()),
		"scare envelope did not decay back to calm")

	motion.reset()
	motion.strength = 1.0
	motion.note_look_delta(0.42, -0.28)
	var look_rotation_peak := 0.0
	var look_position_peak := 0.0
	for i in 60:
		motion.advance(1.0 / 60.0)
		look_rotation_peak = maxf(look_rotation_peak,
			motion._look_rotation.length())
		look_position_peak = maxf(look_position_peak,
			motion._look_position.length())
	check(look_rotation_peak > 0.01,
		"sudden look produced no rotational follow-through")
	check(look_position_peak > 0.001,
		"sudden look produced no handheld position response")
	check(look_rotation_peak <= MotionType.LOOK_ROTATION_LIMIT + 0.0001,
		"look follow-through exceeded its comfort cap")
	for i in 300:
		motion.advance(1.0 / 60.0)
	check(motion._look_rotation.length() < 0.0005
		and motion._look_position.length() < 0.0005,
		"look follow-through did not settle")

	motion.trigger_scare(0.8)
	motion.enabled = false
	motion.advance(1.0 / 60.0)
	check(is_zero_approx(motion.fear_level()),
		"disabling camera did not clear the fear envelope")

	if failures.is_empty():
		print("HANDHELD_CAMERA AUDIT PASS")
	else:
		for failure in failures:
			push_error("HANDHELD_CAMERA AUDIT FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
