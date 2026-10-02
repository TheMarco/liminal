extends "res://tools/lib/audit_base.gd"
## Actual Main playback: cabinet framing and screen spill at desktop aspects.
## Native: godot --path . --script tools/capture_tv_whole_scene.gd -- --nologo --level=1
const OUT := "res://build/tv-playback"
var _game: Node

func settle(count := 12) -> void:
	for frame in count:
		# Native captures can lose window focus while Codex is active. Resume
		# the fixture so focus-pause cannot freeze its camera transition.
		if is_instance_valid(_game) and is_instance_valid(_game._pause_menu):
			_game._close_settings()
		await process_frame

func wait_for_dolly(tv: VhsRitual) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while tv._watch_tween != null and tv._watch_tween.is_running() \
			and Time.get_ticks_msec() < deadline:
		await settle(1)
	expect(tv._watch_tween == null or not tv._watch_tween.is_running(), "camera transition did not finish")
	await settle(2)

func projected_cabinet(tv: VhsRitual) -> Rect2:
	var bounds := Rect2()
	for corner in 8:
		var at := tv._cam.unproject_position(tv.to_global(tv._tv_bounds.get_endpoint(corner)))
		bounds = Rect2(at, Vector2.ZERO) if corner == 0 else bounds.expand(at)
	return bounds

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("TV playback capture requires the native renderer")
		finish("TV playback cabinet")
		return
	expect(OS.get_cmdline_user_args().has("--nologo"), "capture needs --nologo to isolate progress")
	DirAccess.make_dir_recursive_absolute(OUT)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game = load("res://scenes/main.tscn").instantiate()
	_game = game
	game.world_seed = 240721
	view.add_child(game)
	await settle(30)
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	stop_audio(game)
	var settings := GameSettings.new("/tmp/liminal-tv-capture-%d.cfg" % OS.get_process_id())
	settings.set_value("fullscreen", false)
	settings.set_value("vhs_enabled", false)
	settings.set_value("crt_enabled", false)
	settings.apply_quality_preset(1)
	game._settings = settings
	GameSettings.current = settings
	settings.changed.connect(game._apply_game_settings)
	game._apply_game_settings()
	var tv := VhsRitual.new()
	tv.objective = true
	tv.already_watched = true
	tv.setup_key = "capture-shared-tv"
	tv.pinned_tape = VhsTapeLibrary.objective_chapter(0)
	game.add_child(tv)
	tv.position = game.player.position + Vector3(0, 0, -2)
	tv._tape_path = tv.pinned_tape
	expect(tv._ensure_video(), "fixture recording could not load")
	tv._video.volume_db = -80.0
	tv._on_activated(game.player)
	await wait_for_dolly(tv)
	expect(tv._video != null and tv._video.is_playing(), "recording is not playing")
	expect(tv._watch_light.visible and tv._watch_light.layers == VhsRitual.WATCH_LAYER
		and tv._watch_light.light_cull_mask == VhsRitual.WATCH_LAYER,
		"screen spill is missing or lights the room")
	for item in tv._video_vp.find_children("*", "CanvasItem", true, false):
		expect(not item.material is ShaderMaterial, "footage was processed twice")
	for crt in [false, true]:
		settings.set_value("crt_enabled", crt)
		for extent in [Vector2i(1280, 720), Vector2i(3456, 2234)]:
			view.size = extent
			await settle()
			var cabinet := projected_cabinet(tv)
			var safe := Rect2(Vector2(extent) * 0.015, Vector2(extent) * 0.97)
			expect(safe.encloses(cabinet), "cabinet clipped at " + str(extent))
			var hint := tv._watch_hint.get_node("Backing") as PanelContainer
			var hint_bounds := Rect2(hint.position, hint.size * hint.scale)
			expect(not hint_bounds.intersects(cabinet), "controls obscure the TV cabinet")
			await RenderingServer.frame_post_draw
			var label := "%s-%dx%d" % ["crt" if crt else "vhs", extent.x, extent.y]
			expect(view.get_texture().get_image().save_png(OUT.path_join(label + ".png")) == OK,
				"capture failed: " + label)
			print("TV_PLAYBACK %s cabinet=%s" % [label, cabinet])
	tv.reset_tape()
	expect(not tv._watch_light.visible, "screen spill stayed on after playback")
	await wait_for_dolly(tv)
	expect(view.get_camera_3d() == game.player.cam, "playback did not restore the player camera")
	await teardown_game(game)
	view.queue_free()
	await process_frame
	finish("TV playback: complete cabinet, readable screen spill, VHS/CRT, resize and camera restore")
