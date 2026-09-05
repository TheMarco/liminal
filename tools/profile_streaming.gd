extends SceneTree
## Main-thread streaming work, not total frame/GPU time. Warm the exact route,
## then measure a simulated sprint out and back at 60 updates/second.
## godot --headless --path . --script tools/profile_streaming.gd -- --theme=10

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var themes: Array[int] = WorldGen.THEMES.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			themes.assign([int(arg.trim_prefix("--theme="))])
	for theme in themes:
		await traverse(theme, false)
		await traverse(theme, true)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()

func traverse(theme: int, measured: bool) -> void:
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.position = Vector3(6.0, 1.7, 6.0)
	var manager := ChunkManager.new()
	manager.theme = theme
	manager.world_seed = WorldGen.level_seed(240721, theme)
	manager.player = player
	root.add_child(manager)
	manager.set_process(false)
	manager.warm_up(Vector2i.ZERO)
	var samples: Array[float] = []
	var total := 0.0
	for step in 1200:
		var outwards := step < 600
		player.position.x = 6.0 + (step if outwards else 1200 - step) * 0.1
		player.velocity = Vector3(6.0 if outwards else -6.0, 0.0, 0.0)
		var start := Time.get_ticks_usec()
		manager._process(1.0 / 60.0)
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		samples.append(ms)
		total += ms
		# Flush deferred deletion regularly; do not count harness waits as work.
		if step % 10 == 0:
			await process_frame
	if measured:
		samples.sort()
		print("STREAM theme=%d avg=%.3f p95=%.3f p99=%.3f max=%.3f resident=%d" % [
			theme, total / samples.size(), samples[1139], samples[1187], samples[-1], manager.chunks.size()])
	manager.free()
	player.free()
	await process_frame
