extends SceneTree
## Deterministic topology audit for narrow corridor themes.
##
## Run:
##   godot --headless --path . --script tools/audit_corridors.gd -- [seed_count] [radius]
##
## A decorative locked door may hide unbuilt space, but a player must never be
## able to reach that space from an uncased/open corridor boundary.  This tool
## exercises many seeds and checks the data contract the corridor shells rely on.

const THEMES := [0, 1, 4, 5, 6]
const DIRV := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPP := [1, 0, 3, 2]


func _level_seed(base: int, theme: int) -> int:
	if theme == 0:
		return base
	var salt := 348039917
	if theme == 4:
		salt = 536870923
	elif theme == 5:
		salt = 998244353
	elif theme == 6:
		salt = 179424673
	return ((base ^ salt) & 0x7FFFFFFF) | 1


func _same_edge(a: Dictionary, b: Dictionary) -> bool:
	return a["wall"] == b["wall"] \
		and a["full_open"] == b["full_open"] \
		and absf(float(a["t"]) - float(b["t"])) < 0.001 \
		and absf(float(a["w"]) - float(b["w"])) < 0.001


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if args.size() > 0 else 16
	var radius := int(args[1]) if args.size() > 1 else 10
	var checked_edges := 0
	var corridor_boundaries := 0
	var terminal_openings := 0
	var failures := []

	for si in seed_count:
		var base_seed := 4243 + si * 7919
		for theme in THEMES:
			var ws := _level_seed(base_seed, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var cell := Vector2i(x, z)
					var ca := WorldGen.corridor(ws, cell)
					for dir in 4:
						var nb: Vector2i = cell + DIRV[dir]
						var cb := WorldGen.corridor(ws, nb)
						var info := WorldGen.edge_info(ws, cell, dir, theme)
						var other := WorldGen.edge_info(ws, nb, OPP[dir], theme)
						checked_edges += 1
						if not _same_edge(info, other):
							failures.append("asymmetric edge seed=%d theme=%d cell=%s dir=%d" % [
								base_seed, theme, cell, dir])
							continue
						if WorldGen.room_id(ws, cell) == WorldGen.room_id(ws, nb) and \
								WorldGen.finish_variant(ws, cell, theme) != \
								WorldGen.finish_variant(ws, nb, theme):
							failures.append("merged room finish mismatch seed=%d theme=%d cell=%s dir=%d" % [
								base_seed, theme, cell, dir])
							continue
						if ca == 0 and cb == 0:
							continue
						if WorldGen.corridor_link(ws, cell, dir):
							if info["wall"] or not info["full_open"]:
								failures.append("straight corridor interrupted seed=%d theme=%d cell=%s dir=%d" % [
									base_seed, theme, cell, dir])
							continue
						corridor_boundaries += 1
						# Every non-through corridor boundary must either be solid or a
						# cased opening. A fully open edge reveals reserved space.
						if info["full_open"]:
							failures.append("open corridor backing seed=%d theme=%d cell=%s dir=%d" % [
								base_seed, theme, cell, dir])
						var along_axis := (ca == 1 and dir <= 1) or (ca == 2 and dir >= 2) \
							or (cb == 1 and dir <= 1) or (cb == 2 and dir >= 2)
						if along_axis and not info["wall"]:
							terminal_openings += 1
							if absf(float(info["t"]) - 6.0) > 0.001:
								failures.append("off-lane corridor exit seed=%d theme=%d cell=%s dir=%d t=%.2f" % [
									base_seed, theme, cell, dir, float(info["t"])])
						if failures.size() >= 20:
							break
					if failures.size() >= 20:
						break
				if failures.size() >= 20:
					break
			if failures.size() >= 20:
				break
		if failures.size() >= 20:
			break

	print("corridor audit: %d seeds x %d themes, %d directed edges" % [
		seed_count, THEMES.size(), checked_edges])
	print("  non-through corridor boundaries: %d" % corridor_boundaries)
	print("  centred open corridor terminals/junctions: %d" % terminal_openings)
	if failures.is_empty():
		print("  PASS — no exposed backing space, interrupted spines, or asymmetric edges")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("  FAIL — %d topology violations (showing at most 20)" % failures.size())
	quit(1)
