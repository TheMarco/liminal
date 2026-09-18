extends SceneTree
## Regression contract for hostile collision leases. Run:
## godot --headless --path . --script tools/audit_enemy_streaming.gd

const FAR := Vector2i(10, 0)
const NEXT := Vector2i(11, 0)
const MOVED := Vector2i(16, 0)


class LeaseFigure extends ShadowFigure:
	func _ready() -> void:
		set_physics_process(false)


func _init() -> void:
	call_deferred("_run")


func _expect(ok: bool, message: String, failures: Array[String]) -> void:
	if ok:
		return
	failures.append(message)
	push_error(message)


func _manager() -> Dictionary:
	var manager := ChunkManager.new()
	manager.world_seed = 99173
	manager.theme = 10
	root.add_child(manager)
	manager.set_process(false)
	var player := CharacterBody3D.new()
	manager.add_child(player)
	manager.player = player
	player.position = Vector3(6.0, 1.0, 6.0)
	manager.warm_up(Vector2i.ZERO)
	manager._process(1.0 / 60.0)
	return {"manager": manager, "player": player}


func _expect_lease_neighbourhood(manager: ChunkManager, center: Vector2i,
		failures: Array[String]) -> void:
	for cell in manager._room_complete_cells(center, ChunkManager.WARM_R):
		_expect(manager._hostile_cells.has(cell),
			"hostile lease omitted %s around %s" % [cell, center], failures)
		_expect(manager.chunks.has(cell) or manager.queued.has(cell)
				or manager._pending_cell == cell,
			"hostile lease did not request collision cell %s" % cell, failures)


func _run() -> void:
	var failures: Array[String] = []
	var fixture := _manager()
	var manager: ChunkManager = fixture["manager"]
	var player: CharacterBody3D = fixture["player"]
	var player_wanted := manager._wanted.duplicate()
	var far_chunk := manager._build(FAR)
	_expect(far_chunk.body != null, "fixture did not build distant collision", failures)

	manager.set_hostile_cells([FAR, NEXT])
	_expect(manager._wanted == player_wanted,
		"hostile lease changed the player stream ring", failures)
	_expect_lease_neighbourhood(manager, FAR, failures)
	_expect_lease_neighbourhood(manager, NEXT, failures)
	manager._process(1.0 / 60.0)
	_expect(manager.chunk_at(FAR) != null and manager.chunk_at(FAR).body != null,
		"leased distant floor collision unloaded beneath hostile", failures)

	var moved_chunk := manager._build(MOVED)
	manager.set_hostile_cells([MOVED])
	manager._process(1.0 / 60.0)
	_expect(manager.chunk_at(MOVED) == moved_chunk and moved_chunk.body != null,
		"moved hostile lease did not retain its new floor", failures)
	_expect(manager.chunk_at(FAR) == null,
		"moving hostile lease did not release former distant floor", failures)
	manager.set_hostile_cells([])
	manager._process(1.0 / 60.0)
	_expect(manager.chunk_at(MOVED) == null,
		"empty hostile lease did not permit distant floor unload", failures)
	manager.free()

	# Priority must be a category rather than an unbounded player-distance score.
	fixture = _manager()
	manager = fixture["manager"]
	player = fixture["player"]
	manager._cancel_pending()
	manager.queued.clear()
	var outer := Vector2i(ChunkManager.LOAD_R, ChunkManager.LOAD_R)
	_expect(manager._wanted.has(outer), "fixture lacks ordinary wanted outer cell", failures)
	manager.queued[outer] = true
	manager.set_hostile_cells([Vector2i(30, 0)])
	manager._process(1.0 / 60.0)
	_expect(manager._hostile_cells.has(manager._pending_cell),
		"distant hostile collision lost priority to ordinary player scenery", failures)
	manager.free()

	# Integration: one managed actor leases both its current and next route cell;
	# suspension and passive state both propagate to its child suppression flag.
	fixture = _manager()
	manager = fixture["manager"]
	var figures := ShadowFigures.new()
	figures.chunk_manager = manager
	root.add_child(figures)
	var figure := LeaseFigure.new()
	figure.position = Vector3(FAR.x * ChunkManager.CELL + 6.0, 0.0, 6.0)
	figure._route_next = NEXT
	figures.add_child(figure)
	figures._figs.append(figure)
	figures._refresh_streaming()
	_expect(manager._hostile_cells.has(FAR) and manager._hostile_cells.has(NEXT),
		"managed hostile did not lease current and next route cells", failures)
	figures.suspended = true
	_expect(figure.suppressed, "suspended manager did not suppress existing child", failures)
	figures.suspended = false
	figures.passive = true
	_expect(figure.suppressed, "passive manager did not suppress existing child", failures)
	figures.passive = false
	_expect(not figure.suppressed, "cleared suspension/passive left child suppressed", failures)
	figures.despawn()
	_expect(manager._hostile_cells.is_empty(), "despawn did not clear hostile leases", failures)
	figures.free()
	manager.free()

	if failures.is_empty():
		print("enemy streaming audit passed")
	else:
		Chunk.clear_runtime_caches()
		Mats.clear_runtime_caches()
		quit(1)
		return
	Chunk.clear_runtime_caches()
	Mats.clear_runtime_caches()
	quit(0)
