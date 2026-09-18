class_name RealmFlashBounty
extends PhotoAnomaly
## A glyph-built 3D lightning bolt marks a photographic prize. Existing room
## furnishing supplies its checked location; the floating icon is only VFX.

const GLYPH_SHADER := preload("res://shaders/realm_bounty.gdshader")
const STEP := 0.85
const MAX_WALK := 36.0
const MAX_NODES := 2800
const RANGE := 4.5 # Placement must offer a nearby stance; this is not a shutter cutoff.
const BOLT_HEIGHT := 2.05
const SEARCH_BUDGET_USEC := 2000
signal photographed()

var documented := false
var bounds: AABB
var approach := Vector3.ZERO
var walk_distance := 0.0
var visible_from_entry := false
var subject := "object"
var source_asset := ""
var _lamp: OmniLight3D
var _hum: AudioStreamPlayer3D
var _icon: MeshInstance3D
var _icon_origin := Vector3.ZERO
var _icon_yaw := 0.0
var _motion_time := 0.0


static func choose(cm: ChunkManager, origin: Vector3, forward := Vector3.FORWARD) -> Dictionary:
	var tree := cm.get_tree()
	var models: Array[Dictionary] = []
	_collect_models(cm, models)
	var world := cm.get_world_3d()
	var space := world.direct_space_state
	var entry_eye := origin + Vector3.UP * Player.CAM_H
	for model in models:
		var aim := _near_face(model.bounds, entry_eye)
		var delta := aim - entry_eye
		var ray := PhysicsRayQueryParameters3D.create(entry_eye, aim, 1)
		var hit := space.intersect_ray(ray)
		model["entry_visible"] = hit.is_empty() or (hit.position as Vector3).distance_to(aim) < 0.25
		model["entry_ahead"] = delta.normalized().dot(forward) > 0.55
		model["entry_distance"] = delta.length()
	var shape := CapsuleShape3D.new()
	shape.radius = ArrivalSafety.RADIUS
	shape.height = ArrivalSafety.HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.margin = 0.01
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var costs := {Vector2i.ZERO: 0.0}
	var blocked := {}
	var head := 0
	var best := {}
	var score := INF
	var checked_models := {}
	var slice_started := Time.get_ticks_usec()
	# A bounded flood over real capsule sweeps proves the approach, including
	# furniture and door jambs. We never pick a prize through a wall.
	while head < queue.size() and head < MAX_NODES:
		# Thousands of capsule sweeps used to run in one frame as the player
		# approached. Keep the exact search/order but share it across frames.
		if Time.get_ticks_usec() - slice_started >= SEARCH_BUDGET_USEC:
			await tree.process_frame
			if not is_instance_valid(cm) or not cm.is_inside_tree():
				return {}
			slice_started = Time.get_ticks_usec()
		var key := queue[head]
		head += 1
		var cost: float = costs[key]
		var at := origin + Vector3(key.x * STEP, 0.0, key.y * STEP)
		if cost >= STEP:
			for index in models.size():
				if checked_models.has(index):
					continue
				var model: Dictionary = models[index]
				var box: AABB = model.bounds
				var eye := at + Vector3.UP * Player.CAM_H
				var aim := _near_face(box, eye)
				var range_to_prop := eye.distance_to(aim)
				if range_to_prop > RANGE - 0.4 or range_to_prop < 1.0:
					continue
				if float(model.entry_distance) < 5.0:
					continue
				var ray := PhysicsRayQueryParameters3D.create(eye, aim, 1)
				var hit := space.intersect_ray(ray)
				if not hit.is_empty() and (hit.position as Vector3).distance_to(aim) > 0.25:
					continue
				# The flood visits shortest paths first. Judge each prop by its
				# first usable approach, never an artificial detour to make it far.
				checked_models[index] = true
				var priority := 0.0 if model.entry_visible and model.entry_ahead \
					else (100.0 if model.entry_visible else 200.0)
				var rank := priority + absf(cost - 14.0) + range_to_prop * 0.3
				if rank >= score:
					continue
				var icon_origin := _clear_icon_position(world, box, at, origin)
				if not icon_origin.is_finite():
					continue
				var bearing := ((icon_origin - origin) * Vector3(1, 0, 1)).normalized()
				if bearing.dot(forward) < 0.72:
					continue
				score = rank
				best = model.duplicate()
				best["approach"] = at
				best["walk_distance"] = cost
				best["entry_origin"] = origin
				best["icon_origin"] = icon_origin
		if cost + STEP > MAX_WALK:
			continue
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = key + dir
			if costs.has(next) or blocked.has(next):
				continue
			var target := origin + Vector3(next.x * STEP, 0.0, next.y * STEP)
			if not ArrivalSafety.has_floor(world, target) or not ArrivalSafety.is_clear(world, target):
				blocked[next] = true
				continue
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * ArrivalSafety.HEIGHT * 0.5)
			query.motion = target - at
			var sweep := space.cast_motion(query)
			if sweep[0] < 0.999:
				continue # This edge may fail while another approach is clear.
			costs[next] = cost + STEP
			queue.append(next)
	return best if not best.is_empty() else await _open_floor_prize(cm, world, origin, forward, costs)


## Some realms have no suitably small imported fixture. The same glyph bolt
## can stand in clear floor space; both its approach and its full volume still
## have to pass the real room's collision and visibility checks.
static func _open_floor_prize(cm: ChunkManager, world: World3D, origin: Vector3, forward: Vector3,
		costs: Dictionary) -> Dictionary:
	var tree := cm.get_tree()
	var slice_started := Time.get_ticks_usec()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.32, BOLT_HEIGHT + 0.2, 1.32)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := world.direct_space_state
	var entry_eye := origin + Vector3.UP * Player.CAM_H
	var keys: Array = costs.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i):
		return absf(float(costs[a]) - 12.0) < absf(float(costs[b]) - 12.0))
	for key: Vector2i in keys:
		if Time.get_ticks_usec() - slice_started >= SEARCH_BUDGET_USEC:
			await tree.process_frame
			if not is_instance_valid(cm) or not cm.is_inside_tree():
				return {}
			slice_started = Time.get_ticks_usec()
		var foot := origin + Vector3(key.x * STEP, 0, key.y * STEP)
		var delta := foot - origin
		if delta.length() < 6.0 or delta.length() > 18.0 or delta.normalized().dot(forward) < 0.72:
			continue
		var point := foot + Vector3.UP * (BOLT_HEIGHT * 0.5 + 0.12)
		query.transform = Transform3D(Basis.IDENTITY, point)
		if not space.intersect_shape(query, 1).is_empty() \
				or not space.intersect_ray(PhysicsRayQueryParameters3D.create(entry_eye, point, 1)).is_empty():
			continue
		for near: Vector2i in keys:
			if Time.get_ticks_usec() - slice_started >= SEARCH_BUDGET_USEC:
				await tree.process_frame
				if not is_instance_valid(cm) or not cm.is_inside_tree():
					return {}
				slice_started = Time.get_ticks_usec()
			var at := origin + Vector3(near.x * STEP, 0, near.y * STEP)
			var eye := at + Vector3.UP * Player.CAM_H
			if eye.distance_to(point) < 2.0 or eye.distance_to(point) > RANGE - 0.3:
				continue
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, 1)).is_empty():
				continue
			return {"asset": "realm_glyph", "bounds": AABB(point - shape.size * 0.5, shape.size),
				"approach": at, "walk_distance": costs[near], "entry_origin": origin,
				"entry_visible": true, "icon_origin": point}
	return {}


static func _collect_models(node: Node, result: Array[Dictionary]) -> void:
	if node is Node3D and (node.has_meta("attributed_asset") or node.has_meta("authored_asset")):
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(node, meshes)
		if not meshes.is_empty():
			var box := meshes[0].global_transform * meshes[0].mesh.get_aabb()
			for mesh in meshes:
				box = box.merge(mesh.global_transform * mesh.mesh.get_aabb())
			if box.position.y < 1.2 and box.end.y > 0.55 and box.size.y < 3.2 \
					and maxf(box.size.x, box.size.z) < 3.5 and box.size.length() > 0.6:
				result.append({"meshes": meshes, "bounds": box,
					"asset": str(node.get_meta("attributed_asset", node.get_meta("authored_asset", "")))})
		return
	for child in node.get_children():
		_collect_models(child, result)


static func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)


static func _near_face(box: AABB, eye: Vector3) -> Vector3:
	var delta := eye - box.get_center()
	var half := box.size * 0.5 + Vector3.ONE * 0.035
	var ratio := (delta / half).abs()
	return box.get_center() + delta / maxf(1.0, maxf(ratio.x, maxf(ratio.y, ratio.z)))


static func _clear_icon_position(world: World3D, fixture: AABB, at: Vector3,
		entry: Vector3) -> Vector3:
	var outward := ((at - fixture.get_center()) * Vector3(1.0, 0.0, 1.0)).normalized()
	var lateral := Vector3(outward.z, 0.0, -outward.x)
	var face := _near_face(fixture, fixture.get_center() + outward * 10.0)
	var shape := BoxShape3D.new()
	# Reserve the full turning and bobbing envelope, not just the narrow bolt.
	shape.size = Vector3(1.32, BOLT_HEIGHT + 0.2, 1.32)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := world.direct_space_state
	for sideways in [1.35, -1.35, 0.0]:
		for distance in [1.0, 1.6, 0.7]:
			var point: Vector3 = face + outward * distance + lateral * sideways
			point.y = maxf(0.0, fixture.position.y) + BOLT_HEIGHT * 0.5 + 0.22
			query.transform = Transform3D(Basis.IDENTITY, point)
			if not space.intersect_shape(query, 1).is_empty():
				continue
			var foot := Vector3(point.x, at.y, point.z)
			if not ArrivalSafety.has_floor(world, foot):
				continue
			var eye := at + Vector3.UP * Player.CAM_H
			if eye.distance_to(point) > RANGE - 0.3 or eye.distance_to(point) < 1.5:
				continue
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, 1)).is_empty():
				continue
			var entry_eye := entry + Vector3.UP * Player.CAM_H
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(entry_eye, point, 1)).is_empty():
				continue
			return point
	return Vector3.INF


func build(choice: Dictionary, reward_id: String, floor_theme: int) -> void:
	id = reward_id
	type = Type.BOUNTY
	theme = floor_theme
	bounds = choice.bounds
	approach = choice.approach
	walk_distance = choice.walk_distance
	visible_from_entry = choice.entry_visible
	source_asset = choice.asset
	subject = "glyph lightning bolt"
	cell = Vector2i(floori(bounds.get_center().x / 12.0), floori(bounds.get_center().z / 12.0))
	_icon_origin = choice.icon_origin
	var towards_entry: Vector3 = (choice.entry_origin - _icon_origin) * Vector3(1.0, 0.0, 1.0)
	_icon_yaw = atan2(towards_entry.x, towards_entry.z)
	var material := ShaderMaterial.new()
	material.shader = GLYPH_SHADER
	_icon = MeshInstance3D.new()
	_icon.name = "GlyphFlashBolt"
	_icon.mesh = FlashBoltMesh.build(BOLT_HEIGHT, 1.15, 0.32)
	_icon.material_override = material
	_icon.layers = 1 | PHOTO_LAYER
	_icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_icon)
	_update_icon()
	_lamp = OmniLight3D.new()
	_lamp.position = _icon_origin
	_lamp.light_color = Color(0.25, 0.45, 1.0)
	_lamp.light_energy = 3.5
	_lamp.omni_range = 6.0
	_lamp.shadow_enabled = true
	_lamp.set_meta("visible_source", "floating_flash_glyph")
	add_child(_lamp)
	_hum = AudioStreamPlayer3D.new()
	_hum.position = bounds.get_center()
	_hum.stream = SoundBank.portal_hum()
	_hum.bus = SoundBank.GAME_BUS
	_hum.volume_db = -14.0
	_hum.pitch_scale = 1.6
	_hum.unit_size = 10.0
	_hum.max_distance = 30.0
	add_child(_hum)
	_hum.play()


func _process(dt: float) -> void:
	if not is_instance_valid(_icon):
		return
	_motion_time += dt
	_update_icon()


func _update_icon() -> void:
	# A slight turn shows the extruded sides without ever presenting only a
	# thin edge to the arrival view. Both motion and glyphs stay with the icon.
	var comfort := 0.35 if GameSettings.flashing_reduced() else 1.0
	_icon.position = _icon_origin + Vector3.UP * sin(_motion_time * 1.5) * 0.07 * comfort
	if is_instance_valid(_lamp):
		_lamp.position = _icon.position
	_icon.rotation.y = _icon_yaw + 0.32 + sin(_motion_time * 0.9) * 0.14 * comfort
	bounds = _icon.transform * _icon.mesh.get_aabb()
	_points = [_icon.position]


func framing_points(cam: Camera3D) -> Array[Vector3]:
	return [_near_face(bounds, cam.global_position)]


func set_hold(on: bool) -> void:
	_hum.stream_paused = on
	set_process(not on)


func count_caption() -> String:
	return "FLASH CAPTURED — SURVIVE TO KEEP IT"


func album_description(_already_documented := false) -> String:
	return "A floating lightning bolt made of glowing blue-violet glyphs. Its photograph can hold one emergency flash."


func resolves_after_review() -> bool:
	return false


func resolve(_restoring := false) -> void:
	if documented:
		return
	documented = true
	_lamp.light_energy = 0.4
	_hum.stop()
	photographed.emit()
