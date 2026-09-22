extends Node3D
## Preview-only deformation. Keeps native fragment shading and source resources.
## CPU mesh/collision rebuilding is intentionally not a production motion system.

var amplitude := 0.30
var face: SurfaceWear.Face
var patch_size := Vector2(2.6, 2.0)
var mesh_node: MeshInstance3D
var original: Mesh
var original_material: Material
var original_cull_margin := 0.0
var motion_material: ShaderMaterial
var mapped_material: StandardMaterial3D
var render_mesh: PrimitiveMesh
var source_arrays: Array
var frame: Transform3D
var from_mesh: Transform3D
var to_mesh: Transform3D
var collision: CollisionShape3D
var amount := 0.0
var collision_enabled := true
var companions: Array[Node3D] = []

func attach(p_face: SurfaceWear.Face, center: Vector3, size_: Vector2) -> void:
	face = p_face
	patch_size = size_
	mesh_node = face.mesh
	original = mesh_node.mesh
	original_material = mesh_node.material_override
	original_cull_margin = mesh_node.extra_cull_margin
	frame = Transform3D(Basis(face.u, face.v, face.normal), center)
	from_mesh = frame.affine_inverse() * face.transform
	to_mesh = from_mesh.affine_inverse()
	var subdivided := original.duplicate() as PrimitiveMesh
	var physical := face.transform.basis.get_scale() * original.get_aabb().size
	subdivided.set("subdivide_width", clampi(ceili(maxf(absf(physical.x), absf(physical.z)) / 0.10), 0, 160))
	subdivided.set("subdivide_height", clampi(ceili(absf(physical.y) / 0.10), 0, 90))
	if subdivided is BoxMesh:
		subdivided.subdivide_depth = clampi(ceili(absf(physical.z) / 0.10), 0, 160)
	source_arrays = subdivided.get_mesh_arrays()
	render_mesh = subdivided
	if original_material is ShaderMaterial:
		motion_material = _wrap_shader(original_material)
	elif original_material is StandardMaterial3D and original_material.uv1_triplanar:
		mapped_material = _anchor_triplanar(original_material)
	if collision_enabled:
		var body := StaticBody3D.new()
		body.transform = face.transform
		collision = CollisionShape3D.new()
		body.add_child(collision)
		add_child(body)
	_set_amount_local(0.0)

func attach_companion(mesh: MeshInstance3D, relative_transform: Transform3D) -> Node3D:
	if not collision_enabled:
		return null
	if face == null:
		return null
	if mesh == null or mesh == mesh_node:
		return null
	if not (mesh.mesh is BoxMesh or mesh.mesh is QuadMesh):
		return null
	for c in companions:
		var existing: Variant = c
		if existing.get("mesh_node") == mesh:
			return null
	var f := SurfaceWear.Face.new()
	f.mesh = mesh
	f.transform = relative_transform
	f.center = frame.origin
	f.normal = face.normal
	f.u = face.u
	f.v = face.v
	f.size = face.size
	f.material = mesh.material_override.resource_name if mesh.material_override != null else ""
	f.role = face.role
	f.salt = face.salt
	var companion: Variant = get_script().new()
	companion.set("collision_enabled", false)
	add_child(companion as Node)
	(companion as Node3D).transform = Transform3D.IDENTITY
	companion.call("attach", f, frame.origin, patch_size)
	companion.call("configure_size", patch_size, amplitude)
	companion.call("set_amount", amount)
	companions.append(companion as Node3D)
	return companion as Node3D

func _anchor_triplanar(source: StandardMaterial3D) -> StandardMaterial3D:
	# These architectural primitives have flat, axis-aligned faces. Bake the
	# native projection before bending: using the bent normal for triplanar
	# weights introduces ghost tile grids around the bulge's steep slopes.
	# Match Godot's projection signs, scale, phase and tangent basis.
	var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	uvs.resize(vertices.size())
	tangents.resize(vertices.size() * 4)
	var mapping := mesh_node.global_transform if source.uv1_world_triplanar else Transform3D.IDENTITY
	var normal_basis := mapping.basis.inverse().transposed()
	for i in vertices.size():
		var n := (normal_basis * normals[i]).normalized()
		var axis := n.abs().max_axis_index()
		if absf(n[axis]) < 0.9999:
			push_error("Breathing preview requires axis-aligned triplanar faces: " + source.resource_name)
			return null
		var p := (mapping * vertices[i]) * source.uv1_scale + source.uv1_offset
		var t := Vector3.RIGHT
		var b := Vector3.UP
		match axis:
			Vector3.AXIS_X:
				uvs[i] = Vector2(-p.z, -p.y)
				t = Vector3.FORWARD
			Vector3.AXIS_Y:
				uvs[i] = Vector2(p.x, p.z)
				b = Vector3.FORWARD
			Vector3.AXIS_Z:
				uvs[i] = Vector2(p.x, -p.y)
		t = (normal_basis.inverse() * t).normalized()
		b = (normal_basis.inverse() * b).normalized()
		tangents[i * 4] = t.x
		tangents[i * 4 + 1] = t.y
		tangents[i * 4 + 2] = t.z
		tangents[i * 4 + 3] = signf(normals[i].cross(t).dot(b))
	source_arrays[Mesh.ARRAY_TEX_UV] = uvs
	source_arrays[Mesh.ARRAY_TANGENT] = tangents
	var result := source.duplicate() as StandardMaterial3D
	result.uv1_triplanar = false
	result.uv1_world_triplanar = false
	result.uv1_scale = Vector3.ONE
	result.uv1_offset = Vector3.ZERO
	# Godot ignores height mapping while triplanar is enabled; keep that behavior.
	result.heightmap_enabled = false
	return result

func _wrap_shader(source: ShaderMaterial) -> ShaderMaterial:
	var code := source.shader.code
	var start := code.find("void vertex()")
	if start < 0:
		code += "\nvoid vertex() {}\n"
		start = code.find("void vertex()")
	var opening := code.find("{", start)
	var depth := 1
	var end := opening + 1
	while depth > 0 and end < code.length():
		if code[end] == "{": depth += 1
		if code[end] == "}": depth -= 1
		end += 1
	code = code.insert(end - 1, "\nprobe_deform(VERTEX, NORMAL, TANGENT, BINORMAL);\n")
	var insert := code.find(";", code.find("shader_type")) + 1
	code = code.insert(insert, "\n#include \"res://tools/lib/breathing_probe_deform.gdshaderinc\"\n")
	var result := source.duplicate() as ShaderMaterial
	result.shader = Shader.new()
	result.shader.code = code
	for uniform in source.shader.get_shader_uniform_list():
		result.set_shader_parameter(uniform.name, source.get_shader_parameter(uniform.name))
	result.set_shader_parameter("probe_from_mesh", from_mesh)
	result.set_shader_parameter("probe_to_mesh", to_mesh)
	result.set_shader_parameter("probe_size", patch_size)
	return result

func height_at(x: float, y: float, value := -1.0) -> float:
	var u := x / patch_size.x + 0.5
	var v := y / patch_size.y + 0.5
	if u <= 0.0 or u >= 1.0 or v <= 0.0 or v >= 1.0:
		return 0.0
	return amplitude * (amount if value < 0.0 else value) * pow(sin(PI * u) * sin(PI * v), 2.0)

func configure_size(size_: Vector2, depth: float) -> void:
	var previous := amount
	_set_amount_local(0.0)
	patch_size = size_
	amplitude = depth
	if motion_material != null:
		motion_material.set_shader_parameter("probe_size", patch_size)
		motion_material.set_shader_parameter("probe_amplitude", amplitude)
	_set_amount_local(previous)
	for c in companions:
		if is_instance_valid(c):
			var p: Variant = c
			p.configure_size(size_, depth)

func set_amount(value: float) -> void:
	_set_amount_local(value)
	for c in companions:
		if is_instance_valid(c):
			var p: Variant = c
			p.set_amount(value)

func _set_amount_local(value: float) -> void:
	amount = clampf(value, 0.0, 1.0)
	if amount < 0.00001:
		mesh_node.mesh = original
		mesh_node.material_override = original_material
		mesh_node.extra_cull_margin = original_cull_margin
		if collision != null:
			collision.disabled = true
		return
	var arrays := source_arrays.duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for i in vertices.size():
		var p := from_mesh * vertices[i]
		var u := p.x / patch_size.x + 0.5
		var v := p.y / patch_size.y + 0.5
		if u <= 0.0 or u >= 1.0 or v <= 0.0 or v >= 1.0:
			continue
		var dx := amplitude * amount * PI * sin(TAU * u) * pow(sin(PI * v), 2.0) / patch_size.x
		var dy := amplitude * amount * PI * sin(TAU * v) * pow(sin(PI * u), 2.0) / patch_size.y
		p.z += height_at(p.x, p.y)
		vertices[i] = to_mesh * p
		var n := from_mesh.basis.inverse().transposed() * normals[i]
		n = Vector3(n.x - dx * n.z, n.y - dy * n.z, n.z)
		normals[i] = (from_mesh.basis.transposed() * n).normalized()
		if tangents.size() >= (i + 1) * 4:
			var t := from_mesh.basis * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
			t.z += dx * t.x + dy * t.y
			t = (to_mesh.basis * t).normalized()
			tangents[i * 4] = t.x
			tangents[i * 4 + 1] = t.y
			tangents[i * 4 + 2] = t.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var deformed := ArrayMesh.new()
	deformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = render_mesh if motion_material != null else deformed
	mesh_node.extra_cull_margin = maxf(original_cull_margin, amplitude)
	mesh_node.material_override = motion_material if motion_material != null else (mapped_material if mapped_material != null else original_material)
	if motion_material != null:
		motion_material.set_shader_parameter("probe_amount", amount)
	if collision != null:
		collision.shape = deformed.create_trimesh_shape()
		collision.disabled = false

func restore() -> void:
	if collision != null:
		collision.disabled = true
	if is_instance_valid(mesh_node):
		mesh_node.mesh = original
		mesh_node.material_override = original_material
		mesh_node.extra_cull_margin = original_cull_margin
	for c in companions:
		if is_instance_valid(c):
			var p: Variant = c
			p.restore()

func originals_restored() -> bool:
	if is_instance_valid(mesh_node):
		if mesh_node.mesh != original:
			return false
		if mesh_node.material_override != original_material:
			return false
		if mesh_node.extra_cull_margin != original_cull_margin:
			return false
	for c in companions:
		if is_instance_valid(c):
			var p: Variant = c
			if not p.originals_restored():
				return false
	return true
