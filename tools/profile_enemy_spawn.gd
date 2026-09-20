extends SceneTree
## Cold/warm CPU spawn construction, with model decoding measured separately.
## Uses real visuals without changing game progress or running a campaign.

class TimedVisual extends ShadowWalkerVisual:
	var timings := {}
	func _prepare_materials(node: Node) -> void:
		var started := Time.get_ticks_usec()
		super._prepare_materials(node)
		timings.materials_ms = (Time.get_ticks_usec() - started) / 1000.0
	func _prepare_animation(node: Node) -> void:
		var started := Time.get_ticks_usec()
		super._prepare_animation(node)
		timings.animation_ms = (Time.get_ticks_usec() - started) / 1000.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = 30.0
	watchdog.one_shot = true
	watchdog.timeout.connect(func(): quit(1))
	root.add_child(watchdog)
	watchdog.start()
	var started := Time.get_ticks_usec()
	ShadowWalkerVisual.request_model(0)
	while not ShadowWalkerVisual.is_model_ready(0):
		await process_frame
	print("SPAWN PROFILE model decode/wait %.2fms" % ((Time.get_ticks_usec() - started) / 1000.0))
	started = Time.get_ticks_usec()
	ShadowFigure.prewarm_presence()
	print("SPAWN PROFILE manager setup/prewarm %.3fms" % ((Time.get_ticks_usec() - started) / 1000.0))
	var visual := TimedVisual.new()
	started = Time.get_ticks_usec()
	root.add_child(visual)
	print("SPAWN PROFILE visual %.3fms stages=%s" % [(Time.get_ticks_usec() - started) / 1000.0, visual.timings])
	visual.free()
	for index in 4:
		var figure := ShadowFigure.new()
		figure.process_mode = Node.PROCESS_MODE_DISABLED
		started = Time.get_ticks_usec()
		root.add_child(figure)
		print("SPAWN PROFILE construction %d %.3fms" % [index, (Time.get_ticks_usec() - started) / 1000.0])
		figure.free()
		await process_frame
	watchdog.stop()
	watchdog.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0)
