class_name DescentRun
extends Node
## State owned only by Descent. Wander never constructs this node.

signal floor_reached(floor_idx: int)
signal attention_changed(value: float)
signal violation(kind: int)
signal blackout_changed(on: bool)
## The rules are forcing the player to be passive — standing still through a
## blackout, or still reading the floor caption. Whoever owns the figures is
## expected to stop hunting for the duration: a threat the player is not
## permitted to answer is not difficulty, it is a coin flip.
signal passive_changed(on: bool)
signal run_ended(won: bool)
signal anomaly_requested(cell: Vector2i, kind: int)
## Every actual blackout owns one transition to a complete reality generated
## and proven safe when the floor topology was created. `assistance` is private
## selection state: presentation must never reveal whether the new reality was
## chosen because the player was lost or merely because the building moved.
signal blackout_mutation_requested(proposal: TopologyDelta, assistance: bool)
## The called car finished its descent. Whoever owns the objective chunk opens
## the doors; the wait itself is run state so it survives the target room
## streaming out from under a player who walked off during it.
signal lift_arrived()
## The called car gave up because the player left the objective room. The
## summon is a vigil, not an errand: walking away abandons it.
signal lift_cancelled()
## 0..1 — how precisely the thing in the dark has located a player who moved
## during a blackout. Presentation only; at 1.0 `blackout_ambush` fires.
signal blackout_locate_changed(value: float)
## A moving player was found before the power came back.
signal blackout_ambush()
## Optional recordings share one no-repeat cycle across deaths and launches.
## Main mirrors these two events into the persistent Descent checkpoint.
signal short_tape_claimed(path: String)
signal short_tape_cycle_restarted()
## Ordered prologue recordings advance only when playback reaches its end.
signal beginning_tape_completed(completed_count: int)

enum Rule { BLACKOUT_MOVE }

## Descent is a story, so its macro-order never changes. The world seed still
## changes the rooms, route, props and events within every floor.
const FIXED_ORDER: Array[int] = [0, 7, 1, 4, 6, 8, 5, 9, 2, 10, 11]
const FLOOR_COUNT := 11
const THEME_NAMES := {
	0: "the casino", 1: "the office", 2: "the Annex", 4: "the airport",
	5: "the asylum", 6: "the school", 7: "the mall", 8: "the prison",
	9: "the Poolrooms", 10: "the Monolith", 11: "the Upside Down",
}
const ARRIVAL_GRACE := 8.0
const FLOOR_PRESSURE := [0.0, 0.07, 0.14, 0.21, 0.28,
	0.35, 0.42, 0.49, 0.56, 0.63, 0.70]
## How quickly a moving player is located during a blackout, and how slowly
## that certainty fades while they hold still. Roughly 3.3 cumulative seconds
## of movement is fatal; freezing buys time but does not erase the mistake.
const BLACKOUT_LOCATE_RATE := 0.30
const BLACKOUT_LOCATE_DECAY := 0.04
## Moving through a blackout with the torch lit is worse than moving dark.
## Strictly a multiplier on MOVEMENT: a player standing still with the beam up
## is never located, because the caption promises the torch still works and a
## lit torch is the ward that holds a looming figure at arm's length.
const BLACKOUT_TORCH_LOCATE := 1.5
## Attention cost of holding sprint. Running is legal and loud — it is not a
## rule break, it is feeding the building, and every interval that feeds on
## threat shortens for it.
const SPRINT_ATTENTION_RATE := 0.012
const MERCY_STALL_SECONDS := 50.0
const MERCY_MIN_VISITED := 6
## How long the car takes to reach you after the call. This is the only part
## of a floor that is deliberately dead time, and the most dangerous: the
## wait is scored by figures, and every second of it is spent defending the
## room the player is not allowed to leave without losing the car.
const LIFT_WAIT_FIRST := 14.0
const LIFT_WAIT_LAST := 34.0
## Two authored breaks in the ramp, because eleven identical vigils teach the
## rhythm and then bore it: on one floor the car is already there, and on one
## it comes from much further down than it should.
const LIFT_WAIT_INSTANT_FLOOR := 4  # the school
const LIFT_WAIT_LONG_FLOOR := 6     # the asylum

## What a floor's theme does to pacing knobs that already exist. Multipliers
## on the baseline; a theme missing from the table is 1.0 across the board.
## This is authoring, not difficulty scaling: the prison's power fails often
## and briefly, the Monolith is slow, sparse and heavy.
const THEME_MODS := {
	8: {"blackout_due": 0.70, "blackout_len": 0.80},              # the prison
	10: {"blackout_due": 1.15, "blackout_len": 1.10,
		"grace": 1.35, "figures": 1.35},                          # the Monolith
}

var floor_idx := 0
var attention := 0.0
var violations := 0
var elapsed := 0.0
var blackout := false
var suspended := true
var ended := false
var arrival_grace := 0.0
var lift_called := false
var lift_open := false
var lift_wait_left := 0.0
## Set once the player has stepped out of the car they arrived in. From then on
## that car rebuilds shut and dead.
var arrival_used := false
## Set when the floor's tape has played to its end. The lift refuses a player
## who has not watched it.
var tape_watched := false
## True while the ritual television holds the player's view. The rules go
## passive: a moment the game demands cannot also be a moment it punishes.
var watching := false
## The objective cell, mirrored in by whoever built the route. Sentinel means
## no route yet, so nothing can be cancelled against it.
var target_cell := Vector2i(1 << 30, 1 << 30)
## One-way ratchet: how far the next floor has already crept into this one.
## Raised by the owner as the player nears the lift; never lowered mid-floor.
var bleed := 0.0
## Time walked on this floor alone.
var floor_elapsed := 0.0

## The run's one dead charging station has already sprung its collapse. Never
## reset by prepare_floor: a trap the player has seen through stays sprung
## across deaths on the same building.
var broken_station_tried := false

var visited := {}
var anomalies := {}
var player: Player
var horror_director: HorrorDirector
var world_seed := 1
var pinned_attention := -1.0
var route: DescentRoute
var mercy_armed := false
var pending_blackout_mutation: TopologyDelta
## Generated states prove structural safety. Main supplies the live half of the
## preflight because only the scene knows whether an actor or interaction is
## occupying a room whose geometry would be swapped.
var blackout_mutation_validator: Callable

var _cell := Vector2i.ZERO
var _pending_cell := Vector2i.ZERO
var _blackout_grace := 0.0
var _blackout_cost := 0.0
var _blackout_episode := false
var _blackout_due := 0.0
var _blackout_left := 0.0
var _blackout_locate := 0.0
var _ambushed := false
var _passive := false
var _rng := RandomNumberGenerator.new()
var _order: Array[int] = []
## One no-replacement recording deal spans the whole Descent session. Keys are
## stable setup identities, so a streamed-out television rebuilds with the same
## tape, while a new television cannot repeat it before the library cycles.
var _tape_assignments := {}
var _tape_completed := {}
var _short_tape_deck: Array[String] = []
var _short_tape_cycle := 0
var _tape_seed := -1
var _last_short_tape := ""
var _short_tape_exclusions: Array[String] = []
var _completed_beginning_tapes := 0
var _best_route_distance := -1
var _route_stall_time := 0.0


## Kept seed-shaped for callers and audits, but intentionally seed-independent.
static func order_for(_ws: int) -> Array[int]:
	return FIXED_ORDER.duplicate()


func order() -> Array[int]:
	if _order.is_empty():
		_order = order_for(world_seed)
	return _order


func theme() -> int:
	return order()[floor_idx]


func floor_name(idx: int = -1) -> String:
	return THEME_NAMES[order()[idx if idx >= 0 else floor_idx]]


func is_last_floor() -> bool:
	return floor_idx >= FLOOR_COUNT - 1


func floor_progress() -> float:
	return float(floor_idx) / float(FLOOR_COUNT - 1)


## Mistakes raise attention; simply going deeper raises pressure. Keeping the
## two separate lets a careful player recover without making late floors feel
## as harmless as the casino.
func threat() -> float:
	return clampf(attention + float(FLOOR_PRESSURE[floor_idx]), 0.0, 1.0)


func _theme_mod(key: String) -> float:
	var mods: Dictionary = THEME_MODS.get(theme(), {})
	return float(mods.get(key, 1.0))


## Read by main on every floor switch and multiplied into the figure
## manager's spawn interval, so a theme can be sparse without touching the
## threat curve.
func figure_interval_scale() -> float:
	return _theme_mod("figures")


func prepare_floor() -> void:
	visited.clear()
	anomalies.clear()
	if blackout:
		blackout = false
		blackout_changed.emit(false)
	arrival_grace = ARRIVAL_GRACE
	suspended = true
	lift_called = false
	lift_open = false
	lift_wait_left = 0.0
	arrival_used = false
	tape_watched = false
	watching = false
	target_cell = Vector2i(1 << 30, 1 << 30)
	bleed = 0.0
	floor_elapsed = 0.0
	_cell = Vector2i.ZERO
	_pending_cell = Vector2i.ZERO
	_blackout_grace = 0.0
	_blackout_cost = 0.0
	_blackout_episode = false
	_blackout_locate = 0.0
	_ambushed = false
	route = null
	mercy_armed = false
	pending_blackout_mutation = null
	_best_route_distance = -1
	_route_stall_time = 0.0
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


## Static so the objective chunk can present the wait without holding a
## reference to run state it must not be able to mutate.
static func lift_wait_for(p_floor_idx: int) -> float:
	# The school's car answers at once — one press, doors almost immediately.
	# The break in the pattern is the point; by floor five the wait is learned.
	if p_floor_idx == LIFT_WAIT_INSTANT_FLOOR:
		return 1.0
	var p := clampf(float(p_floor_idx) / float(FLOOR_COUNT - 1), 0.0, 1.0)
	var wait := lerpf(LIFT_WAIT_FIRST, LIFT_WAIT_LAST, p)
	# The asylum's takes roughly twice what the ramp says it should.
	if p_floor_idx == LIFT_WAIT_LONG_FLOOR:
		wait *= 2.0
	return wait


func lift_wait_seconds() -> float:
	return lift_wait_for(floor_idx)


## Pressing the plate is a commitment, not a teleport. The car is somewhere
## above and it takes as long as it takes.
func call_lift() -> void:
	if ended or lift_called or lift_open:
		return
	lift_called = true
	lift_wait_left = lift_wait_seconds()


## Walking out on the wait abandons it. The car is honest, but only to a
## player who stands their ground for it.
func cancel_lift() -> void:
	if ended or not lift_called or lift_open:
		return
	lift_called = false
	lift_wait_left = 0.0
	lift_cancelled.emit()


func mark_tape_watched() -> void:
	tape_watched = true


func tape_for_setup(key: String, long_form := false) -> String:
	if _tape_assignments.has(key):
		var assigned := str(_tape_assignments[key])
		var beginning_idx := VhsTapeLibrary.beginning_index(assigned)
		# Another television may have completed this chapter after this setup
		# claimed it and was interrupted. Retire that stale assignment so the
		# rebuilt/retried VCR receives the chapter currently owed.
		if long_form or beginning_idx < 0 \
				or beginning_idx >= _completed_beginning_tapes \
				or setup_tape_completed(key):
			return assigned
		_tape_assignments.erase(key)
	var tape := ""
	if long_form:
		# The final floor has no ritual set; floors 0..9 map one-to-one to the
		# ten authored long-form chapters once that library is complete.
		tape = VhsTapeLibrary.objective_chapter(floor_idx)
	else:
		var beginnings := VhsTapeLibrary.beginning_paths()
		if _completed_beginning_tapes < beginnings.size():
			tape = beginnings[_completed_beginning_tapes]
		else:
			_ensure_tape_deck()
			if _short_tape_deck.is_empty():
				_refill_short_tape_deck()
			if not _short_tape_deck.is_empty():
				tape = _short_tape_deck.pop_back()
				_last_short_tape = tape
	if tape.is_empty():
		return ""
	_tape_assignments[key] = tape
	if not long_form and VhsTapeLibrary.random_paths().has(tape) \
			and not _short_tape_exclusions.has(tape):
		_short_tape_exclusions.append(tape)
		short_tape_claimed.emit(tape)
	return tape


func mark_setup_tape_completed(key: String) -> void:
	if setup_tape_completed(key):
		return
	_tape_completed[key] = true
	var tape := str(_tape_assignments.get(key, ""))
	var beginning_idx := VhsTapeLibrary.beginning_index(tape)
	if beginning_idx != _completed_beginning_tapes:
		return
	_completed_beginning_tapes += 1
	_discard_stale_beginning_assignments(key)
	beginning_tape_completed.emit(_completed_beginning_tapes)


func setup_tape_completed(key: String) -> bool:
	return bool(_tape_completed.get(key, false))


func completed_beginning_count() -> int:
	return _completed_beginning_tapes


## Restore the current optional-video cycle before any set claims a tape. Only
## the already-seen paths are persisted; the remaining deal is regenerated
## deterministically and filtered, which preserves the no-repeat promise.
func restore_short_tape_cycle(paths: Array[String], completed_beginnings := 0) -> void:
	_short_tape_exclusions.clear()
	var random_library := VhsTapeLibrary.random_paths()
	for path in paths:
		if random_library.has(path) and not _short_tape_exclusions.has(path):
			_short_tape_exclusions.append(path)
	_completed_beginning_tapes = clampi(completed_beginnings, 0,
		VhsTapeLibrary.beginning_paths().size())
	_short_tape_deck.clear()
	_tape_seed = -1


func _ensure_tape_deck() -> void:
	if _tape_seed == world_seed:
		return
	if _tape_seed != -1:
		_short_tape_exclusions.clear()
		_tape_assignments.clear()
		_tape_completed.clear()
	_tape_seed = world_seed
	_short_tape_deck.clear()
	_short_tape_cycle = 0
	_last_short_tape = ""
	_refill_short_tape_deck()


func _refill_short_tape_deck() -> void:
	var library := VhsTapeLibrary.random_paths()
	var deck := VhsTapeLibrary.shuffled_random(world_seed, _short_tape_cycle)
	for path in _short_tape_exclusions:
		deck.erase(path)
	# Every short has now played. Repetition becomes legal only at this point,
	# and the persistent cycle is cleared at exactly the same boundary.
	if deck.is_empty() and not library.is_empty() \
			and not _short_tape_exclusions.is_empty():
		_short_tape_exclusions.clear()
		short_tape_cycle_restarted.emit()
		deck = VhsTapeLibrary.shuffled_random(world_seed, _short_tape_cycle)
	# The first draw of a new cycle is pop_back(). Do not put the previous
	# cycle's last recording immediately back in the machine when alternatives
	# exist, even though repetition is now legal.
	if deck.size() > 1 and deck[-1] == _last_short_tape:
		var held: String = deck[-1]
		deck[-1] = deck[0]
		deck[0] = held
	_short_tape_deck = deck
	_short_tape_cycle += 1


func _discard_stale_beginning_assignments(completed_key: String) -> void:
	for key in _tape_assignments.keys():
		if str(key) == completed_key or setup_tape_completed(str(key)):
			continue
		if VhsTapeLibrary.beginning_index(str(_tape_assignments[key])) >= 0:
			_tape_assignments.erase(key)


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
	_update_passive()
	if ended or suspended or player == null or not player.is_inside_tree():
		return
	# Held by the same gate as the rules: a paused run must not have a car
	# quietly arriving behind the confirmation dialog.
	if lift_called and not lift_open:
		lift_wait_left = maxf(0.0, lift_wait_left - dt)
		if lift_wait_left <= 0.0:
			lift_open = true
			lift_arrived.emit()
	elapsed += dt
	floor_elapsed += dt
	if pinned_attention >= 0.0:
		attention = pinned_attention
	if arrival_grace > 0.0:
		arrival_grace = maxf(0.0, arrival_grace - dt)
		_track_cell()
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var charged := false
	_track_cell()
	if not blackout and not watching and not lift_called:
		_track_route_stall(dt, speed)
	if lift_called and not lift_open \
			and target_cell.x != (1 << 30) and _cell != target_cell:
		cancel_lift()
	# Sprint is legal, and it costs exactly what it sounds like it should.
	# Not charged during a blackout: movement is already the crime there.
	if speed > 4.2 and not blackout and pinned_attention < 0.0:
		_set_attention(attention + dt * SPRINT_ATTENTION_RATE)
		charged = true
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
			# Moving with the torch up is the worst of both: the beam is a
			# beacon to whatever is locating you. Kill the light to run.
			var locate_rate := BLACKOUT_LOCATE_RATE
			if player.flashlight != null and player.flashlight.visible:
				locate_rate *= BLACKOUT_TORCH_LOCATE
			_blackout_locate = minf(1.0,
				_blackout_locate + dt * locate_rate)
			blackout_locate_changed.emit(_blackout_locate)
			if _blackout_locate >= 1.0 and not _ambushed:
				_ambushed = true
				blackout_ambush.emit()
		elif speed <= 0.3:
			_blackout_episode = false
			if _blackout_locate > 0.0:
				_blackout_locate = maxf(0.0,
					_blackout_locate - dt * BLACKOUT_LOCATE_DECAY)
				blackout_locate_changed.emit(_blackout_locate)
		if _blackout_left <= 0.0:
			_end_blackout()
	else:
		# The timer is held while the lift is on its way or a recording owns the
		# player's view. The summon wait is scored by figures, never by a blackout.
		if not (lift_called and not lift_open) and not watching:
			_blackout_due -= dt
			if _blackout_due <= 0.0:
				_begin_blackout()
				charged = true

	if not charged and pinned_attention < 0.0 and attention > 0.0:
		var recovery := lerpf(0.0025, 0.0016, floor_progress())
		_set_attention(attention - dt * recovery)
	elif pinned_attention >= 0.0 and not is_equal_approx(attention, pinned_attention):
		_set_attention(pinned_attention)


## Blackout or arrival caption: the player is not free to act, so nothing
## should be closing on them. Recomputed every frame and emitted on change.
func _update_passive() -> void:
	var now := not ended and not suspended \
		and (blackout or arrival_grace > 0.0 or watching)
	if now == _passive:
		return
	_passive = now
	passive_changed.emit(now)


func rules_force_passive() -> bool:
	return _passive


func _track_cell() -> void:
	var now := _player_cell()
	if now != _pending_cell:
		var old := _cell
		_pending_cell = now
		if old != now:
			_maybe_anomaly(old)
	if now == _cell or not _inside_cell(now, 1.0):
		return
	_cell = now
	visited[now] = true


func set_route(value: DescentRoute) -> void:
	route = value
	_best_route_distance = -1
	_route_stall_time = 0.0
	mercy_armed = false


## Use graph progress, not the straight-line HUD number. A correct dogleg can
## move away from the lift in metres while still advancing through the maze.
func _track_route_stall(dt: float, speed: float) -> void:
	if route == null or not route.contains(_cell):
		return
	var distance := route.distance_from_target(_cell)
	if distance < 0:
		return
	if _best_route_distance < 0 or distance < _best_route_distance:
		_best_route_distance = distance
		_route_stall_time = 0.0
		mercy_armed = false
		return
	if speed > 0.3:
		_route_stall_time += dt
	if not mercy_armed and _route_stall_time >= MERCY_STALL_SECONDS \
			and visited.size() >= MERCY_MIN_VISITED:
		mercy_armed = true
		# Once frustration is proven, do not make the player wait another two
		# minutes for the architecture to act.
		if not blackout and _blackout_due > 0.0:
			_blackout_due = minf(_blackout_due, 7.0)


func mark_helpful_mutation_created() -> void:
	mercy_armed = false
	_route_stall_time = 0.0
	_best_route_distance = route.distance_from_target(_cell) \
		if route != null else -1


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
	return Vector2i(floori(player.global_position.x / WorldGen.CELL_SIZE),
		floori(player.global_position.z / WorldGen.CELL_SIZE))


func _inside_cell(at: Vector2i, margin: float) -> bool:
	var lx := player.global_position.x - float(at.x) * WorldGen.CELL_SIZE
	var lz := player.global_position.z - float(at.y) * WorldGen.CELL_SIZE
	return lx >= margin and lx <= WorldGen.CELL_SIZE - margin \
		and lz >= margin and lz <= WorldGen.CELL_SIZE - margin


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
	_blackout_due = _rng.randf_range(lo, hi) * _theme_mod("blackout_due")


func _begin_blackout() -> void:
	if blackout:
		return
	# A blackout without a prevalidated reality transition is not allowed to
	# start. If no generated state's delta is near explored space, quietly retry
	# after the player moves instead of inventing geometry at runtime.
	if route == null or route.topology == null:
		_blackout_due = 6.0
		return
	var proposal := route.topology.find_transition(
		route, _cell, visited, mercy_armed)
	if proposal == null or proposal.is_empty():
		_blackout_due = 6.0
		return
	if blackout_mutation_validator.is_valid() \
			and not bool(blackout_mutation_validator.call(proposal)):
		_blackout_due = 3.0
		return
	# The doorway is valid, but another authored beat may still own the moment.
	# Retry shortly without spending or replacing the normal blackout schedule.
	if horror_director != null and not horror_director.try_start_blackout():
		_blackout_due = 4.0
		return
	pending_blackout_mutation = proposal
	var assistance := mercy_armed and proposal.assistance
	blackout = true
	_blackout_left = _rng.randf_range(
		lerpf(5.0, 6.5, floor_progress()),
		lerpf(8.0, 9.5, floor_progress())) * _theme_mod("blackout_len")
	# A generous beat to actually stop: charging a player who was mid-stride
	# when the lights died taught nothing except that the rule is unfair.
	_blackout_grace = lerpf(2.6, 1.6, floor_progress()) * _theme_mod("grace")
	_blackout_cost = 0.0
	_blackout_episode = false
	_blackout_locate = 0.0
	_ambushed = false
	blackout_changed.emit(true)
	blackout_mutation_requested.emit(proposal, assistance)
	# Recompute now rather than at the top of the next frame: for that one frame
	# the lights would be out with the figures still free to close.
	_update_passive()


func _end_blackout() -> void:
	if not blackout:
		return
	blackout = false
	if horror_director != null:
		horror_director.end_blackout()
	_blackout_grace = 0.0
	_blackout_cost = 0.0
	_blackout_episode = false
	if _blackout_locate > 0.0:
		_blackout_locate = 0.0
		blackout_locate_changed.emit(0.0)
	# Finalize secondary anomalies while the room is still dark. The new reality
	# was installed at blackout onset so every route consumer and streamed room
	# agrees before restored light exposes the transition.
	_post_blackout_changes()
	blackout_changed.emit(false)
	pending_blackout_mutation = null
	_update_passive()
	_schedule_blackout()
	if mercy_armed:
		_blackout_due = minf(_blackout_due, 7.0)


## The topology/furniture transition is the guaranteed visible change. Older
## dead-light and waiting-figure anomalies remain optional secondary unease.
func _post_blackout_changes() -> void:
	if player == null or ended:
		return
	var candidates: Array[Vector2i] = []
	for key in visited:
		var at: Vector2i = key
		if at == _cell or at == Vector2i.ZERO or at == target_cell \
				or anomalies.has(at):
			continue
		var span := (at - _cell).abs()
		if maxi(span.x, span.y) <= 3:
			candidates.append(at)
	if candidates.is_empty():
		return
	var count := mini(candidates.size(), 1 + (1 if _rng.randf() < 0.4 else 0))
	for i in count:
		var pick := candidates[_rng.randi_range(0, candidates.size() - 1)]
		candidates.erase(pick)
		# Furniture now belongs to prevalidated realities. Secondary anomalies
		# are restricted to dead fixtures and rare waiting figures.
		var roll := _rng.randf()
		var kind := 0
		if roll < 0.18:
			kind = 1
		anomalies[pick] = kind
		anomaly_requested.emit(pick, kind)
		if candidates.is_empty():
			break
