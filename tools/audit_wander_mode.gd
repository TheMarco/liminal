extends SceneTree
## Runtime contract for Wander's pressure-free level browsing.
## Run: godot --headless --path . --script tools/audit_wander_mode.gd \
##        -- --nologo

const SEED := 405195947


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	game.world_seed = SEED
	get_root().add_child(game)
	await physics_frame
	await process_frame

	_expect(not game.descent, "default startup did not select Wander", failures)
	_expect(game._figures.suspended,
		"Wander startup enabled hostile shadow figures", failures)
	_expect(not game._whispers.suspended,
		"Wander startup left ambient whispers suspended", failures)

	game._show_return_prompt()
	game._cancel_return_to_title()
	_expect(game._figures.suspended,
		"cancelling the return prompt enabled Wander figures", failures)

	game._on_start(false)
	await process_frame
	_expect(not game.descent, "Wander title start selected Descent", failures)
	_expect(game._figures.suspended,
		"Wander title start enabled hostile shadow figures", failures)

	# A signal already queued before a mode transition must also be harmless.
	game._on_figure_reached_player()
	_expect(not game._dying,
		"a stale figure signal triggered a Wander death", failures)

	if failures.is_empty():
		print("wander mode audit: PASS — shadow figures remain disabled")
	else:
		for failure in failures:
			print("FAIL ", failure)
	_stop_audio(game)
	game.free()
	Chunk.finish_prop_preloads()
	SoundBank._c.clear()
	Sfx._c.clear()
	await process_frame
	await physics_frame
	await create_timer(0.1).timeout
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String,
		failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
