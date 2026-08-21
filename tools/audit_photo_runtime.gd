extends "res://tools/lib/audit_base.gd"
## Runtime contract for the photography layer: anomalies spawn with their
## chunks, the camera's framing test finds a framed anomaly and refuses an
## unframed one, documenting flips the tape's proof gate, and the gate is
## wired into the objective ritual. Runs the production startup path.
## Run: godot --headless --path . --script tools/audit_photo_runtime.gd \
##        -- --mode=descent --nologo

const SEED := 7


func run() -> void:
	var game := await boot_game(SEED)
	expect(game.descent, "Descent CLI mode was not selected")
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	expect(director != null, "photo director was not constructed")
	expect(camera != null, "photo camera was not constructed")
	if director == null or camera == null:
		finish()
		return
	expect(director.plan.size() >= PhotoDirector.REQUIRED,
		"floor 1 plan holds fewer anomalies than the requirement")
	expect(not game.descent_photo_requirement_met(),
		"proof gate already open with zero photographs")

	# Stream a planned cell in and stand the player in front of its anomaly.
	var at: Vector2i = Vector2i(1 << 30, 1 << 30)
	for cell in director.plan:
		if bool(director.plan[cell]["required"]):
			at = cell
			break
	expect(at.x != 1 << 30, "plan has no required cell")
	game.cm.warm_up(at)
	var spawned := await await_until(func() -> bool:
		return director._live.has(at) \
			and is_instance_valid(director._live[at]) \
			and director._live[at].is_inside_tree(), 8000)
	expect(spawned, "anomaly did not spawn with its chunk")
	if spawned:
		var anomaly: PhotoAnomaly = director._live[at]
		var points := anomaly.photo_points()
		expect(not points.is_empty(), "anomaly exposes no photo points")
		var framed: bool = await _frame_from_legal_stance(
			game, director, camera, anomaly)
		expect(framed, "no legal stance framed the spawned anomaly")
		var captured := camera._captured_anomalies()
		expect(captured.has(anomaly),
			"framed anomaly was not detected by the capture test")
		# Turn the camera away: the same anomaly must stop qualifying.
		game.player.cam.rotation.y += PI
		await physics_frame
		expect(not camera._captured_anomalies().has(anomaly),
			"anomaly behind the camera still counted as framed")
		game.player.cam.rotation.y -= PI

	# Documenting to the requirement opens the gate; ids never double-count.
	var ids := []
	for cell in director.plan:
		ids.append(str(director.plan[cell]["id"]))
	expect(director.mark_documented(str(ids[0])),
		"first documentation was rejected")
	expect(not director.mark_documented(str(ids[0])),
		"the same anomaly documented twice")
	director.mark_documented(str(ids[1]))
	expect(not game.descent_photo_requirement_met(),
		"gate opened one photograph early")
	director.mark_documented(str(ids[2]))
	expect(game.descent_photo_requirement_met(),
		"gate closed with the requirement met")
	expect(director.documented_count() == 3, "documented count drifted")

	# Ceiling furniture is the one anomaly whose resolution must be seen after
	# the developed print leaves, never completed behind the review card.
	var delayed := PhotoAnomaly.new()
	delayed.type = PhotoAnomaly.Type.PLACEMENT
	delayed.world_seed = SEED
	delayed._placement_rest_y = 0.5
	delayed._placement_pivot = Node3D.new()
	delayed._placement_pivot.position.y = 2.5
	delayed.add_child(delayed._placement_pivot)
	game.level_root.add_child(delayed)
	var lodged_y := delayed._placement_pivot.position.y
	expect(delayed.resolves_after_review(),
		"ceiling furniture did not opt into post-review resolution")
	camera._review_resolves.append(delayed)
	expect(is_equal_approx(delayed._placement_pivot.position.y, lodged_y),
		"ceiling furniture moved while the developed print was still up")
	camera._release_review_resolutions()
	expect(delayed._placement_pivot == null \
		and camera._review_resolves.is_empty(),
		"closing the photo review did not release the ceiling furniture")
	delayed.queue_free()

	await teardown_game(game)
	finish("photo runtime: spawn, framing, gate, delayed ceiling drop")


func _frame_from_legal_stance(game: Node, director: PhotoDirector,
		camera: PhotoCamera, anomaly: PhotoAnomaly) -> bool:
	var points := anomaly.photo_points()
	if points.is_empty():
		return false
	var target: Vector3 = points[0]
	if points.size() > 1:
		target = (points[0] + points[1]) * 0.5
	for dist in [1.8, 3.5, 6.0]:
		for ang in 8:
			var direction := Vector3(cos(TAU * float(ang) / 8.0), 0.0,
				sin(TAU * float(ang) / 8.0))
			var stand := target + direction * float(dist)
			var stand_cell := Vector2i(
				floori(stand.x / WorldGen.CELL_SIZE),
				floori(stand.z / WorldGen.CELL_SIZE))
			var stand_chunk: Chunk = game.cm.chunk_at(stand_cell)
			if stand_chunk == null:
				game.cm.warm_up(stand_cell)
				stand_chunk = game.cm.chunk_at(stand_cell)
			if stand_chunk == null:
				continue
			var floor_h := Chunk.cell_floor_h(director.world_seed,
				stand_cell, director.theme)
			var local_stand: Vector3 = stand - stand_chunk.global_position
			local_stand.y = floor_h
			if not stand_chunk._floor_spot_clear(local_stand, 0.38, 1.8):
				continue
			game.player.teleport(Vector3(stand.x, floor_h + 0.15, stand.z))
			var eye: Vector3 = game.player.cam.global_position
			var flat := Vector2(target.x - eye.x, target.z - eye.z)
			game.player.rotation.y = atan2(-flat.x, -flat.y)
			game.player.cam.rotation = Vector3(
				atan2(target.y - eye.y, flat.length()),
				game.player.rotation.y, 0.0)
			await physics_frame
			await physics_frame
			if camera._captured_anomalies().has(anomaly):
				return true
	return false
