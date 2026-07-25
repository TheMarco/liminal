extends SceneTree
## Builds the mall and prison across many seeds and checks every generated room
## style for atomic furniture support, doorway clearance, and collision cleanup.
## Run: godot --headless --path . --script tools/audit_new_levels.gd -- [seeds] [radius]

const EXPECTED := {
	7: [WorldGen.MALL_CORRIDOR, WorldGen.MALL_STORE, WorldGen.MALL_ANCHOR,
		WorldGen.MALL_FOODCOURT, WorldGen.MALL_ATRIUM, WorldGen.MALL_SERVICE,
		WorldGen.MALL_KIOSKS, WorldGen.MALL_CINEMA],
	8: [WorldGen.PRISON_CORRIDOR, WorldGen.PRISON_CELLBLOCK,
		WorldGen.PRISON_CELLS, WorldGen.PRISON_MESS, WorldGen.PRISON_SHOWER,
		WorldGen.PRISON_GUARD, WorldGen.PRISON_INDUSTRY,
		WorldGen.PRISON_VISITATION, WorldGen.PRISON_ROTUNDA],
}

const REQUIRED_ENRICHMENT := {
	7: ["shopping_cart", "CashRegister_01", "hand_truck",
		"industrial_storage_cart", "metal_trash_can"],
	8: ["double_bunk", "detention_toilet_sink", "detention_shower_head",
		"cell_personal_effects", "sanitation_clutter",
		"industrial_storage_cart", "metal_trash_can", "visitation_phone"],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 12, 1, 32)
	var radius := clampi(int(args[1]) if args.size() > 1 else 8, 3, 14)
	var built := 0
	var support_failures := 0
	var doorway_failures := 0
	var mall_fixture_failures := 0
	var mall_store_signs := 0
	var mall_painted_signs := 0
	var mall_payphones := 0
	var mall_directories := 0
	var mall_exit_signs := 0
	var mall_foodcourt_brands := 0
	var prison_cell_fixture_failures := 0
	var prison_bunks := 0
	var prison_toilets := 0
	var prison_authored_bunks := 0
	var prison_authored_toilets := 0
	var prison_phone_booths := 0
	var prison_phones := 0
	var prison_phone_failures := 0
	var prison_locked_door_facades := 0
	var prison_interactive_door_leaves := 0
	var prison_door_model_failures := 0
	var exit_housings := {7: 0, 8: 0}
	var exit_fixture_failures := 0
	var styles_seen := {7: {}, 8: {}}
	var enrichment_seen := {7: {}, 8: {}}
	for si in seed_count:
		var base := WorldGen.h(731923, si * 37, si * 71, 2307) | 1
		for theme in [7, 8]:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var c := Vector2i(x, z)
					# One anchor builds shared room furniture; corridor cells and
					# non-anchor cellblock members have their own local structures.
					var style := WorldGen.cell_style(ws, c, theme)
					var local_builder: bool = WorldGen.corridor(ws, c) != 0 \
						or (theme == 8 and style == WorldGen.PRISON_CELLBLOCK)
					if WorldGen.room_id(ws, c) != c and not local_builder:
						continue
					var chunk := Chunk.new(ws, c, theme)
					built += 1
					styles_seen[theme][style] = int(styles_seen[theme].get(style, 0)) + 1
					var support_bad := chunk.atomic_furnishing_support_violations()
					var doorway_bad := chunk.doorway_clearance_violations()
					var exit_report := chunk.exit_sign_fixture_audit()
					support_failures += support_bad
					doorway_failures += doorway_bad
					exit_housings[theme] += int(exit_report["housings"])
					exit_fixture_failures += int(exit_report["violations"])
					var props := chunk.enrichment_prop_counts()
					for prop in props:
						enrichment_seen[theme][prop] = \
							int(enrichment_seen[theme].get(prop, 0)) + int(props[prop])
					if theme == 7:
						var mall_report := chunk.mall_fixture_audit()
						mall_fixture_failures += int(mall_report["violations"])
						mall_store_signs += int(mall_report["store_signs"])
						mall_painted_signs += int(mall_report["painted_signs"])
						mall_payphones += int(mall_report["payphones"])
						mall_directories += int(mall_report["directories"])
						mall_exit_signs += int(mall_report["exit_signs"])
						mall_foodcourt_brands += int(mall_report["foodcourt_brands"])
						if int(mall_report["violations"]) > 0 \
								and mall_fixture_failures <= 12:
							print("FAIL seed=%d mall cell=%s style=%d fixtures=%s" % [
								base, c, style, mall_report])
					else:
						var prison_report := chunk.prison_cell_fixture_audit()
						prison_cell_fixture_failures += int(prison_report["violations"])
						prison_bunks += int(prison_report["bunks"])
						prison_toilets += int(prison_report["toilets"])
						prison_authored_bunks += int(prison_report["authored_bunks"])
						prison_authored_toilets += int(prison_report["authored_toilets"])
						var phone_report := chunk.prison_visitation_phone_audit()
						prison_phone_booths += int(phone_report["booths"])
						prison_phones += int(phone_report["phones"])
						prison_phone_failures += int(phone_report["violations"])
						var door_report := chunk.prison_authored_door_audit()
						prison_locked_door_facades += int(door_report["locked_facades"])
						prison_interactive_door_leaves += int(
							door_report["interactive_leaves"])
						prison_door_model_failures += int(
							door_report["violations"])
					if support_bad + doorway_bad > 0 and \
							support_failures + doorway_failures <= 12:
						print("FAIL seed=%d theme=%d cell=%s style=%d support=%d doorway=%d" % [
							base, theme, c, style, support_bad, doorway_bad])
					if int(exit_report["violations"]) > 0 and exit_fixture_failures <= 12:
						print("FAIL seed=%d theme=%d cell=%s EXIT fixture=%s" % [
							base, theme, c, exit_report])
					chunk.free()
	var missing := 0
	for theme in [7, 8]:
		for style in EXPECTED[theme]:
			if not styles_seen[theme].has(style):
				missing += 1
				print("FAIL theme=%d never generated style=%d" % [theme, style])
		for prop in REQUIRED_ENRICHMENT[theme]:
			if int(enrichment_seen[theme].get(prop, 0)) <= 0:
				missing += 1
				print("FAIL theme=%d never emitted enrichment=%s" % [theme, prop])
	print("new-level furnishing audit: %d seeds, radius %d, %d chunks" % [
		seed_count, radius, built])
	print("  mall styles %s" % [styles_seen[7]])
	print("  prison styles %s" % [styles_seen[8]])
	print("  mall enrichment %s" % [enrichment_seen[7]])
	print("  prison enrichment %s" % [enrichment_seen[8]])
	print("  unsupported/orphaned assemblies: %d | doorway overlaps: %d" % [
		support_failures, doorway_failures])
	print("  mall store signs: %d generated + %d painted | mounted exit signs: %d | fixture violations: %d" % [
		mall_store_signs, mall_painted_signs, mall_exit_signs,
		mall_fixture_failures])
	print("  coherent food-court vendor brands: %d" % mall_foodcourt_brands)
	print("  cell-only prison bunks: %d | toilets: %d | context violations: %d" % [
		prison_bunks, prison_toilets, prison_cell_fixture_failures])
	print("  authored cell models: bunks=%d | toilets=%d" % [
		prison_authored_bunks, prison_authored_toilets])
	print("  visitation booths: %d | recognisable phones: %d | violations: %d" % [
		prison_phone_booths, prison_phones, prison_phone_failures])
	print("  authored prison doors: locked=%d | interactive=%d | violations=%d" % [
		prison_locked_door_facades, prison_interactive_door_leaves,
		prison_door_model_failures])
	print("  complete mounted EXIT fixtures: mall=%d prison=%d | violations: %d" % [
		exit_housings[7], exit_housings[8], exit_fixture_failures])
	var failures := support_failures + doorway_failures + mall_fixture_failures \
		+ prison_cell_fixture_failures + prison_phone_failures \
		+ prison_door_model_failures + exit_fixture_failures + missing
	print("  authored mall fixtures: payphones=%d directories=%d" % [
		mall_payphones, mall_directories])
	if mall_painted_signs == 0:
		failures += 1
		print("FAIL — no painted storefront fascias were placed")
	if mall_payphones == 0 or mall_directories == 0:
		failures += 1
		print("FAIL — authored payphone/directory models did not import")
	if mall_store_signs == 0 or mall_exit_signs == 0:
		failures += 1
		print("FAIL — mall fixture audit did not exercise both sign types")
	if mall_foodcourt_brands == 0:
		failures += 1
		print("FAIL — mall food-court brand audit was not exercised")
	if prison_bunks == 0 or prison_toilets == 0 \
			or prison_authored_bunks != prison_bunks \
			or prison_authored_toilets != prison_toilets:
		failures += 1
		print("FAIL — prison cell fixtures did not all use their authored models")
	if prison_phone_booths == 0 or prison_phones != prison_phone_booths * 2:
		failures += 1
		print("FAIL — prison visitation phones were missing or incomplete")
	if prison_locked_door_facades == 0 or prison_interactive_door_leaves == 0:
		failures += 1
		print("FAIL — authored prison door variants were not both exercised")
	if int(exit_housings[7]) == 0 or int(exit_housings[8]) == 0:
		failures += 1
		print("FAIL — mall/prison EXIT fixture audit was not fully exercised")
	if failures == 0:
		print("  PASS — all new-level room styles are supported, atomic, and navigable")
	quit(0 if failures == 0 else 1)
