extends SceneTree
## Verifies that every active painting appears across its intended themes,
## preserves aspect ratio, fits its wall, never mounts over an opening, and
## remains clear of any resolved interior partition that meets that wall.
## New Liminal Inc. posters stay out of Vegas/Poolrooms, and Airport poster
## lightboxes must preserve the exact printed artwork rather than stretch it.
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
	var office_acs := 0
	var office_art_conflicts := 0
	var filing_cabinets := 0
	var filing_drawers := 0
	var exit_alarms := 0
	var airport_lightboxes := 0
	var airport_lightbox_paths := {}
	for si in seed_count:
		# Seed zero is the reported Office regression; the remaining entries
		# retain the broad deterministic corpus.
		var base := 1065674081 if si == 0 \
			else WorldGen.h(972241, si * 43, si * 79, 2309) | 1
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var chunk := Chunk.new(ws, Vector2i(x, z), theme)
					chunks += 1
					var report := chunk.wall_art_audit()
					var mounts := chunk.office_wall_mount_audit()
					var filing := chunk.filing_bank_audit()
					var exits := chunk.exit_sign_fixture_audit()
					var lightboxes := chunk.airport_poster_lightbox_audit()
					var count := int(report["mounts"])
					theme_mounts[theme] = int(theme_mounts.get(theme, 0)) + count
					violations += int(report["violations"])
					violations += int(mounts["violations"])
					violations += int(filing["violations"])
					violations += int(exits["violations"])
					violations += int(lightboxes["violations"])
					if int(mounts["violations"]) + int(filing["violations"]) \
							+ int(exits["violations"]) > 0 and violations <= 24:
						print("FAIL base=%d theme=%d cell=%s mounts=%s filing=%s exits=%s" % [
							base, theme, Vector2i(x, z), mounts, filing, exits])
					office_acs += int(mounts["air_conditioners"])
					office_art_conflicts += int(mounts["art_conflicts"])
					filing_cabinets += int(filing["cabinets"])
					filing_drawers += int(filing["open_drawers"])
					exit_alarms += int(exits["alarms"])
					airport_lightboxes += int(lightboxes["lightboxes"])
					for path in lightboxes["paths"]:
						airport_lightbox_paths[path] = int(
							airport_lightbox_paths.get(path, 0)) \
							+ int(lightboxes["paths"][path])
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
	for theme in [0, 1, 2, 4, 5, 6, 7, 8]:
		if int(theme_mounts.get(theme, 0)) == 0:
			missing += 1
			print("FAIL — theme %d never generated wall art" % theme)
	var allowed := {
		1: Chunk.POSTER_OFFICE,
		2: Chunk.POSTER_ANNEX,
		4: Chunk.POSTER_AIRPORT,
		5: Chunk.POSTER_ASYLUM,
		6: Chunk.POSTER_SCHOOL,
		7: Chunk.POSTER_MALL,
		8: Chunk.POSTER_PRISON,
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
	for path in Chunk.POSTER_AIRPORT:
		if int(airport_lightbox_paths.get(path, 0)) == 0:
			missing += 1
			print("FAIL — Airport poster never reached a lightbox: %s" % path)
	print("wall-art audit: %d seeds, radius %d, %d chunks" % [
		seed_count, radius, chunks])
	print("  mounts by theme: %s" % [theme_mounts])
	print("  paintings exercised: %d/%d | mounting/aspect violations: %d" % [
		paths.size(), Chunk.WALL_ART_ALL.size(), violations])
	print("  Office ACs: %d | art conflicts: %d | filing cabinets/drawers: %d/%d" % [
		office_acs, office_art_conflicts, filing_cabinets, filing_drawers])
	print("  physical EXIT alarms: %d" % exit_alarms)
	print("  Airport poster lightboxes: %d | designs: %d/%d" % [
		airport_lightboxes, airport_lightbox_paths.size(),
		Chunk.POSTER_AIRPORT.size()])
	if office_acs == 0 or filing_cabinets == 0 or filing_drawers == 0 \
			or exit_alarms == 0 or airport_lightboxes == 0:
		missing += 1
		print("FAIL — fixture corpus did not exercise every regression target")
	if violations + missing == 0:
		print("  PASS — art, ACs, filing drawers, and EXIT alarms are clear and visible")
	quit(0 if violations + missing == 0 else 1)
