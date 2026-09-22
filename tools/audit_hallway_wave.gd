extends "res://tools/lib/audit_base.gd"
## Focused runtime gate: --headless --script tools/audit_hallway_wave.gd -- --nologo --level=1
const Layout := preload("res://scripts/hallway_wave_placement.gd")
const Profile := preload("res://scripts/hallway_wave_profile.gd")
const Surface := preload("res://scripts/hallway_wave_surface.gd")

func run() -> void:
	for phase in [0.1, 0.4, 0.5, 0.7, 0.9]:
		for across in [-6.1, -6.0, 6.0, 6.1]:
			for along in [-6.0, -3.0, 0.0, 3.0, 6.0]:
				for y in [0.0, 1.5, 3.2]:
					var p := Vector3(across,y,along)
					expect(Profile.posed(p,phase,11.85,3.2).is_equal_approx(p), "shared side boundary moved")
		for x in [-5.0, 0.0, 5.0]:
			for z in [-6.0, 6.0]:
				var p := Vector3(x,0,z)
				expect(Profile.posed(p,phase,11.85,3.2).is_equal_approx(p), "shared end boundary moved")
	var game := await boot_game(980712989)
	if "--capture-live-wave" in OS.get_cmdline_user_args():
		# Background GPU capture is not an interactive play session. Keep the
		# game's normal focus-loss pause policy intact outside this harness.
		var resume_capture := func():
			if paused and is_instance_valid(game._pause_menu): game._close_settings()
		process_frame.connect(resume_capture)
		await capture_live_wave(game)
		process_frame.disconnect(resume_capture)
		await teardown_game(game)
		finish("live runtime wave capture")
		return
	var director: Node = game._breathing
	director.set_physics_process(false)
	game.cm.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._director.enabled = false
	if game.opts.hallway_wave:
		expect(director._wave_preview_mode and is_inf(director.cooldown), "manual wave mode did not wait for input")
		director._physics_process(60.0)
		expect(director.active == null and director._debug_kind.is_empty(), "manual wave fired before F6")
	var layout := Layout.find(game.cm.world_seed, 1)
	if layout.is_empty():
		fail("Office sample missing")
		await teardown_game(game)
		finish()
		return
	var cell: Vector2i = layout.cell
	game.cm.warm_up(cell)
	var chunk: Chunk = game.cm.chunks[cell]
	layout = Layout.eligible(chunk)
	if layout.is_empty():
		fail("streamed Office sample ineligible")
		await teardown_game(game)
		finish()
		return
	var frame := Transform3D(Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT) if int(layout.axis) == 1 else Basis.IDENTITY, Vector3(6,chunk._floor_h(),6))
	game.player.global_position = chunk.to_global(frame*Vector3(0,0.05,3))
	game.player.basis = frame.basis
	game.player.cam.global_position = game.player.global_position+Vector3.UP*1.4
	game.player.cam.look_at(chunk.to_global(frame*Vector3(0,1.4,0)))
	print("Runtime wave spawn: ", game.player.global_position, "; yaw=", rad_to_deg(game.player.rotation.y))
	# Read-only neighbor snapshot: event ownership must remain in one chunk.
	var neighbor: Chunk = game.cm.chunks[cell+Vector2i.RIGHT]
	var meshes := {}
	for node: MeshInstance3D in neighbor.find_children("*","MeshInstance3D",true,false): meshes[node] = node.mesh
	# Start through the same automatic selection path used by quiet gameplay.
	if game.opts.hallway_wave:
		director._debug_index = 2 # Would be ceiling in the normal cycling mode.
		var key := InputEventKey.new()
		key.keycode = KEY_F6
		key.pressed = true
		root.push_input(key)
		expect(director._debug_kind == "wave", "F6 did not directly request a wave")
	else:
		director._debug_kind = "wave"
		director.cooldown = 0.0
	for scan in 6:
		director._physics_process(0.1)
		if is_instance_valid(director.active): break
	expect(is_instance_valid(director.active) and director.kind == "wave", "wave search failed")
	if not is_instance_valid(director.active):
		await teardown_game(game)
		finish()
		return
	var surface: Node = director.active
	for step in 2000:
		if director.active == null or surface.prepared: break
		director._physics_process(1.0/60)
		if is_instance_valid(surface) and surface.failed: print("Wave refusal: ", surface.failure)
		await process_frame
	expect(is_instance_valid(director.active) and surface.prepared, "incremental setup failed")
	if director.active == null:
		await teardown_game(game)
		finish()
		return
	print("Wave preparation max slice ms: ", director.max_prepare_step_ms)
	if game.opts.hallway_wave:
		game._director.enabled = true
		game._director._recovery_left = 1.0
		director._physics_process(1.0/60)
		expect(director.active == surface and not director._wave_started and director._wave_wait > 0.0, "manual wave discarded instead of waiting for pacing")
		game._director.enabled = false
	var max_floor_error := 0.0
	var max_tick_ms := 0.0
	game.player.set_physics_process(true)
	for settle in 12: await physics_frame
	var initial: Vector3 = game.player.global_position
	for tick in 240:
		game.player.dev_walk = tick > 60 and tick < 120
		var begin := Time.get_ticks_usec()
		director._physics_process(1.0/60)
		max_tick_ms = maxf(max_tick_ms, (Time.get_ticks_usec()-begin)/1000.0)
		await physics_frame
		if tick == 100:
			expect(director._effect_in_view(), "visible wave audio gate stayed closed")
			var facing: Basis = game.player.cam.global_basis
			game.player.cam.global_basis = facing.rotated(Vector3.UP, PI)
			expect(not director._effect_in_view(), "wave behind camera remained audible")
			game.player.cam.global_basis = facing
		var local: Vector3 = frame.affine_inverse()*chunk.to_local(game.player.global_position)
		var expected := Profile.posed(Vector3(local.x,0,local.z), director.elapsed/Profile.DURATION,layout.width,layout.height).y
		max_floor_error = maxf(max_floor_error,absf(local.y-expected))
	expect(director.active == surface, "walkable wave cancelled while walking its center")
	expect(max_floor_error < 0.12, "feet separated from moving floor")
	expect(game.player.global_position.distance_to(initial) > 0.75, "player could not walk through wave")
	game.player.dev_walk = false
	game.player.set_physics_process(false)
	print("Wave max tick ms: ",max_tick_ms,"; feet error: ",max_floor_error)
	for node in meshes: expect(node.mesh == meshes[node], "neighbor geometry changed")
	# Audio contract: every supplied loop loads, no immediate repeats, smooth
	# visibility release, then silence. No listening-quality claim from this.
	var audio: Node = director._audio
	audio.set_process(false)
	expect(audio._streams.size() == 6, "not all supernatural tracks loaded")
	for stream in audio._streams: expect(stream.loop and stream.get_length() > 0, "invalid loop")
	audio.begin_event()
	var previous: int = audio.track_index
	audio.begin_event()
	expect(audio.track_index != previous, "consecutive audio repeat")
	audio.set_in_view(true)
	audio.advance(0.4)
	expect(audio.gain > 0.0 and audio.gain < 1.0, "audio attack jumped")
	audio.set_in_view(false)
	audio.advance(0.1)
	expect(audio.gain > 0.0, "audio release cut abruptly")
	audio.advance(2.0)
	expect(audio.gain == 0.0 and not audio.voice.playing, "offscreen loop did not stop")
	# Cancellation returns walls outward/ceiling upward/floor downward. Keep
	# monsters untouched: a synthetic group marker exercises the gate only.
	var hostile := Node3D.new()
	root.add_child(hostile)
	hostile.add_to_group("hostile_shadow_figure")
	hostile.global_position = chunk.to_global(Vector3(6,0,6))
	director._physics_process(1.0/60)
	expect(director.active == null and surface.originals_restored(), "hostile did not restore wave")
	hostile.queue_free()
	await process_frame
	# Teardown while suspended mid-preparation must not resume freed objects.
	expect(director.start_event(chunk,layout,"wave"), "restart failed")
	director._physics_process(1.0/60)
	game.cm.chunks.erase(cell)
	chunk.queue_free()
	await process_frame
	director._physics_process(1.0/60)
	expect(director.active == null, "unload retained preparation")
	await process_frame
	await teardown_game(game)
	finish("hallway wave: streamed Office, boundaries, walking, audio, cancellation and unload")

func capture_live_wave(game: Node) -> void:
	# Automated render capture must not consume the user's keyboard input.
	root.set_disable_input(true)
	var level_review := "--review-level-wave" in OS.get_cmdline_user_args()
	if level_review and not prepare_level_view(game): return
	await create_timer(2.0).timeout
	var director: Node = game._breathing
	if not await await_until(game._breathing_allowed, 20000):
		fail("live gameplay did not permit architecture")
		return
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	key.pressed = true
	director._unhandled_input(key)
	if not await await_until(func(): return director._wave_started, 60000):
		var cell := Vector2i(floori(game.player.global_position.x/12.0), floori(game.player.global_position.z/12.0))
		var chunk: Chunk = game.cm.chunks.get(cell)
		print("Capture start refusal: allowed=",game._breathing_allowed()," paused=",paused," cooldown=",director.cooldown," requested=",director._debug_kind," cell=",cell," hostiles=",game._director._hostile_count," eligible=",Layout.eligible(chunk) if is_instance_valid(chunk) else {})
		fail("live wave did not start")
		return
	print("Wave preparation: seconds=", director._prepare_elapsed, " cpu_ms=", director.last_setup_ms, " max_slice_ms=", director.max_prepare_step_ms)
	var presentation_seen := false
	for at in [0.05, 3.5, 5.0]:
		if not await await_until(func(): return director.elapsed >= at or director.active == null, 10000):
			fail("live wave stalled")
			return
		if not is_instance_valid(director.active):
			fail("live wave cancelled before capture")
			return
		await RenderingServer.frame_post_draw
		var path := "/tmp/liminal-live-wave-%.2f.png" % at
		if level_review:
			DirAccess.make_dir_recursive_absolute("/tmp/liminal-wave-level-review")
			path = "/tmp/liminal-wave-level-review/theme-%d-%.2f.png" % [game.active_level, at]
		root.get_texture().get_image().save_png(path)
		print("Live capture: ", path, " elapsed=",director.elapsed," player=",game.player.global_position," camera=",game.player.cam.global_position," facing=",-game.player.cam.global_basis.z)
		if level_review:
			var blur := float(game._reality_aftershock._material.get_shader_parameter("strength"))
			print("Presentation: weight=", director.perception_weight(), " blur=", blur, " audio=", director._audio.voice.playing, " track=", director._audio.track_index)
			presentation_seen = presentation_seen or (director.perception_weight() > 0.0 and director._audio.voice.playing and blur > 0.0)
	if level_review:
		# Wide-room occlusion can reveal the wave later: check the observed
		# sequence, not an arbitrary >50% fade threshold at exactly 3.5 seconds.
		expect(presentation_seen, "visible wave presentation did not engage")

func prepare_level_view(game: Node) -> bool:
	# Keep the real renderer, streaming, event, audio and collision paths. Only
	# hold the viewpoint and unrelated pacing still for comparable screenshots.
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.cm.set_process(false)
	game._director.enabled = false
	var excluded: Array[Vector2i] = []
	for attempt in 16:
		var layout := Layout.find(game.cm.world_seed, game.active_level, 0, excluded)
		if layout.is_empty(): break
		var cell: Vector2i = layout.cell
		var resident: bool = game.cm.chunks.has(cell)
		# Reject unsupported candidates before entering the render world and
		# creating their interactive models/material overrides in _ready.
		var chunk: Chunk = game.cm.chunks[cell] if resident else game.cm._build(cell, false)
		if not is_instance_valid(chunk) or Layout.eligible(chunk).is_empty():
			if not resident and is_instance_valid(chunk): chunk.free()
			excluded.append(cell)
			continue
		if not resident: game.cm._install_chunk(cell, chunk)
		var basis := Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT) if int(layout.axis) == 1 else Basis.IDENTITY
		var frame := Transform3D(basis, Vector3(6, chunk._floor_h(), 6))
		var across := -float(layout.width)/2+1.2 if float(layout.width) > 6.0 else 0.0
		game.player.teleport(chunk.to_global(frame*Vector3(across,0.05,4.6)))
		# Main initially pins streaming to its spawn until the player arrives.
		# This review teleports elsewhere, so release that old focus as well.
		game.cm.stream_focus = Vector3.INF
		game.player.basis = basis
		game.player.cam.global_position = game.player.global_position+Vector3.UP*1.4
		game.player.cam.look_at(chunk.to_global(frame*Vector3(0,1.5,-2)))
		game.cm.warm_up(cell)
		game.cm.set_process(true)
		print("Review theme=",game.active_level," cell=",cell," axis=",layout.axis," width=",layout.width," height=",layout.height)
		return true
	fail("no eligible streamed room found for level review")
	return false
