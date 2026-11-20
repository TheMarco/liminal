extends RefCounted
## Switch off powered surfaces without deleting their geometry or mutating a
## shared material. Cached off variants retain textures, normals, transparency
## and shader detail, so a torch still reveals the real ceiling and fixtures.
## Shader-powered surfaces opt in with the mains_power uniform. Organic/realm
## effects and screen-space water transmission deliberately do not opt in.
var _prepared := {}
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

## Prime eligible materials during the room's existing render-preparation pass.
## The mesh and its overrides are read again at lights-out, after any effects
## have released or replaced them. No visible surface is changed here.
func prepare_mesh(mesh: MeshInstance3D, variants: Dictionary) -> void:
	if mesh.mesh == null:
		return
	_prepare_material(mesh.material_overlay, variants)
	if mesh.material_override != null:
		_prepare_material(mesh.material_override, variants)
	else:
		for i in mesh.mesh.get_surface_count():
			_prepare_material(mesh.get_active_material(i), variants)

func _prepare_material(material: Material, variants: Dictionary) -> void:
	if material == null or variants.has(material):
		return
	var off := off_material(material, variants)
	if off != material:
		_prepared[material] = off

func _copy_for_blackout(material: Material) -> Material:
	var off: Material = _prepared.get(material)
	if off == null:
		return material.duplicate()
	# Shader uniforms and standard-material properties can change in place
	# without a Resource.changed signal. Refresh once per distinct source.
	# Take the copy out of the pool before other rooms start displaying it.
	_prepared.erase(material)
	off.copy_from_resource(material)
	return off

func off_material(material: Material, variants: Dictionary = {}) -> Material:
	if material == null:
		return null
	if variants.has(material):
		return variants[material]
	var off := material
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		if base.emission_enabled or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			var dark := _copy_for_blackout(base) as BaseMaterial3D
			# Extinguish emission through its uniform. Disabling the feature
			# creates a new shader variant at the exact lights-out frame.
			dark.emission_energy_multiplier = 0.0
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			off = dark
	elif material is ShaderMaterial and _has_power(material.shader):
		var dark := _copy_for_blackout(material) as ShaderMaterial
		dark.set_shader_parameter("mains_power", 0.0)
		off = dark
	if material.next_pass != null:
		var dark_pass := off_material(material.next_pass, variants)
		if dark_pass != material.next_pass:
			if off == material:
				off = _copy_for_blackout(material)
			off.next_pass = dark_pass
	variants[material] = off
	return off

func apply(root: Node, variants: Dictionary = {}) -> void:
	apply_visuals(root.find_children("*", "VisualInstance3D", true, false), variants)

func apply_visuals(visuals: Array[Node], variants: Dictionary) -> void:
	for node in visuals:
		if node is Label3D:
			if not node.shaded:
				_labels[node] = false
				node.shaded = true
			continue
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or _meshes.has(mesh):
			continue
		var original := mesh.material_override
		var overlay := mesh.material_overlay
		var dark: Material = variants.get(original)
		if original != null and dark == null:
			dark = off_material(original, variants)
		var dark_overlay := overlay
		if overlay != null:
			dark_overlay = off_material(overlay, variants)
		if original != null and original == dark and overlay == dark_overlay:
			continue
		var surfaces := {}
		if original == null:
			for i in mesh.mesh.get_surface_count():
				var current := mesh.get_active_material(i)
				var variant: Material = variants.get(current)
				if current != null and variant == null:
					variant = off_material(current, variants)
				if variant != current:
					surfaces[i] = mesh.get_surface_override_material(i)
					mesh.set_surface_override_material(i, variant)
		if dark != original or dark_overlay != overlay or not surfaces.is_empty():
			_meshes[mesh] = [original, overlay, surfaces]
			mesh.material_override = dark
			mesh.material_overlay = dark_overlay

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
