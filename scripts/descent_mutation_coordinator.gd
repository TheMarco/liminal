class_name DescentMutationCoordinator
extends RefCounted
## Floor-scoped owner of blackout mutation preflight, staged commit and actor
## safety. Main supplies mode/persistence callbacks; ChunkManager supplies the
## off-tree atomic scene swap; DescentMutationTransaction owns resolver rollback.

signal committed(transaction: DescentMutationTransaction, reveal_at: Vector3)

var manager: ChunkManager
var run: DescentRun
var route: DescentRoute
var player: Player
var figures: ShadowFigures
var passers: PassingShadows
var mode_ready: Callable
var persist_committed: Callable


func configure(p_manager: ChunkManager, p_run: DescentRun,
		p_route: DescentRoute, p_player: Player, p_figures: ShadowFigures,
		p_passers: PassingShadows, p_mode_ready: Callable,
		p_persist_committed: Callable) -> void:
	manager = p_manager
	run = p_run
	route = p_route
	player = p_player
	figures = p_figures
	passers = p_passers
	mode_ready = p_mode_ready
	persist_committed = p_persist_committed


func begin(proposal: TopologyDelta, assistance_requested: bool) -> bool:
	var rebuild := rebuild_cells(proposal)
	var transaction := DescentMutationTransaction.new(proposal,
		assistance_requested, route, run._cell if run != null else Vector2i.ZERO,
		rebuild)
	if not transaction.preflight(Callable(self, "can_commit")):
		return false
	return transaction.stage(manager,
		Callable(self, "_commit").bind(transaction))


func _commit(transaction: DescentMutationTransaction) -> bool:
	if transaction == null or run == null or not run.blackout:
		if transaction != null:
			transaction.fail("blackout ended before staged commit")
		return false
	var topology := route.topology
	if not transaction.commit_topology(
			topology, route, run._cell, Callable(self, "can_commit")):
		return false
	manager.descent_topology = topology
	if figures != null:
		figures.topology = topology
	if passers != null:
		passers.topology = topology
	var verified_help := transaction.assistance_requested \
		and transaction.distance_before >= 0 \
		and transaction.distance_after >= 0 \
		and transaction.distance_after < transaction.distance_before
	if verified_help:
		run.mark_helpful_mutation_created()
	if persist_committed.is_valid():
		persist_committed.call(topology)
	var reveal_at := nearest_reveal(transaction.rebuild_cells)
	committed.emit(transaction, reveal_at)
	print("blackout reality %d -> %d, route %d -> %d, cells=%d, assistance=%s" % [
		transaction.old_state, transaction.delta.to_state,
		transaction.distance_before, transaction.distance_after,
		transaction.rebuild_cells.size(), verified_help])
	return true


## Generated topology proves global navigability. This live preflight prevents
## materializing geometry around actors, interactions, or moving door leaves.
func can_commit(proposal: TopologyDelta) -> bool:
	if not mode_ready.is_valid() or not bool(mode_ready.call()) \
			or manager == null or run == null or route == null \
			or route.topology == null or proposal == null or proposal.is_empty() \
			or run.watching:
		return false
	var next_state := proposal.to_state
	if next_state < 0 or next_state >= route.topology.state_count() \
			or next_state == route.topology.current_state_id():
		return false
	var cells := rebuild_cells(proposal)
	if cells.is_empty() or player == null or not player.is_inside_tree():
		return false
	var has_resident_change := false
	for at in cells:
		if manager.chunk_at(at) != null:
			has_resident_change = true
			break
	if not has_resident_change:
		return false
	if player.is_charging() or _point_near(
			player.global_position, cells, 1.35):
		return false
	if figures != null:
		for figure in figures.active_figures():
			if _point_near(figure.global_position, cells,
					ShadowFigures.FIGURE_CLEAR_RADIUS):
				return false
	if passers != null:
		var passer := passers.active_apparition()
		if passer != null and _point_near(
				passer.global_position, cells, 0.8):
			return false
	for at in cells:
		var chunk := manager.chunk_at(at)
		if chunk == null:
			continue
		if not chunk.find_children("*", "ShadowFigure", true, false).is_empty():
			return false
		for node in chunk.find_children("*", "Node3D", true, false):
			if bool(node.get_meta("moving", false)):
				return false
	return true


func rebuild_cells(proposal: TopologyDelta) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if proposal == null or route == null:
		return out
	for edge in proposal.edges:
		for at in _endpoint_rooms(edge["cell"], edge["other"]):
			if not out.has(at):
				out.append(at)
	for room in proposal.rooms:
		for at in _endpoint_rooms(room, room):
			if not out.has(at):
				out.append(at)
	return out


func _endpoint_rooms(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for endpoint in [a, b]:
		for member in WorldGen.owning_room_members(
				route.world_seed, endpoint, route.theme):
			if not out.has(member):
				out.append(member)
	return out


func nearest_reveal(cells: Array[Vector2i]) -> Vector3:
	if player == null or manager == null:
		return Vector3.INF
	var nearest := Vector3.INF
	var nearest_distance := INF
	for at in cells:
		if manager.chunk_at(at) == null:
			continue
		var point := Vector3((float(at.x) + 0.5) * WorldGen.CELL_SIZE,
			player.global_position.y,
			(float(at.y) + 0.5) * WorldGen.CELL_SIZE)
		var distance := point.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = point
	return nearest


func _point_near(point: Vector3, cells: Array[Vector2i],
		padding: float) -> bool:
	var flat := Vector2(point.x, point.z)
	for at in cells:
		var bounds := Rect2(
			Vector2(float(at.x) * WorldGen.CELL_SIZE - padding,
				float(at.y) * WorldGen.CELL_SIZE - padding),
			Vector2.ONE * (WorldGen.CELL_SIZE + padding * 2.0))
		if bounds.has_point(flat):
			return true
	return false
