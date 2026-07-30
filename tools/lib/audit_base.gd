extends SceneTree
## Shared base for the runtime audits: the ones that boot scenes/main.tscn and
## then poke the running game, rather than constructing chunks directly.
##
## Those three each carried a verbatim copy of the boot sequence, a copy of the
## audio teardown, their own _expect with an incompatible signature, and their own
## exit convention. The teardown in particular is not obvious -- forgetting to
## stop the players or to drain Chunk's threaded preloads makes an audit report
## leaked objects that the audit itself created.
##
## Subclasses `extends "res://tools/lib/audit_base.gd"` and override `run()`.
## Report problems with `fail()` or `expect()`, then call `finish()`, which owns
## the exit code: 0 when nothing failed, 1 otherwise.
##
## A failed audit must still reach finish(). An `extends SceneTree` script that
## errors out mid-run never calls quit(), so the process idles forever and looks
## slow instead of broken; tools/run_audits.sh caps every audit for that reason.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_start")


func _start() -> void:
	await run()


## Override this.
func run() -> void:
	push_error("audit did not override run()")
	finish()


## Boot the real game the way the player does, so startup order is exercised
## rather than simulated. Pass the CLI flags the audit needs on the command line
## (`-- --nologo` and friends); main parses them itself.
func boot_game(world_seed: int) -> Node:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game := scene.instantiate()
	game.world_seed = world_seed
	get_root().add_child(game)
	await physics_frame
	await process_frame
	return game


## Free a booted game without leaving anything behind that a later check would
## count. Audio has to stop before the node goes, and Chunk's threaded prop loads
## have to be consumed or they read as leaked resources.
func teardown_game(game: Node) -> void:
	stop_audio(game)
	game.free()
	Chunk.finish_prop_preloads()
	SoundBank._c.clear()
	Sfx._c.clear()
	await process_frame
	await physics_frame
	await create_timer(0.1).timeout


func stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func fail(message: String) -> void:
	failures.append(message)


## Wait for a condition, or give up. Returns whether it came true. Used instead of
## a fixed frame count because `--quit-after` and frame counts are not wall-clock
## and a slow machine would otherwise fail a passing contract.
func await_until(check: Callable, timeout_ms := 5000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if check.call():
			return true
		await process_frame
	return check.call()


func level_seed(base: int, theme: int) -> int:
	return WorldGen.level_seed(base, theme)


## World-space AABB of everything under a node, which several audits each walked
## for themselves. Skips hidden nodes: they are not part of what the player sees.
func visual_bounds(root: Node, from_child := 0) -> AABB:
	var out := AABB()
	var seeded := false
	var children := root.get_children()
	for i in range(from_child, children.size()):
		var box := _walk_bounds(children[i], Transform3D.IDENTITY)
		if box.size == Vector3.ZERO:
			continue
		out = box if not seeded else out.merge(box)
		seeded = true
	return out


func _walk_bounds(node: Node, xf: Transform3D) -> AABB:
	var here := xf
	if node is Node3D:
		if not (node as Node3D).visible:
			return AABB()
		here = xf * (node as Node3D).transform
	var out := AABB()
	var seeded := false
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			out = here * mesh.get_aabb()
			seeded = true
	for child in node.get_children():
		var box := _walk_bounds(child, here)
		if box.size == Vector3.ZERO:
			continue
		out = box if not seeded else out.merge(box)
		seeded = true
	return out


## An integer command-line argument, clamped. Every audit was re-deriving this
## with a different default and a different range.
func arg_int(index: int, default_value: int, lo: int, hi: int) -> int:
	var args := OS.get_cmdline_user_args()
	var plain: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			plain.append(a)
	if index >= plain.size():
		return clampi(default_value, lo, hi)
	return clampi(int(plain[index]), lo, hi)


## Single exit point, so pass and fail always report the same way.
func finish(summary := "") -> void:
	if failures.is_empty():
		if not summary.is_empty():
			print("  PASS — %s" % summary)
		quit(0)
		return
	for f in failures:
		printerr("FAIL %s" % f)
	printerr("%d failure(s)" % failures.size())
	quit(1)
