extends RefCounted
## Combine the opaque parts of two rigid props into one exact shadow draw.
## Visible meshes/materials, collisions and their scene hierarchy stay intact.
const PATHS := ["res://models/scenario/office/office_desk.glb",
	"res://models/scenario/office/cubicle_divider.glb"]
static var _meshes := {}
static var _material: StandardMaterial3D

static func install(model: Node3D, path: String) -> MeshInstance3D:
	if path not in PATHS: return null
	var parts: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	var layers := -1
	for node in model.find_children("*","MeshInstance3D",true,false):
		var part := node as MeshInstance3D
		var mesh := part.mesh as ArrayMesh
		# Fall back to the original renderer for skins, morphs or special surfaces.
		# These allowlisted props have rigid, visible parts with two-sided materials.
		if mesh == null or mesh.get_blend_shape_count()>0 or part.skin != null \
				or not part.visible or part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			return null
		if layers < 0: layers = part.layers
		if part.layers != layers: return null
		for index in mesh.get_surface_count():
			var mat := part.get_active_material(index) as StandardMaterial3D
			if mesh.surface_get_primitive_type(index) != Mesh.PRIMITIVE_TRIANGLES \
					or mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or mat.cull_mode != BaseMaterial3D.CULL_DISABLED or mat.grow \
					or mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
				return null
		# Model-local coordinates exclude fitting scale/offset on the root, so
		# the same cached geometry works for every placement of this source file.
		var relative := part.transform
		var ancestor := part.get_parent()
		while ancestor != model:
			if ancestor is Node3D: relative = ancestor.transform*relative
			ancestor = ancestor.get_parent()
		if relative.basis.determinant() <= 0.0: return null
		parts.append(part)
		transforms.append(relative)
	if parts.size()<2: return null
	if not _meshes.has(path):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in parts.size():
			for index in parts[i].mesh.get_surface_count():
				# Keep original positions, normals and winding; no simplification or
				# regenerated normals that could alter the area's shadow projection.
				surface.append_from(parts[i].mesh,index,transforms[i])
		_meshes[path] = surface.commit()
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var proxy := MeshInstance3D.new()
	proxy.name = "OfficeShadowBatch"
	proxy.mesh = _meshes[path]
	proxy.material_override = _material
	proxy.layers = layers
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	proxy.set_meta("office_shadow_batch",true)
	model.add_child(proxy)
	for part in parts:
		part.set_meta("office_shadow_original",part.cast_shadow)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return proxy

static func clear_cache() -> void:
	_meshes.clear()
	_material = null
