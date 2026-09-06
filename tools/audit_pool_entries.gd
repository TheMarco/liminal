extends SceneTree
## Drive the real Player up/down authored pool steps without jumping or ladders.
var failures: Array[String] = []
var directions := {}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for ws in [1029384756, 405195947, 918273645]:
		if directions.size() == 4: break
		for x in range(-8, 9):
			if directions.size() == 4: break
			for z in range(-8, 9):
				if directions.size() == 4: break
				var cell := Vector2i(x, z)
				if WorldGen.cell_style(ws, cell, 9) != WorldGen.POOL_STAIRS: continue
				var chunk := Chunk.new(ws, cell, 9)
				root.add_child(chunk)
				var ramp: CollisionShape3D
				for node in chunk.body.get_children():
					if node.has_meta("pool_entry_ramp"): ramp = node; break
				if ramp == null:
					failures.append("Stair pool has no entry ramp at %s" % cell)
					chunk.free(); continue
				var dir: int = ramp.get_meta("pool_entry_dir")
				if directions.has(dir): chunk.free(); continue
				directions[dir] = cell
				await physics_frame
				await check_entry(chunk, ramp, dir)
				chunk.free()
				await process_frame
	if directions.size() != 4: failures.append("Did not exercise all four stair directions")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures: printerr("FAIL " + failure)
	print("POOL ENTRIES %s: %d directions, real Player ascent + descent" % [
		"PASS" if failures.is_empty() else "FAIL", directions.size()])
	quit(0 if failures.is_empty() else 1)

func check_entry(chunk: Chunk, ramp: CollisionShape3D, dir: int) -> void:
	var edge: float = ramp.get_meta("pool_entry_edge")
	var along: float = ramp.get_meta("pool_entry_along")
	var outward := Vector3.RIGHT if dir == 0 else Vector3.LEFT if dir == 1 \
		else Vector3.BACK if dir == 2 else Vector3.FORWARD
	var lip := Vector3(edge, 0, along) if dir < 2 else Vector3(along, 0, edge)
	var bottom := lip - outward * 3.1 + Vector3.UP * 0.03
	var top := lip + outward * 0.75 + Vector3.UP * (Chunk.POOL_DECK_Y + 0.03)
	var player := Player.new()
	player.water_y = Chunk.POOL_WATER_Y
	player.position = bottom
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.dev_walk = true
	await physics_frame
	await walk_to(player, top, dir, "ascent")
	await walk_to(player, bottom, dir, "descent")
	player.free()
	await physics_frame

func walk_to(player: Player, target: Vector3, dir: int, leg: String) -> void:
	player.look_at(Vector3(target.x, player.position.y, target.z), Vector3.UP)
	var arrived := false
	for frame in 420:
		await physics_frame
		player._physics_process(1.0 / 60.0)
		if Vector2(player.position.x, player.position.z).distance_to(Vector2(target.x, target.z)) < 0.20:
			arrived = true
			break
	if not arrived or absf(player.position.y - target.y) > 0.16:
		failures.append("dir %d %s stopped at %s, target %s" % [dir, leg, player.position, target])
	print("ENTRY dir=%d %s position=%s" % [dir, leg, player.position])
