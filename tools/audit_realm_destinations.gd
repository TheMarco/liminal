extends "res://tools/lib/audit_base.gd"
## Real destination geometry and reachable photographic reward across themes.
func run() -> void:
	var seed := 21
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed = int(arg.trim_prefix("--seed="))
	for floor_idx in range(1, DescentRun.FLOOR_COUNT):
		var visit := RealmExcursion.new()
		root.add_child(visit)
		visit.destination_theme = DescentRun.FIXED_ORDER[floor_idx]
		visit.preview = SubViewport.new()
		visit.preview.own_world_3d = true
		visit.preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
		visit.add_child(visit.preview)
		visit.pocket = ChunkManager.new()
		visit.pocket.world_seed = WorldGen.level_seed(seed, visit.destination_theme)
		visit.pocket.theme = visit.destination_theme
		visit.pocket.chunk_built.connect(visit._configure_interactions)
		visit.preview.add_child(visit.pocket)
		visit.pocket.set_process(false)
		for cell in visit.pocket._room_complete_cells(Vector2i.ZERO):
			visit.pocket._build(cell)
			await process_frame
		await physics_frame
		expect(await visit._choose_destination(), "seed=%d destination=%d has no safe landing" % [seed, floor_idx + 1])
		var forward := Basis(Vector3.UP, visit.destination_yaw) * Vector3.FORWARD
		var prize := visit._prize
		expect(not prize.is_empty(), "seed=%d destination=%d has no bounty" % [seed, floor_idx + 1])
		if not prize.is_empty():
			var delta: Vector3 = (prize.icon_origin - visit.destination_position) * Vector3(1,0,1)
			var ahead := delta.normalized().dot(forward)
			expect(ahead > 0.70, "seed=%d destination=%d bounty behind arrival (dot %.2f)" % [seed, floor_idx+1, ahead])
			print("DEST seed=%d floor=%d walk=%.1f ahead=%.2f asset=%s" % [seed, floor_idx+1, prize.walk_distance, ahead, prize.asset])
		visit.queue_free()
		await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("realm destination geometry")
