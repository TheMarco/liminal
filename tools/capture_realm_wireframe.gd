extends SceneTree
## Capture the voxel / wireframe collapse at several exact points.
const OUT := "/tmp/liminal-realm-wireframe"
const TIMEOUT_MS := 45000
var view: SubViewport
var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func shot(name: String) -> void:
	for i in 5:
		await process_frame
	view.get_texture().get_image().save_png(OUT.path_join(name + ".png"))

func run_test() -> void:
	Engine.max_fps = 60
	var run_deadline := Time.get_ticks_msec() + TIMEOUT_MS
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING and Time.get_ticks_msec() < run_deadline:
		await process_frame
	if Time.get_ticks_msec() >= run_deadline:
		push_error("WIREFRAME CAPTURE TIMEOUT while preparing")
		quit(1)
		return
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	visit.collapse_style = "wireframe"
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	for anomaly in game._photo_director._live_doors.values():
		if anomaly.id == visit.seal.photo_id:
			game._photo_director.mark_documented(anomaly.id)
			anomaly.resolve()
			break
	await visit.enter()
	visit.set_process(false)
	visit.threats.suspended = true
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._post_process.set_enabled(false)
	game._osd_layer.visible = false
	game._descent_hud.visible = false
	game._event_panel.visible = false
	var effect: RealmWireframeCollapse = visit._collapse_effect
	var old_reduced: bool = GameSettings.flashing_reduced()
	GameSettings.current.values["reduced_flashing"] = false
	for pair in [[0.0, "01-intact"], [0.18, "02-stripping"], [0.40, "03-wireframe"], [0.65, "04-separating"], [0.86, "05-disintegrating"], [1.0, "06-gone"]]:
		var start := Time.get_ticks_usec()
		effect.set_progress(float(pair[0]))
		if float(pair[0]) == 0.18:
			print("WIREFRAME SAMPLING: %.2f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
		await shot(str(pair[1]))
	GameSettings.current.values["reduced_flashing"] = true
	effect.set_progress(0.65)
	await shot("07-reduced-flashing")
	GameSettings.current.values["reduced_flashing"] = false
	game._post_process.set_enabled(true)
	effect.set_progress(0.40)
	await shot("08-recovered-tape")
	effect.set_progress(0.82)
	await shot("09-late-recovered-tape")
	GameSettings.current.values["reduced_flashing"] = old_reduced
	print("WIREFRAME CAPTURE: %d voxels" % effect.voxel_count)
	visit.elapsed = RealmExcursion.DURATION
	visit.collapse()
	while visit._rebuild_effect == null and Time.get_ticks_msec() < run_deadline:
		await process_frame
	if visit._rebuild_effect == null:
		push_error("WIREFRAME CAPTURE TIMEOUT waiting for reassembly")
		quit(1)
		return
	var rebuild: RealmWireframeCollapse = visit._rebuild_effect
	for pair in [[0.9, "10-return-emerging"], [0.65, "11-return-cubes"], [0.4, "12-return-wireframe"], [0.18, "13-return-solidifying"]]:
		while rebuild.progress > float(pair[0]) and Time.get_ticks_msec() < run_deadline:
			await process_frame
		assert(Time.get_ticks_msec() < run_deadline, "reassembly stage timed out")
		await shot(str(pair[1]))
	while visit.phase != RealmExcursion.Phase.SPENT and Time.get_ticks_msec() < run_deadline:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.SPENT, "return did not complete")
	await shot("14-return-complete")
	print("REALM WIREFRAME CAPTURE PASS: " + OUT)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
