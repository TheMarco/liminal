class_name PoolEquipment
extends RefCounted
## Authored pool props use a deck-level origin at the water lip, facing +Z.
## Placement reserves the deck approach and splashdown before columns spawn.

const KINDS := ["diving_board", "slide_straight", "slide_spiral"]
const PATHS: Array[String] = [
	"res://models/authored/pool_equipment/pool_diving_board.glb",
	"res://models/authored/pool_equipment/pool_slide_straight.glb",
	"res://models/authored/pool_equipment/pool_slide_spiral.glb",
]
# Conservative operating envelopes, including the person at the ladder/board.
const DECK_BOUNDS := [Rect2(-0.65, -2.10, 1.30, 2.02),
	Rect2(-0.85, -3.15, 1.70, 3.07), Rect2(-1.65, -3.00, 4.45, 2.92)]
const MIN_CEILINGS := [4.0, 5.05, 6.20]
const EXIT_X := [0.0, 0.0, 0.65]
# 3.15 m operating depth + 0.55 m perimeter clearance + 0.15 m tolerance.
const STAGING_DECK := 3.85
static var _collision_data := {}
static var _trough_shapes := {}


static func clear_runtime_cache() -> void:
	_collision_data.clear()
	_trough_shapes.clear()


static func footprint(rect: Rect2, at: Vector3, yaw: float) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [rect.position.x, rect.end.x]:
		for z in [rect.position.y, rect.end.y]:
			var p := at + Vector3(x, 0, z).rotated(Vector3.UP, yaw)
			low = low.min(Vector2(p.x, p.z))
			high = high.max(Vector2(p.x, p.z))
	return Rect2(low, high - low)


static func plan(ctx: ChunkBuildContext, layout: Dictionary,
		access: Array, doorways: Array[Rect2]) -> Dictionary:
	if not ctx.is_room_anchor or ctx.target or ctx.arrival \
			or WorldGen.portal(ctx.world_seed, ctx.cell, ctx.theme) >= 0 \
			or ctx.style not in [WorldGen.POOL_BASIN, WorldGen.POOL_CISTERN]:
		return {}
	var preferred := WorldGen.pool_equipment_kind(ctx.world_seed, ctx.cell)
	if preferred < 0:
		return {}
	var center: Vector2 = layout["center"]
	var size: Vector2 = layout["size"]
	var water := Rect2(center - size * 0.5, size)
	var corner_keepout := Rect2()
	var corner := int(layout.get("rounded_corner", -1))
	if corner >= 0:
		var radius := float(layout["corner_radius"]) + 0.10
		var low := water.position
		if corner in [1, 2]: low.x = water.end.x - radius
		if corner in [2, 3]: low.y = water.end.y - radius
		corner_keepout = Rect2(low, Vector2.ONE * radius)
	var links: Array = layout.get("edge_links", [])
	var kind_order: Array = [0] if preferred == 0 else ([1, 0] if preferred == 1 else [2, 1, 0])
	var first := int(layout.get("equipment_side", int(ctx.random01(2472) * 4.0) % 4))
	if first < 0:
		first = int(ctx.random01(2472) * 4.0) % 4
	for kind: int in kind_order:
		if ctx.ceiling_height < MIN_CEILINGS[kind]:
			continue
		for step in 4:
			var dir := (first + step) % 4
			if links.has(dir):
				continue
			var yaw: float = [-PI * 0.5, PI * 0.5, PI, 0.0][dir]
			var at := Vector3(center.x, Chunk.POOL_DECK_Y, center.y)
			if dir < 2:
				at.x += size.x * (0.5 if dir == 0 else -0.5)
			else:
				at.z += size.y * (0.5 if dir == 2 else -0.5)
			# The spiral's ladder and platform are asymmetric around its outlet.
			# Centre their full operating width, then try nearby positions along
			# this shore before giving up on a safe slide placement.
			var lateral_center: float = DECK_BOUNDS[kind].get_center().x
			for offset: float in [0.0, -0.6, 0.6, -1.2, 1.2]:
				var candidate := at + Vector3(offset - lateral_center, 0, 0).rotated(Vector3.UP, yaw)
				var deck := footprint(DECK_BOUNDS[kind], candidate, yaw)
				# Keep a clear strip at the room perimeter, even along full-open edges.
				if not Rect2(0.55, 0.55, 10.9, 10.9).encloses(deck):
					continue
				var landing := footprint(Rect2(EXIT_X[kind] - 0.90, 0.15, 1.80, 2.70), candidate, yaw)
				if not water.grow(-0.10).encloses(landing):
					continue
				# A rectangular water mesh also extends underneath its rounded
				# tiled corner. Keep splashdown out of that solid corner entirely.
				if corner >= 0 and landing.intersects(corner_keepout):
					continue
				var occupied := deck.merge(landing)
				var blocked := false
				for lane: Rect2 in access:
					if occupied.intersects(lane):
						blocked = true
				for lane in doorways:
					if occupied.intersects(lane):
						blocked = true
				if blocked:
					continue
				return {"kind": kind, "at": candidate, "yaw": yaw, "dir": dir,
					"deck": deck, "landing": landing, "occupied": occupied}
	return {}


static func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _shape(body: StaticBody3D, shape: Shape3D,
		at: Vector3, rotation := Vector3.ZERO) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = at
	node.rotation = rotation
	body.add_child(node)
	return node


static func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


static func _trough(kind: int, data: Dictionary) -> ConcavePolygonShape3D:
	if _trough_shapes.has(kind):
		return _trough_shapes[kind]
	var points: Array = data["centerline"]
	var width := float(data["half_width"])
	var wall := float(data["wall_height"])
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var p := _vec(points[i])
		var tangent := _vec(points[mini(i + 1, points.size() - 1)]) - _vec(points[maxi(0, i - 1)])
		tangent.y = 0
		tangent = tangent.normalized()
		var across := Vector3(tangent.z, 0, -tangent.x)
		# Five spans approximate the bed and raised sides. Render-shell thickness,
		# rounded lips and screw heads do not enter the physics mesh.
		var ring := PackedVector3Array()
		for profile: Vector2 in [Vector2(-width, wall), Vector2(-width + 0.03, 0.105),
				Vector2(-width + 0.15, 0), Vector2(width - 0.15, 0),
				Vector2(width - 0.03, 0.105), Vector2(width, wall)]:
			ring.append(p + across * profile.x + Vector3.UP * profile.y)
		rings.append(ring)
	var faces := PackedVector3Array()
	for i in range(rings.size() - 1):
		for j in range(5):
			_quad(faces, rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j + 1])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_trough_shapes[kind] = shape
	return shape


static func build(scene: ChunkSceneWriter, kind: int, at: Vector3, yaw: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pool_" + KINDS[kind]
	pivot.position = at
	pivot.rotation.y = yaw
	pivot.set_meta("pool_equipment", KINDS[kind])
	scene.add_node(pivot)
	var model := scene.attributed_prop_local(pivot, PATHS[kind], Vector3.ZERO, 0.0)
	if model == null:
		pivot.free()
		return null
	if _collision_data.is_empty():
		_collision_data = JSON.parse_string(FileAccess.get_file_as_string(
			"res://models/authored/pool_equipment/collision.json"))
	var data: Dictionary = _collision_data["pool_" + KINDS[kind]]
	var body := StaticBody3D.new()
	body.name = "EquipmentCollision"
	pivot.add_child(body)
	for box: Dictionary in data.get("boxes", []):
		var shape := BoxShape3D.new()
		shape.size = _vec(box["size"])
		_shape(body, shape, _vec(box["center"]), Vector3(0, float(box.get("yaw", 0.0)), 0))
	for leg: Dictionary in data.get("support_legs", []):
		var a := _vec(leg["a"])
		var b := _vec(leg["b"])
		var shape := CylinderShape3D.new()
		shape.radius = float(leg["radius"])
		shape.height = a.distance_to(b)
		var collider := _shape(body, shape, (a + b) * 0.5)
		collider.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	if kind != 0:
		var trough := _shape(body, _trough(kind, data), Vector3.ZERO)
		trough.set_meta("pool_equipment_trough", true)
		_build_ladder(pivot, body, data)
		var slide := PoolSlide.new()
		slide.name = "SlideRide"
		slide.collision_body = body
		slide.configure(data["centerline"])
		pivot.add_child(slide)
	else:
		# This game has no jump/step-up action. Use its existing climb assist at
		# the board's heel so the low springboard can be stepped onto normally.
		_build_ladder(pivot, body, {"ladder_bottom": [0, 0, -1.72],
			"ladder_top": [0, 0.52, -1.22], "boxes": data["boxes"]})
		pivot.get_node("SlideLadder").name = "BoardMount"
	return pivot


static func _build_ladder(pivot: Node3D, body: StaticBody3D, data: Dictionary) -> void:
	var bottom := _vec(data["ladder_bottom"])
	var top := _vec(data["ladder_top"])
	var direction := Vector3(top.x - bottom.x, 0, top.z - bottom.z).normalized()
	var yaw := atan2(direction.x, direction.z)
	# Existing forward-to-climb behavior. A single narrow area follows the
	# ladder to its landing; the player can then walk onto the open chute.
	var area := Area3D.new()
	area.name = "SlideLadder"
	area.collision_layer = Player.LADDER_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.position = (bottom + top) * 0.5 + Vector3.UP * 0.40
	area.rotation.y = yaw
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.02, top.y - bottom.y + 1.3,
		Vector2(top.x - bottom.x, top.z - bottom.z).length() + 0.55)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	area.set_meta("pool_equipment_ladder", true)
	pivot.add_child(area)
	# The small flat landing bridges the ladder's top to the chute mouth.
	if data.get("boxes", []).is_empty():
		var entry := _vec(data["entry"])
		var landing := BoxShape3D.new()
		landing.size = Vector3(0.90, 0.08, maxf(0.18, top.distance_to(entry) + 0.12))
		_shape(body, landing, (top + entry) * 0.5 - Vector3.UP * 0.046, Vector3(0, yaw, 0))
