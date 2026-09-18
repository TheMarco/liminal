extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(60.0, true).timeout.connect(func():
		push_error("BOUNTY LOSS AUDIT TIMEOUT")
		quit(1))
	for caught in [false, true]:
		var game: Node3D = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		while game.run == null:
			await process_frame
		var save_path := "/tmp/liminal_audit_bounty_loss_%s.cfg" % ("caught" if caught else "escaped")
		var progress := DescentProgress.new(save_path)
		progress.clear_from_disk()
		progress.start_new(game.world_seed)
		progress.reach_floor(game.world_seed, game.run.floor_idx)
		progress.mark_realm_visit_used(3 if game.run.floor_idx != 3 else 4)
		game._descent_progress = progress
		game._progress_enabled = true
		var visit: RealmExcursion = game._realm_visit
		while visit.phase == RealmExcursion.Phase.PREPARING:
			await process_frame
		assert(visit.phase == RealmExcursion.Phase.WAITING and is_instance_valid(visit.bounty))
		var source_floor: int = game.run.floor_idx
		game.run.resume_rules(0.0)
		for anomaly in game._photo_director._live_doors.values():
			if anomaly.id == visit.seal.photo_id:
				game._photo_director.mark_documented(anomaly.id)
				anomaly.resolve()
				break
		await visit.enter()
		assert(visit.phase == RealmExcursion.Phase.VISITING)
		assert(game._realm_visit_used(source_floor) and progress.realm_visit_used(source_floor), "entry did not consume current floor")
		assert(progress.realm_visit_used(3 if source_floor != 3 else 4), "entry cleared another floor")
		visit.set_process(false)
		visit.threats.suspended = true
		var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
		game._photo_album_store.configure(game.world_seed, false)
		assert(game._photo_album_store.add_photo(image, {"anomaly_ids": [visit.bounty_id]}) == OK)
		visit.bounty.resolve()
		assert(visit.bounty_captured and not game.player.emergency_flash_held)
		visit.elapsed = 12.0
		await visit.collapse(caught)
		assert(not game.player.emergency_flash_held and not game._flash_icon.held)
		assert("FLASH LOST" in game._photo_album_store.entries.back().flash_status)
		assert(not game.run.ended, "realm failure ended the source run")
		assert(game._realm_visit_used(source_floor), "realm failure restored a spent preview")
		var reloaded := DescentProgress.new(save_path)
		assert(reloaded.realm_visit_used(source_floor), "spent preview returned after reload")
		assert(reloaded.realm_visit_used(3 if source_floor != 3 else 4), "failure cleared another floor")
		progress.clear_from_disk()
		game.free()
		await process_frame
	print("REALM BOUNTY LOSS PASS: early/caught returns lose the reward, keep the run, and stay spent")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
