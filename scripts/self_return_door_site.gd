class_name SelfReturnDoorSite
extends Node3D
## The same live-window presentation as the temporary realm doorway, looking
## into this room from its safe return point. The original wall and collision
## remain behind the opaque window until the actor crosses.

const WIDTH := 1.34
const HEIGHT := 2.34
const OPEN_TIME := 0.85
## Layer 19 is unused by room geometry and included in the player's camera
## mask. The old 1 << 22 layer was outside that mask, hiding the whole portal.
const PORTAL_LAYER := 1 << 18
const WINDOW_SHADER := preload("res://shaders/realm_window.gdshader")

var openness := 0.0
var _actor: Player
var _landing := Vector3.INF
var _preview: SubViewport
var _preview_camera: Camera3D
var _window: MeshInstance3D
var _window_material: ShaderMaterial
var _fallback: MeshInstance3D
var _frame: Node3D
var _leak: RealmDoorLeak
var _hum: AudioStreamPlayer3D
var _has_frame := false


func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_on_preview_drawn)


func build(actor: Player, landing: Vector3, wall_material: Material,
		world_seed: int) -> void:
	_actor = actor
	_landing = landing
	_preview = SubViewport.new()
	_preview.name = "SameRoomView"
	_preview.size = Vector2i(680, 1188)
	_preview.use_hdr_2d = true
	_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_preview)
	_preview_camera = Camera3D.new()
	_preview_camera.near = 0.05
	_preview_camera.far = 70.0
	_preview.add_child(_preview_camera)
	_preview_camera.current = true
	_window = MeshInstance3D.new()
	_window.name = "same room through doorway"
	_window.visible = false
	_window.layers = PORTAL_LAYER
	_window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aperture := QuadMesh.new()
	aperture.size = Vector2(WIDTH, HEIGHT)
	_window.mesh = aperture
	_window.position = Vector3(0, HEIGHT * 0.5, 0.12)
	_window_material = ShaderMaterial.new()
	_window_material.shader = WINDOW_SHADER
	_window_material.set_shader_parameter("realm_view", _preview.get_texture())
	_window_material.set_shader_parameter("impossible_return", 1.0)
	_window.material_override = _window_material
	add_child(_window)
	_fallback = MeshInstance3D.new()
	_fallback.name = "realm surface while view warms"
	_fallback.mesh = aperture
	_fallback.position = _window.position - Vector3(0, 0, 0.015)
	_fallback.layers = PORTAL_LAYER
	_fallback.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fallback_ink := StandardMaterial3D.new()
	fallback_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fallback_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	fallback_ink.albedo_color = Color(0.045, 0.06, 0.16)
	fallback_ink.emission_enabled = true
	fallback_ink.emission = Color(0.12, 0.25, 0.8)
	fallback_ink.emission_energy_multiplier = 0.85
	_fallback.material_override = fallback_ink
	add_child(_fallback)
	_frame = Node3D.new()
	_frame.name = "native wall aperture"
	add_child(_frame)
	for side in [-1.0, 1.0]:
		_frame_piece(Vector3(side * (WIDTH * 0.5 + 0.0325), HEIGHT * 0.5,
			0.15), Vector3(0.065, HEIGHT, 0.065), wall_material)
	_frame_piece(Vector3(0, HEIGHT + 0.0325, 0.15),
		Vector3(WIDTH + 0.13, 0.065, 0.065), wall_material)
	_frame.visible = false
	_leak = RealmDoorLeak.new()
	add_child(_leak)
	_leak.configure_doorway_outline(global_position,
		-global_basis.z.normalized(), world_seed, Vector2(WIDTH, HEIGHT))
	_leak._patch.layers = PORTAL_LAYER
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "realm doorway hum"
	_hum.stream = SoundBank.portal_hum()
	_hum.bus = SoundBank.GAME_BUS
	_hum.volume_db = -12.0
	_hum.pitch_scale = 0.7
	_hum.unit_size = 6.0
	_hum.max_distance = 18.0
	add_child(_hum)
	_hum.position = Vector3(0, 1.3, 0.55)
	_hum.play()
	pose(0.0, 0.0)


func pose(progress: float, _time: float) -> void:
	openness = clampf(progress, 0.0, 1.0)
	if _frame != null:
		_frame.visible = openness >= 0.96
	if _window != null:
		_window.visible = _has_frame and openness >= 0.96
	if _fallback != null:
		_fallback.visible = openness >= 0.96 and not _window.visible


func _process(dt: float) -> void:
	if _preview == null or not is_instance_valid(_actor): return
	var near := _actor.cam.global_position.distance_to(global_position) < 16.0
	var should_render := openness > 0.02 and near and _update_preview_camera()
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
		if should_render else SubViewport.UPDATE_DISABLED
	_window.visible = should_render and _has_frame and openness >= 0.96
	_frame.visible = openness >= 0.96
	_fallback.visible = openness >= 0.96 and not _window.visible
	_leak.update_cue(dt, near, false)


func _update_preview_camera() -> bool:
	# Translate the eye to the far side of this same room. Keeping its heading
	# preserves left and right through the doorway and after crossing.
	var forward := -global_basis.z.normalized()
	var right := forward.cross(Vector3.UP)
	var eye: Vector3 = _landing + _actor.cam.global_position - global_position
	var centre: Vector3 = _landing + _window.global_position - global_position
	var offset := centre - eye
	var depth := offset.dot(forward)
	if depth <= 0.05: return false
	_preview_camera.global_transform = Transform3D(
		Basis(right, Vector3.UP, -forward), eye)
	_preview_camera.cull_mask = _actor.cam.cull_mask & ~PORTAL_LAYER
	_preview_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_preview_camera.set_frustum(HEIGHT,
		Vector2(offset.dot(right), offset.y), depth, depth + 70.0)
	return true


func _on_preview_drawn() -> void:
	if _preview == null or _preview.render_target_update_mode \
			!= SubViewport.UPDATE_ALWAYS:
		return
	_has_frame = true
	_frame.visible = openness >= 0.96
	_window.visible = openness >= 0.96
	_fallback.visible = false


func _frame_piece(at: Vector3, size: Vector3, material: Material) -> void:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.position = at
	piece.material_override = material
	piece.layers = PORTAL_LAYER
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.add_child(piece)
