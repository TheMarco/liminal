extends SceneTree
## Every fully open edge between rooms of unequal ceiling height must be
## sealed: the taller cell builds a fascia from the neighbour's ceiling plane
## up to its own, otherwise the band between the two ceilings is raw void and
## reads as a huge black slab hanging over the opening. Pure topology finds
## the seams cheaply; a sample per theme is then built for real and checked.
##
## Run: godot --headless --path . --script tools/audit_ceiling_seams.gd -- [seeds]

const SCAN_R := 6
const BUILDS_PER_THEME := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 3, 1, 12)
	var failures: Array[String] = []
	var seams := 0
	var built := 0
	var sealed := 0
	for si in seed_count:
		var base := WorldGen.h(6150, si * 37, si * 59, 911) | 1
		for theme in WorldGen.THEMES:
			if theme == 2:
				continue  # one flat drop ceiling; nothing to seal
			var ws := WorldGen.level_seed(base, theme)
			var built_here := 0
			for x in range(-SCAN_R, SCAN_R + 1):
				for z in range(-SCAN_R, SCAN_R + 1):
					var c := Vector2i(x, z)
					var h := Chunk.cell_ceil_h(ws, c, theme)
					for dir in 4:
						var info := WorldGen.edge_info(ws, c, dir, theme)
						if bool(info["wall"]) or not bool(info["full_open"]):
							continue
						var nb_h := Chunk.cell_ceil_h(
							ws, c + WorldGen.DIRV[dir], theme)
						if h - nb_h < 0.1:
							continue
						seams += 1
						# The fascia hangs down to the neighbour's ceiling. It
						# must clear the taller side's WALKABLE floor by a
						# doorway's headroom, or it is a beam across the walk —
						# pool dry halls stand at 1.42, so a low neighbour
						# ceiling gets much closer to heads than it looks.
						var floor_h := 0.0
						if theme == 9 and Chunk.pool_style_dry(
								WorldGen.cell_style(ws, c, theme)):
							floor_h = Chunk.POOL_DRY_Y
						if nb_h - floor_h < 2.1:
							failures.append(
								"theme %d seed %d cell %s dir %d: fascia hangs %.2fm over the floor" % [
									theme, si, c, dir, nb_h - floor_h])
						if built_here >= BUILDS_PER_THEME:
							continue
						built_here += 1
						built += 1
						var chunk := Chunk.new(ws, c, theme)
						if _fascia_ok(chunk, dir, nb_h, h):
							sealed += 1
						else:
							failures.append(
								"theme %d seed %d cell %s dir %d: open seam %.1f -> %.1f unsealed" % [
									theme, si, c, dir, nb_h, h])
						chunk.free()
	print("ceiling seam audit: %d seeds | %d open tall-to-low seams | %d built, %d sealed" % [
		seed_count, seams, built, sealed])
	if seams == 0:
		failures.append(
			"no open seam between unequal ceilings was ever found — audit is inert")
	for f in failures:
		print("  FAIL " + f)
	if not failures.is_empty():
		quit(1)
		return
	print("  PASS — every sampled open joint between unequal ceilings is sealed")
	quit()


func _fascia_ok(chunk: Node, dir: int, nb_h: float, h: float) -> bool:
	for n in chunk.find_children("*", "MeshInstance3D", true, false):
		if int(n.get_meta("open_edge_fascia", -1)) != dir:
			continue
		# The band must span exactly from the neighbour's ceiling to ours —
		# short of either plane, a strip of void survives.
		var yc := (nb_h + h) * 0.5
		return absf(n.position.y - yc) < 0.05 \
			and absf(n.scale.y - (h - nb_h)) < 0.05
	return false
