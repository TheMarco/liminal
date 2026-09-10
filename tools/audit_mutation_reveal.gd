extends SceneTree
## Focused contract for the blackout's world-space mutation locator.

const EFFECT := preload("res://scripts/mutation_reveal_effect.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	failures += 1


func _collect(node: Node, type_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	if node.is_class(type_name):
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect(child, type_name))
	return found


func _portal_trace_height(effect: Node3D) -> float:
	for child in effect.get_children():
		if child is Node3D and _collect(child, &"MeshInstance3D").size() == 4:
			return (child as Node3D).position.y
	return -1.0


func _run() -> void:
	var target := Node3D.new()
	root.add_child(target)
	var target_mesh := MeshInstance3D.new()
	target_mesh.mesh = BoxMesh.new()
	target.add_child(target_mesh)
	var ghost := Node3D.new()
	var ghost_mesh := MeshInstance3D.new()
	ghost_mesh.mesh = BoxMesh.new()
	ghost.add_child(ghost_mesh)
	var effect := EFFECT.new()
	root.add_child(effect)
	if EFFECT.LIFE_SECONDS < 2.0 or EFFECT.LIFE_SECONDS > 3.0:
		_fail("mutation reveal lifetime is outside the requested two-to-three second window")
	effect.configure({
		"kind": "door",
		"position": Vector3.ZERO,
		"edge_center": Vector3.ZERO,
		"opening_height": 3.4,
		"edge": {
			"dir": 0,
			"before": {},
			"after": {"kind": "open", "w": 2.8},
		},
		"nodes": [target],
		"ghost": ghost,
	})
	await process_frame
	if not effect.has_meta("mutation_reveal_effect") \
			or not effect.is_in_group("mutation_reveal_effect"):
		_fail("mutation reveal is not discoverable for replacement/cleanup")
	if target_mesh.material_overlay == null:
		_fail("mutation reveal did not outline the exact installed mesh")
	var outline := target_mesh.material_overlay as ShaderMaterial
	if outline == null or outline.shader == null \
			or "depth_test_disabled" in outline.shader.code:
		_fail("installed outline bypasses world occlusion")
	if ghost.get_parent() != effect or ghost_mesh.material_override == null:
		_fail("mutation reveal did not install the vanished mesh ghost")
	var effect_meshes := _collect(effect, &"MeshInstance3D")
	if effect_meshes.size() != 5:
		_fail("door mutation lacks its exact four-sided boundary trace")
	if not is_equal_approx(_portal_trace_height(effect), 1.7):
		_fail("door mutation trace does not center its custom opening height")
	var custom_height_found := false
	for mesh_node in effect_meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh is BoxMesh \
				and is_equal_approx((mesh_instance.mesh as BoxMesh).size.y, 3.4):
			custom_height_found = true
			break
	if not custom_height_found:
		_fail("door mutation trace does not respect its custom opening height")
	for mesh_node in effect_meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh is QuadMesh:
			_fail("mutation reveal still contains a circular billboard locator")
		var surface := mesh_instance.material_override as StandardMaterial3D
		if surface != null and surface.no_depth_test:
			_fail("ghost/door silhouette bypasses world occlusion")
	var lights := _collect(effect, &"OmniLight3D")
	if not lights.is_empty():
		_fail("mutation reveal still casts a free-floating light beyond its silhouette")

	effect.advance(0.24)
	if outline != null \
			and absf(float(outline.get_shader_parameter("grow")) - 0.045) < 0.0001:
		_fail("exact mesh outline did not pulse")

	var reference: WeakRef = weakref(effect)
	effect.advance(EFFECT.LIFE_SECONDS)
	await process_frame
	var remaining: Variant = reference.get_ref()
	if remaining != null:
		_fail("mutation reveal survived beyond its bounded lifetime")
	if target_mesh.material_overlay != null:
		_fail("mutation reveal did not restore the target's original overlay")

	if failures == 0:
		print("mutation reveal audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)
