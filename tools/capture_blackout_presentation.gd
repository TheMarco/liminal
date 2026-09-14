extends "res://tools/lib/audit_base.gd"
## Render actual floor geometry, environments and the player's torch through
## normal -> loss of power -> torch -> restored power. No profile/run writes.
## godot --path . --script tools/capture_blackout_presentation.gd
const OUT := "res://build/blackout-review"
const POWER := preload("res://scripts/blackout_environment.gd")
var view: SubViewport

func draw(count: int) -> void:
	for i in count:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func capture(key: String) -> float:
	var image := view.get_texture().get_image()
	expect(image.save_png(OUT.path_join(key + ".png")) == OK, "could not save " + key)
	var total := 0.0
	var count := 0
	for x in range(40, image.get_width() - 40, 8):
		for y in range(40, image.get_height() - 40, 8):
			var color := image.get_pixel(x, y)
			total += color.get_luminance()
			count += 1
	return total / float(count)

func fixture(theme: int, grand: bool) -> Vector2i:
	if not grand:
		return Vector2i.ZERO
	var ws := WorldGen.level_seed(240721, theme)
	for radius in range(1, 9):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				if AirportGrandCeiling.applies(Chunk.cell_ceil_h(ws, cell, theme), WorldGen.cell_style(ws, cell, theme)):
					return cell
	fail("no grand Airport fixture")
	return Vector2i.ZERO

func floor_view(theme: int, grand := false) -> void:
	var stage := Node3D.new()
	view.add_child(stage)
	var we := WorldEnvironment.new()
	we.environment = EnvBuilder.build(theme)
	stage.add_child(we)
	var cm := ChunkManager.new()
	cm.theme = theme
	cm.world_seed = WorldGen.level_seed(240721, theme)
	stage.add_child(cm)
	cm.set_process(false)
	var cell := fixture(theme, grand)
	cm.warm_up(cell)
	var chunk := cm.chunk_at(cell)
	var player := Player.new()
	stage.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var from := Vector3(2.3, 0, 2.7)
	for point in [from, Vector3(1.3, 0, 1.3), Vector3(6, 0, 2), Vector3(6, 0, 6)]:
		if chunk._floor_spot_clear(point, 0.3, 1.8):
			from = point
			break
	from.y += Player.CAM_H
	var target := Vector3(8.5, chunk.ceil_h * 0.55, 8.5)
	if grand:
		target = Vector3(6, chunk.ceil_h, 6)
	if theme == 9:
		from.y += Chunk.POOL_DECK_Y
	var origin := Vector3(cell.x * 12.0, 0, cell.y * 12.0)
	player.cam.look_at_from_position(origin + from, origin + target)
	player.cam.current = true
	var post := PostProcessController.new()
	stage.add_child(post)
	post.setup(stage, false, false)
	var key := "%02d" % theme + ("-grand" if grand else "")
	await draw(65)
	var normal := capture(key + "-normal")
	var power := POWER.new()
	var started := Time.get_ticks_usec()
	cm.set_blackout(true)
	power.apply(we.environment)
	var change_ms := float(Time.get_ticks_usec() - started) / 1000.0
	await draw(24)
	var dark := capture(key + "-blackout")
	player.set_flashlight(true)
	await draw(24)
	var torch := capture(key + "-torch")
	post.set_enabled(true)
	await draw(4)
	capture(key + "-torch-tape")
	post.set_enabled(false)
	player.set_flashlight(false)
	cm.set_blackout(false)
	power.restore()
	await draw(65)
	var restored := capture(key + "-restored")
	expect(dark < normal * 0.3, "floor %s remains bright during blackout: %f / %f" % [key, dark, normal])
	expect(torch > dark + 0.01, "floor %s torch no longer reveals the room" % key)
	expect(restored > normal * 0.7, "floor %s stays dark after power returns" % key)
	print("BLACKOUT_RENDER floor=%s cell=%s normal=%.4f off=%.4f torch=%.4f restored=%.4f transition_ms=%.2f" % [
		key, cell, normal, dark, torch, restored, change_ms])
	stage.free()
	await draw(2)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	# Start with the reported floor, including its distinct tall ceiling.
	for theme in [4, 0, 1, 2, 5, 6, 7, 8, 9, 10, 11]:
		await floor_view(theme)
		if theme == 4:
			await floor_view(theme, true)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("rendered blackout presentation")
