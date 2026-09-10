extends SceneTree
## Inspect the same world at several exact points in the disintegration.
const OUT := "/tmp/liminal-realm-collapse"
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
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	var deadline := Time.get_ticks_msec() + 30000
	while visit.phase == RealmExcursion.Phase.PREPARING and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	visit.collapse_style = "fracture" # Preserve the original comparison capture.
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
	var effect: RealmCollapseEffect = visit._collapse_effect
	var old_reduced: bool = GameSettings.flashing_reduced()
	GameSettings.current.values["reduced_flashing"] = false
	for pair in [[0.0, "01-intact"], [0.24, "02-fractures"], [0.58, "03-breaking"], [0.83, "04-disintegration"], [0.96, "05-last-fragments"], [1.0, "05b-gone"]]:
		effect.set_progress(float(pair[0]))
		await shot(str(pair[1]))
	GameSettings.current.values["reduced_flashing"] = true
	effect.set_progress(0.83)
	await shot("06-reduced-flashing")
	GameSettings.current.values["reduced_flashing"] = false
	game._post_process.set_enabled(true)
	effect.set_progress(0.72)
	await shot("07-recovered-tape")
	effect.set_progress(0.93)
	await shot("07b-final-recovered-tape")
	GameSettings.current.values["reduced_flashing"] = old_reduced
	print("COLLAPSE CAPTURE: %d surface fragments" % effect.shard_count)
	print("PARTICLE CAPTURE: %d sparks + %d dust wisps" % [effect._particles.spark_count, effect._particles.dust_count])
	await visit.collapse()
	await shot("08-return")
	print("REALM COLLAPSE CAPTURE PASS: " + OUT)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
