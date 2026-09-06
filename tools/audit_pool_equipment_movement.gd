extends SceneTree
## Board mounting and real slide rides: only steer to the chute entrance.
## Once boarded, release all movement and look away; momentum must do the rest.
var failures: Array[String] = []
var checked := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/authored/pool_equipment/collision.json"))
	for kind in [0, 1, 2]:
		for quarter in (1 if kind == 0 else 4):
			await ride(kind, quarter, data["pool_" + PoolEquipment.KINDS[kind]])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures: printerr(failure)
	print("EQUIPMENT MOVEMENT %s: %d rides" % ["PASS" if failures.is_empty() else "FAIL", checked])
	quit(0 if failures.is_empty() else 1)

func ride(kind: int, quarter: int, config: Dictionary) -> void:
	var chunk := Chunk.new(1029384756, Vector2i.ZERO, 9)
	root.add_child(chunk)
	for child in chunk.get_children():
		if child != chunk.body: child.free()
	for child in chunk.body.get_children(): child.free()
	chunk._scene_writer.box(Vector3(0,1.32,-5), Vector3(20,.2,10), Mats.pool_tile())
	chunk._scene_writer.box(Vector3(0,-.1,5), Vector3(20,.2,10), Mats.pool_tile())
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(20,10)
	water.mesh = plane; water.position = Vector3(0,1.05,5)
	water.material_override = Mats.pool_water(); water.add_to_group("pool_water_surfaces")
	chunk.add_child(water)
	var prop := PoolEquipment.build(chunk._scene_writer, kind, Vector3(0,1.42,0), 0)
	chunk.position = Vector3(30,0,12)
	chunk.rotation.y = quarter * PI / 2.0
	var bottom := PoolEquipment._vec(config["ladder_bottom"]) if kind != 0 else Vector3(0,0,-1.72)
	var top := PoolEquipment._vec(config["ladder_top"]) if kind != 0 else Vector3(0,.52,-1.22)
	var direction := Vector3(top.x-bottom.x, 0, top.z-bottom.z).normalized()
	var player := Player.new()
	player.position = prop.to_global(bottom - direction*.3 + Vector3.UP*.02)
	player.water_y = 1.05
	root.add_child(player)
	player.set_physics_process(false); player.set_process(false); player.dev_walk=true
	await physics_frame
	var label := "%s yaw%d" % [PoolEquipment.KINDS[kind],quarter]
	await walk(player, prop.to_global(top + direction*.1), label+" ladder", .24, 480, kind != 0)
	if kind != 0:
		if not player.is_pool_sliding():
			await walk(player, prop.to_global(PoolEquipment._vec(config["entry"])), label+" entry", .05, 180, true)
		if not player.is_pool_sliding(): failures.append(label+" did not auto-board")
		player.dev_walk = false
		player.rotate_y(1.37)
		var look_yaw := player.rotation.y
		var highest_speed := 0.0
		var peak_ride_speed := 0.0
		var ride_frames := 0
		for frame in 300:
			await physics_frame
			player._physics_process(1.0/60.0)
			if player.is_pool_sliding():
				ride_frames += 1
				peak_ride_speed = maxf(peak_ride_speed, player.velocity.length())
			highest_speed = maxf(highest_speed, player.velocity.length())
			if not player.is_pool_sliding() and player.position.y < .1: break
		if absf(player.rotation.y - look_yaw) > .001: failures.append(label+" forced camera yaw")
		if ride_frames < 10 or highest_speed < 2.0: failures.append(label+" had no automatic acceleration")
		if peak_ride_speed > 6.0: failures.append(label+" snapped along chute instead of sliding smoothly")
		print("AUTO %s frames=%d ride_speed=%.2f final_local=%s" % [label, ride_frames, peak_ride_speed, chunk.to_local(player.position)])
	else:
		await walk(player, prop.to_global(Vector3(0,.52,.82)), "board takeoff", .15, 180)
		await walk(player, chunk.to_global(Vector3(0,0,1.65)), "board splashdown", .18, 240)
		player.dev_walk = false
	for frame in 70:
		await physics_frame
		player._physics_process(1.0/60.0)
	var local := chunk.to_local(player.position)
	if absf(local.y) > .08 or local.z < .95 or local.z > 2.85:
		failures.append("%s did not slide into reserved pool landing: %s" % [label,local])
	if player.is_pool_sliding(): failures.append(label+" never released")
	if kind != 0 and (player._water_fx == null or not player._water_fx._wet):
		failures.append(label+" did not register water splashdown")
	checked += 1
	player.free(); chunk.free(); await process_frame

func walk(player: Player, target: Vector3, label: String, eps: float, frames: int, stop_on_slide := false) -> void:
	var done := false
	for i in frames:
		if stop_on_slide and player.is_pool_sliding(): done=true; break
		if Vector2(player.position.x,player.position.z).distance_to(Vector2(target.x,target.z)) < eps:
			done=true; break
		player.look_at(Vector3(target.x,player.position.y,target.z),Vector3.UP)
		await physics_frame
		player._physics_process(1.0/60.0)
	if not done: failures.append("%s stuck=%s target=%s" % [label,player.position,target])
