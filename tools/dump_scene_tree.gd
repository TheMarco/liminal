extends SceneTree
## Prints imported scene nodes, transforms and mesh bounds.
## Run: godot --headless --path . --script tools/dump_scene_tree.gd -- <res://path>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass a res:// scene path.")
		quit(1)
		return
	var scene := load(args[0]) as PackedScene
	if scene == null:
		push_error("Could not load %s" % args[0])
		quit(1)
		return
	var root := scene.instantiate() as Node3D
	_print_node(root, Transform3D.IDENTITY, "")
	root.free()
	quit()


func _print_node(node: Node, parent_xf: Transform3D, indent: String) -> void:
	var global_xf := parent_xf
	var detail := ""
	if node is Node3D:
		var spatial := node as Node3D
		global_xf = parent_xf * spatial.transform
		detail = " pos=%s rot=%s scale=%s" % [
			spatial.position, spatial.rotation_degrees, spatial.scale]
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		detail += " local_aabb=%s world_aabb=%s" % [
			mesh_node.mesh.get_aabb(), global_xf * mesh_node.mesh.get_aabb()]
	print("%s%s <%s>%s" % [indent, node.name, node.get_class(), detail])
	for child in node.get_children():
		_print_node(child, global_xf, indent + "  ")
