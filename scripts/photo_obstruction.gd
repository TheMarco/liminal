class_name PhotoObstruction
extends RefCounted
## Photographic obstructions reuse the same imported models as ordinary rooms.
## Each endpoint owns a complete bank on its own side of the threshold.

static var _templates: Dictionary = {}
static var _hulls: Dictionary = {}


static func build(fill: Node3D, barrier: StaticBody3D, centre: Vector3,
		dir: int, width: float, height: float, _seed: int, theme: int = 7) -> float:
	var spec := _spec(theme)
	var template := _template(spec.path, spec.get("selection", ""))
	if template.is_empty():
		return 0.0
	var rotation := Basis.from_euler(spec.rotation)
	var bounds: AABB = Transform3D(rotation, Vector3.ZERO) * template.bounds
	var fit := _fit(bounds.size, width, height - 0.12, spec.scale, theme == 7)
	if fit.is_empty():
		push_error("Existing obstruction model cannot fit opening: " + str(spec.path))
		return 0.0
	var count: int = fit.count
	var scale_value: float = fit.scale
	var rows := 1
	if theme == 7:
		rows = maxi(1, floori(minf(2.2, height - 0.12) / (bounds.size.y * scale_value)))
	var direction: Vector2i = WorldGen.DIRV[dir]
	var inward := Vector3(-direction.x, 0.0, -direction.y)
	# Preserve a right-handed coordinate system on all four walls. Assets face
	# inward (+local Z); the original scene's model geometry remains intact.
	var tangent := Vector3(inward.z, 0.0, -inward.x)
	var orientation := Basis(tangent, Vector3.UP, inward)
	var normalized := Transform3D(rotation.scaled(Vector3.ONE * scale_value),
		-Vector3(bounds.get_center().x, bounds.position.y, bounds.position.z) * scale_value)
	var depth := bounds.size.z * scale_value
	for column in range(count):
		for row in range(rows):
			var x := -width * 0.5 + width * (column + 0.5) / count
			var base := Transform3D(orientation, centre + tangent * x
				+ Vector3.UP * (row * bounds.size.y * scale_value))
			for part: Dictionary in template.parts:
				var transform: Transform3D = base * normalized * part.transform
				var instance := MeshInstance3D.new()
				instance.name = "ImportedObstruction_%d_%d_%s" % [column, row, part.name]
				instance.mesh = part.mesh
				instance.material_override = part.material
				for surface in range(part.surface_materials.size()):
					instance.set_surface_override_material(surface, part.surface_materials[surface])
				instance.transform = transform
				instance.set_meta("source_scene", spec.path)
				instance.set_meta("attributed_asset", spec.path)
				instance.set_meta("authored_model", spec.path)
				fill.add_child(instance)
				# Imported source meshes provide the collision hull, never a
				# doorway-sized primitive unrelated to the visible furniture.
				var shape: Shape3D = _hull(part.mesh)
				if shape != null:
					var collision := CollisionShape3D.new()
					collision.name = "ImportedObstructionCollision"
					collision.shape = shape
					collision.transform = transform
					collision.set_meta("source_scene", spec.path)
					barrier.add_child(collision)
	return depth


static func _fit(size: Vector3, width: float, max_height: float, natural_scale: float, stackable: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := INF
	for count in range(1, 7):
		var scale_value := width / (float(count) * size.x)
		if size.y * scale_value > max_height + 0.001 or size.z * scale_value > 2.5:
			continue
		var cost := absf(log(scale_value / natural_scale))
		if not stackable and size.y * scale_value < 0.85:
			cost += 5.0
		if cost < best_cost:
			best_cost = cost
			best = {"count": count, "scale": scale_value}
	return best


static func _spec(theme: int) -> Dictionary:
	var path := Chunk.LOCKERS_PATH
	var scale_value := Chunk.LOCKERS_SCALE
	var rotation := Vector3.ZERO
	var selection := ""
	match theme:
		0:
			path = Chunk.CASINO_SLOT_PATHS[0]
			scale_value = 1.0
		1, 2:
			path = Chunk.ANNEX_SHELVING_PATH
			scale_value = Chunk.ANNEX_SHELVING_SCALE
		4:
			path = Chunk.AIRPORT_TROLLEY_PATH
			scale_value = 1.0
			rotation.y = PI * 0.5
		5:
			path = Chunk.ASY_BED_PATH
			scale_value = Chunk.ASY_BED_SCALE
			rotation.y = PI * 0.5
		6:
			path = Chunk.GYM_LOCKER_PATH
			scale_value = Chunk.GYM_LOCKER_SCALE
			rotation.y = PI
		7:
			path = Chunk.OFFICE_BOXES_PATH
			selection = "290x290x290_1"
			scale_value = 1.6
		8:
			path = Chunk.PRISON_BUNK_PATH
			scale_value = 1.0
		9:
			path = Chunk.POOL_LOUNGE_CHAIR_PATH
			scale_value = Chunk.POOL_LOUNGE_CHAIR_SCALE
		10:
			path = Chunk.DATA_CENTER_RACK_PATH
			scale_value = 0.85
		11:
			path = Chunk.BLOOM_INCUBATOR_PATH
			scale_value = 1.0
	return {"path": path, "scale": scale_value, "rotation": rotation, "selection": selection}


static func _template(path: String, selection: String) -> Dictionary:
	var key := path + ":" + selection
	if _templates.has(key):
		return _templates[key]
	var scene := Chunk._prop_scene(path)
	if scene == null:
		push_error("Missing obstruction model: " + path)
		return {}
	var source := scene.instantiate()
	var parts: Array[Dictionary] = []
	_collect(source, Transform3D.IDENTITY, selection, parts)
	source.free()
	if parts.is_empty():
		push_error("Obstruction model has no selected meshes: " + key)
		return {}
	var bounds: AABB = parts[0].transform * parts[0].mesh.get_aabb()
	for part: Dictionary in parts:
		bounds = bounds.merge(part.transform * part.mesh.get_aabb())
	var result := {"parts": parts, "bounds": bounds}
	_templates[key] = result
	return result


static func _collect(node: Node, parent_transform: Transform3D,
		selection: String, parts: Array[Dictionary]) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D and node.mesh != null and (selection.is_empty() or selection in str(node.name)):
		var overrides: Array[Material] = []
		for surface in range(node.mesh.get_surface_count()):
			overrides.append(node.get_surface_override_material(surface))
		parts.append({"name": str(node.name), "mesh": node.mesh, "transform": transform,
			"material": node.material_override, "surface_materials": overrides})
	for child in node.get_children():
		_collect(child, transform, selection, parts)


static func _hull(mesh: Mesh) -> Shape3D:
	var key := mesh.get_instance_id()
	if not _hulls.has(key):
		_hulls[key] = mesh.create_convex_shape(true, true)
	return _hulls[key]


static func _subject(theme: int) -> String:
	match theme:
		0: return "Slot-machine cabinets"
		1, 2: return "Metal shelving units"
		4: return "Airport luggage trolleys"
		5: return "Hospital beds"
		6: return "School lockers"
		7: return "Stockroom boxes"
		8: return "Prison bunk beds"
		9: return "Pool lounge chairs"
		10: return "Server racks"
		11: return "Incubator cabinets"
	return "Storage furniture"


static func description(theme: int, documented: bool = false) -> String:
	if documented:
		return "A passage cleared by an earlier photograph. %s once blocked the way." % _subject(theme)
	return "%s block this passage, but the camera shows it clear." % _subject(theme)


static func caption(theme: int) -> String:
	return "THE BOXES WERE NOT IN THE PHOTOGRAPH" if theme == 7 else "THE OBSTRUCTION WAS NOT IN THE PHOTOGRAPH"


static func ghost(fill: Node3D) -> Node3D:
	var result := Node3D.new()
	result.name = "VanishedObstruction"
	_copy_meshes(fill, result)
	return result


static func _copy_meshes(source: Node, destination: Node3D) -> void:
	if source is MeshInstance3D:
		var original := source as MeshInstance3D
		if original.mesh != null:
			var copy := MeshInstance3D.new()
			copy.name = original.name
			copy.mesh = original.mesh
			copy.transform = original.global_transform
			copy.layers = 1
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for key in ["source_scene", "attributed_asset", "authored_model"]:
				if original.has_meta(key): copy.set_meta(key, original.get_meta(key))
			destination.add_child(copy)
	for child in source.get_children():
		_copy_meshes(child, destination)
