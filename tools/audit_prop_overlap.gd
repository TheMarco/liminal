extends SceneTree
## Builds furnished rooms across every floor and reports floor furnishings whose
## collision volumes interpenetrate. A suitcase standing inside a row of gate
## seating is the symptom: a scatter prop that picked a random point in the cell
## without asking whether anything was already there.
##
## Colliders are compared, not meshes, and as oriented boxes rather than as
## axis-aligned bounds — a 2.1 x 0.6m seat bank turned 45 degrees has an AABB of
## roughly 1.9 x 1.9m, so merging rotated AABBs invents overlaps that do not
## exist. Each furnishing is one `furnishing_group`, so the parts of a single
## assembly are never compared against each other.
##
## Run: godot --headless --path . --script tools/audit_prop_overlap.gd -- [seeds] [radius]

const OVERLAP_TOL := 0.12   # shapes may kiss; they may not interpenetrate
const FLOOR_MAX := 0.55     # ignore anything mounted off the floor


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 6, 1, 24)
	var radius := clampi(int(args[1]) if args.size() > 1 else 5, 2, 12)
	var rooms := 0
	var pairs := 0
	var worst := 0.0
	var per_theme := {}
	var shown := 0
	for si in seed_count:
		var base := WorldGen.h(5150, si * 31, si * 53, 909) | 1
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var c := Vector2i(x, z)
					# Corridor cells furnish themselves rather than deferring to
					# a room anchor, and the airport concourse — where seating
					# and clutter share one margin line — is one of them. Testing
					# anchors alone never builds those at all.
					var local := WorldGen.corridor(ws, c) != 0
					if WorldGen.room_id(ws, c) != c and not local:
						continue
					var chunk := Chunk.new(ws, c, theme)
					rooms += 1
					var groups := _groups(chunk)
					var keys := groups.keys()
					for i in keys.size():
						for j in range(i + 1, keys.size()):
							var d := _group_overlap(groups[keys[i]], groups[keys[j]])
							if d <= OVERLAP_TOL:
								continue
							pairs += 1
							worst = maxf(worst, d)
							per_theme[theme] = int(per_theme.get(theme, 0)) + 1
							if shown < 12:
								shown += 1
								print("FAIL theme=%d cell=%s style=%d  %s <-> %s  by %.2fm" % [
									theme, c, WorldGen.cell_style(ws, c, theme),
									groups[keys[i]]["tag"], groups[keys[j]]["tag"], d])
					chunk.free()
	print("prop overlap audit: %d seeds, radius %d, %d rooms" % [
		seed_count, radius, rooms])
	print("  interpenetrating floor furnishings: %d %s" % [pairs, per_theme])
	if pairs > 0:
		print("  deepest interpenetration: %.2fm" % worst)
		print("  FAIL — floor props are landing inside placed furniture")
		quit(1)
		return
	print("  PASS — no free-standing floor furnishing sits inside another")
	quit()


## Collision boxes per furnishing group, tagged with what that furnishing is.
func _groups(chunk: Chunk) -> Dictionary:
	var tags := {}
	for node in chunk.find_children("*", "Node3D", true, false):
		if not node.has_meta("furnishing_group"):
			continue
		if node.has_meta("atomic_furnishing"):
			tags[int(node.get_meta("furnishing_group"))] = \
				str(node.get_meta("atomic_furnishing"))
		elif node.has_meta("attributed_furnishing"):
			tags[int(node.get_meta("furnishing_group"))] = \
				str(node.get_meta("attributed_furnishing"))
	var out := {}
	for child in chunk.body.get_children():
		var cs := child as CollisionShape3D
		if cs == null or not cs.has_meta("furnishing_group"):
			continue
		var gid := int(cs.get_meta("furnishing_group"))
		if not tags.has(gid):
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			continue        # cylinders are rare here and never the offender
		var half_h := box.size.y * 0.5
		if cs.position.y - half_h > FLOOR_MAX:
			continue        # wall or ceiling mounted
		if not out.has(gid):
			out[gid] = {"tag": tags[gid], "boxes": []}
		out[gid]["boxes"].append({
			"c": Vector2(cs.position.x, cs.position.z),
			"e": Vector2(box.size.x * 0.5, box.size.z * 0.5),
			"yaw": cs.rotation.y,
			"y0": cs.position.y - half_h,
			"y1": cs.position.y + half_h,
		})
	for gid in out.keys():
		if out[gid]["boxes"].is_empty():
			out.erase(gid)
	return out


func _group_overlap(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for ba in a["boxes"]:
		for bb in b["boxes"]:
			worst = maxf(worst, _obb_overlap(ba, bb))
	return worst


## Separating-axis depth for two yawed boxes in plan, gated on their heights
## actually overlapping. Returns the smallest penetration across all four axes,
## which is 0 the moment any axis separates them.
func _obb_overlap(a: Dictionary, b: Dictionary) -> float:
	var dy := minf(float(a["y1"]), float(b["y1"])) \
		- maxf(float(a["y0"]), float(b["y0"]))
	if dy <= 0.0:
		return 0.0
	var axes := [
		Vector2(cos(a["yaw"]), -sin(a["yaw"])),
		Vector2(sin(a["yaw"]), cos(a["yaw"])),
		Vector2(cos(b["yaw"]), -sin(b["yaw"])),
		Vector2(sin(b["yaw"]), cos(b["yaw"])),
	]
	var least := INF
	for axis in axes:
		var d: Vector2 = b["c"] - a["c"]
		var gap: float = absf(d.dot(axis)) - _project(a, axis) - _project(b, axis)
		if gap >= 0.0:
			return 0.0
		least = minf(least, -gap)
	return least


func _project(box: Dictionary, axis: Vector2) -> float:
	var ax := Vector2(cos(box["yaw"]), -sin(box["yaw"]))
	var az := Vector2(sin(box["yaw"]), cos(box["yaw"]))
	var e: Vector2 = box["e"]
	return absf(ax.dot(axis)) * e.x + absf(az.dot(axis)) * e.y
