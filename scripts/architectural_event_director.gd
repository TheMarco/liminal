class_name ArchitecturalEventDirector
extends Node
## One cadence and memory for the five architectural sights. Effect directors
## still own geometry, visibility, collision, audio and their final safety gate.

const KINDS := ["breath", "travel", "ceiling", "wave", "doorway"]
const WEIGHTS := {"breath": 0.31, "travel": 0.19, "ceiling": 0.19,
	"wave": 0.18, "doorway": 0.13}
const FIRST_DELAY := Vector2(9.0, 13.0)
const DOOR_FIRST_DELAY := Vector2(30.0, 45.0)
const DOOR_REPEAT_DELAY := Vector2(75.0, 105.0)
const MAX_FLOOR_DOORS := 6
const SEARCH_RETRY := 0.75
const OPPORTUNITY_POLL := 0.5
const OPPORTUNITY_FIRST := 12.0
const OPPORTUNITY_GAP := 24.0
const WAVE_ATTEMPT_GAP := 35.0

var manager: ChunkManager
var player: Player
var breathing: Node
var doorways: Node
var pacing: HorrorDirector
var allowed: Callable
var clock_allowed: Callable
var events_started := 0
var history: Array[String] = []
var counts := {}
var cooldown := 0.0
var _clock := 0.0
var _last_event_at := -INF
var _door_ready_at := 0.0
var _floor_doors := 0
var _rng := RandomNumberGenerator.new()
var _configured := false
var _searching := false
var _order: Array[String] = []
var _kind := ""
var _cells: Array[Vector2i] = []
var _pending := ""
var _opportunity_left := 0.0
var _wave_ready_at := 0.0


func configure(cm: ChunkManager, actor: Player, breath_director: Node,
		door_director: Node, horror: HorrorDirector, gate: Callable,
		cadence_gate := Callable()) -> void:
	manager = cm
	player = actor
	breathing = breath_director
	doorways = door_director
	pacing = horror
	allowed = gate
	clock_allowed = cadence_gate if cadence_gate.is_valid() else gate
	breathing.managed = true
	doorways.managed = true
	_floor_doors = 0
	_reset_search()
	_pending = ""
	_opportunity_left = 0.0
	if not _configured:
		_rng.seed = cm.world_seed ^ 0x61726368
		_door_ready_at = _rng.randf_range(DOOR_FIRST_DELAY.x,
			DOOR_FIRST_DELAY.y)
		_configured = true
	# A floor change does not reset variety or make two sightings consecutive.
	cooldown = maxf(_rng.randf_range(FIRST_DELAY.x, FIRST_DELAY.y),
		OPPORTUNITY_GAP - (_clock - _last_event_at))


func _physics_process(dt: float) -> void:
	if not _configured or not is_instance_valid(manager) \
			or not is_instance_valid(player) \
			or not is_instance_valid(breathing) \
			or not is_instance_valid(doorways): return
	# Exploration pays down the wait even while the camera or a threat owns
	# the screen. The independent safety gate still controls every start.
	if clock_allowed.is_valid() and clock_allowed.call():
		_clock += dt
		cooldown = maxf(0.0, cooldown - dt)
	if not allowed.is_valid() or not allowed.call():
		_reset_search()
		return
	if not _pending.is_empty():
		# Preparation is not a sighting. A cancelled wave or wall receives a
		# short retry rather than spending the full event cooldown and quota.
		if _pending == "doorway":
			if not is_instance_valid(doorways.active):
				_pending = ""
				cooldown = SEARCH_RETRY
				_opportunity_left = SEARCH_RETRY
			elif doorways.event_is_open():
				_pending = ""
				_commit("doorway")
		elif breathing.event_was_seen():
			var seen := _pending
			_pending = ""
			_commit(seen)
		elif not is_instance_valid(breathing.active):
			_pending = ""
			cooldown = SEARCH_RETRY
			_opportunity_left = SEARCH_RETRY
		return
	if is_instance_valid(breathing.active) or is_instance_valid(doorways.active):
		return
	# A rare site may be traversed in only a few seconds. Check it while the
	# player is actually there, independently of the broader wall-search timer.
	var opportunity_ready := _clock >= OPPORTUNITY_FIRST if events_started == 0 \
		else _clock - _last_event_at >= OPPORTUNITY_GAP
	if opportunity_ready:
		_opportunity_left -= dt
		if _opportunity_left <= 0.0:
			_opportunity_left = OPPORTUNITY_POLL
			if _try_rare_opportunity(): return
	if cooldown > 0.0: return
	if not _searching:
		_order = ordered_kinds()
		_searching = true
	if _kind.is_empty():
		if _order.is_empty():
			_reset_search()
			cooldown = SEARCH_RETRY
			return
		_kind = _order.pop_front()
		if _kind == "doorway":
			if doorways.try_visible_site():
				_pending = "doorway"
				_reset_search()
			else:
				_kind = ""
			return
		_cells = _nearby_cells()
	if _cells.is_empty():
		_kind = ""
		return
	# One room per physics tick, never a whole-world search in one frame.
	var cell: Vector2i = _cells.pop_front()
	if _kind == "wave" and _clock < _wave_ready_at:
		_kind = ""
		_cells.clear()
		return
	if breathing.try_kind_at_cell(_kind, cell):
		if _kind == "wave": _wave_ready_at = _clock + WAVE_ATTEMPT_GAP
		_pending = _kind
		_reset_search()
	elif _cells.is_empty():
		_kind = ""


func ordered_kinds() -> Array[String]:
	var ranked: Array[Dictionary] = []
	for candidate in KINDS:
		var kind: String = candidate
		if kind == "doorway" and (_clock < _door_ready_at \
				or (manager != null and manager.descent and _floor_doors >= MAX_FLOOR_DOORS)):
			continue
		var score := float(events_started) * float(WEIGHTS[kind]) \
			- float(counts.get(kind, 0)) + _rng.randf_range(-0.36, 0.36)
		# Prefer variety, but keep a repeat as a fallback when it is the only
		# safe visible effect. A hard ban can silence an entire room.
		if history.size() >= 2 and history[-1] == kind and history[-2] == kind:
			score -= 4.0
		if not history.is_empty() and history[-1] == kind:
			score -= 2.0
		elif history.size() >= 2 and history[-2] == kind:
			score -= 0.55
		if events_started == 0 and kind == "breath": score += 1.5
		ranked.append({"kind": kind, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score))
	var result: Array[String] = []
	for row in ranked: result.append(str(row.kind))
	return result


func _nearby_cells() -> Array[Vector2i]:
	var here := Vector2i(floori(player.global_position.x / ChunkManager.CELL),
		floori(player.global_position.z / ChunkManager.CELL))
	var result: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1),
			Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var cell: Vector2i = here + offset
		if manager.chunks.has(cell): result.append(cell)
	return result


func _try_rare_opportunity() -> bool:
	if _clock >= _door_ready_at \
			and (not manager.descent or _floor_doors < MAX_FLOOR_DOORS) \
			and doorways.try_visible_site():
		_pending = "doorway"
		_reset_search()
		return true
	var here := Vector2i(floori(player.global_position.x / ChunkManager.CELL),
		floori(player.global_position.z / ChunkManager.CELL))
	# Opportunistic waves must not bypass the mix on every eligible corridor
	# visit. Their long preparations otherwise starve fast visible wall beats.
	# The ordinary search still retains waves as a fallback when walls fail.
	if events_started == 0 or int(counts.get("wave", 0)) >= \
			ceili(float(events_started + 1) * float(WEIGHTS["wave"])):
		return false
	# A costly wave cancelled before it is seen must not immediately take
	# another preparation slot away from visible, fast-to-prepare wall effects.
	if _clock >= _wave_ready_at and manager.chunks.has(here) \
			and breathing.try_kind_at_cell("wave", here):
		_wave_ready_at = _clock + WAVE_ATTEMPT_GAP
		_pending = "wave"
		_reset_search()
		return true
	return false


func _commit(kind: String) -> void:
	events_started += 1
	counts[kind] = int(counts.get(kind, 0)) + 1
	history.append(kind)
	if history.size() > 2: history.pop_front()
	_last_event_at = _clock
	if kind == "doorway":
		_floor_doors += 1
		_door_ready_at = _clock + _rng.randf_range(
			DOOR_REPEAT_DELAY.x, DOOR_REPEAT_DELAY.y)
		cooldown = _rng.randf_range(30.0, 42.0)
	elif kind == "wave":
		cooldown = _rng.randf_range(28.0, 40.0)
	else:
		cooldown = _rng.randf_range(24.0, 36.0)
	print("ARCHITECTURE SEEN: %s; total %d" % [kind, events_started])
	_reset_search()


func _reset_search() -> void:
	_searching = false
	_order.clear()
	_kind = ""
	_cells.clear()
