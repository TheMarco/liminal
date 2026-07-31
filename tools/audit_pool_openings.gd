extends SceneTree
## Poolrooms opening contract:
## - every cased room connection is a rounded or arched walk-through;
## - selected solid walls contain a true circular, view-only aperture;
## - every curved solid profile has matching convex collision pieces.
##
## Run:
##   godot --headless --path . --script tools/audit_pool_openings.gd -- [seeds]

const THEME := 9
const SCAN_R := 7


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(
		int(args[0]) if not args.is_empty() else 4, 2, 12)
	var failures: Array[String] = []
	var rounded_count := 0
	var arch_count := 0
	var circle_count := 0
	for si in seed_count:
		var base := WorldGen.h(7117, si * 43, si * 67, 1901) | 1
		var ws := WorldGen.level_seed(base, THEME)
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				var cell := Vector2i(x, z)
				var chunk := Chunk.new(ws, cell, THEME)
				for dir in [0, 2]:
					var info := WorldGen.edge_info(ws, cell, dir, THEME)
					if bool(info["full_open"]):
						if not _openings(chunk, dir).is_empty():
							failures.append(
								"seed %d cell %s dir %d: full-open edge has shaped wall mesh" % [
									si, cell, dir])
						continue
					if bool(info["wall"]):
						if not WorldGen.pool_wall_aperture(ws, cell, dir):
							continue
						var circles := _openings(chunk, dir, "circle")
						circle_count += circles.size()
						if circles.size() != 1:
							failures.append(
								"seed %d cell %s dir %d: expected one circular aperture, found %d" % [
									si, cell, dir, circles.size()])
							continue
						var circle := circles[0]
						var radius := float(circle.get_meta(
							"pool_opening_radius", 0.0))
						var center_y := float(circle.get_meta(
							"pool_opening_center_y", 0.0))
						if center_y - radius < Chunk.POOL_DRY_Y + 0.38:
							failures.append(
								"seed %d cell %s dir %d: circular sill is traversably low" % [
									si, cell, dir])
						if _collider_count(
								chunk, dir, "circle_lower") < 8 \
								or _collider_count(
									chunk, dir, "circle_upper") < 8:
							failures.append(
								"seed %d cell %s dir %d: circular wall lacks profile collision" % [
									si, cell, dir])
						continue

					var kind := "arch" \
						if WorldGen.pool_doorway_kind(
							ws, cell, dir) == WorldGen.POOL_OPENING_ARCH \
						else "rounded"
					var openings := _openings(chunk, dir, kind)
					if kind == "arch":
						arch_count += openings.size()
					else:
						rounded_count += openings.size()
					if openings.size() != 1:
						failures.append(
							"seed %d cell %s dir %d: expected one %s doorway, found %d" % [
								si, cell, dir, kind, openings.size()])
						continue
					var profile: Array = openings[0].get_meta(
						"pool_opening_profile", [])
					if profile.size() < 7:
						failures.append(
							"seed %d cell %s dir %d: %s profile is under-segmented" % [
								si, cell, dir, kind])
					var peak := 0.0
					for point_value in profile:
						var point: Vector2 = point_value
						peak = maxf(peak, point.y)
					if absf(peak - Chunk.POOL_DOOR_TOP) > 0.03:
						failures.append(
							"seed %d cell %s dir %d: %s peak %.2f misses door top %.2f" % [
								si, cell, dir, kind, peak,
								Chunk.POOL_DOOR_TOP])
					if _collider_count(chunk, dir, kind) \
							< profile.size() - 1:
						failures.append(
							"seed %d cell %s dir %d: %s header lacks profile collision" % [
								si, cell, dir, kind])
				var clearance_violations := \
					chunk.doorway_clearance_violations()
				if clearance_violations > 0:
					failures.append(
						"seed %d cell %s: %d furnishings block shaped doorway approaches" % [
							si, cell, clearance_violations])
				chunk.free()
	for failure in failures:
		print("  FAIL " + failure)
	if rounded_count == 0 or arch_count == 0 or circle_count == 0:
		failures.append(
			"opening audit is inert: rounded=%d arch=%d circle=%d" % [
				rounded_count, arch_count, circle_count])
	if not failures.is_empty():
		quit(1)
		return
	print(("pool opening audit: PASS — %d rounded doorways, %d arches, " +
		"%d circular view apertures with matched collision") % [
		rounded_count, arch_count, circle_count])
	quit()


func _openings(chunk: Chunk, dir: int, kind := "") -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in chunk.find_children(
			"*", "MeshInstance3D", true, false):
		if not node.has_meta("pool_opening") \
				or int(node.get_meta("pool_opening_dir", -1)) != dir:
			continue
		if not kind.is_empty() \
				and str(node.get_meta("pool_opening_kind", "")) != kind:
			continue
		result.append(node as MeshInstance3D)
	return result


func _collider_count(chunk: Chunk, dir: int, kind: String) -> int:
	var result := 0
	for node in chunk.find_children(
			"*", "CollisionShape3D", true, false):
		if not node.has_meta("pool_opening_collider") \
				or int(node.get_meta("pool_opening_dir", -1)) != dir:
			continue
		if str(node.get_meta("pool_opening_kind", "")) == kind:
			result += 1
	return result
