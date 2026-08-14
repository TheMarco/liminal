extends "res://tools/lib/audit_base.gd"
## Regression test for the real runtime level-swap sequence. The outgoing floor
## must leave the physics world before the destination arrival resolver runs, or
## overlapping collision trees can reject every school landing.
## Run: godot --headless --path . --script tools/audit_level_switches.gd -- --nologo

const REGRESSION_SEED := 1760336105
const SCHOOL_CELL := Vector2i(-1, 0)
const SAVED_POSITION := Vector3(-6.0, 0.0, 6.0)


func run() -> void:
	var game := await boot_game(REGRESSION_SEED)

	# Theme 10 intentionally lives on 0 rather than becoming an awkward tenth
	# item in the 1-N arithmetic used by the original floors.
	var zero := InputEventKey.new()
	zero.pressed = true
	zero.physical_keycode = KEY_0
	game._unhandled_input(zero)
	await await_until(func(): return not game._switching)
	expect(game.active_level == 10,
		"0 key did not enter the Monolith")
	var filter_before: bool = game._post_process.is_enabled()
	var video := InputEventKey.new()
	video.pressed = true
	video.physical_keycode = KEY_V
	game._unhandled_input(video)
	expect(game._post_process.is_enabled() != filter_before,
		"V did not toggle the video filter in Wander")
	game._unhandled_input(video)

	game._jump_to(6, SAVED_POSITION, false)
	await await_until(func(): return not game._switching)

	if game._switching or game.active_level != 6:
		fail("school transition did not complete")
	elif game.level_root == null or not game.level_root.is_inside_tree():
		fail("school level is not active in the scene tree")
	else:
		await physics_frame
		var landed: Vector3 = game.player.global_position
		var actual_cell := Vector2i(floori(landed.x / 12.0), floori(landed.z / 12.0))
		var world: World3D = game.get_world_3d()
		var exclude: Array[RID] = [game.player.get_rid()]
		if actual_cell != SCHOOL_CELL:
			fail("landing left regression cell: %s" % actual_cell)
		if not ArrivalSafety.is_clear(world, landed, exclude):
			fail("landed capsule overlaps generated geometry")
		if not ArrivalSafety.has_floor(world, landed, exclude):
			fail("landing has no supporting floor")
		if ArrivalSafety.escape_count(world, landed, exclude) < 2:
			fail("landing has fewer than two escape directions")
		if game._music_track_for(game.active_level) \
				!= game.MUSIC_TRACKS[game.active_level]:
			fail("Wander soundtrack was changed by Descent escalation")

	# The shared Q flow must pause Wander without labelling it as a Descent run,
	# then restore ordinary input state when cancelled. Haunt timers are NOT part
	# of that restore: Wander is the peaceful mode and keeps its figures suspended
	# throughout, so cancelling the prompt must leave them suspended. This
	# assertion used to demand the opposite, from when figures still ran in
	# Wander.
	game._show_return_prompt()
	expect(is_instance_valid(game._return_prompt) and not game._return_prompt.descent,
		"Wander return prompt received Descent-specific context")
	expect(game._figures.suspended,
		"Wander return prompt did not suspend haunt timers")
	game._cancel_return_to_title()
	expect(game._figures.suspended,
		"cancelling the Wander return prompt released haunt timers")
	expect(not game._whispers.suspended,
		"cancelling the Wander return prompt left ambience muted")

	print("level-switch audit: seed=%d target=school cell=%s player=%s" % [
		REGRESSION_SEED, SCHOOL_CELL, game.player.global_position])
	if not failures.is_empty():
		_print_candidate_colliders(game)
	await teardown_game(game)
	finish("outgoing collision retired before the school arrival probe")


## Only on failure: which generated bodies the arrival probe actually hit, which
## is the difference between "the resolver is wrong" and "the outgoing floor was
## still in the physics world".
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
