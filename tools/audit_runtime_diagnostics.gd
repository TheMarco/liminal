extends "res://tools/lib/audit_base.gd"

func run() -> void:
	var logger := RuntimeDiagnostics.new()
	var path := "/tmp/liminal-diagnostics-audit-%d.jsonl" % OS.get_process_id()
	logger._path = path
	root.add_child(logger)
	logger.set_process(false)
	RuntimeDiagnostics.mark("audit_marker", {"value": 7})
	var records := _read(path)
	expect(records.size() == 2 and records[1].event == "audit_marker", "event not flushed while logger remained open")
	expect(records[0].details.has("driver") and records[0].snapshot.has("system_memory_bytes"), "session omitted renderer/memory context")
	expect(records[0].snapshot.has("frame_work") and records[0].snapshot.has("diagnostic_write_ms"),
		"session omitted CPU/render work or logger cost")
	expect(logger._last_write_usec >= 0 and logger._max_write_usec >= logger._last_write_usec,
		"logger duration bookkeeping is invalid")
	RuntimeDiagnostics.slow("audit_operation", Time.get_ticks_usec() - 30000)
	RuntimeDiagnostics.slow("audit_operation", Time.get_ticks_usec() - 30000)
	records = _read(path)
	expect(records.size() == 3 and logger._slow_counts.audit_operation == 2, "slow-operation rate limit lost counts or logged repeatedly")
	logger._last_frame = Time.get_ticks_usec() - 150000
	logger._last_report = -RuntimeDiagnostics.REPORT_USEC
	logger._process(0.016)
	records = _read(path)
	expect(records[-1].event == "frame_hitch" and records[-1].details.worst_gap_ms >= 150.0, "hitch detection used clamped delta instead of elapsed time")
	expect(records[-1].snapshot.has("pipelines"), "hitch omitted pipeline counters")
	expect(RuntimeDiagnostics._valid_memory_counter(18446744071655532544.0) == null
		and RuntimeDiagnostics._valid_memory_counter(-1.0) == null
		and RuntimeDiagnostics._valid_memory_counter(1048576.0) == 1048576.0,
		"invalid renderer memory counter was reported as a real allocation")
	await _check_movement_contacts(path)
	_check_death_causes(path)
	# Cross the byte cap without a long-running or high-frequency test.
	logger._file.store_string(" ".repeat(RuntimeDiagnostics.MAX_BYTES))
	RuntimeDiagnostics.mark("after_rotation")
	expect(FileAccess.file_exists(path + ".1") and _read(path)[0].event == "after_rotation", "log cap failed to rotate")
	logger._open_log()
	logger._open_log()
	expect(FileAccess.file_exists(path + ".2") and not FileAccess.file_exists(path + ".3"), "rotation exceeded two retained logs")
	logger.free()
	for suffix in ["", ".1", ".2"]: DirAccess.remove_absolute(path + suffix)
	finish("flushed, bounded runtime diagnostics")


func _check_death_causes(path: String) -> void:
	for cause in [DescentRun.DeathCause.FIGURE, DescentRun.DeathCause.BLACKOUT_MOVEMENT]:
		var run := DescentRun.new()
		run.world_seed = 42
		run.blackout = cause == DescentRun.DeathCause.BLACKOUT_MOVEMENT
		run.finish(false, cause)
		var record: Dictionary = _read(path)[-1]
		expect(record.event == "descent_run_ended" and record.details.cause == DescentRun.DeathCause.keys()[cause],
			"death log did not distinguish figure contact from unseen blackout attack")
		expect(record.details.blackout == run.blackout and int(record.details.seed) == 42,
			"death log lost blackout/run context")
		var count := _read(path).size()
		run.finish(false, cause)
		expect(_read(path).size() == count, "finished run logged duplicate deaths")
		run.free()


func _check_movement_contacts(path: String) -> void:
	var floor_body := _box("DiagnosticFloor", Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var wall := _box("DiagnosticWall", Vector3(0, 1.5, -2), Vector3(4, 3, 0.2))
	var player := Player.new()
	player.dev_walk = true
	root.add_child(player)
	await create_timer(3.4).timeout
	var blocked := []
	for record in _read(path):
		if record.event == "movement_obstructed": blocked.append(record)
	expect(blocked.size() == 1, "sustained obstruction was missing or logged every frame")
	if not blocked.is_empty():
		var found_wall := false
		for contact in blocked[0].details.contacts:
			if "DiagnosticWall" in contact.body:
				found_wall = contact.has("shape_transform") and contact.has("box_size")
		expect(found_wall, "movement log did not identify the real blocking shape")
	var stopped_at := player.global_position.z
	wall.queue_free()
	await create_timer(0.3).timeout
	expect(player.global_position.z < stopped_at - 0.2, "diagnostics altered movement after barrier removal")
	var ended := false
	for record in _read(path):
		if record.event == "movement_obstruction_ended":
			ended = record.details.reason == "movement_resumed"
	expect(ended, "resumed movement was not recorded")
	player.set_physics_process(false)
	var overlap := _box("DiagnosticEmbeddedProp", player.global_position + Vector3.UP,
		Vector3(0.4, 0.4, 0.4))
	await physics_frame
	player._record_movement_obstruction(Vector3.RIGHT, Vector3.ZERO, 2.1, false)
	var latest: Dictionary = _read(path)[-1]
	var found_overlap := false
	for entry in latest.details.overlaps:
		if "DiagnosticEmbeddedProp" in entry.body:
			found_overlap = entry.has("shape_transform") and entry.has("box_size")
	expect(found_overlap, "obstruction log missed a shape overlapping the standing capsule")
	expect(latest.details.has("photo_aim") and latest.details.has("charging"),
		"obstruction log omitted interaction state")
	overlap.free()
	await teardown_game(player)
	floor_body.free()


func _box(label: String, at: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body


func _read(path: String) -> Array:
	var result: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var value: Variant = JSON.parse_string(line)
		if value is Dictionary: result.append(value)
	return result
