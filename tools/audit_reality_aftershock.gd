extends SceneTree
## Headless contracts for automatic perception beats and debug-only controls.

const RealityAftershock = preload("res://scripts/reality_aftershock.gd")

class RunStub:
	var ended := false
	var blackout := false
	var watching := false
	var suspended := false

class HostStub extends Node:
	var _switching := false
	var _dying := false
	var _quitting := false
	var _descent_preparing := false
	var _title = null
	var _descent_summary = null
	var _descent_intro = null
	var _photo_album = null
	var _return_prompt = null
	var _quit_prompt = null
	var run = RunStub.new()
	var _realm_visit = null
	var _photo_camera = null
	func _show_event_message(_message: String) -> void: pass

class CameraStub extends Node:
	var _raised := false
	var _capturing := false
	var _review_left := 0.0
	var run = RunStub.new()

class RealmStub:
	var away := false
	var allow := false
	func is_away() -> bool: return away
	func allows_perception_effect() -> bool: return allow

class AnomalyStub extends PhotoAnomaly:
	var resolves := 0
	func resolve(_restoring := false) -> void: resolves += 1

var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var options := CliOptions.parse_args(PackedStringArray(["liminal"]))
	expect(not options.reality_aftershock, "debug aftershock keys enabled by default")
	options = CliOptions.parse_args(PackedStringArray(["liminal", "--reality-aftershock"]))
	expect(options.reality_aftershock, "aftershock flag was not parsed")
	var effect := RealityAftershock.new()
	var host := HostStub.new()
	root.add_child(host)
	effect.host = host
	root.add_child(effect)
	effect.set_process(false)
	expect(is_zero_approx(RealityAftershock.envelope(0.0)), "envelope starts nonzero")
	expect(RealityAftershock.envelope(0.65) > 0.0, "envelope attack missing")
	expect(RealityAftershock.envelope(1.65) > RealityAftershock.envelope(5.49), "envelope release missing")
	expect(is_zero_approx(RealityAftershock.envelope(5.5)), "envelope does not end at zero")
	for i in range(-20, 650):
		var value := RealityAftershock.envelope(i * 0.01)
		expect(is_finite(value) and value >= 0.0 and value <= 1.0, "invalid envelope strength")
	effect.trigger()
	effect.elapsed = 0.8
	effect._process(0.0)
	expect(effect.pulse_count == 1 and effect.visible, "trigger did not start visible pulse")
	effect.trigger()
	expect(effect.pulse_count == 1, "trigger stacked pulses")
	var active_elapsed := effect.elapsed
	paused = true
	effect._process(1.0)
	expect(is_equal_approx(effect.elapsed, active_elapsed) and not effect.visible, "pause did not freeze/hide effect")
	paused = false
	effect.cancel()
	for field in ["_switching", "_dying", "_quitting", "_descent_preparing"]:
		host.set(field, true); effect.cancel(); effect.trigger()
		expect(effect.pulse_count == 1, "%s gate allowed trigger" % field)
		host.set(field, false)
	for field in ["ended", "blackout", "watching", "suspended"]:
		host.run.set(field, true); effect.cancel(); effect.trigger()
		expect(effect.pulse_count == 1, "run %s gate allowed trigger" % field)
		host.run.set(field, false)
	host._photo_camera = CameraStub.new()
	for field in ["_raised", "_capturing"]:
		host._photo_camera.set(field, true); effect.cancel(); effect.trigger()
		expect(effect.pulse_count == 1, "camera %s gate allowed trigger" % field)
		host._photo_camera.set(field, false)
	host._photo_camera._review_left = 1.0; effect.cancel(); effect.trigger()
	expect(effect.pulse_count == 1, "camera review gate allowed trigger")
	host._photo_camera.free()
	host._photo_camera = null
	for field in ["_title", "_descent_summary", "_descent_intro", "_photo_album", "_return_prompt", "_quit_prompt"]:
		host.set(field, Node.new()); effect.cancel(); effect.trigger()
		expect(effect.pulse_count == 1, "%s modal allowed trigger" % field)
		host.get(field).free()
		host.set(field, null)
	host._realm_visit = RealmStub.new(); host._realm_visit.away = true; effect.cancel(); effect.trigger()
	expect(effect.pulse_count == 1, "realm gate allowed trigger")
	host._realm_visit.allow = true
	host._photo_camera = CameraStub.new()
	host.run.suspended = true
	expect(effect.presentation_allowed(), "live realm incorrectly uses suspended source run")
	host._photo_camera.run.suspended = true
	expect(not effect.presentation_allowed(), "realm modal hold allowed presentation")
	host._photo_camera.free()
	host._photo_camera = null
	host.run.suspended = false
	host._realm_visit = null
	effect.cancel()
	expect(effect.elapsed == RealityAftershock.DURATION, "cancel did not clear pulse")
	var previous_settings := GameSettings.current
	GameSettings.current = GameSettings.new("/tmp/aftershock-audit-nonexistent-%d.cfg" % OS.get_process_id())
	effect.elapsed = 0.8
	effect._process(0.0)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), 1.0), "full peak differs")
	GameSettings.current.set_value("reduced_flashing", true)
	GameSettings.current.set_value("head_bob", 0.0)
	effect._process(0.0)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), 0.35), "comfort strength not reduced")
	expect(is_zero_approx(float(effect._material.get_shader_parameter("motion_scale"))), "motion-off still warps")
	GameSettings.current = previous_settings
	effect._process(10.0)
	expect(not effect.visible and effect.elapsed == RealityAftershock.DURATION, "pulse fails to finish")
	# 50% faster means the entire authored animation runs at 1.5x, not just
	# a shorter fade or quicker lens motion with the old duration left behind.
	expect(is_equal_approx(RealityAftershock.PLAYBACK_SPEED, 1.5), "prototype playback rate differs")
	effect.trigger()
	effect._process(0.5)
	expect(is_equal_approx(effect.elapsed, 0.75), "envelope clock is not 50% faster")
	expect(is_equal_approx(float(effect._material.get_shader_parameter("phase")), 0.75), "shader phase did not accelerate with envelope")
	var real_duration := RealityAftershock.DURATION / RealityAftershock.PLAYBACK_SPEED
	effect._process(real_duration - 0.5 - 0.1)
	expect(effect.visible and effect.elapsed < RealityAftershock.DURATION, "faster pulse ends too early")
	effect._process(0.101)
	expect(not effect.visible and effect.elapsed == RealityAftershock.DURATION, "faster pulse overruns its 3.67-second duration")
	var ghost := ShadowFigure.new()
	var pulses := effect.pulse_count
	effect.before_approach(ghost)
	expect(effect.pulse_count == pulses + 1 and is_zero_approx(ghost._approach_hold),
		"pre-approach pulse did not start while walker remained in motion")
	effect._process(0.15)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), RealityAftershock.APPROACH_STRENGTH), "pre-approach strength differs")
	var second_ghost := ShadowFigure.new()
	var phase_before := effect.elapsed
	effect.before_approach(second_ghost)
	expect(effect.pulse_count == pulses + 1 and effect.elapsed == phase_before, "second ghost restarts/stacks pulse")
	expect(is_zero_approx(second_ghost._approach_hold),
		"second walker was frozen during the shared warning pulse")
	effect._process(1.11)
	expect(not effect.visible, "pre-approach effect failed to clear before movement")
	effect.trigger()
	effect._process(0.4)
	phase_before = effect.elapsed
	pulses = effect.pulse_count
	effect.before_approach(ghost)
	expect(effect.pulse_count == pulses and effect.elapsed == phase_before, "approach restarted active photo pulse")
	effect._process(1.26)
	expect(not effect.visible, "approach did not shorten existing photo pulse")
	effect.enabled = false
	second_ghost._approach_hold = 0.0
	effect.before_approach(second_ghost)
	expect(second_ghost._approach_hold == 0.0, "disabled effect freezes ghost invisibly")
	effect.enabled = true
	var debug_key := InputEventKey.new()
	debug_key.physical_keycode = KEY_F8
	debug_key.pressed = true
	effect._unhandled_input(debug_key)
	expect(effect.pulse_count == pulses, "normal play accepts preview key")
	effect.debug_controls = true
	effect._unhandled_input(debug_key)
	expect(effect.pulse_count == pulses + 1, "debug preview flag no longer works")
	# Architecture shares the pass at half warning strength; it cannot amplify
	# or retime either existing pulse, and its visibility fade reaches zero.
	effect.cancel()
	var architecture := {"weight": 1.0}
	effect.architecture_weight = func() -> float: return architecture.weight
	var settings_before_architecture := GameSettings.current
	GameSettings.current = GameSettings.new("/tmp/architecture-aftershock-audit-%d.cfg" % OS.get_process_id())
	effect._process(0.5)
	expect(effect.visible and is_equal_approx(float(effect._material.get_shader_parameter("strength")), RealityAftershock.APPROACH_STRENGTH * 0.25), "architecture is not at its reduced strength")
	architecture.weight = 0.5
	effect._process(0.1)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), 0.0875), "architecture visibility fade ignored")
	architecture.weight = 1.0
	effect.trigger()
	effect._process(0.5)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), 1.0), "architecture stacks with photo pulse")
	expect(is_equal_approx(float(effect._material.get_shader_parameter("phase")), 0.75), "architecture retimes photo pulse")
	effect.cancel()
	effect.before_approach(ghost)
	effect._process(0.15)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), RealityAftershock.APPROACH_STRENGTH), "architecture changes enemy warning")
	effect.cancel()
	GameSettings.current.set_value("reduced_flashing", true)
	effect._process(0.1)
	expect(is_equal_approx(float(effect._material.get_shader_parameter("strength")), 0.175 * 0.35), "architecture ignores comfort strength")
	architecture.weight = 0.0
	effect._process(0.1)
	expect(not effect.visible, "architecture remains visible without a source")
	GameSettings.current = settings_before_architecture
	ghost.free()
	second_ghost.free()
	_audit_photo_signal()
	var post := PostProcessController.new()
	host.add_child(post)
	post.setup(host, true, true)
	post.ensure_scene_copy()
	var copy := post._scene_copy
	post.ensure_scene_copy()
	expect(post._scene_copy == copy and copy.get_index() < post._overlay.get_index(), "post-copy duplicated or ordered after overlay")
	post.set_enabled(false)
	expect(not copy.visible, "disabled post-copy still active")
	post.set_enabled(true)
	expect(copy.visible, "enabled post-copy missing")
	effect.free(); host.free()
	if failures.is_empty():
		print("reality aftershock audit: PASS")
		quit(0)
	else:
		for failure in failures: print("FAIL — " + failure)
		quit(1)

func _audit_photo_signal() -> void:
	var camera := PhotoCamera.new()
	# The release/transition contract needs UI nodes, not a live gameplay scene.
	camera._review_back = ColorRect.new()
	camera._paper = PhotoCamera.PhotoPaper.new()
	camera._photo = TextureRect.new()
	camera._marks = PhotoCamera.EvidenceMarks.new()
	for control in [camera._review_back, camera._paper, camera._photo, camera._marks]:
		camera.add_child(control)
	var counts := {"signal": 0, "callback": 0}
	camera.unnatural_photographed.connect(func(): counts["signal"] += 1)
	var callback := func(): counts["callback"] += 1
	var anomaly := AnomalyStub.new()
	camera._review_callbacks.append(callback)
	camera._review_resolves.append(anomaly)
	camera._pending_unnatural_photo = true
	camera._release_review_resolutions()
	expect(counts["signal"] == 1 and counts["callback"] == 1 and anomaly.resolves == 1, "mutation batch not released exactly once")
	camera._release_review_resolutions()
	expect(counts["signal"] == 1 and anomaly.resolves == 1, "empty release retriggers aftershock")
	# Writing/static anomalies have no delayed world-change callbacks, but
	# successfully documenting one still owns an after-photo perception beat.
	camera._pending_unnatural_photo = true
	camera._release_review_resolutions()
	expect(counts["signal"] == 2, "static unnatural subject/writing missed aftershock")
	camera._review_callbacks.append(callback)
	camera._review_resolves.append(anomaly)
	camera._pending_unnatural_photo = true
	camera.finish_for_transition()
	expect(counts["signal"] == 2 and counts["callback"] == 2 and anomaly.resolves == 2, "transition emitted aftershock or lost mutation")
	camera._release_review_resolutions()
	expect(counts["signal"] == 2, "cancelled photo escaped into next floor")
	anomaly.free()
	camera.free()
