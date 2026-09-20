extends SceneTree
## Enemy traversal over the authored airport travelator and escalator.

const DT := 1.0 / 60.0
var failures: Array[String] = []

class TestWalker extends ShadowWalkerVisual:
	func _ready() -> void: pass

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

func actor(parent: Node, player: Player, at: Vector3) -> Pursuer:
	var f := Pursuer.new()
	f.player = player
	f.position = at
	f.grace = 0.0
	parent.add_child(f)
	f.set_physics_process(false)
	f._walker.rotation.y = atan2(player.global_position.x - at.x,
		player.global_position.z - at.z)
	return f

func make_chunk(world: Node) -> Chunk:
	var chunk := Chunk.new(WorldGen.level_seed(9137, 4), Vector2i.ZERO, 4)
	world.add_child(chunk)
	for child in chunk.get_children():
		if child != chunk.body:
			child.free()
	for child in chunk.body.get_children():
		child.free()
	return chunk

func ground(chunk: Chunk) -> void:
	chunk._scene_writer.box(Vector3(6, -0.1, 6), Vector3(14, 0.2, 14), Mats.marble())

func pursue(f: Pursuer, player: Player, limit: int) -> Dictionary:
	var peak := f.position.y
	for i in limit:
		f._advance(DT, false)
		peak = maxf(peak, f.position.y)
		if f.position.distance_to(player.position) < 1.2:
			break
	return {"distance": f.position.distance_to(player.position), "peak": peak,
		"position": f.position}

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var chunk := make_chunk(world)
	ground(chunk)
	chunk._level_builder._travelator(Vector3(6, 0, 6), 0, 1, 7, 8.4)
	var player := Player.new()
	world.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.flashlight.visible = true
	player.position = Vector3(12, 0, 6)
	await physics_frame
	var f := actor(world, player, Vector3(0, 0, 6))
	var result := pursue(f, player, 3600)
	check(float(result.peak) > 0.10 and float(result.distance) < 1.2,
		"enemy failed to cross travelator uphill: %s" % result)
	f.free()
	player.position = Vector3(0, 0, 6)
	f = actor(world, player, Vector3(12, 0, 6))
	result = pursue(f, player, 3600)
	check(float(result.peak) > 0.10 and float(result.distance) < 1.2,
		"enemy failed to cross travelator downhill: %s" % result)
	f.free()
	chunk.free()
	await physics_frame

	chunk = make_chunk(world)
	ground(chunk)
	chunk._level_builder._escalator_flight(Vector3(6, 0, 6), 0, 0)
	chunk._scene_writer.box(Vector3(6, 2.15, 10), Vector3(1.2, 0.2, 1.8), Mats.marble())
	player.position = Vector3(6, 2.25, 10)
	f = actor(world, player, Vector3(6, 0, 3))
	await physics_frame
	result = pursue(f, player, 6000)
	check(float(result.peak) > 1.8 and float(result.distance) < 1.2,
		"enemy failed to ascend escalator: %s" % result)
	f.free()
	player.position = Vector3(6, 0, 3)
	f = actor(world, player, Vector3(6, 2.25, 10))
	result = pursue(f, player, 6000)
	check(float(result.peak) > 1.8 and float(result.distance) < 1.2,
		"enemy failed to descend escalator: %s" % result)

	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("enemy airport traversal audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
