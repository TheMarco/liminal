class_name DescentMutationCoordinator
extends RefCounted
## Floor-scoped owner of blackout mutation preflight, staged commit and actor
## safety. Main supplies mode/persistence callbacks; ChunkManager supplies the
## off-tree atomic scene swap; DescentMutationTransaction owns resolver rollback.

signal committed(transaction: DescentMutationTransaction, reveal_at: Vector3,
	reveal: Dictionary)

const NO_VISIBLE_WITNESS := -1.0
## Category gaps exceed every route/distance preference in the pure selector:
## any visible architectural change wins; furniture is the explicit fallback.
const DOOR_WITNESS_BONUS := 10000.0
const FURNITURE_WITNESS_BONUS := 2000.0
const WITNESS_HIT_TOLERANCE := 1.35

var manager: ChunkManager
var run: DescentRun
var route: DescentRoute
var player: Player
var figures: ShadowFigures
var passers: PassingShadows
var mode_ready: Callable
var persist_committed: Callable
## Most recent proposal for diagnostics/audits; ownership remains here.
var last_transaction: DescentMutationTransaction
var _selected_witness_at := Vector3.INF
var _selected_witness := {}
var _selected_ghost: Node3D


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
	_clear_selected_ghost()
	var witness := visible_witness(proposal)
	if witness.is_empty():
		witness = nearest_witness(proposal)
	_selected_witness = witness.duplicate()
	_selected_witness_at = witness.get("position", Vector3.INF)
	var rebuild := rebuild_cells(proposal)
	var before_runtime := manager.runtime_state_for_cells(rebuild) \
		if manager != null else ChunkRuntimeState.new()
	var before_present := manager.runtime_object_descriptors(rebuild) \
		if manager != null else {}
	var mutation := WorldMutation.new(proposal, rebuild,
		before_runtime, before_present)
	var transaction := DescentMutationTransaction.new(mutation,
		assistance_requested, route, run._cell if run != null else Vector2i.ZERO,
		rebuild)
	last_transaction = transaction
	if not transaction.preflight(Callable(self, "can_commit")):
		return false
	return transaction.stage(manager,
		Callable(self, "_prepare_commit").bind(transaction),
		Callable(self, "_finish_commit").bind(transaction),
		Callable(self, "_stage_failed").bind(transaction))


## Runs while all replacement rooms are still off-tree and old collision is
## authoritative. No persistence or public commit signal is allowed here.
func _prepare_commit(transaction: DescentMutationTransaction) -> bool:
	if transaction == null or run == null or not run.blackout:
		if transaction != null:
			transaction.fail("blackout ended before staged commit")
		return false
	var topology := route.topology
	if not transaction.commit_topology(
			topology, route, run._cell, Callable(self, "can_commit")):
		return false
	# Topology now points at the future state, but the old scene is still live
	# until ChunkManager's atomic swap. Capture only the selected element's
	# visible meshes so a disappearing object can leave its exact ghost imprint.
	_selected_ghost = _snapshot_visuals(_selected_witness.get("nodes", []))
	transaction.mutation.reconcile_after(manager.staged_runtime_state(),
		manager.staged_object_descriptors())
	return true


## Called by ChunkManager only after the scene swap has passed its last
## fallible gate. This is the durable commit point.
func _finish_commit(transaction: DescentMutationTransaction) -> void:
	if transaction == null or not transaction.finalize(
			manager.runtime_state_for_cells(transaction.rebuild_cells),
			manager.runtime_object_descriptors(transaction.rebuild_cells)):
		return
	var topology := route.topology
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
	# Prefer an exact changed object still in view after the atomic swap. If the
	# player looked away during the darkness, retain the witnessed start point so
	# the restoration creak still comes from the real mutation site.
	var installed_witness := visible_witness(transaction.delta, true)
	if installed_witness.is_empty():
		installed_witness = nearest_witness(transaction.delta, true)
	var reveal_at: Vector3 = installed_witness.get(
		"position", _selected_witness_at)
	if reveal_at == Vector3.INF:
		reveal_at = nearest_reveal(transaction.rebuild_cells)
	var reveal := installed_witness.duplicate() \
		if not installed_witness.is_empty() else _selected_witness.duplicate()
	reveal["position"] = reveal_at
	if is_instance_valid(_selected_ghost):
		reveal["ghost"] = _selected_ghost
		_selected_ghost = null
	committed.emit(transaction, reveal_at, reveal)
	_selected_witness = {}
	print("blackout reality %d -> %d, route %d -> %d, cells=%d, assistance=%s" % [
		transaction.old_state, transaction.delta.to_state,
		transaction.distance_before, transaction.distance_after,
		transaction.rebuild_cells.size(), verified_help])


func _stage_failed(reason: String,
		transaction: DescentMutationTransaction) -> void:
	_clear_selected_ghost()
	if transaction == null:
		return
	# A scene-commit rejection can happen after topology preparation. Restore
	# the exact resolver/history and runtime snapshot while old nodes remain.
	if transaction.phase == DescentMutationTransaction.Phase.COMMITTING:
		transaction.rollback(route.topology, route, reason, manager)
	else:
		transaction.fail(reason)


func _clear_selected_ghost() -> void:
	if is_instance_valid(_selected_ghost):
		_selected_ghost.free()
	_selected_ghost = null


func _snapshot_visuals(value: Variant) -> Node3D:
	if not value is Array:
		return null
	var snapshot := Node3D.new()
	snapshot.name = "VanishedMutationGhost"
	var seen := {}
	for item in value as Array:
		if is_instance_valid(item) and item is Node:
			_copy_visual_meshes(item as Node, snapshot, seen)
	if snapshot.get_child_count() == 0:
		snapshot.free()
		return null
	return snapshot


func _copy_visual_meshes(node: Node, snapshot: Node3D,
		seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		if source.mesh != null and not seen.has(source.get_instance_id()):
			seen[source.get_instance_id()] = true
			var copy := MeshInstance3D.new()
			copy.mesh = source.mesh
			copy.transform = source.global_transform
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			snapshot.add_child(copy)
	for child in node.get_children():
		_copy_visual_meshes(child, snapshot, seen)


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


## Rank one precomputed reality by what the player can genuinely witness now.
## A changed doorway wins over furniture; within a category, nearer evidence
## wins. Negative means the blackout must wait rather than make an unseen swap.
func visibility_rank(proposal: TopologyDelta,
		require_line_of_sight := true) -> float:
	var witness := visible_witness(proposal, false, require_line_of_sight)
	if witness.is_empty():
		return NO_VISIBLE_WITNESS
	var distance := float(witness.get("distance", 0.0))
	return (DOOR_WITNESS_BONUS \
		if str(witness.get("kind", "")) == "door" \
		else FURNITURE_WITNESS_BONUS) - minf(distance, 80.0)


## Exact live witness for selection, commit cues and focused audits. Door
## samples come from the changed edge plane; furniture samples come from the
## real resident pivots owned by a changed prevalidated room arrangement.
func visible_witness(proposal: TopologyDelta,
		changed_furniture_only := false,
		require_line_of_sight := true) -> Dictionary:
	if proposal == null or proposal.is_empty() or player == null \
			or not is_instance_valid(player) or not player.is_inside_tree() \
			or player.cam == null or not player.cam.is_inside_tree():
		return {}
	var best_door := _visible_door_witness(proposal, require_line_of_sight)
	if not best_door.is_empty():
		return best_door
	var best := {}
	var best_distance := INF
	for room in proposal.rooms:
		var chunk := manager.chunk_at(room) if manager != null else null
		if chunk == null:
			continue
		var target_variant := route.topology.furniture_variant_for_state(
			room, proposal.to_state) if route != null \
				and route.topology != null else 0
		for point in chunk.furniture_witness_points_for_variant(
				target_variant, changed_furniture_only):
			if not _point_visible(point, require_line_of_sight):
				continue
			var distance := player.cam.global_position.distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = {
					"kind": "furniture",
					"position": point,
					"distance": distance,
					"room": room,
					"nodes": [chunk.furniture_witness_node_near(
						point, changed_furniture_only)],
				}
	return best


func _visible_door_witness(proposal: TopologyDelta,
		require_line_of_sight: bool) -> Dictionary:
	var best := {}
	var best_distance := INF
	for edge in proposal.edges:
		var edge_cell: Vector2i = edge.get("cell", Vector2i.ZERO)
		var other_cell: Vector2i = edge.get("other", edge_cell)
		if manager == null or (manager.chunk_at(edge_cell) == null \
				and manager.chunk_at(other_cell) == null):
			continue
		var centre := _edge_centre(edge)
		centre.y = Chunk.cell_floor_h(route.world_seed, edge_cell, route.theme) \
			if route != null else 0.0
		for height in [0.55, 1.15, 1.85]:
			var point := centre + Vector3(0.0, height, 0.0)
			if not _point_visible(point, require_line_of_sight):
				continue
			var distance := player.cam.global_position.distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = {
					"kind": "door",
					"position": point,
					"distance": distance,
					"edge": edge,
					"edge_center": centre,
					"nodes": _edge_visual_nodes(edge),
				}
	return best


func _edge_visual_nodes(edge: Dictionary) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if manager == null:
		return out
	var edge_cell: Vector2i = edge.get("cell", Vector2i.ZERO)
	var other_cell: Vector2i = edge.get("other", edge_cell)
	var dir := int(edge.get("dir", 0))
	var near := manager.chunk_at(edge_cell)
	if near != null:
		out.append_array(near.mutation_edge_visuals(dir))
	var far := manager.chunk_at(other_cell)
	if far != null:
		out.append_array(far.mutation_edge_visuals(dir ^ 1))
	return out


## Exact-element fallback when the player turned after selection or an audit
## drives the transaction without a rendered camera pose. Unlike
## `nearest_reveal`, this always retains the semantic edge or furnishing node.
func nearest_witness(proposal: TopologyDelta,
		changed_furniture_only := false) -> Dictionary:
	if proposal == null or proposal.is_empty() or manager == null:
		return {}
	var best := {}
	var best_distance := INF
	for edge in proposal.edges:
		var edge_cell: Vector2i = edge.get("cell", Vector2i.ZERO)
		var other_cell: Vector2i = edge.get("other", edge_cell)
		if manager.chunk_at(edge_cell) == null \
				and manager.chunk_at(other_cell) == null:
			continue
		var centre := _edge_centre(edge)
		centre.y = Chunk.cell_floor_h(route.world_seed, edge_cell, route.theme) \
			if route != null else 0.0
		var point := centre + Vector3(0.0, 1.15, 0.0)
		var distance := player.global_position.distance_to(point) \
			if player != null else 0.0
		if distance < best_distance:
			best_distance = distance
			best = {
				"kind": "door",
				"position": point,
				"distance": distance,
				"edge": edge,
				"edge_center": centre,
				"nodes": _edge_visual_nodes(edge),
			}
	# Architectural changes retain priority just as they do in visible ranking.
	if not best.is_empty():
		return best
	for room in proposal.rooms:
		var chunk := manager.chunk_at(room)
		if chunk == null:
			continue
		var target_variant := route.topology.furniture_variant_for_state(
			room, proposal.to_state) if route != null \
				and route.topology != null else 0
		for point in chunk.furniture_witness_points_for_variant(
				target_variant, changed_furniture_only):
			var distance := player.global_position.distance_to(point) \
				if player != null else 0.0
			if distance < best_distance:
				best_distance = distance
				best = {
					"kind": "furniture",
					"position": point,
					"distance": distance,
					"room": room,
					"nodes": [chunk.furniture_witness_node_near(
						point, changed_furniture_only)],
				}
	return best


func _edge_centre(edge: Dictionary) -> Vector3:
	var at: Vector2i = edge.get("cell", Vector2i.ZERO)
	var dir := int(edge.get("dir", 0))
	var half := WorldGen.CELL_SIZE * 0.5
	match dir:
		0:
			return Vector3((float(at.x) + 1.0) * WorldGen.CELL_SIZE,
				0.0, float(at.y) * WorldGen.CELL_SIZE + half)
		1:
			return Vector3(float(at.x) * WorldGen.CELL_SIZE,
				0.0, float(at.y) * WorldGen.CELL_SIZE + half)
		2:
			return Vector3(float(at.x) * WorldGen.CELL_SIZE + half,
				0.0, (float(at.y) + 1.0) * WorldGen.CELL_SIZE)
		_:
			return Vector3(float(at.x) * WorldGen.CELL_SIZE + half,
				0.0, float(at.y) * WorldGen.CELL_SIZE)


func _point_visible(point: Vector3, require_line_of_sight := true) -> bool:
	var cam := player.cam
	if not cam.is_position_in_frustum(point):
		return false
	if not require_line_of_sight:
		return true
	var query := PhysicsRayQueryParameters3D.create(
		cam.global_position, point)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() \
		or (hit["position"] as Vector3).distance_to(point) \
			<= WITNESS_HIT_TOLERANCE


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
