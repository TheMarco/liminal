extends SceneTree
## Dev: find painted storefront fascias near the origin and print a ready-made
## --pos/--yaw to stand in front of one, so a screenshot does not have to be
## aimed by trial and error.
## Run: godot --headless --path . --script tools/dbg_mall_signs.gd -- <seed> [radius]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 12345
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 1, 12)
	var ws := WorldGen.level_seed(base, 7)
	var found := 0
	var payphones := 0
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var cell := Vector2i(x, z)
			var chunk := Chunk.new(ws, cell, 7)
			var origin := Vector3(float(x) * Chunk.S, 0.0, float(z) * Chunk.S)
			for node in chunk.find_children("*", "MeshInstance3D", true, false):
				if not node.has_meta("mall_painted_sign"):
					continue
				found += 1
				if found > 6:
					continue
				var m := node as MeshInstance3D
				var w := origin + m.position
				# Stand 3.4m out along the sign's own facing. The player looks
				# down its local -Z, so facing the sign means matching the
				# sign's yaw rather than opposing it.
				var f := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
				var stand := w + f * 3.4
				print("%-22s cell %s  sign at (%.1f, %.2f, %.1f)" % [
					str(node.get_meta("mall_painted_sign")), cell, w.x, w.y, w.z])
				print("    --pos=%.1f,%.1f --yaw=%.0f" % [
					stand.x, stand.z, rad_to_deg(m.rotation.y)])
			for node in chunk.find_children("*", "Node3D", true, false):
				if str(node.get_meta("authored_model", "")) != "payphone":
					continue
				payphones += 1
				if payphones > 3:
					continue
				var bank := node.get_parent() as Node3D
				var pw := origin + bank.position
				var bf := Vector3(sin(bank.rotation.y), 0, cos(bank.rotation.y))
				var ps := pw + bf * 2.6
				print("payphone bank          cell %s  at (%.1f, %.1f)" % [
					cell, pw.x, pw.z])
				print("    --pos=%.1f,%.1f --yaw=%.0f" % [
					ps.x, ps.z, rad_to_deg(bank.rotation.y)])
			chunk.free()
	print()
	print("painted fascias found: %d | payphones: %d  (radius %d, seed %d)" % [
		found, payphones, radius, base])
	quit()
