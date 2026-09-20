extends SceneTree
## Package 1 gate for the architectural witness path: thresholds reject
## occluded, offscreen, too-small, and fleeting views; before/after
## accumulators stay independent; and no commit classification upgrades an
## unwitnessed or incomplete commit into an architectural success.
##
## Run:
##   godot --headless --path . --script tools/audit_spatial_witness.gd

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _feed(in_view: bool, unobstructed: bool) -> Dictionary:
	return {"f": {"in_view": in_view, "unobstructed": unobstructed}}


func _run() -> void:
	_audit_rejections()
	_audit_two_of_three()
	_audit_before_window()
	_audit_after_independence()
	_audit_feature_ids()
	_audit_classification()
	_audit_round_robin()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - witness thresholds and commit classification hold")
		quit()
	else:
		quit(1)


func _audit_rejections() -> void:
	var tracker := SpatialWitnessTracker.new()
	tracker.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	# Occluded for a full window: never eligible.
	for i in 80:
		tracker.sample_with_visibility(0.1, _feed(true, false), 100.0 + i * 0.1)
	_expect(not tracker.witness_eligible("f", 108.0),
		"occluded feature must not be witness_eligible")
	# Offscreen for a full window: never eligible.
	var off := SpatialWitnessTracker.new()
	off.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	for i in 80:
		off.sample_with_visibility(0.1, _feed(false, true), 100.0 + i * 0.1)
	_expect(not off.witness_eligible("f", 108.0),
		"offscreen feature must not be witness_eligible")
	# Fleeting: a single clear sample is far below the 0.8s requirement.
	var brief := SpatialWitnessTracker.new()
	brief.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	brief.sample_with_visibility(0.1, _feed(true, true), 100.0)
	brief.sample_with_visibility(0.1, _feed(true, true), 100.1)
	_expect(not brief.witness_eligible("f", 100.1),
		"fleeting 0.2s view must not be witness_eligible")


func _audit_two_of_three() -> void:
	# Alternating clear/blocked: every sample from the second onward has 2 of
	# the last 3 clear, so time accumulates. The first sample alone must not
	# count.
	var tracker := SpatialWitnessTracker.new()
	tracker.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	tracker.sample_with_visibility(0.1, _feed(true, true), 200.0)
	_expect(tracker.visible_before_s("f", 200.0) < 0.05,
		"first sample alone must not accumulate visible time")
	for i in range(1, 20):
		var clear := i % 2 == 0
		tracker.sample_with_visibility(0.1, _feed(true, clear),
			200.0 + i * 0.1)
	_expect(tracker.witness_eligible("f", 202.0),
		"sustained 2-of-3 visibility must become witness_eligible")


func _audit_before_window() -> void:
	var tracker := SpatialWitnessTracker.new()
	tracker.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	for i in 10:
		tracker.sample_with_visibility(0.1, _feed(true, true),
			300.0 + i * 0.1)
	_expect(tracker.witness_eligible("f", 301.0),
		"1.0s of visibility must be witness_eligible")
	# Nine seconds later the old samples leave the 8s window.
	_expect(not tracker.witness_eligible("f", 310.0),
		"stale visibility must expire from the before window")


func _audit_after_independence() -> void:
	var tracker := SpatialWitnessTracker.new()
	tracker.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	for i in 10:
		tracker.sample_with_visibility(0.1, _feed(true, true),
			400.0 + i * 0.1)
	tracker.begin_after()
	for i in 8:
		tracker.sample_with_visibility(0.1, _feed(true, true),
			402.0 + i * 0.1)
	_expect(tracker.witness_eligible("f", 403.0),
		"after-phase sampling must not erase before eligibility")
	_expect(tracker.after_observed("f", 403.0),
		"0.8s of after visibility must satisfy after_observed")
	var short := SpatialWitnessTracker.new()
	short.track_feature("f", Vector3.ZERO, Vector2(1.6, 1.35))
	short.begin_after()
	for i in 5:
		short.sample_with_visibility(0.1, _feed(true, true),
			420.0 + i * 0.1)
	_expect(not short.after_observed("f", 420.5),
		"0.5s of after visibility must not satisfy after_observed")
	_expect(not short.witness_eligible("f", 420.5),
		"after visibility must not create before eligibility")


func _audit_feature_ids() -> void:
	var tracker := SpatialWitnessTracker.new()
	_expect(tracker.visible_before_s("ghost") == 0.0,
		"unknown feature must report zero visible time")
	_expect(not tracker.witness_eligible("ghost"),
		"unknown feature must not be witness_eligible")
	tracker.track_feature("a", Vector3.ZERO, Vector2(1.6, 1.35))
	tracker.track_feature("b", Vector3(5, 0, 0), Vector2(1.6, 1.35))
	tracker.untrack_feature("a")
	var remaining: Array[String] = tracker.tracked_ids()
	_expect(remaining == ["b"],
		"untracked feature must leave the stable id list")
	tracker.sample_with_visibility(0.1,
		{"a": {"in_view": true, "unobstructed": true}}, 500.0)
	_expect(tracker.visible_before_s("a", 500.0) == 0.0,
		"feed for untracked feature must be ignored")


func _audit_classification() -> void:
	_expect(SpatialWitnessTracker.architectural_success_eligible(
		{"committed": true, "witness_before": "visible"}),
		"committed plus visibly witnessed must be eligible")
	_expect(not SpatialWitnessTracker.architectural_success_eligible(
		{"committed": true, "witness_before": "nearest_fallback"}),
		"fallback witness must never claim architectural success")
	_expect(not SpatialWitnessTracker.architectural_success_eligible(
		{"committed": true, "witness_before": "none"}),
		"unwitnessed commit must never claim architectural success")
	_expect(not SpatialWitnessTracker.architectural_success_eligible(
		{"committed": true}),
		"missing provenance must never claim architectural success")
	_expect(not SpatialWitnessTracker.architectural_success_eligible(
		{"committed": false, "witness_before": "visible"}),
		"incomplete commit must never claim architectural success")
	_expect(SpatialWitnessTracker.record_witness_provenance(true, false)
		== SpatialWitnessTracker.PROVENANCE_VISIBLE,
		"visible witness must record visible provenance")
	_expect(SpatialWitnessTracker.record_witness_provenance(false, true)
		== SpatialWitnessTracker.PROVENANCE_FALLBACK,
		"fallback witness must record fallback provenance")
	_expect(SpatialWitnessTracker.record_witness_provenance(false, false)
		== SpatialWitnessTracker.PROVENANCE_NONE,
		"absent witness must record none provenance")


func _audit_round_robin() -> void:
	var tracker := SpatialWitnessTracker.new()
	for id in ["a", "b", "c", "d", "e"]:
		tracker.track_feature(id, Vector3.ZERO, Vector2(1.6, 1.35))
	var first: Array = tracker._select_features_for_sample()
	_expect(first.size() == 2,
		"one sample call must cover at most two features (6-ray budget)")
	var seen := {}
	for _i in 5:
		for id in tracker._select_features_for_sample():
			seen[id] = true
	_expect(seen.size() == 5,
		"round robin must reach every tracked feature")
