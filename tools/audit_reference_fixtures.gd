extends SceneTree
## Small runtime smoke audit for the replacement fixtures from the reference pass.
## This intentionally checks integration markers, transforms and coarse envelopes;
## authored mesh detail is covered by audit_authored_hero_meshes.py.

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("REFERENCE_FIXTURE_AUDIT: " + message)

func _init() -> void:
	call_deferred("run")

func _find_furnishing(chunk: Node, kind: String) -> Node3D:
	for node in _reversed_children(chunk):
		if node is Node3D and String(node.get_meta("atomic_furnishing", "")) == kind:
			return node
	return null

func _mesh_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.get_aabb()
		for corner in [box.position, box.position + Vector3(box.size.x, 0, 0),
			box.position + Vector3(0, box.size.y, 0), box.position + Vector3(0, 0, box.size.z),
			box.position + Vector3(box.size.x, box.size.y, 0),
			box.position + Vector3(box.size.x, 0, box.size.z),
			box.position + Vector3(0, box.size.y, box.size.z), box.end]:
			var transform := mesh.transform
			var parent := mesh.get_parent()
			while parent != root:
				if parent is Node3D: transform = parent.transform * transform
				parent = parent.get_parent()
			var point: Vector3 = transform * corner
			check(point.is_finite(), "%s has non-finite vertex" % root.name)
			if not found:
				bounds = AABB(point, Vector3.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	return bounds

func _reversed_children(node: Node) -> Array[Node]:
	var children := node.get_children()
	children.reverse()
	return children

func _begin(theme: int) -> Chunk:
	return Chunk.new(WorldGen.level_seed(9137, theme), Vector2i.ZERO, theme)

func _finish(chunk: Node, kind: String, label: String, max_size: Vector3 = Vector3.ZERO) -> void:
	var pivot := _find_furnishing(chunk, kind)
	check(pivot != null, "%s missing atomic furnishing marker" % label)
	if pivot == null:
		chunk.free()
		return
	var group := int(pivot.get_meta("furnishing_group", -1))
	check(group >= 0, "%s missing collider group" % label)
	var collider_count := 0
	for node in chunk.body.get_children():
		if node is CollisionShape3D and int(node.get_meta("furnishing_group", -1)) == group:
			collider_count += 1
	check(collider_count > 0, "%s has no bound colliders" % label)
	var bounds := _mesh_bounds(pivot)
	check(bounds.size.length() > 0.1, "%s missing model geometry" % label)
	check(bounds.size.is_finite(), "%s has invalid bounds" % label)
	if max_size != Vector3.ZERO:
		check(bounds.size.x <= max_size.x and bounds.size.y <= max_size.y and bounds.size.z <= max_size.z,
			"%s exceeds envelope %s (got %s)" % [label, max_size, bounds.size])
	chunk.free()

func run() -> void:
	var chunk: Chunk
	# AIR_GATE shares the airport builder and exposes the authored flight helper.
	chunk = _begin(4)
	chunk._level_builder._escalator_flight(Vector3(6, 0, 6), 0.0, 0.0)
	_finish(chunk, "airport_escalator", "airport escalator", Vector3(1.5, 3.4, 6.0))

	for dir in 4:
		chunk = _begin(6)
		chunk._level_builder._sch_servery(dir)
		_finish(chunk, "school_servery", "school servery dir %d" % dir, Vector3(6.0, 2.2, 2.0))
		chunk = _begin(6)
		chunk._level_builder._sch_case(dir, WorldGen.CELL_SIZE - Chunk.T / 2.0 if dir == 0 or dir == 2 else Chunk.T / 2.0)
		_finish(chunk, "school_trophy_case", "school trophy case dir %d" % dir, Vector3(3.0, 2.8, 0.8))

	for yaw in [0.0, PI / 2.0]:
		chunk = _begin(6)
		chunk._level_builder._sch_cupboard(Vector3(6, 0, 6), yaw, 71)
		_finish(chunk, "school_cupboard", "school cupboard", Vector3(1.2, 2.2, 0.7))
		chunk = _begin(6)
		chunk._level_builder._sch_caf_table(Vector3(6, 0, 6), yaw, 71)
		_finish(chunk, "school_cafeteria_table", "cafeteria table", Vector3(3.2, 1.0, 1.9))
		chunk = _begin(6)
		chunk._level_builder._sch_bleachers(Vector3(6, 0, 6), yaw, 8.0)
		_finish(chunk, "school_bleachers", "bleachers", Vector3(8.2, 2.3, 3.4))

	chunk = _begin(8)
	chunk._level_builder._prison_shower_station(0, 6.0)
	_finish(chunk, "prison_shower_fixture", "prison shower fixture", Vector3(0.6, 2.0, 0.5))
	chunk = _begin(8)
	chunk._level_builder._prison_mess_table(Vector3(6, 0, 6), 0.0)
	_finish(chunk, "prison_mess_table", "prison mess table", Vector3(2.1, 1.0, 2.1))

	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("REFERENCE_FIXTURE_AUDIT: failures=%d" % failures)
	quit(1 if failures else 0)
