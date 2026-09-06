extends SceneTree

const Equipment = preload("res://scripts/pool_equipment.gd")
const THEME := 9
const SEEDS := [1029384756, 405195947, 918273645, 246813579, 135792468,
	777777777, 314159265, 271828182, 42424242, 987654321, 1122334455,
	556677889]
const TRI_LIMITS := [1800, 4000, 6500]
var _collision: Dictionary = {}
var _mesh_stats: Dictionary = {}

var failures: Array[String] = []
var first_seen := {}
var counts := {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_assets()
	for seed: int in SEEDS:
		var candidates := 0
		for x in range(-10, 11):
			for z in range(-10, 11):
				if candidates >= 40: break
				var cell := Vector2i(x, z)
				if WorldGen.room_id(seed, cell) != cell: continue
				var style := WorldGen.cell_style(seed, cell, THEME)
				if style not in [WorldGen.POOL_BASIN, WorldGen.POOL_CISTERN]: continue
				if WorldGen.pool_equipment_kind(seed, cell) < 0: continue
				candidates += 1
				var chunk := Chunk.new(seed, cell, THEME)
				get_root().add_child(chunk)
				_check_chunk(chunk, seed, cell)
				chunk.free()
				await process_frame
	if first_seen.size() != Equipment.KINDS.size():
		_fail("not every equipment kind spawned: %s" % first_seen)
	# The old height/clearance gates produced almost all boards despite a
	# healthy total prop count. Check the actual mix, not merely one of each.
	var slides := int(counts.get("slide_straight", 0)) + int(counts.get("slide_spiral", 0))
	var total := slides + int(counts.get("diving_board", 0))
	if total < 300 or slides < total * 0.40 or int(counts.get("slide_spiral", 0)) < 30:
		_fail("slides too scarce across 12 seeds: %s" % counts)
	print("POOL_EQUIPMENT counts=%s first_seen=%s" % [counts, first_seen])
	for failure in failures: push_error("POOL_EQUIPMENT: " + failure)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	Equipment.clear_runtime_cache()
	if failures.is_empty(): print("POOL_EQUIPMENT PASS")
	quit(1 if not failures.is_empty() else 0)

func _check_assets() -> void:
	_mesh_stats = JSON.parse_string(FileAccess.get_file_as_string(
		"res://models/authored/pool_equipment/mesh_stats.json"))
	_collision = JSON.parse_string(FileAccess.get_file_as_string(
		"res://models/authored/pool_equipment/collision.json"))
	for i in Equipment.PATHS.size():
		var path: String = Equipment.PATHS[i]
		if not FileAccess.file_exists(path):
			_fail("missing asset " + path); continue
		if not Chunk.theme_prop_paths(THEME).has(path): _fail("missing theme preload " + path)
		var instance: Node = load(path).instantiate()
		get_root().add_child(instance)
		var meshes: Array[Node] = instance.find_children("*", "MeshInstance3D", true, false)
		var triangles := 0
		var bounds := AABB()
		var has_bounds := false
		for mesh_node: MeshInstance3D in meshes:
			if mesh_node.mesh == null: continue
			if mesh_node.mesh.get_surface_count() > 3: _fail("surface budget " + path)
			for surface in mesh_node.mesh.get_surface_count():
				var arrays := mesh_node.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3) if not indices.is_empty() else int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
			var box := mesh_node.global_transform * mesh_node.mesh.get_aabb()
			bounds = box if not has_bounds else bounds.merge(box); has_bounds = true
		if meshes.size() != 1 or triangles <= 0 or triangles > TRI_LIMITS[i]:
			_fail("geometry budget %s meshes=%d triangles=%d" % [path, meshes.size(), triangles])
		var expected: int = int(_mesh_stats["pool_" + Equipment.KINDS[i]]["triangles"])
		if triangles != expected: _fail("triangle stats mismatch %s actual=%d expected=%d" % [path, triangles, expected])
		if has_bounds and (bounds.size.x < 0.05 or bounds.size.y < 0.01 or bounds.size.z < 0.05):
			_fail("tiny geometry " + path)
		instance.free()
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets.count("collision.json") < 2: _fail("both export presets omit collision.json")
	for key: String in Equipment.KINDS:
		if not _collision.has("pool_" + key): _fail("collision missing " + key)

func _check_chunk(chunk: Chunk, seed: int, cell: Vector2i) -> void:
	var plans: Dictionary = chunk.get_meta("pool_equipment_plan", {})
	var props: Array[Node] = []
	for node in chunk.get_children():
		if node.has_meta("pool_equipment"): props.append(node)
	if props.size() > 1: _fail("multiple equipment props in %s" % cell)
	if props.is_empty(): return
	var prop: Node3D = props[0]
	var kind := str(prop.get_meta("pool_equipment"))
	counts[kind] = int(counts.get(kind, 0)) + 1
	if not first_seen.has(kind): first_seen[kind] = {"seed": seed, "cell": cell}
	if plans.is_empty(): _fail("equipment plan missing metadata %s" % cell); return
	var water_nodes := _meta_meshes(chunk, "pool_water_surface")
	if water_nodes.is_empty(): _fail("equipment has no water surface %s" % cell); return
	var water_center: Vector2 = water_nodes[0].get_meta("pool_water_center", Vector2.ZERO)
	var water_size: Vector2 = water_nodes[0].get_meta("pool_water_size", Vector2.ZERO)
	var water_rect := Rect2(water_center - water_size * 0.5, water_size)
	var landing: Rect2 = plans.get("landing", Rect2())
	if not water_rect.grow(-0.08).encloses(landing):
		_fail("landing outside water margin %s" % cell)
	for corner in _meta_meshes(chunk, "pool_rounded_basin_corner"):
		var bounds := corner.transform * corner.mesh.get_aabb()
		if landing.intersects(Rect2(Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.size.x, bounds.size.z))):
			_fail("landing intersects rounded deck corner %s" % cell)
	var occupied: Rect2 = plans["occupied"]
	for doorway in chunk._doorway_clearance_rects():
		if occupied.intersects(doorway):
			_fail("equipment blocks doorway %s" % cell)
	for lane: Rect2 in chunk.get_meta("pool_access_lanes", []):
		if lane != occupied and occupied.intersects(lane):
			_fail("equipment blocks pool exit %s" % cell)
	var meshes := prop.find_children("*", "MeshInstance3D", true, false)
	var model_box := AABB()
	var seeded := false
	for mesh_node: MeshInstance3D in meshes:
		var box := mesh_node.global_transform * mesh_node.mesh.get_aabb()
		model_box = box if not seeded else model_box.merge(box); seeded = true
	var ceiling := float(chunk._build_context.ceiling_height)
	if seeded and (model_box.position.x < 0.1 or model_box.end.x > 11.9
			or model_box.position.z < 0.1 or model_box.end.z > 11.9
			or model_box.end.y + 0.15 > ceiling):
		_fail("equipment exceeds room bounds %s" % cell)
	if not plans.has("deck"): _fail("equipment deck metadata missing %s" % cell)
	var deck: Rect2 = plans["deck"]
	var kind_key := "pool_" + kind
	for leg: Dictionary in _collision.get(kind_key, {}).get("support_legs", []):
		var foot: Vector3 = prop.to_global(Vector3(float(leg["a"][0]), float(leg["a"][1]), float(leg["a"][2])))
		if foot.y > Chunk.POOL_DECK_Y + 0.04 or not deck.has_point(Vector2(foot.x, foot.z)) \
				or water_rect.has_point(Vector2(foot.x, foot.z)):
			_fail("unsupported/wet equipment foot %s" % cell)
	var obstacles := _meta_meshes(chunk, "pool_pier")
	obstacles.append_array(_meta_meshes(chunk, "pool_rounded_pier_island"))
	for pier in obstacles:
		var pbox := pier.global_transform * pier.mesh.get_aabb()
		if seeded and Rect2(Vector2(pbox.position.x, pbox.position.z), Vector2(pbox.size.x, pbox.size.z)).intersects(landing):
			_fail("landing intersects pier island %s" % cell)
	var body := prop.find_child("EquipmentCollision", true, false)
	if body == null: _fail("equipment physical collision missing %s" % cell)
	if kind != "diving_board":
		var ladder := prop.find_child("SlideLadder", true, false)
		if ladder == null or not ladder is Area3D or not ladder.has_meta("pool_equipment_ladder"):
			_fail("slide ladder area missing %s" % cell)
		var trough_found := false
		for shape in prop.find_children("*", "CollisionShape3D", true, false):
			if shape.has_meta("pool_equipment_trough") and shape.shape is ConcavePolygonShape3D:
				trough_found = true
		if not trough_found:
			_fail("slide trough collision missing %s" % cell)

func _meta_meshes(root: Node, key: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(key): out.append(node)
	return out

func _fail(message: String) -> void:
	failures.append(message)
