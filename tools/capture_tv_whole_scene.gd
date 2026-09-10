extends SceneTree
## Capture actual Main playback with the shared game post-processing pipeline.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--nologo"))
	var view := SubViewport.new()
	view.size = Vector2i(1440, 900)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	view.add_child(game)
	await create_timer(2.0).timeout
	game.player.set_physics_process(false)
	game.cm.set_process(false)
	var tv := VhsRitual.new()
	tv.objective = false
	tv.setup_key = "capture-shared-tv"
	tv.pinned_tape = VhsTapeLibrary.paths(false)[0]
	game.add_child(tv)
	tv.position = game.player.position + Vector3(0, 0, -2)
	await process_frame
	game._post_process.set_enabled(false)
	tv._on_activated(game.player)
	await create_timer(3.0).timeout
	assert(game._post_process._overlay.visible)
	assert(tv._video != null and tv._video.is_playing())
	for item in tv._video_vp.find_children("*", "CanvasItem", true, false):
		assert(not item.material is ShaderMaterial)
	await RenderingServer.frame_post_draw
	var out := "res://build/tv-whole-scene.png"
	assert(view.get_texture().get_image().save_png(out) == OK)
	print("TV_WHOLE_SCENE_CAPTURE PASS ", out)
	quit()
