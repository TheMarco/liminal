class_name SpatialWitnessTracker
extends RefCounted
## Observes named architectural features through the real camera and reports
## whether the before-state was genuinely witnessed. Thresholds estimate
## attention; callers must log the result as `witness_eligible`, never as proof
## the player consciously noticed the change.
##
## There is deliberately no visibility fallback here. An occluded, offscreen,
## too-small, or fleeting feature is simply not witnessed, and the commit
## classification in this file never upgrades such a record into an
## architectural success.

## Tuning: sampling and witness thresholds (spec section 5.1).
const SAMPLE_HZ := 10.0
const MAX_RAYS_PER_FEATURE := 3
const MAX_RAYS_PER_SAMPLE_CALL := 6
const MIN_VIEWPORT_WIDTH_FRACTION := 0.05
const MIN_VIEWPORT_HEIGHT_FRACTION := 0.08
const VIEW_CENTER_FRACTION := 0.8
const BEFORE_REQUIRED_S := 0.8
const BEFORE_WINDOW_S := 8.0
const AFTER_REQUIRED_S := 0.75

## Commit-record witness provenance values.
const PROVENANCE_VISIBLE := "visible"
const PROVENANCE_FALLBACK := "nearest_fallback"
const PROVENANCE_NONE := "none"

var _features := {}
var _order: Array[String] = []
var _cursor := 0
var _since_sample := 0.0
var _after := false
## Injectable occlusion test `(from: Vector3, to: Vector3) -> bool`
## (true means unobstructed). Null uses live physics raycasts.
var ray_test := Callable()


func track_feature(feature_id: String, position: Variant,
		extents: Vector2) -> void:
	if feature_id.is_empty():
		return
	if not (position is Vector3) and not position is Callable:
		return
	if not _features.has(feature_id):
		_order.append(feature_id)
	_features[feature_id] = {
		"position": position,
		"extents": extents,
		"history": [],
		"before": [],
		"after": [],
		"last_visible": -1.0,
	}


func untrack_feature(feature_id: String) -> void:
	_features.erase(feature_id)
	_order.erase(feature_id)


func tracked_ids() -> Array[String]:
	return _order.duplicate()


func begin_after() -> void:
	_after = true


func begin_before() -> void:
	_after = false


func reset() -> void:
	_features.clear()
	_order.clear()
	_cursor = 0
	_since_sample = 0.0
	_after = false


## Bounded per-frame entry point. Most calls only advance the sample clock;
## at SAMPLE_HZ a round-robin subset of features is tested against the camera.
func sample(camera: Camera3D, dt: float, now: float = -1.0) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_since_sample += dt
	if _since_sample < 1.0 / SAMPLE_HZ:
		return
	_since_sample = 0.0
	var stamp := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
	var feed := {}
	var budget := MAX_RAYS_PER_SAMPLE_CALL
	for feature_id in _select_features_for_sample():
		if budget <= 0:
			break
		var feature: Dictionary = _features[feature_id]
		var point := _resolve_position(feature)
		if point == Vector3.INF:
			continue
		var in_view := _point_in_useful_view(camera, point,
			feature["extents"])
		var unobstructed := false
		if in_view:
			# Offscreen features cost no rays; the budget covers visible ones.
			unobstructed = _sample_occlusion(camera, point,
				feature["extents"], budget)
			budget -= MAX_RAYS_PER_FEATURE
		feed[feature_id] = {
			"in_view": in_view,
			"unobstructed": unobstructed,
		}
	sample_with_visibility(1.0 / SAMPLE_HZ, feed, stamp)


## Accumulator entry point with a scripted visibility feed. Audits and the
## camera path share this; only the feed source differs.
func sample_with_visibility(dt: float, feed: Dictionary,
		now: float = -1.0) -> void:
	var stamp := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
	for feature_id in feed.keys():
		if not _features.has(feature_id):
			continue
		var entry: Dictionary = feed[feature_id]
		var in_view := bool(entry.get("in_view", false))
		var unobstructed := bool(entry.get("unobstructed", false))
		var feature: Dictionary = _features[feature_id]
		var history: Array = feature["history"]
		history.append(unobstructed)
		while history.size() > 3:
			history.pop_front()
		var clear_count := 0
		for was_clear in history:
			if was_clear:
				clear_count += 1
		if in_view and clear_count >= 2:
			var samples: Array = feature["after"] if _after \
				else feature["before"]
			samples.append({"at": stamp, "dt": dt})
			feature["last_visible"] = stamp


func visible_before_s(feature_id: String, now: float = -1.0) -> float:
	return _windowed_total(feature_id, "before", BEFORE_WINDOW_S, now)


func visible_after_s(feature_id: String, now: float = -1.0) -> float:
	return _windowed_total(feature_id, "after", -1.0, now)


func witness_eligible(feature_id: String, now: float = -1.0) -> bool:
	return visible_before_s(feature_id, now) >= BEFORE_REQUIRED_S


func after_observed(feature_id: String, now: float = -1.0) -> bool:
	return visible_after_s(feature_id, now) >= AFTER_REQUIRED_S


func last_visible_at(feature_id: String) -> float:
	if not _features.has(feature_id):
		return -1.0
	return float(_features[feature_id]["last_visible"])


## Round-robin subset sized so one sample call never exceeds its ray budget.
func _select_features_for_sample() -> Array[String]:
	var out: Array[String] = []
	if _order.is_empty():
		return out
	var slots := MAX_RAYS_PER_SAMPLE_CALL / MAX_RAYS_PER_FEATURE
	var index := _cursor
	for _i in _order.size():
		if out.size() >= slots:
			break
		var candidate: String = _order[index % _order.size()]
		if _features.has(candidate):
			out.append(candidate)
		index += 1
	_cursor = index % _order.size()
	return out


func _windowed_total(feature_id: String, key: String, window_s: float,
		now: float) -> float:
	if not _features.has(feature_id):
		return 0.0
	var stamp := now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
	var total := 0.0
	var samples: Array = _features[feature_id][key]
	for entry in samples:
		if window_s > 0.0 and stamp - float(entry["at"]) > window_s:
			continue
		total += float(entry["dt"])
	return total


func _resolve_position(feature: Dictionary) -> Vector3:
	var source: Variant = feature["position"]
	if source is Vector3:
		return source
	if source is Callable and (source as Callable).is_valid():
		var value: Variant = (source as Callable).call()
		if value is Vector3:
			return value
	return Vector3.INF


func _point_in_useful_view(camera: Camera3D, point: Vector3,
		extents: Vector2) -> bool:
	if not camera.is_position_in_frustum(point):
		return false
	var viewport := camera.get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var center := camera.unproject_position(point)
	var margin := (1.0 - VIEW_CENTER_FRACTION) * 0.5
	if center.x < size.x * margin or center.x > size.x * (1.0 - margin):
		return false
	if center.y < size.y * margin or center.y > size.y * (1.0 - margin):
		return false
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var half_w := absf(camera.unproject_position(
		point + right * extents.x).x - center.x)
	var half_h := absf(camera.unproject_position(
		point + up * extents.y).y - center.y)
	return half_w * 2.0 / size.x >= MIN_VIEWPORT_WIDTH_FRACTION \
		and half_h * 2.0 / size.y >= MIN_VIEWPORT_HEIGHT_FRACTION


func _sample_occlusion(camera: Camera3D, point: Vector3,
		extents: Vector2, budget: int) -> bool:
	if budget < MAX_RAYS_PER_FEATURE:
		return false
	var from := camera.global_position
	var right := camera.global_transform.basis.x
	var offsets := [0.0, -0.5, 0.5]
	var clear := 0
	for factor in offsets:
		var target: Vector3 = point + right * extents.x * factor
		if _ray_clear(from, target):
			clear += 1
	return clear >= 2


func _ray_clear(from: Vector3, to: Vector3) -> bool:
	if ray_test.is_valid():
		return bool(ray_test.call(from, to))
	var space := _physics_space()
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()


func _physics_space() -> PhysicsDirectSpaceState3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.world_3d.direct_space_state


## No-fallback commit classification for the architectural path. A commit that
## was never visibly witnessed, or never completed, is never reported as an
## architectural success, regardless of after-state visibility.
static func architectural_success_eligible(
		commit_record: Dictionary) -> bool:
	return bool(commit_record.get("committed", false)) \
		and str(commit_record.get("witness_before", PROVENANCE_NONE)) \
			== PROVENANCE_VISIBLE


static func record_witness_provenance(visible: bool,
		fallback_available: bool) -> String:
	if visible:
		return PROVENANCE_VISIBLE
	if fallback_available:
		return PROVENANCE_FALLBACK
	return PROVENANCE_NONE
