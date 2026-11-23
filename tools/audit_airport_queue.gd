extends "res://tools/lib/audit_base.gd"
## Exercise the Airport check-in belts and the short out-of-service escalator belt.

class QueueChunk extends Chunk:
	func _doorway_clearance_rects(_photo_obstruction_only := false) -> Array[Rect2]:
		return [Rect2(4.9, 8.0, 0.6, 1.0)]


func _blocked(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D,
		from: Vector3, to: Vector3) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * Player.BODY_HEIGHT * 0.5)
	query.motion = to - from
	return space.cast_motion(query)[0] < 1.0


func run() -> void:
	var chunk := QueueChunk.new(9137, Vector2i.ZERO, 4, null, true)
	# Two parallel lanes, a perpendicular escalator belt, and a row interrupted by a doorway.
	var rows := [
		[Vector3(1, 0, 4), Vector3(9.4, 0, 4), 6],
		[Vector3(9.4, 0, 5.2), Vector3(1, 0, 5.2), 6],
		[Vector3(11, 0, 3), Vector3(11, 0, 4.2), 2],
		[Vector3(1, 0, 8.5), Vector3(9.4, 0, 8.5), 6],
	]
	var first := chunk.get_child_count()
	var doorways := chunk._doorway_clearance_rects()
	for row: Array in rows:
		chunk._level_builder._stanchion_line(row[0], row[1], row[2], doorways)
	chunk._clear_furnishings_from_doorways(first, 0)
	root.add_child(chunk)
	await physics_frame
	await physics_frame
	var strips: Array[AABB] = []
	for mesh: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override == Mats.rubber_black():
			strips.append(mesh.global_transform * mesh.get_aabb())
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS
	capsule.height = Player.BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var space := root.world_3d.direct_space_state
	for r in rows.size():
		var a: Vector3 = rows[r][0]
		var b: Vector3 = rows[r][1]
		var spans: int = rows[r][2] - 1
		var along := (b - a).normalized()
		var across := along.cross(Vector3.UP) * 0.6
		for i in spans:
			var p := a.lerp(b, float(i) / spans)
			var q := a.lerp(b, float(i + 1) / spans)
			var mid := (p + q) * 0.5
			var is_belt := r != 3 or i != 2
			var label := "row %d span %d" % [r, i]
			for point: Vector3 in [p + along * 0.05, mid, q - along * 0.05]:
				var at_socket_height := point + Vector3.UP * 0.91
				expect(strips.any(func(box: AABB) -> bool: return box.has_point(at_socket_height)) == is_belt,
					"%s: unexpected belt coverage at %s" % [label, at_socket_height])
			expect(_blocked(space, query, mid - across, mid + across) == is_belt, label + " crossing")
			expect(_blocked(space, query, mid + across, mid - across) == is_belt, label + " reverse crossing")
	expect(not _blocked(space, query, Vector3(0, 0, 4.6), Vector3(10, 0, 4.6)), "walking down the lane")
	for end_x in [0.4, 10.0]:
		expect(not _blocked(space, query, Vector3(end_x, 0, 3), Vector3(end_x, 0, 6)), "walking around a row end")
	var post := PhysicsRayQueryParameters3D.create(Vector3(1, 0.4, 3.5), Vector3(1, 0.4, 4.5))
	var below_belt := PhysicsRayQueryParameters3D.create(Vector3(1.84, 0.4, 3.5), Vector3(1.84, 0.4, 4.5))
	expect(not space.intersect_ray(post).is_empty(), "missing collision on the end post")
	expect(space.intersect_ray(below_belt).is_empty(), "unexpected collision below the belt")
	expect(chunk.doorway_clearance_violations() == 0, "queue encroaches on doorway")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("Airport queue belts meet the reels and block crossings while lanes and the doorway stay open")
