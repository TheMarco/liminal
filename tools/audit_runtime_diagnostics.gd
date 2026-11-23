extends "res://tools/lib/audit_base.gd"

class SlowRotationWriter:
	extends "res://scripts/performance_log_writer.gd"
	var opened := 0
	var entered := Semaphore.new()
	var resume := Semaphore.new()

	func _open_next_log() -> Error:
		opened += 1
		if opened == 2:
			entered.post()
			OS.delay_msec(125)
			# Bound the test even if a regression moves rotation onto the main thread.
			var deadline := Time.get_ticks_msec() + 2000
			while not resume.try_wait() and Time.get_ticks_msec() < deadline:
				OS.delay_msec(1)
		return super._open_next_log()


func run() -> void:
	var logger := RuntimeDiagnostics.new()
	var path := "/tmp/liminal-diagnostics-audit-%d.jsonl" % OS.get_process_id()
	logger._path = path
	root.add_child(logger)
	logger.set_process(false)
	RuntimeDiagnostics.mark("audit_marker", {"value": 7})
	var records := await _wait_for(path, "audit_marker")
	if records.size() < 2:
		logger.free()
		finish("failed to flush initial diagnostics")
		return
	expect(records.size() == 2 and records[1].event == "audit_marker", "event not flushed while logger remained open")
	expect(records[0].details.has("driver") and records[0].snapshot.has("system_memory_bytes"), "session omitted renderer/memory context")
	expect(records[0].snapshot.has("frame_work") and records[0].snapshot.has("diagnostic_write_ms")
		and records[0].snapshot.has("diagnostic_disk_ms"),
		"session omitted CPU/render work or logger cost")
	expect(logger._last_write_usec >= 0 and logger._max_write_usec >= logger._last_write_usec,
		"logger duration bookkeeping is invalid")
	RuntimeDiagnostics.slow("audit_operation", Time.get_ticks_usec() - 30000)
	RuntimeDiagnostics.slow("audit_operation", Time.get_ticks_usec() - 30000)
	records = await _wait_for(path, "audit_operation")
	expect(records.size() == 3 and logger._slow_counts.audit_operation == 2, "slow-operation rate limit lost counts or logged repeatedly")
	logger._last_frame = Time.get_ticks_usec() - 150000
	logger._last_physics_frame = Engine.get_physics_frames() - 3
	logger._last_report = -RuntimeDiagnostics.REPORT_USEC
	logger._process(0.016)
	records = await _wait_for(path, "frame_hitch")
	expect(records[-1].event == "frame_hitch" and records[-1].details.worst_gap_ms >= 150.0, "hitch detection used clamped delta instead of elapsed time")
	expect(records[-1].details.worst_gap_physics_steps == 3 and records[-1].snapshot.frame_limit == Engine.max_fps
		and records[-1].snapshot.has("vsync_mode"), "hitch omitted its physics steps or active frame pacing")
	expect(records[-1].snapshot.has("pipelines"), "hitch omitted pipeline counters")
	expect(RuntimeDiagnostics._valid_memory_counter(18446744071655532544.0) == null
		and RuntimeDiagnostics._valid_memory_counter(-1.0) == null
		and RuntimeDiagnostics._valid_memory_counter(1048576.0) == 1048576.0,
		"invalid renderer memory counter was reported as a real allocation")
	await _check_movement_contacts(path)
	await _check_death_causes(path)
	logger.free()
	records = _read(path)
	expect(records[-1].event == "session_end", "shutdown did not drain the last record")
	expect(records.filter(func(record): return record.event == "descent_run_ended").size() == 2,
		"finished run logged duplicate deaths")
	await _check_rotation(path)
	for suffix in ["", ".1", ".2"]: DirAccess.remove_absolute(path + suffix)
	finish("flushed, bounded runtime diagnostics")


func _check_death_causes(path: String) -> void:
	for cause in [DescentRun.DeathCause.FIGURE, DescentRun.DeathCause.BLACKOUT_MOVEMENT]:
		var run := DescentRun.new()
		run.world_seed = 42
		run.blackout = cause == DescentRun.DeathCause.BLACKOUT_MOVEMENT
		var next_count := _read(path).size() + 1
		run.finish(false, cause)
		var records := await _wait_for(path, "descent_run_ended", next_count)
		var record: Dictionary = records[-1]
		expect(record.event == "descent_run_ended" and record.details.cause == DescentRun.DeathCause.keys()[cause],
			"death log did not distinguish figure contact from unseen blackout attack")
		expect(record.details.blackout == run.blackout and int(record.details.seed) == 42,
			"death log lost blackout/run context")
		run.finish(false, cause)
		run.free()


func _check_movement_contacts(path: String) -> void:
	var floor_body := _box("DiagnosticFloor", Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var wall := _box("DiagnosticWall", Vector3(0, 1.5, -2), Vector3(4, 3, 0.2))
	var player := Player.new()
	player.dev_walk = true
	root.add_child(player)
	await create_timer(3.4).timeout
	var blocked := []
	for record in await _wait_for(path, "movement_obstructed"):
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
	for record in await _wait_for(path, "movement_obstruction_ended"):
		if record.event == "movement_obstruction_ended":
			ended = record.details.reason == "movement_resumed"
	expect(ended, "resumed movement was not recorded")
	player.set_physics_process(false)
	var overlap := _box("DiagnosticEmbeddedProp", player.global_position + Vector3.UP,
		Vector3(0.4, 0.4, 0.4))
	await physics_frame
	player._record_movement_obstruction(Vector3.RIGHT, Vector3.ZERO, 2.1, false)
	var records := await _wait_for(path, "movement_obstructed")
	var latest: Dictionary = records[-1]
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
	if not FileAccess.file_exists(path): return result
	var contents := FileAccess.get_file_as_string(path)
	for line in contents.left(contents.rfind("\n") + 1).split("\n", false):
		var value: Variant = JSON.parse_string(line)
		if value is Dictionary: result.append(value)
	return result


func _wait_for(path: String, event: String, minimum := 1) -> Array:
	var deadline := Time.get_ticks_msec() + 3000
	var records := _read(path)
	while records.size() < minimum or records[-1].event != event:
		if Time.get_ticks_msec() >= deadline:
			fail("timed out waiting for %s to flush" % event)
			break
		await process_frame
		records = _read(path)
	return records


func _check_rotation(path: String) -> void:
	var writer := SlowRotationWriter.new()
	var logger := RuntimeDiagnostics.new()
	logger._path = path
	logger._writer = writer
	root.add_child(logger)
	logger.set_process(false)
	RuntimeDiagnostics.mark("rotation_padding", {"padding": "x".repeat(RuntimeDiagnostics.MAX_BYTES)})
	RuntimeDiagnostics.mark("after_rotation")
	var entered := await await_until(writer.entered.try_wait)
	expect(entered, "file did not rotate after crossing the byte cap")
	var largest_submit_usec := 0
	for index in RuntimeDiagnostics.LogWriter.MAX_PENDING + 8:
		RuntimeDiagnostics.mark("during_rotation", {"sequence": index})
		largest_submit_usec = maxi(largest_submit_usec, logger._last_write_usec)
	var frames := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 125:
		await process_frame
		frames += 1
	writer.resume.post()
	logger.free()
	var disk := writer.disk_stats()
	var records := _read(path)
	expect(frames >= 2 and largest_submit_usec < 50000 and disk.max >= 125.0,
		"slow disk rotation blocked gameplay or disappeared from disk timings")
	expect(disk.dropped_records == 8 and records.size() == RuntimeDiagnostics.LogWriter.MAX_PENDING + 2,
		"writer did not bound the queue or lost accepted records on exit")
	if records.size() == RuntimeDiagnostics.LogWriter.MAX_PENDING + 2:
		expect(records[0].event == "after_rotation" and records[-1].event == "session_end", "rotated log lost its boundaries")
		for index in RuntimeDiagnostics.LogWriter.MAX_PENDING:
			var row: Dictionary = records[index + 1]
			if row.event != "during_rotation" or int(row.details.sequence) != index:
				fail("disk writer reordered records at index %d" % index)
				break
	var previous := _read(path + ".1")
	var oldest := _read(path + ".2")
	expect(not previous.is_empty() and previous[-1].event == "rotation_padding"
		and not oldest.is_empty() and oldest[-1].event == "session_end"
		and not FileAccess.file_exists(path + ".3"), "size and startup rotation did not retain the last two files")
	print("ROTATION_AUDIT injected_ms=125 frames=%d largest_submit_ms=%.3f disk_max_ms=%.3f dropped=%d persisted=%d" % [
		frames, largest_submit_usec / 1000.0, disk.max, disk.dropped_records, records.size()])
