extends SceneTree
## Warm-cache generation profiler. It builds real Chunk scenes, counts their
## render/physics nodes, and also samples one landmark per floor.
## Run:
##   godot --headless --path . --script tools/profile_generation.gd

const SEED := 240721
const RADIUS := 2
const LANDMARK_SEARCH := 80


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("GENERATION PROFILE | seed %d | %dx%d background-preloaded cells per floor" %
		[SEED, RADIUS * 2 + 1, RADIUS * 2 + 1])
	# Match the game: workers start decoding glTF resources while the title is
	# visible. A short grace period here keeps the profile focused on streaming.
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	# Prime each theme's common construction path and scene instantiation.
	for theme in WorldGen.THEMES:
		var warm := Chunk.new(_theme_seed(theme), Vector2i.ZERO, theme)
		warm.free()
	for theme in WorldGen.THEMES:
		_profile_theme(theme, "first", true)
		_profile_theme(theme, "steady", false)
	print("PROFILE COMPLETE")
	quit()


func _theme_seed(theme: int) -> int:
	if theme == 0:
		return SEED
	var salt := 348039917
	if theme == 2: salt = 715827883
	elif theme == 4: salt = 536870923
	elif theme == 5: salt = 998244353
	elif theme == 6: salt = 179424673
	return ((SEED ^ salt) & 0x7FFFFFFF) | 1


func _profile_theme(theme: int, pass_name: String, sample_landmark: bool) -> void:
	var ws := _theme_seed(theme)
	var times: Array[float] = []
	var totals := {"nodes": 0, "meshes": 0, "colliders": 0, "lights": 0,
		"probes": 0, "fog_volumes": 0}
	var worst_nodes := 0
	var worst_cell := Vector2i.ZERO
	var slowest_ms := 0.0
	var slowest_cell := Vector2i.ZERO
	var slowest_style := -1
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var cell := Vector2i(x, z)
			var t0 := Time.get_ticks_usec()
			var chunk := Chunk.new(ws, cell, theme)
			var elapsed := float(Time.get_ticks_usec() - t0) / 1000.0
			times.append(elapsed)
			if elapsed > slowest_ms:
				slowest_ms = elapsed
				slowest_cell = cell
				slowest_style = chunk.style
			var counts := _count_nodes(chunk)
			for key in totals:
				totals[key] += counts[key]
			if counts["nodes"] > worst_nodes:
				worst_nodes = counts["nodes"]
				worst_cell = cell
			chunk.free()
	times.sort()
	var sum := 0.0
	for ms in times:
		sum += ms
	var n := times.size()
	var p95: float = times[clampi(ceili(float(n) * 0.95) - 1, 0, n - 1)]
	print("theme %d %-6s | build avg %.2fms p95 %.2fms max %.2fms @ %s style %d | avg nodes %.0f meshes %.0f colliders %.0f lights %.1f probes %.2f fog %.1f | node peak %d @ %s" % [
		theme, pass_name, sum / float(n), p95, times[-1], slowest_cell, slowest_style,
		float(totals["nodes"]) / n, float(totals["meshes"]) / n,
		float(totals["colliders"]) / n, float(totals["lights"]) / n,
		float(totals["probes"]) / n, float(totals["fog_volumes"]) / n,
		worst_nodes, worst_cell])
	if not sample_landmark:
		return
	var lm := _find_landmark(ws, theme)
	if lm != Vector2i(999999, 999999):
		var t1 := Time.get_ticks_usec()
		var landmark_chunk := Chunk.new(ws, lm, theme)
		var lm_ms := float(Time.get_ticks_usec() - t1) / 1000.0
		var lc := _count_nodes(landmark_chunk)
		print("  landmark %s style %d | %.2fms | %s" %
			[lm, landmark_chunk.style, lm_ms, lc])
		landmark_chunk.free()


func _find_landmark(ws: int, theme: int) -> Vector2i:
	for ring in range(1, LANDMARK_SEARCH + 1):
		for x in range(-ring, ring + 1):
			for z in [-ring, ring]:
				var c := Vector2i(x, z)
				if WorldGen.room_id(ws, c) == c and WorldGen.landmark_style(ws, c, theme) >= 0:
					return c
		for z in range(-ring + 1, ring):
			for x in [-ring, ring]:
				var c := Vector2i(x, z)
				if WorldGen.room_id(ws, c) == c and WorldGen.landmark_style(ws, c, theme) >= 0:
					return c
	return Vector2i(999999, 999999)


func _count_nodes(root: Node) -> Dictionary:
	var out := {"nodes": 1, "meshes": 0, "colliders": 0, "lights": 0,
		"probes": 0, "fog_volumes": 0}
	if root is MeshInstance3D: out["meshes"] += 1
	if root is CollisionShape3D: out["colliders"] += 1
	if root is Light3D: out["lights"] += 1
	if root is ReflectionProbe: out["probes"] += 1
	if root is FogVolume: out["fog_volumes"] += 1
	for child in root.get_children():
		var sub := _count_nodes(child)
		for key in out:
			out[key] += sub[key]
	return out
