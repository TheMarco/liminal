extends RefCounted
## Switch off powered surfaces without deleting their geometry or mutating a
## shared material. Cached off variants retain textures, normals, transparency
## and shader detail, so a torch still reveals the real ceiling and fixtures.
## Shader-powered surfaces opt in with the mains_power uniform. Organic/realm
## effects and screen-space water transmission deliberately do not opt in.
var _prepared: Dictionary[Material, Material] = {}
## One unbound copy per floor-owned source. A room takes it out of the pool
## before using it. Room-specific flicker and prop materials stay local.
static var _floor_prepared: Dictionary[Material, Material] = {}
static var _shader_power := {}
var _meshes := {}
var _labels := {}
var _by_override: Dictionary[Material, Array] = {}
var _other_visuals: Array[Node] = []
var _switched_overrides: Dictionary[Material, Array] = {}
## Opt-in authored meshes keep their bindings for their lifetime. Group the
## bindings at room installation so inert cabinet parts cost nothing to switch.
## Source properties (including next passes) are still read at each outage.
var _fixed_bindings: Dictionary[Material, Array] = {}
var _switched_fixed: Array[Array] = []
## A room's suspended strips share one box per lens material. Switching the
## box binding keeps the individual fixtures and the source material intact.
var _emitter_boxes: Dictionary[Material, BoxMesh] = {}
var _switched_boxes: Dictionary[BoxMesh, Material] = {}

func emitter_box(source: Material) -> BoxMesh:
	var box: BoxMesh = _emitter_boxes.get(source)
	if box == null:
		box = BoxMesh.new()
		box.material = source
		_emitter_boxes[source] = box
	return box

static func clear_cache() -> void:
	_floor_prepared.clear()
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
	if material == null or variants.has(material) or _floor_prepared.has(material):
		return
	var off := off_material(material, variants)
	if off != material:
		if Mats.is_cached_material(material):
			_floor_prepared[material] = off
		else:
			_prepared[material] = off

func _copy_for_blackout(material: Material) -> Material:
	var pool := _floor_prepared if _floor_prepared.has(material) else _prepared
	var off: Material = pool.get(material)
	if off == null:
		return material.duplicate()
	# Shader uniforms and standard-material properties can change in place
	# without a Resource.changed signal. Refresh once per distinct source.
	# Take the copy out of the pool before other rooms start displaying it.
	pool.erase(material)
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


func index_visuals(visuals: Array[Node]) -> void:
	_by_override.clear()
	_fixed_bindings.clear()
	_other_visuals.clear()
	for node in visuals:
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.material_overlay == null \
				and mesh.owner != null and mesh.owner.has_meta(&"fixed_power_bindings"):
			if mesh.material_override != null:
				_fixed_bindings.get_or_add(mesh.material_override, []).append([mesh, -1, mesh.material_override])
			else:
				for surface in mesh.mesh.get_surface_count():
					var source := mesh.get_active_material(surface)
					if source != null:
						_fixed_bindings.get_or_add(source, []).append([mesh, surface, mesh.get_surface_override_material(surface)])
		elif mesh != null and mesh.material_override != null and mesh.material_overlay == null:
			var group: Array = _by_override.get_or_add(mesh.material_override, [])
			group.append(mesh)
		else:
			_other_visuals.append(node)


func apply_indexed(variants: Dictionary) -> void:
	for source: Material in _emitter_boxes:
		var box := _emitter_boxes[source]
		var current := box.material
		var dark := off_material(current, variants)
		if dark != current:
			_switched_boxes[box] = current
			box.material = dark
			variants[dark] = dark
	for source: Material in _fixed_bindings:
		var dark := off_material(source, variants)
		if dark == source:
			continue
		var bindings: Array = _fixed_bindings[source]
		for binding: Array in bindings:
			var mesh: MeshInstance3D = binding[0]
			if binding[1] == -1:
				mesh.material_override = dark
			else:
				mesh.set_surface_override_material(binding[1], dark)
		_switched_fixed.append(bindings)
	# Group by original binding only. Read its current shader, emission and
	# next pass at the switch, and check for changes to individual instances.
	var rebound: Array[Node] = []
	for source: Material in _by_override:
		var dark := off_material(source, variants)
		var group: Array = _by_override[source]
		if dark == source:
			for mesh: MeshInstance3D in group:
				if mesh.material_override != source or mesh.material_overlay != null:
					rebound.append(mesh)
		else:
			var switched: Array[MeshInstance3D] = []
			for mesh: MeshInstance3D in group:
				if mesh.material_override != source or mesh.material_overlay != null:
					rebound.append(mesh)
				elif mesh.mesh != null:
					mesh.material_override = dark
					switched.append(mesh)
			_switched_overrides[source] = switched
	apply_visuals(_other_visuals, variants)
	if not rebound.is_empty():
		apply_visuals(rebound, variants)


func apply_visuals(visuals: Array[Node], variants: Dictionary) -> void:
	for node in visuals:
		if node is Label3D:
			if not node.shaded:
				_labels[node] = false
				node.shaded = true
			continue
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var original := mesh.material_override
		var overlay := mesh.material_overlay
		# A wave or a prop effect can replace the mesh or add its own override.
		# Only skip a lens that still draws the room's switched box directly.
		if original == null and overlay == null and mesh.mesh is BoxMesh and _switched_boxes.has(mesh.mesh) \
				and mesh.get_surface_override_material(0) == null:
			continue
		var dark := original
		if original != null:
			dark = variants.get(original)
			if dark == null:
				dark = off_material(original, variants)
			if dark == original and overlay == null:
				continue
		if _meshes.has(mesh):
			continue
		var dark_overlay := overlay
		if overlay != null:
			dark_overlay = off_material(overlay, variants)
		if original != null and original == dark and overlay == dark_overlay:
			continue
		var surfaces: Dictionary
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
			if dark != original:
				mesh.material_override = dark
			if dark_overlay != overlay:
				mesh.material_overlay = dark_overlay

func restore() -> void:
	for box: BoxMesh in _switched_boxes:
		box.material = _switched_boxes[box]
	_switched_boxes.clear()
	for bindings in _switched_fixed:
		for binding: Array in bindings:
			if is_instance_valid(binding[0]):
				var mesh: MeshInstance3D = binding[0]
				if binding[1] == -1:
					mesh.material_override = binding[2]
				else:
					mesh.set_surface_override_material(binding[1], binding[2])
	_switched_fixed.clear()
	for source: Material in _switched_overrides:
		for mesh in _switched_overrides[source]:
			if is_instance_valid(mesh):
				mesh.material_override = source
	_switched_overrides.clear()
	for mesh in _meshes:
		if not is_instance_valid(mesh):
			continue
		var state: Array = _meshes[mesh]
		if mesh.material_override != state[0]:
			mesh.material_override = state[0]
		if mesh.material_overlay != state[1]:
			mesh.material_overlay = state[1]
		for i in state[2]:
			mesh.set_surface_override_material(i, state[2][i])
	for label in _labels:
		if is_instance_valid(label):
			label.shaded = bool(_labels[label])
	_meshes.clear()
	_labels.clear()
