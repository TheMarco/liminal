extends SceneTree
## Focused deterministic policy check; the effect directors' live geometry and
## collision contracts remain in their existing runtime audits.
const Scheduler := preload("res://scripts/architectural_event_director.gd")
const Breath := preload("res://scripts/environment_breath_director.gd")
const Door := preload("res://scripts/native_doorway_director.gd")
var failures: Array[String] = []

class OpportunityBreath:
	extends Node
	var managed := false
	var active: Node3D
	var wave_requests := 0
	func try_kind_at_cell(kind: String, _cell: Vector2i) -> bool:
		if kind != "wave": return false
		wave_requests += 1
		return true

class OpportunityDoor:
	extends Node
	var managed := false
	var active: Node3D
	var visible_site := false
	var opened := false
	func try_visible_site() -> bool:
		if visible_site:
			active = Node3D.new()
			add_child(active)
		return visible_site
	func event_is_open() -> bool:
		return opened


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)


func _run() -> void:
	var scheduler := Scheduler.new()
	var cm := ChunkManager.new()
	cm.world_seed = 151151
	var player := Player.new()
	var breath := Breath.new()
	var door := Door.new()
	scheduler.configure(cm, player, breath, door, null,
		func() -> bool: return true)
	_check(breath.managed and door.managed,
		"one manager did not take ownership of both effect families")
	_check(scheduler.cooldown >= Scheduler.FIRST_DELAY.x \
		and scheduler.cooldown <= Scheduler.FIRST_DELAY.y,
		"first sighting is outside the intended arrival window")
	_check(scheduler.ordered_kinds()[0] == "breath",
		"the introductory architectural sight is not a wall breath")
	scheduler.history.assign(["breath", "breath"])
	_check(scheduler.ordered_kinds().has("breath") and scheduler.ordered_kinds()[0] != "breath",
		"repeat fallback either overrides variety or is unavailable")
	scheduler.history.clear()
	var previous := ""
	var consecutive := 0
	for i in 60:
		# Give every kind a plausible visible site in this policy simulation.
		scheduler._clock += 1000.0
		scheduler._door_ready_at = 0.0
		scheduler._floor_doors = 0
		var kind: String = scheduler.ordered_kinds()[0]
		consecutive = consecutive + 1 if kind == previous else 1
		_check(consecutive < 3, "the policy scheduled three %s sights in a row" % kind)
		previous = kind
		scheduler._commit(kind)
		_check(scheduler.cooldown >= 6.0 and scheduler.cooldown <= 14.0,
			"architecture cadence is outside the frequent exploration window")
	for kind in Scheduler.KINDS:
		_check(int(scheduler.counts.get(kind, 0)) >= 4,
			"fair selection starved %s across a long run" % kind)
	cm.descent = true
	scheduler._door_ready_at = 0.0
	scheduler._floor_doors = Scheduler.MAX_FLOOR_DOORS
	_check(not scheduler.ordered_kinds().has("doorway"),
		"doorway exceeded its per-floor limit")
	var old_count := scheduler.events_started
	var old_history := scheduler.history.duplicate()
	scheduler.configure(cm, player, breath, door, null,
		func() -> bool: return true)
	_check(scheduler.events_started == old_count \
		and scheduler.history == old_history and scheduler._floor_doors == 0,
		"floor change erased run variety or retained the floor door quota")
	# Short-lived corridor and wall opportunities can start after the quiet gap
	# even while the ordinary wall-search timer has not expired.
	var rare := Scheduler.new()
	var rare_breath := OpportunityBreath.new()
	var rare_door := OpportunityDoor.new()
	root.add_child(player)
	cm.chunks[Vector2i.ZERO] = true
	rare.configure(cm, player, rare_breath, rare_door, null,
		func() -> bool: return true)
	rare._clock = Scheduler.OPPORTUNITY_FIRST
	rare._door_ready_at = INF
	rare.cooldown = 100.0
	rare._physics_process(0.1)
	_check(rare_breath.wave_requests == 0,
		"opportunistic wave displaced the introductory ordinary search")
	rare.events_started = 1
	rare.counts["breath"] = 1
	rare._opportunity_left = 0.0
	rare._physics_process(0.1)
	_check(rare._pending == "wave" and rare_breath.wave_requests == 1,
		"eligible hallway wave waited for the ordinary timer")
	rare._pending = ""
	rare_breath.wave_requests = 0
	rare._opportunity_left = 0.0
	rare._physics_process(0.1)
	_check(rare_breath.wave_requests == 0,
		"unseen wave immediately monopolized another preparation slot")
	rare._wave_ready_at = 0.0
	rare.events_started = 2
	rare.counts["wave"] = 1
	rare._opportunity_left = 0.0
	rare._physics_process(0.1)
	_check(rare_breath.wave_requests == 0 and rare.ordered_kinds().has("wave"),
		"wave either monopolized opportunities or lost its ordinary fallback")
	rare.events_started = 0
	rare_door.visible_site = true
	rare._door_ready_at = 0.0
	rare._opportunity_left = 0.0
	rare._physics_process(0.1)
	_check(rare._pending == "doorway" and rare.events_started == 0,
		"doorway preparation spent the sighting quota before opening")
	rare_door.opened = true
	rare._physics_process(0.1)
	_check(rare.events_started == 1 and rare.history.back() == "doorway",
		"opened doorway was not recorded as a sighting")
	# A camera/combat hold must prevent starts without resetting the wait.
	rare.allowed = func() -> bool: return false
	rare.clock_allowed = func() -> bool: return true
	rare.cooldown = 4.0
	rare._physics_process(4.0)
	_check(rare.cooldown == 0.0 and rare.events_started == 1,
		"temporary safety hold froze the clock or allowed an event")
	rare.clock_allowed = func() -> bool: return false
	var held_clock := rare._clock
	rare._physics_process(10.0)
	_check(rare._clock == held_clock, "presentation hold advanced exploration time")
	cm.chunks.clear()
	rare.free()
	rare_door.free()
	rare_breath.free()
	scheduler.free()
	door.free()
	breath.free()
	player.free()
	cm.free()
	for failure in failures: print("FAIL " + failure)
	print("architectural event policy: %d events, %d failures" % [old_count, failures.size()])
	quit(0 if failures.is_empty() else 1)
