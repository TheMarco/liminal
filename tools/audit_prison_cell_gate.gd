extends "res://tools/lib/audit_base.gd"
## Compare the imported sliding leaf to the actual player collision on all four walls.

func run() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS
	capsule.height = Player.BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var fixtures: Array[Dictionary] = []
	for dir in 4:
		for side: float in [-1.0, 1.0]:
			for opened: bool in [false, true]:
				var room := Chunk.new(1299797849, Vector2i.ZERO, 8, {}, true)
				room.position.x = fixtures.size() * 24.0
				room._level_builder._cell_gate(dir, 6.0, 2.6, 2.55, opened, side)
				root.add_child(room)
				fixtures.append({"room":room, "opened":opened})
	await physics_frame
	await physics_frame
	for fixture in fixtures:
		var room: Chunk = fixture.room
		var leaf := room.find_child("SlidingLeaf", true, false) as MeshInstance3D
		expect(leaf != null, "Gate is missing its authored sliding leaf")
		if leaf == null: continue
		var model := leaf.get_parent() as Node3D
		var pivot := model.get_parent() as Node3D
		var fixed_panel := model.find_child("FixedPanel", true, false) as MeshInstance3D
		expect(fixed_panel != null and fixed_panel.position.is_zero_approx(), "Fixed bars moved out of the bay")
		var left_edge := model.transform * (leaf.transform * leaf.get_aabb().position)
		expect(absf(left_edge.x - (-0.02 if fixture.opened else -0.92)) < 0.03,
			"Visible leading edge differs from the gate opening")
		for x: float in [-1.12, -0.50, 0.65]:
			query.transform.origin = pivot.to_global(Vector3(x, Player.BODY_HEIGHT * 0.5, 0.0))
			var hits := room.get_world_3d().direct_space_state.intersect_shape(query, 1)
			var should_pass: bool = fixture.opened and x == -0.50
			expect(hits.is_empty() == should_pass, "Player clearance disagrees with bars at %s" % query.transform.origin)
		room.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("16 prison gates, both slide directions, open and closed player clearance")
