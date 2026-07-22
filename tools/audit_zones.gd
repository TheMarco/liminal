extends SceneTree
## Validates semantic districts and rare landmark contracts without building
## scene geometry. Run:
##   godot --headless --path . --script tools/audit_zones.gd

const SEEDS := [1, 7, 42, 31337, 240721, 8675309, 19088743, 998244353]
const RADIUS := 32

var failures := 0


func _init() -> void:
	for theme in WorldGen.THEMES:
		_audit_theme(theme)
	if failures > 0:
		printerr("ZONE AUDIT FAILED: %d contract violations" % failures)
		quit(1)
	else:
		print("ZONE AUDIT PASS")
		quit()


func _audit_theme(theme: int) -> void:
	var rooms := 0
	var halls := 0
	var landmarks := 0
	var zone_rooms := [0, 0, 0]
	var style_by_zone := [{}, {}, {}]
	for ws in SEEDS:
		var seen := {}
		for x in range(-RADIUS, RADIUS + 1):
			for z in range(-RADIUS, RADIUS + 1):
				var cell := Vector2i(x, z)
				var root := WorldGen.room_id(ws, cell)
				var zone := WorldGen.macro_zone(ws, cell, theme)
				var style := WorldGen.cell_style(ws, cell, theme)
				if seen.has(root):
					var old: Vector2i = seen[root]
					if old.x != zone or old.y != style:
						_fail("theme %d seed %d room %s changed from zone/style %s to (%d,%d)" %
							[theme, ws, root, old, zone, style])
					continue
				seen[root] = Vector2i(zone, style)
				rooms += 1
				zone_rooms[zone] += 1
				style_by_zone[zone][style] = int(style_by_zone[zone].get(style, 0)) + 1
				var size := WorldGen.room_size(ws, root)
				if size >= 4:
					halls += 1
				var landmark := WorldGen.landmark_style(ws, root, theme)
				if landmark >= 0:
					landmarks += 1
					if size < 4 or style != landmark or root == Vector2i.ZERO:
						_fail("theme %d seed %d invalid landmark room %s size %d style %d/%d" %
							[theme, ws, root, size, style, landmark])
	var ratio := float(landmarks) / float(maxi(halls, 1))
	if landmarks == 0 or ratio < 0.12 or ratio > 0.32:
		_fail("theme %d landmark frequency %.1f%% (%d/%d halls)" %
			[theme, ratio * 100.0, landmarks, halls])
	print("theme %d | %d rooms | zones %s | landmarks %d/%d halls (%.1f%%)" %
		[theme, rooms, zone_rooms, landmarks, halls, ratio * 100.0])
	for zone in 3:
		var ranked := []
		for style in style_by_zone[zone]:
			ranked.append([style, style_by_zone[zone][style]])
		ranked.sort_custom(func(a, b): return a[1] > b[1])
		var top := ranked.slice(0, mini(3, ranked.size()))
		print("  %-14s %s" % [WorldGen.macro_zone_name(zone, theme), top])


func _fail(message: String) -> void:
	failures += 1
	if failures <= 20:
		printerr(message)
