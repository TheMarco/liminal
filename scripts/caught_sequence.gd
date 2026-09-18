extends CanvasLayer
## Presentation only: the run is already over. The eye falls, not the player
## collision body. The actual catcher looms over the fallen viewpoint; no
## replacement apparition, white flash, or change to the chosen VHS mode.

signal finished

const DURATION := 2.50
const FALL_START := 0.12
const LAND_AT := 0.72
const SETTLED_AT := 1.08
const LOOM_AT := 1.50
const FADE_START := 1.75
const BLACK_AT := 2.30
const FLOOR_EYE_HEIGHT := 0.23
const CAMERA_RADIUS := 0.16
const RETREAT := 0.26
## A clear forward bend (~24 degrees), visible from the floor. The former
## nine-degree lean still presented the layered body almost edge-on.
const LEAN := 0.42
## Blackout attacks still belong to something unseen, not a staged reveal.
const UNSEEN_DURATION := 0.82

var _player: Player
var _figure: ShadowFigure
var _camera_pose := Transform3D.IDENTITY
var _camera_fov := 75.0
var _process_was := true
var _physics_was := true
var _input_was := false
var _motion := 1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _floor_eye := Vector3.ZERO
var _figure_pose := Transform3D.IDENTITY
var _figure_physics_was := false
var _gloom_was_visible := false
var _lean_axis := Vector3.RIGHT
var _roll_side := 1.0
var _visible_catch := false
var _duration := DURATION
var _elapsed := 0.0
var _running := false
var _restored := false
var _curtain: ColorRect


func begin(subject: Player, figure: ShadowFigure = null) -> void:
	layer = 110
	_player = subject
	_figure = figure
	_camera_pose = subject.cam.global_transform
	_camera_fov = subject.cam.fov
	_visible_catch = is_instance_valid(figure)
	_duration = DURATION if _visible_catch else UNSEEN_DURATION
	_process_was = subject.is_processing()
	_physics_was = subject.is_physics_processing()
	_input_was = subject.is_processing_unhandled_input()
	_motion = clampf(subject.head_bob_strength, 0.0, 1.0)
	subject.stop_charging()
	subject.stop_motion_audio()
	subject.clear_sprint_toggle()
	subject.set_rumble(0.0)
	subject.velocity = Vector3.ZERO
	subject.set_process(false)
	subject.set_physics_process(false)
	subject.set_process_unhandled_input(false)
	if is_instance_valid(figure):
		_figure_pose = figure.global_transform
		_figure_physics_was = figure.is_physics_processing()
		figure.set_physics_process(false)
		_from = figure.global_position
		# Finish only the real catcher's final approach, retaining its floor and
		# wall clearance. Do not move it through a desk to improve the framing.
		var toward := subject.global_position - _from
		toward.y = 0.0
		_to = _from + toward.normalized() * maxf(toward.length() - 0.80, 0.0)
		if figure._move_query == null or not figure._clear_travel(_from, _to):
			_to = _from
		_floor_eye = _plan_floor_eye(toward.normalized())
		var lean_toward := _floor_eye - _to
		lean_toward.y = 0.0
		if lean_toward.length_squared() > 0.0001:
			_lean_axis = Vector3.UP.cross(lean_toward.normalized())
		_roll_side = -1.0 if _camera_pose.basis.x.dot(_from - subject.global_position) < 0.0 else 1.0
		if figure._gloom != null:
			_gloom_was_visible = figure._gloom.visible
			figure._gloom.visible = false
		if figure._walker != null:
			figure._walker.set_closeup_mode(true)
	_curtain = ColorRect.new()
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.color = Color(0, 0, 0, 0)
	add_child(_curtain)
	_running = true


func _process(dt: float) -> void:
	if not _running:
		return
	_elapsed = minf(_elapsed + dt, _duration)
	_sample(_elapsed)
	if is_instance_valid(_figure):
		_figure._animate(dt, false)
	if _elapsed >= _duration:
		_running = false
		finished.emit()


func _sample(seconds: float) -> void:
	if not is_instance_valid(_player):
		return
	if not _visible_catch:
		_sample_unseen(seconds)
		return
	var close := smoothstep(0.0, LAND_AT, seconds)
	var loom := smoothstep(LAND_AT - 0.12, LOOM_AT, seconds)
	if is_instance_valid(_figure):
		# Tilt about the feet. GhostVisual continues to own its billboard yaw
		# and flipbook, so the looming pose never flattens or freezes its body.
		_figure.global_transform = Transform3D(
			Basis(_lean_axis, LEAN * loom) * _figure_pose.basis,
			_from.lerp(_to, close))
	# Accelerate into the fall, then one small settling recoil. No repeated
	# shake, lens zoom, or instant 180-degree snap for side/rear catches.
	var fall := pow(clampf((seconds - FALL_START) / (LAND_AT - FALL_START), 0.0, 1.0), 2.0)
	var settle := sin(clampf((seconds - LAND_AT) / (SETTLED_AT - LAND_AT), 0.0, 1.0) * PI)
	var eye := _camera_pose.origin.lerp(_floor_eye, fall * _motion)
	# Recoil travels back up the already-cleared fall segment, not into a prop.
	eye = eye.lerp(_camera_pose.origin, 0.025 * settle * _motion)
	var basis := _camera_pose.basis
	if _motion > 0.0:
		var focus := _to + Vector3.UP * 1.6
		if is_instance_valid(_figure):
			focus = _figure.global_transform * Vector3(0, _figure._eye_h, 0)
		var gaze := focus - eye
		# With an exactly overhead actor, retain a tiny horizontal component so
		# look-at never receives parallel forward/up vectors.
		if Vector2(gaze.x, gaze.z).length_squared() < 0.0001:
			gaze += -_camera_pose.basis.z * 0.02
			gaze.x += 0.001
		var fallen := Basis.looking_at(gaze, Vector3.UP)
		fallen *= Basis(Vector3.BACK, (0.24 + 0.035 * settle) * _roll_side)
		basis = basis.slerp(fallen, smoothstep(0.06, SETTLED_AT, seconds) * _motion)
	_player.cam.global_transform = Transform3D(basis, eye)
	_curtain.color.a = smoothstep(FADE_START, BLACK_AT, seconds)


func _plan_floor_eye(away: Vector3) -> Vector3:
	var start := _camera_pose.origin
	var goal := start + away * RETREAT
	goal.y = _player.global_position.y + FLOOR_EYE_HEIGHT
	var space := _player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_player.get_rid()]
	# Respect the actual support height on stairs, ramps and raised platforms.
	var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(goal.x, start.y, goal.z), Vector3(goal.x, goal.y - 1.5, goal.z), 1, excluded))
	if not support.is_empty() and (support.normal as Vector3).y > 0.5:
		goal.y = (support.position as Vector3).y + FLOOR_EYE_HEIGHT
	if is_instance_valid(_player._water_fx):
		# A Poolrooms theme alone does not imply water here: use its real mesh
		# footprint, rejecting coping/piers. Include the short retreat segment
		# so landing just beyond a pool edge cannot pass through water en route.
		for i in 5:
			var water_y := _player._water_fx.surface_height(start.lerp(goal, float(i) / 4.0), excluded)
			goal.y = maxf(goal.y, water_y + FLOOR_EYE_HEIGHT)
	goal.y = minf(goal.y, start.y)
	var sphere := SphereShape3D.new()
	sphere.radius = CAMERA_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = excluded
	query.transform = Transform3D(Basis.IDENTITY, start)
	if not space.intersect_shape(query, 1).is_empty():
		return start
	query.motion = goal - start
	var safe := float(space.cast_motion(query)[0])
	# Margin protects the near plane at the contact, including on angled walls.
	return start.lerp(goal, maxf(safe - 0.02, 0.0)) if safe < 1.0 else goal


func _sample_unseen(seconds: float) -> void:
	var grab := sin(clampf(seconds / 0.30, 0.0, 1.0) * PI)
	var slump := smoothstep(0.18, 0.67, seconds)
	var tilt := Basis.from_euler(Vector3(-0.018 * grab - 0.045 * slump,
		0.0, 0.035 * grab + 0.016 * slump) * _motion)
	_player.cam.global_transform = Transform3D(_camera_pose.basis * tilt,
		_camera_pose.origin + Vector3.DOWN * 0.075 * slump * _motion)
	_curtain.color.a = smoothstep(0.43, 0.67, seconds)


## Caller installs the results screen before removing the black curtain.
## Also runs on interrupted teardown so a retry never inherits a locked player.
func restore() -> void:
	if _restored:
		return
	_restored = true
	_running = false
	if is_instance_valid(_player):
		_player.cam.global_transform = _camera_pose
		_player.cam.fov = _camera_fov
		_player.set_process(_process_was)
		_player.set_physics_process(_physics_was)
		_player.set_process_unhandled_input(_input_was)
	if is_instance_valid(_figure):
		_figure.global_transform = _figure_pose
		_figure.set_physics_process(_figure_physics_was)
		if _figure._walker != null:
			_figure._walker.set_closeup_mode(false)
		if _figure._gloom != null:
			_figure._gloom.visible = _gloom_was_visible


func _exit_tree() -> void:
	restore()
