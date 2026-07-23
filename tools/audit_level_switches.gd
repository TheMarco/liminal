extends SceneTree
## Regression test for the real runtime level-swap sequence. The outgoing
## floor must leave the physics world before the destination arrival resolver
## runs, or overlapping collision trees can reject every school landing.
## Run: godot --headless --path . --script tools/audit_level_switches.gd -- --nologo

const REGRESSION_SEED := 1760336105
const SCHOOL_CELL := Vector2i(-1, 0)
const SAVED_POSITION := Vector3(-6.0, 0.0, 6.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	game.world_seed = REGRESSION_SEED
	get_root().add_child(game)
	await physics_frame

	game._jump_to(6, SAVED_POSITION, false)
	var deadline := Time.get_ticks_msec() + 5000
	while game._switching and Time.get_ticks_msec() < deadline:
		await process_frame

	var failures := []
	if game._switching or game.active_level != 6:
		failures.append("school transition did not complete")
	elif game.level_root == null or not game.level_root.is_inside_tree():
		failures.append("school level is not active in the scene tree")
	else:
		await physics_frame
		var landed: Vector3 = game.player.global_position
		var actual_cell := Vector2i(floori(landed.x / 12.0), floori(landed.z / 12.0))
		if actual_cell != SCHOOL_CELL:
			failures.append("landing left regression cell: %s" % actual_cell)
		if not ArrivalSafety.is_clear(game.get_world_3d(), landed, [game.player.get_rid()]):
			failures.append("landed capsule overlaps generated geometry")
		if not ArrivalSafety.has_floor(game.get_world_3d(), landed, [game.player.get_rid()]):
			failures.append("landing has no supporting floor")
		if ArrivalSafety.escape_count(game.get_world_3d(), landed, [game.player.get_rid()]) < 2:
			failures.append("landing has fewer than two escape directions")

	print("level-switch audit: seed=%d target=school cell=%s player=%s" % [
		REGRESSION_SEED, SCHOOL_CELL, game.player.global_position])
	if failures.is_empty():
		print("  PASS — outgoing collision retired before the school arrival probe")
	else:
		for failure in failures:
			print("FAIL ", failure)
		_print_candidate_colliders(game)
	quit(0 if failures.is_empty() else 1)


func _print_candidate_colliders(game: Node) -> void:
	var world: World3D = game.get_world_3d()
	var exclude: Array[RID] = [game.player.get_rid()]
	for off in ArrivalSafety.OFFSETS:
		var p := Vector3(SCHOOL_CELL.x * 12.0 + off.x, 0.0,
			SCHOOL_CELL.y * 12.0 + off.y)
		var shape := CapsuleShape3D.new()
		shape.radius = ArrivalSafety.RADIUS
		shape.height = ArrivalSafety.HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,
			p + Vector3(0, ArrivalSafety.HEIGHT * 0.5, 0))
		query.collision_mask = 1
		query.collide_with_areas = false
		query.exclude = exclude
		var names := []
		for hit in world.direct_space_state.intersect_shape(query, 8):
			var collider: Object = hit["collider"]
			names.append(str(collider.get_path()) if collider is Node else str(collider))
		print("  candidate %s clear=%s floor=%s exits=%d hits=%s" % [p,
			ArrivalSafety.is_clear(world, p, exclude),
			ArrivalSafety.has_floor(world, p, exclude),
			ArrivalSafety.escape_count(world, p, exclude), names])
