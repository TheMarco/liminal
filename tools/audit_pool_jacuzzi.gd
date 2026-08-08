extends SceneTree
## Contract for the guaranteed start-room jacuzzi.
##
## Run:
##   godot --headless --path . --script tools/audit_pool_jacuzzi.gd

const THEME := 9
const WORLD_SEED := 1065674081


func _init() -> void:
	var failures: Array[String] = []
	var ws := WorldGen.level_seed(WORLD_SEED, THEME)
	var chunk := Chunk.new(ws, Vector2i.ZERO, THEME)
	root.add_child(chunk)
	await physics_frame

	var jacuzzis := _nodes_with_meta(chunk, "pool_jacuzzi")
	var exits := _areas_with_meta(chunk, "pool_jacuzzi_exit_volume")
	var bottoms := _meshes_with_meta(chunk, "pool_jacuzzi_basin_floor")
	var collars := _meshes_with_meta(chunk, "pool_jacuzzi_flush_collar")
	var cutout_corners := _meshes_with_meta(
		chunk, "pool_jacuzzi_cutout_corner")
	if jacuzzis.size() != 1:
		failures.append(
			"expected one guaranteed start-room jacuzzi, built %d" % jacuzzis.size())
	if exits.size() != 1:
		failures.append(
			"expected one jacuzzi climb-out volume, built %d" % exits.size())
	if bottoms.size() != 1:
		failures.append(
			"expected one jacuzzi basin floor, built %d" % bottoms.size())
	if not collars.is_empty():
		failures.append(
			"jacuzzi still has %d added coping collar(s)" % collars.size())
	if cutout_corners.size() != 4:
		failures.append(
			"rounded jacuzzi cutout has %d/4 corner fills" % [
				cutout_corners.size()])
	if jacuzzis.size() == 1:
		var reveal := float(jacuzzis[0].get_meta(
			"pool_jacuzzi_deck_reveal", 0.0))
		if reveal < 0.05:
			failures.append(
				"jacuzzi molded rim is not raised clearly above deck")
		var waters := _meshes_with_meta(jacuzzis[0], "pool_jacuzzi_water")
		if waters.size() != 1:
			failures.append(
				"expected one raised jacuzzi water surface, built %d" % waters.size())
		elif absf(waters[0].global_position.y - (Chunk.POOL_DRY_Y - 0.12)) > 0.01:
			failures.append(
				"jacuzzi water is not 12cm below the flush rim")

	if exits.size() == 1:
		var exit := exits[0]
		if exit.collision_layer != Player.LADDER_LAYER \
				or exit.collision_mask != 0:
			failures.append("jacuzzi climb-out volume uses the wrong collision layer")
		var shapes := exit.find_children(
			"*", "CollisionShape3D", true, false)
		if shapes.size() != 4:
			failures.append(
				"expected four climbable inside edges, built %d" % shapes.size())
		else:
			for shape in shapes:
				if not (shape.shape is BoxShape3D):
					failures.append("jacuzzi climb-out edge is not a box")
					break
		_check_exit_queries(chunk, exit, failures)

	if jacuzzis.size() == 1 and bottoms.size() == 1:
		_check_visible_bath_footprint(jacuzzis[0], bottoms[0], failures)

	for failure in failures:
		print("  FAIL " + failure)
	chunk.queue_free()
	await process_frame
	if not failures.is_empty():
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		quit(1)
		return
	print("pool jacuzzi audit: PASS — authored rim only, raised water and four climb-out edges active")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()


func _check_exit_queries(chunk: Chunk, exit: Area3D,
		failures: Array[String]) -> void:
	var shape_nodes := exit.find_children(
		"*", "CollisionShape3D", true, false)
	for i in shape_nodes.size():
		var shape_node := shape_nodes[i] as CollisionShape3D
		var inside := exit.global_position + shape_node.position
		inside.y = 0.90
		if not _ladder_query_hits(chunk, inside):
			failures.append("climb-out edge %d is not found by the player query" % i)
	var on_deck := exit.global_position
	on_deck.y = Chunk.POOL_DRY_Y + 0.90
	if _ladder_query_hits(chunk, on_deck):
		failures.append("climb-out volume catches a player already standing on deck")


func _ladder_query_hits(chunk: Chunk, at: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Player.LADDER_LAYER
	return not chunk.get_world_3d().direct_space_state.intersect_point(
		q, 8).is_empty()


func _check_visible_bath_footprint(jacuzzi: Node, bottom: MeshInstance3D,
		failures: Array[String]) -> void:
	var bath := jacuzzi.find_child("Bath_Bath_0", true, false) as MeshInstance3D
	if bath == null:
		failures.append("authored white Bath mesh is missing")
		return
	var bath_bounds := bath.global_transform * bath.get_aabb()
	var hole_bounds := bottom.global_transform * bottom.get_aabb()
	var eps := 0.025
	var overlap_x := minf(
		hole_bounds.position.x - bath_bounds.position.x,
		bath_bounds.end.x - hole_bounds.end.x)
	var overlap_z := minf(
		hole_bounds.position.z - bath_bounds.position.z,
		bath_bounds.end.z - hole_bounds.end.z)
	if overlap_x < 0.05 - eps or overlap_z < 0.05 - eps:
		failures.append(
			"structural opening escapes the outer white Bath rim")
	var rim_height := bath_bounds.end.y - Chunk.POOL_DRY_Y
	var expected_rim_height := float(jacuzzi.get_meta(
		"pool_jacuzzi_deck_reveal", 0.0)) + 0.017
	if absf(rim_height - expected_rim_height) > 0.015:
		failures.append(
			"jacuzzi rim height %.3f does not match intended %.3f" % [
				rim_height, expected_rim_height])


func _nodes_with_meta(root_node: Node, key: String) -> Array[Node]:
	var result: Array[Node] = []
	for node in root_node.find_children("*", "", true, false):
		if node.has_meta(key):
			result.append(node)
	return result


func _areas_with_meta(root_node: Node, key: String) -> Array[Area3D]:
	var result: Array[Area3D] = []
	for node in root_node.find_children("*", "Area3D", true, false):
		if node.has_meta(key):
			result.append(node as Area3D)
	return result


func _meshes_with_meta(root_node: Node, key: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta(key):
			result.append(node as MeshInstance3D)
	return result
