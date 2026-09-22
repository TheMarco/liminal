extends RefCounted
## Conservative native-layout selection. No generated architecture is replaced.
const WIDTHS := {0: 2.85, 1: 3.55, 5: 3.95, 6: 3.95,
	7: 11.85, 8: 11.85, 10: 3.08, 11: 3.62}

static func at(seed_value: int, cell: Vector2i, theme: int) -> Dictionary:
	if theme == 4:
		# Airport transit corridors contain moving walkways. Do not warp their
		# decks/rails independently of the drive Areas: use ordinary halls only.
		if WorldGen.cell_style(seed_value, cell, theme) != WorldGen.AIR_HALL: return {}
		if WorldGen.room_size(seed_value, WorldGen.room_id(seed_value, cell)) != 1: return {}
		return {"cell": cell, "axis": 1, "width": 11.7,
			"height": Chunk.cell_ceil_h(seed_value, cell, theme)-Chunk.cell_floor_h(seed_value, cell, theme)}
	if theme == 9:
		# Pool channels are wet. Use a native, single-cell dry alcove instead;
		# never alter a water surface or the swimming-height contract.
		var style := WorldGen.cell_style(seed_value, cell, theme)
		var room_root := WorldGen.room_id(seed_value, cell)
		if style != WorldGen.POOL_ALCOVE or WorldGen.room_size(seed_value, room_root) != 1: return {}
		# Alcoves can contain a Jacuzzi even though their main floor is dry.
		if WorldGen.r01(seed_value, cell.x, cell.y, 2344) < 0.52: return {}
		return {"cell": cell, "axis": 1, "width": 11.7,
			"height": Chunk.cell_ceil_h(seed_value, cell, theme)-Chunk.cell_floor_h(seed_value, cell, theme)}
	var axis := WorldGen.annex_corridor_axis(seed_value, cell) if theme == 2 else WorldGen.corridor(seed_value, cell)
	if axis not in [1, 2]: return {}
	# Pick a legible sample; this is not a gameplay eligibility rule.
	if theme == 8 and WorldGen.r01(seed_value, cell.x, cell.y, 1800) < 0.08: return {}
	if theme == 2 and WorldGen.annex_corridor_bend(seed_value, cell): return {}
	var width := float(WIDTHS.get(theme, 0.0))
	if theme == 2:
		width = WorldGen.annex_horizontal_width(seed_value, cell.y) if axis == 1 else WorldGen.annex_vertical_width(seed_value, cell.x)
	if width <= 0: return {}
	var height := Chunk.cell_ceil_h(seed_value, cell, theme)
	if theme == 10: height = 3.45 # Inner tunnel, not the outer 5.8 m shell.
	return {"cell": cell, "axis": axis, "width": width, "height": height}

static func find(seed_value: int, theme: int, requested_axis := 0, excluded: Array[Vector2i] = []) -> Dictionary:
	for y in range(-8, 9):
		for x in range(-8, 9):
			if excluded.has(Vector2i(x,y)): continue
			var result := at(seed_value, Vector2i(x, y), theme)
			if not result.is_empty() and (requested_axis == 0 or result.axis == requested_axis): return result
	return {}

static func eligible(chunk: Chunk) -> Dictionary:
	if chunk._build_context != null and (not chunk._build_context.route_landmark.is_empty() or chunk._build_context.optional_discovery or not chunk._build_context.casino_landmark.is_empty()): return {}
	if chunk.is_queued_for_deletion() or chunk.portal_dest >= 0 or chunk.descent_target or chunk.descent_arrival or chunk.descent_final: return {}
	if chunk.bleed_amount > 0.0 or chunk.anomaly_kind >= 0 or chunk.optional_vhs or chunk._blackout: return {}
	if chunk.room_n != 1 and WorldGen.corridor(chunk.wseed, chunk.cell) == 0: return {}
	if not exclusions(chunk).is_empty(): return {}
	return at(chunk.wseed, chunk.cell, chunk.theme)

static func exclusions(chunk: Chunk) -> String:
	for node in chunk.find_children("*", "Node3D", true, false):
		# The charging station creates its Interactable only on entering the
		# tree. This tag also permits preview rejection before _ready runs.
		if node.has_meta("charging_station"):
			return "charging station"
		if node is Travelator or node.has_meta("walkway_flow"):
			return "moving walkway"
		if node is Area3D:
			return "interaction/traversal volume"
		if node.has_meta("pool_water_surface") or node.is_in_group("pool_water_surfaces"):
			return "water surface"
	return ""
