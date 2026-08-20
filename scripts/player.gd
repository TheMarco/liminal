class_name Player
extends CharacterBody3D
## First-person controller: WASD + mouse look, sprint, subtle head bob.
## Built entirely in code — no scene file needed.
##
## The camera is top_level and is placed every RENDERED frame, interpolated
## between the last two physics positions. Physics ticks and frames do not
## line up, so a camera parented to the body advances 0 or 2 steps on some
## frames — which reads as choppy exactly when you walk and turn at once,
## because the mouse-driven rotation beside it is perfectly smooth.

const WALK_SPEED := 3.4
const SPRINT_SPEED := 6.2
## Sprint is a reserve, not a state: five seconds flat out, ten to fill back
## up. Partial recovery is spendable — the only lockout is after running the
## tank completely dry, and it lifts as soon as REARM seconds have returned.
## Without that floor an empty tank plus a held shift key oscillates between
## sprint and walk every physics tick.
const STAMINA_MAX := 5.0
const STAMINA_REGEN_RATE := STAMINA_MAX / 10.0
const STAMINA_REARM := 0.75
const ACCEL := 12.0
const GRAVITY := 16.0
const SENS := 0.0022
## Lowered 15% from the original 1.62m eye line. The collision capsule remains
## a full 1.8m tall; only the viewpoint changes, so clearance and movement stay
## identical while the player no longer reads as unusually tall.
const CAM_H := 1.377
const GRAB_SETTLE_MS := 150   # mouse motion to swallow after taking the cursor
const INTERACT_DIST := 3.2
## Interaction focus does not need to raycast at render rate. Thirty probes a
## second keeps the prompt responsive while avoiding duplicate queries on
## high-refresh displays.
const INTERACTION_SCAN_SECONDS := 1.0 / 30.0

## The torch is a resource, not a state you leave switched on. Its cell is
## deliberately generous enough for several encounters, but only the charging
## stations refill it. That turns darkness into route planning instead of a
## seven-second pause after every use.
const FLASH_ENERGY := 4.5
const FLASH_MAX := 20.0
const FLASH_CHARGE_TIME := 10.0
const FLASH_CHARGE_RATE := FLASH_MAX / FLASH_CHARGE_TIME
## Refuse to switch on for a useless flicker. Being told "not yet" is fairer
## than handing over a beam that dies in the half second you needed it.
const FLASH_MIN_START := 2.2
const FLASH_WARN := 2.5       # it starts to fail this long before it goes out

## Chest-deep water halves your pace and takes the spring out of the step. The
## Poolrooms are the only floor that sets `water_y`; everywhere else it stays
## far below the world and none of this costs anything.
const WADE_SPEED := 0.52
const WADE_ACCEL := 0.45
## Physics layer the pool ladders register on. Climbing is resolved with a
## point query rather than an Area3D on the player, so nothing else in the
## game has to grow a collision shape it did not need.
const LADDER_LAYER := 8
const CLIMB_SPEED := 2.1

signal interaction_prompt_changed(text: String)

var cam: Camera3D
var flashlight: SpotLight3D
var world_seed := 0   # set by main; used to pick footstep surface per cell
var level_theme := 0  # set by main on level switch
var _flash_charge := FLASH_MAX
var _charging_station: Node3D
var _charge_session_active := false
## World height of the water surface on this floor, or far below everything if
## the floor has no water. Set by main on every level switch.
var water_y := -1.0e9
var _on_ladder := false
var _was_submerged := false
var _wade_p: AudioStreamPlayer
var _splash_p: AudioStreamPlayer
var _flash_t := 0.0
var _bob := 0.0
## 0..1. A sealed lift car gives the eye nothing to move against, so the ride
## is sold almost entirely through this and the motor loop.
var _rumble := 0.0
var _rumble_t := 0.0
var _step_acc := 0.0
var _roll := 0.0
var _land := 0.0
var _was_floor := true
var _pitch := 0.0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _cam_y := CAM_H
var _grabbed := -10000
var _walk_p: AudioStreamPlayer
var _walk_surface := ""
var _walk_vol := -60.0
var _flash_click: AudioStreamPlayer
var dev_spin := false     # dev: whip around every few seconds, for testing
var dev_walk := false     # dev: hold forward, for frame-pacing tests
var _spin_wait := 3.0
var _spin_left := 0.0
var _strafe := 0.0
var _sprinting := false
## Mode-owned movement gate. Both current modes allow sprint; Descent observes
## `_sprinting` to turn the extra noise into attention pressure.
var allow_sprint := true
var _stamina := STAMINA_MAX
var _sprint_spent := false
## Owned by PhotoCamera: true while the camera is raised, for the FOV pull.
var photo_aim := false
var _focused: Interactable
var _focus_text := ""
var _interaction_scan_left := 0.0


func _init() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	cam = Camera3D.new()
	cam.top_level = true
	cam.position = Vector3(0, CAM_H, 0)
	cam.fov = 77.0
	cam.near = 0.05
	cam.far = 80.0
	# The eye never sees photo-only geometry; only the snapshot camera adds
	# this layer back.
	cam.cull_mask &= ~PhotoAnomaly.PHOTO_LAYER
	add_child(cam)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.10, -0.10, -0.06)
	flashlight.light_color = Color(0.88, 0.93, 1.0)
	flashlight.light_energy = 4.5
	flashlight.spot_range = 21.0
	flashlight.spot_angle = 46.0
	flashlight.spot_attenuation = 1.15
	flashlight.light_volumetric_fog_energy = 0.42
	flashlight.shadow_enabled = true
	flashlight.visible = false
	cam.add_child(flashlight)


func _ready() -> void:
	_prev_pos = global_position
	_curr_pos = global_position
	cam.current = true
	grab_look()
	# One continuous walking loop, faded with movement. The recordings are
	# whole strides at about two a second, so triggering them per step would
	# stack twenty overlapping feet.
	_walk_p = AudioStreamPlayer.new()
	_walk_p.bus = SoundBank.GAME_BUS
	_walk_p.volume_db = -60.0
	add_child(_walk_p)
	_flash_click = AudioStreamPlayer.new()
	_flash_click.bus = SoundBank.GAME_BUS
	_flash_click.stream = SoundBank.key_click()
	_flash_click.volume_db = -10.0
	add_child(_flash_click)
	# Water. Silent and idle on every floor that has none.
	_wade_p = AudioStreamPlayer.new()
	_wade_p.bus = SoundBank.GAME_BUS
	_wade_p.stream = Sfx.water_wade()
	_wade_p.volume_db = -60.0
	add_child(_wade_p)
	_splash_p = AudioStreamPlayer.new()
	_splash_p.bus = SoundBank.GAME_BUS
	_splash_p.volume_db = -6.0
	add_child(_splash_p)


## Move without the camera sweeping across the world to catch up — the
## interpolation would otherwise smear from the old position for a tick.
func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_prev_pos = to
	_curr_pos = to
	if cam != null:
		cam.global_position = to + Vector3(0, _cam_y, 0)


## Continuous low-frequency camera shake, held until it is set back to zero.
## Descent's lift ride owns this; nothing else currently drives it.
func set_rumble(amount: float) -> void:
	_rumble = clampf(amount, 0.0, 1.0)


## Take the mouse. Capturing it warps the cursor to the middle of the window,
## and that warp comes back as one enormous relative motion — so ignore what
## the mouse claims to have done for a moment afterwards, or pressing start
## flings your head at the ceiling.
func grab_look() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_grabbed = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Time.get_ticks_msec() - _grabbed < GRAB_SETTLE_MS:
			return
		rotate_y(-event.relative.x * SENS)
		_pitch = clampf(_pitch - event.relative.y * SENS, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		grab_look()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E:
		if is_instance_valid(_focused):
			_focused.interact(self)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F:
		set_flashlight(not flashlight.visible)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_flashlight(on: bool) -> void:
	if flashlight == null:
		return
	if on and is_charging():
		stop_charging()
	if on and _flash_charge < FLASH_MIN_START:
		# a dead click, so a refusal is legible rather than an unresponsive key
		if is_instance_valid(_flash_click):
			_flash_click.pitch_scale = 0.62
			_flash_click.volume_db = -16.0
			_flash_click.play()
		return
	if on:
		flashlight.light_energy = FLASH_ENERGY
	flashlight.visible = on
	if is_instance_valid(_flash_click):
		_flash_click.pitch_scale = 1.08 if on else 0.86
		_flash_click.volume_db = -10.0
		_flash_click.play()


## How much beam is left, 0..1. The HUD has nothing to show it with yet; the
## light failing in your hand is the readout.
func flashlight_charge() -> float:
	return _flash_charge / FLASH_MAX


## Sprint reserve left, 0..1, for the HUD meter.
func stamina() -> float:
	return _stamina / STAMINA_MAX


## True during the post-depletion lockout, so the meter can flash a refusal
## rather than leave a held shift key looking ignored.
func sprint_spent() -> bool:
	return _sprint_spent


## A checkpoint restores the player at an arrival elevator, not in the exact
## state of the death. Resource and motion state therefore reset together.
func reset_descent_resources() -> void:
	if is_charging():
		stop_charging()
	if flashlight != null:
		flashlight.visible = false
		flashlight.light_energy = FLASH_ENERGY
	_flash_charge = FLASH_MAX
	_flash_t = 0.0
	_stamina = STAMINA_MAX
	_sprint_spent = false
	velocity = Vector3.ZERO


func is_charging() -> bool:
	return _charge_session_active


func is_charging_at(station: Node) -> bool:
	return is_charging() and is_instance_valid(_charging_station) \
		and _charging_station == station


## Connect to a station without locking the player in place. E toggles the
## connection, F breaks it and raises the torch, and simply stepping away also
## breaks it. Charge enters the cell continuously, so every partial second is
## retained when danger forces the player to disconnect.
func start_charging(station: Node3D) -> bool:
	if station == null or _flash_charge >= FLASH_MAX - 0.001:
		return false
	set_flashlight(false)
	_charging_station = station
	_charge_session_active = true
	return true


func stop_charging(_completed := false) -> void:
	_charging_station = null
	_charge_session_active = false


## Burn the cell down while it is lit. The last couple of seconds visibly fail,
## so the torch going out is never a surprise — you get to decide whether to
## spend them or save enough to reach a station. A tiny clean-kill refund still
## rewards accuracy without making the stations optional.
func add_flashlight_charge(seconds: float) -> void:
	_flash_charge = minf(FLASH_MAX, _flash_charge + maxf(0.0, seconds))


func _update_flashlight(dt: float) -> void:
	if flashlight == null:
		return
	_flash_t += dt
	if is_charging():
		if not is_instance_valid(_charging_station) \
				or global_position.distance_to(_charging_station.global_position) > 3.1:
			stop_charging()
		else:
			_flash_charge = minf(FLASH_MAX,
				_flash_charge + dt * FLASH_CHARGE_RATE)
			if _flash_charge >= FLASH_MAX - 0.001:
				_flash_charge = FLASH_MAX
				stop_charging(true)
		return
	if not flashlight.visible:
		return
	_flash_charge = maxf(0.0, _flash_charge - dt)
	if _flash_charge <= 0.0:
		set_flashlight(false)
		return
	var left := _flash_charge / FLASH_WARN
	if left >= 1.0:
		flashlight.light_energy = FLASH_ENERGY
		return
	var dying := 1.0 - left
	var stutter := 1.0 - 0.42 * dying * maxf(0.0, sin(_flash_t * 27.0))
	flashlight.light_energy = FLASH_ENERGY * (0.48 + 0.52 * left) * stutter


func _physics_process(dt: float) -> void:
	_update_flashlight(dt)
	if dev_spin:
		if _spin_left > 0.0:
			var step := minf(_spin_left, dt * 9.0)
			rotate_y(step)
			_spin_left -= step
		else:
			_spin_wait -= dt
			if _spin_wait <= 0.0:
				_spin_wait = 5.0
				_spin_left = PI
	var input := Vector2.ZERO
	if dev_walk:
		input.y -= 1.0
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): input.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): input.x += 1.0
	if _sprint_spent and _stamina >= STAMINA_REARM:
		_sprint_spent = false
	var sprinting := allow_sprint and not _sprint_spent and _stamina > 0.0 \
		and Input.is_physical_key_pressed(KEY_SHIFT) and input != Vector2.ZERO
	if sprinting:
		_stamina = maxf(0.0, _stamina - dt)
		if _stamina <= 0.0:
			_sprint_spent = true
			sprinting = false
	else:
		_stamina = minf(STAMINA_MAX, _stamina + STAMINA_REGEN_RATE * dt)
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED

	# Chest deep in water you do not stride, and you certainly do not sprint.
	var submerged := global_position.y + 0.55 < water_y
	if submerged:
		speed *= WADE_SPEED

	var wish := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		wish = (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var flat := Vector3(velocity.x, 0, velocity.z)
	var accel := ACCEL * (WADE_ACCEL if submerged else 1.0)
	flat = flat.lerp(wish * speed, minf(1.0, accel * dt))
	velocity.x = flat.x
	velocity.z = flat.z
	# On a ladder the world stops pulling: forward climbs, back descends, and
	# stepping off the top is just walking forward onto the deck.
	_on_ladder = water_y > -1.0e8 and _ladder_here()
	if _on_ladder:
		velocity.y = -input.y * CLIMB_SPEED
		velocity.x *= 0.35
		velocity.z *= 0.35
	elif is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.6
	else:
		velocity.y -= GRAVITY * dt
		# Water resists a fall rather than arresting it, so dropping off a deck
		# lands you with a slump instead of a thud.
		if submerged and velocity.y < -2.2:
			velocity.y = lerpf(velocity.y, -2.2, minf(1.0, dt * 6.0))
	var vy_before := velocity.y
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position

	# landing dip
	if is_on_floor() and not _was_floor:
		_land = clampf(-vy_before * 0.02, 0.0, 0.15)

	_update_water_audio(dt, submerged)
	_was_floor = is_on_floor()
	_land = lerpf(_land, 0.0, minf(1.0, dt * 6.0))
	_strafe = input.x
	_sprinting = sprinting
	_update_walk(dt)

	# footsteps stay on the physics clock
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 0.4:
		_bob += dt * hs * 1.6
		_cam_y = CAM_H + sin(_bob * 2.0) * 0.035 - _land
		_step_acc += hs * dt
	else:
		_cam_y = lerpf(_cam_y, CAM_H - _land, minf(1.0, dt * 6.0))


## Place the camera for THIS frame: body position interpolated through the
## physics tick, look direction straight from the mouse. Both advance every
## frame, so walking while turning is smooth.
func _process(dt: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	cam.global_position = _prev_pos.lerp(_curr_pos, f) + Vector3(0, _cam_y, 0)
	_roll = lerpf(_roll, -_strafe * 0.022, minf(1.0, dt * 8.0))
	var tilt := 0.0
	if _rumble > 0.0:
		# Deliberately not random per frame: a lift is a machine with a period,
		# and white-noise jitter reads as a bad camera rather than as travel.
		_rumble_t += dt * 37.0
		cam.global_position += Vector3(
			sin(_rumble_t * 1.31) * 0.0090,
			sin(_rumble_t) * 0.0155,
			cos(_rumble_t * 0.79) * 0.0090) * _rumble
		tilt = sin(_rumble_t * 0.61) * 0.0045 * _rumble
	cam.rotation = Vector3(_pitch, rotation.y, _roll + tilt)
	_interaction_scan_left -= dt
	if _interaction_scan_left <= 0.0:
		_interaction_scan_left = INTERACTION_SCAN_SECONDS
		_scan_interaction()
	var hs := Vector2(velocity.x, velocity.z).length()
	var fov_target := 83.0 if (_sprinting and hs > 4.0) else 77.0
	if photo_aim:
		fov_target = 58.0
	cam.fov = lerpf(cam.fov, fov_target, minf(1.0, dt * 5.0))


func _scan_interaction() -> void:
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * INTERACT_DIST
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var next: Interactable
	if not hit.is_empty() and hit["collider"] is Interactable:
		var candidate := hit["collider"] as Interactable
		if candidate.enabled:
			next = candidate
	if next != _focused:
		if is_instance_valid(_focused):
			_focused.set_focused(false)
		_focused = next
		if is_instance_valid(_focused):
			_focused.set_focused(true)
	var text := _focused.prompt_text if is_instance_valid(_focused) else ""
	if text != _focus_text:
		_focus_text = text
		interaction_prompt_changed.emit(text)


## What you are walking on, per floor and per room — terrazzo in a terminal,
## carpet in the office and Annex, tile and concrete in institutions.
func _surface() -> String:
	var cellv := Vector2i(floori(global_position.x / WorldGen.CELL_SIZE), floori(global_position.z / WorldGen.CELL_SIZE))
	if world_seed == 0:
		return "carpet"
	match level_theme:
		1:
			return "carpet"
		2:
			return "carpet"
		4:
			return "carpet" if WorldGen.cell_style(world_seed, cellv, 4) == WorldGen.AIR_GATE else "marble"
		5:
			return "concrete"
		6:
			var st6 := WorldGen.cell_style(world_seed, cellv, 6)
			if st6 == WorldGen.SCH_BATHROOM or st6 == WorldGen.SCH_CAFETERIA \
					or st6 == WorldGen.SCH_ADMIN:
				return "marble"
			return "concrete"
		7:
			return "concrete" if WorldGen.cell_style(world_seed, cellv, 7) == WorldGen.MALL_SERVICE \
				else "marble"
		8:
			return "concrete"
		9:
			return "wet"
		10:
			return "concrete"
		11:
			return "wet"
	if WorldGen.cell_style(world_seed, cellv) == WorldGen.STYLE_GRAND:
		return "marble"
	return "carpet"


## Fade the walking loop with how fast you are actually moving, and pitch it
## up when running so the stride rate matches your legs.
func _update_walk(dt: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and hs > 0.5
	if moving:
		var surf := _surface()
		if surf != _walk_surface:
			_walk_surface = surf
			_walk_p.stream = Sfx.walk(surf)[0]
			_walk_p.play()
		elif not _walk_p.playing:
			_walk_p.play()
	_walk_vol = lerpf(_walk_vol, 0.0 if moving else -40.0, minf(1.0, dt * (14.0 if moving else 9.0)))
	if _walk_surface != "":
		_walk_p.volume_db = float(Sfx.walk(_walk_surface)[1]) + _walk_vol
		_walk_p.pitch_scale = clampf(hs / 3.4, 0.85, 1.7)
		if _walk_vol < -38.0 and not moving and _walk_p.playing:
			_walk_p.stop()


## Physics is disabled while a recording owns the camera, so the normal fade
## loop cannot observe the zeroed velocity. Cut movement loops explicitly at
## that boundary; normal physics restarts them only if movement resumes.
func stop_motion_audio() -> void:
	_walk_vol = -60.0
	if _walk_p != null:
		_walk_p.volume_db = -60.0
		_walk_p.stop()
	if _wade_p != null:
		_wade_p.volume_db = -60.0
		_wade_p.stop()


## Is the player standing in a pool ladder's climbable volume?
func _ladder_here() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position + Vector3(0, 0.9, 0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = LADDER_LAYER
	q.exclude = [get_rid()]
	return not space.intersect_point(q, 1).is_empty()


## Entering and leaving the water are events; wading through it is a loop that
## only speaks while you are actually shifting water. The loop is faded rather
## than started and stopped, because a hard cut on a body of water is the one
## thing that instantly reads as a sound effect.
func _update_water_audio(dt: float, submerged: bool) -> void:
	if _wade_p == null:
		return
	if submerged != _was_submerged:
		_was_submerged = submerged
		if water_y > -1.0e8 and _splash_p != null:
			var cue: Array = Sfx.water_enter() if submerged else Sfx.water_exit()
			_splash_p.stream = cue[0]
			_splash_p.volume_db = float(cue[1])
			_splash_p.play()
	var speed_now := Vector2(velocity.x, velocity.z).length()
	var want := -60.0
	if submerged and speed_now > 0.25:
		want = lerpf(-26.0, -11.0, clampf(speed_now / (WALK_SPEED * WADE_SPEED),
			0.0, 1.0))
	if submerged and not _wade_p.playing:
		_wade_p.play()
	elif not submerged and _wade_p.playing and _wade_p.volume_db <= -55.0:
		_wade_p.stop()
	_wade_p.volume_db = lerpf(_wade_p.volume_db, want, minf(1.0, dt * 5.0))
