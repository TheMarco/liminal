extends SceneTree
## Poolrooms enemy-ground regression.  Uses prototype walkers so no large assets load.

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

func check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("FAIL — ", msg)

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

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	box(world, Vector3(6, -0.1, 6), Vector3(12, 0.2, 12))
	# Raised dry ring; its square opening is x/z in [4, 8].
	box(world, Vector3(2, Chunk.POOL_DRY_Y * 0.5, 6), Vector3(4, Chunk.POOL_DRY_Y, 12))
	box(world, Vector3(10, Chunk.POOL_DRY_Y * 0.5, 6), Vector3(4, Chunk.POOL_DRY_Y, 12))
	box(world, Vector3(6, Chunk.POOL_DRY_Y * 0.5, 2), Vector3(4, Chunk.POOL_DRY_Y, 4))
	box(world, Vector3(6, Chunk.POOL_DRY_Y * 0.5, 10), Vector3(4, Chunk.POOL_DRY_Y, 4))

	var player := Player.new()
	world.add_child(player)
	await process_frame
	await physics_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.level_theme = 9
	player.position = Vector3(10, Chunk.POOL_DRY_Y, 6)

	var manager := ShadowFigures.new()
	manager.player = player
	manager.completed_levels = 10
	manager.set_physics_process(false)
	world.add_child(manager)
	await physics_frame

	var deck := manager._floor_at(Vector3(10, Chunk.POOL_DRY_Y, 6))
	check(deck != Vector3.INF and absf(deck.y - Chunk.POOL_DRY_Y) < 0.01, "deck-height floor probe failed")
	var wading := manager._floor_at(Vector3(10, 0.25, 6))
	check(wading != Vector3.INF and absf(wading.y - Chunk.POOL_DRY_Y) < 0.01, "wading-height deck probe failed")
	check(manager._floor_at(Vector3(6, 0, 6)) == Vector3.INF, "basin floor accepted")
	check(not manager._spawn_at(Vector3(6, 0, 6), false, 0.0), "basin spawn accepted")
	check(not manager._spawn_at(Vector3(6, Chunk.POOL_DRY_Y, 6), false, 0.0), "hovering basin spawn accepted")
	check(not manager._spawn_at(Vector3(3.6, Chunk.POOL_DRY_Y, 6), false, 0.0), "lip-overhanging spawn accepted")

	var f := Pursuer.new()
	f.player = player
	f.use_walker_prototype = true
	f.position = Vector3(2, Chunk.POOL_DRY_Y, 6)
	f.grace = 0.0
	manager.add_child(f)
	f.set_physics_process(false)
	await physics_frame
	check(not f._clear_travel(f.position, player.position), "straight travel across pool accepted")
	check(not f._clear_travel(Vector3(2, 0, 6), Vector3(10, 0, 6)), "submerged travel accepted")
	var detoured := false
	for i in 2400:
		f._advance(DT, false)
		if f.position.z < 3.7 or f.position.z > 8.3: detoured = true
		check(ShadowFigure.pool_deck_clear(player, f.position, ShadowFigure.MOVE_RADIUS), "detour entered basin")
		if f.position.distance_to(player.position) < 1.2: break
	check(detoured and f.position.distance_to(player.position) < 1.2, "dry-deck pursuit did not detour to player")

	player.position = Vector3(6, 0, 6)
	f.position = Vector3(2, Chunk.POOL_DRY_Y, 6)
	f._local_path.invalidate()
	f._clear_route()
	for i in 240:
		f._advance(DT, false)
		check(ShadowFigure.pool_deck_clear(player, f.position, ShadowFigure.MOVE_RADIUS), "water pursuit entered pool")
	check(f.position.x > 2.8 and f.position.x < 3.5, "water pursuit failed to approach dry shore: %s" % f.position)
	player.position = Vector3(10, Chunk.POOL_DRY_Y, 6)
	for i in 1800: f._advance(DT, false)
	check(f.position.distance_to(player.position) < 1.5, "pursuit failed to resume from dry shore")

	box(world, Vector3(6, Chunk.POOL_DRY_Y - 0.1, 6), Vector3(4, 0.2, 1.8))
	await physics_frame
	check(ShadowFigure.pool_deck_clear(player, Vector3(6, Chunk.POOL_DRY_Y, 6), ShadowFigures.FIGURE_CLEAR_RADIUS), "dry bridge rejected")
	check(f._clear_travel(Vector3(2, Chunk.POOL_DRY_Y, 6), Vector3(10, Chunk.POOL_DRY_Y, 6)), "dry bridge crossing rejected")
	# A pool continuing through the middle of a shared room opening must route
	# onto a dry side of that opening, instead of repeatedly aiming into water.
	box(world, Vector3(12, -0.1, 30), Vector3(24, 0.2, 12))
	box(world, Vector3(4, Chunk.POOL_DRY_Y * 0.5, 30), Vector3(8, Chunk.POOL_DRY_Y, 12))
	box(world, Vector3(20, Chunk.POOL_DRY_Y * 0.5, 30), Vector3(8, Chunk.POOL_DRY_Y, 12))
	box(world, Vector3(12, Chunk.POOL_DRY_Y * 0.5, 26), Vector3(8, Chunk.POOL_DRY_Y, 4))
	box(world, Vector3(12, Chunk.POOL_DRY_Y * 0.5, 34), Vector3(8, Chunk.POOL_DRY_Y, 4))
	await physics_frame
	f.position = Vector3(2, Chunk.POOL_DRY_Y, 30)
	player.position = Vector3(22, Chunk.POOL_DRY_Y, 30)
	f._local_path.invalidate()
	f._clear_route()
	var crossing := f._doorway_waypoint(Vector2i(0, 2), Vector2i(1, 2))
	check(f._clear_travel(crossing - Vector3.RIGHT * ShadowFigure.DOORWAY_CROSS_INSET * 2.0, crossing),
		"connected pool chose a wet crossing")
	for i in 2400:
		f._advance(DT, false)
		check(ShadowFigure.pool_deck_clear(player, f.position, ShadowFigure.MOVE_RADIUS), "connected pool pursuit entered water")
		if f.position.distance_to(player.position) < 1.2: break
	check(f.position.distance_to(player.position) < 1.2, "connected pool pursuit failed: %s" % f.position)
	box(world, Vector3(26, -0.1, 6), Vector3(12, 0.2, 12))
	await physics_frame
	player.level_theme = 4
	check(manager._floor_at(Vector3(26, 0, 6)) != Vector3.INF, "non-pool floor rejected")
	check(f._clear_travel(Vector3(22, 0, 6), Vector3(30, 0, 6)), "non-pool travel rejected")
	world.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("pool enemy ground audit: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
