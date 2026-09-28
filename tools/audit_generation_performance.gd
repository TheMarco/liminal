extends SceneTree
## Controlled headless smoke gate for the historically expensive
## builders. One-time compilation is explicitly prewarmed behind the same
## transition boundary production uses; only in-play steady construction is
## measured.

const SEED := 240721
const RADIUS := 2
const LIMITS := {
	0: {"p95": 20.0, "max": 35.0},
	2: {"p95": 20.0, "max": 35.0},
	4: {"p95": 20.0, "max": 35.0},
	11: {"p95": 25.0, "max": 45.0},
}

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for theme in [0, 2, 4, 11]:
		var ws := WorldGen.level_seed(SEED, theme)
		Chunk.prepare_floor_resources(theme)
		Chunk.prewarm_theme_content(ws, theme)
		# Prime the exact sample once; the measured pass represents revisiting or
		# streaming after the transition's resource compilation boundary.
		_build_sample(ws, theme, false)
		var times := _build_sample(ws, theme, true)
		times.sort()
		var p95: float = times[clampi(
			ceili(float(times.size()) * 0.95) - 1, 0, times.size() - 1)]
		var maximum: float = times[-1]
		var limit: Dictionary = LIMITS[theme]
		print("generation performance theme %d: p95 %.2fms max %.2fms" % [
			theme, p95, maximum])
		if p95 > float(limit["p95"]) or maximum > float(limit["max"]):
			failures.append("theme %d exceeded p95/max ceiling: %.2f/%.2fms" % [
				theme, p95, maximum])
		if theme in [0, 4]:
			await _stream_sample(ws, theme, false)
			await _stream_sample(ws, theme, true)
	Chunk.clear_runtime_caches()
	Mats.clear_runtime_caches()
	await process_frame
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("generation performance audit: PASS")
		quit()
	else:
		quit(1)


func _build_sample(ws: int, theme: int, measured: bool) -> Array[float]:
	var times: Array[float] = []
	for y in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var started := Time.get_ticks_usec()
			var chunk := Chunk.new(ws, Vector2i(x, y), theme)
			var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
			chunk.free()
			if measured:
				times.append(elapsed)
	return times


## Match the out-and-back route that exposed the Airport decode tail. This
## measures ChunkManager CPU work only, not rendering or a minimum-spec FPS.
func _stream_sample(ws: int, theme: int, measured: bool) -> void:
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.position = Vector3(6.0, 1.7, 6.0)
	var manager := ChunkManager.new()
	manager.theme = theme
	manager.world_seed = ws
	manager.player = player
	root.add_child(manager)
	manager.set_process(false)
	manager.warm_up(Vector2i.ZERO)
	var samples: Array[float] = []
	for step in 1200:
		var outwards := step < 600
		player.position.x = 6.0 + (step if outwards else 1200 - step) * 0.1
		player.velocity = Vector3(6.0 if outwards else -6.0, 0.0, 0.0)
		var started := Time.get_ticks_usec()
		manager._process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if step % 10 == 0:
			await process_frame
	if measured:
		samples.sort()
		print("streaming performance theme %d: p95 %.2fms max %.2fms" % [theme, samples[1139], samples[-1]])
		if samples[1139] > 10.0 or samples[-1] > 25.0:
			failures.append("theme %d streaming exceeded 10/25ms p95/max ceiling: %.2f/%.2fms" % [theme, samples[1139], samples[-1]])
	manager.free()
	player.free()
	await process_frame
