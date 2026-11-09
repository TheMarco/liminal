extends "res://tools/lib/audit_base.gd"
## Tester 0.5.9: a capsule tangent to the CHANGE machine at this seeded room
## spends every slide iteration on the floor and cannot retreat in any direction.
## Run with -- --mode=descent --nologo.

const TRAP := Vector3(551.1118, 0.00094, 519.455)
const DT := 1.0 / 60.0

func run() -> void:
	var game := await boot_game(2048823945)
	game.set_process(false)
	game.run.set_physics_process(false)
	game._figures.suspended = true
	game._photo_camera.set_process(false)
	var player: Player = game.player
	player.set_physics_process(false)
	player.set_process(false)
	player.dev_walk = true
	game.cm.stream_focus = TRAP
	game.cm.warm_up(Vector2i(45, 43))
	var installed := await await_until(func():
		return game.cm.chunks.has(Vector2i(45, 43)), 10000)
	expect(installed, "reported room was not installed")
	if not installed:
		await teardown_game(game)
		finish()
		return
	for heading in [Vector2(-0.694559, -0.719435), Vector2(0.942418, -0.334437),
			Vector2(-0.714838, 0.69929), Vector2(-0.968715, -0.248175)]:
		await _walk(player, heading, 45)
		var moved := Vector2(player.position.x - TRAP.x, player.position.z - TRAP.z).length()
		expect(moved > 0.15, "floor contact pinned retreat %s: moved %.6fm" % [heading, moved])
		expect(moved <= Player.WALK_SPEED * 45.0 * DT + 0.01,
			"floor recovery added movement beyond this frame's walking budget")
		expect(player._movement_overlap_details().is_empty(),
			"retreat entered a solid collider")
	# Press into the cabinet and the outer wall. Recovery must still sweep the
	# physical capsule, never teleport, disable collision or shrink the player.
	await _walk(player, Vector2(0.1, 1.0).normalized(), 90)
	expect(player.position.distance_to(TRAP) < 0.15,
		"recovery walked through the CHANGE machine")
	expect(Vector2(player.velocity.x, player.velocity.z).length() < 0.1,
		"blocked cabinet contact retained walking velocity/footsteps")
	expect(player._movement_overlap_details().is_empty(), "cabinet contains the standing capsule")
	await _walk(player, Vector2.RIGHT, 90)
	expect(player.position.x <= 551.85 - Player.BODY_RADIUS + 0.002,
		"recovery walked through the outer wall")
	expect(player._movement_overlap_details().is_empty(), "wall contains the standing capsule")
	await teardown_game(game)
	finish("reported casino floor contact: four retreats, cabinet and wall blocking")


func _walk(player: Player, heading: Vector2, frames: int) -> void:
	player.teleport(TRAP)
	player.rotation.y = atan2(-heading.x, -heading.y)
	await physics_frame
	for frame in frames:
		await physics_frame
		player._physics_process(DT)
