extends SceneTree
## Regression fixtures for enemy/player traversal parity.

const DT := 1.0 / 60.0
var failures: Array[String] = []

class TestWalker extends ShadowWalkerVisual:
	func _ready() -> void:
		pass

class Pursuer extends ShadowFigure:
	func _create_walker_visual() -> void:
		_walker = TestWalker.new()
		add_child(_walker)
	func _build_presence() -> void:
		pass
	func _seize() -> void:
		pass
	func _edge_info(_cell: Vector2i, _dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL — ", message)

func box(parent: Node, at: Vector3, size: Vector3, angle := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.position = at
	body.rotation.z = angle
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

func tick(f: Pursuer, seen := false) -> void:
	var from := f.global_position
	f._advance(DT, seen)
	if f.global_position.distance_to(from) > 0.0001:
		check(f._clear_travel(from, f.global_position),
			"enemy capsule intersected geometry during traversal")

func _player(parent: Node, at: Vector3) -> Player:
	var p := Player.new()
	parent.add_child(p)
	await process_frame
	p.set_process(false)
	p.set_physics_process(false)
	p.flashlight.visible = true
	p.position = at
	return p

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(6, -0.1, 6), Vector3(100, 0.2, 100))
	var player := await _player(world, Vector3(10, 0, 6))
	await physics_frame

	# Enemy traversal must reserve the same standing capsule as the player.
	var probe := actor(world, player, Vector3(2, 0, 6))
	var player_capsule: CapsuleShape3D = null
	for child in player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			player_capsule = child.shape
	check(player_capsule != null, "player standing capsule missing")
	check(is_equal_approx(probe._move_shape.radius, player_capsule.radius)
		and is_equal_approx(probe._move_shape.height, player_capsule.height),
		"enemy traversal capsule differs from player capsule")
	probe.free()

	# A 0.90m inner hallway (walls at z=5.55 and 6.45) must remain traversable.
	var hallway_walls := [box(world, Vector3(6, 1.4, 5.45), Vector3(6, 2.8, 0.2)),
		box(world, Vector3(6, 1.4, 6.55), Vector3(6, 2.8, 0.2))]
	var narrow := actor(world, player, Vector3(2, 0, 6))
	await physics_frame
	for i in 2400:
		tick(narrow)
		if narrow.position.distance_to(player.position) < 1.2:
			break
	check(narrow.position.distance_to(player.position) < 1.2,
		"enemy stalled in player-width hallway: %s" % narrow.position)
	narrow.free()
	for wall in hallway_walls:
		wall.free()
	await physics_frame

	# A sloped floor with flat landings must be followed in both directions.
	# Off-grid passages are seeded by the player's physically travelled path.
	hallway_walls = [box(world, Vector3(6, 1.4, 5.60), Vector3(6, 2.8, 0.2)),
		box(world, Vector3(6, 1.4, 6.62), Vector3(6, 2.8, 0.2))]
	for index in 51:
		player.position = Vector3(2.5 + index * 0.15, 0, 6.11)
		player._record_traversal_sample()
	player.position = Vector3(10, 0, 6.11)
	narrow = actor(world, player, Vector3(2, 0, 5.91))
	await physics_frame
	for i in 3600:
		tick(narrow)
		if narrow.position.distance_to(player.position) < 1.2: break
	check(narrow.position.distance_to(player.position) < 1.2,
		"enemy lost the player's off-grid passage: %s" % narrow.position)
	narrow.free()
	player._traversal_samples.clear()
	for wall in hallway_walls: wall.free()
	await physics_frame

	var ramp_angle := atan(1.5 / 6.0)
	box(world, Vector3(6, 0.75, 6), Vector3(sqrt(38.25), 0.1, 2), ramp_angle)
	box(world, Vector3(0, -0.05, 6), Vector3(2, 0.1, 2))
	box(world, Vector3(10, 1.45, 6), Vector3(2, 0.1, 2))
	player.position = Vector3(10, 1.5, 6)
	var uphill := actor(world, player, Vector3(0, 0, 6))
	await physics_frame
	var start_y := uphill.position.y
	for i in 2400:
		tick(uphill)
		if uphill.position.distance_to(player.position) < 1.2:
			break
	check(uphill.position.y - start_y > 1.0 and uphill.position.distance_to(player.position) < 1.2,
		"enemy failed to ascend ramp: %s" % uphill.position)
	uphill.free()

	player.position = Vector3(0, 0, 6)
	var downhill := actor(world, player, Vector3(10, 1.5, 6))
	await physics_frame
	start_y = downhill.position.y
	for i in 2400:
		tick(downhill)
		if downhill.position.distance_to(player.position) < 1.2:
			break
	check(start_y - downhill.position.y > 1.0 and downhill.position.distance_to(player.position) < 1.2,
		"enemy failed to descend ramp: %s" % downhill.position)

	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("enemy traversal audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
