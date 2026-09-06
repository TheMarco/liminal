extends SceneTree
## Slot banks must be common outside large gaming-district halls, and close
## to the entrance. --report records the old distribution without assertions.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("CASINO_DISTRIBUTION: " + message)


func nearest_slots(seed: int, origin: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [origin]
	var distance := {origin: 0}
	var first := 0
	var origin_room := WorldGen.room_id(seed, origin)
	while first < queue.size():
		var cell := queue[first]
		first += 1
		var steps := int(distance[cell])
		var room := WorldGen.room_id(seed, cell)
		if room != origin_room and WorldGen.cell_style(seed, cell, 0) == WorldGen.STYLE_SLOTS \
				and WorldGen.room_split(seed, room, 0).is_empty():
			return {"distance": steps, "room": room}
		if steps >= 12:
			continue
		for dir in 4:
			var next: Vector2i = cell + WorldGen.DIRV[dir]
			if not distance.has(next) and not WorldGen.edge_info(seed, cell, dir, 0).wall:
				distance[next] = steps + 1
				queue.append(next)
	return {"distance": 99, "room": Vector2i.ZERO}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var report := OS.get_cmdline_user_args().has("--report")
	var rooms := [0, 0, 0]
	var slots := [0, 0, 0]
	var small_slots := 0
	var nearest_sum := 0
	var nearest_max := 0
	var descent_max := 0
	for si in 64:
		var seed: int = [454890253, 4242][si] if si < 2 else WorldGen.h(78241, si * 43, si * 79, 9621) | 1
		var nearest := nearest_slots(seed, Vector2i.ZERO)
		nearest_sum += int(nearest.distance)
		nearest_max = maxi(nearest_max, int(nearest.distance))
		if si == 0:
			print("Current seed %d: nearest slot room %s, %d connected cell transitions from entrance" % [seed, nearest.room, nearest.distance])
		if not report:
			check(nearest.distance <= 4, "No nearby slot room for seed %d (%d steps)" % [seed, nearest.distance])
			if si < 8:
				var furnished := Chunk.new(seed, nearest.room, 0)
				check(furnished.slot_machine_count() > 0, "Nearest slot room lost all cabinets during furnishing")
				check(furnished.doorway_clearance_violations() == 0, "Near-entrance machines obstruct a doorway")
				furnished.free()
		if si < 8:
			var route := DescentRoute.build(seed, 0, 0)
			var from_arrival := nearest_slots(seed, route.origin)
			descent_max = maxi(descent_max, int(from_arrival.distance))
			if not report:
				check(from_arrival.distance <= 4, "Descent arrival is far from slots: seed %d, origin %s" % [seed, route.origin])
		for x in range(-12, 13):
			for z in range(-12, 13):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(seed, cell) != cell or WorldGen.corridor(seed, cell) != 0:
					continue
				var zone := WorldGen.macro_zone(seed, cell, 0)
				rooms[zone] += 1
				if WorldGen.cell_style(seed, cell, 0) == WorldGen.STYLE_SLOTS:
					slots[zone] += 1
					if WorldGen.room_size(seed, cell) == 1:
						small_slots += 1
					if not report:
						check(WorldGen.room_split(seed, cell, 0).is_empty(), "Slot room partition replaced its machines")
	var total_rooms: int = rooms[0] + rooms[1] + rooms[2]
	var total_slots: int = slots[0] + slots[1] + slots[2]
	print("CASINO_DISTRIBUTION: %d/%d rooms have slots (%.1f%%); %d regular-size slot rooms" % [total_slots, total_rooms, 100.0 * total_slots / total_rooms, small_slots])
	for zone in 3:
		var share: float = float(slots[zone]) / rooms[zone]
		print("  %s: %.1f%% slot rooms" % [WorldGen.macro_zone_name(zone, 0), share * 100])
		if not report:
			check(share >= .25 and share <= .80, "Casino district lost slot availability or variety")
	print("  Nearest from entrance: mean %.2f / max %d cell transitions; Descent arrival max %d" % [nearest_sum / 64.0, nearest_max, descent_max])
	if not report:
		check(small_slots > 0, "Regular casino rooms never contain slot banks")
	print("  failures=%d" % failures)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures else 0)
