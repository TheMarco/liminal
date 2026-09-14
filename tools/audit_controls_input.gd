extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func run() -> void:
	var player := Player.new()
	player._apply_mouse_look(Vector2(20, 30))
	var normal_pitch := player._pitch
	var normal_yaw := player.rotation.y
	player.rotation = Vector3.ZERO
	player._pitch = 0.0
	player.invert_y = true
	player._apply_mouse_look(Vector2(20, 30))
	check(is_equal_approx(player._pitch, -normal_pitch), "invert Y does not reverse pitch")
	check(is_equal_approx(player.rotation.y, normal_yaw), "invert Y changed yaw")
	player._apply_mouse_look(Vector2(0, 100000))
	check(is_equal_approx(player._pitch, 1.45), "inverted pitch escaped clamp")
	check(player._sprint_requested(true, true), "default hold sprint missing")
	check(not player._sprint_requested(true, false), "default sprint does not require holding Shift")
	player.toggle_sprint = true
	player._unhandled_input(key(KEY_SHIFT))
	check(player._sprint_requested(true, false), "tap does not latch sprint")
	player._unhandled_input(key(KEY_SHIFT, false))
	player._unhandled_input(key(KEY_SHIFT, true, true))
	check(player._sprint_requested(true, false), "key release or echo unlatches sprint")
	player._unhandled_input(key(KEY_SHIFT))
	check(not player._sprint_requested(true, false), "second tap does not stop sprint")
	player._unhandled_input(key(KEY_SHIFT))
	check(player._sprint_requested(true, false), "second sprint did not start")
	check(not player._sprint_requested(false, false), "stopping movement kept sprint active")
	check(not player._sprint_requested(true, false), "walking restarted sprint automatically")
	player._unhandled_input(key(KEY_SHIFT))
	player._stamina = 0.0
	check(not player._sprint_requested(true, false), "empty stamina allowed sprint")
	player._stamina = 5.0
	check(not player._sprint_requested(true, false), "stamina recovery restarted toggle")
	for reason in [Node.NOTIFICATION_PAUSED, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		player._unhandled_input(key(KEY_SHIFT))
		player.notification(reason)
		check(not player._sprint_requested(true, false), "pause/focus retained sprint")
	player._unhandled_input(key(KEY_SHIFT))
	player.toggle_sprint = false
	player.toggle_sprint = true
	check(not player._sprint_requested(true, false), "changing sprint mode retained latch")
	player._unhandled_input(key(KEY_SHIFT))
	player.reset_descent_resources()
	check(not player._sprint_requested(true, false), "retry retained sprint latch")
	var station := Node3D.new()
	player._flash_charge = 5.0
	check(player.start_charging(station), "charge fixture failed")
	player._focused = null
	player._unhandled_input(key(KEY_E))
	check(not player.is_charging(), "E did not disconnect when looking away")
	var other := Interactable.new()
	var uses: Array[bool] = []
	other.activated.connect(func(_actor: Node): uses.append(true))
	player._focused = other
	player.start_charging(station)
	player._unhandled_input(key(KEY_E))
	check(not player.is_charging() and uses.is_empty(), "disconnect also activated another object")
	player._unhandled_input(key(KEY_E))
	check(uses == [true], "normal E use regressed")
	player.start_charging(station)
	player._unhandled_input(key(KEY_F))
	check(not player.is_charging(), "F no longer disconnects")
	other.free()
	station.free()
	player.free()
	for failure in failures:
		push_error(failure)
	print("CONTROLS_INPUT_AUDIT: %d failures; inverted look, hold/toggle sprint, reset gates, charging" % failures.size())
	quit(0 if failures.is_empty() else 1)
