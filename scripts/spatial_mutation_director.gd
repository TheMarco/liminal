class_name SpatialMutationDirector
extends Node
## Floor-owned selector and sequencer for spatial mutation events. Owns the
## witness tracker, pacing holds, leases, and presentation; never constructs
## meshes, moves actors, or persists beyond the transaction's allowlisted
## outcome. One structural event per floor is active at a time.

signal event_finished(site_id: String, outcome: String)
signal event_started(site_id: String, presentation: String)

const PAYOFF_WATCH_S := 10.0

var tracker := SpatialWitnessTracker.new()

var _horror: HorrorDirector
var _manager: ChunkManager
var _topology: DescentTopology
var _route: DescentRoute
var _camera: Camera3D
var _blackout_begin := Callable()
var _blackout_end := Callable()
var _mode_ready := Callable()
var _probe_override := Callable()
var _scanned_override: Array = []
var _sites := {}
var _active_site := ""
var _active_tx: SpatialSiteTransaction
var _active_plan: SpatialTransitionPlan
var _active_presentation := ""
var _occupancy := Callable()
var _payoff_until := {}
var _phase := "dormant"
## Structured record of the most recent event (request through recognition).
var last_event := {}
## Rejected requests do not overwrite a running/settled event's telemetry.
var last_rejection := {}


func configure(horror: HorrorDirector, manager: ChunkManager,
		topology: DescentTopology, route: DescentRoute = null) -> void:
	_horror = horror
	_manager = manager
	_topology = topology
	_route = route


## Fixture seam: scripted base passability and scanned set. Without it the
## campaign topology/route supplies both.
func set_connectivity(probe: Callable, scanned: Array) -> void:
	_probe_override = probe
	_scanned_override = scanned.duplicate()


func set_camera(camera: Camera3D) -> void:
	_camera = camera


func set_blackout_driver(begin: Callable, end: Callable) -> void:
	_blackout_begin = begin
	_blackout_end = end


func set_mode_ready(check: Callable) -> void:
	_mode_ready = check


func register_door_site(site: MigratingDoorSite, state: SpatialSiteState,
		occupancy: Callable, persist: Callable,
		graph_invalidated := Callable()) -> bool:
	if site == null or not site.is_prepared() or state == null:
		return false
	if state.spec_id != site.spec().id:
		return false
	_sites[state.spec_id] = {
		"site": site,
		"state": state,
		"occupancy": occupancy,
		"persist": persist,
		"graph_invalidated": graph_invalidated,
	}
	tracker.begin_before()
	for feature_id in site_witness_ids(state.spec_id):
		var point: Dictionary = site.spec() \
			.witness_points[feature_id]
		tracker.track_feature(feature_id, point["position"],
			point["extents"])
	return true


func site_witness_ids(site_id: String) -> Array:
	if not _sites.has(site_id):
		return []
	var site: MigratingDoorSite = _sites[site_id]["site"]
	var ids: Array = site.spec().witness_points.keys()
	ids.sort()
	return ids


func is_active() -> bool:
	return not _active_site.is_empty()


func site_state(site_id: String) -> SpatialSiteState:
	if not _sites.has(site_id):
		return null
	return _sites[site_id]["state"] as SpatialSiteState


func site_cue_position(site_id: String) -> Vector3:
	if not _sites.has(site_id):
		return Vector3.INF
	var site: MigratingDoorSite = _sites[site_id]["site"]
	return site.leading_edge_position("b")


func current_phase() -> String:
	return _phase


## Request one event: witness, pacing, revision, leases, validation, then
## onset. Nothing visible changes unless every gate passes. The plan is
## built fresh per request so its expected revision is current.
func request_event(site_id: String,
		plan: SpatialTransitionPlan) -> Dictionary:
	if is_active():
		return _reject(site_id, "another event is active", plan)
	if not _sites.has(site_id):
		return _reject(site_id, "unknown site", plan)
	if plan == null or not plan.is_valid() or plan.site_id != site_id:
		return _reject(site_id, "invalid plan", plan)
	if not _payoff_until.is_empty():
		return _reject(site_id, "recognition payoff pending", plan)
	if _mode_ready.is_valid() and not bool(_mode_ready.call(plan.presentation)):
		return _reject(site_id, "player mode is not ready", plan)
	var entry: Dictionary = _sites[site_id]
	var presentation := plan.presentation
	_phase = "armed"
	for feature_id in site_witness_ids(site_id):
		if not tracker.witness_eligible(feature_id):
			_phase = "dormant"
			return _reject(site_id,
				"witness not eligible: %s" % feature_id, plan)
	if _horror != null and not _horror.try_start_structural():
		_phase = "dormant"
		return _reject(site_id, "pacing hold refused", plan)
	if _topology != null and _topology.revision != plan.expected_revision:
		_release_hold()
		return _reject(site_id, "topology revision changed", plan)
	_phase = "preparing"
	var site: MigratingDoorSite = entry["site"]
	if _manager != null:
		_manager.set_site_cells(site.spec().cells)
	var probe := _probe_override
	var scanned := _scanned_override
	if not probe.is_valid():
		if _topology == null or _route == null:
			_release_hold()
			_release_leases()
			return _reject(site_id, "connectivity proof unavailable", plan)
		probe = Callable(self, "_campaign_probe")
		scanned = _route.scanned_cells()
	var tx := SpatialSiteTransaction.new()
	var begin := tx.begin(plan, site, entry["state"], _topology,
		probe, scanned, entry["persist"], entry["graph_invalidated"])
	if not begin.ok:
		_release_hold()
		_release_leases()
		var rejected := _reject(site_id, begin.reason, plan)
		last_rejection["persist_error"] = int(begin.persist_error)
		return rejected
	_active_site = site_id
	_active_tx = tx
	_active_plan = plan
	_active_presentation = presentation
	_occupancy = entry["occupancy"]
	var admission := site.current_clearance()
	last_event = {
		"site": site_id,
		"presentation": presentation,
		"witness_features": site_witness_ids(site_id),
		"witness_before": SpatialWitnessTracker.PROVENANCE_VISIBLE,
		"outcome": "running",
		"committed": false,
		"failure_reason": "",
		"requested_at_msec": Time.get_ticks_msec(),
		"lights_on_msec": -1,
		"admission": {"a": admission.openness["a"],
			"b": admission.openness["b"]},
	}
	if presentation == "blackout":
		_phase = "presenting"
		var dark_ok := true
		if _blackout_begin.is_valid():
			dark_ok = bool(_blackout_begin.call())
		if not dark_ok:
			_abort_before_onset("blackout onset refused")
			return {"ok": false, "reason": "blackout onset refused"}
	_phase = "transitioning"
	event_started.emit(site_id, presentation)
	return {"ok": true, "reason": ""}


## Lights returned (blackout timer or external restore). A running transition
## settles to its safe stable state and reveals that actual result; nothing
## is prolonged or snapped.
func notify_lights_on() -> void:
	if not last_event.is_empty() \
			and str(last_event.get("presentation", "")) == "blackout" \
			and int(last_event.get("lights_on_msec", -1)) < 0:
		last_event["lights_on_msec"] = Time.get_ticks_msec()
	if is_active() and _active_presentation == "blackout" \
			and _blackout_end.is_valid():
		_blackout_end.call()
	if is_active() and _active_tx.is_running():
		_active_tx.cancel()
		return
	var settled_site := str(last_event.get("site", ""))
	if _payoff_until.has(settled_site) \
			and is_inf(float(_payoff_until[settled_site])):
		_begin_recognition_window(settled_site)


func _physics_process(dt: float) -> void:
	if _camera != null and not _sites.is_empty():
		tracker.sample(_camera, dt)
	_update_recognition()
	if not is_active():
		return
	var occupancy := []
	if _occupancy.is_valid():
		occupancy = _occupancy.call()
	var result := _active_tx.advance(dt, occupancy)
	if not result.done:
		return
	_phase = "settling"
	last_event["outcome"] = result.outcome
	last_event["committed"] = result.durable
	last_event["persist_error"] = int(result.persist_error)
	if result.invariant_failed:
		last_event["failure_reason"] = "topology publication failed"
	elif not result.durable:
		last_event["failure_reason"] = "settled state was not durably saved"
	last_event["settled_at_msec"] = Time.get_ticks_msec()
	var settled_site: MigratingDoorSite = _sites[_active_site]["site"]
	var settled := settled_site.current_clearance()
	last_event["settled_phase"] = _active_tx.settle_state().stable_phase
	last_event["settled_geometry"] = {"a": settled.openness["a"],
		"b": settled.openness["b"]}
	last_event["topology_revision"] = _topology.revision \
		if _topology != null else -1
	if _active_presentation == "blackout" and _blackout_end.is_valid() \
			and int(last_event.get("lights_on_msec", -1)) < 0:
		_blackout_end.call()
		last_event["lights_on_msec"] = Time.get_ticks_msec()
	_release_leases()
	_release_hold()
	var finished_site := _active_site
	var waits_for_light := _active_presentation == "blackout" \
		and int(last_event.get("lights_on_msec", -1)) < 0
	if waits_for_light:
		# Keep the admission gate occupied, but do not sample or spend the payoff
		# clock in darkness. notify_lights_on() starts the real window.
		_payoff_until[finished_site] = INF
		_phase = "awaiting_visibility"
	else:
		_begin_recognition_window(finished_site)
	_active_site = ""
	_active_tx = null
	_active_plan = null
	event_finished.emit(finished_site, result.outcome)


## Consume the pending blackout reveal, if the last settled event ran in
## darkness. Returns {"position": Vector3} once, then {} until the next
## blackout event settles. Main plays the architectural creak there.
func take_blackout_reveal() -> Dictionary:
	if last_event.is_empty() \
			or str(last_event.get("presentation", "")) != "blackout" \
			or bool(last_event.get("reveal_taken", false)) or is_active():
		return {}
	if not _sites.has(str(last_event.get("site", ""))):
		return {}
	# No creak for a non-event: aborted-before-onset outcomes never moved.
	var site: MigratingDoorSite = _sites[str(last_event["site"])]["site"]
	var now := site.current_clearance()
	var admission: Dictionary = last_event.get("admission", {})
	if is_equal_approx(float(now.openness.get("a", 0.0)),
			float(admission.get("a", 0.0))) \
		and is_equal_approx(float(now.openness.get("b", 0.0)),
			float(admission.get("b", 0.0))):
		return {}
	last_event["reveal_taken"] = true
	return {"position": site.leading_edge_position("b")}


## Called by the presentation layer (or audit) once the after-state had its
## useful visible time. Recognition is telemetry, never a success upgrade.
func note_recognized(site_id: String) -> void:
	_payoff_until.erase(site_id)
	if str(last_event.get("site", "")) == site_id:
		last_event["recognized"] = true
		last_event["observed_after_msec"] = Time.get_ticks_msec()
	tracker.begin_before()
	_phase = "dormant"


func _begin_recognition_window(site_id: String) -> void:
	if site_id.is_empty() or not _sites.has(site_id):
		return
	tracker.begin_after()
	_payoff_until[site_id] = Time.get_ticks_msec() / 1000.0 \
		+ PAYOFF_WATCH_S
	_phase = "awaiting_recognition"


func _payoff_pending(site_id: String) -> bool:
	if not _payoff_until.has(site_id):
		return false
	if Time.get_ticks_msec() / 1000.0 > float(_payoff_until[site_id]):
		_payoff_until.erase(site_id)
		return false
	return true


func _update_recognition() -> void:
	if _payoff_until.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for raw_id in _payoff_until.keys().duplicate():
		var site_id := str(raw_id)
		if not _sites.has(site_id):
			_payoff_until.erase(site_id)
			continue
		if is_inf(float(_payoff_until[site_id])):
			continue
		var observed_at := -1.0
		for feature_id in site_witness_ids(site_id):
			# The clock is a stable reference; recognition is earned by seeing
			# either of the two architectural positions after it changed.
			if str(feature_id).begins_with("anchor_"):
				continue
			if tracker.after_observed(feature_id, now):
				observed_at = maxf(observed_at,
					tracker.last_visible_at(feature_id))
		if observed_at >= 0.0:
			var entry: Dictionary = _sites[site_id]
			var state: SpatialSiteState = entry["state"]
			state.last_seen_after = observed_at
			var persist: Callable = entry["persist"]
			if persist.is_valid():
				persist.call(state)
			note_recognized(site_id)
			continue
		if now > float(_payoff_until[site_id]):
			_payoff_until.erase(site_id)
			if str(last_event.get("site", "")) == site_id:
				last_event["recognized"] = false
				last_event["recognition_expired_msec"] = Time.get_ticks_msec()
			tracker.begin_before()
			_phase = "dormant"


func _reject(site_id: String, reason: String,
		plan: SpatialTransitionPlan = null) -> Dictionary:
	last_rejection = {
		"site": site_id,
		"presentation": plan.presentation if plan != null else "",
		"requested_at_msec": Time.get_ticks_msec(),
		"outcome": "rejected",
		"failure_reason": reason,
	}
	return {"ok": false, "reason": reason}


func _release_hold() -> void:
	_phase = "dormant"
	if _horror != null:
		_horror.end_structural()


func _release_leases() -> void:
	if _manager != null:
		_manager.set_site_cells([])


func _abort_before_onset(reason: String) -> void:
	_active_tx.cancel()
	var result := _active_tx.advance(0.0, [])
	last_event["outcome"] = result.outcome \
		if result.outcome == "persistence_failed" else reason
	last_event["committed"] = false
	last_event["persist_error"] = int(result.persist_error)
	last_event["failure_reason"] = reason if result.persist_error == OK \
		else "rollback state was not durably saved"
	_release_leases()
	_release_hold()
	_active_site = ""
	_active_tx = null
	_active_plan = null


## Campaign base passability: legacy state plus photo layer, without the
## site overlay the transaction's overrides replace. Site keys never overlap
## photographed keys (reservation rejects them), so photo answers stand.
func _campaign_probe(cell: Vector2i, dir: int) -> bool:
	if _topology == null:
		return false
	var record := _topology.site_edge(cell, dir)
	if not record.is_empty():
		# The plan's phase edges must cover every site key; the probe must
		# never answer for one. Fail closed so the proof cannot pass
		# through an edge whose phase state was not declared.
		push_error("SpatialMutationDirector: site key missing from plan")
		return false
	var info := _topology.edge_info_for_state(cell, dir,
		_topology.current_state_id())
	return not bool(info.get("wall", true))
