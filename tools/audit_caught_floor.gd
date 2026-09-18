extends "res://tools/lib/audit_base.gd"
## Standalone geometry/comfort fixtures; no campaign, settings or save writes.

const SEQUENCE := preload("res://scripts/caught_sequence.gd")
var world: Node3D
var checks := 0


func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = at
	body.add_child(shape)
	world.add_child(body)


func _fixture(floor_y: float, obstacle: String, variant: int, direction: Vector3,
		water := "") -> Array:
	world = Node3D.new()
	root.add_child(world)
	_box(Vector3(0, floor_y - 0.1, 0), Vector3(24, 0.2, 24))
	if obstacle == "box":
		_box(Vector3(0, floor_y + 0.35, 0.38), Vector3(0.8, 0.7, 0.26))
	elif obstacle == "wall":
		_box(Vector3(0, floor_y + 1.5, 0.50), Vector3(3, 3, 0.2))
	if water != "":
		var surface := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(2, 2)
		surface.mesh = mesh
		surface.position = Vector3(0, floor_y + 0.7, -0.9 if water == "edge" else 0.0)
		surface.add_to_group(Player.WaterInteraction.SURFACE_GROUP)
		world.add_child(surface)
	var player := Player.new()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.teleport(Vector3(3 if water == "dry" else 0, floor_y + 0.01, 0))
	if water != "":
		player.water_y = floor_y + 0.7
		player._water_surface_here()
	var figure := ShadowFigure.new()
	figure.player = player
	figure.variant = variant
	figure.position = player.position + direction
	world.add_child(figure)
	figure.set_physics_process(false)
	await physics_frame
	await process_frame
	return [player, figure]


func _basis_ok(basis: Basis) -> bool:
	return basis.is_finite() and basis.orthonormalized().is_equal_approx(basis) \
		and is_equal_approx(basis.determinant(), 1.0)


func _exercise(p: Player, f: ShadowFigure, label: String, pitch: float,
		motion: float, floor_y: float, blocked: bool, wet: bool, original_physics := false) -> void:
	p.head_bob_strength = motion
	p.cam.fov = 63.0
	p.cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, 0, 0)),
		p.global_position + Vector3.UP * Player.CAM_H)
	var pose := p.cam.global_transform
	var figure_pose := f.global_transform
	var body_pose := p.global_transform
	var gloom_visible := f._gloom.visible
	# No frames elapse between enabling and begin(): test that interruption
	# restores the original flag, without running this artificial enemy's AI.
	f.set_physics_process(original_physics)
	var seq := SEQUENCE.new()
	world.add_child(seq)
	seq.begin(p, f)
	seq.set_process(false)
	expect(not f.is_physics_processing(), label + " did not freeze actor")
	expect(not f._gloom.visible, label + " retained close fog volume")
	var previous_basis := pose.basis
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SEQUENCE.CAMERA_RADIUS
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for i in range(126):
		var at := float(i) * 0.02
		seq._sample(at)
		var now := p.cam.global_transform
		expect(_basis_ok(now.basis), label + " non-finite/non-orthonormal camera")
		expect(previous_basis.get_rotation_quaternion().angle_to(now.basis.get_rotation_quaternion()) < 0.25,
			label + " abrupt camera rotation")
		previous_basis = now.basis
		if motion == 0.0:
			expect(now.is_equal_approx(pose), label + " zero motion moved camera")
		expect(is_equal_approx(p.cam.fov, 63.0), label + " changed FOV")
		if at < SEQUENCE.FADE_START:
			expect(is_zero_approx(seq._curtain.color.a), label + " faded before reveal")
		query.transform = Transform3D(Basis.IDENTITY, now.origin)
		expect(p.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(),
			label + " camera penetrated a collider")
		if wet:
			expect(now.origin.y >= floor_y + 0.7 + SEQUENCE.FLOOR_EYE_HEIGHT - 0.001,
				label + " camera crossed water surface")
	seq._sample(SEQUENCE.LOOM_AT)
	expect(is_equal_approx(figure_pose.basis.y.angle_to(f.global_basis.y), SEQUENCE.LEAN),
		label + " ghost did not achieve its full forward lean")
	f._quad._process(0.0)
	expect(f._quad.global_basis.z.normalized().y < -0.30,
		label + " billboard update cancelled the visible downward tilt")
	expect(p.global_transform.is_equal_approx(body_pose), label + " moved player body")
	expect(p.cam.global_position.is_equal_approx(pose.origin.lerp(seq._floor_eye, motion)),
		label + " head-motion strength did not scale the fall")
	if motion == 1.0:
		var focus := f.global_transform * Vector3(0, f._eye_h, 0)
		expect((-p.cam.global_basis.z).dot((focus - p.cam.global_position).normalized()) > 0.95,
			label + " camera missed the actual leaned head")
		if not blocked and not wet:
			expect(absf(p.cam.global_position.y - floor_y - SEQUENCE.FLOOR_EYE_HEIGHT) < 0.002,
				label + " missed the floor eye height")
			expect(pose.origin.y - p.cam.global_position.y > 0.9, label + " did not fall")
		elif blocked:
			expect(p.cam.global_position.y > floor_y + SEQUENCE.FLOOR_EYE_HEIGHT + 0.1,
				label + " obstacle did not actually block this fixture")
	var start_side := figure_pose.origin - body_pose.origin
	var end_side := f.global_position - body_pose.origin
	start_side.y = 0.0
	end_side.y = 0.0
	expect(start_side.dot(end_side) > 0.0 and end_side.length() >= 0.79,
		label + " teleported ghost across/inside player")
	seq.free()
	expect(p.cam.global_transform.is_equal_approx(pose) and is_equal_approx(p.cam.fov, 63.0),
		label + " did not restore camera")
	expect(f.global_transform.is_equal_approx(figure_pose) and f.is_physics_processing() == original_physics,
		label + " did not restore ghost transform/physics")
	expect(f._gloom.visible == gloom_visible, label + " did not restore ghost fog")
	f.set_physics_process(false)
	checks += 1
	world.free()
	await process_frame


func run() -> void:
	for spec in [["front", Vector3.FORWARD, 0.0], ["rear", Vector3.BACK, 0.0],
			["side", Vector3.RIGHT, 0.0], ["up", Vector3.FORWARD, deg_to_rad(80)],
			["down", Vector3.FORWARD, deg_to_rad(-80)]]:
		for variant in range(7):
			var actors := await _fixture(0, "", variant, spec[1])
			await _exercise(actors[0], actors[1], "%s-%d" % [spec[0], variant], spec[2], 1, 0, false, false)
	for motion in [0.0, 0.5]:
		var actors := await _fixture(0, "", 0, Vector3.FORWARD)
		await _exercise(actors[0], actors[1], "motion-%s" % motion, 0, motion, 0, false, false, true)
	for obstacle in ["", "box", "wall"]:
		var actors := await _fixture(2, obstacle, 0, Vector3.FORWARD)
		await _exercise(actors[0], actors[1], "elevated-" + obstacle, 0, 1, 2, obstacle != "", false)
	for water in ["wet", "dry", "edge"]:
		var actors := await _fixture(0, "", 0, Vector3.FORWARD, water)
		await _exercise(actors[0], actors[1], "water-" + water, 0, 1, 0, false, water != "dry")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("%d floor-fall fixtures: seven variants, front/rear/side, pitch, comfort, walls/props, water and restoration" % checks)
