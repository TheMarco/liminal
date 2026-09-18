extends SceneTree
## Roster models must pose with feet at local zero and the body centred on the
## origin. The hound ships with its skeleton offset from the scene origin, which
## used to sink it into the floor, push it metres behind its slot, and let the
## ghost foot-fade erase everything below local zero (rear, legs, belly).
## Checks every roster model: posed surface centred, ghost foot_base at the
## posed minimum, and culling bounds covering the posed mesh.
## Run: godot --headless --path . --script tools/audit_walker_origin.gd

# A mid-stride frame legitimately offsets humanoids by ~10cm; the check
# guards gross origin errors (the hound sat metres off its origin).
const CENTER_TOL := 0.15
const CULL_TOL := 0.05

var failures: Array[String] = []
var checked := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for index in ShadowWalkerVisual.model_count():
		await _check_model(index)
	print("walker origin: %d checked, %d failures" % [checked, failures.size()])
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for failure in failures.slice(0, 12):
			push_error(failure)
		print("FAIL")
		quit(1)


func _check_model(index: int) -> void:
	var visual := ShadowWalkerVisual.new()
	visual.model_index = index
	root.add_child(visual)
	await process_frame
	await process_frame
	if visual._model == null:
		failures.append("model %d failed to load" % index)
		visual.free()
		return
	var meshes := visual._meshes(visual._model)
	if meshes.is_empty():
		failures.append("model %d has no meshes" % index)
		visual.free()
		return
	var box := AABB()
	var first := true
	var to_global := visual.global_transform
	for mesh in meshes:
		var to_local := mesh.global_transform.affine_inverse() * to_global
		var local_min := INF
		for surface in mesh.mesh.get_surface_count():
			for point in visual._posed_surface_vertices(mesh, surface):
				if first:
					box = AABB(point, Vector3.ZERO)
					first = false
				else:
					box = box.expand(point)
				local_min = minf(local_min, (to_local * point).y)
		_checked_mesh(index, visual, mesh, box, local_min)
	if first:
		failures.append("model %d produced no surface points" % index)
		visual.free()
		return
	checked += 1
	var center := box.get_center()
	if absf(center.x) > CENTER_TOL or absf(center.z) > CENTER_TOL \
			or absf(box.position.y) > CENTER_TOL:
		failures.append("model %d posed off origin: min=%s center=%s" % [
			index, str(box.position), str(center)])
	visual.free()


func _checked_mesh(index: int, visual: ShadowWalkerVisual, mesh: MeshInstance3D,
		box: AABB, local_min: float) -> void:
	if local_min == INF:
		failures.append("model %d mesh %s has no vertices" % [index, mesh.name])
		return
	for surface in mesh.mesh.get_surface_count():
		var mat := mesh.get_surface_override_material(surface) as ShaderMaterial
		if mat != null and mat.shader == ShadowWalkerVisual.GHOST_SHADER:
			var foot_base: Variant = mat.get_shader_parameter(&"foot_base")
			if foot_base == null:
				failures.append("model %d ghost body has no foot_base" % index)
			elif foot_base > local_min + 0.001 or foot_base < local_min - 0.05:
				failures.append("model %d foot_base %s misses posed min %s" % [
					index, str(foot_base), str(local_min)])
			break
	var custom := mesh.custom_aabb
	var effective: AABB = custom \
		if custom.size.length() > 0.001 else mesh.mesh.get_aabb()
	var culling := mesh.global_transform * effective
	var posed := visual.global_transform * box
	if not culling.grow(CULL_TOL).encloses(posed):
		failures.append("model %d culling %s misses posed %s" % [
			index, str(culling), str(posed)])
