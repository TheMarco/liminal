class_name LevelTransitionController
extends Node
## Owns the atomic floor-transition sequence and its arrival safety policy.

var _port: LevelTransitionPort
var _fade: ColorRect
var _warp: AudioStreamPlayer
var _portal_arrivals: Dictionary
var _portal_arrival_default: Vector3
var _default_spawn: Vector3
var _switching := false
var _saved_positions: Dictionary = {}


func _exit_tree() -> void:
	# The port owns Callables that close over Main. Drop them before Node teardown
	# so the RefCounted port cannot retain the scene root through cleanup.
	_port = null


func configure(port: LevelTransitionPort, fade: ColorRect,
		warp: AudioStreamPlayer, default_spawn: Vector3,
		portal_arrivals: Dictionary, portal_arrival_default: Vector3) -> void:
	assert(port != null and port.is_valid())
	_port = port
	_fade = fade
	_warp = warp
	_default_spawn = default_spawn
	_portal_arrivals = portal_arrivals.duplicate(true)
	_portal_arrival_default = portal_arrival_default


func is_switching() -> bool:
	return _switching


func set_switching(value: bool) -> void:
	_switching = value


func clear_saved_positions() -> void:
	_saved_positions.clear()


func saved_position_count() -> int:
	return _saved_positions.size()


func switch_wander(level: int) -> void:
	if bool(_port.descent_mode.call()) or _switching \
			or level == int(_port.active_level.call()):
		return
	var pos: Vector3 = _saved_positions.get(level, Vector3.INF)
	if pos == Vector3.INF:
		pos = safe_arrival(level, Vector2i.ZERO, _default_spawn)
	jump_to(level, pos, false)


func enter_portal(destination: int, cell: Vector2i) -> void:
	if bool(_port.descent_mode.call()) or _switching \
			or destination == int(_port.active_level.call()):
		return
	var base: Vector3 = _portal_arrivals.get(
		destination, _portal_arrival_default)
	jump_to(destination, safe_arrival(destination, cell, base), true)


## Convert a cell-local arrival hint into a world-space point, including the
## authored school aisle and Airport gate-pocket exceptions.
func safe_arrival(level: int, cell: Vector2i, base: Vector3) -> Vector3:
	var seed := int(_port.level_seed.call(level))
	return safe_arrival_for_seed(level, cell, base, seed)


static func safe_arrival_for_seed(level: int, cell: Vector2i, base: Vector3,
		seed: int) -> Vector3:
	var floor_y := Chunk.cell_floor_h(seed, cell, level)
	var pos := Vector3(cell.x * WorldGen.CELL_SIZE + base.x, floor_y + base.y,
		cell.y * WorldGen.CELL_SIZE + base.z)
	if level == 6 and cell == Vector2i.ZERO:
		var root := WorldGen.room_id(seed, cell)
		var centre := WorldGen.room_centre(seed, root)
		var front := WorldGen.anchor_wall(seed, root, 72)
		var facing := Vector2.ZERO
		match front:
			0: facing = Vector2(1.0, 0.0)
			1: facing = Vector2(-1.0, 0.0)
			2: facing = Vector2(0.0, 1.0)
			_: facing = Vector2(0.0, -1.0)
		var side := Vector2(facing.y, -facing.x)
		return Vector3(centre.x + facing.x * 2.2 + side.x * 3.0,
			floor_y + base.y, centre.y + facing.y * 2.2 + side.y * 3.0)
	if level != 4 or WorldGen.cell_style(seed, cell, 4) != WorldGen.AIR_GATE:
		return pos
	var wall := WorldGen.anchor_wall(seed, cell, 310)
	if wall == 3 and base.z < 2.4:
		pos.z = cell.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE - base.z)
	elif wall == 2 and base.z > 9.6:
		pos.z = cell.y * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE - base.z)
	elif wall == 1 and base.x < 2.4:
		pos.x = cell.x * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE - base.x)
	elif wall == 0 and base.x > 9.6:
		pos.x = cell.x * WorldGen.CELL_SIZE + (WorldGen.CELL_SIZE - base.x)
	return pos


func jump_to(level: int, requested_position: Vector3, via_portal: bool,
		exact := false, yaw := NAN) -> void:
	_switching = true
	var player_node: Player = _port.player.call()
	if player_node.is_charging():
		player_node.stop_charging()
	if not bool(_port.descent_mode.call()):
		_saved_positions[int(_port.active_level.call())] = player_node.position
	if via_portal:
		_warp.play()
	var fade_out := create_tween()
	fade_out.tween_property(
		_fade, "color:a", 1.0, 0.16 if via_portal else 0.3)
	await fade_out.finished

	var outgoing: Node3D = _port.level_root.call()
	_port.detach_level.call(outgoing)
	outgoing.queue_free()
	_port.reset_floor_presence.call()
	_port.switch_music.call(level)
	_port.set_active_level.call(level)
	await get_tree().physics_frame

	var prepared: Dictionary = _port.prepare_destination.call(
		level, requested_position, exact, yaw)
	var position: Vector3 = prepared.get("position", requested_position)
	exact = bool(prepared.get("exact", exact))
	yaw = float(prepared.get("yaw", yaw))
	_port.build_level.call(level, position)
	_port.post_build.call(level)
	await get_tree().physics_frame

	var cell := Vector2i(floori(position.x / WorldGen.CELL_SIZE),
		floori(position.z / WorldGen.CELL_SIZE))
	var safe := _resolve_live_arrival(level, cell, position, exact, player_node)
	player_node.teleport(safe)
	if is_finite(yaw):
		player_node.rotation.y = yaw
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(
		_fade, "color:a", 0.0, 0.45 if via_portal else 0.5)
	await fade_in.finished
	_switching = false


func settle_initial_arrival() -> void:
	await get_tree().physics_frame
	var player_node: Player = _port.player.call()
	if player_node == null or not is_instance_valid(player_node) \
			or bool(_port.sealed_descent_arrival.call()):
		return
	var pos := player_node.global_position
	var cell := Vector2i(floori(pos.x / WorldGen.CELL_SIZE),
		floori(pos.z / WorldGen.CELL_SIZE))
	var excluded: Array[RID] = [player_node.get_rid()]
	var safe := ArrivalSafety.find_safe(
		_port.world_3d.call(), pos, cell, excluded)
	if safe != Vector3.INF and safe.distance_to(pos) > 0.02:
		player_node.teleport(safe)


func _resolve_live_arrival(level: int, cell: Vector2i, pos: Vector3,
		exact: bool, player_node: Player) -> Vector3:
	var world: World3D = _port.world_3d.call()
	var excluded: Array[RID] = [player_node.get_rid()]
	var trusted := exact and ArrivalSafety.is_clear(world, pos, excluded) \
		and ArrivalSafety.has_floor(world, pos, excluded)
	if trusted:
		return pos
	if exact:
		push_warning("Descent arrival car interior was not clear in theme %d cell %s; falling back" % [level, cell])
	var safe := ArrivalSafety.find_safe(world, pos, cell, excluded)
	if safe != Vector3.INF:
		return safe
	var seed := int(_port.level_seed.call(level))
	var support := ArrivalSafety.support_top(world, pos.x, pos.z, pos.y, excluded)
	safe = pos if support == -INF else Vector3(
		pos.x, support + ArrivalSafety.STANDING_CLEARANCE, pos.z)
	push_error(("No audited arrival candidate in theme %d cell %s " +
		"(style %d, floor y %.2f, requested y %.2f); using %s") % [
		level, cell, WorldGen.cell_style(seed, cell, level),
		Chunk.cell_floor_h(seed, cell, level), pos.y,
		"supported point" if support != -INF else "requested position"])
	return safe
