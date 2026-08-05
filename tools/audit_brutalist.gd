extends SceneTree
## Regression audit for the Monolith's authored fixtures, exact-height portal
## casings, compressed passage shell and reused Annex door facade.
## Run: godot --headless --path . --script tools/audit_brutalist.gd

const THEME := 10
const SEARCH_RADIUS := 30


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed := WorldGen.level_seed(918273, THEME)
	var passage_cells: Array[Vector2i] = []
	var casing_cell := Vector2i(1 << 20, 1 << 20)
	var door_cell := Vector2i(1 << 20, 1 << 20)
	for x in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for z in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			var cell := Vector2i(x, z)
			var axis := WorldGen.corridor(seed, cell)
			if axis != 0 and passage_cells.size() < 2:
				if passage_cells.is_empty() \
						or WorldGen.corridor(seed, passage_cells[0]) != axis:
					passage_cells.append(cell)
			if casing_cell.x > 100000:
				for dir in 4:
					var info := WorldGen.edge_info(seed, cell, dir, THEME)
					if not bool(info["wall"]) and not bool(info["full_open"]):
						casing_cell = cell
						break
			if door_cell.x > 100000 and WorldGen.room_id(seed, cell) == cell \
					and WorldGen.room_size(seed, cell) == 1:
				for dir in 4:
					if bool(WorldGen.edge_info(seed, cell, dir, THEME)["wall"]):
						door_cell = cell
						break
			if passage_cells.size() == 2 and casing_cell.x < 100000 \
					and door_cell.x < 100000:
				break
		if passage_cells.size() == 2 and casing_cell.x < 100000 \
				and door_cell.x < 100000:
			break

	var failures := 0
	if passage_cells.size() != 2:
		failures += 1
		print("FAIL did not find both Monolith passage axes")
	for cell in passage_cells:
		var chunk := Chunk.new(seed, cell, THEME)
		root.add_child(chunk)
		var fixtures := _count_meta(chunk, "brutal_fluorescent_fixture")
		var ceilings := _count_meta_value(chunk, "brutal_tunnel_part", "ceiling")
		var side_walls := _count_meta_value(chunk, "brutal_tunnel_part", "side_wall")
		if fixtures != 4 or ceilings != 1 or side_walls < 2:
			failures += 1
			print("FAIL passage %s fixtures=%d ceiling=%d side_walls=%d" % [
				cell, fixtures, ceilings, side_walls])
		var axis := WorldGen.corridor(seed, cell)
		var side_dirs := [2, 3] if axis == 1 else [0, 1]
		for dir in side_dirs:
			if bool(WorldGen.edge_info(seed, cell, dir, THEME)["full_open"]):
				failures += 1
				print("FAIL passage %s side dir %d is fully open" % [cell, dir])
		root.remove_child(chunk)
		chunk.free()

	if casing_cell.x > 100000:
		failures += 1
		print("FAIL no cased Monolith opening found")
	else:
		var chunk := Chunk.new(seed, casing_cell, THEME)
		root.add_child(chunk)
		var casings := 0
		for node in chunk.find_children("*", "MeshInstance3D", true, false):
			if not bool(node.get_meta("brutal_door_casing", false)):
				continue
			casings += 1
			if absf(float(node.get_meta("brutal_door_head", -1.0)) \
					- chunk.BRUTAL_DOOR_TOP) > 0.001:
				failures += 1
		if casings < 3:
			failures += 1
			print("FAIL cased opening %s has %d casing pieces" % [casing_cell, casings])
		root.remove_child(chunk)
		chunk.free()

	# Search a bounded set of eligible cells until the deterministic facade
	# gate produces one. This proves the Annex model reaches generated Monolith.
	var reused_doors := 0
	for x in range(-12, 13):
		if reused_doors > 0:
			break
		for z in range(-12, 13):
			var cell := Vector2i(x, z)
			var chunk := Chunk.new(seed, cell, THEME)
			root.add_child(chunk)
			reused_doors += _count_meta(chunk, "monolith_annex_door")
			root.remove_child(chunk)
			chunk.free()
			if reused_doors > 0:
				break
	if reused_doors == 0:
		failures += 1
		print("FAIL Annex exit-door model never reached the Monolith")

	# The early Bloom incursion is intentionally rare, but it must remain
	# reachable and strictly decorative when its deterministic gate opens.
	var organic_traces := 0
	for x in range(-8, 9):
		if organic_traces > 0:
			break
		for z in range(-8, 9):
			var cell := Vector2i(x, z)
			# Use a procedural-only trace so freeing this short-lived audit chunk
			# does not tear down an imported scene's renderer state mid-frame.
			if cell == Vector2i.ZERO \
					or WorldGen.r01(seed, cell.x, cell.y, 2230) >= 0.075 \
					or WorldGen.r01(seed, cell.x, cell.y, 2234) < 0.34:
				continue
			var chunk := Chunk.new(seed, cell, THEME)
			root.add_child(chunk)
			var traces := _count_meta(chunk, "monolith_organic_trace")
			if traces > 0:
				organic_traces += traces
				var tendrils := _count_meta(chunk, "monolith_organic_tendril")
				if tendrils != 2:
					failures += 1
					print("FAIL Monolith incursion %s has %d tendrils" % [
						cell, tendrils])
			root.remove_child(chunk)
			chunk.free()
			if organic_traces > 0:
				break
	if organic_traces == 0:
		failures += 1
		print("FAIL no early organic trace reached the Monolith")

	Chunk.finish_prop_preloads()
	if failures == 0:
		print("brutalist audit: PASS — structure, fixtures, casing, Annex door and rare organic trace verified")
		quit()
	else:
		print("brutalist audit: FAIL (%d violations)" % failures)
		quit(1)


func _count_meta(node: Node, key: String) -> int:
	var total := 0
	for child in node.find_children("*", "Node3D", true, false):
		if bool(child.get_meta(key, false)):
			total += 1
	return total


func _count_meta_value(node: Node, key: String, value: String) -> int:
	var total := 0
	for child in node.find_children("*", "Node3D", true, false):
		if str(child.get_meta(key, "")) == value:
			total += 1
	return total
