extends SceneTree
## Builds furnished room anchors across every theme and verifies that no
## generated prop mesh or collider survives inside a real doorway's approach
## lane. Locked facade doors are deliberately outside this contract.
## Run: godot --headless --path . --script tools/audit_doorways.gd -- [seeds] [radius]


func _level_seed(base: int, theme: int) -> int:
	if theme == 0:
		return base
	var salt := 348039917
	if theme == 2: salt = 715827883
	elif theme == 4: salt = 536870923
	elif theme == 5: salt = 998244353
	elif theme == 6: salt = 179424673
	return ((base ^ salt) & 0x7FFFFFFF) | 1


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
					if bad > 0:
						failures += bad
						if failures <= 12:
							print("FAIL seed=%d theme=%d cell=%s style=%d overlaps=%d" % [
								base, theme, c, WorldGen.cell_style(ws, c, theme), bad])
					chunk.free()
	print("doorway furnishing audit: %d seeds, radius %d, %d furnished rooms" % [
		seed_count, radius, rooms])
	print("  removed %d blocking prop pieces/pivots and colliders | by theme %s" % [
		culled, per_theme])
	if failures == 0:
		print("  PASS — no furnishing mesh or collider occupies a real doorway approach")
	else:
		print("  FAIL — %d doorway approach overlaps remain" % failures)
	quit(0 if failures == 0 else 1)
