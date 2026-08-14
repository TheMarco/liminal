class_name DescentMutationTransaction
extends RefCounted
## One explicit blackout world-mutation transaction from selection through
## topology preparation, atomic scene commit and durable completion.
##
## ChunkManager owns off-tree scene staging, while this object owns the
## topology-side state machine and rollback contract. Main supplies live-scene
## validation and performs post-commit wiring/persistence only after this
## transaction reports COMMITTED.

enum Phase {
	CREATED,
	PREFLIGHTED,
	STAGING,
	COMMITTING,
	COMMITTED,
	ROLLED_BACK,
	FAILED,
}

var mutation: WorldMutation
var delta: TopologyDelta:
	get:
		return mutation.topology if mutation != null else null
var assistance_requested := false
var origin_cell := Vector2i.ZERO
var rebuild_cells: Array[Vector2i] = []
var distance_before := -1
var distance_after := -1
var old_state := -1
var old_history: Array[int] = []
var phase := Phase.CREATED
var failure_reason := ""


func _init(p_mutation: Variant, p_assistance: bool,
		route: DescentRoute, from: Vector2i,
		p_rebuild_cells: Array[Vector2i]) -> void:
	if p_mutation is WorldMutation:
		mutation = p_mutation as WorldMutation
	elif p_mutation is TopologyDelta:
		# Compatibility for focused transaction tests. Production always passes
		# a complete WorldMutation from the coordinator.
		mutation = WorldMutation.new(p_mutation as TopologyDelta,
			p_rebuild_cells)
	else:
		mutation = WorldMutation.new()
	assistance_requested = p_assistance
	origin_cell = from
	rebuild_cells = p_rebuild_cells.duplicate()
	if route != null and route.topology != null:
		distance_before = route.distance_from_target(from)
		old_state = route.topology.current_state_id()
		old_history = route.topology.state_history()


func preflight(validator: Callable) -> bool:
	if phase != Phase.CREATED:
		return fail("preflight called out of order")
	if delta == null or delta.is_empty():
		return fail("empty topology delta")
	if rebuild_cells.is_empty():
		return fail("topology delta has no rebuild cells")
	if not validator.is_valid() or not bool(validator.call(delta)):
		return fail("live preflight rejected mutation")
	phase = Phase.PREFLIGHTED
	return true


func stage(manager: ChunkManager, when_ready: Callable,
		when_committed := Callable(), when_failed := Callable()) -> bool:
	if phase != Phase.PREFLIGHTED:
		return fail("staging called before preflight")
	if manager == null or not when_ready.is_valid():
		return fail("staging dependencies unavailable")
	phase = Phase.STAGING
	var failed := when_failed if when_failed.is_valid() \
		else Callable(self, "fail")
	if not manager.stage_rebuild_cells(rebuild_cells, delta.to_state,
			when_ready, failed, when_committed):
		return fail("chunk staging could not start")
	return true


## Commit the resolver only after all replacement rooms exist off-tree. The
## manager keeps old collision installed until this returns true. Any route
## failure restores the exact prior state/history before staged rooms are
## discarded, so renderer and collision never observe a partial transaction.
func commit_topology(topology: DescentTopology, route: DescentRoute,
		commit_cell: Vector2i, validator: Callable) -> bool:
	if phase != Phase.STAGING:
		return fail("commit called before staging completed")
	if topology == null or route == null:
		return fail("commit topology unavailable")
	if not validator.is_valid() or not bool(validator.call(delta)):
		return fail("live commit preflight rejected mutation")
	if topology.current_state_id() != old_state:
		return fail("topology changed during staging")
	phase = Phase.COMMITTING
	if not topology.transition_to(delta.to_state):
		return fail("topology refused selected state")
	route.refresh_topology()
	distance_after = route.distance_from_target(commit_cell)
	if distance_after < 0:
		rollback(topology, route, "committed state disconnected live route")
		return false
	# Scene nodes have not swapped yet. The manager will call finalize only
	# after its last fallible gate and atomic replacement pass succeed.
	phase = Phase.COMMITTING
	return true


func finalize(after_runtime: ChunkRuntimeState,
		after_present: Dictionary) -> bool:
	if phase != Phase.COMMITTING:
		return fail("scene committed before topology preparation")
	mutation.reconcile_after(after_runtime, after_present)
	phase = Phase.COMMITTED
	return true


func rollback(topology: DescentTopology, route: DescentRoute,
		reason: String, manager: ChunkManager = null) -> void:
	if topology != null:
		topology.restore_state(old_state, old_history)
	if route != null:
		route.refresh_topology()
	if manager != null and mutation != null:
		manager.restore_runtime_state_for_cells(
			mutation.before_runtime, rebuild_cells)
	failure_reason = reason
	phase = Phase.ROLLED_BACK


func fail(reason: String) -> bool:
	failure_reason = reason
	phase = Phase.FAILED
	return false


func committed() -> bool:
	return phase == Phase.COMMITTED
