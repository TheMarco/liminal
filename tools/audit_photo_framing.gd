extends SceneTree
## Production capture predicate and complete geometry bounds, without a profile.
var failures: Array[String] = []
signal archive_started
signal release_archive
var shutter_events: Array[String] = []
var archived_image: Image

func hold_archive(image: Image, _metadata: Dictionary) -> void:
	archived_image = image
	shutter_events.append("archiving")
	archive_started.emit()
	await release_archive
	shutter_events.append("archived")

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	for frame in 3: await physics_frame

func check_review_pixels(capture: PhotoCamera, print_image: Image, hdr: bool) -> void:
	# Sample the live review and the archived image through identical UI draws.
	var viewport := SubViewport.new()
	var half := Vector2i(128, 72)
	viewport.size = Vector2i(half.x * 2, half.y)
	viewport.use_hdr_2d = hdr
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	for texture: Texture2D in [capture._photo.texture, ImageTexture.create_from_image(print_image)]:
		var rect := TextureRect.new()
		rect.position.x = viewport.get_child_count() * half.x
		rect.size = half
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.modulate = capture._photo.modulate
		rect.texture = texture
		viewport.add_child(rect)
	await RenderingServer.frame_post_draw
	var pair := viewport.get_texture().get_image()
	var left := pair.get_region(Rect2i(Vector2i.ZERO, half))
	var right := pair.get_region(Rect2i(Vector2i(half.x, 0), half))
	check(left.get_data() == right.get_data(), "review colours differ from the archived print (HDR %s)" % hdr)
	viewport.free()

func check_mark(subject: PhotoAnomaly, camera: Camera3D, extent: Vector2) -> void:
	var bounds := PhotoCamera.evidence_screen_bounds(subject, camera)
	check(bounds.has_area(), "subject has no evidence bounds")
	var mark := PhotoCamera.evidence_ellipse(bounds, extent)
	for point in subject.evidence_points():
		var pixel := camera.unproject_position(point)
		var relative := (pixel - mark.position) / (mark.size * 0.95)
		check(relative.length_squared() <= 1.0, "evidence mark cuts off subject corner")

func check_print_lighting(capture: PhotoCamera, player: Player) -> void:
	var world := player.get_world_3d()
	var previous := world.environment
	var env := Environment.new()
	env.sdfgi_cascades = 4
	env.sdfgi_enabled = true
	world.environment = env
	player.level_theme = 0
	capture._request_snapshot_draw()
	var print_env := capture._snap_cam.environment
	check(print_env != null and print_env != env and print_env.sdfgi_enabled
		and print_env.sdfgi_cascades == PhotoCamera.CASINO_PRINT_CASCADES, "Casino print lighting missing")
	check(env.sdfgi_cascades == 4 and player.cam.environment == null, "shutter changed player lighting")
	player.level_theme = 7
	capture._request_snapshot_draw()
	check(capture._snap_cam.environment == null, "Casino lighting carried into another floor")
	player.level_theme = 0
	env.sdfgi_cascades = 2
	capture._request_snapshot_draw()
	check(capture._snap_cam.environment == null, "shutter replaced the low-cost GI preset")
	var camera_env := Environment.new()
	camera_env.sdfgi_enabled = false
	player.cam.environment = camera_env
	capture._request_snapshot_draw()
	check(capture._snap_cam.environment == camera_env, "camera's own lighting override was lost")
	player.cam.environment = null
	world.environment = previous

func check_floor_growth(capture: PhotoCamera, director: PhotoDirector, player: Player) -> void:
	var at := Vector3(6, 0, 6)
	var chunk := Chunk.new(WorldGen.level_seed(9137, 6), Vector2i.ZERO, 6,
		{"descent": true, "bleed_theme": 8}, true)
	chunk._place_bleed_prop(at, PI / 4.0)
	root.add_child(chunk)
	director._register_bleed_props(chunk)
	await settle()
	var anomaly := director._live_bleed.get(chunk.cell) as PhotoAnomaly
	check(anomaly != null, "School floor growth was not registered as evidence")
	if anomaly != null:
		var from := Transform3D(Basis.IDENTITY, at + Vector3(-1.5, 0.01, 0))
		check(player.test_move(from, Vector3.RIGHT * 3.0), "player could walk through floor growth")
		from.origin.z += 1.3
		check(not player.test_move(from, Vector3.RIGHT * 3.0), "growth blocks clear floor beside it")
		var focus := anomaly.photo_points()[0]
		check(focus.y > at.y and focus.y < at.y + 0.35, "camera aims above the growth")
		player.cam.global_position = at + Vector3(0, 1.6, 2.8)
		player.cam.look_at(at + Vector3.UP * 0.17)
		check(capture._captured_anomalies().has(anomaly), "visible growth cannot be photographed")
		chunk._box(at + Vector3(0, 1, 1.4), Vector3(3, 2, 0.15), Mats.sch_trim())
		await settle()
		check(not capture._captured_anomalies().has(anomaly), "growth was photographed through a wall")
	director._live_bleed.erase(chunk.cell)
	chunk.free()


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
	await check_floor_growth(capture, director, player)
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
		check_print_lighting(capture, player)
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
		capture.archive_photograph = hold_archive
		capture.photograph_taken.connect(func(_image: Image, _metadata: Dictionary): shutter_events.append("taken"))
		capture.photo_documented.connect(func(_id: String, _count: int, _required: int, _caption: String): shutter_events.append("documented"))
		capture._take_photo()
		await capture._review_back.visibility_changed
		check(shutter_events.is_empty() and capture._photo.visible and capture._capturing,
			"review waited for readback or disk")
		check(root.disable_3d and not capture._snap_viewport.disable_3d, "opaque print still renders the game world")
		check(capture._photo.texture == capture._snap_viewport.get_texture(), "review uploaded a second photo texture")
		check(capture._marks.marks.size() == 1, "rendered print did not receive evidence mark")
		if not capture._marks.marks.is_empty():
			var review := capture._review_rect()
			var ratio := maxf(review.size.x / root.size.x, review.size.y / root.size.y)
			var crop := (Vector2(root.size) * ratio - review.size) * 0.5
			check(capture._marks.marks[0].position.is_equal_approx(original_mark.position * ratio + review.position - crop), "print mark centre drifted")
			check(capture._marks.marks[0].size.is_equal_approx(original_mark.size * ratio), "print mark scale drifted")
		await archive_started
		await process_frame
		capture._process(PhotoCamera.REVIEW_SECONDS + 0.1)
		check(capture.is_reviewing() and capture._capturing and not director._documented.has(writing.id),
			"slow album write uncovered the world or awarded evidence before publication")
		capture.visible = false
		check(not root.disable_3d, "hiding the photo overlay left the world hidden")
		capture.visible = true
		check(root.disable_3d, "showing the pending review drew the world again")
		await check_review_pixels(capture, archived_image, root.use_hdr_2d)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/liminal-round3-photo-proof.png")
		# The GPU buffer can have an extra alpha channel. Check the exact print
		# bytes, orientation and colour depth against Godot's reference read.
		var saved_hdr := root.use_hdr_2d
		for hdr in [false, true]:
			root.use_hdr_2d = hdr
			var exposure := await capture._draw_snapshot()
			var print_image := await capture._download_snapshot(exposure)
			var reference := capture._snap_viewport.get_texture().get_image()
			check(print_image != null and print_image.get_format() == reference.get_format()
				and print_image.get_size() == reference.get_size() and print_image.get_data() == reference.get_data(),
				"shutter readback changed the print (HDR %s)" % hdr)
			if print_image != null:
				await check_review_pixels(capture, print_image, hdr)
		root.use_hdr_2d = saved_hdr
		await process_frame
		var photographed_id := writing.id
		writing.free()
		release_archive.emit()
		check(shutter_events == ["archiving", "archived", "taken", "documented"],
			"photo publication order changed: %s" % str(shutter_events))
		check(not capture._capturing and director._documented.has(photographed_id),
			"unloading the photographed room lost the archived evidence")
		capture._process(0.016)
		check(not capture.is_reviewing() and not root.disable_3d, "finished album restarted the review timer or left the world hidden")
		capture._show_print(capture._photo.texture, [], Vector2(root.size))
		capture.finish_for_transition()
		check(not root.disable_3d, "transition left the world hidden")
		root.disable_3d = true
		capture._show_print(capture._photo.texture, [], Vector2(root.size))
		capture.finish_for_transition()
		check(root.disable_3d, "review enabled another owner's disabled viewport")
		root.disable_3d = false
		capture._show_print(capture._photo.texture, [], Vector2(root.size))
		wall.free()
	if is_instance_valid(writing):
		writing.free()
	capture.free()
	check(not root.disable_3d, "removing a visible review stranded the viewport")
	director.free()
	player.free()
	for failure in failures: push_error(failure)
	print("photo framing audit: %d failures; distant writing, occlusion, facing, complete evidence bounds" % failures.size())
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)
