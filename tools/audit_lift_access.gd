extends "res://tools/lib/audit_base.gd"
## Real lift targets, four orientations: room membership, occlusion and stale E.
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := Player.new()
	stage.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var route := DescentRoute.build(21, 0, 0)
	for direction in 4:
		var chunk := Chunk.new(21, route.target, 0, {
			"descent": true, "target": true, "target_wall": direction,
			"final": false, "floor_idx": 0})
		stage.add_child(chunk)
		chunk.position = Vector3(route.target.x * 12, 0, route.target.y * 12)
		var hit := chunk.find_child("DescentLiftCall", true, false) as Interactable
		expect(hit != null, "lift missing in direction %d" % direction)
		if hit == null:
			chunk.free()
			continue
		var stand := hit.global_position + hit.global_basis.z * 2.0
		player.global_position = stand - Vector3.UP * Player.CAM_H
		player.cam.global_position = stand
		player.cam.look_at(hit.global_position)
		await physics_frame
		await physics_frame
		expect(hit.can_interact(player), "visible in-room lift refused direction %d" % direction)
		player._scan_interaction()
		expect(player._focused == hit, "visible lift has no prompt direction %d" % direction)
		var members := WorldGen.owning_room_members(21, route.target, 0)
		var other := route.target + Vector2i(5, 5)
		player.global_position = Vector3(other.x * 12 + 6, 0, other.y * 12 + 6)
		expect(not hit.can_interact(player), "other room could call lift")
		# The room contract is ownership, not equality with the lift's cell.
		for member in members:
			player.global_position = Vector3(member.x * 12 + 6, 0, member.y * 12 + 6)
			expect(hit.can_interact(player), "merged-room member rejected")
		player.global_position = stand - Vector3.UP * Player.CAM_H
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3, 3, 0.15)
		shape.shape = box
		wall.add_child(shape)
		stage.add_child(wall)
		wall.global_transform = hit.global_transform
		wall.position += hit.global_basis.z * 1.0
		await physics_frame
		await physics_frame
		expect(not hit.can_interact(player), "wall did not block lift interaction")
		# Focus came from before the wall appeared; E must revalidate it.
		hit.interact(player)
		expect(hit.enabled, "stale interaction called lift through wall")
		player._scan_interaction()
		expect(player._focused != hit, "lift prompt visible through wall")
		wall.free()
		await physics_frame
		await physics_frame
		player.cam.rotate_y(PI)
		expect(not hit.can_interact(player), "looking away still permits call")
		player.cam.rotate_y(PI)
		hit.interact(player)
		expect(not hit.enabled, "valid visible call did not activate lift")
		chunk.free()
		await process_frame
	await teardown_game(stage)
	finish("lift access: four facings, same room, wall occlusion, stale press, valid call")
