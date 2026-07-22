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
const ACCEL := 12.0
const GRAVITY := 16.0
const SENS := 0.0022
const CAM_H := 1.62
const GRAB_SETTLE_MS := 150   # mouse motion to swallow after taking the cursor

var cam: Camera3D
var world_seed := 0   # set by main; used to pick footstep surface per cell
var level_theme := 0  # set by main on level switch
var _bob := 0.0
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
var dev_spin := false     # dev: whip around every few seconds, for testing
var dev_walk := false     # dev: hold forward, for frame-pacing tests
var _spin_wait := 3.0
var _spin_left := 0.0
var _strafe := 0.0
var _sprinting := false


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
	add_child(cam)


func _ready() -> void:
	_prev_pos = global_position
	_curr_pos = global_position
	cam.current = true
	grab_look()
	# One continuous walking loop, faded with movement. The recordings are
	# whole strides at about two a second, so triggering them per step would
	# stack twenty overlapping feet.
	_walk_p = AudioStreamPlayer.new()
	_walk_p.volume_db = -60.0
	add_child(_walk_p)


## Move without the camera sweeping across the world to catch up — the
## interpolation would otherwise smear from the old position for a tick.
func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_prev_pos = to
	_curr_pos = to
	if cam != null:
		cam.global_position = to + Vector3(0, _cam_y, 0)


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
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(dt: float) -> void:
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
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED

	var wish := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		wish = (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	var flat := Vector3(velocity.x, 0, velocity.z)
	flat = flat.lerp(wish * speed, minf(1.0, ACCEL * dt))
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.6
	else:
		velocity.y -= GRAVITY * dt
	var vy_before := velocity.y
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position

	# landing dip
	if is_on_floor() and not _was_floor:
		_land = clampf(-vy_before * 0.02, 0.0, 0.15)

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
	cam.rotation = Vector3(_pitch, rotation.y, _roll)
	var hs := Vector2(velocity.x, velocity.z).length()
	cam.fov = lerpf(cam.fov, 83.0 if (_sprinting and hs > 4.0) else 77.0, minf(1.0, dt * 5.0))


## What you are walking on, per floor and per room — terrazzo in a terminal,
## carpet on the gate lounge islands within it, wet concrete down the works.
func _surface() -> String:
	var cellv := Vector2i(floori(global_position.x / 12.0), floori(global_position.z / 12.0))
	if world_seed == 0:
		return "carpet"
	match level_theme:
		1:
			return "carpet"
		2:
			return "concrete" if WorldGen.cell_style(world_seed, cellv, 2) == WorldGen.SEWER_DRY else "wet"
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
