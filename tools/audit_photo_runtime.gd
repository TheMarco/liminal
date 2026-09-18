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
	expect(game._reality_aftershock != null, "automatic perception effect missing without debug flag")
	expect(game._reality_aftershock.debug_controls == game.opts.reality_aftershock,
		"perception preview keys escaped their debug flag")
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	expect(director != null, "photo director was not constructed")
	expect(camera != null, "photo camera was not constructed")
	if director == null or camera == null:
		finish()
		return
	# A successful shot is described only after the opaque developed print has
	# closed. The caption must then retain a full readable hold instead of
	# spending its lifetime behind the camera layer.
	var before_caption: String = game._event_hint.text
	var evidence_caption := "PHOTOGRAPH 1 — THE CLOCK HAS TOO MANY HANDS"
	game._on_photo_documented("audit-caption", 1, 3,
		"THE CLOCK HAS TOO MANY HANDS")
	expect(game._pending_photo_message == evidence_caption,
		"successful photo did not queue its anomaly description")
	expect(game._event_hint.text == before_caption,
		"photo description appeared before the developed print closed")
	camera._review_left = 0.01
	camera._process(0.02)
	expect(game._pending_photo_message.is_empty() \
		and game._event_hint.text == evidence_caption,
		"closing the developed print did not reveal the anomaly description")
	if game._event_tween != null and game._event_tween.is_valid():
		game._event_tween.custom_step(3.0)
		expect(game._event_panel.modulate.a > 0.9,
			"successful photo description did not retain a readable hold")
		game._event_tween.kill()
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
	game.cm.stream_focus = Vector3(at.x * 12.0 + 6, 0.0, at.y * 12.0 + 6)
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
		# Leave the real, framed anomaly unphotographed until after the minimum.
		if cell != at:
			ids.append(str(director.plan[cell]["id"]))
	expect(ids.size() >= 3, "plan has no additional evidence beyond the minimum")
	if ids.size() < 3:
		await teardown_game(game)
		finish()
		return
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

	# Documentation must survive a room rebuild without erasing its visuals or
	# making its evidence eligible for a second reward.
	if spawned:
		var documented: PhotoAnomaly = director._live[at]
		var documented_id := documented.id
		expect(director.capturable().has(documented),
			"reaching the minimum retired an ordinary unphotographed anomaly")
		expect(await _frame_from_legal_stance(game, director, camera, documented),
			"the camera could not capture new ordinary evidence after the minimum")
		expect(director.mark_documented(documented_id),
			"new ordinary evidence was rejected after the minimum")
		documented.resolve(true)
		var total := director.documented_count()
		expect(total == 4 and game.descent_photo_requirement_met(),
			"a fourth discovery did not increase the count while keeping the lift unlocked")
		expect(game._descent_hud._photo.text == "PHOTOS 4 · MIN 3",
			"the evidence HUD clamped the count to the floor minimum")
		game._on_photo_documented(documented_id, total, 3, "EXTRA DISCOVERY")
		expect(game._pending_photo_message == "PHOTOGRAPH 4 — EXTRA DISCOVERY",
			"extra discovery caption did not show its actual photograph count")
		expect(not director.capturable().has(documented),
			"documented anomaly is still eligible for a reward")
		documented.free()
		director._on_chunk_built(game.cm.chunk_at(at))
		var rebuilt: PhotoAnomaly = director._live.get(at)
		expect(is_instance_valid(rebuilt) and rebuilt.id == documented_id,
			"documented anomaly disappeared when its room rebuilt")
		expect(not director.mark_documented(documented_id)
			and director.documented_count() == total,
			"rebuilt anomaly awarded repeat credit")
		# Directly exercise the former deletion path with writing geometry.
		var writing := PhotoAnomaly.new()
		writing.type = PhotoAnomaly.Type.WRITING
		var lettering := MeshInstance3D.new()
		lettering.mesh = QuadMesh.new()
		lettering.layers = PhotoAnomaly.PHOTO_LAYER
		writing.add_child(lettering)
		writing._resolvables.append(lettering)
		game.level_root.add_child(writing)
		writing.resolve()
		expect(not lettering.is_queued_for_deletion() and lettering.visible,
			"photographing erased camera-only writing")
		writing.free()

	# Ceiling furniture is the one anomaly whose resolution must be seen after
	# the developed print leaves, never completed behind the review card.
	var delayed := PhotoAnomaly.new()
	delayed.id = "audit:post-minimum-placement"
	delayed.type = PhotoAnomaly.Type.PLACEMENT
	delayed.world_seed = SEED
	delayed._placement_rest_y = 0.5
	delayed._placement_pivot = Node3D.new()
	delayed._placement_pivot.position.y = 2.5
	var ceiling_mesh := MeshInstance3D.new()
	ceiling_mesh.mesh = BoxMesh.new()
	delayed._placement_pivot.add_child(ceiling_mesh)
	delayed.add_child(delayed._placement_pivot)
	game.level_root.add_child(delayed)
	var fixture_cell := Vector2i(1 << 29, 1 << 29)
	director._live[fixture_cell] = delayed
	var before_extra := director.documented_count()
	expect(director.requirement_met() and director.capturable().has(delayed),
		"world-altering ordinary evidence was unavailable after the minimum")
	expect(director.mark_documented(delayed.id),
		"world-altering evidence could not be documented after the minimum")
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
	var lens_pose := delayed.get_node_or_null("DocumentedCeilingPose") as Node3D
	expect(lens_pose != null and is_equal_approx(lens_pose.position.y, lodged_y),
		"falling furniture lost its impossible pose in the viewfinder")
	if lens_pose != null:
		expect(lens_pose.get_child(0).layers == PhotoAnomaly.PHOTO_LAYER
			and ceiling_mesh.layers == PhotoAnomaly.EYE_ONLY_LAYER,
			"ceiling anomaly did not separate the persistent lens and physical poses")
	expect(not director.capturable().has(delayed)
		and not director.mark_documented(delayed.id)
		and director.documented_count() == before_extra + 1,
		"a repeat post-minimum photograph awarded additional evidence credit")
	director._live.erase(fixture_cell)
	delayed.queue_free()

	await teardown_game(game)
	finish("photo runtime: spawn, framing, minimum gate, extra evidence, delayed ceiling drop")


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
