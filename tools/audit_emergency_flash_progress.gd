extends SceneTree
## Persistence audit for the Descent emergency flash charge.
## Run: godot --headless --path . --log-file /tmp/flash-progress-audit-engine.log --script tools/audit_emergency_flash_progress.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var path := "/tmp/liminal_audit_emergency_flash_%d.cfg" % Time.get_ticks_usec()
	var progress := DescentProgress.new(path)
	progress.clear_from_disk()
	_expect(not progress.emergency_flash_held,
		"absent charge did not default to false")
	_expect(progress.emergency_flash_photo_id.is_empty(),
		"absent charge had a photo id")

	progress.start_new(21)
	progress.record_emergency_flash(true, "realm-flash:21:0")
	var reloaded := DescentProgress.new(path)
	_expect(reloaded.emergency_flash_held,
		"held emergency flash did not survive reload")
	_expect(reloaded.emergency_flash_photo_id == "realm-flash:21:0",
		"held emergency flash photo id did not survive reload")

	reloaded.reach_floor(21, 1)
	var next_floor := DescentProgress.new(path)
	_expect(next_floor.emergency_flash_held,
		"same-seed floor advance lost emergency flash")
	_expect(next_floor.emergency_flash_photo_id == "realm-flash:21:0",
		"same-seed floor advance lost emergency flash photo id")

	next_floor.record_emergency_flash(false, "ignored-after-spend")
	var spent := DescentProgress.new(path)
	_expect(not spent.emergency_flash_held,
		"spent emergency flash reloaded as held")
	_expect(spent.emergency_flash_photo_id.is_empty(),
		"spent emergency flash photo id was retained")

	spent.record_emergency_flash(true, "realm-flash:21:1")
	spent.start_new(22)
	var new_seed := DescentProgress.new(path)
	_expect(not new_seed.emergency_flash_held,
		"new seed retained emergency flash charge")
	_expect(new_seed.emergency_flash_photo_id.is_empty(),
		"new seed retained emergency flash photo id")

	var legacy := ConfigFile.new()
	legacy.set_value("descent", "version", 4)
	legacy.set_value("descent", "run_seed", 77)
	legacy.set_value("descent", "deepest_floor", 2)
	_expect(legacy.save(path) == OK, "could not write hand-built VERSION4 checkpoint")
	var legacy_loaded := DescentProgress.new(path)
	_expect(legacy_loaded.run_seed == 77 and legacy_loaded.deepest_floor == 2,
		"hand-built VERSION4 checkpoint did not load")
	_expect(not legacy_loaded.emergency_flash_held,
		"legacy VERSION4 checkpoint gained an emergency flash charge")
	_expect(legacy_loaded.emergency_flash_photo_id.is_empty(),
		"legacy VERSION4 checkpoint gained an emergency flash photo id")

	legacy_loaded.clear_from_disk()
	_expect(not FileAccess.file_exists(ProjectSettings.globalize_path(path)),
		"temporary checkpoint was not cleaned up")

	if failures.is_empty():
		print("PASS: emergency flash progress persistence audit")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		print("FAIL: emergency flash progress persistence audit (%d failures)" % failures.size())
		quit(1)
