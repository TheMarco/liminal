class_name RealmCollapseEffect
extends Node3D
## Surface-anchored fractures and bounded, nonphysical fragments. No room
## materials or collision are changed. Everything dies with this one effect.

const FRACTURE_SHADER := preload("res://shaders/realm_disintegration.gdshader")
const SHARD_SHADER := preload("res://shaders/realm_shard.gdshader")
const SHARD_COLUMNS := 16
const SHARD_ROWS := 10
const MAX_SHARDS := SHARD_COLUMNS * SHARD_ROWS
const PROTECTED_FINISH := 0.76

var progress := 0.0
var sampled := false
var reduced := false
var shard_count := 0
var _player: Player
var _seed := 0
var _screen: MeshInstance3D
var _material: ShaderMaterial
var _shards: MultiMeshInstance3D
var _particles: RealmCollapseParticles
var _origins: Array[Vector3] = []
var _normals: Array[Vector3] = []
var _randoms: Array[float] = []
var _hum: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _impact: AudioStreamPlayer
var _fracture: AudioStreamPlayer
var _cue_stage := 0


func configure(player_node: Player, seed_value: int) -> void:
	_player = player_node
	_seed = seed_value
	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_screen.mesh = quad
	_screen.extra_cull_margin = 16384.0
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = FRACTURE_SHADER
	_material.render_priority = 120
	_screen.material_override = _material
	_screen.visible = false
	add_child(_screen)
	_shards = MultiMeshInstance3D.new()
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := _fragment_mesh()
	var shard_material := ShaderMaterial.new()
	shard_material.shader = SHARD_SHADER
	shard_material.render_priority = 121
	_shards.material_override = shard_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = MAX_SHARDS
	instances.visible_instance_count = 0
	_shards.multimesh = instances
	add_child(_shards)
	_shards.top_level = true
	_shards.global_transform = Transform3D.IDENTITY
	_particles = RealmCollapseParticles.new()
	add_child(_particles)
	_particles.prepare(MAX_SHARDS)
	# Prepare cached waveforms before the busy final five seconds.
	_hum = _sound(SoundBank.portal_hum(), -45.0)
	_creak = _sound(SoundBank.creak(), -12.0)
	_impact = _sound(SoundBank.thud(), -8.0)
	_fracture = _sound(SoundBank.clang(), -14.0)
	_fracture.pitch_scale = 0.65


func _fragment_mesh() -> ArrayMesh:
	# Small solid chips with a dark face and a luminous broken rim, rather
	# than flat additive triangles. These are VFX, never collision objects.
	var outline := [Vector3(-0.55, -0.25, 0), Vector3(0.32, -0.35, 0),
		Vector3(0.55, 0.20, 0), Vector3(-0.12, 0.65, 0), Vector3(-0.45, 0.18, 0)]
	var faces: Array = []
	var depth := Vector3(0, 0, 0.025)
	for i in outline.size():
		var j := (i + 1) % outline.size()
		faces.append([depth, outline[i] + depth, outline[j] + depth])
		faces.append([-depth, outline[j] - depth, outline[i] - depth])
		faces.append([outline[i] + depth, outline[i] - depth, outline[j] - depth])
		faces.append([outline[i] + depth, outline[j] - depth, outline[j] + depth])
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	for face in faces:
		vertices.append_array(PackedVector3Array(face))
		for vertex in face:
			uv.append(Vector2(vertex.x, vertex.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sound(stream: AudioStream, decibels: float) -> AudioStreamPlayer:
	var node := AudioStreamPlayer.new()
	node.stream = stream
	node.volume_db = decibels
	node.bus = SoundBank.GAME_BUS
	add_child(node)
	return node


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	reduced = GameSettings.flashing_reduced()
	_material.set_shader_parameter("collapse", progress)
	_material.set_shader_parameter("reduced_flashing", reduced)
	_screen.visible = progress > 0.0
	_screen.global_transform = _player.cam.global_transform
	if progress <= 0.0:
		_particles.set_progress(0.0, reduced)
		_shards.multimesh.visible_instance_count = 0
		return
	if not sampled:
		_sample_surfaces()
		_hum.play()
	_hum.volume_db = lerpf(-34.0, -11.0, smoothstep(0.0, 0.85, progress)) - 28.0 * smoothstep(0.90, 1.0, progress)
	_hum.pitch_scale = lerpf(0.72, 1.2, progress * progress)
	if _cue_stage == 0 and progress >= 0.10:
		_creak.play()
		_cue_stage = 1
	if _cue_stage == 1 and progress >= 0.46:
		_impact.play()
		_cue_stage = 2
	if _cue_stage == 2 and progress >= 0.79:
		_fracture.play()
		_cue_stage = 3
	_update_shards()
	_particles.set_progress(progress, reduced)


func _sample_surfaces() -> void:
	sampled = true
	var cam := _player.cam
	var size := Vector2(cam.get_viewport().get_visible_rect().size)
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	for row in SHARD_ROWS:
		for column in SHARD_COLUMNS:
			var random := WorldGen.r01(_seed, column, row, 15641)
			var pixel := Vector2((float(column) + 0.15 + random * 0.7) / SHARD_COLUMNS,
				(float(row) + 0.15 + fmod(random * 7.0, 0.7)) / SHARD_ROWS) * size
			var ray := cam.project_ray_normal(pixel)
			var query := PhysicsRayQueryParameters3D.create(cam.global_position,
				cam.global_position + ray * 24.0, 1, exclude)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			var point: Vector3 = hit["position"]
			if point.distance_to(cam.global_position) < 0.8:
				continue
			var normal: Vector3 = hit["normal"]
			_origins.append(point + normal * 0.04)
			_normals.append(normal)
			_randoms.append(random)
	shard_count = _origins.size()
	_shards.multimesh.visible_instance_count = shard_count
	_particles.seed_surfaces(_origins, _normals, _seed)


func _update_shards() -> void:
	_shards.multimesh.visible_instance_count = 0 if progress >= 1.0 else shard_count
	for i in shard_count:
		var random := _randoms[i]
		var age := maxf(0.0, progress - 0.07 - random * 0.40)
		var normal := _normals[i]
		var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var drift := (normal * (0.45 + random) + tangent * (random - 0.5) * 0.9
			+ Vector3.UP * 0.35) * age * age * 4.0
		if reduced:
			drift *= 0.55
		var at := _origins[i] + drift
		var dissolve := smoothstep(0.80 + random * 0.12, 0.90 + random * 0.10, progress)
		var scale_value := (0.06 + pow(random, 7.0) * 0.60) * smoothstep(0.0, 0.1, age)
		var rotation := Basis.looking_at(normal, tangent).rotated(normal, random * TAU)
		rotation = rotation.rotated(tangent, age * (0.7 if reduced else 1.8))
		_shards.multimesh.set_instance_transform(i, Transform3D(rotation.scaled(Vector3.ONE * scale_value), at))
		var colour := Color(0.3, 0.92, 1.0).lerp(Color(0.48, 0.12, 1.0), fmod(random * 23.0, 1.0))
		colour.a = smoothstep(0.0, 0.08, age) * (1.0 - dissolve) * (0.55 if reduced else 0.95)
		_shards.multimesh.set_instance_color(i, colour)
		_shards.multimesh.set_instance_custom_data(i, Color(dissolve, 0, 0, 0))


func set_hold(on: bool) -> void:
	for node in [_hum, _creak, _impact, _fracture]:
		node.stream_paused = on


func finish() -> void:
	_screen.visible = false
	_shards.visible = false
	_particles.finish()
	for node in [_hum, _creak, _impact, _fracture]:
		node.stop()
	queue_free()
