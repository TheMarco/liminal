extends "res://tools/lib/audit_base.gd"
## Native encounter regression and before/warning/appearance review captures.
## godot --path . --script tools/capture_enemy_glitch.gd -- --nologo --level=1
const HOST = preload("res://scripts/ntscrt_video_host.gd")
const OUT := "res://build/ntscrt-review/enemy-glitch/"
var game: Node

func next_frame() -> void:
	# Focus changes open settings automatically during native tool captures.
	if is_instance_valid(game._pause_menu): game._close_settings()
	await process_frame
	if is_instance_valid(game._pause_menu): game._close_settings()
	await RenderingServer.frame_post_draw

func shot(name: String) -> Image:
	var result := root.get_texture().get_image()
	result.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d: result.linear_to_srgb()
	result.save_png(OUT + name + ".png")
	return result

func run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--nologo"):
		fail("Requires native GPU renderer and --nologo")
		finish()
		return
	root.size = Vector2i(1280,720)
	var host := HOST.new()
	root.add_child(host)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	host.attach(game)
	var settings := GameSettings.new("/tmp/liminal-enemy-glitch-%d.cfg" % OS.get_process_id())
	settings.apply_video_look(3)
	settings.set_value("ntsc_auto_faults",false)
	settings.set_value("handheld_camera",false)
	game._settings.changed.disconnect(game._apply_game_settings)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	expect(not game._progress_enabled,"Preview must not save campaign progress")
	Engine.max_fps = 60
	for frame in 60: await next_frame()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game.cm.set_process(false)
	var manager: ShadowFigures = game._figures
	manager.set_physics_process(false)
	manager.suspended = false
	manager.passive = false
	manager._walker_due = false
	manager._dark_bag.assign([0])
	var timeout := Time.get_ticks_msec()+10000
	while not ShadowWalkerVisual.is_model_ready(0) and Time.get_ticks_msec()<timeout:
		await next_frame()
	var ground := Vector3.INF
	for distance in [4.0,6.0,8.0]:
		for angle in [0.0,-0.35,0.35,-0.7,0.7]:
			var candidate := manager._floor_at(game.player.global_position + manager._flat_fwd().rotated(Vector3.UP,angle)*distance)
			if candidate != Vector3.INF and manager._figure_volume_clear(candidate) and manager._spawn_body_visible(candidate):
				ground = candidate
				break
		if ground != Vector3.INF: break
	expect(ground != Vector3.INF,"Fixture needs a visible, collision-safe spawn")
	if ground == Vector3.INF:
		await teardown_game(game)
		finish()
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	await RenderingServer.frame_post_draw
	shot("before")
	expect(manager._spawn_at(ground,false,2.0),"Enemy spawn was rejected")
	if manager.active_figures().is_empty():
		await teardown_game(game)
		finish()
		return
	var figure := manager.active_figures()[0]
	figure.set_physics_process(false)
	var post: PostProcessController = game._post_process
	expect(post._glitch_encounter,"Real spawn did not trigger the recording warning")
	expect(post._glitch_sequence=="glitch_pop","Enemy did not select the original Glitch pop timeline")
	expect(figure._walker._manifestation == 0.0,"Enemy visible before warning")
	expect(not manager._can_add_figure(),"Pending appearance did not reserve encounter occupancy")
	var grace := figure.grace
	figure.suppressed = true
	figure._physics_process(0.6)
	expect(is_equal_approx(figure.appearance_delay,ShadowFigures.APPEARANCE_WARNING_SECONDS),"Passive hold spent appearance delay")
	figure.suppressed = false
	var cue_left := post._encounter_left
	var saved_signal: Dictionary = host._signal_knobs.duplicate(true)
	paused = true
	for frame in 5: await process_frame
	paused = false
	expect(post._encounter_left == cue_left and figure._walker._manifestation == 0.0,"Pause spent the warning")
	for frame in 90:
		figure._physics_process(1.0/60.0)
		post.update()
		await next_frame()
		if frame < 26:
			expect(figure._walker._manifestation == 0.0 and figure.global_position.is_equal_approx(ground),"Enemy visible/moving during warning")
			expect(figure.grace == grace and not figure._seen and figure._burn == 0.0,"Hidden enemy spent grace or reacted to the player")
		if frame == 6:
			expect(float(host.presenter.game_state.get("fault_amount",0.0)) > 0.5,"Warning did not reach live GPU output")
			shot("warning")
			expect(host.presenter.signal_settings != saved_signal,"Original animation tracks did not reach the GPU signal")
		if frame == 70: shot("appeared")
	expect(figure._walker._manifestation > 0.95,"Enemy did not materialize after the warning")
	expect(float(host.presenter.game_state.get("fault_amount",0.0)) == 0.0,"Warning did not settle")
	expect(not host.presenter.receiver_enabled,"Warning enabled expensive receiver simulation")
	# With unrelated gameplay stress cleared, every animated knob must settle
	# exactly back to the active preset, not to the source JSON's fixed look.
	host.set_game_state(0.0,Vector2.ZERO,0.0,0.0,{})
	expect(host.presenter.signal_settings==saved_signal,"Authored warning left changed signal knobs behind")
	expect(host.presenter.last_error.is_empty(),host.presenter.last_error)
	# A floor change during the hidden stage must not reveal a stale actor.
	manager.despawn()
	await process_frame
	manager._dark_bag.assign([0])
	manager._walker_due = false
	expect(manager._spawn_at(ground,false,2.0),"Cancellation fixture did not spawn")
	manager.despawn()
	for frame in 35: await process_frame
	expect(manager.active_figures().is_empty(),"Cancelled appearance survived despawn")
	await teardown_game(game)
	finish("GPU warning precedes manifestation; holds, comfort routing, occupancy and cancellation preserved")
