extends SceneTree
## Deterministic topology audit for the sewer water graph and room contracts.
##
## Run:
##   godot --headless --path . --script tools/audit_sewers.gd -- [seed_count] [radius]

const DIRV := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPP := [1, 0, 3, 2]


func _level_seed(base: int) -> int:
	return ((base ^ 715827883) & 0x7fffffff) | 1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if args.size() > 0 else 24
	var radius := int(args[1]) if args.size() > 1 else 14
	var checked_edges := 0
	var wet_edges := 0
	var culvert_edges := 0
	var junctions := [0, 0, 0, 0, 0]
	var style_counts := {20: 0, 21: 0, 22: 0, 23: 0, 24: 0, 25: 0}
	var failures := []

	for si in seed_count:
		var base_seed := 4243 + si * 7919
		var ws := _level_seed(base_seed)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var root := WorldGen.room_id(ws, cell)
				var room_n := WorldGen.room_size(ws, root)
				var style := WorldGen.cell_style(ws, cell, 2)
				style_counts[style] = int(style_counts.get(style, 0)) + 1
				var degree := 0
				for dir in 4:
					var nb: Vector2i = cell + DIRV[dir]
					var wet := WorldGen.sewer_channel(ws, cell, dir)
					var other_wet := WorldGen.sewer_channel(ws, nb, OPP[dir])
					checked_edges += 1
					if wet:
						wet_edges += 1
						degree += 1
						if WorldGen.edge_info(ws, cell, dir, 2)["wall"]:
							culvert_edges += 1
					if wet != other_wet:
						failures.append("channel mismatch seed=%d cell=%s dir=%d" % [
							base_seed, cell, dir])
					elif wet and WorldGen.sewer_flow(ws, cell, dir) != \
							WorldGen.sewer_flow(ws, nb, OPP[dir]):
						failures.append("flow mismatch seed=%d cell=%s dir=%d" % [
							base_seed, cell, dir])
					if WorldGen.room_id(ws, nb) == root and \
							WorldGen.cell_style(ws, nb, 2) != style:
						failures.append("room style mismatch seed=%d cell=%s neighbour=%s" % [
							base_seed, cell, nb])
					if WorldGen.room_id(ws, nb) == root and \
							WorldGen.finish_variant(ws, nb, 2) != \
							WorldGen.finish_variant(ws, cell, 2):
						failures.append("room finish mismatch seed=%d cell=%s neighbour=%s" % [
							base_seed, cell, nb])
				junctions[degree] += 1
				var cdir := WorldGen.corridor(ws, cell)
				if cdir != 0 and style != WorldGen.SEWER_GALLERY:
					failures.append("corridor is not gallery seed=%d cell=%s" % [base_seed, cell])
				elif cdir == 0:
					var valid := false
					if room_n >= 4:
						valid = style == WorldGen.SEWER_BASIN \
							or style == WorldGen.SEWER_PUMP \
							or style == WorldGen.SEWER_CISTERN
					elif room_n >= 2:
						valid = style == WorldGen.SEWER_TUNNEL \
							or style == WorldGen.SEWER_BASIN \
							or style == WorldGen.SEWER_PUMP \
							or style == WorldGen.SEWER_DRY
					else:
						valid = style == WorldGen.SEWER_TUNNEL \
							or style == WorldGen.SEWER_DRY \
							or style == WorldGen.SEWER_PUMP
					if not valid:
						failures.append("invalid room style seed=%d cell=%s n=%d style=%d" % [
							base_seed, cell, room_n, style])
				if failures.size() >= 20:
					break
			if failures.size() >= 20:
				break
		if failures.size() >= 20:
			break

	# Both views of the protected spawn edge must agree that it is dry.
	for si in seed_count:
		var ws := _level_seed(4243 + si * 7919)
		if WorldGen.sewer_channel(ws, Vector2i.ZERO, 3) \
				or WorldGen.sewer_channel(ws, Vector2i(0, -1), 2):
			failures.append("spawn south edge is wet for audit seed %d" % si)

	print("sewer audit: %d seeds, radius %d, %d directed edges" % [
		seed_count, radius, checked_edges])
	print("  wet directed edges: %d | through-wall culverts: %d" % [wet_edges, culvert_edges])
	print("  channel degree 0..4: %s" % [junctions])
	print("  styles tunnel/basin/pump/dry/gallery/cistern: %s" % [[
		style_counts[20], style_counts[21], style_counts[22], style_counts[23],
		style_counts[24], style_counts[25]]])
	if failures.is_empty():
		print("  PASS — symmetric channels and flows; valid room/style contracts")
		quit(0)
		return
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("  FAIL — %d topology violations (showing at most 20)" % failures.size())
	quit(1)
