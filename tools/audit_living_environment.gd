extends "res://tools/lib/audit_base.gd"
## One real Office route and collision world. Checks the same-room return
## against safe passage and unchanged route topology.

const ReturnDoor := preload("res://scripts/self_return_door_director.gd")


func run() -> void:
	var world_seed := WorldGen.level_seed(20260807, 1)
	var route := DescentRoute.build(world_seed, 1, 2)
	var topology := DescentTopology.new(world_seed, 1)
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
	manager.theme = 1
	manager.descent = true
	manager.descent_floor_idx = 2
	manager.descent_route = route
	manager.descent_topology = topology
	manager.native_doorway_plan = NativeDoorwayPlan.new()
	manager.native_doorway_plan.configure(world_seed, 1, topology)
	manager.player = actor
	holder.add_child(manager)
	manager.set_process(false)
	var door := ReturnDoor.new()
	holder.add_child(door)
	door.preview = true
	door.configure(manager, actor, func() -> bool: return true,
		func() -> void: pass, route)
	door.set_physics_process(false)
	var staged := false
	for room in route.path_from_origin():
		if room == route.origin or room == route.target \
				or route.is_intro_door_room(room) \
				or WorldGen.cell_style(world_seed, room, 1) \
				== WorldGen.OFFICE_CORRIDOR:
			continue
		var chunk := manager.chunk_at(room)
		if chunk == null: chunk = manager._build(room)
		actor.teleport(chunk.to_global(Vector3(6,
			chunk._floor_h() + 0.15, 6)))
		await physics_frame
		if door._try_stage():
			staged = true
			break
	expect(staged, "no safe same-room glowing door could be staged")
	if staged:
		# The preview fixture uses the same real door. Attach the production
		# scheduler here to verify that a first view spends its shared quota.
		var pacing := HorrorDirector.new()
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
		var scheduler := ArchitecturalEventDirector.new()
		holder.add_child(scheduler)
		scheduler.configure(manager, actor, breath, openings, door, pacing,
			func() -> bool: return true)
		scheduler.set_physics_process(false)
		var toward: Vector3 = door.site.global_position - actor.global_position
		toward.y = 0.0
		expect((-actor.global_basis.z).dot(toward.normalized()) > 0.95,
			"return-door preview did not face the staged door")
		expect((actor.cam.cull_mask & SelfReturnDoorSite.PORTAL_LAYER) != 0,
			"return doorway is on a layer hidden from the player camera")
		expect(door.site._frame.visible and door.site._fallback.visible,
			"return doorway has no visible surface before its live view is ready")
		expect(door.site._preview.find_world_3d() == actor.get_world_3d(),
			"return doorway is not previewing the original room world")
		expect(door.site._window_material.shader == RealmExcursion.WINDOW_SHADER \
			and door.site._leak._material.shader == RealmDoorLeak.SHADER,
			"return doorway does not use the temporary realm door visuals")
		expect(door.site._leak._material.get_shader_parameter("opening_size")
			== Vector2(SelfReturnDoorSite.WIDTH, SelfReturnDoorSite.HEIGHT),
			"return doorway has no glow surrounding its opening")
		expect((door.site._leak._patch.mesh as QuadMesh).size
			== Vector2(SelfReturnDoorSite.WIDTH + 0.5, SelfReturnDoorSite.HEIGHT + 0.5)
			and door.site._window_material.get_shader_parameter("impossible_return") == 1.0,
			"return doorway lost its narrow rim or refracted same-room view")
		door.site._has_frame = true
		actor.cam.rotation.y = actor.rotation.y
		door.site._process(0.016)
		door.preview = false
		door._physics_process(0.016)
		expect(scheduler.events_started == 1
			and int(scheduler.counts.get("return", 0)) == 1,
			"first view of return door did not enter shared architecture cadence")
		expect(float(pacing.snapshot()["visual"]) > 7.0,
			"first view of return door did not renew its quiet window")
		expect(door.site._leak.visible and door.site._leak._light.light_energy > 0.2,
			"return doorway loses its blue glow when the live view appears")
		var door_forward: Vector3 = -door.site.global_basis.z.normalized()
		var door_right: Vector3 = door_forward.cross(Vector3.UP)
		expect((-door.site._preview_camera.global_basis.z).dot(
				door_forward) > 0.98
			and door.site._preview_camera.global_basis.x.dot(door_right) > 0.98
			and door.site.global_basis.x.dot(door_right) > 0.98,
			"return doorway mirrors the room in its live view")
		expect(is_instance_valid(door._landmark)
			and door._landmark.get_parent() == manager.chunk_at(door.site_cell)
			and door._landmark.find_child("Overturned office chair", true, false) != null
			and door._landmark.find_child("Flickering ceiling lamp", true, false) != null,
			"same-room chair and lamp were not present before crossing")
		var door_chunk := manager.chunk_at(door.site_cell)
		var wall_body := door_chunk.body
		var state_id := topology.current_state_id()
		var site_cell := door.site_cell
		var inward: Vector3 = door.site.global_basis.z.normalized()
		var return_basis: Basis = door._record["return_basis"]
		expect(return_basis.z.dot(-inward) > 0.98,
			"return landing does not preserve room handedness")
		actor.teleport(door.site.to_global(Vector3(0, 0.15, 0.64)))
		actor.rotation.y = atan2(inward.x, inward.z)
		for frame in 60:
			door._physics_process(1.0 / 60.0)
		expect(float(pacing.snapshot()["visual"]) > 0.0
			and not pacing.can_start_hostile()
			and not pacing.try_start_visual(1.0),
			"return crossing did not reserve the director for its sound reveal")
		expect(door.site.openness > 0.96,
			"return doorway did not reveal the live room view on approach")
		actor.dev_walk = true
		door._physics_process(0.016)
		await physics_frame
		expect(door.used and not is_instance_valid(door.site),
			"return crossing left its door visible")
		expect(is_instance_valid(door._afterimage) \
			and door._reveal_stage == ReturnDoor.RevealStage.RECOGNIZE,
			"return crossing gave no visible cue on the original wall")
		expect(door._door_audio.volume_db >= -5.0
			and door._door_audio.unit_size >= 8.0,
			"latch and knocks are still too quiet at the return point")
		expect(is_instance_valid(door._landmark)
			and door._landmark.get_parent() == door_chunk,
			"the chair and lamp changed or vanished on crossing")
		expect((-actor.global_basis.z).dot(-inward) > 0.98,
			"crossing turned the player into a mirrored view of the room")
		var former_wall: Vector3 = door._former_door.origin - actor.global_position
		former_wall.y = 0.0
		expect((-actor.global_basis.z).dot(former_wall.normalized()) < -0.9,
			"vanished doorway is not behind the player")
		if not GameSettings.flashing_reduced():
			var lamp := door._landmark.find_child("Uneven fluorescent light",
				true, false) as OmniLight3D
			door._landmark._process(0.42)
			expect(lamp != null and lamp.light_energy < 0.3,
				"the landmark lamp did not flicker during recognition")
		door._physics_process(0.01)
		expect(not door._trace_fade_started,
			"stale camera rotation erased the trace before the player looked back")
		actor.cam.rotation.y = actor.rotation.y
		var chair_eye: Vector3 = door._landmark.global_position + Vector3.UP * 0.5
		var lamp_eye: Vector3 = door._landmark.find_child(
			"Flickering ceiling lamp", true, false).global_position
		expect(actor.cam.is_position_in_frustum(chair_eye)
			and actor.cam.is_position_in_frustum(lamp_eye),
			"chair and lamp are not both in the forward view after crossing")
		expect(manager.chunk_at(site_cell) == door_chunk \
			and door_chunk.body == wall_body \
			and topology.current_state_id() == state_id,
			"return crossing changed the room instance, original wall or topology")
		expect(ReturnDoor._cell_of(actor.global_position) == site_cell \
			and ArrivalSafety.is_clear(actor.get_world_3d(),
			actor.global_position, [actor.get_rid()]),
			"return crossing did not land safely in the same room")
		expect(bool(manager._runtime_state.payload_for(ReturnDoor.STATE_KEY).get(
			"used", false)), "return-door consumption was not saved")
		# An unusually early turn must still dissolve the trace on first view,
		# without stealing the separate fourth knock from the later sound beat.
		var wall: Vector3 = door._former_door.origin + Vector3.UP * 1.35
		var back: Vector3 = wall - actor.global_position
		actor.rotation.y = atan2(-back.x, -back.z)
		actor.cam.rotation.y = actor.rotation.y  # Top-level camera; render process is disabled here.
		door._physics_process(ReturnDoor.TRACE_FADE_SECONDS * 0.5)
		var echo_strength: float = door._afterimage._material.get_shader_parameter(
			"strength")
		expect(door._trace_fade_started and echo_strength < 0.06 \
			and echo_strength > 0.04 \
			and door._reveal_stage == ReturnDoor.RevealStage.RECOGNIZE,
			"first look did not start the one-second trace fade")
		door._physics_process(ReturnDoor.TRACE_FADE_SECONDS * 0.5 + 0.02)
		await physics_frame
		expect(not is_instance_valid(door._afterimage)
			and door._reveal_stage == ReturnDoor.RevealStage.RECOGNIZE,
			"the wall trace did not finish fading on an early look")
		actor.rotation.y = atan2(inward.x, inward.z)
		actor.cam.rotation.y = actor.rotation.y
		door._physics_process(ReturnDoor.RECOGNITION_SECONDS + 0.02)
		expect(door._reveal_stage == ReturnDoor.RevealStage.LATCH
			and door._door_audio.stream == ReturnDoor.LATCH,
			"latch played before room recognition or used the wrong sound")
		door._physics_process(ReturnDoor.LATCH.get_length() + ReturnDoor.SOUND_GAP + 0.02)
		expect(door._reveal_stage == ReturnDoor.RevealStage.TWO_KNOCKS
			and door._door_audio.stream == ReturnDoor.TWO_KNOCKS,
			"the pair of knocks did not follow the latch")
		door._physics_process(ReturnDoor.TWO_KNOCKS.get_length() + ReturnDoor.SOUND_GAP + 0.02)
		expect(door._reveal_stage == ReturnDoor.RevealStage.THIRD_KNOCK
			and door._door_audio.stream == ReturnDoor.ONE_KNOCK,
			"the third knock did not follow the pair")
		door._physics_process(ReturnDoor.ONE_KNOCK.get_length() + 0.02)
		expect(door._reveal_stage == ReturnDoor.RevealStage.WAIT_FOR_LOOK,
			"final knock was not held for the look back")
		door._physics_process(4.0)
		expect(door._reveal_stage == ReturnDoor.RevealStage.WAIT_FOR_LOOK,
			"final knock advanced without a look back")
		actor.rotation.y = atan2(-back.x, -back.z)
		actor.cam.rotation.y = actor.rotation.y
		await physics_frame
		door._physics_process(0.01)
		expect(door._reveal_stage == ReturnDoor.RevealStage.DONE
			and door._door_audio.stream == ReturnDoor.ONE_KNOCK,
			"the look back did not trigger the final knock")
	var roundtrip := ChunkRuntimeState.from_dictionary(
		manager.runtime_state_snapshot().to_dictionary())
	expect(bool(roundtrip.payload_for(ReturnDoor.STATE_KEY).get("used", false)),
		"return-door consumption did not survive runtime-state serialization")
	var save_path := "/tmp/liminal-living-audit-%d.cfg" % OS.get_process_id()
	var checkpoint := DescentProgress.new(save_path)
	checkpoint.start_new(20260807)
	expect(checkpoint.record_runtime_state(2,
		manager.runtime_state_snapshot()) == OK,
		"Office one-shot state did not reach the checkpoint")
	var reloaded := DescentProgress.new(save_path)
	var resumed := reloaded.runtime_state_for_floor(2)
	expect(bool(resumed.payload_for(ReturnDoor.STATE_KEY).get("used", false)),
		"Continue did not reload the consumed return door")
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".bak")
	await teardown_game(holder)
	finish("living environment: same-room return")
