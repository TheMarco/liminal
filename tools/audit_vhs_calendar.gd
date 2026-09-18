extends SceneTree
## The recovered-tape calendar advances through the canonical 1986 Descent
## while remaining deterministic in test and Wander modes.

var failures: Array[String] = []


func _init() -> void:
	_check(VhsOsd.Frame.recording_date_for_day(0) == "Jan. 01 1986",
		"the first floor no longer starts on Jan. 01 1986")
	_check(VhsOsd.Frame.recording_date_for_day(1) == "Jan. 02 1986",
		"the second floor did not advance one day")
	_check(VhsOsd.Frame.recording_date_for_day(30) == "Jan. 31 1986",
		"January boundary is off by one")
	_check(VhsOsd.Frame.recording_date_for_day(31) == "Feb. 01 1986",
		"calendar did not roll into February")
	_check(VhsOsd.Frame.recording_date_for_day(365) == "Jan. 01 1987",
		"calendar did not roll into the next year")
	var frame := VhsOsd.Frame.new()
	frame.recording_day_offset = 4
	_check(frame.recording_day_offset == 4,
		"frame rejected a campaign day offset")
	frame.recording_day_offset = -2
	_check(frame.recording_day_offset == 0,
		"frame accepted a date before the recording began")
	frame.free()
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check("_set_recording_day_for_level(level)" in main_source \
			and "DescentRun.FIXED_ORDER.find(theme)" in main_source,
		"main does not synchronize the OSD date with floor progression")
	for failure in failures:
		push_error("VHS CALENDAR AUDIT FAIL: " + failure)
	if failures.is_empty():
		print("VHS CALENDAR AUDIT PASS — 1986 date advances with campaign floors")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
