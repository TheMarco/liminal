extends RefCounted
## Only fixed Airport architecture uses these nine render layers. Props, actors
## and photographic effects keep their own layers. The pattern repeats every
## three cells in each direction, beyond the reach of the fixtures we mask.

const CELL_SIZE := WorldGen.CELL_SIZE
const SOLID_EDGE := &"airport_solid_edge"


static func cell_layer(cell: Vector2i) -> int:
	return 1 << (2 + posmod(cell.x, 3) + 3 * posmod(cell.y, 3))


static func wall_heights(room: Node3D, candidates: Array[MeshInstance3D]) -> PackedFloat32Array:
	var heights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for wall in candidates:
		if not is_instance_valid(wall) or wall.get_parent() != room or not wall.visible \
				or wall.is_queued_for_deletion() or not wall.has_meta(SOLID_EDGE):
			continue
		var direction := int(wall.get_meta(SOLID_EDGE))
		var bounds := wall.transform * wall.get_aabb()
		var along := 2 if direction < 2 else 0
		if bounds.position.y <= 0.001 and bounds.position[along] <= 0.001 \
				and bounds.end[along] >= CELL_SIZE - 0.001:
			heights[direction] = bounds.end.y
	return heights


static func restrict_ceiling_fixture(light: AreaLight3D, room: Node3D, cell: Vector2i,
		walls: PackedFloat32Array) -> void:
	var placement := light.transform
	var parent := light.get_parent()
	while parent != room and parent is Node3D:
		placement = parent.transform * placement
		parent = parent.get_parent()
	if parent != room or not placement.basis.z.is_equal_approx(Vector3.UP):
		return
	var centre := Vector2(placement.origin.x, placement.origin.z)
	var emitter_radius := 0.5 * light.area_size.length()
	var reach := light.area_range + emitter_radius + 0.001
	var margin := minf(minf(centre.x, centre.y), CELL_SIZE - maxf(centre.x, centre.y))
	# Keep the full mask when an emitter straddles the boundary or could
	# reach a second cell sharing a neighbour's bit.
	if margin <= emitter_radius or reach >= margin + CELL_SIZE:
		return
	var mask := light.light_cull_mask
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var offset := Vector2i(dx, dz)
			var corner := Vector2(offset) * CELL_SIZE
			var nearest := centre.clamp(corner, corner + Vector2.ONE * CELL_SIZE)
			# A straight ray into a diagonal neighbour can leave by either
			# boundary. Both must be solid to the full emitting height.
			var blocked_x := dx == 0 or walls[0 if dx > 0 else 1] >= placement.origin.y + 0.001
			var blocked_z := dz == 0 or walls[2 if dz > 0 else 3] >= placement.origin.y + 0.001
			if centre.distance_squared_to(nearest) > reach * reach or (blocked_x and blocked_z):
				mask &= ~cell_layer(cell + offset)
	if mask != light.light_cull_mask:
		light.light_cull_mask = mask
