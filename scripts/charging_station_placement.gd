class_name ChargingStationPlacement
extends RefCounted
## Build-time geometry queries work before streamed chunks enter the tree.
## Include visual dressing, nested solids and water, not just the main body.
var obstacles: Array[AABB] = []
var water: Array[AABB] = []
var supports: Array[AABB] = []

func _init(chunk: Node3D) -> void:
	for child in chunk.get_children():
		_collect(child, Transform3D.IDENTITY)

func _collect(node: Node, parent: Transform3D, shown := true) -> void:
	if node.has_meta("charging_station") or node is Area3D:
		return
	var xf := parent
	if node is Node3D:
		shown = shown and node.visible
		xf = parent * node.transform
	# Ritual furniture is assembled in _ready(), after off-tree placement.
	if node is VhsRitual:
		obstacles.append(xf * AABB(Vector3(-1.1, 0.05, -0.45),
			Vector3(2.2, 1.9, 0.95)))
		return
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = xf * node.mesh.get_aabb()
		if node.has_meta("pool_water_surface") or node.has_meta("pool_jacuzzi_water"):
			water.append(bounds)
		elif shown and not node.get_meta("surface_wear_patch", false):
			# Stains/repaint are zero-thickness visual overlays, offset a few
			# millimetres from their supporting wall to prevent z-fighting.
			# They must not reject a cabinet seated against that same wall.
			obstacles.append(bounds)
	if node is CollisionShape3D and node.shape != null and not node.disabled:
		var bounds: AABB = xf * node.shape.get_debug_mesh().get_aabb()
		obstacles.append(bounds)
		if node.shape is BoxShape3D:
			supports.append(bounds)
	for child in node.get_children():
		_collect(child, xf, shown)

func clear(at: Vector3, yaw: float, pool: bool, doors: Array[Rect2],
		cabinet_bounds := AABB(Vector3(-0.43, 0.06, -0.36), Vector3(0.86, 1.78, 0.72)),
		approach_bounds := AABB(Vector3(-0.43, 0.06, 0.36), Vector3(0.86, 1.78, 0.90)),
		cell_inset := 0.30) -> bool:
	var xf := Transform3D(Basis(Vector3.UP, yaw), at)
	# Cabinet including trim, plus a standing space facing its +Z front.
	var cabinet := xf * cabinet_bounds
	var approach := xf * approach_bounds
	for volume in [cabinet, approach]:
		if volume.position.x < cell_inset or volume.end.x > WorldGen.CELL_SIZE - cell_inset \
				or volume.position.z < cell_inset or volume.end.z > WorldGen.CELL_SIZE - cell_inset:
			return false
		for obstacle in obstacles:
			if volume.intersects(obstacle):
				return false
		var footprint := Rect2(Vector2(volume.position.x, volume.position.z),
			Vector2(volume.size.x, volume.size.z))
		for wet in water:
			if footprint.intersects(Rect2(Vector2(wet.position.x, wet.position.z),
					Vector2(wet.size.x, wet.size.z)).grow(0.18)):
				return false
		if pool:
			# Prove there is a dry slab below the whole unit AND its user.
			# A nominally dry room can still contain an inset hot tub.
			for x in [volume.position.x, volume.get_center().x, volume.end.x]:
				for z in [volume.position.z, volume.get_center().z, volume.end.z]:
					var supported := false
					for slab in supports:
						if absf(slab.end.y - at.y) < 0.025 \
								and x >= slab.position.x and x <= slab.end.x \
								and z >= slab.position.z and z <= slab.end.z:
							supported = true
							break
					if not supported:
						return false
	# Keep the cabinet itself out of door and lift circulation.
	var footprint := Rect2(Vector2(cabinet.position.x, cabinet.position.z),
		Vector2(cabinet.size.x, cabinet.size.z))
	for door in doors:
		if footprint.intersects(door):
			return false
	return true
