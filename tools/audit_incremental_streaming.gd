extends SceneTree
## Focused contract for deferred chunk streaming and its safety invariants.
## Run: godot --headless --path . --script tools/audit_incremental_streaming.gd \
##   --log-file /tmp/liminal-incremental-streaming.log

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	if ChunkManager.LOAD_R != 3 or ChunkManager.UNLOAD_R != ChunkManager.LOAD_R + 1 \
			or ChunkManager.BUDGET != 1 or ChunkManager.WARM_R != 1:
		failures.append("expanded range changed the one-chunk budget or safe 3x3 warmup")
	_audit_visible_rings(failures)
	var deferred := Chunk.new(99173, Vector2i(0, 0), 2, null, true)
	var stages := 0
	while not deferred.build_next_stage():
		stages += 1
	if stages != 7 or deferred._build_stage != 8:
		failures.append("deferred chunk did not complete exactly eight stages")
	if deferred.body == null or deferred.get_parent() != null:
		failures.append("deferred chunk was installed or lacks collision body")
	deferred.free()

	var manager := ChunkManager.new()
	root.add_child(manager)
	manager.world_seed = 99173
	manager.theme = 10
	manager.set_process(false)
	var signals := {"count": 0}
	manager.chunk_built.connect(func(chunk: Chunk):
		signals.count += 1
		if chunk._build_stage != 8 or not chunk.is_inside_tree() \
				or manager.chunks.get(chunk.cell) != chunk or chunk.body == null:
			failures.append("chunk_built observed incomplete/uninstalled content"))
	manager.warm_up(Vector2i.ZERO)
	for z in range(-1, 2):
		for x in range(-1, 2):
			var safe := manager.chunk_at(Vector2i(x, z))
			if safe == null or safe.body.get_child_count() == 0:
				failures.append("Data Center warmup missing collision")
	var player := CharacterBody3D.new()
	manager.add_child(player)
	manager.player = player
	player.position = Vector3(6.0, 1.0, 6.0)
	player.velocity = Vector3(18.0, 0.0, 0.0)
	manager._process(1.0 / 60.0)
	for _frame in 12:
		var before: int = signals.count
		manager._process(1.0 / 60.0)
		if signals.count - before > 1:
			failures.append("streaming installed more than one completed chunk per frame")
	var expected_ahead := Vector2i(1, 0)
	if manager._last_ahead != expected_ahead or not manager._ahead.has(expected_ahead) \
			or not manager._ahead.has(expected_ahead + Vector2i(ChunkManager.LOAD_R, 0)):
		failures.append("directional prefetch did not cover predicted cell")
	var old_pending_id := manager._pending_chunk.get_instance_id() if manager._pending_chunk != null else 0
	player.position = Vector3(60.0, 1.0, 6.0)
	manager._process(1.0 / 60.0)
	if old_pending_id != 0 and is_instance_id_valid(old_pending_id):
		failures.append("center change did not cancel stale pending chunk")
	for x in [48.0, 36.0, 24.0, 12.0, 0.0, -12.0]:
		player.position.x = x
		manager._process(1.0 / 60.0)
	if manager._last_center != Vector2i(-1, 0):
		failures.append("reverse traversal did not update streaming center")
	manager.set_blackout(true)
	if manager._pending_chunk != null:
		failures.append("blackout left a pending ordinary build")
	manager.set_blackout(false)
	if signals.count == 0:
		failures.append("no complete chunk was installed/signalled")
	for cell in manager._wanted:
		for member in WorldGen.owning_room_members(manager.world_seed, cell, manager.theme):
			var anchor := WorldGen.room_id(manager.world_seed, member)
			if WorldGen.corridor(manager.world_seed, member) == 0 and not manager._wanted.has(anchor):
				failures.append("visible room member lacks required owning anchor")
	# Cancellation is tested with a guaranteed incomplete off-tree chunk,
	# independently of how fast this computer happens to build a normal frame.
	manager._cancel_pending()
	var staged_cell: Vector2i = manager._wanted.keys()[0]
	manager._pending_cell = staged_cell
	manager._pending_chunk = Chunk.new(manager.world_seed, staged_cell, manager.theme, null, true)
	var staged_id := manager._pending_chunk.get_instance_id()
	manager._pending_chunk.build_next_stage()
	manager.set_blackout(true)
	if is_instance_id_valid(staged_id) or not manager.queued.has(staged_cell):
		failures.append("blackout did not discard and requeue incomplete content")
	manager.free()

	var warm_manager := ChunkManager.new()
	root.add_child(warm_manager)
	warm_manager.world_seed = 99173
	warm_manager.theme = 2
	warm_manager.set_process(false)
	warm_manager.warm_up(Vector2i.ZERO)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if not warm_manager.chunks.has(Vector2i(dx, dz)):
				failures.append("3x3 warmup missing collision chunk %s" % Vector2i(dx, dz))
			else:
				var chunk := warm_manager.chunks[Vector2i(dx, dz)] as Chunk
				if chunk.body == null or not is_instance_valid(chunk.body):
					failures.append("warmup chunk lacks collision body")
	warm_manager.free()
	if failures.is_empty():
		print("incremental streaming audit passed")
	else:
		for failure in failures:
			push_error(failure)
		Chunk.clear_runtime_caches()
		Mats.clear_runtime_caches()
		quit(1)
		return
	Chunk.clear_runtime_caches()
	Mats.clear_runtime_caches()
	quit(0)


func _audit_visible_rings(failures: Array[String]) -> void:
	var manager := ChunkManager.new()
	manager.world_seed = 99173
	manager.theme = 4
	root.add_child(manager)
	manager.set_process(false)
	var player := CharacterBody3D.new()
	manager.add_child(player)
	manager.player = player
	player.position = Vector3(6, 1.7, 6)
	player.velocity = Vector3(6, 0, 0)
	manager._process(1.0 / 60.0)
	for z in range(-3, 4):
		for x in range(-3, 4):
			if not manager._wanted.has(Vector2i(x, z)):
				failures.append("7x7 core is missing %s" % Vector2i(x, z))
	# A completed predicted room must be visible BEFORE entering the next cell.
	var ahead_cell := Vector2i(ChunkManager.LOAD_R + 1, 0)
	var ahead := manager._build(ahead_cell)
	ahead.visible = false
	manager._process(1.0 / 60.0)
	if manager._wanted.has(ahead_cell) or not manager._ahead.has(ahead_cell) or not ahead.visible:
		failures.append("completed prefetch room is not visible beyond the core")
	# Stopping invalidates the prediction, not the scenery already in memory.
	player.velocity = Vector3.ZERO
	manager._process(1.0 / 60.0)
	if manager._ahead.has(ahead_cell) or not ahead.visible or not manager.chunks.has(ahead_cell):
		failures.append("stopping hid or discarded a resident outer room")
	var retention_only := Vector2i(ChunkManager.UNLOAD_R, ChunkManager.UNLOAD_R)
	if not manager._retained.has(retention_only) or manager.queued.has(retention_only):
		failures.append("retention ring was queued for construction instead of only retained")
	var outer_anchor := ChunkManager.NO_BROKEN_STATION
	for cell in manager._retained:
		if WorldGen.corridor(manager.world_seed, cell) == 0 \
				and not manager._retained.has(WorldGen.room_id(manager.world_seed, cell)):
			failures.append("retained room lost its owning anchor")
		if manager._cheb(cell, Vector2i.ZERO) > ChunkManager.UNLOAD_R:
			outer_anchor = cell
	if outer_anchor == ChunkManager.NO_BROKEN_STATION:
		failures.append("test seed no longer exercises a merged-room anchor outside the retention square")
	else:
		var anchor := manager._build(outer_anchor)
		anchor.visible = false
		manager._process(1.0 / 60.0)
		if not manager.chunks.has(outer_anchor) or not anchor.visible:
			failures.append("merged-room furniture anchor was hidden/freed before its retained members")
	var old_edge := Vector2i(ChunkManager.LOAD_R, 0)
	var edge := manager._build(old_edge)
	player.position.x = -6.0
	manager._process(1.0 / 60.0)
	if manager._wanted.has(old_edge) or not edge.visible:
		failures.append("crossing a boundary hid a loaded outer room")
	player.position.x = -120.0
	manager._process(1.0 / 60.0)
	if manager.chunks.has(old_edge) or manager.chunks.has(ahead_cell):
		failures.append("distant scenery was not unloaded after leaving the retained ring")
	# An enlarged view must not prematurely release the arrival collision focus.
	manager.stream_focus = Vector3(6, 0, 6)
	player.position.x = 30.0
	manager._process(1.0 / 60.0)
	if manager.stream_focus == Vector3.INF or manager._last_center != Vector2i.ZERO:
		failures.append("floor focus released before the player reached the safe warmup ring")
	player.position.x = 6.0
	manager._process(1.0 / 60.0)
	if manager.stream_focus != Vector3.INF:
		failures.append("arrival focus did not release after landing")
	# Doorway previews keep their cheaper preparation radius and complete anchors.
	var preview_cells := manager._room_complete_cells(Vector2i.ZERO, RealmExcursion.PREVIEW_LOAD_R)
	if RealmExcursion.PREVIEW_LOAD_R != 2 or preview_cells.has(Vector2i(3, 3)):
		failures.append("doorway preview inherited the full gameplay build radius")
	manager.free()
