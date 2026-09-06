extends SceneTree
## Exercise the actual Player from several generated hot tubs to surrounding dry deck.

var failures: Array[String] = []
var checked := 0
const CELLS := [Vector2i.ZERO, Vector2i(-6, 5), Vector2i(-6, 0)]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var ws := WorldGen.level_seed(473692151, 9)
	for cell: Vector2i in CELLS:
		# Only one generated room occupies the physics world at a time.
		var chunk := Chunk.new(ws, cell, 9)
		root.add_child(chunk)
		var center: Variant = _jacuzzi_center(chunk)
		if center == null:
			failures.append("Jacuzzi fixture missing at %s" % cell)
		else:
			await _exercise_fixture({"center": center, "label": str(cell)})
		chunk.free()
		await physics_frame

	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		printerr("FAIL " + failure)
	print("JACUZZI MOVEMENT %s: %d directions across %d fixtures" % [
		"PASS" if failures.is_empty() else "FAIL", checked, CELLS.size()])
	quit(0 if failures.is_empty() else 1)

func _jacuzzi_center(chunk: Node) -> Variant:
	for node in chunk.get_children():
		if node.has_meta("pool_jacuzzi_basin_floor"):
			return Vector3(node.position.x, 0.0, node.position.z)
	return null

func _exercise_fixture(fixture: Dictionary) -> void:
	var center: Vector3 = fixture["center"]
	var player := Player.new()
	player.water_y = Chunk.POOL_WATER_Y
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	await physics_frame
	for i in 8:
		var direction := Vector3(sin(float(i) * TAU / 8.0), 0.0,
			cos(float(i) * TAU / 8.0))
		player.teleport(center + Vector3.UP * 0.03)
		player.velocity = Vector3.ZERO
		player.look_at(player.position + direction, Vector3.UP)
		player.dev_walk = true
		await physics_frame
		var arrived := false
		var highest := 0.0
		var climb_frames := 0
		for frame in 300:
			await physics_frame
			player._physics_process(1.0 / 60.0)
			highest = maxf(highest, player.position.y)
			if player._on_ladder:
				climb_frames += 1
			if Vector2(player.position.x - center.x, player.position.z - center.z).length() >= 1.8 \
					and player.position.y >= Chunk.POOL_DECK_Y - 0.03:
				arrived = true
				break
		checked += 1
		print("JACUZZI EXIT fixture=%s dir=%d arrived=%s position=%s max_y=%.3f climb_frames=%d" % [
			fixture["label"], i, arrived, player.position, highest, climb_frames])
		if not arrived:
			failures.append("Could not leave jacuzzi %s in direction %d" % [fixture["label"], i])
		player.dev_walk = false
		for frame in 45:
			await physics_frame
			player._physics_process(1.0 / 60.0)
		if arrived and (player._on_ladder or absf(player.position.y - Chunk.POOL_DECK_Y) > 0.05):
			failures.append("Climb assist did not release on deck, fixture %s direction %d" % [fixture["label"], i])
	player.free()
