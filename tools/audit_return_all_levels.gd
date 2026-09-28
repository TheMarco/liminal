extends "res://tools/lib/audit_base.gd"
## One real Descent route per theme: every level must offer at least one safe,
## non-mirrored same-room return without changing its planned topology.

const ReturnDoor := preload("res://scripts/self_return_door_director.gd")


func run() -> void:
	var only_theme := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only-theme="):
			only_theme = int(arg.get_slice("=", 1))
	for floor_idx in DescentRun.FLOOR_COUNT:
		var theme: int = DescentRun.FIXED_ORDER[floor_idx]
		if only_theme >= 0 and theme != only_theme: continue
		var world_seed := WorldGen.level_seed(20260807, theme)
		var route := DescentRoute.build(world_seed, theme, floor_idx)
		var topology := DescentTopology.new(world_seed, theme)
		route.set_topology(topology)
		topology.plan_floor(route)
		var holder := Node3D.new()
		root.add_child(holder)
		var actor := Player.new()
		holder.add_child(actor)
		actor.set_physics_process(false)
		actor.set_process(false)
		var manager := ChunkManager.new()
		manager.world_seed = world_seed
		manager.theme = theme
		manager.descent = true
		manager.descent_floor_idx = floor_idx
		manager.descent_route = route
		manager.descent_topology = topology
		manager.native_doorway_plan = NativeDoorwayPlan.new()
		manager.native_doorway_plan.configure(world_seed, theme, topology)
		manager.player = actor
		holder.add_child(manager)
		manager.set_process(false)
		var door := ReturnDoor.new()
		holder.add_child(door)
		# Exercise an actual scheduler placement on the first floor. Other
		# themes keep the direct preview so every wall pair is still checked.
		var scheduled := floor_idx == 0
		door.preview = not scheduled
		door.configure(manager, actor, func() -> bool: return true,
			func() -> void: pass, route)
		door.set_physics_process(false)
		var scheduler: ArchitecturalEventDirector
		var pacing: HorrorDirector
		if scheduled:
			pacing = HorrorDirector.new()
			holder.add_child(pacing)
			pacing.enabled = true
			pacing.set_physics_process(false)
			door.pacing = pacing
			var breath := preload("res://scripts/environment_breath_director.gd").new()
			var openings := preload("res://scripts/native_doorway_director.gd").new()
			holder.add_child(breath)
			holder.add_child(openings)
			breath.set_physics_process(false)
			openings.set_physics_process(false)
			scheduler = ArchitecturalEventDirector.new()
			holder.add_child(scheduler)
			scheduler.configure(manager, actor, breath, openings, door,
				pacing, func() -> bool: return true)
			scheduler.set_physics_process(false)
			scheduler._clock = 90.0
			scheduler._door_ready_at = INF
			scheduler._return_ready_at = 0.0
			door.clock = 90.0
			door.ready_at = 0.0
		var staged := false
		var rooms: Array[Vector2i] = route.path_from_origin()
		if theme == 2:
			var seen := {}
			for room in rooms: seen[room] = true
			for path_room in route.path_from_origin():
				for offset in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var nearby: Vector2i = path_room + offset
					if not seen.has(nearby):
						seen[nearby] = true
						rooms.append(nearby)
		for room in rooms:
			if room == route.origin or room == route.target \
					or route.is_intro_door_room(room) \
					or ReturnDoor._is_corridor(
						WorldGen.cell_style(world_seed, room, theme)):
				continue
			var chunk := manager.chunk_at(room)
			if chunk == null: chunk = manager._build(room)
			if theme == 2 or theme == 9:
				for owner in [room + Vector2i(-1, 0), room + Vector2i(0, -1)]:
					if manager.chunk_at(owner) == null: manager._build(owner)
			actor.teleport(chunk.to_global(Vector3(6,
				chunk._floor_h() + 0.15, 6)))
			await physics_frame
			if scheduled: door.clock += 3.0
			if (scheduler._try_rare_opportunity() if scheduled else door._try_stage()):
				staged = true
				break
		expect(staged, "return doorway could not stage on %s (floor %d)" % [
			DescentRun.THEME_NAMES[theme], floor_idx + 1])
		if staged:
			if scheduled:
				expect(scheduler.events_started == 0
					and float(pacing.snapshot()["visual"]) > 0.0,
					"return placement was counted before it was seen or lacked a quiet lease")
				actor.cam.look_at(door.site.global_position + Vector3.UP * 1.3)
				door._physics_process(0.016)
				expect(scheduler.events_started == 1
					and int(scheduler.counts.get("return", 0)) == 1,
					"scheduled return was not counted on first sight")
			var source_normal: Vector3 = door.site.global_basis.z.normalized()
			var return_basis: Basis = door._record["return_basis"]
			expect(return_basis.z.dot(-source_normal) > 0.98,
				"return landing mirrored %s" % DescentRun.THEME_NAMES[theme])
			expect(door.site._update_preview_camera()
				and (-door.site._preview_camera.global_basis.z).dot(
					-source_normal) > 0.98,
				"return doorway preview mirrored %s" %
				DescentRun.THEME_NAMES[theme])
			var cell := door.site_cell
			var old_state := topology.current_state_id()
			door._cross()
			expect(door.used and ReturnDoor._cell_of(actor.global_position) == cell
				and topology.current_state_id() == old_state,
				"return crossing changed room or topology on %s" %
				DescentRun.THEME_NAMES[theme])
			if door.used:
				actor.cam.rotation.y = actor.rotation.y
				var landmark: SelfReturnLandmark = door._landmark
				var chair: Vector3 = landmark.global_position + Vector3.UP * 0.5
				var lamp_fixture := landmark.find_child("Flickering ceiling lamp",
					true, false) as MeshInstance3D
				var lamp: Vector3 = lamp_fixture.global_position
				var wall: Vector3 = door._former_door.origin - actor.global_position
				wall.y = 0.0
				var forward_ok := (-actor.global_basis.z).dot(-source_normal) > 0.98
				var chair_ok := actor.cam.is_position_in_frustum(chair)
				var lamp_ok := actor.cam.is_position_in_frustum(lamp)
				var wall_ok := (-actor.global_basis.z).dot(wall.normalized()) < -0.9
				expect(forward_ok and chair_ok and lamp_ok and wall_ok,
					"return reveal lost its forward landmark or rear wall on %s" %
					DescentRun.THEME_NAMES[theme])
		await teardown_game(holder)
	finish("same-room return on all Descent levels")
