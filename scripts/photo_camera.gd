class_name PhotoCamera
extends CanvasLayer
## The phone's other function. Hold right mouse to raise the camera, left
## mouse to take the picture. The torch is untouched — a lit torch keeps
## warding while you shoot; the cost of a photograph is the seconds your eyes
## spend on it.
##
## The camcorder is the detector. Within PROXIMITY_RANGE of an undocumented
## anomaly the OSD picks up interference (tracking bars, a stuttering REC
## lamp, tape static) that grows as you close in, camera raised or lowered,
## halved through walls — "there is something in this room", never where.
## Raising the camera and framing it snaps the brackets: the last metre of
## the hunt stays a search.
##
## The snapshot renders through a private SubViewport whose camera carries the
## photo-only layer, so hidden writing exists in the print and never on the
## screen. After a successful photograph the room answers: usually nothing,
## sometimes the environment, sometimes the thing itself — the same forced
## encounter the tape's ending already uses, which spawns with line of sight
## in the arc behind you. You lower the camera and look around to find out.

const AIM_FOV := 58.0
const REVIEW_SECONDS := 2.6
const FLASH_SECONDS := 0.09
## Post-photo danger table; rolled only when the shot documented something.
const RISK_NOTHING := 0.70
const RISK_ENVIRONMENT := 0.22   # remainder is the encounter
const ENCOUNTER_DELAY := 1.4
## Framing: every sample point must sit inside the frustum, roughly ahead,
## and unoccluded from the lens.
const FRAME_DOT := 0.42
const OCCLUSION_TOLERANCE := 0.45
## Proximity signal: full strength at PROXIMITY_NEAR, silent beyond
## PROXIMITY_RANGE; an occluded anomaly counts at PROXIMITY_OCCLUDED weight.
const PROXIMITY_RANGE := 18.0
const PROXIMITY_NEAR := 3.5
const PROXIMITY_OCCLUDED := 0.45
const PROXIMITY_SCAN := 0.2
const STATIC_DB_FULL := -14.0
const STATIC_DB_SILENT := -60.0

var player: Player
var run: DescentRun
var director: PhotoDirector
var figures: ShadowFigures
var events: EnvironmentEvents
var enabled := false

var _raised := false
## True when the camera was raised by the C toggle, so an unrelated
## right-mouse release cannot lower it.
var _toggled := false
var _review_left := 0.0
## Counted anomalies with a visible resolution beat. They remain frozen while
## the opaque developed print is up, then resolve as the bare-eyed view returns.
var _review_resolves: Array[PhotoAnomaly] = []
var _pending_risk := false
var _hinted := false
var _snap_viewport: SubViewport
var _snap_cam: Camera3D
var _photo: TextureRect
var _review_back: ColorRect
var _paper: PhotoPaper
var _marks: EvidenceMarks
var _reticle: PhotoReticle
var _mask: ViewfinderMask
var _flash: ColorRect
var _shutter: AudioStreamPlayer
var _focus_tick: AudioStreamPlayer
var _focus_scan_left := 0.0
var _capturing := false
var _static: AudioStreamPlayer
var _click: AudioStreamPlayer
var _click_left := 0.0
var _warm_tick_left := 0.0
var _proximity := 0.0
var _proximity_target := 0.0
var _proximity_los := 0.0
var _proximity_los_target := 0.0
var _proximity_scan_left := 0.0

signal photo_documented(anomaly_id: String, count: int, required: int,
	caption: String)
signal first_raise()
## True while the camera is up — main hides the whole HUD so only the
## viewfinder exists (owner, 2026-08-20).
signal raised_changed(on: bool)
## 0..1 nearness of the closest undocumented anomaly, smoothed; the OSD
## frame renders it as interference.
## `value` includes through-wall detections at reduced weight (drives the
## ambient interference, static and clicks); `los` counts only anomalies
## with actual line of sight, so the explicit HUD warning never points at a
## thing in the next room.
signal proximity_changed(value: float, los: float)


func _ready() -> void:
	layer = 2
	_mask = ViewfinderMask.new()
	_mask.visible = false
	add_child(_mask)
	_reticle = PhotoReticle.new()
	_reticle.visible = false
	add_child(_reticle)
	# Review: a plain black card with the print centred on it. Anchors are
	# never mixed with the photo's top-left offsets, so the two controls cannot
	# compound each other's layout and drift down/right.
	_review_back = ColorRect.new()
	_review_back.color = Color.BLACK
	_review_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_review_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_review_back.visible = false
	add_child(_review_back)
	_paper = PhotoPaper.new()
	_paper.visible = false
	add_child(_paper)
	_photo = TextureRect.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# A very slight warm cast keeps the developed image from reading like a
	# second digital viewport laid over the game.
	_photo.modulate = Color(1.0, 0.985, 0.955, 1.0)
	_photo.visible = false
	add_child(_photo)
	_marks = EvidenceMarks.new()
	_marks.visible = false
	add_child(_marks)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_shutter = AudioStreamPlayer.new()
	_shutter.bus = SoundBank.GAME_BUS
	_shutter.stream = SoundBank.key_click()
	_shutter.volume_db = -6.0
	add_child(_shutter)
	_focus_tick = AudioStreamPlayer.new()
	_focus_tick.bus = SoundBank.GAME_BUS
	_focus_tick.stream = SoundBank.key_click()
	_focus_tick.volume_db = -9.0
	_focus_tick.pitch_scale = 1.9
	add_child(_focus_tick)
	_click = AudioStreamPlayer.new()
	_click.bus = SoundBank.GAME_BUS
	_click.stream = SoundBank.key_click()
	_click.volume_db = -12.0
	_click.pitch_scale = 1.15
	add_child(_click)
	_static = AudioStreamPlayer.new()
	_static.bus = SoundBank.GAME_BUS
	_static.stream = SoundBank.static_hiss()
	_static.volume_db = STATIC_DB_SILENT
	add_child(_static)


func _allowed() -> bool:
	if not enabled or player == null or not is_instance_valid(player):
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if player.is_charging():
		return false
	return run != null and not run.ended and not run.suspended \
		and not run.blackout and not run.watching


## Trackpad-first controls: C toggles the camera, Space is the shutter.
## Mouse users get the same through hold-RMB / LMB. Listens in _input, not
## _unhandled_input: Space doubles as ui_accept, so any Control that
## happened to hold focus swallowed the shutter before it arrived
## (owner report, 2026-08-20). _allowed() gates everything on captured-
## mouse gameplay, so menus never see a stolen key.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			if _raised:
				_lower()
				get_viewport().set_input_as_handled()
			elif _allowed():
				_raise(true)
				get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_SPACE and _can_shoot():
			_take_photo()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and _allowed():
				_raise()
			elif not event.pressed and not _toggled:
				_lower()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
				and _can_shoot():
			_take_photo()


func _can_shoot() -> bool:
	return _raised and not _capturing and _review_left <= 0.0 and _allowed()


func _process(dt: float) -> void:
	if _raised and not _allowed():
		_lower()
	# Autofocus: the viewfinder knows when something wrong is framed. With the
	# proximity interference saying "this room", the raised camera runs hot
	# and cold: the brackets close and the tick quickens as the aim passes
	# nearer the thing — a converging search, not a blind pixel hunt — and
	# bite fully when it is framed. The only way photo-only writing can be
	# found at all.
	if _raised and not _capturing and _review_left <= 0.0:
		_focus_scan_left -= dt
		if _focus_scan_left <= 0.0:
			_focus_scan_left = 0.12
			var found := not _captured_anomalies().is_empty()
			if found and not _reticle.focused:
				_focus_tick.pitch_scale = 1.9
				_focus_tick.volume_db = -9.0
				_focus_tick.play()
			_reticle.focused = found
			_reticle.warmth = 1.0 if found else _aim_warmth()
		if _reticle.warmth > 0.05 and not _reticle.focused:
			_warm_tick_left -= dt
			if _warm_tick_left <= 0.0:
				_warm_tick_left = lerpf(0.85, 0.14, _reticle.warmth)
				_focus_tick.pitch_scale = lerpf(1.3, 1.75, _reticle.warmth)
				_focus_tick.volume_db = lerpf(-20.0, -11.0, _reticle.warmth)
				_focus_tick.play()
	elif _reticle.focused or _reticle.warmth > 0.0:
		_reticle.focused = false
		_reticle.warmth = 0.0
	if _review_left > 0.0:
		_review_left -= dt
		if _review_left <= 0.0:
			_photo.visible = false
			_review_back.visible = false
			_paper.visible = false
			_marks.visible = false
			# The shot ends the stance: show the print, then put the
			# camera down (owner, 2026-08-20). Whatever answers the
			# photograph is met with bare eyes.
			_lower()
			_release_review_resolutions()
			if _pending_risk:
				_pending_risk = false
				_roll_risk()
	_update_proximity(dt)


func _update_proximity(dt: float) -> void:
	_proximity_scan_left -= dt
	if _proximity_scan_left <= 0.0:
		_proximity_scan_left = PROXIMITY_SCAN
		var scanned := _scan_proximity()
		_proximity_target = scanned.x
		_proximity_los_target = scanned.y
	var was := _proximity
	_proximity = move_toward(_proximity, _proximity_target, dt * 1.6)
	_proximity_los = move_toward(_proximity_los, _proximity_los_target,
		dt * 1.6)
	# Detector clicks: sparse far out, a rattle close in. Lower-pitched than
	# the framing tick so the two read as different events.
	if _proximity > 0.05:
		_click_left -= dt
		if _click_left <= 0.0:
			_click_left = lerpf(1.3, 0.16, _proximity) * randf_range(0.8, 1.2)
			_click.pitch_scale = randf_range(1.05, 1.25)
			_click.volume_db = lerpf(-16.0, -8.0, _proximity)
			_click.play()
	else:
		_click_left = 0.0
	if absf(_proximity - was) > 0.002 or (_proximity == 0.0 and was != 0.0):
		proximity_changed.emit(_proximity, _proximity_los)
		if _proximity > 0.01:
			if not _static.playing:
				_static.play()
			_static.volume_db = lerpf(STATIC_DB_SILENT, STATIC_DB_FULL,
				pow(_proximity, 0.7))
		elif _static.playing:
			_static.stop()


## Nearness of the closest undocumented live anomaly to the lens, 0..1.
## x: including through-wall hits at reduced weight (the ambient channel).
## y: line-of-sight hits only (the explicit warning channel) — "here" must
## mean THIS room, or the hunt turns into searching the wrong one.
func _scan_proximity() -> Vector2:
	if director == null or player == null or not is_instance_valid(player) \
			or not enabled or run == null or run.ended or run.suspended \
			or run.blackout or run.watching:
		return Vector2.ZERO
	var cam := player.cam
	var space := player.get_world_3d().direct_space_state
	var best := 0.0
	var best_los := 0.0
	for anomaly in director.capturable():
		var points := anomaly.photo_points()
		if points.is_empty():
			continue
		var point: Vector3 = points[0]
		var d := cam.global_position.distance_to(point)
		if d >= PROXIMITY_RANGE:
			continue
		var k := 1.0 - clampf((d - PROXIMITY_NEAR)
			/ (PROXIMITY_RANGE - PROXIMITY_NEAR), 0.0, 1.0)
		var excludes: Array[RID] = [player.get_rid()]
		excludes.append_array(anomaly.occlusion_excludes())
		var query := PhysicsRayQueryParameters3D.create(
			cam.global_position, point, 1, excludes)
		var hit := space.intersect_ray(query)
		var occluded := not hit.is_empty() and Vector3(hit["position"]) \
			.distance_to(point) > OCCLUSION_TOLERANCE
		# The wrong side of a writing wall is never line of sight, however
		# close the ray lands to the floating label.
		if not _on_facing_side(anomaly, cam.global_position):
			occluded = true
		if occluded:
			k *= PROXIMITY_OCCLUDED
		else:
			best_los = maxf(best_los, k)
		best = maxf(best, k)
	return Vector2(best, best_los)


## How close the aim passes to the nearest findable anomaly, 0..1. Facing
## and occlusion respected, angle-driven: warmth is for converging on the
## spot, the proximity channel already said "this room".
func _aim_warmth() -> float:
	if director == null or player == null:
		return 0.0
	var cam := player.cam
	var space := player.get_world_3d().direct_space_state
	var forward := -cam.global_transform.basis.z
	var best := 0.0
	for anomaly in director.capturable():
		var points := anomaly.photo_points()
		if points.is_empty():
			continue
		if not _on_facing_side(anomaly, cam.global_position):
			continue
		var point: Vector3 = points[0]
		var to_point := point - cam.global_position
		if to_point.length() > anomaly.capture_distance():
			continue
		var excludes: Array[RID] = [player.get_rid()]
		excludes.append_array(anomaly.occlusion_excludes())
		var query := PhysicsRayQueryParameters3D.create(
			cam.global_position, point, 1, excludes)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and Vector3(hit["position"]) \
				.distance_to(point) > OCCLUSION_TOLERANCE:
			continue
		var dot := forward.dot(to_point.normalized())
		best = maxf(best, clampf((dot - 0.2) / 0.75, 0.0, 1.0))
	return best


## True when the camera is on the side a directional anomaly faces (always
## true for free-standing ones).
func _on_facing_side(anomaly: PhotoAnomaly, from: Vector3) -> bool:
	var normal := anomaly.facing_normal()
	if normal == Vector3.ZERO:
		return true
	var points := anomaly.photo_points()
	if points.is_empty():
		return true
	var world_normal := anomaly.global_transform.basis * normal
	return (from - points[0]).dot(world_normal) > 0.0


func _raise(toggled := false) -> void:
	if _raised:
		return
	_raised = true
	_toggled = toggled
	player.photo_aim = true
	# Through the lens you see the truth: the raised viewfinder renders the
	# photo-only layer live and DROPS the eye-only layer, so hidden writing
	# appears while a MISSING prop vanishes. The eye never sees the first
	# and always sees the second; the print-only layer stays for the film.
	player.cam.cull_mask |= PhotoAnomaly.PHOTO_LAYER
	player.cam.cull_mask &= ~PhotoAnomaly.EYE_ONLY_LAYER
	_mask.visible = true
	_reticle.visible = true
	raised_changed.emit(true)
	if not _hinted:
		_hinted = true
		first_raise.emit()


func _lower() -> void:
	if not _raised:
		return
	_raised = false
	_toggled = false
	if player != null and is_instance_valid(player):
		player.photo_aim = false
		player.cam.cull_mask &= ~PhotoAnomaly.PHOTO_LAYER
		player.cam.cull_mask |= PhotoAnomaly.EYE_ONLY_LAYER
	_mask.visible = false
	_reticle.visible = false
	raised_changed.emit(false)


func _take_photo() -> void:
	if not _raised:
		return
	_capturing = true
	_shutter.pitch_scale = randf_range(1.35, 1.5)
	_shutter.play()
	_flash.color = Color(1, 1, 1, 0.85)
	var fade := create_tween()
	fade.tween_property(_flash, "color:a", 0.0, FLASH_SECONDS * 3.0)
	# Judge the framing from the live camera at shutter time, before the
	# render — what you saw is what you shot.
	var captured := _captured_anomalies()
	# Screen positions at shutter time, for the evidence circles the review
	# draws — the investigator marks the print, so even an easy-to-miss
	# wrongness is legible once it is on film.
	var marks: Array[Rect2] = []
	var cam := player.cam
	for anomaly in captured:
		if director == null or director._documented.has(anomaly.id):
			continue
		var pts := anomaly.photo_points()
		var lo := Vector2.INF
		var hi := -Vector2.INF
		for point in pts:
			if cam.is_position_behind(point):
				continue
			var sp := cam.unproject_position(point)
			lo = lo.min(sp)
			hi = hi.max(sp)
		if lo.x > hi.x:
			continue
		var centre := (lo + hi) * 0.5
		var radius := maxf(70.0, (hi - lo).length() * 0.8 + 60.0)
		marks.append(Rect2(centre, Vector2(radius, radius * 0.78)))
	var image := await _render_snapshot()
	_capturing = false
	if image != null:
		_photo.texture = ImageTexture.create_from_image(image)
		# Black card, centred print at exactly the live viewfinder's size; the
		# viewfinder chrome leaves with it. The same covered-image transform maps
		# the evidence marks, so annotations cannot drift away from the image.
		var review_rect := _review_rect()
		_paper.photo_rect = review_rect
		_photo.position = review_rect.position
		_photo.size = review_rect.size
		_review_back.visible = true
		_paper.visible = true
		_photo.visible = true
		_mask.visible = false
		_reticle.visible = false
		var source_size := Vector2(image.get_size())
		var scale := maxf(review_rect.size.x / source_size.x,
			review_rect.size.y / source_size.y)
		var crop := (source_size * scale - review_rect.size) * 0.5
		for i in marks.size():
			var m := marks[i]
			marks[i] = Rect2(m.position * scale + review_rect.position - crop,
				m.size * scale)
	_review_left = REVIEW_SECONDS
	var counted := false
	for anomaly in captured:
		if director != null and director.mark_documented(anomaly.id):
			counted = true
			if anomaly.resolves_after_review():
				_review_resolves.append(anomaly)
			else:
				anomaly.resolve()
			photo_documented.emit(anomaly.id, director.documented_count(),
				director.required_count(), anomaly.count_caption())
	# The ternary must stay typed: `[] ` unifies the whole expression to a
	# plain Array, and assigning that to Array[Rect2] is a runtime error
	# that also skipped the risk roll (found in a play log, 2026-08-20).
	var none: Array[Rect2] = []
	_marks.marks = marks if counted else none
	_marks.visible = _photo.visible and not _marks.marks.is_empty()
	# Only evidence provokes; snapshots of nothing stay free.
	_pending_risk = counted


func _release_review_resolutions() -> void:
	for anomaly in _review_resolves:
		if is_instance_valid(anomaly):
			anomaly.resolve()
	_review_resolves.clear()


## The developed print occupies the same window the player framed. Deriving
## both axes from the viewport keeps it horizontally and vertically centred at
## every supported window shape without mixing anchors and offsets.
func _review_rect() -> Rect2:
	var viewport_size := Vector2(get_viewport().size)
	var window_size := viewport_size * Vector2(ViewfinderMask.WINDOW_W,
		ViewfinderMask.WINDOW_H)
	return Rect2((viewport_size - window_size) * 0.5, window_size)


func _captured_anomalies() -> Array[PhotoAnomaly]:
	var out: Array[PhotoAnomaly] = []
	if director == null or player == null:
		return out
	var cam := player.cam
	var space := player.get_world_3d().direct_space_state
	var forward := -cam.global_transform.basis.z
	for anomaly in director.capturable():
		var points := anomaly.photo_points()
		if points.is_empty():
			continue
		if not _on_facing_side(anomaly, cam.global_position):
			continue
		var excludes: Array[RID] = [player.get_rid()]
		excludes.append_array(anomaly.occlusion_excludes())
		var all_good := true
		for point in points:
			var to_point: Vector3 = point - cam.global_position
			if to_point.length() > anomaly.capture_distance() \
					or not cam.is_position_in_frustum(point) \
					or forward.dot(to_point.normalized()) < FRAME_DOT:
				all_good = false
				break
			var query := PhysicsRayQueryParameters3D.create(
				cam.global_position, point, 1, excludes)
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and Vector3(hit["position"]) \
					.distance_to(point) > OCCLUSION_TOLERANCE:
				all_good = false
				break
		if all_good:
			out.append(anomaly)
	return out


## One off-screen render with the photo layer enabled. The print sees the
## writing; the screen never does.
func _render_snapshot() -> Image:
	var viewport := get_viewport()
	if _snap_viewport == null:
		_snap_viewport = SubViewport.new()
		_snap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_snap_viewport.transparent_bg = false
		add_child(_snap_viewport)
		_snap_cam = Camera3D.new()
		_snap_viewport.add_child(_snap_cam)
	_snap_viewport.size = viewport.size
	_snap_viewport.world_3d = player.get_world_3d()
	var cam := player.cam
	_snap_cam.global_transform = cam.global_transform
	_snap_cam.fov = cam.fov
	_snap_cam.near = cam.near
	_snap_cam.far = cam.far
	_snap_cam.cull_mask = (cam.cull_mask | PhotoAnomaly.PHOTO_LAYER
		| PhotoAnomaly.PRINT_LAYER) & ~PhotoAnomaly.EYE_ONLY_LAYER
	_snap_cam.current = true
	_snap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if _snap_viewport == null:
		return null
	return _snap_viewport.get_texture().get_image()


func _roll_risk() -> void:
	var roll := randf()
	if roll < RISK_NOTHING:
		return
	if roll < RISK_NOTHING + RISK_ENVIRONMENT:
		if events != null:
			events.photo_response()
	elif figures != null:
		figures.force_encounter(ENCOUNTER_DELAY)


## The eyecup: raising the camera seriously constricts vision to the
## viewfinder window. The shader measures its falloff in screen pixels and
## clamps it to the available surround, which keeps every side continuous at
## 720p, ultrawide and narrow window sizes.
class ViewfinderMask extends ColorRect:
	## Fraction of the viewport the window occupies.
	const WINDOW_W := 0.60
	const WINDOW_H := 0.66

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		color = Color.WHITE
		var shader_material := ShaderMaterial.new()
		shader_material.shader = preload("res://shaders/viewfinder_mask.gdshader")
		shader_material.set_shader_parameter("window_fraction",
			Vector2(WINDOW_W, WINDOW_H))
		material = shader_material


## A physical print beneath the developed image: warm photographic stock,
## imperfect fibres, a fine cut edge and a soft shadow against the black
## review table. It is a sibling behind TextureRect, so the image naturally
## masks the paper texture inside the exposure area.
class PhotoPaper extends Control:
	var photo_rect := Rect2():
		set(value):
			photo_rect = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if photo_rect.size.x <= 0.0 or photo_rect.size.y <= 0.0:
			return
		var border := clampf(minf(size.x, size.y) * 0.021, 12.0, 34.0)
		var paper_rect := photo_rect.grow(border)
		var shadow_offset := Vector2(border * 0.28, border * 0.38)
		# Layered, low-alpha silhouettes approximate a soft contact shadow without
		# requiring a blur viewport or a full-screen post effect.
		for i in range(10, 0, -1):
			var spread := border * 0.055 * float(i)
			var shadow_rect := paper_rect.grow(spread)
			shadow_rect.position += shadow_offset
			draw_rect(shadow_rect, Color(0.0, 0.0, 0.0,
				0.010 + float(10 - i) * 0.003))
		# Fibre stock is deliberately warm rather than screen-white. A slightly
		# darker lower edge gives the sheet thickness when it catches the light.
		draw_rect(paper_rect, Color(0.955, 0.942, 0.905, 1.0))
		draw_rect(paper_rect, Color(0.72, 0.69, 0.62, 0.85), false, 1.0)
		draw_line(paper_rect.position + Vector2(1.0, paper_rect.size.y - 1.0),
			paper_rect.end - Vector2(1.0, 1.0),
			Color(0.55, 0.51, 0.43, 0.42), 2.0)
		# Deterministic microscopic fibres keep the border from reading as a flat
		# UI rectangle. The photo sibling covers any strokes inside the exposure.
		for i in 150:
			var xi := (i * 73 + i * i * 19 + 41) % 997
			var yi := (i * 151 + i * i * 7 + 83) % 991
			var p := paper_rect.position + Vector2(
				float(xi) / 997.0 * paper_rect.size.x,
				float(yi) / 991.0 * paper_rect.size.y)
			var fibre := 0.8 + float((i * 37) % 11) * 0.16
			draw_line(p, p + Vector2(fibre, 0.0),
				Color(0.36, 0.32, 0.25, 0.055), 1.0)
		# A hairline around the exposure reads as the dark emulsion/paper seam.
		draw_rect(photo_rect.grow(1.5), Color(0.12, 0.11, 0.095, 0.72),
			false, 2.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Hand-drawn red circles over the review print, one per counted anomaly.
## Rect2: position = screen centre, size.x/size.y = ellipse radii.
class EvidenceMarks extends Control:
	var marks: Array[Rect2] = []:
		set(value):
			marks = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var ink := Color(0.85, 0.14, 0.1, 0.9)
		for mark in marks:
			var centre := mark.position
			var radii := mark.size
			# Two slightly misregistered passes read as a marker, not UI.
			for pass_i in 2:
				var jog := Vector2(2.5, -1.5) * float(pass_i)
				var prev := Vector2.INF
				for i in 33:
					var a := TAU * float(i) / 32.0
					var wobble := 1.0 + 0.05 * sin(a * 3.0 + float(pass_i))
					var p := centre + jog + Vector2(cos(a) * radii.x,
						sin(a) * radii.y) * wobble
					if prev != Vector2.INF:
						draw_line(prev, p, ink, 3.5 - float(pass_i))
					prev = p


## Viewfinder framing marks while aiming — thin OSD brackets around the
## centre third, in the HUD's phosphor ink.
class PhotoReticle extends Control:
	var focused := false:
		set(value):
			if focused != value:
				focused = value
				queue_redraw()
	var warmth := 0.0:
		set(value):
			if absf(warmth - value) > 0.01:
				warmth = value
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var s := size
		var k := 1.0 if focused else warmth
		var c := VhsOsd.INK if focused else VhsOsd.INK_DIM.lerp(VhsOsd.INK,
			warmth * 0.7)
		var w := s.x * lerpf(0.30, 0.24, k)
		var h := s.y * lerpf(0.26, 0.21, k)
		var arm := minf(s.x, s.y) * 0.035
		var cx := s.x * 0.5
		var cy := s.y * 0.5
		if focused:
			var f: Font = VhsOsd.FONT
			var fs := 30
			var tw := f.get_string_size("FOCUS", HORIZONTAL_ALIGNMENT_LEFT,
				-1, fs).x
			VhsOsd.draw_osd_string(self, f,
				Vector2(cx - tw * 0.5, cy + h * 0.5 + fs * 1.2),
				"FOCUS", fs, VhsOsd.INK)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1),
				Vector2(-1, 1), Vector2(1, 1)]:
			var px := cx + w * 0.5 * corner.x
			var py := cy + h * 0.5 * corner.y
			draw_line(Vector2(px, py), Vector2(px - arm * corner.x, py), c, 2.0)
			draw_line(Vector2(px, py), Vector2(px, py - arm * corner.y), c, 2.0)
		# Centre metering patch: a faint translucent square with a fine
		# cross, the way an optical finder marks its sweet spot.
		var patch := minf(s.x, s.y) * 0.055
		draw_rect(Rect2(cx - patch, cy - patch, patch * 2.0, patch * 2.0),
			Color(1, 1, 1, 0.10 if not focused else 0.16))
		draw_rect(Rect2(cx - patch, cy - patch, patch * 2.0, patch * 2.0),
			c, false, 1.5)
		draw_line(Vector2(cx - patch * 0.55, cy),
			Vector2(cx + patch * 0.55, cy), c, 1.5)
		draw_line(Vector2(cx, cy - patch * 0.55),
			Vector2(cx, cy + patch * 0.55), c, 1.5)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
