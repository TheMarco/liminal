extends SceneTree
## Builds slot rooms across many casino seeds and asserts that every surviving
## cabinet has explicit front and rear volume. This guards both the central
## aisle and the screen face, where layered quads once exposed the room behind.
## Run: godot --headless --path . --script tools/audit_slots.gd -- [seeds] [radius]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 12, 1, 32)
	var radius := clampi(int(args[1]) if args.size() > 1 else 8, 3, 14)
	var rooms := 0
	var machines := 0
	var missing_backs := 0
	var missing_fronts := 0
	for si in seed_count:
		var base := WorldGen.h(920713, si * 43, si * 79, 2219) | 1
		var ws := WorldGen.level_seed(base, 0)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell \
						or WorldGen.cell_style(ws, cell, 0) != WorldGen.STYLE_SLOTS:
					continue
				var chunk := Chunk.new(ws, cell, 0)
				var count := chunk.slot_machine_count()
				if count > 0:
					rooms += 1
					machines += count
					missing_backs += chunk.slot_back_violations()
					missing_fronts += chunk.slot_front_violations()
				chunk.free()
	print("slot cabinet audit: %d seeds, radius %d, %d rooms, %d machines" % [
		seed_count, radius, rooms, machines])
	print("  missing closed rear shells: %d" % missing_backs)
	print("  missing closed front shells: %d" % missing_fronts)
	var failures := missing_backs + missing_fronts
	if rooms == 0 or machines == 0:
		failures += 1
		print("FAIL — no furnished slot room generated in the audit area")
	elif failures == 0:
		print("  PASS — every generated slot cabinet is closed front and rear")
	quit(0 if failures == 0 else 1)
