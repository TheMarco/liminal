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
		var target: Vector3 = points[0]
		# Stand between the anomaly and the cell centre, facing it: always
		# inside the room, never inside the wall the writing hangs on.
		var centre := Vector3((float(at.x) + 0.5) * WorldGen.CELL_SIZE, 0.0,
			(float(at.y) + 0.5) * WorldGen.CELL_SIZE)
		var away := centre - target
		away.y = 0.0
		if away.length() < 0.5:
			away = Vector3(1, 0, 0)
		var stand := target + away.normalized() * 2.5
		game.player.teleport(Vector3(stand.x, 0.15, stand.z))
		var eye: Vector3 = game.player.cam.global_position
		var flat := Vector2(target.x - eye.x, target.z - eye.z)
		game.player.rotation.y = atan2(-flat.x, -flat.y)
		game.player.cam.rotation = Vector3(
			atan2(target.y - eye.y, flat.length()),
			game.player.rotation.y, 0.0)
		await physics_frame
		await physics_frame
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

	await teardown_game(game)
	finish("photo runtime: spawn, framing, gate")
