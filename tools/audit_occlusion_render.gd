extends SceneTree
## Actual-game image comparison for authored Data Center occluders.
## Run with a GPU, not --headless:
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
##   --script tools/audit_occlusion_render.gd -- --nologo --mode=wander
## Temporal AA is disabled only in this diagnostic for deterministic readback.

var view: SubViewport
var game: Node3D
var failures := 0

func _init() -> void:
	call_deferred("run")

func draw(count := 1) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 0.0)

func compare(target: SubViewport, label: String) -> void:
	target.use_occlusion_culling = false
	await draw(16)
	var before := target.get_texture().get_image()
	target.use_occlusion_culling = true
	await draw(16)
	var after := target.get_texture().get_image()
	var a := before.get_data()
	var b := after.get_data()
	if a.is_empty() or a.size() != b.size():
		push_error("Missing occlusion readback")
		failures += 1
		return
	var total := 0.0
	var changed := 0
	var maximum := 0
	for i in a.size():
		var error := absi(int(a[i]) - int(b[i]))
		total += error
		maximum = maxi(maximum, error)
		if error > 4:
			changed += 1
	var mean := total / a.size()
	var fraction := float(changed) / a.size()
	print("OCCLUSION_COMPARE %s mean=%.5f max=%d changed_over_4=%.5f" % [
		label, mean, maximum, fraction])
	if mean > 0.15 or fraction > 0.001:
		failures += 1
		before.save_png("/tmp/liminal-occlusion-%s-before.png" % label)
		after.save_png("/tmp/liminal-occlusion-%s-after.png" % label)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Occlusion image audit requires a GPU renderer.")
		quit(1)
		return
	view = SubViewport.new()
	view.size = Vector2i(960, 540)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 240721
	view.add_child(game)
	game._switch_level(10)
	while game._switching:
		await draw()
	await draw(300)
	game._post_process.set_enabled(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 0.0
	view.use_taa = false
	var photo := SubViewport.new()
	photo.size = Vector2i(640, 360)
	photo.world_3d = view.world_3d
	photo.msaa_3d = Viewport.MSAA_4X
	photo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(photo)
	var camera := Camera3D.new()
	camera.fov = game.player.cam.fov
	camera.cull_mask = (game.player.cam.cull_mask | PhotoAnomaly.PHOTO_LAYER) & ~PhotoAnomaly.EYE_ONLY_LAYER
	photo.add_child(camera)
	for dark in [false, true]:
		game.cm.set_blackout(dark)
		if dark:
			game.we.environment.ambient_light_energy = 0.003
		# Let volumetric-fog history settle after switching all room lights.
		await draw(96)
		for angle in 4:
			game.player.rotation.y = angle * PI * 0.5
			camera.global_transform = game.player.cam.global_transform
			await compare(view, "live-%s-%d" % [dark, angle])
			await compare(photo, "photo-%s-%d" % [dark, angle])
	game.free()
	game = null
	photo.free()
	view.free()
	view = null
	Engine.time_scale = 1.0
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	await draw(3)
	print("occlusion render audit: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
