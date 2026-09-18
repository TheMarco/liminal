extends CanvasLayer
## Perception beats after unnatural photographs and before hostile approach.
## No camera transforms, audio or saved-photo changes. Legacy apparitions wait
## through the warning; 3D walkers materialize in motion with contact grace.
## Phase uses paused gameplay time, never shader TIME. Hidden passes do no work.

const EFFECT_SHADER := preload("res://shaders/reality_aftershock.gdshader")
const PLAYBACK_SPEED := 1.5
# Authored timeline seconds; the complete pulse now takes 5.5 / 1.5 real seconds.
const DURATION := 5.5
const ATTACK := 0.65
const RELEASE_START := 1.65
const APPROACH_SECONDS := 1.25
const APPROACH_STRENGTH := 0.7
const REACTION_MARGIN := 0.10

var host: Node
var enabled := true
var debug_controls := false
var elapsed := DURATION
var pulse_count := 0
var _playback_speed := PLAYBACK_SPEED
var _strength_scale := 1.0
var _material: ShaderMaterial
var _copy: BackBufferCopy
var _overlay: ColorRect


func _ready() -> void:
	layer = 1 # World only; the HUD begins at layer 2, camera/menus above that.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = EFFECT_SHADER
	_overlay.material = _material
	add_child(_overlay)
	visible = false


static func envelope(seconds: float) -> float:
	if seconds <= 0.0 or seconds >= DURATION:
		return 0.0
	return smoothstep(0.0, ATTACK, seconds) * (1.0 - smoothstep(RELEASE_START, DURATION, seconds))


func presentation_allowed() -> bool:
	if host == null or not is_instance_valid(host) or not enabled:
		return false
	if host._switching or host._dying or host._quitting or host._descent_preparing:
		return false
	for modal in [host._title, host._descent_summary, host._descent_intro,
			host._photo_album, host._return_prompt, host._quit_prompt]:
		if is_instance_valid(modal):
			return false
	var active_run = host.run
	if is_instance_valid(host._realm_visit) and host._realm_visit.is_away():
		if not host._realm_visit.allows_perception_effect():
			return false
		active_run = host._photo_camera.run
	if is_instance_valid(active_run) and (active_run.ended or active_run.blackout
			or active_run.watching or active_run.suspended):
		return false
	var camera = host._photo_camera
	return camera == null or not (camera._raised or camera._capturing or camera._review_left > 0.0)


func trigger() -> void:
	if get_tree().paused or not presentation_allowed():
		return
	# One envelope only. A burst of callbacks cannot stack blur or extend a hit.
	if elapsed < DURATION:
		return
	_playback_speed = PLAYBACK_SPEED
	_strength_scale = 1.0
	elapsed = 0.0
	pulse_count += 1


func before_approach(figure: ShadowFigure) -> void:
	if not is_instance_valid(figure) or get_tree().paused or not presentation_allowed():
		return
	if elapsed >= DURATION:
		elapsed = 0.0
		_strength_scale = APPROACH_STRENGTH
		_playback_speed = DURATION / APPROACH_SECONDS
		pulse_count += 1
	else:
		# A photograph or another figure may already own the pulse. Finish that
		# same trajectory sooner instead of stacking or restarting the distortion.
		_playback_speed = maxf(_playback_speed, (DURATION - elapsed) / APPROACH_SECONDS)
	if not figure.use_walker_prototype:
		figure.hold_approach((DURATION - elapsed) / _playback_speed + REACTION_MARGIN)


func cancel() -> void:
	elapsed = DURATION
	visible = false
	if _material != null:
		_material.set_shader_parameter("strength", 0.0)


func _process(dt: float) -> void:
	if get_tree().paused:
		visible = false
		return
	if not presentation_allowed():
		cancel()
		return
	# Advance the envelope AND shader motion together, preserving the same look.
	elapsed = minf(DURATION, elapsed + dt * _playback_speed)
	var amount := envelope(elapsed) * _strength_scale
	if GameSettings.flashing_reduced():
		amount *= 0.35
	var motion := 1.0
	if GameSettings.current != null:
		motion = float(GameSettings.current.get_value("head_bob"))
	_material.set_shader_parameter("strength", amount)
	_material.set_shader_parameter("phase", elapsed)
	_material.set_shader_parameter("motion_scale", motion)
	visible = amount > 0.0001


func _unhandled_input(event: InputEvent) -> void:
	if not debug_controls or not event is InputEventKey or not event.pressed or event.echo or get_tree().paused:
		return
	if event.physical_keycode == KEY_F8:
		if presentation_allowed():
			trigger()
			get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_F9:
		# A/B switch requires the explicit debug flag; never saved to profile.
		var was_enabled := enabled
		enabled = true
		if presentation_allowed():
			enabled = not was_enabled
			cancel()
			host._show_event_message("REALITY AFTERSHOCK: ON" if enabled else "REALITY AFTERSHOCK: OFF")
			get_viewport().set_input_as_handled()
		else:
			enabled = was_enabled
