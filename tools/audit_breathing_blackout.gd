extends "res://tools/lib/audit_base.gd"
## Actual Main blackout handoff during Airport ceiling preparation, motion and
## deferred cleanup. Optional --capture writes native before/during/after views.
## godot --headless --path . --script tools/audit_breathing_blackout.gd -- \
##   --test-mode --descent-floor=4 --seed=345114697 --no-video-effects
const Placement := preload("res://scripts/environment_breath_placement.gd")
const Surface := preload("res://scripts/environment_breath_surface.gd")
const Profile := preload("res://scripts/environment_breath_profile.gd")
const OUT := "res://build/breathing-blackout-review"
var view: SubViewport
var game: Node
var capture_enabled := false


func draw(count := 24) -> void:
	for i in count:
		if is_instance_valid(game) and is_instance_valid(game._pause_menu):
			game._close_settings()
		await process_frame
		if capture_enabled: RenderingServer.force_draw(false, 1.0 / 60.0)


func capture(key: String) -> Image:
	if not capture_enabled: return null
	var image := view.get_texture().get_image()
	expect(image.save_png(OUT.path_join(key + ".png")) == OK, "save " + key)
	return image


func run() -> void:
	capture_enabled = OS.get_cmdline_user_args().has("--capture")
	if capture_enabled: DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(960, 600)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	expect(game.descent and game.active_level == 4 and not game._progress_enabled,
		"requires isolated Descent Airport CLI flags")
	if not game.descent or game.active_level != 4:
		await teardown_game(game)
		view.free()
		finish()
		return
	game.player.set_flashlight(false)
	game._post_process.set_enabled(false)
	for layer in game.find_children("*", "CanvasLayer", true, false): layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var chunk: Chunk
	var choice: Dictionary = {}
	for candidate: Chunk in game.cm.chunks.values():
		var choices := Placement.candidates(candidate, "ceiling")
		if not choices.is_empty():
			chunk = candidate
			choice = choices[0]
			break
	expect(not choice.is_empty(), "Airport fixture has no ceiling breath candidate")
	if choice.is_empty():
		await teardown_game(game)
		view.free()
		finish()
		return
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.current = true
	var focus: Vector3 = chunk.to_global(choice.center)
	camera.look_at_from_position(focus + Vector3(-1.5, -2.5, 1.5), focus)
	var ceiling: MeshInstance3D = choice.face.mesh
	var original_mesh := ceiling.mesh
	var original_material := ceiling.material_override as StandardMaterial3D
	var original_margin := ceiling.extra_cull_margin
	expect(original_material != null and original_material.uv1_triplanar,
		"fixture must exercise Airport's world-projected textured ceiling")
	var director: Node = game._breathing
	for phase in ["preparing", "active", "cancelled"]:
		# Let the production GI/probe history settle before comparing pixels.
		await draw(65)
		var before := capture(phase + "-before")
		var effect := Surface.new()
		chunk.add_child(effect)
		effect.begin_setup(choice, "ceiling")
		# Use the real surface and director cleanup, controlling only timing.
		while not effect.prepared and not effect.failed:
			effect.prepare_step()
			if phase == "preparing" and not effect.pieces.is_empty(): break
		expect(not effect.failed and (effect.prepared or phase == "preparing"),
			phase + ": effect preparation failed")
		director.active = effect
		director.active_chunk = chunk
		director.selection = choice
		director.kind = "ceiling"
		if phase != "preparing":
			effect.pose(Profile.weights("ceiling", 0.5))
			effect.sync_collision()
			expect(ceiling.mesh != original_mesh and ceiling.material_override != original_material,
				phase + ": effect did not install the paired mesh/material")
		if phase == "active":
			await draw()
			capture("active-motion")
		if phase == "cancelled": director.cancel()
		game.run.blackout = true
		game._on_descent_blackout(true)
		expect(director.active == null, phase + ": blackout did not synchronously cancel architecture")
		expect(ceiling.mesh == original_mesh, phase + ": blackout captured a temporary mesh")
		# Exercise the old next-tick safety gate and queue_free/_exit_tree too.
		director._physics_process(0.016)
		await draw()
		expect(not is_instance_valid(effect), phase + ": effect was not freed")
		var dark := ceiling.material_override as StandardMaterial3D
		expect(dark != null and dark.emission_energy_multiplier == 0.0,
			phase + ": cleanup relit the ceiling during blackout")
		expect(dark != null and dark.uv1_triplanar,
			phase + ": blackout material lost the original texture projection")
		var off := capture(phase + "-blackout")
		game.run.blackout = false
		game._on_descent_blackout(false)
		await draw(65)
		expect(ceiling.mesh == original_mesh and ceiling.material_override == original_material
			and ceiling.extra_cull_margin == original_margin,
			phase + ": power restoration mismatched original mesh/material")
		var after := capture(phase + "-restored")
		if capture_enabled:
			var normal_luma := _luminance(before)
			var off_luma := _luminance(off)
			var error := _pixel_error(before, after)
			expect(off_luma < normal_luma * 0.3, phase + ": rendered ceiling remains bright")
			expect(error < 0.015, phase + ": restored ceiling differs from its original appearance")
			print("CEILING_BLACKOUT phase=%s normal=%.4f off=%.4f restored_error=%.6f" % [phase, normal_luma, off_luma, error])
		# Isolate cases even when demonstrating the unfixed restoration bug.
		ceiling.mesh = original_mesh
		ceiling.material_override = original_material
		ceiling.extra_cull_margin = original_margin
	await teardown_game(game)
	view.free()
	finish("Airport ceiling blackout handoff: preparation, active motion, deferred cleanup")


func _luminance(image: Image) -> float:
	var total := 0.0
	var count := 0
	for x in range(40, image.get_width() - 40, 8):
		for y in range(40, image.get_height() - 40, 8):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / count


func _pixel_error(before: Image, after: Image) -> float:
	var total := 0.0
	var count := 0
	for x in range(40, before.get_width() - 40, 8):
		for y in range(40, before.get_height() - 40, 8):
			var delta := before.get_pixel(x, y) - after.get_pixel(x, y)
			total += (absf(delta.r) + absf(delta.g) + absf(delta.b)) / 3.0
			count += 1
	return total / count
