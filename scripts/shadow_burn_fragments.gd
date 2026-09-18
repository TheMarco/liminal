class_name ShadowBurnFragments
extends MultiMeshInstance3D
## A detached, true-3D copy of the walker's posed surface. Each tiny faceted
## instance begins on the body, then tumbles outward and dissolves on the GPU.

const FRAGMENT_SHADER := preload("res://shaders/shadow_burn_fragment.gdshader")
const DURATION := 1.34

static var _fragment_mesh: ArrayMesh

var fragment_count := 0
var _elapsed := 0.0
var _material: ShaderMaterial


func configure(samples: Dictionary, hdr_peak: float) -> void:
	var points: PackedVector3Array = samples.get("points", PackedVector3Array())
	var normals: PackedVector3Array = samples.get("normals", PackedVector3Array())
	fragment_count = mini(points.size(), normals.size())
	if fragment_count <= 0:
		queue_free()
		return
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	_material = ShaderMaterial.new()
	_material.shader = FRAGMENT_SHADER
	_material.set_shader_parameter(&"progress", 0.0)
	_material.set_shader_parameter(&"hdr_peak", hdr_peak)
	material_override = _material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = _mesh()
	instances.instance_count = fragment_count
	instances.visible_instance_count = fragment_count
	for index in fragment_count:
		var seed := fmod(sin(float(index + 1) * 91.713 + points[index].dot(
			Vector3(17.17, 43.31, 29.53))) * 43758.5453, 1.0)
		seed = seed + 1.0 if seed < 0.0 else seed
		# 0.5-1.2cm, with irregular faceted proportions. Density, not oversized
		# sprites, reconstructs the original body.
		var size := lerpf(0.005, 0.012, seed)
		var scale := Vector3(size * lerpf(0.60, 1.15, fmod(seed * 7.1, 1.0)),
			size * lerpf(0.75, 1.45, fmod(seed * 11.7, 1.0)),
			size * lerpf(0.55, 1.05, fmod(seed * 17.3, 1.0)))
		instances.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(scale), points[index]))
		var normal := normals[index].normalized()
		instances.set_instance_custom_data(index, Color(
			normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5,
			normal.z * 0.5 + 0.5, seed))
	multimesh = instances
	set_process(true)


func _process(dt: float) -> void:
	_elapsed += maxf(dt, 0.0)
	var amount := clampf(_elapsed / DURATION, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter(&"progress", amount)
	if amount >= 1.0:
		queue_free()


static func _mesh() -> ArrayMesh:
	if _fragment_mesh != null:
		return _fragment_mesh
	# Four disconnected faces give each particle genuine volume and parallax.
	var p := [Vector3(0.0, 0.82, 0.0), Vector3(-0.72, -0.46, 0.48),
		Vector3(0.74, -0.43, 0.43), Vector3(0.03, -0.38, -0.78)]
	var faces := [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for face in faces:
		var a: Vector3 = p[face[0]]
		var b: Vector3 = p[face[1]]
		var c: Vector3 = p[face[2]]
		var normal := (b - a).cross(c - a).normalized()
		for point in [a, b, c]:
			vertices.append(point)
			normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	_fragment_mesh = ArrayMesh.new()
	_fragment_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _fragment_mesh
