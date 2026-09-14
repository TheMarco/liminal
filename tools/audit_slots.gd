extends SceneTree
## Builds casino rooms across many seeds. Slot rooms must contain only slot
## machines, never table games; other room styles must never contain slots.
## Every surviving cabinet must also have explicit front and rear volume.
## Run: godot --headless --path . --script tools/audit_slots.gd -- [seeds] [radius]

const NostalgiaProps = preload("res://scripts/nostalgia_props.gd")


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
	var missing_change := 0
	var missing_change_wall := 0
	var no_change_bay := 0
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
					var change_count := int(furnishings.get("casino_change_machine", 0))
					# Fully open-plan rooms may have no real wall; never require
					# a freestanding fallback just to reach a prop count.
					var available_bay := NostalgiaProps.machine_site(chunk,
						Chunk.CHANGE_MACHINE_BOUNDS) if change_count == 0 else {}
					if change_count > 1 or (change_count == 0 and not available_bay.is_empty()):
						missing_change += 1
						print("FAIL seed=%d cell=%s: %d change machines" % [base, cell, change_count])
					elif change_count == 0:
						no_change_bay += 1
					for node in chunk.find_children("*", "Node3D", true, false):
						if str(node.get_meta("attributed_furnishing", "")) != "casino_change_machine": continue
						if not _change_machine_wall_supported(chunk, node):
							missing_change_wall += 1
							if missing_change_wall <= 8:
								print("FAIL seed=%d cell=%s: change machine lacks rear wall at %s" % [base, cell, node.position])
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
	print("  invalid change-machine counts (duplicates or unused safe wall bays): %d" % missing_change)
	print("  open/crowded slot rooms without a safe machine wall bay: %d" % no_change_bay)
	print("  change machines without supported rear wall: %d" % missing_change_wall)
	var failures := missing_backs + missing_fronts + mixed_rooms + misplaced_slots + missing_change + missing_change_wall
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


func _change_machine_wall_supported(chunk: Chunk, node: Node3D) -> bool:
	for x in [-.526, .526]:
		for y in [.10, 1.716]:
			var rear := node.transform * Vector3(x, y, -.315)
			var found := false
			for wall in NostalgiaProps.backing_walls(chunk):
				for step in range(1, 9):
					if wall.has_point(rear - node.basis.z.normalized() * float(step) * .01):
						found = true
						break
				if found: break
			if not found: return false
	return true
