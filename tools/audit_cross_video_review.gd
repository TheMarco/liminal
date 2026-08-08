extends SceneTree
## Contract for the optional-video editorial reviewer. The audit report lives
## in an isolated temporary file and never touches a real prune list.
## Run: godot --headless --path . --script tools/audit_cross_video_review.gd

const TEST_REPORT := "/tmp/liminal_audit_cross_video_review.txt"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_REPORT)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

	var review := CrossVideoReview.new()
	review.report_path = TEST_REPORT
	root.add_child(review)
	await process_frame
	await process_frame
	var reviewed := review.review_paths()
	var optional := VhsTapeLibrary.paths(false)
	var objective := VhsTapeLibrary.paths(true)
	_expect(reviewed == optional,
		"reviewer does not contain the complete sorted optional pool")
	_expect(not reviewed.is_empty(), "reviewer has no optional recordings")
	for path in reviewed:
		_expect(not objective.has(path),
			"reviewer leaked objective recording %s" % path)
		_expect(load(path) is VideoStream,
			"reviewer path is not a loadable VideoStream: %s" % path)
		_expect(review._sources.has(path),
			"reviewer has no source mapping for %s" % path)

	if not reviewed.is_empty():
		review._toggle_mark()
		_expect(review.marked_paths() == [reviewed[0]],
			"marking did not record the current clip")
		var report := FileAccess.get_file_as_string(absolute)
		_expect(report.contains(reviewed[0]),
			"marked clip was not written to the prune report")
		review._toggle_mark()
		_expect(review.marked_paths().is_empty(),
			"unmarking did not remove the current clip")

	review.free()
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("Cross video review audit: PASS — optional pool only; prune report is reversible")
		quit()
	else:
		quit(1)
