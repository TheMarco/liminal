extends SceneTree

## A representative four-cell Cistern must read as one 18 x 18 m pool with
## multiple round supports, dry circulation on its outside, and open seams.

const SEED := 240721
const THEME := 9
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ws := WorldGen.level_seed(SEED, THEME)
	var root_cell := Vector2i(2147483647, 2147483647)
	for radius in range(1, 25):
		if root_cell.x != 2147483647:
			break
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) == cell \
						and WorldGen.pool_grand_cistern(ws, cell):
					root_cell = cell
					break
			if root_cell.x != 2147483647:
				break
	if root_cell.x == 2147483647:
		failures.append("no grand Cistern within 24 cells of the seed")
	else:
		var total_piers := 0
		for dx in 2:
			for dz in 2:
				var cell := root_cell + Vector2i(dx, dz)
				if not WorldGen.pool_grand_cistern(ws, cell):
					failures.append("%s is not in the grand Cistern" % cell)
					continue
				var chunk := Chunk.new(ws, cell, THEME)
				get_root().add_child(chunk)
				var waters := _with_meta(chunk, "pool_water_surface")
				var piers := _with_meta(chunk, "pool_grand_cistern_pier")
				var collars := _with_meta(chunk, "pool_grand_cistern_collar")
				var deck_piers := _with_meta(chunk, "pool_grand_cistern_deck_pier")
				var flamingos := []
				var mattresses := []
				var striped := []
				var rings := []
				for child in chunk.find_children("*", "RigidBody3D", true, false):
					if child.has_meta("pool_flamingo_float"):
						flamingos.append(child)
					if child.has_meta("pool_mattress_float"):
						mattresses.append(child)
					if child.has_meta("pool_striped_float"):
						striped.append(child)
					if child.has_meta("pool_ring_float"):
						rings.append(child)
				if waters.size() != 1:
					failures.append("%s has %d water surfaces" % [cell, waters.size()])
				else:
					var water: MeshInstance3D = waters[0]
					var center: Vector2 = water.get_meta("pool_water_center", Vector2.ZERO)
					var size: Vector2 = water.get_meta("pool_water_size", Vector2.ZERO)
					var x0 := center.x - size.x * 0.5
					var x1 := center.x + size.x * 0.5
					var z0 := center.y - size.y * 0.5
					var z1 := center.y + size.y * 0.5
					var expected_x0 := 3.0 if dx == 0 else 0.0
					var expected_x1 := 12.0 if dx == 0 else 9.0
					var expected_z0 := 3.0 if dz == 0 else 0.0
					var expected_z1 := 12.0 if dz == 0 else 9.0
					if not is_equal_approx(x0, expected_x0) \
							or not is_equal_approx(x1, expected_x1) \
							or not is_equal_approx(z0, expected_z0) \
							or not is_equal_approx(z1, expected_z1):
						failures.append("%s water bounds (%s, %s)-(%s, %s)" % [
							cell, x0, z0, x1, z1])
					var links: Array = water.get_meta("pool_water_edge_links", [])
					if not bool(water.get_meta("pool_water_connected", false)) \
							or not links.has(0 if dx == 0 else 1) \
							or not links.has(2 if dz == 0 else 3) \
							or links.size() != 2:
						failures.append("%s has wrong internal water links: %s" % [cell, links])
				if piers.size() < 4 or piers.size() > 5:
					failures.append("%s has %d columns" % [cell, piers.size()])
				total_piers += piers.size()
				if collars.size() != piers.size() * 2:
					failures.append("%s missing column collars" % cell)
				if deck_piers.size() != 1:
					failures.append("%s lacks a deck column" % cell)
				if chunk.doorway_clearance_violations() != 0:
					failures.append("%s has doorway obstruction" % cell)
				if chunk.has_meta("pool_equipment_plan"):
					failures.append("%s has pool equipment in its shared basin" % cell)
				if dx == 0 and dz == 0 and flamingos.size() != 1:
					failures.append("%s lacks its flamingo float" % cell)
				if dx == 1 and dz == 1 and mattresses.size() != 1:
					failures.append("%s lacks its colored mattress float" % cell)
				if dx == 1 and dz == 0 and striped.is_empty():
					failures.append("%s lacks its striped float" % cell)
				if dx == 0 and dz == 1 and rings.is_empty():
					failures.append("%s lacks its ring float" % cell)
				chunk.free()
				await process_frame
		if total_piers < 16:
			failures.append("only %d columns across the room" % total_piers)
		print("POOL_GRAND_CISTERN seed=%d root=%s columns=%d" % [
			ws, root_cell, total_piers])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		push_error("POOL_GRAND_CISTERN FAIL: " + failure)
	if failures.is_empty():
		print("POOL_GRAND_CISTERN PASS")
	quit(1 if not failures.is_empty() else 0)


func _with_meta(node: Node, key: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child.has_meta(key):
			found.append(child)
	return found
