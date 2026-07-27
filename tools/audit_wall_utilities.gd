extends SceneTree
## Runtime contract for the authored outlet and light-switch infrastructure.
##
## Run:
##   godot --headless --path . --script tools/audit_wall_utilities.gd

const EXPECTED := {
	"outlet": {
		"path": "res://models/cc_by/outlet/outlet.glb",
		"height": 0.31,
		"face_width": 0.08,
		"face_height": 0.12,
	},
	"light_switch": {
		"path": "res://models/cc_by/light_switch/light_switch.glb",
		"height": 1.12,
		"face_width": 0.07,
		"face_height": 0.114,
	},
}


func _find_asset(node: Node, path: String) -> Node3D:
	if str(node.get_meta("attributed_asset", "")) == path:
		return node as Node3D
	for child in node.get_children():
		var found := _find_asset(child, path)
		if found != null:
			return found
	return null


func _model_bounds(node: Node, parent_xf := Transform3D.IDENTITY) -> AABB:
	var xf := parent_xf
	var bounds := AABB()
	var found := false
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		bounds = xf * mesh_node.mesh.get_aabb()
		found = true
	for child in node.get_children():
		var child_bounds := _model_bounds(child, xf)
		if child_bounds.size == Vector3.ZERO:
			continue
		bounds = bounds.merge(child_bounds) if found else child_bounds
		found = true
	return bounds


func _init() -> void:
	var failures: Array[String] = []
	for kind in EXPECTED:
		var contract: Dictionary = EXPECTED[kind]
		var packed := load(str(contract["path"])) as PackedScene
		if packed == null:
			failures.append("%s model cannot be loaded" % kind)
			continue
		var model := packed.instantiate() as Node3D
		var bounds := _model_bounds(model)
		model.free()
		var face_width := maxf(bounds.size.x, bounds.size.z)
		if absf(face_width - float(contract["face_width"])) > 0.002 \
				or absf(bounds.size.y - float(contract["face_height"])) > 0.002:
			failures.append(
				"%s plate is not real-world size: %.3f x %.3fm" % [
					kind, face_width, bounds.size.y])
	var total_chunks := 0
	var office_chunks := 0
	var corridor_chunks := 0
	var utility_count := 0
	var office_outlets := 0
	var office_switches := 0
	var corridor_outlets := 0
	var corridor_switches := 0
	for si in 4:
		var ws := WorldGen.level_seed(5153 + si * 3571, 1)
		for x in range(-4, 5):
			for z in range(-4, 5):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, 1)
				var chunk := Chunk.new(ws, cell, 1)
				total_chunks += 1
				office_chunks += 1
				if style == WorldGen.OFFICE_CORRIDOR:
					corridor_chunks += 1
				for node in chunk.find_children("*", "Node3D", true, false):
					if not node.has_meta("wall_utility_kind"):
						continue
					utility_count += 1
					var kind := str(node.get_meta("wall_utility_kind"))
					if not EXPECTED.has(kind):
						failures.append("unknown utility kind %s at %s" % [
							kind, cell])
						continue
					var contract: Dictionary = EXPECTED[kind]
					if int(node.get_meta("wall_utility_theme", -1)) != 1:
						failures.append("office utility has wrong theme at %s" % [
							cell])
					if absf(float(node.get_meta("wall_utility_height", -1.0))
							- float(contract["height"])) > 0.001:
						failures.append("%s has wrong height at %s" % [
							kind, cell])
					var asset := _find_asset(node, str(contract["path"]))
					if asset == null:
						failures.append("%s is missing its authored model at %s" % [
							kind, cell])
					elif not asset.scale.is_equal_approx(Vector3.ONE):
						failures.append("%s is not placed at measured 1:1 scale at %s" % [
							kind, cell])
					if kind == "outlet":
						office_outlets += 1
						if style == WorldGen.OFFICE_CORRIDOR:
							corridor_outlets += 1
					else:
						office_switches += 1
						if style == WorldGen.OFFICE_CORRIDOR:
							corridor_switches += 1
				chunk.free()

	if office_outlets == 0 or office_switches == 0:
		failures.append("office sample did not generate both utility types")
	if corridor_chunks == 0:
		failures.append("office corridor contract was not exercised")
	elif corridor_outlets == 0 or corridor_switches == 0:
		failures.append(
			"visible office corridors did not generate both utility types")
	var density := float(utility_count) / float(maxi(office_chunks, 1))
	if density < 0.45 or density > 4.50:
		failures.append("office utility density outside normal range: %.3f/chunk" % [
			density])

	print("Wall-utility audit: %d office chunks (%d corridors), %d utilities — %d outlets / %d switches; corridors %d / %d" % [
		total_chunks, corridor_chunks, utility_count,
		office_outlets, office_switches,
		corridor_outlets, corridor_switches])
	if failures.is_empty():
		print("  PASS — authored switches and outlets occupy rooms and visible office corridors")
		quit(0)
		return
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("  FAIL — %d wall-utility contract violations" % failures.size())
	quit(1)
