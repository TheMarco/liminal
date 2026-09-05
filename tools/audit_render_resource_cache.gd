extends SceneTree
## Focused contract for pool render-resource reuse.
## Run: godot --headless --path . --script tools/audit_render_resource_cache.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	PoolCornerMesh.clear_runtime_cache()
	PoolOpeningMesh.clear_runtime_cache()
	var c := PoolCornerMesh.quarter_cove(
		Vector2.ZERO, Vector2.RIGHT, PI * 0.5, 1.0, Vector2(1.0, 1.0),
		0.0, 2.0, 8)
	if c.get_instance_id() != PoolCornerMesh.quarter_cove(
		Vector2.ZERO, Vector2.RIGHT, PI * 0.5, 1.0, Vector2(1.0, 1.0),
		0.0, 2.0, 8).get_instance_id():
		failures.append("identical corner calls did not share mesh")
	var near := PoolCornerMesh.quarter_cove(
		Vector2.ZERO, Vector2.RIGHT, PI * 0.5, 1.0, Vector2(1.0005, 1.0),
		0.0, 2.0, 8)
	if near.get_instance_id() == c.get_instance_id():
		failures.append("nearby corner inputs collided")
	var path: Array[Vector2] = [Vector2.ZERO, Vector2(1.0, 0.2), Vector2(2.0, 0.0)]
	var p := PoolCornerMesh.path_bullnose(
		path, 1.0, 0.18, 0.05, 0.0, 0.12, 6)
	if p.surface_get_arrays(0) != PoolCornerMesh._path_bullnose_build(
		path, 1.0, 0.18, 0.05, 0.0, 0.12, 6).surface_get_arrays(0):
		failures.append("cached path geometry differs from builder")
	var panel := PoolOpeningMesh.circular_aperture_panel(1.0, 0.3, 3.0, 1.5, 16)
	if panel.surface_get_arrays(0) != PoolOpeningMesh._circular_aperture_panel_build(
		1.0, 0.3, 3.0, 1.5, 16).surface_get_arrays(0):
		failures.append("cached aperture geometry differs from builder")
	for i in 129:
		PoolCornerMesh.quarter_cove(
			Vector2(float(i), 0.0), Vector2.RIGHT, PI * 0.5, 1.0,
			Vector2(1.0, 1.0), 0.0, 2.0, 8)
	if PoolCornerMesh._mesh_cache.size() > 128:
		failures.append("corner cache exceeded 128 entries")
	PoolCornerMesh.clear_runtime_cache()
	PoolOpeningMesh.clear_runtime_cache()
	if failures.is_empty():
		print("render resource cache audit passed")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)
