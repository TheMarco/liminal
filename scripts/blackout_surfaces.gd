extends RefCounted
## Switch off powered surfaces without deleting their geometry or mutating a
## shared material. Cached off variants retain textures, normals, transparency
## and shader detail, so a torch still reveals the real ceiling and fixtures.
## Shader-powered surfaces opt in with the mains_power uniform. Organic/realm
## effects and screen-space water transmission deliberately do not opt in.
var _variants := {}
static var _shader_power := {}
var _meshes := {}
var _labels := {}

static func clear_cache() -> void:
	_shader_power.clear()

static func _has_power(shader: Shader) -> bool:
	if shader == null:
		return false
	if not _shader_power.has(shader):
		_shader_power[shader] = false
		for uniform in shader.get_shader_uniform_list():
			if uniform.name == "mains_power":
				_shader_power[shader] = true
				break
	return bool(_shader_power[shader])

func off_material(material: Material) -> Material:
	if material == null:
		return null
	if _variants.has(material):
		return _variants[material]
	var off := material
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		if base.emission_enabled or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			var dark := base.duplicate() as BaseMaterial3D
			dark.emission_enabled = false
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			off = dark
	elif material is ShaderMaterial and _has_power(material.shader):
		var dark := material.duplicate() as ShaderMaterial
		dark.set_shader_parameter("mains_power", 0.0)
		off = dark
	if material.next_pass != null:
		var dark_pass := off_material(material.next_pass)
		if dark_pass != material.next_pass:
			if off == material:
				off = material.duplicate()
			off.next_pass = dark_pass
	_variants[material] = off
	return off

func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if _meshes.has(mesh) or mesh.mesh == null:
			continue
		var surfaces := {}
		var original := mesh.material_override
		var overlay := mesh.material_overlay
		var dark := off_material(original)
		var dark_overlay := off_material(overlay)
		if original == null:
			for i in mesh.mesh.get_surface_count():
				var current := mesh.get_active_material(i)
				var variant := off_material(current)
				if variant != current:
					surfaces[i] = mesh.get_surface_override_material(i)
					mesh.set_surface_override_material(i, variant)
		if dark != original or dark_overlay != overlay or not surfaces.is_empty():
			_meshes[mesh] = [original, overlay, surfaces]
			mesh.material_override = dark
			mesh.material_overlay = dark_overlay
	for node in root.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if not _labels.has(label) and not label.shaded:
			_labels[label] = label.shaded
			label.shaded = true

func restore() -> void:
	for mesh in _meshes:
		if not is_instance_valid(mesh):
			continue
		var state: Array = _meshes[mesh]
		mesh.material_override = state[0]
		mesh.material_overlay = state[1]
		for i in state[2]:
			mesh.set_surface_override_material(i, state[2][i])
	for label in _labels:
		if is_instance_valid(label):
			label.shaded = bool(_labels[label])
	_meshes.clear()
	_labels.clear()
	_variants.clear()
