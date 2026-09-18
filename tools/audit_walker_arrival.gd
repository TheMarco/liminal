extends SceneTree
## Real 3D arrival: moving materialization, warning without a freeze, safe grace.
const Effect := preload("res://scripts/reality_aftershock.gd")
const Host := preload("res://tools/audit_reality_aftershock.gd").HostStub
const DT := 1.0 / 60.0
var failures: Array[String] = []

class Figure extends ShadowFigure:
	var catches := 0
	func _seize() -> void: catches += 1

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 30.0
	watchdog.timeout.connect(func(): quit(1))
	root.add_child(watchdog)
	watchdog.start()
	var world := Node3D.new()
	root.add_child(world)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 0.2, 24)
	shape.shape = box
	body.position = Vector3(6, -0.1, 6)
	body.add_child(shape)
	world.add_child(body)
	var player := Player.new()
	player.position = Vector3(10, 0, 6)
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.flashlight.visible = false
	var host := Host.new()
	world.add_child(host)
	var effect := Effect.new()
	effect.host = host
	world.add_child(effect)
	effect.set_process(false)
	ShadowWalkerVisual.request_model(0)
	while not ShadowWalkerVisual.is_model_ready(0): await process_frame
	await physics_frame
	var figure := Figure.new()
	figure.player = player
	figure.use_walker_prototype = true
	figure.grace = 3.0
	figure.position = Vector3(2, 0, 6)
	world.add_child(figure)
	figure.set_physics_process(false)
	figure.approach_starting.connect(effect.before_approach)
	var visual := figure._walker
	visual._transition.kill()
	visual.set_manifestation(0.0)
	player.cam.look_at(figure.global_position + Vector3.UP * 1.4)
	check(visual.forward_world().dot(Vector3.RIGHT) > 0.999, "new monster faces away from target")
	check(not visual._presentation.visible and not figure._wisps.visible,
		"arrival starts fully visible")
	check(is_zero_approx(figure._wisps.preprocess), "arrival fast-forwards GPU particles")
	check(figure._wisps.process_material == ShadowFigure.prewarm_presence(true).process,
		"arrival rebuilt immutable particle resources")
	var start := figure.position
	figure._physics_process(DT)
	check(figure.position.distance_to(start) > 0.0001 and figure.ground_velocity.length() > 0.0,
		"monster stood still on its first movement tick")
	check(figure.grace > 2.9 and figure._approach_hold == 0.0 and effect.pulse_count == 1,
		"moving arrival lost contact grace or warning still freezes it")
	var phase := visual.animation_player().current_animation_position
	for frame in 48:
		visual.set_manifestation(float(frame + 1) / 48.0)
		effect._process(DT)
		figure._physics_process(DT)
	check(figure.position.distance_to(start) > 0.45, "materializing monster did not keep walking")
	check(visual.animation_player().current_animation_position != phase,
		"materializing monster did not animate its steps")
	check(effect.pulse_count == 1, "arrival repeated its warning")
	figure.suppressed = true
	start = figure.position
	figure._physics_process(DT)
	check(figure.position == start, "moving arrival ignores modal suppression")
	figure.suppressed = false
	player.flashlight.visible = true
	figure._physics_process(0.1)
	check(figure._burn > 0.0, "arrival grace makes the monster immune to the torch")
	player.flashlight.visible = false
	figure.position = player.position - Vector3.RIGHT * 0.9
	figure.grace = 0.5
	visual.set_manifestation(0.3)
	figure._physics_process(DT)
	check(figure.catches == 0, "incomplete arrival can catch the player")
	figure.grace = 0.0
	visual.set_manifestation(1.0)
	figure._physics_process(DT)
	check(figure.catches == 1, "completed arrival cannot catch the player")
	world.free()
	watchdog.stop()
	watchdog.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("WALKER ARRIVAL: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
