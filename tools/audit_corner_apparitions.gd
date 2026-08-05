extends SceneTree
## Focused contract for the five user-supplied, stationary corner sightings.
## Run: godot --headless --path . --script tools/audit_corner_apparitions.gd

const SEEDS := [405195947, 7, 1234577]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	if CornerApparitions.LOOKS.size() != 5:
		failures.append("expected five corner silhouettes, got %d" \
			% CornerApparitions.LOOKS.size())
	if not is_equal_approx(CornerApparitions.HOLD_SECONDS, 2.0):
		failures.append("stationary hold is not exactly two seconds")
	if CornerApparitions.MAX_REVEAL_D > 16.0:
		failures.append("corner apparitions can still reveal too far away")
	if CornerApparitions.QUIET_MIN < 120.0 \
			or CornerApparitions.QUIET_MAX <= CornerApparitions.QUIET_MIN:
		failures.append("success cooldown is too frequent or inverted")

	for key in CornerApparitions.LOOKS:
		var path := "res://textures/ghosts/%s.png" % key
		if not ResourceLoader.exists(path):
			failures.append("missing texture " + path)
			continue
		var texture := load(path) as Texture2D
		if texture == null or texture.get_height() != 512:
			failures.append("%s is not a 512px game cutout" % key)
			continue
		var image := texture.get_image()
		if image == null or not image.detect_alpha():
			failures.append("%s has no transparent background" % key)

	var topology_rows := 0
	for base_seed in SEEDS:
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base_seed, theme)
			for y in range(-2, 3):
				for x in range(-2, 3):
					var origin := Vector2i(x, y)
					for row in CornerApparitions.topology_candidates(
							ws, theme, origin):
						topology_rows += 1
						var first_dir: int = row["first_dir"]
						var turn_dir: int = row["turn_dir"]
						var bend: Vector2i = row["bend"]
						var first_step: Vector2i = WorldGen.DIRV[first_dir]
						var turn_step: Vector2i = WorldGen.DIRV[turn_dir]
						if first_step.x * turn_step.x \
								+ first_step.y * turn_step.y != 0:
							failures.append("candidate is not a ninety-degree turn")
						if bool(WorldGen.edge_info(
								ws, origin, first_dir, theme)["wall"]):
							failures.append("candidate crosses a wall before its bend")
						if bool(WorldGen.edge_info(
								ws, bend, turn_dir, theme)["wall"]):
							failures.append("candidate crosses a wall after its bend")
						var expected: Vector2i = bend + WorldGen.DIRV[turn_dir] \
							* int(row["turn_steps"])
						if row["target_cell"] != expected:
							failures.append("candidate target is not beyond its bend")
	if topology_rows < 100:
		failures.append("too few topology-valid corner candidates: %d" \
			% topology_rows)

	# Render/lifetime contract. Disable scheduling while its manually revealed
	# node and tween are inspected.
	var manager := CornerApparitions.new()
	root.add_child(manager)
	manager.set_physics_process(false)
	manager._hidden_since[Vector2i.ZERO] = 1.0
	manager._exposed_until[Vector2i.ONE] = 2.0
	manager._t = 0.0
	manager.defer_for(CornerApparitions.SHARED_QUIET_SECONDS)
	if not manager._hidden_since.is_empty() \
			or not manager._exposed_until.is_empty() \
			or manager._t < CornerApparitions.SHARED_QUIET_SECONDS:
		failures.append("shared visual-scare quiet window was not enforced")
	var passer := PassingShadows.new()
	passer._t = 0.0
	passer.defer_for(CornerApparitions.SHARED_QUIET_SECONDS)
	if passer._t < CornerApparitions.SHARED_QUIET_SECONDS:
		failures.append("passing shadow ignored the shared quiet window")
	passer.free()
	manager._show(Vector3.ZERO)
	var live := manager._live
	if not is_instance_valid(live) or not live.has_meta("corner_apparition"):
		failures.append("manual reveal did not create an apparition")
	else:
		var meshes := live.find_children("*", "MeshInstance3D", true, false)
		var sounds := live.find_children("*", "AudioStreamPlayer3D", true, false)
		var collisions := live.find_children("*", "CollisionObject3D", true, false)
		if meshes.size() != 1:
			failures.append("apparition does not own exactly one silhouette mesh")
		elif (meshes[0] as MeshInstance3D).material_override == null:
			failures.append("apparition silhouette has no ghost material")
		if sounds.size() != 1 or (sounds[0] as AudioStreamPlayer3D).stream == null:
			failures.append("apparition reveal has no jump-scare cue")
		if not collisions.is_empty():
			failures.append("harmless apparition owns collision")
	await create_timer(CornerApparitions.HOLD_SECONDS - 0.10).timeout
	if not is_instance_valid(manager._live):
		failures.append("apparition vanished before its two-second hold")
	await create_timer(0.18).timeout
	if is_instance_valid(manager._live):
		var smoke_nodes := manager._live.find_children(
			"SilhouetteSmokePuff", "CPUParticles3D", true, false)
		if smoke_nodes.size() != 1:
			failures.append("apparition did not become a real smoke-particle puff")
		else:
			var smoke := smoke_nodes[0] as CPUParticles3D
			if smoke.amount < 200 or not smoke.one_shot or smoke.mesh == null:
				failures.append("smoke puff is missing its dense one-shot particle mesh")
	await create_timer(CornerApparitions.FADE_SECONDS + 0.12).timeout
	await process_frame
	if is_instance_valid(manager._live):
		failures.append("apparition survived its two-second hold and fade")
	root.remove_child(manager)
	manager.free()

	# Visibility gate: a figure remains completely absent behind the corner,
	# then gets one short eligibility window after the sight line opens.
	var world := Node3D.new()
	root.add_child(world)
	var test_player := Player.new()
	world.add_child(test_player)
	test_player.teleport(Vector3.ZERO)
	var sight := Vector3(8.0, 1.05, 8.0)
	test_player.look_at(Vector3(8.0, 0.0, 8.0), Vector3.UP)
	var wall := StaticBody3D.new()
	wall.position = Vector3(4.0, 1.5, 4.0)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.5, 3.0, 6.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	var gate := CornerApparitions.new()
	gate.player = test_player
	gate.suspended = false
	gate.passive = false
	world.add_child(gate)
	gate.set_physics_process(false)
	var test_cell := Vector2i(1, 1)
	var hidden_at := 100.0
	await physics_frame
	if gate._clear_line(test_player.cam.global_position, sight):
		failures.append("visibility fixture failed to occlude the target")
	gate._record_visibility(test_cell, false, hidden_at)
	if gate._freshly_exposed(test_cell,
			hidden_at + CornerApparitions.HIDDEN_MIN_SECONDS):
		failures.append("occluded corner candidate became eligible through a wall")
	world.remove_child(wall)
	wall.free()
	await physics_frame
	await process_frame
	if not gate._clear_line(test_player.cam.global_position, sight):
		failures.append("visibility fixture remained blocked after wall removal")
	var exposed_at := hidden_at + CornerApparitions.HIDDEN_MIN_SECONDS + 0.01
	gate._record_visibility(test_cell, true, exposed_at)
	if not gate._freshly_exposed(test_cell, exposed_at):
		failures.append("corner candidate did not become eligible when revealed")
	if gate._freshly_exposed(test_cell,
			exposed_at + CornerApparitions.EXPOSED_GRACE_SECONDS + 0.01):
		failures.append("corner reveal eligibility never expired")

	# Passing shadows are a separate event. They may only originate from a
	# genuine narrow corridor containing the player, never from a broad theme,
	# room, Annex intersection, or wide Annex band.
	var hallway_rows := 0
	var passer_gate := PassingShadows.new()
	for base_seed in SEEDS:
		for test_theme in WorldGen.THEMES:
			passer_gate.world_seed = WorldGen.level_seed(base_seed, test_theme)
			passer_gate.theme = test_theme
			for z in range(-12, 13):
				for x in range(-12, 13):
					var cell := Vector2i(x, z)
					var axis := passer_gate._narrow_corridor_axis(cell)
					if PassingShadows.BROAD_THEMES.has(test_theme) and axis != 0:
						failures.append("broad theme %d admitted a passing shadow" \
							% test_theme)
					if axis == 0:
						continue
					hallway_rows += 1
					if axis != 1 and axis != 2:
						failures.append("room/intersection admitted as narrow corridor")
					if test_theme == 2:
						var width := WorldGen.annex_horizontal_width(
							passer_gate.world_seed, cell.y) if axis == 1 \
							else WorldGen.annex_vertical_width(
								passer_gate.world_seed, cell.x)
						if width > PassingShadows.NARROW_ANNEX_MAX:
							failures.append("wide Annex band admitted as narrow corridor")
	if hallway_rows < 100:
		failures.append("too few narrow-hallway passing-shadow candidates: %d" \
			% hallway_rows)
	passer_gate.free()
	root.remove_child(world)
	world.free()

	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print(("corner apparition audit: PASS — 5 cutouts, %d corner paths, " \
			+ "%d narrow-hall cells, physical reveal gate, 2s hold/fade") \
			% [topology_rows, hallway_rows])
		quit()
	else:
		quit(1)
