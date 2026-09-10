extends SceneTree
## Runtime check for the real charging station inside the temporary realm.

var game: Node3D

func _init() -> void:
	call_deferred("run_test")

func _find_station(root_node: Node) -> ChargingStation:
	for child in root_node.get_children():
		if child is ChargingStation and not (child as ChargingStation).broken:
			return child
		var nested := _find_station(child)
		if nested != null:
			return nested
	return null

func _assert_pocket_interactions(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Interactable:
			var station := child.get_parent() as ChargingStation
			if visit_phase() != RealmExcursion.Phase.VISITING:
				assert(not (child as Interactable).enabled, "preview interaction enabled")
			elif station == null or station.broken:
				assert(not (child as Interactable).enabled, "non-charger pocket interaction enabled")
		_assert_pocket_interactions(child)

func visit_phase() -> int:
	return (game._realm_visit as RealmExcursion).phase

func _press_e(player: Player) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	player._unhandled_input(event)

func _press_f(player: Player) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F
	player._unhandled_input(event)

func _check_disconnected_during_return() -> void:
	assert(visit_phase() == RealmExcursion.Phase.RETURNING, "return never began")
	assert(not game.player.is_charging(), "charging survived the beginning of return")

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(45.0).timeout.connect(func():
		push_error("Realm charging audit timed out")
		quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	var deadline := Time.get_ticks_msec() + 15000
	while visit.phase == RealmExcursion.Phase.PREPARING and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING, "realm did not prepare")
	game.run.resume_rules(0.0)
	var station := _find_station(visit.pocket)
	assert(station != null, "generated mall contains no healthy charging station")
	_assert_pocket_interactions(visit.pocket)
	var source_root: Node = game.level_root
	var source_cm: Node = game.cm
	var source_floor: int = game.run.floor_idx
	var source_objective: Vector2i = game.run.target_cell
	for anomaly in game._photo_director._live_doors.values():
		if is_instance_valid(anomaly) and anomaly.id == visit.seal.photo_id:
			game._photo_director.mark_documented(anomaly.id)
			anomaly.resolve()
			break
	assert(visit.seal.opened, "photographic doorway did not open")
	var source_evidence: Array = game._photo_director.documented_ids().duplicate()
	var source_tape_watched: bool = game.run.tape_watched
	var source_lift_called: bool = game.run.lift_called
	var source_lift_open: bool = game.run.lift_open
	await visit.enter()
	assert(visit.phase == RealmExcursion.Phase.VISITING, "realm did not enter")
	visit.set_process(false)
	visit.threats.suspended = true
	game.player.set_physics_process(false)
	_assert_pocket_interactions(visit.pocket)
	station = _find_station(visit.pocket)
	assert(station != null, "station missing after entry")
	var player: Player = game.player
	player._flash_charge = Player.FLASH_MAX * 0.2
	var front := station.global_transform.basis.z.normalized()
	player.teleport(station.global_position + front * 1.5 + Vector3.UP * 0.05)
	player.cam.look_at(station._hit.global_position)
	await physics_frame
	assert(ArrivalSafety.is_clear(game.get_world_3d(), player.global_position, [player.get_rid()]),
		"pod approach is obstructed")
	assert(ArrivalSafety.has_floor(game.get_world_3d(), player.global_position, [player.get_rid()]),
		"pod approach has no floor")
	player._scan_interaction()
	assert(player._focused == station._hit and station._hit.enabled, "station was not focusable")
	assert(player._focus_text == "E — CHARGE FLASHLIGHT", "charging prompt missing")
	var before: float = player.flashlight_charge()
	_press_e(player)
	assert(player.is_charging_at(station), "E did not start charging")
	player._update_flashlight(1.0)
	assert(player.flashlight_charge() > before, "charging did not increase battery")
	_press_e(player)
	assert(not player.is_charging(), "E did not stop charging")
	_press_e(player)
	assert(player.is_charging_at(station), "second charging session did not start")
	_press_f(player)
	assert(not player.is_charging(), "F did not stop charging")
	_press_e(player)
	assert(player.is_charging_at(station), "final charging session did not start")
	var retained: float = player.flashlight_charge()
	call_deferred("_check_disconnected_during_return")
	await visit.collapse()
	assert(not player.is_charging(), "charging session survived collapse")
	assert(player.flashlight_charge() >= retained - 0.001, "battery was lost on return")
	assert(visit.phase == RealmExcursion.Phase.SPENT and game.level_root == source_root \
		and game.cm == source_cm and game.run.floor_idx == source_floor \
		and game.run.target_cell == source_objective \
		and game.run.tape_watched == source_tape_watched \
		and game.run.lift_called == source_lift_called and game.run.lift_open == source_lift_open \
		and game._photo_director.documented_ids() == source_evidence,
		"source run state changed during realm charging")
	print("REALM CHARGING PASS: generated station disabled in preview, real E scan/start/stop, battery gain, F stop, collapse cleanup and source preservation")
	game.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
