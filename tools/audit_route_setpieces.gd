extends SceneTree
var failures: Array[String] = []

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var inspected := 0
	for seed_value in [21, 7, 12345]:
		for floor_index in DescentRun.FIXED_ORDER.size():
			var theme: int = DescentRun.FIXED_ORDER[floor_index]
			var route := DescentRoute.build(seed_value, theme, floor_index)
			print("SETPIECE %d theme %d: %s side %s" % [seed_value, theme, route.landmark_rooms, route.discovery_rooms])
			if floor_index > 0: check(route.landmark_rooms.size() == 1, "missing landmark seed %d theme %d" % [seed_value, theme])
			check(route.landmark_rooms == RouteSetpieces.plan_landmarks(route), "landmark plan not deterministic")
			check(route.discovery_rooms == RouteSetpieces.plan_discoveries(route), "discovery plan not deterministic")
			var protected := DescentTopology.new(seed_value, theme)._protected_cells(route)
			for room in route.landmark_rooms:
				check(route.is_path_room(room), "landmark not on route")
				check(protected.has(room) and not route.is_intro_door_room(room), "landmark not protected or overlaps a photo doorway")
				if seed_value != 21: continue
				var spec := ChunkBuildSpec.new()
				spec.descent = true
				spec.floor_idx = floor_index
				spec.route_landmark = str(route.landmark_rooms[room])
				var chunk := Chunk.new(seed_value, room, theme, spec)
				root.add_child(chunk)
				await physics_frame
				check(chunk.has_meta("route_landmark"), "landmark missing metadata")
				if chunk.style != RouteSetpieces.NATIVE[theme]:
					check(chunk.has_node("RouteLandmark"), "landmark culled or not built: theme %d" % theme)
				check(chunk.doorway_clearance_violations() == 0, "landmark blocks doorway: theme %d" % theme)
				chunk.free()
				await process_frame
				inspected += 1
			for room in route.discovery_rooms:
				check(not route.is_path_room(room) and protected.has(room), "discovery on route or unprotected")
				check(not route.is_intro_door_room(room), "discovery overlaps a photo doorway")
				if seed_value != 21: continue
				var spec := ChunkBuildSpec.new()
				spec.descent = true
				spec.optional_discovery = true
				spec.optional_vhs = true
				spec.optional_vhs_key = "audit:side:%d" % theme
				spec.floor_idx = floor_index
				var chunk := Chunk.new(seed_value, room, theme, spec)
				root.add_child(chunk)
				await physics_frame
				check(chunk.has_node("OptionalVhs"), "side discovery failed placement: theme %d" % theme)
				check(chunk.doorway_clearance_violations() == 0, "side discovery blocks doorway: theme %d" % theme)
				chunk.free()
				await process_frame
	print("Route setpieces: 33 routes, %d landmark rooms built, failures=%s" % [inspected, failures])
	quit(0 if failures.is_empty() else 1)
