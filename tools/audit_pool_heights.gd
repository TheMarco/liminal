extends SceneTree
## Poolroom scale contract: large rooms genuinely become two- and three-level
## volumes, every member agrees on height, and tall boundary cells expose that
## height with illuminated stacked clerestories.

const THEME := 9
const SCAN_R := 10
const SAMPLE_LIMIT := 24


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 8, 1, 24)
	var failures: Array[String] = []
	var tier_counts := {
		WorldGen.POOL_HEIGHT_SINGLE: 0,
		WorldGen.POOL_HEIGHT_DOUBLE: 0,
		WorldGen.POOL_HEIGHT_TRIPLE: 0,
	}
	var room_heights := {}
	var tall_boundary_samples: Array[Dictionary] = []
	for si in seed_count:
		var base := WorldGen.h(12041, si * 43, si * 79, 541) | 1
		var ws := WorldGen.level_seed(base, THEME)
		var seen_roots := {}
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				var cell := Vector2i(x, z)
				if WorldGen.corridor(ws, cell) != 0:
					continue
				var root := WorldGen.room_id(ws, cell)
				var tier := WorldGen.pool_room_height_tier(ws, root)
				var height := Chunk.cell_ceil_h(ws, cell, THEME)
				var room_key := "%d:%d:%d" % [si, root.x, root.y]
				if room_heights.has(room_key) \
						and not is_equal_approx(float(room_heights[room_key]), height):
					failures.append(
						"seed %d room %s disagrees on member height %.3f vs %.3f" % [
							si, root, float(room_heights[room_key]), height])
				room_heights[room_key] = height
				if not seen_roots.has(root):
					seen_roots[root] = true
					tier_counts[tier] = int(tier_counts[tier]) + 1
					if tier == WorldGen.POOL_HEIGHT_DOUBLE \
							and (height < 8.0 or height > 9.1):
						failures.append(
							"seed %d room %s double-height is %.2fm" % [
								si, root, height])
					elif tier == WorldGen.POOL_HEIGHT_TRIPLE \
							and (height < 11.3 or height > 12.7):
						failures.append(
							"seed %d room %s triple-height is %.2fm" % [
								si, root, height])
				if tier == WorldGen.POOL_HEIGHT_SINGLE \
						or tall_boundary_samples.size() >= SAMPLE_LIMIT:
					continue
				var eligible_wall := false
				for dir in 4:
					if bool(WorldGen.edge_info(ws, cell, dir, THEME)["wall"]) \
							and not WorldGen.pool_wall_aperture(ws, cell, dir):
						eligible_wall = true
						break
				if eligible_wall:
					tall_boundary_samples.append({
						"seed_index": si,
						"ws": ws,
						"cell": cell,
						"tier": tier,
					})
	var sampled_windows := 0
	var sampled_window_lights := 0
	for sample in tall_boundary_samples:
		var chunk := Chunk.new(
			int(sample["ws"]), sample["cell"], THEME)
		var windows := 0
		var window_lights := 0
		for node in chunk.find_children("*", "Node", true, false):
			if node.has_meta("pool_window"):
				windows += 1
			if node.has_meta("pool_window_light"):
				window_lights += 1
			if node is OmniLight3D \
					and node.get_meta("pool_light_type", "") == "ceiling_disc":
				var needed := chunk.ceil_h - chunk.POOL_DRY_Y + 1.0
				if (node as OmniLight3D).omni_range < needed:
					failures.append(
						"seed %d cell %s: %.2fm ceiling light reaches only %.2fm" % [
							int(sample["seed_index"]), sample["cell"],
							chunk.ceil_h, (node as OmniLight3D).omni_range])
		var minimum_windows := 5 \
			if int(sample["tier"]) == WorldGen.POOL_HEIGHT_TRIPLE else 2
		if not chunk.has_meta("pool_tall_clerestory") \
				or windows < minimum_windows:
			failures.append(
				"seed %d cell %s: tall boundary has %d/%d clerestory windows" % [
					int(sample["seed_index"]), sample["cell"],
					windows, minimum_windows])
		if window_lights == 0:
			failures.append(
				"seed %d cell %s: tall clerestory has no direct daylight" % [
					int(sample["seed_index"]), sample["cell"]])
		sampled_windows += windows
		sampled_window_lights += window_lights
		chunk.free()
	print(
		("pool height audit: %d seeds | %d single rooms | "
		+ "%d double-height rooms | %d triple-height rooms | "
		+ "%d tall boundary samples | %d windows | %d window lights") % [
			seed_count,
			int(tier_counts[WorldGen.POOL_HEIGHT_SINGLE]),
			int(tier_counts[WorldGen.POOL_HEIGHT_DOUBLE]),
			int(tier_counts[WorldGen.POOL_HEIGHT_TRIPLE]),
			tall_boundary_samples.size(),
			sampled_windows,
			sampled_window_lights,
		])
	if int(tier_counts[WorldGen.POOL_HEIGHT_DOUBLE]) == 0 \
			or int(tier_counts[WorldGen.POOL_HEIGHT_TRIPLE]) == 0:
		failures.append("scan did not produce both double- and triple-height rooms")
	if tall_boundary_samples.is_empty():
		failures.append("scan did not produce any auditable tall boundary cell")
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print("  PASS — Poolrooms include lit two- and three-level volumes")
	quit()
