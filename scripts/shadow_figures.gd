class_name ShadowFigures
extends Node3D
## You are not alone. Figures appear where nothing was — down a corridor, at
## the edge of the frame, and above all BEHIND you: whip around and there is
## a good chance one is already standing there. Each gets a moment's grace so
## you always register it, then it dissolves under your gaze. They never
## approach. Up to MAX_FIGS exist at once.

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

# revenant, drowned, pilgrim, trailing, gaoler, reacher, drifter.
# Seven animated wraiths, weighted close to evenly — none of them is a
# fallback for the others any more, so there is no reason to favour one.
const VARIANT_W := [0.16, 0.15, 0.14, 0.13, 0.14, 0.14, 0.14]
# The two that hang rather than walk, and trail into nothing where legs should
# be, keep to the floors where something could have got in from below. Nothing
# gets into the office.
const UNDERNEATH := [ShadowFigure.TRAILING, ShadowFigure.DRIFTER]
const UNDERNEATH_THEMES := [2, 5]  # the sewers, the asylum

signal stared_away
signal burned_away
signal seen_by_player
## One of them closed the distance. In the endless floors this is a scare and
## nothing more; whoever owns this node decides whether a run survives it.
signal reached_player

var player: Player
var suspended := false
var interval_scale := 1.0

var _t := 0.0
var _dev := false
var _force_at := Vector3.INF
var _force_variant := -1
var _figs: Array[ShadowFigure] = []
var _prev_yaw := NAN
var _turn_acc := 0.0
var _turn_cd := 8.0
var _pending := 0.0


func _ready() -> void:
	_t = randf_range(5.0, 13.0)
	for arg in OS.get_cmdline_user_args():
		if arg == "--haunt":
			_t = 1.2  # dev: first figure almost immediately
			_dev = true
		elif arg.begins_with("--haunt-at="):
			var parts := arg.substr(11).split(",")
			if parts.size() >= 2:
				_force_at = Vector3(float(parts[0]), 0, float(parts[1]))
				_t = 1.2
				_dev = true
			if parts.size() >= 3:
				_force_variant = int(parts[2])


## Level switch or portal jump: whatever was standing there stays behind.
func despawn() -> void:
	for f in _figs:
		if is_instance_valid(f):
			f.queue_free()
	_figs.clear()
	# Stingers and death cries are deliberately hung on this node rather than on
	# the figure, because the figure stops existing while they are still
	# playing. That also means they outlive a floor change unless they are cut
	# here — a three-second death cry following you into the lift belongs to a
	# building you have already left.
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.queue_free()
	_t = randf_range(4.0, 11.0)
	_prev_yaw = NAN


func _physics_process(dt: float) -> void:
	if suspended or player == null or not player.is_inside_tree():
		return
	for i in range(_figs.size() - 1, -1, -1):
		if not is_instance_valid(_figs[i]):
			_figs.remove_at(i)
	_track_turn(dt)
	if _figs.size() >= MAX_FIGS:
		return
	_t -= dt
	if _t <= 0.0:
		_t = (randf_range(7.0, 18.0) if _try_spawn() \
			else randf_range(2.5, 6.0)) * interval_scale


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
	if _turn_cd > 0.0 or _figs.size() >= MAX_FIGS:
		return
	if randf() > TURN_CHANCE:
		_turn_cd = randf_range(4.0, 9.0)
		return
	_pending = 0.9  # settle window before it is standing there


func _turn_spawn() -> bool:
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
		if not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			continue
		_spawn_at(ground, false, 1.7)
		if _dev:
			print("turn-figure at %.0f deg off centre, %.1fm away" % [rad_to_deg(_flat_fwd().angle_to((ground - player.global_position).normalized())), ground.distance_to(player.global_position)])
		return true
	return false


func _try_spawn() -> bool:
	if _force_at != Vector3.INF:
		_spawn_at(_force_at, false, 3.0)
		_force_at = Vector3.INF
		return true
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
		# glimpsable, mostly: front spawns want a sight line
		if not behind and not _clear_line(player.cam.global_position, ground + Vector3(0, 1.4, 0)):
			if randf() < 0.55:
				continue
		_spawn_at(ground, behind, 0.9)
		if _dev:
			print("figure at t=%.1fs behind=%s alive=%d" % [Time.get_ticks_msec()/1000.0, behind, _figs.size()])
		return true
	if _dev:
		print("figure: no valid spot this cycle")
	return false


func _spawn_at(ground: Vector3, announce: bool, grace: float) -> void:
	var f := ShadowFigure.new()
	f.player = player
	f.variant = _force_variant if _force_variant >= 0 else _pick_variant()
	_force_variant = -1
	f.grace = grace
	f.announce = announce or randf() < 0.3
	f.position = ground
	add_child(f)
	f.stared_away.connect(func(): stared_away.emit())
	f.burned_away.connect(func(): burned_away.emit())
	f.seen_by_player.connect(func(): seen_by_player.emit())
	f.reached_player.connect(func(): reached_player.emit())
	_figs.append(f)
	if _dev:
		print("spawned variant %d at %s (player %s)" % [f.variant, ground, player.global_position])


func _pick_variant() -> int:
	var deep := UNDERNEATH_THEMES.has(player.level_theme)
	var total := 0.0
	for i in VARIANT_W.size():
		if deep or not UNDERNEATH.has(i):
			total += VARIANT_W[i]
	var r := randf() * total
	for i in VARIANT_W.size():
		if not deep and UNDERNEATH.has(i):
			continue
		r -= VARIANT_W[i]
		if r <= 0.0:
			return i
	return 0


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
## sewer's channel invert at -0.48m are not. The old probe accepted anything
## within 1.3m, which is why figures stood on furniture and sank into trenches —
## and why they read as the wrong size when they did.
const FLOOR_TOL := 0.34
const FLOOR_PIERCE := 6


## The first surface under `pos` is very often furniture. Keep dropping through
## it until the real floor turns up, so the body-volume check that follows gets
## to reject the spot properly instead of clearing the air above a table.
func _floor_at(pos: Vector3) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var bottom := pos + Vector3(0, -2.0, 0)
	var from := pos + Vector3(0, 2.6, 0)
	for pierce in FLOOR_PIERCE:
		var q := PhysicsRayQueryParameters3D.create(from, bottom)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return Vector3.INF
		var p: Vector3 = hit["position"]
		if hit["normal"].y >= 0.8 and absf(p.y) <= FLOOR_TOL:
			return p
		if p.y <= bottom.y + 0.01:
			return Vector3.INF
		from = p - Vector3(0, 0.03, 0)
	return Vector3.INF
