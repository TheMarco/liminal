extends SceneTree
## Verifies that every active painting appears across its intended themes,
## preserves aspect ratio, fits its wall, never mounts over an opening, and
## remains clear of any resolved interior partition that meets that wall.
## Sewers must remain art-free; office art is restricted to its B&W portraits.
## Run: godot --headless --path . --script tools/audit_wall_art.gd -- [seeds] [radius]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 10, 1, 24)
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 3, 10)
	var paths := {}
	var theme_paths := {}
	var theme_mounts := {}
	var violations := 0
	var chunks := 0
	for si in seed_count:
		var base := WorldGen.h(972241, si * 43, si * 79, 2309) | 1
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var chunk := Chunk.new(ws, Vector2i(x, z), theme)
					chunks += 1
					var report := chunk.wall_art_audit()
					var count := int(report["mounts"])
					theme_mounts[theme] = int(theme_mounts.get(theme, 0)) + count
					violations += int(report["violations"])
					for path in report["paths"]:
						paths[path] = int(paths.get(path, 0)) \
							+ int(report["paths"][path])
						if not theme_paths.has(theme):
							theme_paths[theme] = {}
						theme_paths[theme][path] = \
							int(theme_paths[theme].get(path, 0)) \
							+ int(report["paths"][path])
					chunk.free()
	var missing := 0
	for path in Chunk.WALL_ART_ALL:
		if int(paths.get(path, 0)) == 0:
			missing += 1
			print("FAIL — painting never generated: %s" % path)
	for theme in [0, 1, 4, 5, 6, 7, 8]:
		if int(theme_mounts.get(theme, 0)) == 0:
			missing += 1
			print("FAIL — theme %d never generated wall art" % theme)
	if int(theme_mounts.get(2, 0)) != 0:
		missing += int(theme_mounts.get(2, 0))
		print("FAIL — sewer generated %d forbidden paintings" % theme_mounts.get(2, 0))
	var allowed := {
		1: Chunk.ART_OFFICE,
		4: Chunk.ART_AIRPORT + Chunk.ART_MALL + Chunk.ART_RANDOM,
		8: Chunk.ART_PRISON + Chunk.ART_AIRPORT + Chunk.ART_RANDOM,
	}
	for theme in allowed:
		for path in theme_paths.get(theme, {}):
			if not allowed[theme].has(path):
				missing += 1
				print("FAIL — theme %d generated disallowed art: %s" % [theme, path])
	for theme in theme_paths:
		for path in theme_paths[theme]:
			if Chunk.ART_SEWER.has(path):
				missing += 1
				print("FAIL — retired sewer art generated in theme %d: %s" % [
					theme, path])
	print("wall-art audit: %d seeds, radius %d, %d chunks" % [
		seed_count, radius, chunks])
	print("  mounts by theme: %s" % [theme_mounts])
	print("  paintings exercised: %d/%d | mounting/aspect violations: %d" % [
		paths.size(), Chunk.WALL_ART_ALL.size(), violations])
	if violations + missing == 0:
		print("  PASS — every painting is wall-mounted, in-bounds, and undistorted")
	quit(0 if violations + missing == 0 else 1)
