extends "res://tools/lib/audit_base.gd"
## One previously solid Office edge, both native endpoints, route overlay,
## and the gameplay director's closed/open collision and cleanup.

const Director := preload("res://scripts/native_doorway_director.gd")


func run() -> void:
	var ws := WorldGen.level_seed(20260807, 1)
	var route := DescentRoute.build(ws, 1, 1)
	var topology := DescentTopology.new(ws, 1)
	route.set_topology(topology)
	topology.plan_floor(route)
	var world := Node3D.new()
	root.add_child(world)
	var manager := ChunkManager.new()
	manager.world_seed = ws
	manager.theme = 1
	manager.descent = true
	manager.descent_topology = topology
	manager.native_doorway_plan = NativeDoorwayPlan.new()
	manager.native_doorway_plan.configure(ws, 1, topology)
	world.add_child(manager)
	manager.set_process(false)
	var actor := Player.new()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	manager.player = actor
	var director := Director.new()
	world.add_child(director)
	director.configure(manager, actor, null, func() -> bool: return true)
	expect(director.cooldown >= Director.FIRST_COOLDOWN.x \
		and director.cooldown <= Director.FIRST_COOLDOWN.y,
		"first automatic doorway attempt is outside the rare pacing window")
	director.set_physics_process(false)
	director.set_process(false)
	var selected := false
	var cell := Vector2i.ZERO
	var dir := 2
	for x in range(-12, 13):
		if selected: break
		for z in range(-12, 13):
			if selected: break
			for axis in [0, 2]:
				cell = Vector2i(x, z)
				dir = axis
				if manager.native_doorway_plan.candidate(cell, dir).is_empty(): continue
				var near := Chunk.new(ws, cell, 1, {"descent": true,
					"topology": topology, "native_doorway_plan": manager.native_doorway_plan})
				var other: Vector2i = cell + WorldGen.DIRV[dir]
				var far := Chunk.new(ws, other, 1, {"descent": true,
					"topology": topology, "native_doorway_plan": manager.native_doorway_plan})
				if near.native_doorway_site(dir).is_empty() \
						or far.native_doorway_site(WorldGen.OPP[dir]).is_empty() \
						or near.doorway_clearance_violations() != 0 \
						or far.doorway_clearance_violations() != 0:
					near.free()
					far.free()
					continue
				near.position = Vector3(cell.x * 12.0, 0.0, cell.y * 12.0)
				far.position = Vector3(other.x * 12.0, 0.0, other.y * 12.0)
				manager.add_child(near)
				manager.add_child(far)
				manager.chunks[cell] = near
				manager.chunks[other] = far
				selected = true
				break
	expect(selected, "no prepared solid Office wall passed clearance")
	if selected:
		var site: Dictionary = manager.chunks[cell].native_doorway_site(dir)
		var centre: Vector3 = director._site_centre(cell, dir,
			float(site["t"]), float(site["floor"]))
		print("Generated Office doorway: cell ", cell, " dir ", dir,
			" width ", site["w"], " along ", site["t"], " centre ", centre)
		actor.global_position = centre - WorldGen.DIRV[dir].x * Vector3.RIGHT * 6.0 \
			- WorldGen.DIRV[dir].y * Vector3.BACK * 6.0
		actor.cam.global_position = actor.global_position + Vector3.UP * Player.CAM_H
		actor.cam.look_at(centre + Vector3.UP * 1.2)
		actor.cam.make_current()
		await physics_frame
		expect(_threshold_hit(world, centre, dir), "hidden endpoint is not a solid wall")
		expect(bool(topology.edge_info(cell, dir)["wall"]),
			"hidden endpoint leaked into route topology")
		expect(director._eligible(cell, dir),
			"unobstructed prepared wall was not visible")
		var blocker := StaticBody3D.new()
		var blocker_shape := CollisionShape3D.new()
		var blocker_box := BoxShape3D.new()
		blocker_box.size = Vector3(0.5, 2.0, 2.5) if dir == 0 else \
			Vector3(2.5, 2.0, 0.5)
		blocker_shape.shape = blocker_box
		blocker.add_child(blocker_shape)
		var normal := Vector3(float(WorldGen.DIRV[dir].x), 0.0,
			float(WorldGen.DIRV[dir].y))
		blocker.position = centre - normal * 3.0 + Vector3.UP * 1.2
		world.add_child(blocker)
		await physics_frame
		expect(not director._eligible(cell, dir),
			"prepared wall could trigger while hidden behind another object")
		blocker.free()
		await physics_frame
		expect(director._eligible(cell, dir),
			"prepared wall stayed blocked after occluder removal")
		director._physics_process(director.cooldown + 0.1)
		expect(is_instance_valid(director.active) and director.events_started == 1,
			"prepared gameplay doorway did not start automatically after its cooldown")
		if is_instance_valid(director.active):
			var surface: Node3D = director.active
			director._process(Director.MOVE_SECONDS * 0.5)
			director._physics_process(0.0)
			expect(surface.phase > 0.0 and surface.phase < 1.0 \
					and surface._collision_phase == surface.phase,
				"moving wall and collider diverged")
			director._process(Director.MOVE_SECONDS * 0.6)
			director._physics_process(0.0)
			await physics_frame
			await physics_frame
			expect(surface.phase == 1.0 and not _threshold_hit(world, centre, dir),
				"appeared doorway remained blocked")
			expect(not bool(topology.edge_info(cell, dir)["wall"]),
				"visible opening did not update route topology")
			var safe_edge_offset := Vector3(2.0, 0.0,
				float(site["w"]) * 0.5 + 1.2) if dir == 0 else \
				Vector3(float(site["w"]) * 0.5 + 1.2, 0.0, 2.0)
			actor.global_position = centre + safe_edge_offset
			expect(not director._can_close(),
				"doorway could close beside a player near the opening edge")
			actor.global_position = centre - WorldGen.DIRV[dir].x * Vector3.RIGHT * 6.0 \
				- WorldGen.DIRV[dir].y * Vector3.BACK * 6.0
			director._process(Director.OPEN_SECONDS + 0.1)
			director._process(Director.MOVE_SECONDS + 0.1)
			director._physics_process(0.0)
			await physics_frame
			await physics_frame
			expect(director.active == null and _threshold_hit(world, centre, dir),
				"disappeared doorway left a walkable hole")
			expect(director.cooldown >= Director.REPEAT_COOLDOWN.x \
				and director.cooldown <= Director.REPEAT_COOLDOWN.y,
				"repeat doorway attempt is outside the rare pacing window")
			expect(bool(topology.edge_info(cell, dir)["wall"]),
				"closed doorway remained open in route topology")
			expect(site["closed_nodes"][0].visible and not site["nodes"][0].visible,
				"cleanup did not restore the native full wall")
			director._physics_process(director.cooldown + 0.1)
			expect(not is_instance_valid(director.active),
				"automatic pacing reused the same doorway site")
			# Saved floor state is restored before streaming builds a chunk.
			manager.set_native_doorway_open(cell, dir, true)
			var saved := manager.runtime_state_snapshot()
			manager.native_doorway_plan.set_open(cell, dir, false)
			manager.restore_runtime_state(saved)
			expect(manager.native_doorway_plan.is_open(cell, dir) \
				and not bool(topology.edge_info(cell, dir)["wall"]),
				"saved opening did not restore route state")
			var rebuilt := Chunk.new(ws, cell, 1, {"descent": true,
				"topology": topology, "native_doorway_plan": manager.native_doorway_plan})
			var rebuilt_site := rebuilt.native_doorway_site(dir)
			expect(not rebuilt_site.is_empty() \
				and rebuilt_site["nodes"][0].visible \
				and not rebuilt_site["closed_nodes"][0].visible,
				"streamed rebuild lost the opened endpoint")
			rebuilt.free()
			manager.set_native_doorway_open(cell, dir, false)
			director._used.clear()
			expect(director.start_event(cell, dir), "doorway did not restart after restoration")
			manager.chunks.erase(cell)
			director._physics_process(0.0)
			expect(not is_instance_valid(director.active), "unload retained doorway effect")
			expect(not director._used.has(NativeDoorwayPlan.edge_key(cell, dir)),
				"interrupted unopened doorway consumed its only prepared site")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	stop_audio(world)
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("native Office latent doorway: hidden wall, opening, route, closure")


func _threshold_hit(world: Node3D, centre: Vector3, dir: int) -> bool:
	var offset := Vector3.RIGHT * 0.5 if dir == 0 else Vector3.BACK * 0.5
	var ray := PhysicsRayQueryParameters3D.create(
		centre + Vector3.UP * 1.2 - offset,
		centre + Vector3.UP * 1.2 + offset)
	return not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
