class_name ShadowFigures
extends Node3D
## You are not alone. Figures appear where nothing was — down a corridor, at
## the edge of the frame, and above all BEHIND you: whip around and there is
## a good chance one is already standing there. Each gets a moment's grace so
## you always register it, then stalks through several doorways until it is
## destroyed, reaches you, or gives up at a safe room boundary. Ordinary floors
## stage one stalker at a time. Explicit combat spaces may opt into MAX_FIGS;
## the room-boundary retirement keeps those slots from filling permanently.

const MAX_FIGS := 3
const TURN_TRIG := 1.9      # accumulated fast-turn radians that trigger a check
const TURN_CHANCE := 0.6    # chance one is there when you whip around
# Turn spawns sit off to the side of your new facing — inside the frame but
# outside the stare cone, so they are seen before they can be stared away.
const TURN_OFF_MIN := 17.0
const TURN_OFF_MAX := 44.0
# Widest painted silhouette is a little over a metre. Reserve its full body
# volume at spawn time so a camera-facing quad cannot straddle a wall edge.
const FIGURE_CLEAR_RADIUS := 0.68
const FIGURE_CLEAR_HEIGHT := 2.55
## Encounters should read as separate threats, never as two bodies authored in
## the same spot. This applies to every runtime spawn path, including directed
## and developer encounters.
const SPAWN_SEPARATION := 4.0

# revenant, drowned, pilgrim, trailing, gaoler, reacher, drifter.
# Seven animated wraiths, weighted close to evenly — none of them is a
# fallback for the others any more, so there is no reason to favour one.
const VARIANT_W := [0.16, 0.15, 0.14, 0.13, 0.14, 0.14, 0.14]
# The two that hang rather than walk, and trail into nothing where legs should
# be, keep to the floors where something could have got in from below. Nothing
# gets into the office.
const UNDERNEATH := [ShadowFigure.TRAILING, ShadowFigure.DRIFTER]
const UNDERNEATH_THEMES := [2, 5]  # the Annex, the asylum
# The three tuned archetypes are introductions, not seasoning: each is held
# back until the Descent floor where it debuts, so the late game gains new
# behaviour to learn rather than only shorter spawn intervals. Variants
# absent from this table are eligible everywhere.
const DEBUT_FLOOR := {
	ShadowFigure.GAOLER: 3,
	ShadowFigure.REACHER: 5,
	ShadowFigure.DRIFTER: 6,
}

signal burned_away
signal seen_by_player
## A hostile figure just entered the world (spawned or adopted) — the
## recording's cue for a catastrophic frame or two.
signal spawned
signal approach_starting(figure: ShadowFigure)
## One of them closed the distance. The owning game mode decides the outcome;
## Wander keeps this manager suspended, while Descent treats contact as fatal.
signal reached_player

var player: Player
var topology: DescentTopology
var horror_director: HorrorDirector
var suspended := false:
	set(value):
		suspended = value
		_sync_suppression()
var directed_only := false
## Normal campaign encounters are single-occupancy. The realm excursion opts
## into reinforcements explicitly for its authored 1 -> 2 -> 3 escalation.
var allow_reinforcements := false
## The rules have the player pinned — a blackout they must stand still through,
## or the arrival caption. Nothing new arrives and nothing already out there
## closes the distance; the torch still works, so the player keeps an answer.
## Distinct from `suspended`, which is a hard stop for level switches.
var passive := false:
	set(value):
		passive = value
		_sync_suppression()
var interval_scale := 1.0
## Descent floor index, mirrored in by main on every level switch; gates the
## archetype debuts. The high default keeps the full roster in any context
## that never sets it (dev tools, focused audits).
var floor_idx := 99
var completed_levels := 0
var chunk_manager: ChunkManager

var _t := 0.0
var _dev := false
var _forced_left := 0.0
var _forced_tries := 0
var _forced_requires_quiet := false
var _force_at := Vector3.INF
var _force_variant := -1
var _figs: Array[ShadowFigure] = []
## Exact source of the fatal contact, retained only until the caught beat ends.
var catching_figure: ShadowFigure
var _prev_yaw := NAN
var _turn_acc := 0.0
var _turn_cd := 8.0
var _pending := 0.0
var _new_spawn_hold := 0.0
## Dev haunt settings, assigned by main from CliOptions before this enters the
## tree. Previously read straight off the command line here.
var dev_haunt := false
var dev_haunt_at := Vector3.ZERO
var dev_haunt_at_given := false
var dev_haunt_variant := -1
## Each haunted level has its signature stalker, staged by roster index: the
## office hound, the Annex trenchwalker, the airport silent visitor, the
## asylum plague surgeon, the school teacher (veiled matron) and the mall
## harlequin, the prison enforcer and the poolrooms horror girl. Between
## signature appearances the black shadow people (roster 0-3) haunt every
## level; unmapped levels see only them.
const THEME_WALKER := {1: 9, 2: 4, 4: 7, 5: 6, 6: 8, 7: 5, 8: 11, 9: 10}
const DARK_ROSTER := [0, 1, 2, 3]
## The signature stalker alternates with black shadow people; every level
## opens with its monster.
var _walker_due := true
var _dark_bag: Array[int] = []
func active_figures() -> Array[ShadowFigure]:
	var out: Array[ShadowFigure] = []
	for figure in _figs:
		if is_instance_valid(figure) and not figure.is_queued_for_deletion():
			out.append(figure)
	return out


func _can_add_figure() -> bool:
	var limit := MAX_FIGS if allow_reinforcements else 1
	return active_figures().size() < limit


func _sync_suppression() -> void:
	for figure in active_figures():
		figure.suppressed = passive or suspended


## Broadcast a published topology change to every live pursuit immediately.
## Refreshing leases after route invalidation also drops any stale next-room
## waypoint from the hostile streaming footprint.
func invalidate_navigation_for_topology_change() -> void:
	for figure in active_figures():
		figure.invalidate_navigation_for_topology_change()
	_refresh_streaming()


func _ready() -> void:
	# Figures the world places rather than the haunt timer find us through this.
	add_to_group("figure_manager")
	_t = randf_range(5.0, 13.0)
	if dev_haunt:
		_t = 1.2  # dev: first figure almost immediately
		_dev = true
	if dev_haunt_at_given:
		_force_at = dev_haunt_at
		_t = 1.2
		_dev = true
	if dev_haunt_variant >= 0:
		_force_variant = dev_haunt_variant
	ShadowFigure.prewarm_presence()
	if player != null:
		ShadowWalkerVisual.request_model(
			THEME_WALKER.get(player.level_theme, -1))


## Try to place a short-lived realm-encounter figure in a visible, clear area.
## This is an explicit encounter request; it does not alter the normal timer.
func try_realm_encounter(front_first: bool = false) -> bool:
	if suspended or passive or _new_spawn_hold > 0.0 or player == null or not player.is_inside_tree():
		return false
	if not _can_add_figure():
		return false
	var fwd := _flat_fwd()
	if fwd == Vector3.ZERO:
		return false
	for i in 32:
		var angle: float
		if front_first and i < 16:
			angle = deg_to_rad(randf_range(-50.0, 50.0))
		else:
			angle = randf_range(-PI, PI)
		var ground := _floor_at(player.global_position
			+ fwd.rotated(Vector3.UP, angle) * randf_range(7.0, 12.0))
		if ground == Vector3.INF:
			continue
		if not _figure_volume_clear(ground):
			continue
		if not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			continue
		if not _spawn_separated(ground):
			continue
		return _spawn_at(ground, true, 2.0)
	return false


## An authored encounter: something arrives shortly, behind the player when
## the room allows it. Descent calls this when the objective tape ends and
## when a dead charging station has just taken the torch. It deliberately
## skips the director's pacing gate — it IS the directed beat — but still
## respects the figure cap and the passive hold, and gives up quietly if the
## room never offers a legal spot.
func force_encounter(delay := 1.6, respect_pacing := false) -> void:
	# Random room-exit encounters queue behind a reserved visual beat. Authored
	# tape/charger encounters retain priority, including over an existing queue.
	_forced_requires_quiet = respect_pacing if _forced_left <= 0.0 \
		else _forced_requires_quiet and respect_pacing
	_forced_left = delay if _forced_left <= 0.0 else minf(_forced_left, delay)
	_forced_tries = 6


## A brief discovery beat delays fresh arrivals, preserving pending encounters
## and leaving every figure already in the world free to move and burn.
func hold_new_spawns(seconds: float) -> void:
	_new_spawn_hold = maxf(_new_spawn_hold, seconds)


func _forced_spawn() -> bool:
	if _new_spawn_hold > 0.0:
		return false
	if not _can_add_figure():
		return false
	var fwd := _flat_fwd()
	if fwd == Vector3.ZERO:
		return false
	for i in 20:
		# The rear arc first: the beat is turning round and it is there.
		# Widen to any bearing once behind has been exhausted.
		var behind := i < 12
		var off := deg_to_rad(randf_range(12.0, 58.0)) * signf(randf() - 0.5)
		var dirv := fwd.rotated(Vector3.UP, off + (PI if behind else 0.0))
		var ground := _floor_at(player.global_position
			+ dirv * randf_range(4.5, 11.0))
		if ground == Vector3.INF:
			continue
		if not _figure_volume_clear(ground):
			continue
		if not _spawn_separated(ground):
			continue
		if not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			continue
		if not _spawn_at(ground, behind, 1.2):
			continue
		if _dev:
			print("forced figure behind=%s" % behind)
		return true
	return false


## Take ownership of a figure the world placed. Reparent it out of its chunk
## so unloading its birth room cannot delete an active pursuit. It is active
## and wired exactly like a spawned one: it approaches, burns and refunds the
## torch, costs attention when seen, and ends the run on contact.
func adopt(f: ShadowFigure) -> void:
	if f == null or not is_instance_valid(f) or _figs.has(f):
		return
	f.player = player
	f.topology = topology
	f.native_doorway_plan = chunk_manager.native_doorway_plan \
		if chunk_manager != null else null
	f.completed_levels = completed_levels
	if f.is_inside_tree() and f.get_parent() != self:
		f.reparent(self, true)
	f.suppressed = passive or suspended
	f.burned_away.connect(func(): burned_away.emit())
	f.seen_by_player.connect(func(): seen_by_player.emit())
	f.reached_player.connect(_on_figure_reached.bind(f))
	f.approach_starting.connect(_on_figure_approach)
	_figs.append(f)
	_refresh_streaming()
	_sync_director_count()
	spawned.emit()
## Level switch: whatever was standing there stays behind. A temporary realm
## visit only removes the figures; its source encounter clock stays paused.
func despawn(reset_encounters := true) -> void:
	catching_figure = null
	_new_spawn_hold = 0.0
	_walker_due = true
	for f in _figs:
		if is_instance_valid(f):
			f.queue_free()
	_figs.clear()
	if is_instance_valid(chunk_manager):
		chunk_manager.set_hostile_cells([])
	_sync_director_count(false)
	# Stingers and death cries are deliberately hung on this node rather than on
	# the figure, because the figure stops existing while they are still
	# playing. That also means they outlive a floor change unless they are cut
	# here — a three-second death cry following you into the lift belongs to a
	# building you have already left.
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.queue_free()
	_prev_yaw = NAN
	if not reset_encounters:
		return
	_t = randf_range(4.0, 11.0)
	# A beat owed on this floor does not follow the player to the next one.
	_forced_left = 0.0
	_forced_tries = 0
	_forced_requires_quiet = false
	if player != null:
		ShadowWalkerVisual.request_model(
			THEME_WALKER.get(player.level_theme, -1))


func _physics_process(dt: float) -> void:
	_refresh_streaming()
	if suspended or player == null or not player.is_inside_tree():
		# Forget where the player was facing. Coming back from a pause with a
		# stale yaw turns however far they happened to turn while pinned into
		# one enormous delta, which reads as a whip-around that never happened.
		_prev_yaw = NAN
		return
	for i in range(_figs.size() - 1, -1, -1):
		if not is_instance_valid(_figs[i]):
			_figs.remove_at(i)
	_sync_director_count()
	if passive:
		_prev_yaw = NAN
		return
	if _new_spawn_hold > 0.0:
		_new_spawn_hold = maxf(0.0, _new_spawn_hold - dt)
		_prev_yaw = NAN
		return
	if directed_only:
		_prev_yaw = NAN
		return
	# The countdown to an authored encounter only runs while the player is
	# free, so a beat queued during a tape lands after control returns, not
	# under the dolly-back.
	# An authored beat remains pending behind the live stalker instead of
	# creating a pair or silently spending all of its placement retries.
	if _forced_left > 0.0 and _can_add_figure() \
			and (not _forced_requires_quiet or horror_director == null \
			or horror_director.can_start_hostile()):
		_forced_left -= dt
		if _forced_left <= 0.0:
			_forced_tries -= 1
			if not _forced_spawn() and _forced_tries > 0:
				_forced_left = 0.8
	_track_turn(dt)
	if not _can_add_figure():
		return
	_t -= dt
	if _t <= 0.0:
		_t = (randf_range(7.0, 18.0) if _try_spawn() \
			else randf_range(2.5, 6.0)) * interval_scale


func _refresh_streaming() -> void:
	if not is_instance_valid(chunk_manager):
		return
	var cells: Array[Vector2i] = []
	for figure in active_figures():
		for cell in figure.streaming_cells():
			if not cells.has(cell):
				cells.append(cell)
	chunk_manager.set_hostile_cells(cells)


func _exit_tree() -> void:
	if is_instance_valid(chunk_manager):
		chunk_manager.set_hostile_cells([])


## Whip around fast enough and it may already be there. It was following.
## It usually is. The long cooldown is only spent when one actually appears.
func _track_turn(dt: float) -> void:
	var yaw := player.rotation.y
	if is_nan(_prev_yaw):
		_prev_yaw = yaw
		return
	var dy := absf(wrapf(yaw - _prev_yaw, -PI, PI))
	_prev_yaw = yaw
	_turn_cd -= dt
	var spd := dy / maxf(dt, 0.0001)
	# A trigger fires mid-swing, so placing the figure right then puts it
	# relative to a half-finished turn — off-screen by the time you stop.
	# Wait for the turn to settle, then stand it in your new field of view.
	if _pending > 0.0:
		_pending -= dt
		if spd < 1.2 or _pending <= 0.0:
			_pending = 0.0
			_turn_cd = randf_range(10.0, 22.0) if _turn_spawn() else randf_range(2.0, 5.0)
		return
	_turn_acc = _turn_acc * exp(-dt * 3.0) + dy
	if _turn_acc <= TURN_TRIG:
		return
	_turn_acc = 0.0
	if _turn_cd > 0.0 or not _can_add_figure():
		return
	if randf() > TURN_CHANCE:
		_turn_cd = randf_range(4.0, 9.0)
		return
	_pending = 0.9  # settle window before it is standing there


func _turn_spawn() -> bool:
	if _new_spawn_hold > 0.0:
		return false
	if not _can_add_figure():
		return false
	if horror_director != null and not horror_director.can_start_hostile():
		return false
	var fwd := _flat_fwd()
	if fwd == Vector3.ZERO:
		return false
	for i in 14:
		var off := deg_to_rad(randf_range(TURN_OFF_MIN, TURN_OFF_MAX)) * signf(randf() - 0.5)
		var dirv := fwd.rotated(Vector3.UP, off)
		var ground := _floor_at(player.global_position + dirv * randf_range(6.0, 14.0))
		if ground == Vector3.INF:
			continue
		if not _figure_volume_clear(ground):
			continue
		if not _spawn_separated(ground):
			continue
		if not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			continue
		if not _spawn_at(ground, false, 1.7):
			continue
		if _dev:
			print("turn-figure at %.0f deg off centre, %.1fm away" % [rad_to_deg(_flat_fwd().angle_to((ground - player.global_position).normalized())), ground.distance_to(player.global_position)])
		return true
	return false


func _try_spawn() -> bool:
	if _new_spawn_hold > 0.0:
		return false
	if not _can_add_figure():
		return false
	if horror_director != null and not horror_director.can_start_hostile():
		return false
	if _force_at != Vector3.INF:
		if _spawn_at(_force_at, false, 3.0):
			_force_at = Vector3.INF
			return true
		return false
	var fwd := _flat_fwd()
	if fwd == Vector3.ZERO:
		return false
	for i in 14:
		var behind := randf() < 0.22
		var off := deg_to_rad(randf_range(22.0, 58.0)) * signf(randf() - 0.5)
		var dirv := fwd.rotated(Vector3.UP, off + (PI if behind else 0.0))
		var ground := _floor_at(player.global_position + dirv * randf_range(7.0, 16.0))
		if ground == Vector3.INF:
			continue
		if not _figure_volume_clear(ground):
			continue
		if not _spawn_separated(ground):
			continue
		# Every encounter starts on a route that is physically open — corridors
		# included, which the old same-room gate made impossible: a corridor
		# cell is 12m and spawns want 7-16m. Line of sight is the real test.
		if not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			continue
		if not _spawn_at(ground, behind, 0.9):
			continue
		if _dev:
			print("figure at t=%.1fs behind=%s alive=%d" % [Time.get_ticks_msec()/1000.0, behind, _figs.size()])
		return true
	if _dev:
		print("figure: no valid spot this cycle")
	return false


func _spawn_at(ground: Vector3, announce: bool, grace: float) -> bool:
	# Keep the invariant at the creation boundary too (including debug and
	# authored spawns), rather than relying on every caller remembering it.
	if not _can_add_figure() or not _spawn_separated(ground):
		return false
	if not ShadowFigure.pool_deck_clear(player, ground, FIGURE_CLEAR_RADIUS):
		return false
	var walker_model := _next_spawn_model()
	if walker_model < 0:
		return false
	var f := ShadowFigure.new()
	f.player = player
	f.topology = topology
	f.native_doorway_plan = chunk_manager.native_doorway_plan \
		if chunk_manager != null else null
	f.completed_levels = completed_levels
	f.walker_model_index = walker_model
	f.variant = _force_variant if _force_variant >= 0 else _pick_variant()
	_force_variant = -1
	f.grace = grace
	f.announce = announce or randf() < 0.3
	f.position = ground
	f.suppressed = passive or suspended
	add_child(f)
	f.burned_away.connect(func(): burned_away.emit())
	f.seen_by_player.connect(func(): seen_by_player.emit())
	f.reached_player.connect(_on_figure_reached.bind(f))
	f.approach_starting.connect(_on_figure_approach)
	_figs.append(f)
	_refresh_streaming()
	_sync_director_count()
	spawned.emit()
	if _dev:
		print("spawned variant %d at %s (player %s)" % [f.variant, ground, player.global_position])
	return true


## The level's signature stalker alternates with black shadow people, so both
## haunt every mapped level. -1 defers the spawn without consuming anything:
## an unfinished decode waits for its design rather than staging a fallback.
func _next_spawn_model() -> int:
	var theme_model: int = THEME_WALKER.get(player.level_theme, -1)
	if theme_model >= 0 and _walker_due:
		if not _walker_model_ready(theme_model):
			return -1
		_walker_due = false
		return theme_model
	if _dark_bag.is_empty():
		_refill_dark_bag()
	if not _walker_model_ready(_dark_bag.back()):
		return -1
	var selected: int = _dark_bag.pop_back()
	if not _dark_bag.is_empty():
		ShadowWalkerVisual.request_model(_dark_bag.back())
	if theme_model >= 0:
		_walker_due = true
	return selected


func _walker_model_ready(index: int) -> bool:
	return ShadowWalkerVisual.is_model_ready(index)


func _refill_dark_bag() -> void:
	_dark_bag.assign(DARK_ROSTER)
	_dark_bag.shuffle()
	ShadowWalkerVisual.request_model(_dark_bag.back())


func _spawn_separated(ground: Vector3) -> bool:
	for figure in active_figures():
		var delta := figure.global_position - ground
		delta.y = 0.0
		if delta.length_squared() < SPAWN_SEPARATION * SPAWN_SEPARATION:
			return false
	return true


func _on_figure_approach(figure: ShadowFigure) -> void:
	approach_starting.emit(figure)


func _on_figure_reached(figure: ShadowFigure) -> void:
	catching_figure = figure
	reached_player.emit()


func _sync_director_count(start_recovery := true) -> void:
	if horror_director == null:
		return
	var active := 0
	for f in _figs:
		if is_instance_valid(f):
			active += 1
	horror_director.set_hostile_count(active, start_recovery)


func _pick_variant() -> int:
	var deep := UNDERNEATH_THEMES.has(player.level_theme)
	var total := 0.0
	for i in VARIANT_W.size():
		if _variant_eligible(i, deep):
			total += VARIANT_W[i]
	var r := randf() * total
	for i in VARIANT_W.size():
		if not _variant_eligible(i, deep):
			continue
		r -= VARIANT_W[i]
		if r <= 0.0:
			return i
	return 0


func _variant_eligible(variant: int, deep: bool) -> bool:
	if not deep and UNDERNEATH.has(variant):
		return false
	return floor_idx >= int(DEBUT_FLOOR.get(variant, 0))


## Distance to the nearest live figure, or a large number when none is out
## there. The heartbeat samples this: something standing close by is a dread
## the player can hear without it having to startle them again.
func nearest_distance() -> float:
	if player == null or not player.is_inside_tree():
		return 1e9
	var best := 1e9
	for f in _figs:
		if not is_instance_valid(f):
			continue
		best = minf(best, f.global_position.distance_to(player.global_position))
	return best


## Is something the player has already seen close enough that stopping is a
## reaction rather than dawdling? The stop rule asks before it charges.
func _flat_fwd() -> Vector3:
	var fwd := -player.cam.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length() > 0.01 else Vector3.ZERO


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit["position"].distance_to(b) < 1.2


func _figure_volume_clear(ground: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = FIGURE_CLEAR_RADIUS
	shape.height = FIGURE_CLEAR_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY,
		ground + Vector3(0, FIGURE_CLEAR_HEIGHT * 0.5 + 0.04, 0))
	q.exclude = [player.get_rid()]
	q.collision_mask = 1
	return player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Distance a real walkable floor may sit off the level's ground plane. A dais
## or a shallow step is fine; a table top at 0.73m, a bed at 0.60m or the
## old retired sewer channel invert at -0.48m are not. The old probe accepted anything
## within 1.3m, which is why figures stood on furniture and sank into trenches —
## and why they read as the wrong size when they did.
const FLOOR_TOL := 0.34
const FLOOR_PIERCE := 6


## The first surface under `pos` is very often furniture. Keep dropping through
## it until the real floor turns up, so the body-volume check that follows gets
## to reject the spot properly instead of clearing the air above a table.
func _floor_at(pos: Vector3) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var pool_level := player.level_theme == 9
	var floor_y := Chunk.POOL_DRY_Y if pool_level else 0.0
	# Probe the deck even while the player is wading down on the basin floor.
	var probe := Vector3(pos.x, floor_y if pool_level else pos.y, pos.z)
	var bottom := probe + Vector3(0, -2.0, 0)
	var from := probe + Vector3(0, 2.6, 0)
	for pierce in FLOOR_PIERCE:
		var q := PhysicsRayQueryParameters3D.create(from, bottom)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return Vector3.INF
		var p: Vector3 = hit["position"]
		if hit["normal"].y >= 0.8 and absf(p.y - floor_y) <= FLOOR_TOL:
			if not ShadowFigure.pool_deck_clear(player, p, FIGURE_CLEAR_RADIUS):
				return Vector3.INF
			return p
		if p.y <= bottom.y + 0.01:
			return Vector3.INF
		from = p - Vector3(0, 0.03, 0)
	return Vector3.INF
