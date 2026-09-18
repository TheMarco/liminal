extends SceneTree
## Regression audit for the discovery hold that pauses only fresh figure arrivals.

var failures: Array[String] = []
var world: Node3D
var manager: ShadowFigures
var player: Player
var figure: ShadowFigure
var spawned := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func run_test() -> void:
	Engine.max_fps = 60
	var timeout: SceneTreeTimer = create_timer(15.0, true)
	timeout.timeout.connect(func():
		printerr("DISCOVERY SPAWN HOLD AUDIT TIMEOUT")
		quit(1))

	world = Node3D.new()
	root.add_child(world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = floor_box
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	player = Player.new()
	player.position = Vector3(10.0, 0.0, 6.0)
	player.set_physics_process(false)
	player.set_process(false)
	world.add_child(player)
	await physics_frame
	player.set_physics_process(false)
	player.set_process(false)
	player.flashlight.visible = true

	manager = ShadowFigures.new()
	manager.player = player
	manager.set_physics_process(false)
	world.add_child(manager)
	await physics_frame
	manager.set_physics_process(false)
	manager.player = player
	manager.spawned.connect(func(): spawned += 1)

	figure = ShadowFigure.new()
	figure.player = player
	figure.variant = ShadowFigure.DROWNED
	figure.position = Vector3(2.0, 0.0, 6.0)
	figure.set_physics_process(false)
	figure.set_process(false)
	manager.add_child(figure)
	await physics_frame
	figure.set_physics_process(false)
	figure.set_process(false)
	manager.adopt(figure)
	manager.suspended = false
	manager.passive = false
	manager._t = 2.0
	manager.force_encounter(0.8)
	manager._pending = 0.4
	manager._turn_cd = 3.0
	var forced_tries_before: int = manager._forced_tries
	var initial_position: Vector3 = figure.global_position
	var initial_t: float = manager._t
	var initial_forced_left: float = manager._forced_left
	var initial_pending: float = manager._pending
	manager.hold_new_spawns(4.5)
	var hold_before: float = manager._new_spawn_hold
	check(is_equal_approx(hold_before, 4.5), "hold duration was not recorded")
	check(not manager._try_spawn(), "_try_spawn bypassed the hold")
	check(not manager._turn_spawn(), "_turn_spawn bypassed the hold")
	check(not manager._forced_spawn(), "_forced_spawn bypassed the hold")
	check(not manager.try_realm_encounter(), "realm encounter bypassed the hold")

	for i in 270:
		manager._physics_process(1.0 / 60.0)
		figure._advance(1.0 / 60.0, true)
	check(spawned == 1, "new spawned emission occurred during hold")
	check(initial_position.distance_to(figure.global_position) > 2.0, "existing figure did not advance")
	check(not figure.suppressed, "existing figure was suppressed")
	check(is_equal_approx(manager._t, initial_t), "normal timer changed during hold")
	check(is_equal_approx(manager._forced_left, initial_forced_left), "forced timer changed during hold")
	check(manager._forced_tries == forced_tries_before, "forced tries changed during hold")
	check(is_equal_approx(manager._pending, initial_pending), "pending turn changed during hold")
	check(manager._new_spawn_hold <= 1.0 / 60.0, "hold did not expire within one frame")
	if manager._new_spawn_hold > 0.0:
		manager._physics_process(1.0 / 60.0)
	manager._physics_process(1.0 / 60.0)
	check(is_equal_approx(manager._t, initial_t)
		and is_equal_approx(manager._forced_left, initial_forced_left),
		"encounter clocks advanced behind an existing stalker")
	manager.hold_new_spawns(3.0)
	var remaining_t := manager._t
	var remaining_forced := manager._forced_left
	manager.despawn(false)
	check(is_zero_approx(manager._new_spawn_hold), "despawn(false) did not clear hold")
	check(manager._t == remaining_t and manager._forced_left == remaining_forced, "despawn(false) reset ordinary or forced timers")
	manager._physics_process(1.0 / 60.0)
	check(manager._t < remaining_t and manager._forced_left < remaining_forced,
		"queued encounter clocks did not resume after the live stalker left")

	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("DISCOVERY SPAWN HOLD: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
