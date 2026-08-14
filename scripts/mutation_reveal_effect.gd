class_name MutationRevealEffect
extends Node3D
## Short-lived supernatural silhouette bound to the exact altered geometry.
## Every material uses ordinary depth testing: walls occlude the reveal just as
## they occlude the object itself. Appearing/moved meshes get a pulsing grown
## outline; vanished meshes retain a translucent pre-swap imprint; changed
## architectural edges get a fitted doorway trace. There is deliberately no
## camera-facing locator circle.

const LIFE_SECONDS := 3.2
const OUTLINE_SHADER := preload("res://shaders/mutation_outline.gdshader")
const CORE_COLOR := Color(0.58, 1.0, 1.0)
const FRINGE_COLOR := Color(0.32, 0.12, 1.0)

var _elapsed := 0.0
var _outline_material: ShaderMaterial
var _ghost_material: StandardMaterial3D
var _outlined := {}
var _ghost: Node3D
var _portal_trace: Node3D


func _ready() -> void:
	set_meta("mutation_reveal_effect", true)
	add_to_group("mutation_reveal_effect")


## Bind the presentation to the committed mutation's exact scene geometry.
## Installed meshes receive a temporary grown emissive shell. Geometry which
## vanished during the atomic swap arrives as a mesh-only ghost captured while
## the old reality was still live.
func configure(descriptor: Dictionary) -> void:
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_color", CORE_COLOR)
	_outline_material.set_shader_parameter("strength", 6.5)
	_outline_material.set_shader_parameter("opacity", 0.82)
	_outline_material.set_shader_parameter("grow", 0.045)
	_ghost_material = _make_ghost_material()
	var nodes: Variant = descriptor.get("nodes", [])
	if nodes is Array:
		for value in nodes as Array:
			if is_instance_valid(value) and value is Node:
				_outline_node(value as Node)
	var ghost_value: Variant = descriptor.get("ghost", null)
	if is_instance_valid(ghost_value) and ghost_value is Node3D:
		_ghost = ghost_value as Node3D
		add_child(_ghost)
		_ghost.top_level = true
		_ghost.global_transform = Transform3D.IDENTITY
		_apply_ghost_material(_ghost)
	if str(descriptor.get("kind", "")) == "door":
		_build_portal_trace(descriptor)


func _make_ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(CORE_COLOR, 0.20)
	material.emission_enabled = true
	material.emission = CORE_COLOR
	material.emission_energy_multiplier = 3.8
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _outline_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and not _outlined.has(mesh):
			_outlined[mesh] = mesh.material_overlay
			mesh.material_overlay = _outline_material
	for child in node.get_children():
		_outline_node(child)


func _apply_ghost_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = _ghost_material
		mesh.material_overlay = _outline_material
	for child in node.get_children():
		_apply_ghost_material(child)


## Door changes may remove the old mesh completely. Trace the exact boundary
## and opening dimensions so the absence itself has a supernatural silhouette.
func _build_portal_trace(descriptor: Dictionary) -> void:
	var edge_value: Variant = descriptor.get("edge", {})
	if not edge_value is Dictionary:
		return
	var edge := edge_value as Dictionary
	var record: Dictionary = edge.get("after", {})
	if record.is_empty():
		record = edge.get("before", {})
	var width := clampf(float(record.get("w", 3.0)), 1.2, 4.6)
	var height := 2.55
	var edge_centre: Vector3 = descriptor.get("edge_center",
		descriptor.get("position", global_position))
	var dir := int(edge.get("dir", 0))
	_portal_trace = Node3D.new()
	add_child(_portal_trace)
	_portal_trace.top_level = true
	_portal_trace.global_position = edge_centre + Vector3(0.0, height * 0.5, 0.0)
	var side_size := Vector3(0.055, height, 0.055)
	var top_size := Vector3(width, 0.055, 0.055)
	if dir < 2:
		side_size = Vector3(0.055, height, 0.055)
		top_size = Vector3(0.055, 0.055, width)
		_add_trace_bar(Vector3(0.0, 0.0, -width * 0.5), side_size)
		_add_trace_bar(Vector3(0.0, 0.0, width * 0.5), side_size)
	else:
		_add_trace_bar(Vector3(-width * 0.5, 0.0, 0.0), side_size)
		_add_trace_bar(Vector3(width * 0.5, 0.0, 0.0), side_size)
	_add_trace_bar(Vector3(0.0, height * 0.5, 0.0), top_size)
	_add_trace_bar(Vector3(0.0, -height * 0.5, 0.0), top_size)


func _add_trace_bar(position: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	bar.mesh = box
	bar.position = position
	bar.material_override = _ghost_material
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_portal_trace.add_child(bar)


func _process(delta: float) -> void:
	advance(delta)


## Kept as one deterministic step so the focused audit can verify the complete
## lifecycle without sleeping for the three-second presentation.
func advance(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	var progress := clampf(_elapsed / LIFE_SECONDS, 0.0, 1.0)
	var highlight_fade := 1.0 - smoothstep(0.48, 1.0, progress)
	if _outline_material != null:
		var outline_pulse := 0.035 + 0.013 * (0.5 + 0.5 * sin(_elapsed * 13.0))
		_outline_material.set_shader_parameter("opacity", 0.82 * highlight_fade)
		_outline_material.set_shader_parameter(
			"strength", 1.0 + 5.5 * highlight_fade)
		_outline_material.set_shader_parameter("grow", outline_pulse)
	if _ghost_material != null:
		var ghost_pulse := 0.72 + sin(_elapsed * 17.0) * 0.18
		_ghost_material.albedo_color = Color(FRINGE_COLOR,
			0.24 * highlight_fade * ghost_pulse)
		_ghost_material.emission = CORE_COLOR.lerp(FRINGE_COLOR,
			0.35 + 0.15 * sin(_elapsed * 8.0))
		_ghost_material.emission_energy_multiplier = 1.0 + 4.2 * highlight_fade

	if _elapsed >= LIFE_SECONDS:
		queue_free()


func _exit_tree() -> void:
	for value in _outlined:
		if not is_instance_valid(value):
			continue
		var mesh := value as MeshInstance3D
		# Do not erase a newer reveal that took ownership before this queued free.
		if mesh.material_overlay == _outline_material:
			mesh.material_overlay = _outlined[value] as Material
	_outlined.clear()
