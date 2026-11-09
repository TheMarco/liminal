extends SceneTree
## Deterministic physical locomotion regression: exercise the real controller
## and yaw steering without loading six large skinned assets for every fixture.

const DT := 1.0 / 60.0
var failures: Array[String] = []

class TestWalker extends ShadowWalkerVisual:
	func _ready() -> void:
		pass

class Pursuer extends ShadowFigure:
	var catches := 0
	func _create_walker_visual() -> void:
		_walker = TestWalker.new()
		add_child(_walker)
	func _build_presence() -> void:
		pass
	func _seize() -> void:
		catches += 1
	func _edge_info(_cell: Vector2i, dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL — ", message)

func box(parent: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.position = at
	body.add_child(collision)
	parent.add_child(body)
	return body

func actor(parent: Node, player: Player, at: Vector3) -> Pursuer:
	var f := Pursuer.new()
	f.player = player
	f.position = at
	f.grace = 0.0
	parent.add_child(f)
	f.set_physics_process(false)
	var direction := player.global_position - at
	f._walker.rotation.y = atan2(direction.x, direction.z)
	return f

func tick(f: Pursuer, seen := true, dt := DT) -> void:
	var old_position := f.global_position
	var heading := f._walker.forward_world()
	f._advance(dt, seen)
	var moved := f.global_position - old_position
	var forward := f._walker.forward_world()
	check(heading.angle_to(forward) <= ShadowWalkerVisual.TURN_SPEED * minf(dt, 0.1) + 0.001,
		"heading snapped beyond bounded turn rate")
	if moved.length() > 0.0001:
		check(moved.normalized().dot(forward) > 0.999, "walking translated sideways")
		check(f._clear_travel(old_position, f.global_position), "walker crossed physical collision")
		check(absf(f._walker._movement_ratio * f._walker.walk_cycle_speed()
			- f.ground_velocity.length()) < 0.001, "walk playback did not track ground speed")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(6, -0.1, 6), Vector3(100, 0.2, 100))
	var player := Player.new()
	world.add_child(player)
	await process_frame
	await physics_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.flashlight.visible = true
	player.position = Vector3(10, 0, 6)
	var f := actor(world, player, Vector3(2, 0, 6))
	var obstruction := box(world, Vector3(6, 1.4, 6), Vector3(4, 2.8, 4))
	await physics_frame
	for i in 1800:
		tick(f)
		if f.position.distance_to(player.position) < 1.1:
			break
	check(f.position.distance_to(player.position) < 1.1,
		"3D walker stalled around finite obstacle: %s" % f.position)
	print("finite obstacle endpoint: ", f.position)
	f.free()
	obstruction.free()
	await physics_frame

	# A sharp far-range retarget may bend the path behind the model. Turning is
	# visible locomotion, not an AI pause: it must keep making a small safe arc.
	f = actor(world, player, Vector3(2, 0, 6))
	f._walker.rotation.y = -PI / 2.0
	var turn_start := f.position
	for frame in 30:
		tick(f)
	check(f.position.distance_to(turn_start) > 0.04,
		"far walker froze while reversing toward a new route: %s" % f.position)
	f.free()
	await physics_frame

	# A U-shaped obstacle requires walking away before resuming the pursuit.
	var walls := [box(world, Vector3(6.5, 1.4, 6), Vector3(0.4, 2.8, 4)),
		box(world, Vector3(5, 1.4, 4), Vector3(3.4, 2.8, 0.4)),
		box(world, Vector3(5, 1.4, 8), Vector3(3.4, 2.8, 0.4))]
	f = actor(world, player, Vector3(5.5, 0, 6))
	await physics_frame
	var detoured := false
	for i in 2400:
		tick(f)
		detoured = detoured or f.position.x < 3.0
		if f.position.distance_to(player.position) < 1.1:
			break
	check(detoured and f.position.distance_to(player.position) < 1.1,
		"3D walker stalled inside U-shaped furniture: %s" % f.position)
	print("U obstacle endpoint: ", f.position)
	f.free()
	for wall in walls:
		wall.free()
	await physics_frame

	# Three actors converge, maintaining both space and forward-only motion.
	var group: Array[Pursuer] = []
	for z in [3.0, 6.0, 9.0]:
		group.append(actor(world, player, Vector3(2, 0, z)))
	var closest := INF
	for frame in 1500:
		for a in group:
			tick(a)
			for b in group:
				if a != b:
					closest = minf(closest, a.position.distance_to(b.position))
	check(closest >= ShadowFigure.PEER_SEPARATION - 0.001,
		"crowd interpenetrated: %.4fm" % closest)
	for a in group:
		check(a.position.distance_to(player.position) < 2.3,
			"crowd permanently stalled away from player: %s" % a.position)
		print("crowd endpoint: ", a.position)
	for a in group:
		a.free()

	# Head-on traffic must choose opposing passing sides, not mutual standstill.
	var second_player := Player.new()
	world.add_child(second_player)
	await process_frame
	second_player.set_process(false)
	second_player.set_physics_process(false)
	second_player.position = Vector3(2, 0, 6)
	second_player.flashlight.visible = true
	f = actor(world, player, Vector3(3.5, 0, 6))
	var g := actor(world, second_player, Vector3(8.5, 0, 6))
	closest = INF
	for frame in 1500:
		tick(f)
		tick(g)
		closest = minf(closest, f.position.distance_to(g.position))
	check(closest >= ShadowFigure.PEER_SEPARATION - 0.001, "head-on walkers intersected")
	check(f.position.x > 8.5 and g.position.x < 3.5,
		"head-on walkers failed to pass: %s / %s" % [f.position, g.position])
	print("passing endpoints: ", f.position, " / ", g.position)
	f.free()
	g.free()
	second_player.free()

	# A 1.4m doorway with a 2.25m header forces a real narrow crossing, then
	# a turn after the entire capsule clears the jamb. Two followers must queue
	# when necessary and both make it through, never interpenetrate.
	walls = [box(world, Vector3(12, 1.4, -2.35), Vector3(0.3, 2.8, 15.3)),
		box(world, Vector3(12, 1.4, 14.35), Vector3(0.3, 2.8, 15.3)),
		box(world, Vector3(12, 2.625, 6), Vector3(0.3, 0.75, 1.4))]
	player.position = Vector3(18, 0, 8)
	f = actor(world, player, Vector3(8, 0, 3))
	g = actor(world, player, Vector3(5, 0, 8))
	f.completed_levels = 10
	g.completed_levels = 10
	await physics_frame
	closest = INF
	for frame in 3600:
		tick(f, false)
		tick(g, false)
		closest = minf(closest, f.position.distance_to(g.position))
		if f.position.x > 14.0 and g.position.x > 14.0:
			break
	check(f.position.x > 14 and g.position.x > 14,
		"narrow-door followers stalled: %s / %s" % [f.position, g.position])
	check(closest >= ShadowFigure.PEER_SEPARATION - 0.001,
		"doorway followers overlapped")
	print("doorway endpoints: ", f.position, " / ", g.position)
	f.free()
	g.free()
	for wall in walls:
		wall.free()
	await physics_frame
	player.position = Vector3(10, 0, 6)

	# Unseen actors keep closing, while a solid wall must block close-range kills.
	f = actor(world, player, Vector3(7.5, 0, 6))
	for frame in 90:
		tick(f, false)
	check(f.position.x > 8.4, "unseen actor parked near player")
	check(f._next_route_cell(Vector2i.ZERO, Vector2i(100, 0)) == Vector2i(1, 0),
		"room routing still has a distance cutoff")
	f.position = Vector3(2, 0, 6)
	f._walker.rotation.y = PI / 2.0
	var before_hitch := f.position
	f._advance(0.25, true)
	check(absf(f._walker._movement_ratio * f._walker.walk_cycle_speed() * 0.25
		- f.position.distance_to(before_hitch)) < 0.00001,
		"long-frame animation covered more distance than the moving body")
	f.position = Vector3(9.2, 0, 6)
	player.flashlight.visible = false
	obstruction = box(world, Vector3(9.6, 1.4, 6), Vector3(0.1, 2.8, 4))
	await physics_frame
	f._advance(DT)
	check(f.catches == 0, "actor caught the player through a solid wall")
	f.free()
	obstruction.free()

	# Wall time, not a clamped physics delta, detects stalls. Catch-up ticks
	# cannot spend the recovery window or reach contact before control returns.
	var guard := root.get_node("StallGuard") as GameplayFrameGuard
	guard.reset_clock(1000000)
	for frame in 20:
		var now := 1000000 + (frame + 1) * 50000
		guard.observe_physics(now)
		guard.observe_frame(now)
	check(not GameplayFrameGuard.is_recovering(),"ordinary 20 FPS triggered recovery")
	guard.observe_physics(3000000)
	check(GameplayFrameGuard.is_recovering(),"wall-clock stall was missed before physics")
	for frame in 8: guard.observe_physics(3000000 + frame * 100)
	check(guard.remaining_usec == GameplayFrameGuard.RECOVERY_USEC,
		"physics catch-up consumed reaction time")
	guard.observe_frame(3001000)
	f = actor(world,player,Vector3(9.2,0,6))
	f._walker._manifestation = 1.0
	var held_position := f.position
	f._advance(DT,false)
	check(f.catches == 0 and f.position == held_position,"stall recovery allowed pursuit or contact")
	f.appearance_delay = 0.45
	f.grace = 0.9
	f._physics_process(0.5)
	check(is_equal_approx(f.appearance_delay,0.45) and is_equal_approx(f.grace,0.9),
		"stall recovery consumed the encounter warning")
	f.appearance_delay = 0.0
	f.grace = 0.0
	for frame in 15: guard.observe_frame(3051000 + frame * 50000)
	check(not GameplayFrameGuard.is_recovering(),"responsive frames did not release recovery")
	f._advance(DT,false)
	check(f.catches == 1,"contact stayed disabled after recovery ended")
	guard.observe_frame(6000000)
	guard.observe_frame(6300000)
	check(guard.remaining_usec == GameplayFrameGuard.RECOVERY_USEC,"repeated stalls spent reaction time")
	guard.reset_clock(7000000)
	for frame in 30: guard.observe_physics(7016667 + frame * 16667)
	check(GameplayFrameGuard.is_recovering(),"running physics concealed a stalled picture")
	guard.reset_clock(8000000)
	GameplayFrameGuard.hold_for_presentation()
	check(GameplayFrameGuard.is_recovering(),"video resize did not hold threats while showing an old frame")
	guard.reset_clock(Time.get_ticks_usec())
	f.free()

	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("enemy pursuit audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
