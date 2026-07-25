extends SceneTree
## Dev: build one asylum cell and print where every authored prop landed, with
## its world AABB, so placement can be checked without opening a window.
## Run: godot --headless --path . --script tools/dbg_asylum.gd -- <seed> <x> <z>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 12345
	var cx := int(args[1]) if args.size() > 1 else 4
	var cz := int(args[2]) if args.size() > 2 else 3
	var ws := WorldGen.level_seed(base, 5)
	var cell := Vector2i(cx, cz)
	var style := WorldGen.cell_style(ws, cell, 5)
	print("cell %s  style %d  room %s" % [cell, style, WorldGen.room_id(ws, cell)])
	var chunk := Chunk.new(ws, cell, 5)
	# The chunk is never added to a tree here, so walk it from its own root
	# rather than asking for a global transform that does not exist yet.
	_walk(chunk, Transform3D.IDENTITY)
	chunk.free()
	quit()


func _walk(n: Node, xf: Transform3D) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	var tag := ""
	if n.has_meta("attributed_furnishing"):
		tag = str(n.get_meta("attributed_furnishing"))
	elif n.has_meta("asylum_wall_notices"):
		tag = "wall_notices"
	elif bool(n.get_meta("wall_mounted_asylum_door", false)):
		tag = "facade_door"
	if not tag.is_empty() and n is Node3D:
		var bb := _aabb(n, xf * (n as Node3D).transform.affine_inverse())
		print("  %-18s at %s yaw %7.1f  aabb %s size %s" % [
			tag, _v(xf.origin), rad_to_deg((n as Node3D).rotation.y),
			_v(bb.position), _v(bb.size)])
	for c in n.get_children():
		_walk(c, xf)


func _v(v: Vector3) -> String:
	return "(%6.2f,%6.2f,%6.2f)" % [v.x, v.y, v.z]


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = xf * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var bb := _aabb(c, xf)
		if bb.size != Vector3.ZERO:
			out = bb if first else out.merge(bb)
			first = false
	return out
