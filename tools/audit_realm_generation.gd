extends "res://tools/lib/audit_base.gd"
## Procedural admission audit for the optional realm visit doorway.
## Usage: -- --seed=21 [--floor=N] [--states=N] [--planning-only]

func run() -> void:
	var seed := 21
	var floor_filter := -1
	var states := 1
	var planning_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--floor="):
			floor_filter = int(arg.trim_prefix("--floor=")) - 1
		elif arg.begins_with("--states="):
			states = clampi(int(arg.trim_prefix("--states=")), 1, 7)
		elif arg == "--planning-only":
			planning_only = true
	var checked := 0
	for floor_idx in DescentRun.order_for(seed).size():
		if floor_filter >= 0 and floor_idx != floor_filter:
			continue
		var theme := DescentRun.order_for(seed)[floor_idx]
		var ws := WorldGen.level_seed(seed, theme)
		var label := "seed=%d floor=%d theme=%d" % [seed, floor_idx + 1, theme]
		var route := DescentRoute.build(ws, theme, floor_idx)
		var path := route.path_from_origin()
		var topology := DescentTopology.new(ws, theme)
		route.set_topology(topology)
		topology.plan_floor(route)
		var realm_records: Array[Dictionary] = topology.photo_doorways().filter(func(r: Dictionary): return bool(r.get("realm", false)))
		var evidence := PhotoDirector.build_plan(route)
		expect(evidence.size() >= PhotoDirector.required_for(floor_idx, theme), label + " cannot satisfy photograph quota")
		var realm := topology.realm_door()
		if floor_idx < DescentRun.FLOOR_COUNT - 1:
			expect(realm_records.size() == 1, label + " has %d realm door records" % realm_records.size())
			expect(not realm.is_empty(), label + " has no realm doorway")
		else:
			expect(realm_records.is_empty(), label + " has %d realm door records" % realm_records.size())
			expect(realm.is_empty(), label + " incorrectly has a realm doorway")
		if realm.is_empty():
			continue
		var approach: Vector2i = realm.get("approach_cell", realm.get("cell", Vector2i.ZERO))
		var path_index := int(realm.get("approach_path_index", -1))
		expect(path_index >= 0 and path_index <= floori(float(path.size() - 1) / 2.0), label + " realm approach is too late")
		var approach_room = WorldGen.annex_room_id(ws, approach) if theme == 2 else WorldGen.room_id(ws, approach)
		var route_room = WorldGen.annex_room_id(ws, path[path_index]) if theme == 2 and path_index >= 0 and path_index < path.size() else (WorldGen.room_id(ws, path[path_index]) if path_index >= 0 and path_index < path.size() else "")
		expect(path_index < path.size() and approach_room == route_room, label + " realm approach leaves ordinary route room")
		expect(str(realm.get("key", "")) != str(route.obstruction_hint.get("key", "")), label + " realm reuses obstruction edge")
		if floor_idx == 0 and not route.intro_door_hint.is_empty():
			expect(str(realm.get("key", "")) == str(route.intro_door_hint.get("key", "")), label + " casino realm edge differs from intro edge")
		var rebuilt := DescentRoute.build(ws, theme, floor_idx)
		expect(rebuilt.realm_door_hint == route.realm_door_hint, label + " realm hint is not deterministic")
		expect(realm == rebuilt.realm_door_hint, label + " realm topology record changed after rebuild")
		expect(route.path_from_origin() == path, label + " ordinary route changed before photograph")
		if planning_only:
			print("REALM PLAN %s id=%s approach=%s path_index=%d" % [label, realm.get("id", ""), approach, path_index])
			continue
		var cm := ChunkManager.new()
		cm.world_seed = ws
		cm.theme = theme
		cm.descent = true
		cm.descent_floor_idx = floor_idx
		cm.descent_base_seed = seed
		cm.descent_route = route
		cm.descent_topology = topology
		var director := PhotoDirector.new()
		director.world_seed = ws
		director.theme = theme
		var endpoints := [Vector2i(realm["cell"]), Vector2i(realm["cell"]) + WorldGen.DIRV[DescentTopology.edge_dir(realm)]]
		for state in range(mini(states, topology.state_count())):
			var parts: Array[Chunk] = []
			var seen := {}
			for endpoint in endpoints:
				for member in WorldGen.owning_room_members(ws, endpoint, theme):
					if seen.has(member):
						continue
					seen[member] = true
					parts.append(cm._build(member, false, state))
			expect(director._photo_door_approach_clear(realm, parts), "%s state=%d realm approach is blocked" % [label, state])
			checked += 1
			for part in parts:
				stop_audio(part)
				part.free()
		director.free()
		cm.free()
		await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("realm generation: %d physical doorway checks" % checked)
