extends SceneTree
## Real authored slide triggers must respect entry height and world lifecycle.
var failures: Array[String] = []
var player: Player
var checks := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/authored/pool_equipment/collision.json"))
	for kind in [1, 2]:
		var chunk := Chunk.new(1029384756, Vector2i.ZERO, 9)
		root.add_child(chunk)
		for child in chunk.get_children():
			if child != chunk.body: child.free()
		for child in chunk.body.get_children(): child.free()
		chunk._scene_writer.box(Vector3(0,1.32,-5),Vector3(20,.2,10),Mats.pool_tile())
		chunk._scene_writer.box(Vector3(0,-.1,5),Vector3(20,.2,10),Mats.pool_tile())
		var prop := PoolEquipment.build(chunk._scene_writer,kind,Vector3(0,1.42,0),0)
		var config: Dictionary = data["pool_"+PoolEquipment.KINDS[kind]]
		var entry := prop.to_global(PoolEquipment._vec(config["entry"]))
		player = Player.new(); player.water_y = 1.05; root.add_child(player)
		player.set_physics_process(false); player.set_process(false)
		await physics_frame
		player.teleport(Vector3(entry.x,1.43,entry.z)); await ticks(60)
		check(not player.is_pool_sliding(), "ground beneath slide boarded kind%d" % kind)
		player.teleport(entry+Vector3(0,0,1.0)); await ticks(60)
		check(not player.is_pool_sliding(), "outside chute boarded kind%d" % kind)
		await board(entry,kind)
		# Pause normal physics on an active slide, not an already-disabled actor.
		player.set_physics_process(true)
		paused = true
		var before := player.position
		var progress := player._slide_distance
		await create_timer(.12,true).timeout
		check(player.position.is_equal_approx(before) and is_equal_approx(progress,player._slide_distance), "pause advanced ride kind%d" % kind)
		paused = false
		await physics_frame; await physics_frame
		check(player.position.distance_to(before) > .005, "resume did not advance ride kind%d" % kind)
		player.set_physics_process(false)
		player.teleport(Vector3(4,1.43,-4))
		check(not player.is_pool_sliding(), "teleport retained ride kind%d" % kind)
		before=player.position; await ticks(2)
		check(player.position.distance_to(before)<.15, "teleport snapped to old path kind%d" % kind)
		await board(entry,kind)
		player.reset_descent_resources()
		check(not player.is_pool_sliding(), "resource reset retained ride kind%d" % kind)
		await board(entry,kind)
		prop.free(); await ticks(2)
		check(not player.is_pool_sliding() and is_finite(player.position.y), "unloaded slide retained motion kind%d" % kind)
		player.free(); chunk.free(); await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures: printerr(failure)
	print("POOL SLIDE LIFECYCLE %s: %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func ticks(frames: int) -> void:
	for i in frames:
		await physics_frame
		player._physics_process(1.0/60.0)
func board(entry: Vector3, kind: int) -> void:
	player.teleport(entry+Vector3.UP*.04)
	for i in 90:
		await ticks(1)
		if player.is_pool_sliding(): break
	check(player.is_pool_sliding(), "real entry did not board kind%d" % kind)
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
