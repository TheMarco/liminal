extends SceneTree
## Reproducibly split the project-owner-supplied, material-merged Sketchfab AC
## collection into three independently placeable floor units.
## Run: godot --headless --path . --script tools/extract_air_conditioners.gd

const SOURCE := "res://models/cc_by/air_conditioners/air_conditioners.glb"
const OUTPUT_DIR := "res://models/cc_by/air_conditioners/"
const MATERIAL_OUTPUT := OUTPUT_DIR + "air_conditioner_material.res"
const ALBEDO_TEXTURE := OUTPUT_DIR + "air_conditioners_0.png"
const NORMAL_TEXTURE := OUTPUT_DIR + "air_conditioners_2.png"
const UNITS := [
	{
		"name": "air_conditioner_floor_a",
		"bounds": AABB(Vector3(145.0, -5.0, -300.0),
			Vector3(185.0, 155.0, 250.0)),
	},
	{
		"name": "air_conditioner_floor_b",
		"bounds": AABB(Vector3(370.0, -5.0, -235.0),
			Vector3(235.0, 160.0, 180.0)),
	},
	{
		"name": "air_conditioner_floor_c",
		"bounds": AABB(Vector3(220.0, -5.0, 0.0),
			Vector3(230.0, 150.0, 180.0)),
	},
]


func _init() -> void:
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return
	var source_root := packed.instantiate() as Node3D
	var source_mesh := source_root.find_child("Object_2", true, false) \
		as MeshInstance3D
	if source_mesh == null or source_mesh.mesh == null:
		push_error("The AC collection no longer contains Object_2")
		source_root.free()
		quit(1)
		return
	var source_material := source_mesh.mesh.surface_get_material(0)
	if source_material == null:
		push_error("The AC collection no longer contains its conditioner material")
		source_root.free()
		quit(1)
		return
	if not source_material is StandardMaterial3D:
		push_error("The AC conditioner material is no longer StandardMaterial3D")
		source_root.free()
		quit(1)
		return
	# Keep one lightweight shared material instead of embedding the glTF
	# specular/gloss conversion's raw ImageTextures in every extracted scene.
	# The authored colour/alpha and normal maps remain external compressed
	# textures; engine-native painted-metal values replace that legacy workflow.
	var shared_source := source_material.duplicate(false) as StandardMaterial3D
	shared_source.albedo_texture = load(ALBEDO_TEXTURE)
	shared_source.normal_texture = load(NORMAL_TEXTURE)
	shared_source.metallic_texture = null
	shared_source.roughness_texture = null
	shared_source.metallic = 0.24
	shared_source.roughness = 0.46
	var material_error := ResourceSaver.save(shared_source, MATERIAL_OUTPUT)
	if material_error != OK:
		push_error("Could not save shared AC material: %s" %
			error_string(material_error))
		source_root.free()
		quit(1)
		return
	var shared_material := load(MATERIAL_OUTPUT) as Material
	var failures := 0
	for spec in UNITS:
		if not _extract_unit(source_mesh, spec, shared_material):
			failures += 1
	source_root.free()
	quit(1 if failures > 0 else 0)


func _extract_unit(source: MeshInstance3D, spec: Dictionary,
		shared_material: Material) -> bool:
	var source_arrays := source.mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
	var source_tangents: PackedFloat32Array = source_arrays[Mesh.ARRAY_TANGENT]
	var source_uvs: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV]
	var source_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	var selection: AABB = spec["bounds"]
	var basis := Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	var wanted: Array[int] = []
	for tri in range(0, source_indices.size(), 3):
		var a: Vector3 = basis * source_vertices[source_indices[tri]]
		var b: Vector3 = basis * source_vertices[source_indices[tri + 1]]
		var c: Vector3 = basis * source_vertices[source_indices[tri + 2]]
		if selection.has_point((a + b + c) / 3.0):
			wanted.append(source_indices[tri])
			wanted.append(source_indices[tri + 1])
			wanted.append(source_indices[tri + 2])
	if wanted.is_empty():
		push_error("%s selected no triangles" % spec["name"])
		return false

	var remap := {}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for old_index in wanted:
		if not remap.has(old_index):
			var new_index := vertices.size()
			remap[old_index] = new_index
			vertices.append(basis * source_vertices[old_index])
			normals.append((basis * source_normals[old_index]).normalized())
			var ti := old_index * 4
			var tangent := basis * Vector3(source_tangents[ti],
				source_tangents[ti + 1], source_tangents[ti + 2])
			tangents.append(tangent.x)
			tangents.append(tangent.y)
			tangents.append(tangent.z)
			tangents.append(source_tangents[ti + 3])
			uvs.append(source_uvs[old_index])
		indices.append(int(remap[old_index]))

	var bounds := _bounds(vertices)
	var origin := Vector3(bounds.get_center().x, bounds.position.y,
		bounds.get_center().z)
	for i in vertices.size():
		vertices[i] -= origin
	bounds = _bounds(vertices)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, shared_material)

	var root := Node3D.new()
	root.name = String(spec["name"])
	var visual := MeshInstance3D.new()
	visual.name = "AirConditioner"
	visual.mesh = mesh
	root.add_child(visual)
	visual.owner = root
	var unit_scene := PackedScene.new()
	if unit_scene.pack(root) != OK:
		push_error("Could not pack %s" % spec["name"])
		root.free()
		return false
	var output := OUTPUT_DIR + String(spec["name"]) + ".scn"
	var save_error := ResourceSaver.save(unit_scene, output)
	root.free()
	if save_error != OK:
		push_error("Could not save %s: %s" % [output, error_string(save_error)])
		return false
	print("saved %s — %d triangles, bounds=%s, scaled=%s" % [
		output, indices.size() / 3, bounds, bounds.size * 0.004])
	return true


func _bounds(vertices: PackedVector3Array) -> AABB:
	var out := AABB(vertices[0], Vector3.ZERO)
	for i in range(1, vertices.size()):
		out = out.expand(vertices[i])
	return out
