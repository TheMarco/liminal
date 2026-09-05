extends SceneTree
## Runtime contract for the layered GhostVisual owner and its four mesh layers.
## Run: godot --headless --path . --script tools/audit_ghost_visuals.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var root_node := Node3D.new()
	get_root().add_child(root_node)
	var visuals: Array[GhostVisual] = []
	for variant in ShadowFigure.LOOKS:
		var figure := ShadowFigure.new()
		figure.variant = variant
		root_node.add_child(figure)
		figure.set_physics_process(false)
		var visual := figure._quad
		visual.set_process(false)
		visuals.append(visual)
		var sheet: String = ShadowFigure.LOOKS[variant][0]
		if visual._layers.size() != 4 or visual._layers[0].material_override.shader != GhostVisual.SHADER:
			failures.append("visual %s lacks four layered shader meshes" % sheet)
		for i in visual._layers.size():
			if visual._layers[i].get_instance_shader_parameter("layer") != float(i):
				failures.append("visual %s layer index mismatch" % sheet)
		var expected := load("res://textures/ghosts/%s.webp" % sheet)
		if visual._layers[0].material_override.get_shader_parameter("tex") != expected:
			failures.append("visual %s texture mismatch" % sheet)

	var visual := visuals[0]
	for parameter in [&"fade", &"torch", &"burn", &"ignite", &"flip", &"dissolve_smoke"]:
		var value := 0.35
		if parameter == &"torch": value = 0.7
		if parameter == &"burn": value = 0.5
		if parameter == &"ignite": value = 1.0
		if parameter == &"flip" or parameter == &"dissolve_smoke": value = 1.0
		visual.set_instance_shader_parameter(parameter, value)
		for pane in visual._layers:
			if pane.get_instance_shader_parameter(parameter) != value:
				failures.append("parameter %s did not reach every layer" % parameter)
	visual.set_instance_shader_parameter(&"fade", 1.0)
	visual.set_instance_shader_parameter(&"ignite", 0.0)
	for pane in visual._layers:
		if pane.get_instance_shader_parameter(&"fade") != 1.0 \
				or pane.get_instance_shader_parameter(&"ignite") != 0.0:
			failures.append("recovery did not restore every layer")
	var second := ShadowFigure.make_visual("wraith_anim")
	root_node.add_child(second)
	second.set_process(false)
	second.set_instance_shader_parameter(&"fade", 0.2)
	visual.set_instance_shader_parameter(&"fade", 0.35)
	for pane in second._layers:
		if not is_equal_approx(pane.get_instance_shader_parameter(&"fade"), 0.2):
			failures.append("visual instance parameters leaked between visuals")

	var history := ShadowFigure.make_visual("wraith5")
	root_node.add_child(history)
	history.set_process(false)
	history.set_instance_shader_parameter(&"flip_loop", 1.0)
	history.set_instance_shader_parameter(&"flip_frame", 23.5)
	history._process(0.0)
	history.set_instance_shader_parameter(&"flip_frame", 0.5)
	history._process(0.1)
	var seam_sample := history._sample_frame(0.05, true)
	if minf(absf(seam_sample), absf(seam_sample - 24.0)) > 0.001:
		failures.append("history interpolation did not follow the wrap seam")
	for i in 240:
		history.set_instance_shader_parameter(&"flip_frame", 0.5)
		history._process(0.05)
	for pane in history._layers:
		if absf(pane.get_instance_shader_parameter(&"delayed_frame") - 0.5) > 0.001:
			failures.append("veil history did not converge to held frame")
	if history._history.size() >= 20:
		failures.append("frame history is unbounded")
	var camera := Camera3D.new()
	root_node.add_child(camera)
	camera.position = Vector3(3.0, 1.0, 4.0)
	camera.current = true
	history.scale = Vector3(1.4, 2.2, 1.0)
	history._process(0.0)
	var facing := history.global_basis.z.normalized()
	if facing.dot(Vector3(3.0, 0.0, 4.0).normalized()) < 0.999 \
			or not history.scale.is_equal_approx(Vector3(1.4, 2.2, 1.0)):
		failures.append("billboard rotation lost facing or authored proportions")
	var layer_refs := history._layers.duplicate()

	root_node.free()
	await process_frame
	for pane in layer_refs:
		if is_instance_valid(pane): failures.append("a veil outlived its owner")
	if failures.is_empty():
		print("PASS ghost_visuals")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
