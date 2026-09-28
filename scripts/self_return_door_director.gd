class_name SelfReturnDoorDirector
extends Node
## One floor-scoped impossible door. It returns the actor to the SAME streamed
## room, then removes its own assembly and leaves the underlying wall intact.

const Site := preload("res://scripts/self_return_door_site.gd")
const Landmark := preload("res://scripts/self_return_landmark.gd")
const LATCH := preload("res://sounds/return-latch.mp3")
const TWO_KNOCKS := preload("res://sounds/return-two-knocks.mp3")
const ONE_KNOCK := preload("res://sounds/return-one-knock.mp3")
const STATE_KEY := "cell:0:0/self_return:site"
const FIRST_DELAY := 40.0
const RETRY_DELAY := 2.0
const DISCOVERY_LEASE := 8.0
const CROSS_Z := 0.70
const APPROACH_Z := 2.4
const RECOGNITION_SECONDS := 1.8
const TRACE_FADE_SECONDS := 1.0
const SOUND_GAP := 0.10

enum RevealStage { NONE, RECOGNIZE, LATCH, TWO_KNOCKS, THIRD_KNOCK,
	WAIT_FOR_LOOK, DONE }

signal preview_notice(message: String)
signal returned
signal noticed

var manager: ChunkManager
var player: Player
var allowed: Callable
var persist: Callable
var route: DescentRoute
var pacing: HorrorDirector
var managed := false
var site: Node3D
var site_cell := Vector2i.ZERO
var used := false
var ready_at := FIRST_DELAY
var clock := 0.0
var _record: Dictionary = {}
var _pending_landing := Vector3.INF
var _opened_once := false
var _noticed := false
var _visual_lease_left := 0.0
var _afterimage: RealmDoorLeak
var _landmark: SelfReturnLandmark
var _door_audio: AudioStreamPlayer3D
var _reveal_stage := RevealStage.NONE
var _beat_left := 0.0
var _trace_fade_left := TRACE_FADE_SECONDS
var _trace_fade_started := false
var _former_door := Transform3D.IDENTITY
var preview := false


func configure(cm: ChunkManager, actor: Player, gate: Callable,
		save: Callable, floor_route: DescentRoute = null) -> void:
	manager = cm
	player = actor
	allowed = gate
	persist = save
	route = floor_route
	_record = manager._runtime_state.payload_for(STATE_KEY)
	used = bool(_record.get("used", false))
	if preview: ready_at = 0.0
	if not _record.is_empty() and not used:
		_restore_site()
	process_physics_priority = -12


func _physics_process(dt: float) -> void:
	if manager == null or not is_instance_valid(player): return
	_visual_lease_left = maxf(0.0, _visual_lease_left - dt)
	_update_reveal(dt)
	if used:
		_ensure_landmark()
		return
	if allowed.is_valid() and allowed.call(): clock += dt
	if not is_instance_valid(site):
		if not _record.is_empty():
			_restore_site()
			return
		if managed: return
		if not allowed.is_valid() or not allowed.call(): return
		if clock < ready_at: return
		if not _try_stage(): ready_at = clock + RETRY_DELAY
		return
	if manager.chunk_at(site_cell) != site.get_parent():
		site.queue_free()
		site = null
		return
	if not _noticed and _site_in_view():
		_noticed = true
		if pacing != null and not preview:
			pacing.hold_story_discovery(DISCOVERY_LEASE)
			_visual_lease_left = maxf(_visual_lease_left, DISCOVERY_LEASE)
		noticed.emit()
	if not allowed.is_valid() or not allowed.call(): return
	var local: Vector3 = site.to_local(player.global_position)
	var horizontal := absf(local.x) < Site.WIDTH * 0.5 - 0.04
	var facing := (-player.global_basis.z).dot(-site.global_basis.z) > 0.46
	var near := horizontal and local.z > 0.0 and local.z < APPROACH_Z \
		and absf(local.y) < 1.4
	var wants_open := near and facing
	if wants_open and not _opened_once and not _reserve_crossing():
		wants_open = false
	if _opened_once and _visual_lease_left > 0.0 and pacing != null:
		pacing.extend_visual(2.0, HorrorDirector.ARCHITECTURE_RECOVERY)
		_visual_lease_left = maxf(_visual_lease_left, 2.0)
	var target := 1.0 if preview or wants_open or _opened_once else 0.0
	site.pose(move_toward(site.openness, target, dt / Site.OPEN_TIME), clock)
	if wants_open and not _opened_once:
		_opened_once = true
	if not _opened_once: return
	if not near:
		if local.z > APPROACH_Z + 1.0 or not horizontal:
			_opened_once = false
		return
	if site.openness < 0.96 or local.z > CROSS_Z or not facing: return
	# The player can press into a solid wall while velocity is zero; require
	# explicit forward intent rather than motion measured after move_and_slide.
	if not (player.dev_walk or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and GameInput.is_held("forward"))):
		return
	_cross()


func _try_stage() -> bool:
	if not allowed.is_valid() or not allowed.call(): return false
	var at := _actor_cell()
	if route != null:
		if (manager.theme != 2 and not route.is_path_room(at)) \
				or at == route.origin or at == route.target \
				or route.is_intro_door_room(at):
			return false
	var chunk := manager.chunk_at(at)
	if chunk == null or _is_corridor(chunk.style): return false
	for choice in preload("res://scripts/environment_breath_placement.gd").candidates(
			chunk, "breath"):
		var face: SurfaceWear.Face = choice["face"]
		if absf(face.normal.y) > 0.1 or absf(face.v.dot(Vector3.UP)) < 0.98:
			continue
		var center: Vector3 = choice["center"]
		var floor_y := chunk._floor_h()
		if face.center.y - face.size.y * 0.5 > floor_y + 0.12 \
				or face.center.y + face.size.y * 0.5 < floor_y + Site.HEIGHT + 0.14 \
				or face.size.x < Site.WIDTH + 0.35:
			continue
		center.y = floor_y
		var point := chunk.to_global(center)
		var normal: Vector3 = (chunk.global_basis * face.normal).normalized()
		if player.global_position.distance_to(point) < 3.0 \
				or player.global_position.distance_to(point) > 11.0 \
				or player.cam.is_position_in_frustum(point + Vector3.UP * 1.3):
			continue
		var entry := point + normal * 1.15 + Vector3.UP * ArrivalSafety.STANDING_CLEARANCE
		if _cell_of(entry) != at: continue
		if not ArrivalSafety.is_clear(player.get_world_3d(), entry, [player.get_rid()]) \
				or not ArrivalSafety.has_floor(player.get_world_3d(), entry, [player.get_rid()]):
			continue
		var opposite := _opposite_wall_return(chunk, point, normal, at)
		if opposite.is_empty(): continue
		if not preview and pacing != null and not pacing.try_start_visual(
				DISCOVERY_LEASE, HorrorDirector.ARCHITECTURE_RECOVERY):
			return false
		_visual_lease_left = DISCOVERY_LEASE if not preview else 0.0
		var basis := Basis(face.u, Vector3.UP, face.normal).orthonormalized()
		_record = {"used": false, "cell": at, "origin": center,
			"basis": basis, "landing": opposite["landing"],
			"landmark": opposite["landmark"],
			"return_origin": opposite["origin"],
			"return_basis": opposite["basis"]}
		manager._runtime_state.put(STATE_KEY, "self_return", _record)
		if persist.is_valid(): persist.call()
		_attach(chunk)
		if preview:
			var vantage := point + normal * 4.0 \
				+ Vector3.UP * ArrivalSafety.STANDING_CLEARANCE
			var safe_vantage := ArrivalSafety.find_safe(player.get_world_3d(),
				vantage, at, [player.get_rid()])
			if safe_vantage != Vector3.INF \
					and safe_vantage.distance_to(vantage) < 1.0:
				player.teleport(safe_vantage)
			var toward: Vector3 = point - player.global_position
			player.rotation.y = atan2(-toward.x, -toward.z)
			preview_notice.emit("RETURN DOOR — WALK THROUGH THE DOORWAY")
		return true
	return false


func try_visible_site() -> bool:
	if used or is_instance_valid(site) or clock < ready_at: return false
	if _try_stage(): return true
	ready_at = clock + RETRY_DELAY
	return false


func awaiting_notice_near_player() -> bool:
	return is_instance_valid(site) and not _noticed \
		and _actor_cell() == site_cell


func _site_in_view() -> bool:
	if not is_instance_valid(site): return false
	var point: Vector3 = site.global_position \
		+ Vector3.UP * Site.HEIGHT * 0.5 \
		+ site.global_basis.z.normalized() * 0.30
	if player.cam.global_position.distance_to(point) > 15.0 \
			or not player.cam.is_position_in_frustum(point): return false
	var ray := PhysicsRayQueryParameters3D.create(
		player.cam.global_position, point)
	ray.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _reveal_lease_seconds() -> float:
	return Site.OPEN_TIME + RECOGNITION_SECONDS + LATCH.get_length() \
		+ TWO_KNOCKS.get_length() + ONE_KNOCK.get_length() \
		+ SOUND_GAP * 2.0 + 1.0


func _reserve_crossing() -> bool:
	if preview or pacing == null: return true
	var seconds := _reveal_lease_seconds()
	if _visual_lease_left > 0.0 and float(pacing.snapshot()["visual"]) > 0.0:
		pacing.extend_visual(seconds, HorrorDirector.ARCHITECTURE_RECOVERY)
	else:
		if not pacing.try_start_visual(seconds,
				HorrorDirector.ARCHITECTURE_RECOVERY): return false
	_visual_lease_left = seconds
	return true


static func _is_corridor(style: int) -> bool:
	return style in [WorldGen.STYLE_HALLWAY, WorldGen.OFFICE_CORRIDOR,
		WorldGen.ANNEX_PASSAGE, WorldGen.AIR_TRANSIT, WorldGen.ASY_CORRIDOR,
		WorldGen.SCH_CORRIDOR, WorldGen.MALL_CORRIDOR,
		WorldGen.PRISON_CORRIDOR, WorldGen.POOL_CHANNEL,
		WorldGen.BRUTAL_PASSAGE, WorldGen.BLOOM_PASSAGE]


func _restore_site() -> void:
	var at: Vector2i = _record.get("cell", Vector2i.ZERO)
	var chunk := manager.chunk_at(at)
	if chunk == null: return
	if not _record.has("return_origin"):
		# Pending saves from the older in-place turn can still be used. Pair
		# their doorway with a real far wall before restoring its live view.
		var old_basis: Basis = _record["basis"]
		var source := chunk.to_global(_record["origin"])
		var normal: Vector3 = (chunk.global_basis * old_basis.z).normalized()
		var paired := _opposite_wall_return(chunk, source, normal, at)
		if paired.is_empty():
			_record = {}
		else:
			_record["landing"] = paired["landing"]
			_record["landmark"] = paired["landmark"]
			_record["return_origin"] = paired["origin"]
			_record["return_basis"] = paired["basis"]
		manager._runtime_state.put(STATE_KEY, "self_return", _record)
		if persist.is_valid(): persist.call()
		if _record.is_empty(): return
	_attach(chunk)


func _attach(chunk: Chunk) -> void:
	if is_instance_valid(site): site.queue_free()
	site_cell = chunk.cell
	site = Site.new()
	site.name = "Impossible Return Door"
	site.transform = Transform3D(_record["basis"], _record["origin"])
	chunk.add_child(site)
	site.build(player, chunk.to_global(_record["landing"]),
		chunk._wall_material(), manager.world_seed)
	_ensure_landmark()
	if preview: site.pose(1.0, clock)
	_opened_once = false


func _cross() -> void:
	var chunk := manager.chunk_at(site_cell)
	if chunk == null: return
	var return_frame: Transform3D = chunk.global_transform * Transform3D(
		_record["return_basis"], _record["return_origin"])
	var inward: Vector3 = return_frame.basis.z.normalized()
	var desired := chunk.to_global(_record["landing"])
	var safe := _safe_landing(desired, site_cell, return_frame.origin, inward)
	if safe == Vector3.INF: return
	if pacing != null and _visual_lease_left > 0.0:
		var reveal_seconds := _reveal_lease_seconds() - Site.OPEN_TIME
		pacing.extend_visual(reveal_seconds,
			HorrorDirector.ARCHITECTURE_RECOVERY)
		_visual_lease_left = maxf(_visual_lease_left, reveal_seconds)
	# The source aperture is now ahead of the arrival camera. Hide it before
	# moving the player; queue_free alone waits until the end of the frame.
	site.visible = false
	site.set_process(false)
	player.teleport(safe)
	player.rotation.y = atan2(-inward.x, -inward.z)
	if is_instance_valid(_landmark): _landmark.cue_recognition()
	used = true
	_record["used"] = true
	manager._runtime_state.put(STATE_KEY, "self_return", _record)
	if persist.is_valid(): persist.call()
	site.queue_free()
	site = null
	_start_return_reveal(return_frame)
	returned.emit()


func _safe_landing(desired: Vector3, at: Vector2i,
		door_point: Vector3, inward: Vector3) -> Vector3:
	var resolved := ArrivalSafety.find_safe(player.get_world_3d(), desired, at,
		[player.get_rid()])
	if resolved == Vector3.INF or _cell_of(resolved) != at \
			or (resolved - door_point).dot(inward) < 1.9 \
			or resolved.distance_to(desired) > 1.5:
		return Vector3.INF
	return resolved


func _opposite_wall_return(chunk: Chunk, source: Vector3,
		source_normal: Vector3, at: Vector2i) -> Dictionary:
	# Enter at the far wall with the same heading used on approach. A 180-degree
	# turn in the source room reads as a mirror; this translation keeps the
	# chair, lights, and left/right layout in their original orientation.
	for choice in preload("res://scripts/environment_breath_placement.gd").candidates(
			chunk, "breath"):
		var face: SurfaceWear.Face = choice["face"]
		var normal: Vector3 = (chunk.global_basis * face.normal).normalized()
		if normal.dot(-source_normal) < 0.98: continue
		if face.size.x < Site.WIDTH + 0.35 \
				or absf(face.v.dot(Vector3.UP)) < 0.98:
			continue
		var floor_y := chunk._floor_h()
		if face.center.y - face.size.y * 0.5 > floor_y + 0.12 \
				or face.center.y + face.size.y * 0.5 < floor_y + Site.HEIGHT + 0.14:
			continue
		var source_local := chunk.to_local(source)
		var along: float = (source_local - face.center).dot(face.u)
		var usable := face.size.x * 0.5 - Site.WIDTH * 0.5 - 0.2
		var wall_local: Vector3 = face.center + face.u * clampf(along,
			-usable, usable)
		wall_local.y = floor_y
		var basis := Basis(face.u, Vector3.UP, face.normal).orthonormalized()
		var result := _validated_return_wall(chunk, source, source_normal,
			wall_local, normal, basis, at)
		if not result.is_empty(): return result
	# Annex and Poolrooms put west/south wall geometry in the adjacent chunk.
	# The source chunk's surface scan cannot see its own far wall, although
	# the neighbouring owner is streamed around the player in normal play.
	if chunk.theme == 2 or chunk.theme == 9:
		return _shared_boundary_return(chunk, source, source_normal, at)
	return {}


func _shared_boundary_return(chunk: Chunk, source: Vector3,
		source_normal: Vector3, at: Vector2i) -> Dictionary:
	var local_normal: Vector3 = (chunk.global_basis.inverse() * source_normal).normalized()
	var opposite := -local_normal
	var wall_local := chunk.to_local(source)
	var dir := -1
	if local_normal.x < -0.98:
		wall_local.x = 0.15
		wall_local.z = clampf(wall_local.z, 1.05, Chunk.S - 1.05)
		dir = 1
	elif local_normal.x > 0.98:
		wall_local.x = Chunk.S - 0.15
		wall_local.z = clampf(wall_local.z, 1.05, Chunk.S - 1.05)
		dir = 0
	elif local_normal.z < -0.98:
		wall_local.z = 0.15
		wall_local.x = clampf(wall_local.x, 1.05, Chunk.S - 1.05)
		dir = 3
	elif local_normal.z > 0.98:
		wall_local.z = Chunk.S - 0.15
		wall_local.x = clampf(wall_local.x, 1.05, Chunk.S - 1.05)
		dir = 2
	if dir < 0: return {}
	var edge := chunk._edge_info(at, dir)
	if not bool(edge.get("wall", false)) \
			or edge.has("photo_door_id") \
			or (chunk.theme == 9 \
				and WorldGen.pool_wall_aperture(chunk.wseed, at, dir) \
				and not bool(edge.get("runtime_seal", false))):
		return {}
	wall_local.y = chunk._floor_h()
	var basis := Basis(Vector3.UP.cross(opposite), Vector3.UP,
		opposite).orthonormalized()
	var normal: Vector3 = (chunk.global_basis * opposite).normalized()
	return _validated_return_wall(chunk, source, source_normal,
		wall_local, normal, basis, at)


func _validated_return_wall(chunk: Chunk, source: Vector3,
		source_normal: Vector3, wall_local: Vector3, normal: Vector3,
		basis: Basis, at: Vector2i) -> Dictionary:
	var wall := chunk.to_global(wall_local)
	if (wall - source).dot(source_normal) < 5.0: return {}
	var wall_probe := PhysicsRayQueryParameters3D.create(
		wall + normal * 0.65 + Vector3.UP * 1.3,
		wall - normal * 0.35 + Vector3.UP * 1.3)
	wall_probe.exclude = [player.get_rid()]
	var wall_hit := player.get_world_3d().direct_space_state.intersect_ray(
		wall_probe)
	if wall_hit.is_empty() \
			or (wall_hit["position"] as Vector3).distance_to(
				wall + Vector3.UP * 1.3) > 0.32:
		return {}
	var landing := wall + normal * 2.25 \
		+ Vector3.UP * ArrivalSafety.STANDING_CLEARANCE
	if _cell_of(landing) != at: return {}
	var safe := _safe_landing(landing, at, wall, normal)
	if safe == Vector3.INF: return {}
	var landmark_at := _landmark_spot(chunk, safe, normal, at)
	if landmark_at == Vector3.INF: return {}
	return {"origin": wall_local, "basis": basis,
		"landing": chunk.to_local(safe),
		"landmark": chunk.to_local(landmark_at)}


func _landmark_spot(chunk: Chunk, landing: Vector3, normal: Vector3,
		at: Vector2i) -> Vector3:
	var across := normal.cross(Vector3.UP).normalized()
	for distance in [2.15, 2.7, 1.8]:
		for side in [0.0, -0.7, 0.7]:
			var point: Vector3 = landing + normal * distance + across * side
			if _cell_of(point) != at: continue
			var local := chunk.to_local(point)
			local.y = chunk._floor_h()
			if not chunk._floor_spot_clear(local, 0.62, 0.92): continue
			var sight := PhysicsRayQueryParameters3D.create(
				landing + Vector3.UP * Player.CAM_H,
				chunk.to_global(local) + Vector3.UP * 0.55)
			sight.exclude = [player.get_rid()]
			if not player.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				continue
			return chunk.to_global(local)
	return Vector3.INF


func _ensure_landmark() -> void:
	if is_instance_valid(_landmark) or not _record.has("landmark"): return
	var chunk := manager.chunk_at(_record.get("cell", Vector2i.ZERO))
	if chunk == null: return
	_landmark = Landmark.new()
	_landmark.name = "Return room landmark"
	_landmark.position = _record["landmark"]
	var basis: Basis = _record["basis"]
	_landmark.build(chunk.ceil_h - chunk._floor_h(),
		basis.get_euler().y,
		manager.world_seed + 287)
	chunk.add_child(_landmark)


func _start_return_reveal(frame: Transform3D) -> void:
	_former_door = frame
	_door_audio = AudioStreamPlayer3D.new()
	_door_audio.name = "Sounds at vanished doorway"
	_door_audio.bus = SoundBank.GAME_BUS
	_door_audio.volume_db = -5.0
	_door_audio.unit_size = 8.0
	_door_audio.max_distance = 11.0
	add_child(_door_audio)
	_door_audio.global_position = frame.origin + frame.basis.z.normalized() * 0.22 \
		+ Vector3.UP * 1.25
	_afterimage = RealmDoorLeak.new()
	_afterimage.name = "Last trace of return doorway"
	add_child(_afterimage)
	_afterimage.configure_doorway_outline(frame.origin,
		-frame.basis.z.normalized(), manager.world_seed,
		Vector2(Site.WIDTH, Site.HEIGHT))
	_afterimage.update_cue(0.0, true, false)
	_afterimage._material.set_shader_parameter("strength", 0.10)
	_afterimage._light.light_energy = 0.025
	_reveal_stage = RevealStage.RECOGNIZE
	_beat_left = RECOGNITION_SECONDS
	_trace_fade_left = TRACE_FADE_SECONDS
	_trace_fade_started = false


func _play_door_sound(stream: AudioStream) -> void:
	_door_audio.stop()
	_door_audio.stream = stream
	_door_audio.play()


func _update_reveal(dt: float) -> void:
	# The wall keeps its last trace until the player actually sees it. This
	# happens independently of the audio sequence if they turn early.
	if is_instance_valid(_afterimage) and not _trace_fade_started \
			and _looking_at_former_door():
		_trace_fade_started = true
	if _trace_fade_started and is_instance_valid(_afterimage):
		_trace_fade_left = maxf(0.0, _trace_fade_left - dt)
		if _trace_fade_left <= 0.0:
			_afterimage.queue_free()
			_afterimage = null
	match _reveal_stage:
		RevealStage.RECOGNIZE:
			_beat_left -= dt
			if _beat_left <= 0.0:
				_play_door_sound(LATCH)
				_reveal_stage = RevealStage.LATCH
				_beat_left = LATCH.get_length() + SOUND_GAP
		RevealStage.LATCH:
			_beat_left -= dt
			if _beat_left <= 0.0:
				_play_door_sound(TWO_KNOCKS)
				_reveal_stage = RevealStage.TWO_KNOCKS
				_beat_left = TWO_KNOCKS.get_length() + SOUND_GAP
		RevealStage.TWO_KNOCKS:
			_beat_left -= dt
			if _beat_left <= 0.0:
				_play_door_sound(ONE_KNOCK)
				_reveal_stage = RevealStage.THIRD_KNOCK
				_beat_left = ONE_KNOCK.get_length()
		RevealStage.THIRD_KNOCK:
			_beat_left -= dt
			if _beat_left <= 0.0:
				_reveal_stage = RevealStage.WAIT_FOR_LOOK
		RevealStage.WAIT_FOR_LOOK:
			if _looking_at_former_door():
				_play_door_sound(ONE_KNOCK)
				_reveal_stage = RevealStage.DONE
	if is_instance_valid(_afterimage):
		_afterimage.update_cue(dt, true, false)
		var fade := 1.0 if not _trace_fade_started else \
			_trace_fade_left / TRACE_FADE_SECONDS
		_afterimage._material.set_shader_parameter("strength", 0.10 * fade)
		_afterimage._light.light_energy = 0.025 * fade


func _looking_at_former_door() -> bool:
	var wall: Vector3 = _former_door.origin \
		+ _former_door.basis.z.normalized() * 0.22 + Vector3.UP * 1.35
	var view: Vector3 = wall - player.cam.global_position
	if view.length() >= 12.0: return false
	# The body check excludes a stale top-level camera transform on the frame
	# immediately after teleport; the frustum samples admit the first edge of
	# the former opening as soon as it enters view.
	var body_view := Vector3(view.x, 0.0, view.z).normalized()
	if (-player.global_basis.z).dot(body_view) <= 0.65: return false
	for side in [-0.54, 0.0, 0.54]:
		if player.cam.is_position_in_frustum(
				wall + _former_door.basis.x.normalized() * side):
			return true
	return false


func _actor_cell() -> Vector2i:
	return _cell_of(player.global_position)


static func _cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / ChunkManager.CELL),
		floori(point.z / ChunkManager.CELL))
