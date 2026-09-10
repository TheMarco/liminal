extends SceneTree
## Tests the actual close-up framing path before physically walking in.
var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	Engine.max_fps = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var cam: Camera3D = game.player.cam
	var camera: PhotoCamera = game._photo_camera
	var id: String = visit.seal.photo_id
	var failed := false
	for distance in [5.8, 2.0, 1.0, 0.6]:
		cam.global_position = visit.source_centre - visit.source_forward * distance + Vector3.UP * 1.4
		cam.look_at(visit.source_centre + Vector3.UP * 1.35)
		cam.fov = PhotoCamera.AIM_FOV
		var captured := _has_id(camera._captured_anomalies(), id)
		print("REALM FRAME distance=%.1f captured=%s" % [distance, captured])
		failed = failed or not captured
		cam.rotate_y(PI)
		assert(not _has_id(camera._captured_anomalies(), id), "looking away must not open the realm")
	# A wall in front of the visible doorway must still veto the photograph.
	cam.global_position = visit.source_centre - visit.source_forward * 3.0 + Vector3.UP * 1.4
	cam.look_at(visit.source_centre + Vector3.UP * 1.35)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.global_position = visit.source_centre - visit.source_forward * 1.5 + Vector3.UP * 1.5
	blocker.rotation.y = visit.return_yaw
	await physics_frame
	await physics_frame
	assert(not _has_id(camera._captured_anomalies(), id), "cannot photograph through intervening wall")
	blocker.free()
	if failed:
		push_error("REALM ENTRY FAIL: visible close-up doorway did not register")
		game.free()
		quit(1)
		return
	# The same resolve callback as the real shutter, then ordinary player
	# movement. No teleport beyond the doorway and no direct enter() call.
	for anomaly in game._photo_director._live_doors.values():
		if anomaly.id == id:
			game._photo_director.mark_documented(id)
			anomaly.resolve()
			break
	game.player.teleport(visit.source_centre - visit.source_forward * 2.0 + Vector3.UP * 0.15)
	game.player.rotation.y = visit.return_yaw
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.dev_walk = true
	var deadline := Time.get_ticks_msec() + 8000
	while visit.phase in [RealmExcursion.Phase.WAITING, RealmExcursion.Phase.ENTERING] and Time.get_ticks_msec() < deadline:
		await process_frame
	game.player.dev_walk = false
	assert(visit.phase == RealmExcursion.Phase.VISITING, "ordinary walking must enter")
	await visit.collapse()
	print("REALM ENTRY PASS: close framing, look-away/occlusion rejection, physical walking")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()

func _has_id(nodes: Array[PhotoAnomaly], id: String) -> bool:
	for node in nodes:
		if node.id == id:
			return true
	return false
