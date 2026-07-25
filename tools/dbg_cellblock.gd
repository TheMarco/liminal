extends SceneTree
## Dev: build one prison chunk directly and report what furnished it.
## Run: godot --headless --path . --script tools/dbg_cellblock.gd -- <seed> <cx> <cz>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 4242
	var c := Vector2i(int(args[1]) if args.size() > 1 else 1,
		int(args[2]) if args.size() > 2 else 0)
	var ws := WorldGen.level_seed(base, 8)
	var ch := Chunk.new(ws, c, 8)
	print("cell %s style=%d anchor=%s room_n=%d ceil=%.2f descent_target=%s" % [
		c, ch.style, ch.is_room_anchor, ch.room_n, ch.ceil_h, ch.descent_target])
	print("children=%d body_colliders=%d" % [ch.get_child_count(), ch.body.get_child_count()])
	var mats := {}
	for n in ch.get_children():
		if n is MeshInstance3D:
			var mo: Material = (n as MeshInstance3D).material_override
			var key := "none"
			if mo != null:
				key = str(mo.get_instance_id())
			mats[key] = mats.get(key, 0) + 1
		elif n.has_meta("atomic_furnishing"):
			print("atomic furnishing: ", n.get_meta("atomic_furnishing"),
				" at ", (n as Node3D).position if n is Node3D else Vector3.ZERO)
	print("mesh children by material id: ", mats)
	var ax := WorldGen.r01(ws, WorldGen.room_id(ws, c).x, WorldGen.room_id(ws, c).y, 1840)
	print("axis r01=%.3f -> dirs %s" % [ax, "[2,3]" if ax < 0.5 else "[0,1]"])
	quit()
