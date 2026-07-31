extends SceneTree
## Prints ready-to-use viewpoints for the School fixture regressions.
## Run: godot --headless --path . --script tools/dbg_school_fixtures.gd -- \
##   [base_seed] [radius]


func _init() -> void:
	call_deferred("_run")


func _viewpoint(target: Vector3, into_room: Vector3, distance: float) -> String:
	var direction := into_room.normalized()
	if direction.length_squared() < 0.5:
		direction = Vector3.FORWARD
	var stand := target + direction * distance
	var look := (target - stand).normalized()
	var yaw := rad_to_deg(atan2(-look.x, -look.z))
	return "--pos=%.2f,%.2f --yaw=%.1f" % [stand.x, stand.z, yaw]


func _wall_inward(dir: int) -> Vector3:
	match dir:
		0: return Vector3.LEFT
		1: return Vector3.RIGHT
		2: return Vector3.BACK
	return Vector3.FORWARD


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 1065674081
	var radius := clampi(int(args[1]) if args.size() > 1 else 10, 2, 16)
	var ws := WorldGen.level_seed(base, 6)
	var host := Node3D.new()
	get_root().add_child(host)
	var shown := {
		"door": 0,
		"urinal": 0,
		"stationery": 0,
		"screen": 0,
		"elevator": 0,
		"alarm": 0,
		"library": 0,
	}
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var chunk := Chunk.new(ws, Vector2i(x, z), 6)
			chunk.position = Vector3(float(x) * Chunk.S, 0, float(z) * Chunk.S)
			host.add_child(chunk)
			for node in chunk.find_children("*", "Node3D", true, false):
				var n := node as Node3D
				if n.has_meta("school_swing_door") \
						and int(shown["door"]) < 3:
					var door_dir := int(n.get_meta("door_dir", -1))
					var inward := _wall_inward(door_dir) if door_dir >= 0 \
						else n.global_basis * Vector3(0, 0, 1)
					var target := n.global_position + Vector3.UP * 1.2
					var door_meshes := n.find_children(
						"*", "MeshInstance3D", true, false)
					var door_mesh := door_meshes[0] as MeshInstance3D \
						if not door_meshes.is_empty() else null
					if door_mesh != null:
						target = door_mesh.global_position
					print("door cell=%s pos=%s dir=%d leaf_top=%.3f frame_top=%.3f %s" % [
						Vector2i(x, z),
						target,
						door_dir,
						float(n.get_meta("school_door_leaf_top")),
						float(n.get_meta("school_door_frame_top")),
						_viewpoint(target, inward, 2.8)])
					shown["door"] = int(shown["door"]) + 1
				elif str(n.get_meta("attributed_furnishing", "")) \
						== "school_urinal" and int(shown["urinal"]) < 3:
					var dir := int(n.get_meta("school_urinal_wall_dir"))
					print("urinal cell=%s standoff=%.3f %s" % [
						Vector2i(x, z),
						float(n.get_meta("school_urinal_mount_standoff")),
						_viewpoint(n.global_position + Vector3.UP,
							_wall_inward(dir), 2.6)])
					shown["urinal"] = int(shown["urinal"]) + 1
				elif n.has_meta("school_teacher_stationery") \
						and int(shown["stationery"]) < 3:
					var centre_direction := (
						chunk.global_position
						+ Vector3(Chunk.S * 0.5, 0, Chunk.S * 0.5)
						- n.global_position)
					print("stationery cell=%s local_y=%.4f local_yaw=%.1f %s" % [
						Vector2i(x, z), n.position.y,
						rad_to_deg(n.rotation.y),
						_viewpoint(n.global_position, centre_direction, 2.2)])
					shown["stationery"] = int(shown["stationery"]) + 1
				elif n.has_meta("school_projector_screen") \
						and int(shown["screen"]) < 3:
					var screen_dir := int(n.get_meta("school_projector_screen"))
					print("screen cell=%s compact=%s %s" % [
						Vector2i(x, z),
						bool(n.get_meta("school_projector_screen_compact")),
						_viewpoint(n.global_position + Vector3.UP * 2.1,
							_wall_inward(screen_dir), 3.4)])
					shown["screen"] = int(shown["screen"]) + 1
				elif n.has_meta("elevator_facade") \
						and int(shown["elevator"]) < 3:
					print("elevator cell=%s counters=%d %s" % [
						Vector2i(x, z),
						int(chunk.school_fixture_integrity_audit()[
							"admin_counters"]),
						_viewpoint(n.global_position + Vector3.UP * 1.3,
							n.global_basis * Vector3(0, 0, 1), 4.2)])
					shown["elevator"] = int(shown["elevator"]) + 1
				elif n.has_meta("structural_exit_alarm") \
						and int(shown["alarm"]) < 3:
					print("alarm cell=%s asset=%s %s" % [
						Vector2i(x, z), str(n.get_meta("attributed_asset")),
						_viewpoint(n.global_position,
							n.global_basis * Vector3(0, 0, 1), 2.8)])
					shown["alarm"] = int(shown["alarm"]) + 1
				elif n.has_meta("school_library_encyclopedia_set") \
						and int(shown["library"]) < 3:
					var room_direction := (
						chunk.global_position
						+ Vector3(Chunk.S * 0.5, 0, Chunk.S * 0.5)
						- n.global_position)
					print("library books cell=%s parent=%s %s" % [
						Vector2i(x, z), n.get_parent().name,
						_viewpoint(n.global_position, room_direction, 3.0)])
					shown["library"] = int(shown["library"]) + 1
			host.remove_child(chunk)
			chunk.free()
	print("School fixture viewpoints: %s" % shown)
	host.free()
	quit()
