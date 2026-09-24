extends "res://tools/lib/audit_base.gd"
## Boots a real streamed level and exercises F6 against an originally solid
## edge. --theme=6 checks School; --capture samples the approved blur.

const Director := preload("res://scripts/native_doorway_director.gd")


func run() -> void:
	var theme := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): theme = int(arg.substr(8))
	var game := await boot_game(20260807)
	# A foreground GUI audit can inherit a pause-menu key event while the
	# window opens. This harness owns its input and needs streaming unpaused.
	_resume_game(game)
	if "--switch-to-school" in OS.get_cmdline_user_args():
		theme = 6
		game._switch_level(theme)
		var switched := await await_until(func() -> bool:
			_resume_game(game)
			return game.active_level == theme and game.cm != null \
				and game.cm.theme == theme and not game._transitions.is_switching(), 15000)
		expect(switched, "Office-to-School transition did not complete")
	var manager: ChunkManager = game.cm
	expect(manager != null and game.active_level == theme and manager.theme == theme,
		"live audit did not boot the requested theme")
	expect(manager != null and manager.native_doorway_plan != null,
		"Main did not install the prepared-doorway plan")
	if manager == null or manager.native_doorway_plan == null:
		await teardown_game(game)
		finish()
		return
	var selected := {}
	for x in range(-18, 19):
		if not selected.is_empty(): break
		for z in range(-18, 19):
			for dir in [0, 2]:
				var cell := Vector2i(x, z)
				var info := manager.native_doorway_plan.candidate(cell, dir)
				if not info.is_empty():
					selected = {"cell": cell, "dir": dir, "info": info}
					break
			if not selected.is_empty(): break
	expect(not selected.is_empty(), "requested theme has no prepared solid edge")
	if not selected.is_empty():
		var cell: Vector2i = selected["cell"]
		var dir: int = selected["dir"]
		var info: Dictionary = selected["info"]
		var other: Vector2i = cell + WorldGen.DIRV[dir]
		var visual: Node = game._native_doorways
		var scheduler: Node = game._architectural_events
		if is_instance_valid(scheduler): scheduler.set_physics_process(false)
		expect(is_instance_valid(visual), "Main did not install doorway director")
		if is_instance_valid(visual):
			expect(visual.pacing == game._director,
				"doorway director did not inherit the current shared pacing authority")
			var centre: Vector3 = visual._site_centre(cell, dir,
				float(info["t"]), Chunk.cell_floor_h(manager.world_seed, cell, theme))
			var normal := Vector3(float(WorldGen.DIRV[dir].x), 0.0,
				float(WorldGen.DIRV[dir].y))
			game.player.teleport(centre - normal * 6.0)
			manager.stream_focus = centre - normal * 6.0
			var ready := await await_until(func() -> bool:
				_resume_game(game)
				var near := manager.chunk_at(cell)
				var far := manager.chunk_at(other)
				return near != null and far != null \
					and not near.native_doorway_site(dir).is_empty(), 20000)
			expect(ready, "live prepared edge did not stream in")
			if not ready:
				print("Doorway stream diagnostic: player=", game.player.global_position,
					" focus=", manager.stream_focus, " chunks=", manager.chunks.size(),
					" near=", manager.chunk_at(cell) != null,
					" far=", manager.chunk_at(other) != null,
					" pending=", manager._pending_cell,
					" paused=", paused, " process=", manager.can_process(),
					" wanted=", manager._wanted.size(),
					" queued=", manager.queued.size())
			if ready:
				visual.set_process(false)
				visual.set_physics_process(false)
				var automatic := "--auto-doorway" in OS.get_cmdline_user_args()
				if not automatic:
					visual.pacing = null
					visual.allowed = func() -> bool: return true
				game.player.set_process(false)
				game.player.set_physics_process(false)
				game.player.cam.global_position = game.player.global_position \
					+ Vector3.UP * Player.CAM_H
				game.player.cam.look_at(centre + Vector3.UP * 1.2)
				game.player.cam.make_current()
				await process_frame
				if "--capture" in OS.get_cmdline_user_args():
					DirAccess.make_dir_recursive_absolute("/tmp/liminal-native-doorway-live")
					await _capture("closed")
				expect(bool(WorldGen.edge_info(manager.world_seed, cell, dir, theme)["wall"]),
					"chosen site was not a base solid wall")
				if automatic:
					var gate_ready := await await_until(func() -> bool:
						_resume_game(game)
						return game._breathing_allowed(), 10000)
					expect(gate_ready,
						"automatic doorway gate never became ready in the live game")
					if gate_ready:
						if is_instance_valid(scheduler):
							scheduler._clock = 150.0
							scheduler._door_ready_at = 0.0
							scheduler.counts = {"breath": 5, "travel": 5,
								"ceiling": 5, "wave": 5}
							scheduler.cooldown = 0.0
							scheduler._physics_process(0.1)
						else:
							visual.cooldown = 0.0
							visual._physics_process(0.1)
						expect(is_instance_valid(visual.active),
							"automatic doorway did not start at a visible prepared wall")
						if is_instance_valid(scheduler):
							expect(scheduler._pending == "doorway" \
								and scheduler.events_started == 0,
								"unopened doorway spent the shared sighting quota")
				elif "--doorway" in OS.get_cmdline_user_args():
					var breathing_notices: Array[String] = []
					game._breathing.debug_notice.connect(func(message: String) -> void:
						breathing_notices.append(message))
					var key := InputEventKey.new()
					key.keycode = KEY_F6
					key.physical_keycode = KEY_F6
					key.pressed = true
					Input.parse_input_event(key)
					await process_frame
					expect(is_instance_valid(visual.active),
						"live F6 did not open a hidden wall")
					expect(breathing_notices.is_empty(),
						"breathing preview also handled doorway F6")
				else:
					expect(visual.start_event(cell, dir),
						"live hidden wall could not start")
				if is_instance_valid(visual.active):
					visual._process(Director.MOVE_SECONDS * 0.5)
					if "--capture" in OS.get_cmdline_user_args(): await _capture("mid")
					visual._process(Director.MOVE_SECONDS * 0.6)
					visual._physics_process(0.0)
					if is_instance_valid(scheduler) \
							and "--auto-doorway" in OS.get_cmdline_user_args():
						scheduler._physics_process(0.1)
						expect(not scheduler.history.is_empty() \
								and scheduler.history.back() == "doorway",
								"shared scheduler did not record the open doorway")
					await physics_frame
					expect(visual.active.phase == 1.0,
						"live hidden wall did not become a doorway")
					expect(manager.native_doorway_plan.is_open(cell, dir),
						"live route remained closed after visible opening")
					if "--capture" in OS.get_cmdline_user_args(): await _capture("open")
					visual._process(Director.OPEN_SECONDS + 0.1)
					visual._process(Director.MOVE_SECONDS + 0.1)
					visual._physics_process(0.0)
					expect(visual.active == null and not manager.native_doorway_plan.is_open(cell, dir),
						"live doorway did not restore its original wall")
				print("Live hidden doorway theme ", theme, " cell ", cell,
					" dir ", dir, " centre ", centre)
	await teardown_game(game)
	finish("live theme %d: streamed solid wall, %s opening and restoration" % [
		theme, "automatic" if "--auto-doorway" in OS.get_cmdline_user_args()
		else "F6"])


func _resume_game(game: Node) -> void:
	# The rendered audit can inherit a late GUI pause-menu event while its
	# window is opening or transitioning. It is not part of this test's input.
	if is_instance_valid(game._pause_menu): game._close_settings()
	paused = false


func _capture(name: String, frames := 4) -> void:
	for frame in frames: await process_frame
	root.get_texture().get_image().save_png(
		"/tmp/liminal-native-doorway-live/%s.png" % name)
