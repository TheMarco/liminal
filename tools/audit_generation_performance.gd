extends SceneTree
## Controlled headless smoke gate for the two historically frame-breaking
## builders. One-time compilation is explicitly prewarmed behind the same
## transition boundary production uses; only in-play steady construction is
## measured.

const SEED := 240721
const RADIUS := 2
const LIMITS := {
	2: {"p95": 20.0, "max": 35.0},
	11: {"p95": 25.0, "max": 45.0},
}

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	for theme in [2, 11]:
		var ws := WorldGen.level_seed(SEED, theme)
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
