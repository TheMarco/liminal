extends SceneTree
## Production capture predicate and complete geometry bounds, without a profile.
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	for frame in 3: await physics_frame

func check_mark(subject: PhotoAnomaly, camera: Camera3D, extent: Vector2) -> void:
	var bounds := PhotoCamera.evidence_screen_bounds(subject, camera)
	check(bounds.has_area(), "subject has no evidence bounds")
	var mark := PhotoCamera.evidence_ellipse(bounds, extent)
	for point in subject.evidence_points():
		var pixel := camera.unproject_position(point)
		var relative := (pixel - mark.position) / (mark.size * 0.95)
		check(relative.length_squared() <= 1.0, "evidence mark cuts off subject corner")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var director := PhotoDirector.new()
	root.add_child(director)
	var capture := PhotoCamera.new()
	capture.player = player
	capture.director = director
	root.add_child(capture)
	capture.set_process(false)
	var writing := PhotoAnomaly.new()
	writing.id = "audit:writing"
	writing.type = PhotoAnomaly.Type.WRITING
	writing._facing = Vector3.BACK
	var label := Label3D.new()
	label.text = "THE DOORS MOVE WHEN IT'S DARK"
	label.font = PhotoAnomaly.WRITING_FONT
	label.font_size = 100
	label.pixel_size = 0.003
	label.layers = PhotoAnomaly.PHOTO_LAYER
	label.modulate = Color(0.8, 0.1, 0.06)
	writing.add_child(label)
	writing._writing_label = label
	writing._points = [Vector3.ZERO]
	root.add_child(writing)
	director._live[Vector2i.ZERO] = writing
	player.cam.fov = PhotoCamera.AIM_FOV
	player.cam.far = 80
	for distance in [8.0, 12.0, 20.0, 35.0]:
		player.cam.global_position = Vector3(0, 0, distance)
		player.cam.look_at(Vector3.ZERO)
		await settle()
		check(capture._captured_anomalies().has(writing), "visible writing not counted at %sm" % distance)
		if distance == 8.0:
			check(capture.viewfinder_feedback().text == "FOCUS", "fully framed writing did not show FOCUS")
		check_mark(writing, player.cam, Vector2(root.size))
	director._documented[writing.id] = true
	check(capture.viewfinder_feedback().text == "ALREADY DOCUMENTED", "documented writing feedback missing")
	director._documented.erase(writing.id)
	player.cam.global_position = Vector3(0, 0, -20)
	player.cam.look_at(Vector3.ZERO)
	await settle()
	check(not capture._captured_anomalies().has(writing), "back of writing counted")
	check(capture.viewfinder_feedback().text.is_empty(), "back of writing produced feedback")
	player.cam.global_position = Vector3(0, 0, 1)
	player.cam.look_at(Vector3.ZERO)
	await settle()
	check(capture.viewfinder_feedback().text == "FRAME THE WHOLE SUBJECT", "cropped visible phrase lacks framing guidance")
	player.cam.global_position = Vector3(0, 0, 20)
	player.cam.look_at(Vector3.ZERO)
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 20, 1)
	collider.shape = shape
	blocker.add_child(collider)
	blocker.position.z = 10
	root.add_child(blocker)
	await settle()
	check(not capture._captured_anomalies().has(writing), "writing through wall counted")
	check(capture.viewfinder_feedback().text.is_empty(), "fully occluded writing produced feedback")
	shape.size.x = 2.0
	blocker.position.x = 1.0
	await settle()
	check(capture.viewfinder_feedback().text == "VIEW PARTLY BLOCKED", "partially occluded phrase lacks obstruction guidance")
	blocker.free()
	player.cam.rotation.y += PI
	await settle()
	check(not capture._captured_anomalies().has(writing), "writing behind camera counted")
	check(capture.viewfinder_feedback().text.is_empty(), "writing behind camera produced feedback")
	player.cam.look_at(Vector3.ZERO)
	label.text = "STOP TAKING\nPICTURES"
	await settle()
	check_mark(writing, player.cam, Vector2(root.size))
	var bounty := RealmFlashBounty.new()
	bounty.id = "audit:flash"
	bounty.bounds = AABB(Vector3(-0.5, -1.0, -0.2), Vector3(1, 2, 0.4))
	root.add_child(bounty)
	director._live[Vector2i.ONE] = bounty
	await settle()
	check(capture._captured_anomalies().has(bounty), "visible flash prize still uses a hidden distance cutoff")
	director._live.erase(Vector2i.ONE)
	bounty.free()
	var large := PhotoAnomaly.new()
	large.type = PhotoAnomaly.Type.DUPLICATE
	for x in [-2.0, 2.0]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2, 4, 2)
		mesh.mesh = box
		mesh.position.x = x
		mesh.rotation.y = 0.7
		large.add_child(mesh)
	root.add_child(large)
	for extent in [Vector2i(640, 480), Vector2i(720, 1280), Vector2i(3840, 2160)]:
		root.size = extent
		await settle()
		check_mark(large, player.cam, Vector2(extent))
		check_mark(writing, player.cam, Vector2(extent))
	large.free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		player.cam.global_position = Vector3(0, 0, 12)
		player.cam.look_at(Vector3.ZERO)
		label.text = "THE DOORS MOVE WHEN IT'S DARK"
		var wall := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(30, 12)
		wall.mesh = quad
		wall.position.z = -0.1
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.65, 0.62, 0.48)
		wall.material_override = material
		root.add_child(wall)
		await settle()
		var original_mark := PhotoCamera.evidence_ellipse(PhotoCamera.evidence_screen_bounds(writing, player.cam), Vector2(root.size))
		capture._raised = true
		await capture._take_photo()
		check(capture._marks.marks.size() == 1, "rendered print did not receive evidence mark")
		if not capture._marks.marks.is_empty():
			var review := capture._review_rect()
			var ratio := maxf(review.size.x / root.size.x, review.size.y / root.size.y)
			var crop := (Vector2(root.size) * ratio - review.size) * 0.5
			check(capture._marks.marks[0].position.is_equal_approx(original_mark.position * ratio + review.position - crop), "print mark centre drifted")
			check(capture._marks.marks[0].size.is_equal_approx(original_mark.size * ratio), "print mark scale drifted")
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/liminal-round3-photo-proof.png")
		wall.free()
	writing.free()
	capture.free()
	director.free()
	player.free()
	for failure in failures: push_error(failure)
	print("photo framing audit: %d failures; distant writing, occlusion, facing, complete evidence bounds" % failures.size())
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)
