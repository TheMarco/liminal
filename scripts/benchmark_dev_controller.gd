class_name BenchmarkDevController
extends Node
## Isolated command-line benchmark, partition audit and screenshot tooling.
## None of this state participates in the game loop unless an explicit dev
## option enables it.

var _enabled := false
var _player: Player
var _elapsed := 0.0
var _frames := 0
var _worst := 0.0
var _slow := 0
var _previous_camera := Vector3.ZERO
var _steps: Array[float] = []
var _process_worst := 0.0
var _physics_worst := 0.0
var _draws_max := 0
var _primitives_max := 0
var _collision_pairs_max := 0
var _static_start := 0
var _static_peak := 0
var _nodes_start := 0
var _resources_start := 0
var _vram_max := 0


func start_benchmark(player: Player) -> void:
	_player = player
	_enabled = player != null
	if not _enabled:
		return
	_player.dev_spin = true
	_player.dev_walk = true
	_previous_camera = _player.cam.global_position
	_reset_monitors()


func update(delta: float) -> void:
	if not _enabled or _player == null or not is_instance_valid(_player):
		return
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	_sample_monitors()
	if delta > 1.0 / 55.0:
		_slow += 1
	# Per-rendered-frame movement catches physics-tick judder directly.
	var camera_position := _player.cam.global_position
	var step := camera_position.distance_to(_previous_camera)
	_previous_camera = camera_position
	if _frames > 2:
		_steps.append(step)
	if _elapsed < 3.0:
		return
	_print_report()
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0
	_slow = 0
	_reset_monitors()


func schedule_screenshot(player: Player, viewport: Viewport,
		path: String, after := 2.5) -> void:
	if path.is_empty() or player == null or viewport == null:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var delay := create_tween()
	delay.tween_interval(maxf(0.1, after))
	delay.tween_callback(_capture_screenshot.bind(player, viewport, path))


func audit_partitions(run_seed: int) -> void:
	for theme in WorldGen.THEMES:
		var world_seed := WorldGen.level_seed(run_seed, theme)
		var splits := 0
		var old_bad := 0
		var new_bad := 0
		var dropped := 0
		for cx in range(-30, 31):
			for cz in range(-30, 31):
				var cell := Vector2i(cx, cz)
				var split := WorldGen.room_split(world_seed,
					WorldGen.room_id(world_seed, cell), theme)
				if split.is_empty() \
						or WorldGen.room_id(world_seed, cell) != cell:
					continue
				splits += 1
				var axis_x: bool = split[0]
				var wanted: float = split[1]
				var blocked := WorldGen.crossing_openings(
					world_seed, cell, theme, axis_x)
				for opening in blocked:
					if absf(wanted - opening.x) < opening.y:
						old_bad += 1
						if old_bad <= 3:
							print("   was-broken cell %s  (centre %.0f, %.0f)" % [
								cell,
								cell.x * WorldGen.CELL_SIZE \
									+ WorldGen.CELL_SIZE * 0.5,
								cell.y * WorldGen.CELL_SIZE \
									+ WorldGen.CELL_SIZE * 0.5])
						break
				var placed := WorldGen.partition_offset(
					world_seed, cell, theme, axis_x, wanted)
				if placed < 0.0:
					axis_x = not axis_x
					placed = WorldGen.partition_offset(
						world_seed, cell, theme, axis_x, wanted)
					blocked = WorldGen.crossing_openings(
						world_seed, cell, theme, axis_x)
				if placed < 0.0:
					dropped += 1
					continue
				for opening in blocked:
					if absf(placed - opening.x) < opening.y:
						new_bad += 1
						break
		print("theme %d: %d partitions | split a doorway BEFORE: %d | NOW: %d | skipped: %d" % [
			theme, splits, old_bad, new_bad, dropped])


func _print_report() -> void:
	if _steps.size() > 10:
		var minimum := 1e9
		var maximum := 0.0
		var sum := 0.0
		for value in _steps:
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			sum += value
		var average := sum / float(_steps.size())
		var stalled := 0
		for value in _steps:
			if value < average * 0.25:
				stalled += 1
		print("  per-frame CAMERA move: avg %.4fm  min %.4f  max %.4f  (max/avg %.2fx)  stalled frames %d/%d" % [
			average, minimum, maximum, maximum / maxf(average, 0.0001),
			stalled, _steps.size()])
		_steps.clear()
	print("fps %.1f | frame avg %.2fms worst %.2fms | frames over 18ms: %d/%d | physics %d Hz" % [
		float(_frames) / _elapsed, 1000.0 * _elapsed / float(_frames),
		1000.0 * _worst, _slow, _frames, Engine.physics_ticks_per_second])
	print("  render stress: CPU process worst %.2fms, physics worst %.2fms | draws %d, primitives %d | collision pairs %d" % [
		1000.0 * _process_worst, 1000.0 * _physics_worst,
		_draws_max, _primitives_max, _collision_pairs_max])
	print("  memory/object deltas: static %+.1f KiB (peak %+.1f), nodes %+d, resources %+d | video %.1f MiB" % [
		float(int(Performance.get_monitor(Performance.MEMORY_STATIC)) \
			- _static_start) / 1024.0,
		float(_static_peak - _static_start) / 1024.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - _nodes_start,
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) \
			- _resources_start,
		float(_vram_max) / (1024.0 * 1024.0)])


func _reset_monitors() -> void:
	_process_worst = 0.0
	_physics_worst = 0.0
	_draws_max = 0
	_primitives_max = 0
	_collision_pairs_max = 0
	_static_start = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	_static_peak = _static_start
	_nodes_start = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_resources_start = int(Performance.get_monitor(
		Performance.OBJECT_RESOURCE_COUNT))
	_vram_max = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))


func _sample_monitors() -> void:
	_process_worst = maxf(_process_worst,
		float(Performance.get_monitor(Performance.TIME_PROCESS)))
	_physics_worst = maxf(_physics_worst,
		float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)))
	_draws_max = maxi(_draws_max,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_primitives_max = maxi(_primitives_max,
		int(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_collision_pairs_max = maxi(_collision_pairs_max,
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)))
	_static_peak = maxi(_static_peak,
		int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_vram_max = maxi(_vram_max,
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))


func _capture_screenshot(player: Player, viewport: Viewport,
		path: String) -> void:
	print("player at ", player.global_position)
	viewport.get_texture().get_image().save_png(path)
	get_tree().quit()
