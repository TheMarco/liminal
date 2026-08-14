extends SceneTree
## End-to-end proof for the generalized world-mutation contract. Finds real
## generated realities (not fixtures) in which a swing door appears/disappears
## and a stable furniture group changes transform, then proves both survive a
## return to their earlier reality.

const THEMES := [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]
const BASE_SEED := 405195947

var failures: Array[String] = []
var door_proven := false
var furniture_proven := false


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	for floor_idx in THEMES.size():
		if door_proven and furniture_proven:
			break
		var theme: int = THEMES[floor_idx]
		var seed := WorldGen.level_seed(BASE_SEED, theme)
		var route := DescentRoute.build(seed, theme, floor_idx)
		var topology := DescentTopology.new(seed, theme)
		route.set_topology(topology)
		topology.plan_floor(route)
		for state_id in range(1, topology.state_count()):
			if door_proven and furniture_proven:
				break
			var delta := topology.state_delta(0, state_id)
			if delta == null or delta.is_empty():
				continue
			var cells := _rebuild_cells(route, delta)
			var before := _build_state(route, topology, 0, cells)
			var after := _build_state(route, topology, state_id, cells)
			var mutation := WorldMutation.new(delta, cells,
				before["runtime"] as ChunkRuntimeState,
				before["descriptors"] as Dictionary)
			mutation.reconcile_after(after["runtime"] as ChunkRuntimeState,
				after["descriptors"] as Dictionary)
			_expect(mutation.id == mutation.copy().id,
				"WorldMutation identity changed when copied")
			_expect(int(before["identity_errors"]) == 0 \
				and int(after["identity_errors"]) == 0,
				"generated reality contained duplicate runtime object ids")
			if not door_proven:
				door_proven = _prove_door_return(
					route, topology, state_id, mutation)
			if not furniture_proven and not delta.rooms.is_empty():
				furniture_proven = _prove_furniture_return(
					route, topology, state_id, cells,
					before["furniture_transforms"] as Dictionary,
					after["furniture_transforms"] as Dictionary)
			_free_chunks(before["chunks"] as Array)
			_free_chunks(after["chunks"] as Array)

	_expect(door_proven,
		"no generated reality proved a disappearing/reappearing swing door")
	_expect(furniture_proven,
		"no generated reality proved a moved-and-restored furniture group")
	for failure in failures:
		print("  FAIL " + failure)
	Chunk.finish_prop_preloads()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if failures.is_empty():
		print("world mutation contract audit: PASS — door and furniture realities are stable, persistent and reversible")
		quit()
	else:
		quit(1)


func _build_state(route: DescentRoute, topology: DescentTopology,
		state_id: int, cells: Array[Vector2i]) -> Dictionary:
	var chunks: Array[Chunk] = []
	var descriptors := {}
	var runtime := ChunkRuntimeState.new()
	var furniture_transforms := {}
	var identity_errors := 0
	for cell in cells:
		var spec := ChunkBuildSpec.new()
		spec.descent = true
		spec.topology = topology
		spec.topology_state_override = state_id
		spec.furniture_variant_override = \
			topology.furniture_variant_for_state(
				WorldGen.annex_room_id(route.world_seed, cell) \
					if route.theme == 2 else \
					WorldGen.room_id(route.world_seed, cell), state_id)
		var chunk := Chunk.new(route.world_seed, cell, route.theme, spec)
		chunks.append(chunk)
		descriptors.merge(chunk.runtime_object_descriptors(), true)
		runtime.merge(chunk.capture_runtime_state())
		furniture_transforms.merge(
			chunk.runtime_object_transforms("furniture"), true)
		identity_errors += chunk.runtime_identity_violations()
	return {
		"chunks": chunks,
		"descriptors": descriptors,
		"runtime": runtime,
		"furniture_transforms": furniture_transforms,
		"identity_errors": identity_errors,
	}


func _prove_door_return(route: DescentRoute, topology: DescentTopology,
		state_id: int, mutation: WorldMutation) -> bool:
	for object_delta in mutation.object_deltas:
		if object_delta.kind != "swing_door" \
				or object_delta.before_present == object_delta.after_present:
			continue
		var present_state := 0 if object_delta.before_present else state_id
		var key := object_delta.key
		var cell := _cell_from_key(key)
		var canonical := mutation.before_runtime.copy() \
			if object_delta.before_present else mutation.after_runtime.copy()
		# The door is opened, then its reality is absent. Keeping this record in
		# the floor registry is what lets a later mutation-back restore it.
		canonical.put(key, "swing_door", {"open": true, "angle": 1.11})
		var returned := _build_state(route, topology, present_state, [cell])
		var returned_chunks := returned["chunks"] as Array
		if returned_chunks.is_empty():
			return false
		var chunk := returned_chunks[0] as Chunk
		chunk.restore_runtime_state(canonical)
		var restored := chunk.capture_runtime_state().payload_for(key)
		var valid := bool(restored.get("open", false)) \
			and is_equal_approx(float(restored.get("angle", 0.0)), 1.11)
		_free_chunks(returned_chunks)
		_expect(valid,
			"swing door state was lost while its generated reality was absent")
		return valid
	return false


func _prove_furniture_return(route: DescentRoute,
		topology: DescentTopology, state_id: int, cells: Array[Vector2i],
		before: Dictionary, after: Dictionary) -> bool:
	for key in before:
		if not after.has(key):
			continue
		var before_transform := before[key] as Transform3D
		var after_transform := after[key] as Transform3D
		if before_transform.is_equal_approx(after_transform):
			continue
		var cell := _cell_from_key(str(key))
		var returned := _build_state(route, topology, 0, [cell])
		var returned_transform: Variant = \
			(returned["furniture_transforms"] as Dictionary).get(key)
		var restored := returned_transform is Transform3D \
			and (returned_transform as Transform3D).is_equal_approx(
				before_transform)
		_free_chunks(returned["chunks"] as Array)
		_expect(restored,
			"stable furniture group did not return to its exact base transform")
		return restored
	return false


func _rebuild_cells(route: DescentRoute,
		delta: TopologyDelta) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for edge in delta.edges:
		for endpoint in [edge["cell"], edge["other"]]:
			for member in WorldGen.owning_room_members(
					route.world_seed, endpoint, route.theme):
				if not out.has(member):
					out.append(member)
	for room in delta.rooms:
		for member in WorldGen.owning_room_members(
				route.world_seed, room, route.theme):
			if not out.has(member):
				out.append(member)
	return out


func _cell_from_key(key: String) -> Vector2i:
	var head := key.get_slice("/", 0).trim_prefix("cell:")
	return Vector2i(int(head.get_slice(":", 0)), int(head.get_slice(":", 1)))


func _free_chunks(chunks: Array) -> void:
	for chunk in chunks:
		if is_instance_valid(chunk):
			(chunk as Chunk).free()
