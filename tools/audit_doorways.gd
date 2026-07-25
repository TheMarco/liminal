extends SceneTree
## Builds furnished room anchors across every theme and verifies that no
## generated prop mesh or collider survives inside a real doorway's approach
## lane. It also enforces that school chalk stays parented to a board on a
## solid edge, and that no terminal can survive without its supporting desk.
## Locked facade doors are deliberately outside this contract.
## Run: godot --headless --path . --script tools/audit_doorways.gd -- [seeds] [radius]


func _level_seed(base: int, theme: int) -> int:
	return WorldGen.level_seed(base, theme)


func _room_has_door(ws: int, root: Vector2i, theme: int) -> bool:
	for x in range(root.x - 1, root.x + 2):
		for z in range(root.y - 1, root.y + 2):
			var c := Vector2i(x, z)
			if WorldGen.room_id(ws, c) != root:
				continue
			for dir in 4:
				var edge := WorldGen.edge_info(ws, c, dir, theme)
				if not edge["wall"] and not edge["full_open"]:
					return true
	return false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 6, 1, 24)
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 2, 12)
	var rooms := 0
	var culled := 0
	var failures := 0
	var chalk_failures := 0
	var terminal_failures := 0
	var stationery_failures := 0
	var projector_screens := 0
	var projector_failures := 0
	var orphan_exit_failures := 0
	var airport_apron_setpieces := 0
	var airport_apron_failures := 0
	var school_carts := 0
	var school_stalls := 0
	var school_fixture_failures := 0
	var asylum_authored := {}
	var authored_census := {}
	var asylum_failures := 0
	var per_theme := {}
	for si in seed_count:
		var base := WorldGen.h(421337, si * 29, si * 47, 2011) | 1
		for theme in WorldGen.THEMES:
			var ws := _level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var c := Vector2i(x, z)
					if WorldGen.room_id(ws, c) != c or WorldGen.corridor(ws, c) != 0 \
							or not _room_has_door(ws, c, theme):
						continue
					var chunk := Chunk.new(ws, c, theme)
					rooms += 1
					culled += chunk.doorway_props_removed
					per_theme[theme] = int(per_theme.get(theme, 0)) + chunk.doorway_props_removed
					var bad := chunk.doorway_clearance_violations()
					var chalk_bad := chunk.school_chalkboard_violations()
					var terminal_bad := chunk.terminal_support_violations()
					var stationery_bad := chunk.school_stationery_support_violations()
					var projector_report := chunk.school_projector_screen_audit()
					var projector_bad := int(projector_report["violations"])
					var orphan_exit_bad := chunk.orphan_exit_label_violations()
					var airport_report := chunk.airport_apron_setpiece_audit()
					var airport_bad := int(airport_report["violations"])
					var school_report := chunk.school_fixture_integrity_audit()
					var school_bad := int(school_report["violations"])
					var census := chunk.authored_furnishing_counts()
					for kind in census:
						authored_census[kind] = int(authored_census.get(kind, 0)) \
							+ int(census[kind])
					var asylum_report := chunk.asylum_authored_audit()
					asylum_failures += int(asylum_report["violations"])
					for key in asylum_report:
						if key == "violations":
							continue
						asylum_authored[key] = int(asylum_authored.get(key, 0)) \
							+ int(asylum_report[key])
					chalk_failures += chalk_bad
					terminal_failures += terminal_bad
					stationery_failures += stationery_bad
					projector_screens += int(projector_report["screens"])
					projector_failures += projector_bad
					orphan_exit_failures += orphan_exit_bad
					airport_apron_setpieces += int(airport_report["setpieces"])
					airport_apron_failures += airport_bad
					school_carts += int(school_report["carts"])
					school_stalls += int(school_report["stalls"])
					school_fixture_failures += school_bad
					if bad > 0:
						failures += bad
						if failures <= 12:
							print("FAIL seed=%d theme=%d cell=%s style=%d overlaps=%d" % [
								base, theme, c, WorldGen.cell_style(ws, c, theme), bad])
					if chalk_bad > 0:
						failures += chalk_bad
						if failures <= 12:
							print("FAIL seed=%d school cell=%s orphan/invalid chalk=%d" % [
								base, c, chalk_bad])
					if terminal_bad > 0:
						failures += terminal_bad
						if failures <= 12:
							print("FAIL seed=%d office cell=%s unsupported terminals=%d" % [
								base, c, terminal_bad])
					if stationery_bad > 0:
						failures += stationery_bad
						if failures <= 12:
							print("FAIL seed=%d school cell=%s unsupported stationery=%d" % [
								base, c, stationery_bad])
					if projector_bad > 0:
						failures += projector_bad
						if failures <= 12:
							print("FAIL seed=%d school cell=%s invalid projector screens=%d" % [
								base, c, projector_bad])
					if orphan_exit_bad > 0:
						failures += orphan_exit_bad
						if failures <= 12:
							print("FAIL seed=%d theme=%d cell=%s orphan EXIT labels=%d" % [
								base, theme, c, orphan_exit_bad])
					if airport_bad > 0:
						failures += airport_bad
						if failures <= 12:
							print("FAIL seed=%d airport cell=%s apron overflow meshes=%d" % [
								base, c, airport_bad])
					if school_bad > 0:
						failures += school_bad
						if failures <= 12:
							print("FAIL seed=%d school cell=%s incomplete/transparent fixtures=%d" % [
								base, c, school_bad])
					chunk.free()
	print("doorway furnishing audit: %d seeds, radius %d, %d furnished rooms" % [
		seed_count, radius, rooms])
	print("  removed %d blocking prop pieces/pivots and colliders | by theme %s" % [
		culled, per_theme])
	print("  school orphan/invalid chalk labels: %d" % chalk_failures)
	print("  unsupported school desk stationery: %d" % stationery_failures)
	print("  mounted school projector screens: %d | invalid: %d" % [
		projector_screens, projector_failures])
	print("  orphan EXIT labels: %d" % orphan_exit_failures)
	print("  unsupported office terminals: %d" % terminal_failures)
	print("  enclosed airport apron setpieces: %d | overflow meshes: %d" % [
		airport_apron_setpieces, airport_apron_failures])
	print("  opaque school carts: %d | complete bathroom stalls: %d | violations: %d" % [
		school_carts, school_stalls, school_fixture_failures])
	print("  asylum authored furniture %s | violations: %d" % [
		asylum_authored, asylum_failures])
	print("  authored furnishings placed %s" % [authored_census])
	if projector_screens == 0:
		failures += 1
		print("FAIL — school projector fixture audit was not exercised")
	if airport_apron_setpieces == 0:
		failures += 1
		print("FAIL — airport apron containment audit was not exercised")
	if school_carts == 0 or school_stalls == 0:
		failures += 1
		print("FAIL — school cart/stall integrity audit was not fully exercised")
	failures += asylum_failures
	# Every downloaded model has to actually reach the rooms it was chosen for.
	for kind in ["blackjack_table", "roulette_table", "hotdog_stand",
			"autopsy_table", "office_printer", "school_desk", "office_phone"]:
		if int(authored_census.get(kind, 0)) == 0:
			failures += 1
			print("FAIL — no %s were placed" % kind)
	# The authored hospital furniture is the asylum's whole furnishing pass now;
	# silence here would mean the models stopped reaching the rooms at all.
	for required in ["beds", "gurneys", "trolleys", "baths", "sinks",
			"casing_leaves"]:
		if int(asylum_authored.get(required, 0)) == 0:
			failures += 1
			print("FAIL — no authored asylum %s were placed" % required)
	if failures == 0:
		print("  PASS — approaches clear; chalk, stationery and terminals retain their supports")
	else:
		print("  FAIL — %d doorway approach overlaps remain" % failures)
	quit(0 if failures == 0 else 1)
