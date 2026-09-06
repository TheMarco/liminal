extends SceneTree
## Builds casino rooms across many seeds. Slot rooms must contain only slot
## machines, never table games; other room styles must never contain slots.
## Every surviving cabinet must also have explicit front and rear volume.
## Run: godot --headless --path . --script tools/audit_slots.gd -- [seeds] [radius]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 12, 1, 32)
	var radius := clampi(int(args[1]) if args.size() > 1 else 8, 3, 14)
	var rooms := 0
	var machines := 0
	var missing_backs := 0
	var missing_fronts := 0
	var checked_rooms := 0
	var mixed_rooms := 0
	var misplaced_slots := 0
	var table_counts := {"blackjack_table": 0, "roulette_table": 0}
	for si in seed_count:
		var base := 454890253 if si == 0 else WorldGen.h(920713, si * 43, si * 79, 2219) | 1
		var ws := WorldGen.level_seed(base, 0)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell:
					continue
				var chunk := Chunk.new(ws, cell, 0)
				checked_rooms += 1
				var count := chunk.slot_machine_count()
				var furnishings := chunk.authored_furnishing_counts()
				var tables := int(furnishings.get("blackjack_table", 0)) \
					+ int(furnishings.get("roulette_table", 0))
				if chunk.style == WorldGen.STYLE_SLOTS and tables > 0:
					mixed_rooms += 1
					if mixed_rooms <= 8:
						print("FAIL seed=%d cell=%s: slot room contains %d table games" % [base, cell, tables])
				elif chunk.style != WorldGen.STYLE_SLOTS:
					if count > 0:
						misplaced_slots += 1
					for kind in table_counts:
						table_counts[kind] += int(furnishings.get(kind, 0))
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
	print("  %d casino rooms checked; mixed slot/table rooms: %d; non-slot rooms with slots: %d" % [checked_rooms, mixed_rooms, misplaced_slots])
	print("  table games retained outside slot rooms: %s" % table_counts)
	var failures := missing_backs + missing_fronts + mixed_rooms + misplaced_slots
	for kind in table_counts:
		if table_counts[kind] == 0:
			failures += 1
			print("FAIL — %s disappeared from non-slot rooms" % kind)
	if rooms == 0 or machines == 0:
		failures += 1
		print("FAIL — no furnished slot room generated in the audit area")
	elif failures == 0:
		print("  PASS — slot rooms exclude table games; all cabinets are closed front and rear")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)
