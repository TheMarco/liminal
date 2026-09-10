extends SceneTree
## Rendered comparison of realm preparation, a sealed wall, and the lens view.
## Run with -- --mode=descent --nologo --seed=21 --descent-floor=2.
var game: Node3D
var view: SubViewport

func _init() -> void:
	call_deferred("run_profile")

func report(label: String, samples: Array[float], draws: Array[float]) -> void:
	if samples.is_empty():
		return
	samples.sort()
	draws.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	print("REALM PERF %s frames=%d avg=%.2f p95=%.2f max=%.2f draws_median=%.0f" % [label, samples.size(), total / samples.size(), samples[mini(samples.size() - 1, floori(samples.size() * 0.95))], samples[-1], draws[draws.size() / 2]])

func sample_frames(label: String, count: int) -> void:
	var samples: Array[float] = []
	var draws: Array[float] = []
	for i in count:
		var started := Time.get_ticks_usec()
		await process_frame
		var frame_ms := (Time.get_ticks_usec() - started) / 1000.0
		samples.append(frame_ms)
		if frame_ms > 80.0:
			print("REALM PERF spike %s wall=%.1f process=%.1f physics=%.1f" % [label, frame_ms,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report(label, samples, draws)

func run_profile() -> void:
	Engine.max_fps = 60
	create_timer(100.0, true).timeout.connect(func(): quit(1))
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	game.run.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._set_presence(game.Presence.SILENT)
	var visit: RealmExcursion = game._realm_visit
	await sample_frames("arrival", 90)
	var eye: Vector3 = visit._record.discovery_origin
	var forward: Vector3 = visit._record.discovery_forward
	game.player.teleport(eye - Vector3.UP * Player.CAM_H)
	game.player.cam.rotation.y = atan2(-forward.x, -forward.z)
	var samples: Array[float] = []
	var draws: Array[float] = []
	var prepared := Time.get_ticks_usec()
	while visit.phase == RealmExcursion.Phase.PREPARING or not is_instance_valid(visit.window):
		var started := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report("prepare", samples, draws)
	print("REALM PERF ready_after_ms=%.1f" % ((Time.get_ticks_usec() - prepared) / 1000.0))
	await sample_frames("settle", 120)
	game.cm.set_process(false)
	game.run.arrival_grace = 0.0
	game.run.resume_rules(0.0)
	await sample_frames("sealed", 180)
	print("REALM PERF sealed_preview_mode=%d size=%s" % [visit.preview.render_target_update_mode, visit.preview.size])
	game._photo_camera._raise(true)
	await sample_frames("lens", 180)
	print("REALM PERF lens_preview_mode=%d size=%s" % [visit.preview.render_target_update_mode, visit.preview.size])
	game._photo_camera._lower()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
