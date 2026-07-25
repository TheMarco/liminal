extends SceneTree
## Dev: does a shadow figure actually close the distance while it is not being
## looked at? Drives the figure's own `_physics_process` by hand at a fixed step
## rather than waiting on real physics frames, so the answer is deterministic
## and the script cannot hang waiting for a tick that never comes.
##
## Run: godot --headless --path . --script tools/dbg_ghost_advance.gd

const STEP := 1.0 / 60.0


func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var ws := WorldGen.level_seed(12345, 0)
	var chunk := Chunk.new(ws, Vector2i(0, 0), 0)
	root.add_child(chunk)
	var player := Player.new()
	root.add_child(player)
	player.global_position = Vector3(Chunk.S * 0.5, 0.1, Chunk.S * 0.5)
	await process_frame
	await physics_frame

	var fig := ShadowFigure.new()
	fig.player = player
	fig.variant = ShadowFigure.DROWNED
	fig.grace = 0.0
	fig.position = player.global_position \
		+ Vector3(0, -0.1, 9.0)
	root.add_child(fig)
	await process_frame

	print("Figure 9m away. Driving its own step function by hand.")
	print()
	print("  phase          secs    gap     held   delta")
	var gap := _gap(player, fig)
	# yaw PI faces +Z, which is where the figure is stood
	gap = _phase(player, fig, 2.0, PI, "watching ", gap)
	gap = _phase(player, fig, 2.0, 0.0, "back turned", gap)
	gap = _phase(player, fig, 2.0, PI, "watching ", gap)
	gap = _phase(player, fig, 4.0, 0.0, "back turned", gap)
	print()
	if is_instance_valid(fig):
		print("final gap %.2f m" % _gap(player, fig))
	else:
		print("figure gone")
	quit()


func _gap(player: Player, fig: ShadowFigure) -> float:
	if not is_instance_valid(fig):
		return -1.0
	return Vector2(fig.global_position.x - player.global_position.x,
		fig.global_position.z - player.global_position.z).length()


func _phase(player: Player, fig: ShadowFigure, secs: float, yaw: float,
		label: String, last: float) -> float:
	player.rotation.y = yaw
	player.force_update_transform()
	if player.cam != null:
		player.cam.force_update_transform()
	var t := 0.0
	var report := 0.0
	while t < secs:
		if not is_instance_valid(fig):
			print("  %s  faded out" % label)
			return -1.0
		fig._physics_process(STEP)
		t += STEP
		report += STEP
		if report >= 1.0:
			report = 0.0
			var g := _gap(player, fig)
			print("  %-12s %4.1f  %6.2f   %-5s  %+.2f" % [
				label, t, g, str(fig.get("_held")), g - last])
			last = g
	return last
