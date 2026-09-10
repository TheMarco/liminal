class_name RealmCollapseParticles
extends Node3D
## Several thousand surface-born sparks and soft dust wisps in two draw calls.
## Motion uses the encounter's progress on the GPU, so holds and exact-frame
## captures freeze every particle without a separate simulation clock.

const PARTICLE_SHADER := preload("res://shaders/realm_collapse_particle.gdshader")
const SPARKS_PER_SURFACE := 24
const DUST_PER_SURFACE := 3

var spark_count := 0
var dust_count := 0
var progress := 0.0
var _sparks: MultiMeshInstance3D
var _dust: MultiMeshInstance3D
var _spark_material: ShaderMaterial
var _dust_material: ShaderMaterial


func prepare(max_surfaces: int) -> void:
	_spark_material = _material(false)
	_dust_material = _material(true)
	_sparks = _batch(max_surfaces * SPARKS_PER_SURFACE, _spark_material)
	_dust = _batch(max_surfaces * DUST_PER_SURFACE, _dust_material)


func _material(dust: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PARTICLE_SHADER
	material.render_priority = 123 if dust else 124
	material.set_shader_parameter("dust", dust)
	return material


func _batch(capacity: int, material: ShaderMaterial) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.material_override = material
	batch.extra_cull_margin = 12.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = capacity
	instances.visible_instance_count = 0
	batch.multimesh = instances
	add_child(batch)
	batch.top_level = true
	batch.global_transform = Transform3D.IDENTITY
	return batch


func seed_surfaces(origins: Array[Vector3], normals: Array[Vector3], seed_value: int) -> void:
	assert(origins.size() == normals.size())
	for i in origins.size():
		var normal := normals[i]
		var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var axes := Basis(tangent, normal.cross(tangent).normalized(), normal)
		for slot in SPARKS_PER_SURFACE + DUST_PER_SURFACE:
			var random := WorldGen.r01(seed_value, i, slot, 15917)
			var spread := WorldGen.r01(seed_value, i, slot, 15923)
			var is_dust := slot >= SPARKS_PER_SURFACE
			var n := slot - SPARKS_PER_SURFACE if is_dust else slot
			# Four staggered showers per surface. Most of the final shower
			# erupts during the protected last second as the walls give way.
			var birth := 0.10 + float(n % 4) * 0.22 + random * 0.08
			if is_dust:
				birth = 0.25 + float(n) * 0.23 + random * 0.08
			var offset := axes.x * (random - 0.5) * 0.18 + axes.y * (spread - 0.5) * 0.18
			var at := Transform3D(axes, origins[i] + offset)
			var target := _dust.multimesh if is_dust else _sparks.multimesh
			var index := i * (DUST_PER_SURFACE if is_dust else SPARKS_PER_SURFACE) + n
			target.set_instance_transform(index, at)
			target.set_instance_custom_data(index, Color(random, birth, spread, 1.0))
	spark_count = origins.size() * SPARKS_PER_SURFACE
	dust_count = origins.size() * DUST_PER_SURFACE


func set_progress(value: float, reduced: bool) -> void:
	progress = clampf(value, 0.0, 1.0)
	var live := progress > 0.0 and progress < 1.0
	_sparks.multimesh.visible_instance_count = spark_count if live else 0
	_dust.multimesh.visible_instance_count = dust_count if live else 0
	for material in [_spark_material, _dust_material]:
		material.set_shader_parameter("collapse", progress)
		material.set_shader_parameter("reduced_flashing", reduced)


func finish() -> void:
	_sparks.multimesh.visible_instance_count = 0
	_dust.multimesh.visible_instance_count = 0
	visible = false
