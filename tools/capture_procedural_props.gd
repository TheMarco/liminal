extends SceneTree
## Compare generated props using the same stage, camera and original builders.
## --baseline uses local snapshots under ignored build/procedural-review/source-before.
## godot --path . --audio-driver Dummy --disable-render-loop --script \
##   tools/capture_procedural_props.gd -- --out=/tmp/props [--baseline] [--filter=...]

class Stage extends "res://tools/preview_prop.gd":
	func _ready() -> void:
		pass

const BUILDERS := {0: "vegas", 1: "office", 2: "annex", 4: "airport",
	5: "asylum", 6: "school", 7: "mall", 8: "prison", 9: "pool",
	10: "brutalist", 11: "bloom"}
var output := "res://build/procedural-review/after"
var baseline := false
var filter := ""
var reverse := false
var both_sides := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		elif arg == "--baseline":
			baseline = true
		elif arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
		elif arg == "--reverse":
			reverse = true
		elif arg == "--both-sides":
			both_sides = true
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)


func rotate_stage(stage: Node3D) -> void:
	for node in stage.get_children():
		if node is Camera3D or node is Light3D:
			node.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * node.transform


func mesh_stats(chunk: Chunk, first: int) -> Dictionary:
	var stats := {"meshes": 0, "surfaces": 0, "triangles": 0}
	var pending: Array[Node] = []
	for i in range(first, chunk.get_child_count()):
		pending.append(chunk.get_child(i))
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		pending.append_array(node.get_children())
		if not node is MeshInstance3D or node.mesh == null:
			continue
		stats.meshes += 1
		stats.surfaces += node.mesh.get_surface_count()
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			stats.triangles += (indices.size() if indices != null and not indices.is_empty()
				else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return stats


func run() -> void:
	Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute(output)
	var chunk_script: Script = preload("res://scripts/chunk.gd")
	if baseline:
		# Override only shared procedural recipes; inherit the production Chunk
		# type so contexts remain valid. Snapshots are text, never editor classes.
		var source := FileAccess.get_file_as_string(
			"res://build/procedural-review/source-before/chunk.gd.txt")
		var original := GDScript.new()
		original.source_code = "extends Chunk\n"
		for method in ["_filing_bank", "_vt100", "_vt100_keyboard", "_shelf_unit",
				"_small_desk", "_interactive_elevator", "_descent_car_shell"]:
			var start := source.find("\nfunc " + method + "(")
			assert(start >= 0)
			var end := source.find("\nfunc ", start + 1)
			# End at the next top-level declaration/comment boundary only after
			# extracting this function's indented body.
			var lines := source.substr(start + 1, end - start - 1).split("\n")
			for index in range(1, lines.size()):
				var line: String = lines[index]
				if not line.is_empty() and not line.begins_with("\t") and not line.begins_with("#"):
					lines.resize(index)
					break
			while not lines.is_empty() and (lines[-1].is_empty() or lines[-1].begins_with("#")):
				lines.remove_at(lines.size() - 1)
			original.source_code += "\n" + "\n".join(lines) + "\n"
		assert(original.reload() == OK, "Cannot compile original shared recipes")
		chunk_script = original
	var catalog: Array = []
	for suffix in ["a", "b", "c", "shared"]:
		var path := "res://tools/prop_review_%s.gd" % suffix
		if FileAccess.file_exists(path):
			catalog.append_array(load(path).cases())
	var manifest: Array = []
	for entry in catalog:
		if not filter.is_empty() and not filter in entry.name:
			continue
		var view := SubViewport.new()
		view.size = Vector2i(960, 720)
		view.own_world_3d = true
		view.msaa_3d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var stage := Stage.new()
		view.add_child(stage)
		var theme: int = entry.theme
		var base_seed: int = int(entry.get("seed", 4242))
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		var chunk: Chunk = chunk_script.new(WorldGen.level_seed(base_seed, theme), cell, theme)
		stage.add_child(chunk)
		for node in chunk.get_children():
			if node is Node3D:
				node.visible = false
		if baseline:
			var path := "res://build/procedural-review/source-before/%s_level_builder.gd.txt" % BUILDERS[theme]
			var original := GDScript.new()
			original.source_code = FileAccess.get_file_as_string(path)
			assert(original.reload() == OK, "Cannot compile original builder")
			chunk._level_builder = original.new(chunk._build_context, chunk._scene_writer)
		var first := chunk.get_child_count()
		var method: String = entry.get("baseline_method", entry.method) if baseline else entry.method
		var target: Object = chunk if chunk.has_method(method) else chunk._level_builder
		var args: Array = (entry.get("baseline_args", entry.args) if baseline else entry.args).duplicate()
		if entry.get("parent", false):
			var parent := Node3D.new()
			parent.position = Vector3(6, 0, 6)
			chunk.add_child(parent)
			args.push_front(parent)
		target.callv(method, args)
		var bounds := stage._bounds(chunk, first)
		if bounds.size == Vector3.ZERO:
			printerr("No geometry for %s" % entry.name)
			view.free()
			continue
		var shift := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		for i in range(first, chunk.get_child_count()):
			var node := chunk.get_child(i)
			if node is Node3D:
				node.position += shift
		bounds.position += shift
		stage._stage(bounds)
		if entry.has("camera_fov"):
			for node in stage.get_children():
				if node is Camera3D:
					node.fov = float(entry.camera_fov)
		if reverse:
			rotate_stage(stage)
		await frames(24)
		var image := view.get_texture().get_image()
		assert(image.save_png(output.path_join(entry.name + ".png")) == OK)
		if both_sides:
			rotate_stage(stage)
			await frames(12)
			assert(view.get_texture().get_image().save_png(
				output.path_join(entry.name + "-reverse.png")) == OK)
		manifest.append({"name": entry.name, "theme":theme,
			"size": [bounds.size.x, bounds.size.y, bounds.size.z],
			"geometry": mesh_stats(chunk, first)})
		print("PROP %s %s" % [entry.name, bounds.size])
		view.free()
		await frames(2)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	assert(file != null, "Cannot write review manifest")
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("PROP CAPTURE COMPLETE: %d" % manifest.size())
	quit()
