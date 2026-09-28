extends "res://tools/lib/audit_base.gd"
## Real lift targets, four orientations: room membership, occlusion and stale E.

class ArrivalObserver extends Node:
	var spent_count := 0

	func descent_arrival_spent() -> void:
		spent_count += 1


func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var observer := ArrivalObserver.new()
	stage.add_child(observer)
	observer.add_to_group("descent_listener")
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
		await _audit_arrival_reentry(stage, player, observer, direction)
	await teardown_game(stage)
	finish("lift access: four facings, call access, arrival re-entry before/during closure and empty retirement")


func _walk_car(player: Player, car: Node3D, z: float, label: String) -> void:
	var target := car.to_global(Vector3(0.0, 0.15, z))
	var blocker := "none"
	for step in 180:
		await physics_frame
		var offset := target - player.global_position
		if offset.length() < 0.025:
			return
		var collision := player.move_and_collide(offset.limit_length(Player.WALK_SPEED / 60.0))
		if collision != null:
			blocker = str(collision.get_collider().get_path())
	fail("arrival walk blocked: %s at %s by %s" % [
		label, car.to_local(player.global_position), blocker])


func _audit_arrival_reentry(stage: Node3D, player: Player,
		observer: ArrivalObserver, direction: int) -> void:
	observer.spent_count = 0
	var chunk := Chunk.new(21, Vector2i.ZERO, 0, {
		"descent": true, "arrival": true, "arrival_wall": direction,
		"floor_idx": 0}, true)
	stage.add_child(chunk)
	# Build the production car in isolation; an arbitrary generated room can
	# put unrelated furniture in this test's straight approach path.
	chunk._descent_arrival_car(direction)
	var rig: Dictionary = chunk._descent_arrival_rig
	var car: Node3D = rig["root"]
	var left: AnimatableBody3D = rig["left"]
	var light: OmniLight3D = rig["light"]
	player.global_position = car.to_global(Vector3(0.0, 0.15, 1.12))
	await physics_frame
	await physics_frame
	chunk.open_descent_arrival()
	expect(await await_until(func(): return left.position.x <= -1.01),
		"arrival failed to open in facing %d" % direction)

	# Reverse course during the delay, then stay inside past both timers.
	await _walk_car(player, car, 3.6, "first exit %d" % direction)
	await _walk_car(player, car, 1.12, "return before closing %d" % direction)
	await create_timer(2.8).timeout
	expect(left.position.x <= -1.01 and light.visible and observer.spent_count == 0,
		"arrival retired after returning during delay, facing %d" % direction)

	# Start back after the leaves are actually moving. Stop in the doorway:
	# the player must not need to reach the cabin centre to stop the doors.
	await _walk_car(player, car, 3.6, "second exit %d" % direction)
	expect(await await_until(func(): return left.position.x > -1.0),
		"empty arrival never started closing, facing %d" % direction)
	await _walk_car(player, car, 2.3, "return during closing %d" % direction)
	await create_timer(1.2).timeout
	expect(left.position.x <= -1.01 and light.visible and observer.spent_count == 0,
		"arrival sealed an occupied doorway, facing %d" % direction)
	await _walk_car(player, car, 1.12, "back into cabin %d" % direction)
	await create_timer(1.8).timeout
	expect(left.position.x <= -1.01 and observer.spent_count == 0,
		"stale close retired a reoccupied arrival, facing %d" % direction)

	await _walk_car(player, car, 3.6, "final escape %d" % direction)
	expect(await await_until(func(): return not light.visible),
		"empty arrival did not retire, facing %d" % direction)
	await physics_frame
	await physics_frame
	expect(is_equal_approx(left.position.x, -0.54) and observer.spent_count == 1 \
			and chunk.descent_arrival_used,
		"arrival retirement facing %d: leaf %.4f, spent %d, used %s" % [
			direction, left.position.x, observer.spent_count, chunk.descent_arrival_used])
	chunk.free()
	await physics_frame
	var rebuilt := Chunk.new(21, Vector2i.ZERO, 0, {
		"descent": true, "arrival": true, "arrival_wall": direction,
		"floor_idx": 0, "arrival_used": true}, true)
	stage.add_child(rebuilt)
	rebuilt._descent_arrival_car(direction)
	rebuilt.open_descent_arrival()
	var retired: Dictionary = rebuilt._descent_arrival_rig
	expect(not rebuilt.has_descent_arrival() and not retired["light"].visible \
			and is_equal_approx(retired["left"].position.x, -0.54),
		"retired arrival reopened after rebuilding, facing %d" % direction)
	rebuilt.free()
	await physics_frame
