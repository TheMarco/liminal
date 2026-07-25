class_name DescentRun
extends Node
## State owned only by Descent. Wander never constructs this node.

signal floor_reached(floor_idx: int)
signal attention_changed(value: float)
signal violation(kind: int)
signal blackout_changed(on: bool)
signal run_ended(won: bool)
signal anomaly_requested(cell: Vector2i, kind: int)

enum Rule { STARE, STOP, BACKTRACK, BLACKOUT_MOVE }

const ORDER: Array[int] = [0, 7, 1, 4, 6, 8, 5, 2]
const NAMES := [
	"the casino", "the mall", "the office", "the airport",
	"the school", "the prison", "the asylum", "the sewers",
]
const ARRIVAL_GRACE := 8.0
const FLOOR_PRESSURE := [0.0, 0.09, 0.18, 0.27, 0.36, 0.46, 0.56, 0.68]

var floor_idx := 0
var attention := 0.0
var violations := 0
var elapsed := 0.0
var blackout := false
var suspended := true
var ended := false
var arrival_grace := 0.0

var visited := {}
var departed := {}
var charged_backtracks := {}
var anomalies := {}
var player: Player
var world_seed := 1
var pinned_attention := -1.0

var _cell := Vector2i.ZERO
var _pending_cell := Vector2i.ZERO
var _stop_time := 0.0
var _stop_cost := 0.0
var _stop_episode := false
var _blackout_grace := 0.0
var _blackout_cost := 0.0
var _blackout_episode := false
var _blackout_due := 0.0
var _blackout_left := 0.0
var _rng := RandomNumberGenerator.new()


func theme() -> int:
	return ORDER[floor_idx]


func is_last_floor() -> bool:
	return floor_idx >= ORDER.size() - 1


func floor_progress() -> float:
	return float(floor_idx) / float(maxi(1, ORDER.size() - 1))


## Mistakes raise attention; simply going deeper raises pressure. Keeping the
## two separate lets a careful player recover without making late floors feel
## as harmless as the casino.
func threat() -> float:
	return clampf(attention + float(FLOOR_PRESSURE[floor_idx]), 0.0, 1.0)


func prepare_floor() -> void:
	visited.clear()
	departed.clear()
	charged_backtracks.clear()
	anomalies.clear()
	if blackout:
		blackout = false
		blackout_changed.emit(false)
	arrival_grace = ARRIVAL_GRACE
	suspended = true
	_cell = Vector2i.ZERO
	_pending_cell = Vector2i.ZERO
	_stop_time = 0.0
	_stop_cost = 0.0
	_stop_episode = false
	_blackout_grace = 0.0
	_blackout_cost = 0.0
	_blackout_episode = false
	_rng.seed = int(world_seed) ^ (floor_idx * 104729 + 0x5EED)
	_schedule_blackout()


func start_floor() -> void:
	suspended = false
	arrival_grace = ARRIVAL_GRACE
	if player != null:
		_cell = _player_cell()
		_pending_cell = _cell
		visited[_cell] = true
	floor_reached.emit(floor_idx)


func finish(won: bool) -> void:
	if ended:
		return
	ended = true
	suspended = true
	run_ended.emit(won)


func add_stare_violation() -> void:
	if suspended or ended or arrival_grace > 0.0:
		return
	_charge(Rule.STARE, 0.10, true)


func suspend_rules() -> void:
	suspended = true


func resume_rules(grace := 1.0) -> void:
	if ended:
		return
	suspended = false
	arrival_grace = maxf(arrival_grace, grace)
	if player != null:
		_cell = _player_cell()
		_pending_cell = _cell
		visited[_cell] = true


func _physics_process(dt: float) -> void:
	if ended or suspended or player == null or not player.is_inside_tree():
		return
	elapsed += dt
	if pinned_attention >= 0.0:
		attention = pinned_attention
	if arrival_grace > 0.0:
		arrival_grace = maxf(0.0, arrival_grace - dt)
		_track_cell(false)
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var charged := false
	_track_cell(true)
	if blackout:
		_blackout_left -= dt
		_blackout_grace = maxf(0.0, _blackout_grace - dt)
		if _blackout_grace <= 0.0 and speed > 0.3:
			if not _blackout_episode:
				_blackout_episode = true
				_blackout_cost = 0.06
				_charge(Rule.BLACKOUT_MOVE, 0.06, true)
				charged = true
			elif _blackout_cost < 0.20:
				var amount := minf(dt * 0.02, 0.20 - _blackout_cost)
				_blackout_cost += amount
				_charge(Rule.BLACKOUT_MOVE, amount, false)
				charged = true
		elif speed <= 0.3:
			_blackout_episode = false
		if _blackout_left <= 0.0:
			_end_blackout()
	else:
		_blackout_due -= dt
		if _blackout_due <= 0.0:
			_begin_blackout()
			charged = true
		if speed < 0.3:
			_stop_time += dt
			var stop_threshold := lerpf(6.0, 3.75, floor_progress())
			if _stop_time >= stop_threshold:
				if not _stop_episode:
					_stop_episode = true
					_stop_cost = 0.04
					_charge(Rule.STOP, 0.04, true)
					charged = true
				elif _stop_cost < 0.12:
					var amount := minf(dt * 0.01, 0.12 - _stop_cost)
					_stop_cost += amount
					_charge(Rule.STOP, amount, false)
					charged = true
		else:
			_stop_time = 0.0
			_stop_cost = 0.0
			_stop_episode = false

	if not charged and pinned_attention < 0.0 and attention > 0.0:
		var recovery := lerpf(0.0025, 0.0016, floor_progress())
		_set_attention(attention - dt * recovery)
	elif pinned_attention >= 0.0 and not is_equal_approx(attention, pinned_attention):
		_set_attention(pinned_attention)


func _track_cell(enforce: bool) -> void:
	var now := _player_cell()
	if now != _pending_cell:
		var old := _cell
		_pending_cell = now
		if old != now:
			departed[old] = true
			_maybe_anomaly(old)
	if now == _cell or not _inside_cell(now, 1.0):
		return
	_cell = now
	visited[now] = true
	if enforce and departed.has(now) and not charged_backtracks.has(now):
		charged_backtracks[now] = true
		_charge(Rule.BACKTRACK, 0.06, true)


func _maybe_anomaly(at: Vector2i) -> void:
	if anomalies.has(at) or at == Vector2i.ZERO:
		return
	var roll := WorldGen.r01(world_seed ^ (floor_idx * 65537),
		at.x, at.y, 2401)
	if roll > 0.22 + threat() * 0.35:
		return
	var kind := WorldGen.h(world_seed, at.x, at.y,
		2417 + floor_idx * 31) % 2
	anomalies[at] = kind
	anomaly_requested.emit(at, kind)


func _player_cell() -> Vector2i:
	return Vector2i(floori(player.global_position.x / 12.0),
		floori(player.global_position.z / 12.0))


func _inside_cell(at: Vector2i, margin: float) -> bool:
	var lx := player.global_position.x - float(at.x) * 12.0
	var lz := player.global_position.z - float(at.y) * 12.0
	return lx >= margin and lx <= 12.0 - margin \
		and lz >= margin and lz <= 12.0 - margin


func _charge(kind: Rule, amount: float, count_episode: bool) -> void:
	amount *= lerpf(1.0, 1.30, floor_progress())
	if amount <= 0.0 or pinned_attention >= 0.0:
		if count_episode:
			violations += 1
			violation.emit(kind)
		return
	if count_episode:
		violations += 1
		violation.emit(kind)
	_set_attention(attention + amount)


func _set_attention(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, attention):
		return
	attention = next
	if not blackout and _blackout_due > 0.0:
		_blackout_due = minf(_blackout_due,
			lerpf(150.0, 40.0, threat()))
	attention_changed.emit(attention)


func _schedule_blackout() -> void:
	var pressure := threat()
	var lo := lerpf(90.0, 25.0, pressure)
	var hi := lerpf(150.0, 40.0, pressure)
	_blackout_due = _rng.randf_range(lo, hi)


func _begin_blackout() -> void:
	if blackout:
		return
	blackout = true
	_blackout_left = _rng.randf_range(
		lerpf(5.0, 6.5, floor_progress()),
		lerpf(8.0, 9.5, floor_progress()))
	_blackout_grace = lerpf(0.75, 0.45, floor_progress())
	_blackout_cost = 0.0
	_blackout_episode = false
	_stop_time = 0.0
	_stop_episode = false
	blackout_changed.emit(true)


func _end_blackout() -> void:
	if not blackout:
		return
	blackout = false
	_blackout_grace = 0.0
	_blackout_cost = 0.0
	_blackout_episode = false
	blackout_changed.emit(false)
	_schedule_blackout()
