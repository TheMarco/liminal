extends SceneTree
## Capture representative styles with production geometry, lighting and post.
## GPU required: godot --path . --minimized --audio-driver Dummy --disable-render-loop \
##   --script tools/capture_visual_review.gd -- --nologo --mode=wander \
##   --review-out=/tmp/liminal-visual-review
## Diagnostic camera placement does not change player progress or game files.
var view: SubViewport
var game: Node3D
var output := "res://build/visual-review"
var manifest: Array[Dictionary] = []
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-out="): output = arg.trim_prefix("--review-out=")
	call_deferred("run")
func draw(count := 1) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
func cells_for(theme: int) -> Dictionary:
	var ws := WorldGen.level_seed(240721, theme)
	var found := {}
	for radius in 30:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var cell := Vector2i(x,z)
				var style := WorldGen.cell_style(ws, cell, theme)
				if not found.has(style) and WorldGen.room_id(ws, cell) == cell:
					found[style] = cell
	return found
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view = SubViewport.new()
	view.size = Vector2i(960,540)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.use_taa = true
	view.positional_shadow_atlas_size = root.positional_shadow_atlas_size
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.world_seed = 240721
	view.add_child(game)
	for theme in WorldGen.THEMES:
		if game.active_level != theme:
			game.player.set_physics_process(true)
			game._switch_level(theme)
			while game._switching: await draw()
		await draw(60)
		game.player.set_physics_process(false)
		var cells := cells_for(theme)
		var styles := cells.keys()
		styles.sort()
		for style in styles:
			var cell: Vector2i = cells[style]
			var centre := Vector3(6, 0.15, 6)
			var safe: Vector3 = game._safe_arrival(theme, cell, centre)
			game.player.teleport(safe)
			game.player.reset_physics_interpolation()
			game.player.rotation.y = 0.65
			game.player._pitch = -0.08
			game.cm.stream_focus = safe
			game.cm.warm_up(Vector2i(floori(safe.x/12), floori(safe.z/12)))
			game._post_process.set_enabled(true)
			view.scaling_3d_scale = 480.0 / 540.0
			await draw(150)
			var resolved := ArrivalSafety.find_safe(game.get_world_3d(), safe, cell, [game.player.get_rid()])
			if resolved != Vector3.INF:
				game.player.teleport(resolved)
				safe = resolved
			game.player.reset_physics_interpolation()
			await draw(32)
			assert(Vector2i(floori(safe.x / WorldGen.CELL_SIZE), floori(safe.z / WorldGen.CELL_SIZE)) == cell)
			var prefix := "%s/theme-%02d-style-%03d" % [output,theme,style]
			view.get_texture().get_image().save_png(prefix + "-tape.png")
			game._post_process.set_enabled(false)
			view.scaling_3d_scale = 1.0
			await draw(32)
			view.get_texture().get_image().save_png(prefix + "-clean.png")
			game.player.rotation.y += PI
			await draw(32)
			view.get_texture().get_image().save_png(prefix + "-reverse-clean.png")
			manifest.append({"theme":theme,"style":style,"cell":[cell.x,cell.y],"position":[safe.x,safe.y,safe.z],"yaw":0.65,"prefix":prefix,"vram_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0})
			FileAccess.open(output+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
			print("CAPTURE theme=%d style=%d cell=%s position=%s" % [theme,style,cell,safe])
	game.free()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("LOOK REVIEW COMPLETE %d styles" % manifest.size())
	quit()
