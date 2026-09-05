extends SceneTree
## Regression audit for the Data Center's authored infrastructure, fixtures,
## exact-height portal casings, compressed passage shell and reused Annex door.
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
	var rack_cell := Vector2i(1 << 20, 1 << 20)
	var riser_cell := Vector2i(1 << 20, 1 << 20)
	var riser_score := -1
	var service_cell := Vector2i(1 << 20, 1 << 20)
	var sanctum_cell := Vector2i(1 << 20, 1 << 20)
	var large_rack_cell := Vector2i(1 << 20, 1 << 20)
	var cooling_cell := Vector2i(1 << 20, 1 << 20)
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
			if WorldGen.room_id(seed, cell) == cell:
				var style := WorldGen.cell_style(seed, cell, THEME)
				if rack_cell.x > 100000 and (style == WorldGen.BRUTAL_HALL \
						or style == WorldGen.BRUTAL_GALLERY):
					rack_cell = cell
				if style == WorldGen.BRUTAL_RAMP:
					var score := WorldGen.room_size(seed, cell) * 10
					if WorldGen.room_split(seed, cell, THEME).is_empty():
						score += 5
					if score > riser_score:
						riser_score = score
						riser_cell = cell
				if service_cell.x > 100000 and style == WorldGen.BRUTAL_SERVICE:
					service_cell = cell
				if sanctum_cell.x > 100000 and style == WorldGen.BRUTAL_SANCTUM:
					sanctum_cell = cell
				if large_rack_cell.x > 100000 \
						and WorldGen.room_size(seed, cell) >= 4 \
						and style in [WorldGen.BRUTAL_HALL,
							WorldGen.BRUTAL_GALLERY, WorldGen.BRUTAL_ATRIUM,
							WorldGen.BRUTAL_RAMP, WorldGen.BRUTAL_SERVICE,
							WorldGen.BRUTAL_SANCTUM]:
					large_rack_cell = cell
				if cooling_cell.x > 100000 \
						and style == WorldGen.BRUTAL_WATER_COURT:
					cooling_cell = cell

	var failures := 0
	if passage_cells.size() != 2:
		failures += 1
		print("FAIL did not find both Data Center passage axes")
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
		var passage_racks := _count_meta(chunk, "data_center_passage_rack")
		var left_racks := _count_meta_int(chunk, "data_center_passage_side", -1)
		var right_racks := _count_meta_int(chunk, "data_center_passage_side", 1)
		var unsupported_panels := _count_meta(chunk,
			"data_center_passage_infrastructure")
		var passage_busways := _count_meta(chunk,
			"data_center_overhead_busway")
		if passage_racks < 8 or left_racks < 4 or right_racks < 4 \
				or passage_busways != 2 or unsupported_panels != 0:
			failures += 1
			print("FAIL passage %s racks=%d left/right=%d/%d busways=%d floating_panels=%d" % [
				cell, passage_racks, left_racks, right_racks, passage_busways,
				unsupported_panels])
		if chunk.atomic_furnishing_support_violations() != 0:
			failures += 1
			print("FAIL passage %s has unsupported/floating rack furniture" % cell)
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
		print("FAIL no cased Data Center opening found")
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
	# gate produces one. This proves the Annex model reaches the Data Center.
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
		print("FAIL Annex exit-door model never reached the Data Center")

	# The arrival chamber must present the remodel immediately, and the two
	# dominant room families must retain dense authored infrastructure.
	var arrival := Chunk.new(seed, Vector2i.ZERO, THEME)
	root.add_child(arrival)
	var arrival_racks := _count_meta(arrival, "data_center_rack")
	var arrival_busways := _count_meta(arrival, "data_center_overhead_busway")
	if arrival_racks < 14 or arrival_busways < 4:
		failures += 1
		print("FAIL arrival infrastructure racks=%d busways=%d culled=%d counts=%s" % [
			arrival_racks, arrival_busways, arrival.doorway_props_removed,
			arrival.authored_furnishing_counts()])
	if _has_material_named(arrival, "brutal_black_water"):
		failures += 1
		print("FAIL arrival retained the removed glossy black court material")
	root.remove_child(arrival)
	arrival.free()

	if rack_cell.x > 100000:
		failures += 1
		print("FAIL no server hall or rack gallery anchor found")
	else:
		var rack_room := Chunk.new(seed, rack_cell, THEME)
		root.add_child(rack_room)
		var racks := _count_meta(rack_room, "data_center_rack")
		var busways := _count_meta(rack_room, "data_center_overhead_busway")
		if racks < 12 or busways < 4:
			failures += 1
			print("FAIL rack room %s racks=%d busways=%d" % [
				rack_cell, racks, busways])
		root.remove_child(rack_room)
		rack_room.free()

	# The former dead-end stair room is now one of the densest switching aisles.
	# Doorway culling can remove end cabinets, but both banks and multiple rack
	# models must survive around the transverse service gap.
	if riser_cell.x > 100000:
		failures += 1
		print("FAIL no former cable-riser anchor found")
	else:
		var riser_room := Chunk.new(seed, riser_cell, THEME)
		root.add_child(riser_room)
		var riser_racks := _count_meta(riser_room, "data_center_rack")
		var riser_kinds := _meta_values(riser_room, "data_center_kind")
		var riser_busways := _count_meta(riser_room,
			"data_center_overhead_busway")
		if riser_racks < 12 or riser_kinds.size() < 2 or riser_busways < 4:
			failures += 1
			print("FAIL dense switching aisle %s racks=%d kinds=%s busways=%d" % [
				riser_cell, riser_racks, riser_kinds, riser_busways])
		if riser_room.doorway_clearance_violations() != 0:
			failures += 1
			print("FAIL dense switching aisle blocks a doorway")
		root.remove_child(riser_room)
		riser_room.free()

	if service_cell.x > 100000:
		failures += 1
		print("FAIL no Data Center service-room anchor found")
	else:
		var service_room := Chunk.new(seed, service_cell, THEME)
		root.add_child(service_room)
		var service_racks := _count_meta(service_room, "data_center_rack")
		if service_racks < 12:
			failures += 1
			print("FAIL service room %s only has %d racks" % [
				service_cell, service_racks])
		root.remove_child(service_room)
		service_room.free()

	if sanctum_cell.x > 100000:
		failures += 1
		print("FAIL no Data Center core-vault anchor found")
	else:
		var sanctum_room := Chunk.new(seed, sanctum_cell, THEME)
		root.add_child(sanctum_room)
		var sanctum_racks := _count_meta(sanctum_room, "data_center_rack")
		var hero_racks := _count_meta_value(sanctum_room,
			"data_center_kind", "data_center_detailed_server_rack")
		if sanctum_racks < 14 or hero_racks != 1:
			failures += 1
			print("FAIL core vault %s racks=%d hero=%d" % [
				sanctum_cell, sanctum_racks, hero_racks])
		root.remove_child(sanctum_room)
		sanctum_room.free()

	if large_rack_cell.x > 100000:
		failures += 1
		print("FAIL no 24m Data Center rack chamber found")
	else:
		var large_room := Chunk.new(seed, large_rack_cell, THEME)
		root.add_child(large_room)
		var large_racks := _count_meta(large_room, "data_center_rack")
		var large_busways := _count_meta(large_room,
			"data_center_overhead_busway")
		if large_racks < 50 or large_busways < 8:
			failures += 1
			print("FAIL 24m rack chamber %s racks=%d busways=%d" % [
				large_rack_cell, large_racks, large_busways])
		if large_room.doorway_clearance_violations() != 0:
			failures += 1
			print("FAIL 24m rack chamber blocks a doorway")
		root.remove_child(large_room)
		large_room.free()

	if cooling_cell.x > 100000:
		failures += 1
		print("FAIL no cooling-plant anchor found")
	else:
		var cooling_room := Chunk.new(seed, cooling_cell, THEME)
		root.add_child(cooling_room)
		var cooling_units := _count_meta(cooling_room, "data_center_cooling")
		var cooling_racks := _count_meta(cooling_room, "data_center_rack")
		var variants := _meta_values(cooling_room,
			"data_center_cooling_variant")
		# Cooling is supporting infrastructure inside a rack hall, not the room's
		# only content: two individual variants service a dense server field.
		if cooling_units < 2 or variants.size() < 2 or cooling_racks < 12:
			failures += 1
			print("FAIL cooling plant %s racks=%d units=%d variants=%s" % [
				cooling_cell, cooling_racks, cooling_units, variants])
		if _has_material_named(cooling_room, "brutal_black_water"):
			failures += 1
			print("FAIL cooling plant retained the glossy black court material")
		root.remove_child(cooling_room)
		cooling_room.free()

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
					print("FAIL Data Center incursion %s has %d tendrils" % [
						cell, tendrils])
			root.remove_child(chunk)
			chunk.free()
			if organic_traces > 0:
				break
	if organic_traces == 0:
		failures += 1
		print("FAIL no early organic trace reached the Data Center")

	# The supplied machinery recording is this floor's only continuous score.
	# It must retain its normalized mix, loop seamlessly, and follow the one-second
	# powered fade without restarting.
	if not ResourceLoader.exists("res://sounds/data-center-ambient.mp3"):
		failures += 1
		print("FAIL Data Center ambient loop is missing")
	elif not Sfx.has_bed(THEME):
		failures += 1
		print("FAIL Data Center ambient loop is not registered")
	else:
		var bed: Array = Sfx.bed(THEME)
		if bed.is_empty() or not (bed[0] is AudioStreamMP3) \
				or not (bed[0] as AudioStreamMP3).loop:
			failures += 1
			print("FAIL Data Center ambient recording is not looping")
		elif not is_equal_approx(float(bed[1]), -14.8):
			failures += 1
			print("FAIL Data Center ambient trim is not meter-calibrated: %s" % bed[1])
		var power_bed := Ambience.new(THEME)
		root.add_child(power_bed)
		await process_frame
		var powered_db := power_bed.volume_db
		power_bed.set_powered(false)
		await create_timer(Ambience.POWER_FADE_SECONDS + 0.05).timeout
		if absf(power_bed.volume_db - Ambience.POWER_SILENCE_DB) > 0.1:
			failures += 1
			print("FAIL Data Center bed did not fade out with the power")
		power_bed.set_powered(true)
		await create_timer(Ambience.POWER_FADE_SECONDS + 0.05).timeout
		if absf(power_bed.volume_db - powered_db) > 0.1:
			failures += 1
			print("FAIL Data Center bed did not fade back after power restoration")
		power_bed.stop()
		await process_frame
		power_bed.stream = null
		root.remove_child(power_bed)
		power_bed.free()
		bed.clear()
		Sfx._c.clear()
		await process_frame

	# Imported rack scenes, tuned materials and the MP3 stream are process-lifetime
	# production caches. A short audit must release them before quitting or the
	# suite correctly treats their live renderer/audio RIDs as a leak.
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if failures == 0:
		print("data-center audit: PASS — racks, individual cooling units, service infrastructure, structure and rare organic trace verified")
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


func _count_meta_int(node: Node, key: String, value: int) -> int:
	var total := 0
	for child in node.find_children("*", "Node3D", true, false):
		if int(child.get_meta(key, 0)) == value:
			total += 1
	return total


func _meta_values(node: Node, key: String) -> Array:
	var values: Array = []
	for child in node.find_children("*", "Node3D", true, false):
		if child.has_meta(key) and not values.has(child.get_meta(key)):
			values.append(child.get_meta(key))
	return values


func _has_material_named(node: Node, material_name: String) -> bool:
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := found as MeshInstance3D
		if mesh_node.material_override != null \
				and mesh_node.material_override.resource_name == material_name:
			return true
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(surface)
			if material != null and material.resource_name == material_name:
				return true
	return false
