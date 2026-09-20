extends SceneTree
## Pool girl traversal regression: water movement, ladders, and solid geometry.

const DT := 1.0 / 60.0
var failures: Array[String] = []

class TestWalker extends ShadowWalkerVisual:
	var last_speed := 0.0
	var last_running := false
	func _ready() -> void: pass
	func set_ground_speed(metres_per_second: float, running := false) -> void:
		last_speed = metres_per_second
		last_running = running

class Pursuer extends ShadowFigure:
	func _create_walker_visual() -> void:
		_walker = TestWalker.new()
		add_child(_walker)
	func _build_presence() -> void: pass
	func _seize() -> void: pass
	func _edge_info(_cell: Vector2i, _dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
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

func ladder(parent: Node, at: Vector3, dry_direction := Vector3.ZERO) -> Area3D:
	var area := Area3D.new()
	area.position = at
	if dry_direction != Vector3.ZERO:
		area.set_meta("enemy_ladder_landing_local",
			dry_direction.normalized() * 0.70 \
			+ Vector3.UP * (Chunk.POOL_DRY_Y - at.y))
		area.set_meta("enemy_ladder_climb_local",
			-dry_direction.normalized() * 0.60)
		area.set_meta("enemy_ladder_facing_local", dry_direction.normalized())
	area.collision_layer = Player.LADDER_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(1.6, 3.0, 1.6)
	shape.shape = volume
	area.add_child(shape)
	parent.add_child(area)
	return area

func actor(parent: Node, player: Player, at: Vector3) -> Pursuer:
	var f := Pursuer.new()
	f.walker_model_index = 10
	f.player = player
	f.position = at
	f.grace = 0.0
	parent.add_child(f)
	f.set_physics_process(false)
	var direction := player.global_position - at
	f._walker.rotation.y = atan2(direction.x, direction.z)
	return f

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(6, -0.1, 6), Vector3(12, 0.2, 12))
	box(world, Vector3(2, 0.71, 6), Vector3(4, 1.42, 12))
	var player := Player.new()
	world.add_child(player)
	await process_frame
	await physics_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.level_theme = 9
	player.water_y = Chunk.POOL_WATER_Y
	player.flashlight.visible = true
	player.position = Vector3(7, 0, 6)
	ladder(world, Vector3(3.85, 0.9, 6), Vector3.LEFT)

	# A ladder climb is one committed sequence: centre between the rails, face
	# the lip, rise, then step onto the authored dry landing. Starting off-centre
	# and facing away catches the former up/down bob beside the ladder.
	var climb_probe := actor(world, player, Vector3(4.45, 0.0, 6.55))
	climb_probe._walker.rotation.y = PI / 2.0
	climb_probe._begin_vertical_travel(climb_probe.position + Vector3.UP * 0.1)
	var first_rise_facing := -1.0
	var first_rise_lateral_error := INF
	for i in 480:
		var before_y := climb_probe.position.y
		climb_probe._advance_vertical(DT, DT)
		if first_rise_facing < 0.0 and climb_probe.position.y > before_y + 0.001:
			first_rise_facing = climb_probe._walker.forward_world().dot(Vector3.LEFT)
			first_rise_lateral_error = absf(climb_probe.position.z - 6.0)
		if climb_probe._vertical_target == Vector3.INF:
			break
	check(first_rise_facing >= 0.80,
		"pool girl began climbing before facing the pool lip: %.2f" % first_rise_facing)
	check(first_rise_lateral_error < 0.06,
		"pool girl climbed beside the ladder instead of between its rails: %.2f" \
		% first_rise_lateral_error)
	check(climb_probe._vertical_target == Vector3.INF \
			and climb_probe.position.x < 3.30 \
			and absf(climb_probe.position.y - Chunk.POOL_DRY_Y) < 0.03,
		"pool girl did not commit from ladder to dry deck: %s" % climb_probe.position)
	climb_probe.free()
	await physics_frame

	# Water-to-water travel is valid for the pool girl.
	var f := actor(world, player, Vector3(2, 1.42, 6))
	await physics_frame
	check(f._clear_travel(Vector3(5, 0, 6), Vector3(8, 0, 6)),
		"pool girl rejected submerged water-to-water travel")
	# A solid wall must still block the capsule.
	var wall := box(world, Vector3(6, 0.9, 6), Vector3(0.2, 1.8, 3))
	await physics_frame
	check(not f._clear_travel(Vector3(5, 0, 6), Vector3(7, 0, 6)),
		"pool girl phased through a solid wall")
	wall.free()
	await physics_frame

	var dry_run_seen := false
	var wet_walk_seen := false
	var max_dry_speed := 0.0
	var max_wet_speed := 0.0
	for i in 3600:
		f._advance(DT, false)
		var walker := f._walker as TestWalker
		if f.position.y > 1.3:
			max_dry_speed = maxf(max_dry_speed, walker.last_speed)
			dry_run_seen = dry_run_seen or (walker.last_running and walker.last_speed > 1.5)
		elif f.position.y < 0.2:
			var wet_horizontal := Vector2(f.ground_velocity.x, f.ground_velocity.z).length()
			max_wet_speed = maxf(max_wet_speed, wet_horizontal)
			wet_walk_seen = wet_walk_seen or (not walker.last_running \
				and wet_horizontal > 0.7)
		if f.position.y < 0.2 and f.position.distance_to(player.position) < 1.2:
			break
	check(dry_run_seen and max_dry_speed > 1.9,
		"pool girl did not run on deck: %.2f m/s" % max_dry_speed)
	check(wet_walk_seen and max_wet_speed <= ShadowFigure.POOL_GIRL_WATER_SPEED + 0.05,
		"pool girl did not slow to a water walk: %.2f m/s" % max_wet_speed)
	check(f.position.y < 0.2 and f.position.distance_to(player.position) < 1.2,
		"pool girl failed to enter basin and reach player: %s" % f.position)

	player.position = Vector3(2, 1.42, 6)
	f.position = Vector3(7, 0, 6)
	f._local_path.invalidate()
	f._clear_route()
	var climb_reversals := 0
	var last_vertical_sign := 0
	for i in 6000:
		var before_y := f.position.y
		f._advance(DT, false)
		var delta_y := f.position.y - before_y
		var vertical_sign := signi(delta_y) if absf(delta_y) > 0.001 else 0
		if vertical_sign != 0 and last_vertical_sign != 0 \
				and vertical_sign != last_vertical_sign:
			climb_reversals += 1
		if vertical_sign != 0:
			last_vertical_sign = vertical_sign
		if f.position.y > 1.3 and f.position.distance_to(player.position) < 1.2:
			break
	check(f.position.y > 1.3 and f.position.distance_to(player.position) < 1.2,
		"pool girl failed to climb ladder to deck: %s" % f.position)
	check(climb_reversals == 0,
		"pool girl reversed vertically %d times while leaving water" % climb_reversals)

	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("pool enemy traversal audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
