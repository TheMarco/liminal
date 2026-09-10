extends SceneTree
## Persistence audit for one-shot realm visits.
## Run: godot --headless --path . --script tools/audit_realm_visit_progress.gd

const TEST_PATH := "/tmp/liminal_audit_realm_visit_progress.cfg"
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var progress := DescentProgress.new(TEST_PATH)
	progress.clear_from_disk()
	progress.start_new(101)
	_expect(not progress.realm_visit_used(0), "new run has a used realm visit")
	progress.mark_realm_visit_used(0)
	progress.mark_realm_visit_used(0)
	progress.mark_realm_visit_used(3)
	_expect(progress.realm_visit_used(0) and progress.realm_visit_used(3), "visits did not mark")
	_expect(not progress.realm_visit_used(-1) and not progress.realm_visit_used(DescentRun.FLOOR_COUNT - 1), "invalid/final floor accepted")

	var loaded := DescentProgress.new(TEST_PATH)
	_expect(loaded.realm_visit_used(0) and loaded.realm_visit_used(3), "visits did not survive reload")
	loaded.allow_realm_visit_retry(0)
	loaded.allow_realm_visit_retry(0)
	loaded.allow_realm_visit_retry(-1)
	loaded.allow_realm_visit_retry(DescentRun.FLOOR_COUNT - 1)
	_expect(not loaded.realm_visit_used(0) and loaded.realm_visit_used(3), "retry cleared the wrong visits")
	var retried := DescentProgress.new(TEST_PATH)
	_expect(not retried.realm_visit_used(0) and retried.realm_visit_used(3), "retry did not persist selectively")
	loaded.reach_floor(101, 2)
	_expect(not loaded.realm_visit_used(0) and loaded.realm_visit_used(3), "same-seed reach changed visits")
	loaded.start_new(202)
	_expect(loaded.realm_visits.is_empty(), "new run inherited visits")
	loaded.mark_realm_visit_used(1)
	loaded.reach_floor(303, 1)
	_expect(loaded.realm_visits.is_empty(), "new-seed reach inherited visits")

	var legacy := ConfigFile.new()
	legacy.set_value("descent", "version", 5)
	legacy.set_value("descent", "run_seed", 404)
	legacy.set_value("descent", "deepest_floor", 2)
	legacy.set_value("descent", "emergency_flash_held", true)
	legacy.set_value("descent", "emergency_flash_photo_id", "flash:legacy")
	legacy.save(TEST_PATH)
	var legacy_loaded := DescentProgress.new(TEST_PATH)
	_expect(legacy_loaded.realm_visits.is_empty(), "legacy v5 invented visits")
	_expect(legacy_loaded.emergency_flash_held and legacy_loaded.emergency_flash_photo_id == "flash:legacy", "legacy flash was lost")

	var malformed := ConfigFile.new()
	malformed.set_value("descent", "version", 6)
	malformed.set_value("descent", "run_seed", 505)
	malformed.set_value("descent", "deepest_floor", 2)
	malformed.set_value("descent", "realm_visits", {"0": true, "01": true, "2": false, "3": "true", "bad": true, "10": true})
	malformed.save(TEST_PATH)
	var sanitized := DescentProgress.new(TEST_PATH)
	_expect(sanitized.realm_visit_used(0), "valid visit was sanitized away")
	_expect(sanitized.realm_visit_used(1), "canonicalized integer key was rejected")
	_expect(not sanitized.realm_visit_used(2) and not sanitized.realm_visit_used(3), "malformed values were accepted")
	_expect(not sanitized.realm_visit_used(DescentRun.FLOOR_COUNT - 1), "final floor visit was accepted")

	sanitized.clear_from_disk()
	_expect(sanitized.realm_visits.is_empty() and not sanitized.has_checkpoint(), "clear did not reset visits")
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("realm visit progress audit: PASS — one-shot visits migrate, sanitize and persist")
		quit()
	else:
		quit(1)
