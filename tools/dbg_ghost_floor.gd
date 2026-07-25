extends SceneTree
## Dev: exercise the shadow-figure floor probe against real furnished chunks and
## report where it says the ground is. A figure is only ever as well-placed as
## this raycast: if it returns a table top or a sewer channel invert, the figure
## stands on the furniture or sinks into the trench, which reads as a scale bug
## rather than as a placement one.
##
## Run: godot --headless --path . --script tools/dbg_ghost_floor.gd -- [seeds]

const SAMPLES := 40


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 4, 1, 16)
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var per_theme := {}
	for si in seed_count:
		var base := WorldGen.h(90210, si * 13, si * 29, 77) | 1
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-2, 3):
				for z in range(-2, 3):
					var c := Vector2i(x, z)
					if WorldGen.room_id(ws, c) != c:
						continue
					var chunk := Chunk.new(ws, c, theme)
					chunk.position = Vector3(float(x) * Chunk.S, 0.0,
						float(z) * Chunk.S)
					root.add_child(chunk)
					await physics_frame
					_probe(root, chunk.position, theme, per_theme)
					root.remove_child(chunk)
					chunk.free()
	print("ghost floor probe: %d seeds" % seed_count)
	print("  theme | probes | on real floor | on furniture | sunk | rejected")
	var bad_total := 0
	for theme in WorldGen.THEMES:
		var d: Dictionary = per_theme.get(theme, {})
		var n := int(d.get("n", 0))
		if n == 0:
			continue
		bad_total += int(d.get("high", 0)) + int(d.get("low", 0))
		print("  %5d | %6d | %13d | %12d | %4d | %8d" % [theme, n,
			int(d.get("ok", 0)), int(d.get("high", 0)), int(d.get("low", 0)),
			int(d.get("miss", 0))])
	print()
	print("  figures placed above 0.25m (standing on furniture) or below -0.30m")
	print("  (sunk into a trench): %d" % bad_total)
	quit()


func _probe(root: Node3D, origin: Vector3, theme: int, per_theme: Dictionary) -> void:
	var space := root.get_world_3d().direct_space_state
	var d: Dictionary = per_theme.get(theme, {})
	for i in SAMPLES:
		var p := origin + Vector3(randf_range(1.5, Chunk.S - 1.5), 0.0,
			randf_range(1.5, Chunk.S - 1.5))
		d["n"] = int(d.get("n", 0)) + 1
		# mirrors ShadowFigures._floor_at: drop through furniture to real floor
		var bottom := p + Vector3(0, -2.0, 0)
		var from := p + Vector3(0, 2.6, 0)
		var got := Vector3.INF
		for pierce in 6:
			var q := PhysicsRayQueryParameters3D.create(from, bottom)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var hp: Vector3 = hit["position"]
			if hit["normal"].y >= 0.8 and absf(hp.y - origin.y) <= 0.34:
				got = hp
				break
			if hp.y <= bottom.y + 0.01:
				break
			from = hp - Vector3(0, 0.03, 0)
		if got == Vector3.INF:
			d["miss"] = int(d.get("miss", 0)) + 1
			continue
		var hy: float = got.y - origin.y
		if false:
			d["high"] = int(d.get("high", 0)) + 1
		elif hy < -0.30:
			d["low"] = int(d.get("low", 0)) + 1
		else:
			d["ok"] = int(d.get("ok", 0)) + 1
	per_theme[theme] = d
