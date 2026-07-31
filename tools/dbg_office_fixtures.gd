extends SceneTree
## Prints ready-to-use screenshot viewpoints for the three Office fixture
## regressions: filing drawers, AC/art walls, and visible EXIT alarms.
## Run: godot --headless --path . --script tools/dbg_office_fixtures.gd -- \
##   [base_seed] [radius]


func _init() -> void:
	call_deferred("_run")


func _viewpoint(target: Vector3, into_room: Vector3, distance: float) -> String:
	var stand := target + into_room.normalized() * distance
	var look := (target - stand).normalized()
	var yaw := rad_to_deg(atan2(-look.x, -look.z))
	return "--pos=%.2f,%.2f --yaw=%.1f" % [stand.x, stand.z, yaw]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 1065674081
	var radius := clampi(int(args[1]) if args.size() > 1 else 7, 2, 14)
	var ws := WorldGen.level_seed(base, 1)
	var host := Node3D.new()
	get_root().add_child(host)
	var shown := {"filing": 0, "ac_art": 0, "alarm": 0}
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var chunk := Chunk.new(ws, Vector2i(x, z), 1)
			chunk.position = Vector3(float(x) * Chunk.S, 0, float(z) * Chunk.S)
			host.add_child(chunk)
			for node in chunk.find_children("*", "Node3D", true, false):
				var n := node as Node3D
				if n.has_meta("filing_bank_open_drawer") \
						and int(shown["filing"]) < 5:
					var forward := n.global_basis * Vector3(0, 0, 1)
					print("filing cell=%s row=%d projection=%.3f %s" % [
						Vector2i(x, z),
						int(n.get_meta("filing_bank_open_row")),
						float(n.get_meta("filing_bank_projection")),
						_viewpoint(n.global_position, forward, 2.5)])
					shown["filing"] = int(shown["filing"]) + 1
				elif n.has_meta("office_ac_mount") \
						and int(shown["ac_art"]) < 5:
					var member: Vector2i = n.get_meta("office_ac_member")
					var dir := int(n.get_meta("office_ac_dir"))
					var art := chunk._office_wall_art_layout(member, dir)
					if art.is_empty():
						continue
					var inward := n.global_basis * Vector3(0, 0, 1)
					print("AC+art anchor=%s member=%s dir=%d ac=%.2f art=%.2f %s" % [
						Vector2i(x, z), member, dir,
						float(n.get_meta("office_ac_along")), float(art["along"]),
						_viewpoint(n.global_position, inward, 3.4)])
					shown["ac_art"] = int(shown["ac_art"]) + 1
				elif n.has_meta("structural_exit_alarm") \
						and int(shown["alarm"]) < 5:
					var inward_alarm := n.global_basis * Vector3(0, 0, 1)
					print("alarm cell=%s asset=%s %s" % [
						Vector2i(x, z), str(n.get_meta("attributed_asset")),
						_viewpoint(n.global_position, inward_alarm, 2.8)])
					shown["alarm"] = int(shown["alarm"]) + 1
			host.remove_child(chunk)
			chunk.free()
	print("Office fixture viewpoints: %s" % shown)
	host.free()
	quit()
