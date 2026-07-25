extends SceneTree
## Dev: find authored furnishings of a given kind near the origin and print a
## ready-made --pos/--yaw to stand in front of one, so a screenshot never has to
## be aimed by trial and error. Kinds are the strings `_attributed_floor_prop`
## tags its pivots with: blackjack_table, roulette_table, hotdog_stand,
## autopsy_table, office_printer, school_desk, office_phone, ward_bed, ...
##
## Run: godot --headless --path . --script tools/dbg_find_prop.gd -- \
##   <seed> <theme> <kind> [radius]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 12345
	var theme := int(args[1]) if args.size() > 1 else 7
	var kind := str(args[2]) if args.size() > 2 else "hotdog_stand"
	var radius := clampi(int(args[3]) if args.size() > 3 else 6, 1, 14)
	var ws := WorldGen.level_seed(base, theme)
	var found := 0
	var anchors := 0
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var cell := Vector2i(x, z)
			var chunk := Chunk.new(ws, cell, theme)
			anchors += 1
			var origin := Vector3(float(x) * Chunk.S, 0.0, float(z) * Chunk.S)
			for node in chunk.find_children("*", "Node3D", true, false):
				if str(node.get_meta("attributed_furnishing", "")) != kind:
					continue
				found += 1
				if found > 8:
					continue
				var n3 := node as Node3D
				var w := origin + n3.position
				# stand back along the prop's own facing and look at it
				var f := Vector3(sin(n3.rotation.y), 0, cos(n3.rotation.y))
				var stand := w + f * 3.2
				print("%-16s cell %-9s at (%7.1f,%7.1f)   --pos=%.1f,%.1f --yaw=%.0f" % [
					kind, str(cell), w.x, w.z, stand.x, stand.z,
					rad_to_deg(n3.rotation.y)])
			chunk.free()
	print()
	print("%s: %d found across %d cells (theme %d, seed %d, radius %d)" % [
		kind, found, anchors, theme, base, radius])
	quit()
