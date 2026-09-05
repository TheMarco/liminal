class_name GhostVisual
extends Node3D
## The approved curved body and three delayed, blurred edge veils. The owner
## keeps the original ghost parameter API; lifecycle changes reach every layer.

const SHADER := preload("res://shaders/ghost_layered.gdshader")
const DEPTHS := [0.0, -0.22, 0.14, -0.10]
const WISP_DELAY := 0.19
const FORWARDED := [&"flip_frame", &"flip_blend", &"flip_loop", &"fade", &"flip",
	&"dissolve_seed", &"dissolve_smoke", &"burn", &"ignite", &"sway", &"torch"]
static var _mesh: PlaneMesh

var _layers: Array[MeshInstance3D] = []
var _parameters := {}
var _frame_count: int
var _fps: float
var _elapsed := 0.0
var _history: Array[Vector2] = []
var _last_frame := 0.0
var _unwrapped_frame := 0.0


func _init(material: ShaderMaterial, frame_count: int, fps: float) -> void:
	_frame_count = maxi(frame_count, 1)
	_fps = fps
	if _mesh == null:
		_mesh = PlaneMesh.new()
		_mesh.orientation = PlaneMesh.FACE_Z
		_mesh.size = Vector2.ONE
		_mesh.subdivide_width = 18
		_mesh.subdivide_depth = 28
	for i in DEPTHS.size():
		var pane := MeshInstance3D.new()
		pane.name = "Body" if i == 0 else "Veil%d" % i
		pane.mesh = _mesh
		pane.material_override = material
		pane.position.z = DEPTHS[i]
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pane.extra_cull_margin = 0.25
		pane.set_instance_shader_parameter("layer", float(i))
		add_child(pane)
		_layers.append(pane)


func set_instance_shader_parameter(parameter: StringName, value: Variant) -> void:
	if _parameters.has(parameter) and _parameters[parameter] == value:
		return
	_parameters[parameter] = value
	if FORWARDED.has(parameter):
		for pane in _layers:
			pane.set_instance_shader_parameter(parameter, value)


func get_instance_shader_parameter(parameter: StringName) -> Variant:
	return _parameters.get(parameter)


func _process(dt: float) -> void:
	# Rotate the real geometry together, preserving actual depth sorting,
	# clipping and fog for the curved body and all three veils.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var parent := get_parent_node_3d()
		var camera_position := parent.to_local(camera.global_position) \
			if parent != null else camera.global_position
		var toward := camera_position - position
		if Vector2(toward.x, toward.z).length_squared() > 0.000001:
			rotation.y = atan2(toward.x, toward.z)
	_elapsed += dt
	var phase := float(_parameters.get(&"flip_phase", 0.0))
	var frame := float(_parameters.get(&"flip_frame", -1.0))
	var looping := float(_parameters.get(&"flip_loop", 1.0)) > 0.5
	if frame < 0.0:
		frame = _elapsed * _fps + phase * _frame_count
	frame = fposmod(frame, float(_frame_count)) if looping \
		else clampf(frame, 0.0, float(_frame_count - 1))
	_record_frame(frame, looping)
	for i in _layers.size():
		var pane := _layers[i]
		pane.set_instance_shader_parameter("elapsed", _elapsed + phase * 8.0)
		pane.set_instance_shader_parameter("flip_frame", frame)
		pane.set_instance_shader_parameter("delayed_frame",
			_sample_frame(_elapsed - float(i) * WISP_DELAY, looping))


func _record_frame(frame: float, looping: bool) -> void:
	if _history.is_empty():
		_unwrapped_frame = frame
	else:
		var advance := frame - _last_frame
		# Interpolate through the last/first-frame seam, never backward through
		# the middle of the sheet. Holds remain holds and veils catch up to them.
		if looping:
			advance = wrapf(advance, -float(_frame_count) * 0.5,
				float(_frame_count) * 0.5)
		_unwrapped_frame += advance
	_last_frame = frame
	var sample := Vector2(_elapsed, _unwrapped_frame)
	if not _history.is_empty() and is_equal_approx(_history.back().x, _elapsed):
		_history[-1] = sample
	else:
		_history.append(sample)
	# Keep the sample before the longest delay as an interpolation bracket.
	while _history.size() > 2 and _history[1].x < _elapsed - WISP_DELAY * 3.0:
		_history.pop_front()


func _sample_frame(at: float, looping: bool) -> float:
	var sampled: float = _history.front().y
	for i in range(1, _history.size()):
		var previous := _history[i - 1]
		var next := _history[i]
		if at <= next.x:
			var weight := clampf((at - previous.x) / maxf(next.x - previous.x, 0.000001), 0.0, 1.0)
			sampled = lerpf(previous.y, next.y, weight)
			break
		sampled = next.y
	return fposmod(sampled, float(_frame_count)) if looping \
		else clampf(sampled, 0.0, float(_frame_count - 1))
