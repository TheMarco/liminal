extends SceneTree
## Production Startup/input/pause contract. Native renderer required.
## godot --path . --script tools/audit_ntscrt_video_host.gd --quit-after 900 -- --nologo --level=1
class TickProbe extends Node:
	var physics_ticks = 0
	var draw_ticks = 0
	var torch_events = 0
	var motion_events = 0
	func _physics_process(_dt: float) -> void: physics_ticks += 1
	func _process(_dt: float) -> void: draw_ticks += 1
	func _unhandled_input(event: InputEvent) -> void:
		if GameInput.matches(event,"torch"): torch_events += 1
		if event is InputEventMouseMotion and event.relative==Vector2(20,10): motion_events += 1
var failures: Array[String] = []
var game: Node
var host: Control
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print("HOST_CHECK ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await process_frame
func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = true
	Input.parse_input_event(event)
	var release = InputEventKey.new()
	release.physical_keycode = code; release.keycode = code
	Input.parse_input_event(release)
func clear_focus_pause() -> void:
	if is_instance_valid(game._pause_menu):
		print("HOST_HARNESS closing focus-loss pause before scenario")
		game._close_settings()
	root.grab_focus()
func _run() -> void:
	if DisplayServer.get_name()=="headless": push_error("Native renderer required"); quit(1); return
	change_scene_to_file("res://scenes/startup.tscn")
	for i in 180:
		await process_frame
		if get_first_node_in_group("level_manager")!=null: break
	game = get_first_node_in_group("level_manager")
	if game==null or not game.has_meta("ntscrt_video_host"):
		check(false,"production Startup created VideoHost"); quit(1); return
	# Main startup has completed. Redirect all menu saves before input tests.
	game._settings._path = "/tmp/liminal-video-host-audit-settings.cfg"
	game._settings.values = GameSettings.DEFAULTS.duplicate(true)
	game._settings.values.fullscreen = false
	game._settings.values.hdr_enabled = false
	game._settings.changed.emit()
	host = game.get_meta("ntscrt_video_host")
	check(not game._progress_enabled and not game.descent,"CLI startup cannot write campaign progress")
	check(game.is_in_group("level_manager"),"production level_manager available through canonical group")
	check(current_scene==host and current_scene.get_parent()==root,"current_scene is the production root VideoHost")
	check(game.get_parent()==host.source,"Startup attaches main to stable source viewport")
	check(host.source.own_world_3d and game.player.get_world_3d()==host.source.find_world_3d(),"source owns player world")
	check(host.source.get_camera_3d()==game.player.cam,"source owns current gameplay camera")
	check(game.process_mode==Node.PROCESS_MODE_PAUSABLE,"always-running host preserves game pause inheritance")
	var simulation = TickProbe.new()
	game.player.add_child(simulation)
	var presentation = TickProbe.new()
	presentation.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(presentation)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,600)
	await frames(12)
	clear_focus_pause()
	game.player.grab_look()
	await create_timer(0.22).timeout
	clear_focus_pause()
	var before_torch = game.player.flashlight.visible
	var before_events = simulation.torch_events
	key(GameInput.primaries(game._settings).torch)
	await frames(2)
	check(game.player.flashlight.visible!=before_torch,"root torch press toggles flashlight once")
	check(simulation.torch_events-before_events==1,"root torch press delivered exactly once to game viewport")
	var yaw = game.player.rotation.y
	var pitch = game.player._pitch
	var before_motion = simulation.motion_events
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(root.size)/2
	motion.relative = Vector2(20,10)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	await frames(2)
	var sensitivity = game.player.SENS*game.player.sensitivity_multiplier
	check(absf(angle_difference(yaw,game.player.rotation.y)+20*sensitivity)<0.00001,"root mouse yaw applied exactly once")
	check(absf(game.player._pitch-pitch+10*sensitivity)<0.00001,"root mouse pitch applied exactly once")
	check(simulation.motion_events-before_motion==1,"root mouse motion delivered exactly once")
	key(KEY_ESCAPE)
	await frames(2)
	check(paused and is_instance_valid(game._pause_menu),"root Escape opens production pause menu")
	if is_instance_valid(game._pause_menu):
		check(game._pause_menu.custom_viewport==root,"pause canvas targets root viewport")
		check(game._pause_menu._overlay.is_visible_in_tree() and game._pause_menu._resume_button.is_visible_in_tree(),"pause overlay and Resume remain accessible")
	var physics_before = simulation.physics_ticks
	var display_before = presentation.draw_ticks
	var position_before = game.player.global_position
	await frames(8)
	check(simulation.physics_ticks==physics_before and game.player.global_position==position_before,"pause freezes player physics")
	check(presentation.draw_ticks>display_before,"presentation continues while game paused")
	key(KEY_ESCAPE)
	await frames(3)
	check(not paused and not is_instance_valid(game._pause_menu),"root Escape closes production pause menu")
	var old_size = host.source.size
	root.size = Vector2i(1120,720)
	await frames(10)
	check(host.source.size!=old_size and Vector2(host.source.size).is_equal_approx(root.get_visible_rect().size),"root resize updates source viewport extent")
	check(absf(host.source.scaling_3d_scale*host.source.size.y-480)<1.0,"resize preserves 480-line camera rendering scale")
	clear_focus_pause()
	var original_parent = game.get_parent()
	var original_scene = current_scene
	# Isolate the CRT switch: full ntsc-rs independently needs the GPU presenter.
	game._settings.set_value("video_pipeline",0)
	for model in [1,7,0]:
		game._settings.set_value("crt_shader",model)
		await frames(8)
		check(game.get_parent()==original_parent and current_scene==original_scene,"CRT %d switch preserves scene ownership"%model)
		check(game._post_process._tube_display.visible==(model==0),"CRT %d gates original tube pass"%model)
		if model>0:
			check(is_instance_valid(host.presenter) and host.presenter.visible,"CRT %d activates root presenter"%model)
			if is_instance_valid(host.presenter):
				check(host.presenter.last_error.is_empty(),"CRT %d compiles without presenter error: %s"%[model,host.presenter.last_error])
				check(host.presenter.ready_frames>0,"CRT %d has presented rendered GPU frames"%model)
				if model==1:
					clear_focus_pause()
					key(KEY_ESCAPE)
					await frames(2)
					var ready_before = host.presenter.ready_frames
					var ticks_before = simulation.physics_ticks
					await frames(6)
					check(paused and simulation.physics_ticks==ticks_before and host.presenter.ready_frames>ready_before,"original CRT presenter advances while world physics remains paused")
					key(KEY_ESCAPE)
					await frames(2)
		else: check(not host.presenter.visible,"return to model zero restores direct source presentation")
	clear_focus_pause()
	game._settings.set_value("video_pipeline",2)
	game._settings.set_value("crt_shader",GameSettings.CRT_AUTOMATIC)
	game._build_title(true)
	for i in 120:
		await process_frame
		if host._suspended: break
	check(host._suspended and host.source.render_target_update_mode==SubViewport.UPDATE_DISABLED,"opaque title suspends warmed source viewport")
	check(not game.cm.is_processing(),"title stops hidden chunk streaming")
	check(game._title.custom_viewport==root and game._title._primary_button.is_visible_in_tree(),"title remains visible on root canvas")
	var title_frames = host.presenter.ready_frames
	var title_chunks = game.cm.chunks.size()
	await frames(10)
	check(host.presenter.ready_frames==title_frames and game.cm.chunks.size()==title_chunks,"idle title stops GPU effects and streaming")
	game._open_settings(true)
	game._settings.set_value("crt_shader",7)
	await frames(12)
	check(host._suspended,"settings changes warm then resuspend covered video")
	game._close_settings()
	game._title._start(false)
	await frames(12)
	check(not host._suspended and host.source.render_target_update_mode==SubViewport.UPDATE_ALWAYS and game.cm.is_processing(),"starting play resumes rendering and streaming before title fade")
	check(host.presenter.ready_frames>title_frames,"GPU presentation resumes after title")
	# Exercise the reported Wander event with the real renderer and logger.
	clear_focus_pause()
	game._events.set_process(false)
	await game._events._power_sag(0.2,"THE POWER DIPS")
	await create_timer(0.7).timeout
	check(not game._events._busy and host.presenter.last_error.is_empty(),"power dip completes and restores lighting without a video failure")
	for attempt in 2:
		game._events._play_knocks()
		await create_timer(0.8).timeout
		check(game._event_hint.text=="THREE KNOCKS FROM BEHIND THE WALL" and host.presenter.last_error.is_empty(),"knocks event %d presents its caption without a video failure" % (attempt+1))
	# Perception blur is independent of CRT/VHS. Verify the support A/B switch
	# and its diagnostic state against the real presentation path.
	var saved_video: Dictionary = game._settings.values.duplicate(true)
	game._settings.values.vhs_enabled = false
	game._settings.values.crt_enabled = false
	game._settings.values.receiver_enabled = false
	game._settings.changed.emit()
	await frames(3)
	clear_focus_pause()
	var effect = game._reality_aftershock
	var saved_debug: bool = effect.debug_controls
	effect.debug_controls = true
	effect.trigger()
	await create_timer(0.15).timeout
	var context: Dictionary = game._runtime_diagnostic_context()
	check(not context.video.gpu_effects_active and context.perception.active and context.perception.strength > 0.0,
		"diagnostics distinguish active perception blur from disabled CRT/VHS")
	key(KEY_F9)
	await frames(2)
	context = game._runtime_diagnostic_context()
	check(not context.perception.enabled and not context.perception.active and game._event_hint.text=="REALITY AFTERSHOCK: OFF",
		"support A/B key disables perception blur and records its state")
	effect.enabled = true
	effect.debug_controls = saved_debug
	game._settings.values = saved_video
	game._settings.changed.emit()
	# Preparing a new floor under the covered title must not depend on the
	# suspended streamer's _process callback. CLI mode keeps saves isolated.
	game._build_title(true)
	await game._prepare_descent(TitleScreen.DescentEntry.NEW)
	check(game.descent and not game._descent_preparing and game._title._descent_ready and not game.cm.is_processing(),"Descent prepares successfully while title streaming is suspended")
	game._pending_new_descent_intro = false
	game._title._start(true)
	await frames(12)
	check(not host._suspended and game.cm.is_processing(),"Descent resumes rendering and streaming")
	var failures_seen: Array[String] = []
	host.pipeline_failed.connect(func(message: String): failures_seen.append(message))
	var preferences: Dictionary = game._settings.values.duplicate(true)
	RenderingServer.call_on_render_thread(host.presenter._fail_pipeline.bind("audit simulated GPU setup failure"))
	await frames(5)
	var failed_frames = host.presenter.ready_frames
	RenderingServer.call_on_render_thread(host.presenter._fail_pipeline.bind("must not retry"))
	await frames(5)
	check(failures_seen.size()==1 and host.presenter.ready_frames==failed_frames,"GPU failure latches once instead of retrying every frame")
	check(not host.presenter.visible and not game._post_process.is_enabled() and host._container.visible,"GPU failure restores direct unfiltered presentation")
	check(game._settings.values==preferences,"GPU fallback preserves saved preferences")
	paused = false
	# Let the production teardown retire the renderer and stop any title fade
	# still in flight; a direct quit used to leave test-owned resources alive.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player in game.find_children("*", kind, true, false):
			player.stop()
			player.stream = null
	for tween in get_processed_tweens(): tween.kill()
	await process_frame
	host.queue_free()
	await frames(3)
	GameSettings.current = null
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("VIDEO_HOST_AUDIT ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
	# Direct SceneTree quit avoids the gameplay quit/save flow.
	quit(0 if failures.is_empty() else 1)
