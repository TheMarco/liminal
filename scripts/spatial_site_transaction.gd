class_name SpatialSiteTransaction
extends RefCounted
## Module-phase executor for one site transition. Opens before it closes, so
## every intermediate state is a validated fully-open phase; never restores
## walls through occupants. Single-door sequencing for Package 2.
##
## The transaction owns phase order, graph publication, the safety-hold
## timer, and the persistence outcome. The director owns leases, pacing,
## witness gating, and presentation.

class BeginResult extends RefCounted:
	var ok := false
	var reason := ""
	var persist_error: Error = OK


class AdvanceResult extends RefCounted:
	var done := false
	## Running phase name, or the settled stable phase once done.
	var phase := ""
	var outcome := ""
	var close_blocked := false
	var tokens: Array = []
	## True only after the settled state reached the atomic checkpoint.
	var durable := false
	var persist_error: Error = OK
	var invariant_failed := false


class CommitResult extends RefCounted:
	var ok := false
	var outcome := ""
	var state: SpatialSiteState

## Aperture openness per stable door phase. Opening always precedes closing.
const PHASE_APERTURES := {
	"a_open": {"a": 1.0, "b": 0.0},
	"both_open": {"a": 1.0, "b": 1.0},
	"b_open": {"a": 0.0, "b": 1.0},
}
const BOTH_OPEN_DWELL := 0.3

var _plan: SpatialTransitionPlan
var _site: MigratingDoorSite
var _state: SpatialSiteState
var _topology: DescentTopology
var _graph_probe := Callable()
var _scanned := {}
var _persist := Callable()
var _graph_invalidated := Callable()
var _running := false
var _settled := false
var _steps: Array = []
var _step_idx := 0
var _dwell_left := 0.0
var _hold_time := 0.0
var _own_commits := 0
var _outcome := ""
var _durable := false
var _persist_error: Error = OK
var _publication_failed := false
var _cancelling := false
var _settling := false
var _settle_targets := {"a": 1.0, "b": 1.0}
var _published := {"a": false, "b": false}


## graph_probe(cell, dir) -> bool answers base passability (without the
## site overlay); scanned lists every routable cell; persist(state) stores
## the settled outcome; graph_invalidated() refreshes routing/caches after
## each published passability change.
func begin(plan: SpatialTransitionPlan, site: MigratingDoorSite,
		state: SpatialSiteState, topology: DescentTopology,
		graph_probe: Callable, scanned_cells: Array,
		persist: Callable,
		graph_invalidated := Callable()) -> BeginResult:
	var out := BeginResult.new()
	if _running or _settled:
		out.reason = "transaction already used"
		return out
	if plan == null or not plan.is_valid():
		out.reason = "invalid plan"
		return out
	if site == null or not site.is_prepared():
		out.reason = "site not prepared"
		return out
	if state == null or state.spec_id != plan.site_id:
		out.reason = "state does not belong to planned site"
		return out
	if topology != null and topology.revision != plan.expected_revision:
		out.reason = "topology revision changed before begin"
		return out
	if not PHASE_APERTURES.has(plan.from_phase) \
			or not PHASE_APERTURES.has(plan.to_phase):
		out.reason = "unknown door phase"
		return out
	if not graph_probe.is_valid() or scanned_cells.is_empty():
		out.reason = "connectivity proof unavailable"
		return out
	if not persist.is_valid():
		out.reason = "persistence unavailable"
		out.persist_error = ERR_UNCONFIGURED
		return out
	_plan = plan
	_site = site
	_state = state
	_topology = topology
	_graph_probe = graph_probe
	_persist = persist
	_graph_invalidated = graph_invalidated
	for at in scanned_cells:
		_scanned[at] = true
	for phase in _plan.phase_edges.keys():
		if not _phase_connects(str(phase)):
			out.reason = "phase %s disconnects a protected route" % phase
			_reset()
			return out
	var clearance := _site.current_clearance()
	for aperture in ["a", "b"]:
		var want_open := float(PHASE_APERTURES[_plan.from_phase][aperture]) \
			> 0.5
		if bool(clearance.traversable[aperture]) != want_open:
			out.reason = "installed geometry does not match from_phase"
			_reset()
			return out
		_published[aperture] = want_open
		if _topology != null and _plan.aperture_edges.has(aperture):
			var mapping: Dictionary = _plan.aperture_edges[aperture]
			var record := _topology.site_edge(mapping["cell"],
				int(mapping["dir"]))
			var record_open := str(record.get("kind", "open")) != "wall"
			if record.is_empty() or record_open != want_open:
				out.reason = "topology overlay does not match from_phase"
				_reset()
				return out
	_steps = _plan_steps()
	_state.progress = 0.0
	_running = true
	# Establish a safe arrival-based reconstruction before any leaf moves.
	# SpatialSiteState.to_disk() maps the active live state to both-open without
	# mutating the exact phase/progress used by this transaction.
	var checkpoint_error := _persist_state()
	if checkpoint_error != OK:
		_state.progress = -1.0
		out.reason = "active checkpoint failed"
		out.persist_error = checkpoint_error
		_reset()
		return out
	_apply_step_targets()
	out.ok = true
	return out


func is_running() -> bool:
	return _running and not _settled


func cancel() -> void:
	if not is_running():
		return
	_cancelling = true


## Drive one physics tick. Occupancy entries use the site's fixed keys.
func advance(dt: float, occupancy: Array) -> AdvanceResult:
	var out := AdvanceResult.new()
	if not is_running():
		out.done = _settled
		out.phase = _state.stable_phase if _state != null else ""
		out.outcome = _outcome
		out.durable = _durable
		out.persist_error = _persist_error
		out.invariant_failed = _publication_failed
		return out
	if not _settling and _topology != null and _topology.revision \
			!= _plan.expected_revision + _own_commits:
		_begin_settle("revision_conflict", 1.0, 1.0, "both_open", false)
	if _cancelling and not _settling:
		_begin_cancel_settle()
	var result := _site.advance_physics(dt, occupancy)
	out.close_blocked = result.close_blocked
	out.tokens = result.tokens
	if result.passability_changed:
		if not _publish_passability(result) and not _settling:
			_begin_settle("graph_publication_failed", 1.0, 1.0,
				"both_open", false)
	if _settling:
		_update_progress()
		if result.targets_reached:
			var commit := _commit_settled()
			out.done = true
			out.phase = _state.stable_phase
			out.outcome = commit.outcome
			out.durable = commit.ok
			out.persist_error = _persist_error
			out.invariant_failed = _publication_failed
			return out
	if _step_waiting_on_motion(result):
		if result.close_blocked and _step_closes():
			_hold_time += dt
			if _hold_time >= _plan.hold_timeout:
				# The building made a new route even though it could not
				# close the old one. Settle both-open; never retry closure
				# behind the same actor.
				_begin_settle("both_open_timeout", 1.0, 1.0,
					"both_open", true)
				out.phase = _state.stable_phase
				out.outcome = _outcome
				return out
		_step_progress(result, dt)
		_update_progress()
		out.phase = _current_phase_name()
		return out
	_step_idx += 1
	if _step_idx >= _steps.size():
		var commit := _finish()
		out.done = true
		out.outcome = commit.outcome
		out.durable = commit.ok
		out.persist_error = _persist_error
		out.invariant_failed = _publication_failed
		out.phase = _state.stable_phase
		return out
	else:
		_apply_step_targets()
	_update_progress()
	out.phase = _state.stable_phase
	if out.outcome.is_empty():
		out.outcome = _outcome
	return out


func settle_state() -> SpatialSiteState:
	return _state


func _plan_steps() -> Array:
	var from_map: Dictionary = PHASE_APERTURES[_plan.from_phase]
	var to_map: Dictionary = PHASE_APERTURES[_plan.to_phase]
	var steps := []
	for aperture in ["a", "b"]:
		if float(from_map[aperture]) < 0.5 \
				and float(to_map[aperture]) > 0.5:
			steps.append({"aperture": aperture, "target": 1.0,
				"closes": false})
	for aperture in ["a", "b"]:
		if float(from_map[aperture]) > 0.5 \
				and float(to_map[aperture]) < 0.5:
			steps.append({"aperture": aperture, "target": 0.0,
				"closes": true})
	return steps


func _apply_step_targets() -> void:
	_dwell_left = 0.0
	_hold_time = 0.0
	if _step_idx >= _steps.size():
		return
	var from_map: Dictionary = PHASE_APERTURES[_plan.from_phase]
	var targets := {"a": float(from_map["a"]), "b": float(from_map["b"])}
	for i in _step_idx + 1:
		var step: Dictionary = _steps[i]
		targets[str(step["aperture"])] = float(step["target"])
	_site.set_targets(targets["a"], targets["b"])


func _aperture_open_at_start(aperture: String) -> bool:
	return float(PHASE_APERTURES[_plan.from_phase][aperture]) > 0.5


func _step_closes() -> bool:
	if _step_idx >= _steps.size():
		return false
	return bool(_steps[_step_idx]["closes"])


func _current_phase_name() -> String:
	var clearance := _site.current_clearance()
	var a := bool(clearance.traversable["a"])
	var b := bool(clearance.traversable["b"])
	if a and b:
		return "both_open"
	if a:
		return "a_open"
	if b:
		return "b_open"
	return "transit"


func _step_waiting_on_motion(result: MigratingDoorSite.PhaseResult) -> bool:
	if not result.targets_reached:
		return true
	if _current_phase_name() == "both_open" and _step_idx + 1 < _steps.size():
		return true
	return false


func _step_progress(result: MigratingDoorSite.PhaseResult, dt: float) -> void:
	if not result.targets_reached:
		return
	if _current_phase_name() == "both_open" \
			and _step_idx + 1 < _steps.size():
		_dwell_left += dt
		if _dwell_left >= BOTH_OPEN_DWELL:
			_step_idx += 1
			_apply_step_targets()


func _publish_passability(result: MigratingDoorSite.PhaseResult) -> bool:
	var ok := true
	for aperture in ["a", "b"]:
		var open := bool(result.traversable[aperture])
		if open == bool(_published[aperture]):
			continue
		if _topology != null and _plan.aperture_edges.has(aperture):
			var mapping: Dictionary = _plan.aperture_edges[aperture]
			if not _topology.set_site_edge(_plan.site_id, mapping["cell"],
					int(mapping["dir"]), open):
				ok = false
				_publication_failed = true
				continue
			_own_commits += 1
		_published[aperture] = open
	if _graph_invalidated.is_valid():
		_graph_invalidated.call()
	return ok


func _finish() -> CommitResult:
	_state.stable_phase = _plan.to_phase
	_state.door_openness["a"] = _site.current_clearance().openness["a"]
	_state.door_openness["b"] = _site.current_clearance().openness["b"]
	_state.activated = true
	_state.completed = true
	_outcome = "completed_%s" % _plan.to_phase
	return _commit_settled()


func _begin_settle(outcome: String, a: float, b: float, phase: String,
		completed: bool, activated := true) -> void:
	_outcome = outcome
	_settle_targets = {"a": a, "b": b}
	_site.set_targets(a, b)
	_state.stable_phase = phase
	_state.activated = activated
	_state.completed = completed
	_settling = true


func _begin_cancel_settle() -> void:
	# Before exposure the old state is a safe rollback; after exposure the
	# validated both-open state is. Either way the site drives to the safe
	# targets before anything is persisted.
	var clearance := _site.current_clearance()
	var exposed := bool(clearance.traversable["a"]) \
		!= _aperture_open_at_start("a") \
		or bool(clearance.traversable["b"]) != _aperture_open_at_start("b")
	if exposed:
		_begin_settle("cancelled_both_open", 1.0, 1.0, "both_open", false)
	else:
		_begin_settle("cancelled_rollback",
			1.0 if _aperture_open_at_start("a") else 0.0,
			1.0 if _aperture_open_at_start("b") else 0.0,
			_plan.from_phase, false, false)


func _commit_settled() -> CommitResult:
	var result := CommitResult.new()
	_state.door_openness["a"] = _site.current_clearance().openness["a"]
	_state.door_openness["b"] = _site.current_clearance().openness["b"]
	_state.progress = -1.0
	if _publication_failed:
		# The initial active checkpoint already contains the safe both-open
		# reconstruction. Do not claim or write a final durable outcome while
		# live geometry and the navigation overlay could disagree.
		_outcome = "graph_publication_failed"
		_durable = false
		_running = false
		_settled = true
		result.ok = false
		result.outcome = _outcome
		result.state = _state
		return result
	_persist_error = _persist_state()
	_durable = _persist_error == OK
	if not _durable:
		_outcome = "persistence_failed"
	_running = false
	_settled = true
	result.ok = _durable
	result.outcome = _outcome
	result.state = _state
	return result


func _persist_state() -> Error:
	if not _persist.is_valid():
		return ERR_UNCONFIGURED
	var raw: Variant = _persist.call(_state)
	# Temporary compatibility with older fixture callbacks that captured state
	# and returned void. Production callbacks must return DescentProgress's Error.
	if raw == null:
		return OK
	if typeof(raw) != TYPE_INT:
		return ERR_INVALID_DATA
	return int(raw)


func _update_progress() -> void:
	var clearance := _site.current_clearance()
	_state.door_openness["a"] = clearance.openness["a"]
	_state.door_openness["b"] = clearance.openness["b"]
	if _steps.is_empty():
		_state.progress = 1.0
		return
	if _step_idx >= _steps.size():
		_state.progress = 1.0
		return
	var step: Dictionary = _steps[_step_idx]
	var aperture := str(step["aperture"])
	var openness := float(clearance.openness[aperture])
	var fraction := openness if float(step["target"]) > 0.5 \
		else 1.0 - openness
	_state.progress = clampf((float(_step_idx) + fraction) \
		/ float(_steps.size()), 0.0, 1.0)


func _phase_connects(phase: String) -> bool:
	var overrides: Dictionary = _plan.phase_edges.get(phase, {})
	var pairs: Array = _plan.phase_pairs.get(phase, [])
	if pairs.is_empty() or _scanned.is_empty():
		return false
	# The planner proves the generated base graph, but the event may start after a
	# legacy reality change. Re-prove the complete live scanned graph with this
	# phase's two site-edge overrides so two individually safe mutations cannot
	# combine into an isolated player/enemy/objective region.
	var roots: Array = _scanned.keys()
	var reached := _bfs_reachable(roots[0] as Vector2i, overrides)
	if reached.size() != _scanned.size():
		return false
	for pair in pairs:
		if not pair is Array or (pair as Array).size() != 2:
			return false
		var start: Vector2i = pair[0]
		var goal: Vector2i = pair[1]
		if not reached.has(start) or not reached.has(goal):
			return false
	return true


func _bfs_reachable(start: Vector2i, overrides: Dictionary) -> Dictionary:
	if not _scanned.has(start):
		return {}
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for dir in 4:
			var key := DescentTopology.edge_key(at, dir)
			var open: bool
			if overrides.has(key):
				open = bool(overrides[key])
			else:
				open = not _is_base_wall(at, dir)
			if not open:
				continue
			var other: Vector2i = at + WorldGen.DIRV[dir]
			if reached.has(other) or not _scanned.has(other):
				continue
			reached[other] = true
			queue.append(other)
	return reached


func _is_base_wall(cell: Vector2i, dir: int) -> bool:
	# graph_probe answers base passability: true means open.
	return not bool(_graph_probe.call(cell, dir))


func _reset() -> void:
	_plan = null
	_site = null
	_state = null
	_topology = null
	_scanned.clear()
	_steps.clear()
	_running = false
	_durable = false
	_persist_error = OK
	_publication_failed = false
