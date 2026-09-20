extends SceneTree
## Deterministic CPU microbenchmark for real enemy navigation, without model loads.
## Run: godot --headless --path . --script tools/profile_enemy_navigation.gd
## Keep these fixtures unchanged when comparing production navigation revisions.

const DT := 1.0 / 60.0
const FRAMES := 420
const FRAME_BUDGET_MS := 16.7
const WATCHDOG_SECONDS := 180.0

class TestWalker extends ShadowWalkerVisual:
	func _ready() -> void: pass

class ProfilePath extends EnemyLocalPath:
	var elapsed_us := 0
	var search_us: Array[int] = []
	var search_slice_us: Array[int] = []
	func waypoint(from: Vector3, target: Vector3, dt: float, clear: Callable,
			reach := 0.0, reachable := Callable(), allow_partial := false) -> Vector3:
		var started := Time.get_ticks_usec()
		var result := super.waypoint(from, target, dt, clear, reach, reachable, allow_partial)
		elapsed_us = Time.get_ticks_usec() - started
		return result
	func _find(from: Vector3, target: Vector3, clear: Callable, reach: float,
			reachable := Callable(), allow_partial := false) -> Array[Vector3]:
		var started := Time.get_ticks_usec()
		var result := super._find(from, target, clear, reach, reachable, allow_partial)
		search_us.append(Time.get_ticks_usec() - started)
		return result
	func _step_search(clear: Callable, reachable: Callable) -> void:
		var started := Time.get_ticks_usec()
		super._step_search(clear, reachable)
		search_slice_us.append(Time.get_ticks_usec() - started)

class Pursuer extends ShadowFigure:
	var clear_calls := 0
	func _create_walker_visual() -> void:
		_walker = TestWalker.new()
		_walker.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_walker)
	func _build_presence() -> void: pass
	func _seize() -> void: pass
	func _edge_info(_cell: Vector2i, _dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}
	func _clear_travel(from: Vector3, to: Vector3) -> bool:
		clear_calls += 1
		return super._clear_travel(from, to)

var _finished := false
var _active_fixture: Node3D
var _watchdog_timer: Timer

func _initialize() -> void:
	seed(23117)
	call_deferred("_run")

func _watchdog() -> void:
	if not _finished:
		push_error("[enemy_navigation_profile] watchdog expired; benchmark did not complete")
		if is_instance_valid(_active_fixture):
			_active_fixture.free()
		quit(1)

func _box(parent: Node, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.position = at
	body.add_child(collision)
	parent.add_child(body)

func _pool(parent: Node) -> void:
	# Same deck ring and basin dimensions as audit_pool_enemy_ground.gd.
	_box(parent, Vector3(6, -0.1, 6), Vector3(12, 0.2, 12))
	_box(parent, Vector3(2, Chunk.POOL_DRY_Y * 0.5, 6), Vector3(4, Chunk.POOL_DRY_Y, 12))
	_box(parent, Vector3(10, Chunk.POOL_DRY_Y * 0.5, 6), Vector3(4, Chunk.POOL_DRY_Y, 12))
	_box(parent, Vector3(6, Chunk.POOL_DRY_Y * 0.5, 2), Vector3(4, Chunk.POOL_DRY_Y, 4))
	_box(parent, Vector3(6, Chunk.POOL_DRY_Y * 0.5, 10), Vector3(4, Chunk.POOL_DRY_Y, 4))

func _actor(parent: Node, player: Player, at: Vector3) -> Pursuer:
	var actor := Pursuer.new()
	actor.player = player
	actor.position = at
	actor.grace = 0.0
	actor.completed_levels = 10
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor._local_path = ProfilePath.new()
	parent.add_child(actor)
	var direction := player.global_position - at
	actor._walker.rotation.y = atan2(direction.x, direction.z)
	return actor

func _stats(values: Array[int], divisor := 1000.0) -> Dictionary:
	if values.is_empty():
		return {"samples": 0, "avg": 0.0, "p95": 0.0, "max": 0.0, "over_16_7_ms": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	var over_budget := 0
	for value in values:
		total += value
		if float(value) / divisor > FRAME_BUDGET_MS:
			over_budget += 1
	return {"samples": values.size(),
		"avg": snappedf(float(total) / values.size() / divisor, 0.001),
		"p95": snappedf(float(sorted[ceili(values.size() * 0.95) - 1]) / divisor, 0.001),
		"max": snappedf(float(sorted[-1]) / divisor, 0.001),
		"over_16_7_ms": over_budget}

func _fixture(label: String, is_pool: bool, moving: bool, actor_count: int) -> void:
	var world := Node3D.new()
	_active_fixture = world
	root.add_child(world)
	if is_pool:
		_pool(world)
	else:
		_box(world, Vector3(6, -0.1, 6), Vector3(100, 0.2, 100))
		_box(world, Vector3(6, 1.4, 6), Vector3(4, 2.8, 4))
	var player := Player.new()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.level_theme = 9 if is_pool else 4
	world.add_child(player)
	player.flashlight.visible = true
	player.position = Vector3(10, Chunk.POOL_DRY_Y, 6) if moving else (
		Vector3(6, 0, 6) if is_pool else Vector3(10, 0, 6))
	var actors: Array[Pursuer] = []
	for index in actor_count:
		var z := 6.0 if actor_count == 1 else 3.0 + index * 3.0
		actors.append(_actor(world, player, Vector3(2, Chunk.POOL_DRY_Y if is_pool else 0.0, z)))
	await physics_frame
	await physics_frame
	var advance_us: Array[int] = []
	var waypoint_us: Array[int] = []
	var frame_us: Array[int] = []
	var clear_counts: Array[int] = []
	var searches_us: Array[int] = []
	var search_slices_us: Array[int] = []
	var started := Time.get_ticks_usec()
	for frame in FRAMES:
		if moving:
			# A dry rectangular shoreline path, with continuous movement and corners.
			var corners := [Vector3(10, Chunk.POOL_DRY_Y, 6), Vector3(10, Chunk.POOL_DRY_Y, 10),
				Vector3(2, Chunk.POOL_DRY_Y, 10), Vector3(2, Chunk.POOL_DRY_Y, 2),
				Vector3(10, Chunk.POOL_DRY_Y, 2), Vector3(10, Chunk.POOL_DRY_Y, 6)]
			var progress := float(frame) * 5.0 / FRAMES
			var segment := mini(floori(progress), 4)
			player.position = corners[segment].lerp(corners[segment + 1], progress - segment)
		var frame_total := 0
		for actor in actors:
			var path := actor._local_path as ProfilePath
			path.elapsed_us = 0
			actor.clear_calls = 0
			var call_started := Time.get_ticks_usec()
			actor._advance(DT, false)
			var elapsed := Time.get_ticks_usec() - call_started
			advance_us.append(elapsed)
			waypoint_us.append(path.elapsed_us)
			clear_counts.append(actor.clear_calls)
			frame_total += elapsed
		frame_us.append(frame_total)
		# Allow the watchdog and native server queues to progress between batches.
		if frame % 30 == 29:
			await process_frame
	var endpoints: Array[String] = []
	for actor in actors:
		var path := actor._local_path as ProfilePath
		searches_us.append_array(path.search_us)
		search_slices_us.append_array(path.search_slice_us)
		endpoints.append(str(actor.position))
	var clear_total := 0
	for count in clear_counts:
		clear_total += count
	print("[enemy_navigation_profile] ", JSON.stringify({
		"fixture": label, "frames": FRAMES, "actors": actor_count,
		"advance_ms": _stats(advance_us), "waypoint_ms": _stats(waypoint_us),
		"search_ms": _stats(searches_us), "search_slice_ms": _stats(search_slices_us),
		"frame_ms": _stats(frame_us),
		"clear_calls_total": clear_total, "clear_calls_max": clear_counts.max(),
		"clear_calls_avg": snappedf(float(clear_total) / clear_counts.size(), 0.01),
		"wall_ms": snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.001),
		"endpoints": endpoints}))
	world.free()
	_active_fixture = null
	await physics_frame

func _run() -> void:
	_watchdog_timer = Timer.new()
	_watchdog_timer.one_shot = true
	_watchdog_timer.wait_time = WATCHDOG_SECONDS
	_watchdog_timer.timeout.connect(_watchdog)
	root.add_child(_watchdog_timer)
	_watchdog_timer.start()
	print("[enemy_navigation_profile] version=1 frames=%d dt=%.8f seed=23117" % [FRAMES, DT])
	await _fixture("dry_obstacle_detour", false, false, 1)
	await _fixture("unreachable_water_target", true, false, 1)
	await _fixture("moving_shore_target", true, true, 1)
	await _fixture("three_actors_water_target", true, false, 3)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	_finished = true
	_watchdog_timer.stop()
	_watchdog_timer.free()
	print("[enemy_navigation_profile] complete")
	quit(0)
