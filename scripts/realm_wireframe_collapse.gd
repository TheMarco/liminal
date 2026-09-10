class_name RealmWireframeCollapse
extends Node3D
## Alternate presentation. The original fracture/particle version remains in
## RealmCollapseEffect and is selectable with --realm-collapse=fracture.

const SCREEN_SHADER := preload("res://shaders/realm_wireframe.gdshader")
const VOXEL_SHADER := preload("res://shaders/realm_wire_voxel.gdshader")
const CELL_SIZE := 0.45
const SAMPLE_COLUMNS := 56
const SAMPLE_ROWS := 36
const MAX_VOXELS := SAMPLE_COLUMNS * SAMPLE_ROWS
# The solid picture is gone at this point, so combat must yield to the finish.
const PROTECTED_FINISH := 0.30

var progress := 0.0
var reduced := false
var sampled := false
var voxel_count := 0
var rebuilding := false
var _player: Player
var _seed := 0
var _screen: MeshInstance3D
var _material: ShaderMaterial
var _voxels: MultiMeshInstance3D
var _voxel_material: ShaderMaterial
var _hum: AudioStreamPlayer
var _erase: AudioStreamPlayer
var _erase_played := false


func configure(player: Player, seed_value: int, reconstructing := false) -> void:
	_player = player
	_seed = seed_value
	rebuilding = reconstructing
	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_screen.mesh = quad
	_screen.extra_cull_margin = 16384.0
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SCREEN_SHADER
	_material.render_priority = 120
	_material.set_shader_parameter("cell_size", CELL_SIZE)
	_screen.material_override = _material
	_screen.visible = false
	add_child(_screen)
	_voxels = MultiMeshInstance3D.new()
	_voxels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_voxels.extra_cull_margin = 8.0
	_voxel_material = ShaderMaterial.new()
	_voxel_material.shader = VOXEL_SHADER
	_voxel_material.render_priority = 121
	_voxels.material_override = _voxel_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	instances.mesh = cube
	instances.instance_count = MAX_VOXELS
	instances.visible_instance_count = 0
	_voxels.multimesh = instances
	add_child(_voxels)
	_voxels.top_level = true
	_voxels.global_transform = Transform3D.IDENTITY
	_hum = _sound(SoundBank.portal_hum(), -40.0)
	_erase = _sound(SoundBank.static_hiss(), -17.0)
	_erase.pitch_scale = 0.75


func _sound(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.bus = SoundBank.GAME_BUS
	sound.volume_db = volume
	add_child(sound)
	return sound


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	reduced = GameSettings.flashing_reduced()
	for material in [_material, _voxel_material]:
		material.set_shader_parameter("collapse", progress)
		material.set_shader_parameter("reduced_flashing", reduced)
	_screen.global_transform = _player.cam.global_transform
	_screen.visible = progress > 0.0
	if progress > 0.0 and not sampled:
		_sample_surface_cells()
		_material.set_shader_parameter("scan_origin", _player.cam.global_position)
		_voxel_material.set_shader_parameter("scan_origin", _player.cam.global_position)
		_hum.play()
	_voxels.multimesh.visible_instance_count = voxel_count if progress > 0.45 and progress < 1.0 else 0
	_hum.volume_db = lerpf(-34.0, -13.0, smoothstep(0.0, 0.7, progress)) - smoothstep(0.86, 1.0, progress) * 32.0
	_hum.pitch_scale = lerpf(0.55, 0.95, 1.0 - progress if rebuilding else progress)
	if ((rebuilding and progress < 0.8) or (not rebuilding and progress >= 0.5)) and not _erase_played:
		_erase.play()
		_erase_played = true
	_erase.volume_db = -17.0 - smoothstep(0.82, 1.0, progress) * 30.0


func _sample_surface_cells() -> void:
	sampled = true
	var cam := _player.cam
	var size := Vector2(cam.get_viewport().get_visible_rect().size)
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	var occupied := {}
	for row in SAMPLE_ROWS:
		for column in SAMPLE_COLUMNS:
			var r := WorldGen.r01(_seed, column, row, 17011)
			var pixel := Vector2((column + 0.2 + r * 0.6) / SAMPLE_COLUMNS,
				(row + 0.2 + fmod(r * 17.0, 0.6)) / SAMPLE_ROWS) * size
			var ray := cam.project_ray_normal(pixel)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				cam.global_position, cam.global_position + ray * 24.0, 1, exclude))
			if hit.is_empty():
				continue
			var point: Vector3 = hit["position"]
			var normal: Vector3 = hit["normal"]
			if point.distance_to(cam.global_position) < 0.9:
				continue
			var cell := Vector3i(((point - normal * 0.012) / CELL_SIZE).floor())
			if occupied.has(cell):
				continue
			occupied[cell] = true
			var centre := (Vector3(cell) + Vector3.ONE * 0.5) * CELL_SIZE
			# Bring the outside face just clear of the source surface's depth.
			centre += normal * CELL_SIZE * 0.55
			_voxels.multimesh.set_instance_transform(voxel_count,
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CELL_SIZE), centre))
			_voxels.multimesh.set_instance_custom_data(voxel_count,
				Color(r, fmod(r * 11.0, 1.0), fmod(r * 23.0, 1.0), 1))
			voxel_count += 1


func set_hold(on: bool) -> void:
	_hum.stream_paused = on
	_erase.stream_paused = on


func finish() -> void:
	_screen.visible = false
	_voxels.multimesh.visible_instance_count = 0
	_hum.stop()
	_erase.stop()
	queue_free()
