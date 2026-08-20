class_name DescentHUD
extends CanvasLayer
## The lift instrument: how far, never which way. Distance is the only help
## the building offers — the direction is the player's problem, and finding
## it is the floor.
##
## Metres are a lie the player is meant to live with: a correct dogleg can
## raise the number, and a wall a stride from the lift still reads as two.
## Watching an optional recording buys a short window of the truth instead —
## the count of rooms actually left between here and the car. Still no
## direction, so the maze is untouched; only the instrument stops lying.

const CELL := WorldGen.CELL_SIZE
## How long the honest count survives after an optional recording ends. Long
## enough to reorient with, far too short to navigate by.
const TRUE_DISTANCE_SECONDS := 15.0

var player: Player
var route: DescentRoute
var run: DescentRun
var world_seed := 1
var theme := 0

var _active := false
var _true_left := 0.0
var _panel: PanelContainer
var _label: Label
var _distance: Label
var _photo: Label
var _photo_warn: Label
## Set after the tape refuses for lack of photos: the instrument relents and
## counts metres to the nearest undocumented anomaly. Distance only, like
## LIFT — the maze stays the maze. Cleared per floor by configure().
var evidence_target := Vector3.INF
var _photo_proximity := 0.0
var _warn_t := 0.0
var _last_label_text := ""
var _last_distance_text := ""
var _last_viewport_size := Vector2.ZERO
var _last_wide := false


func _ready() -> void:
	layer = 2
	# Viewfinder OSD: bare shadowed text, no plate. The panel node survives
	# only as the centring container.
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)
	_label = VhsOsd.make_label(44, VhsOsd.INK_DIM)
	_label.text = "LIFT"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_distance = VhsOsd.make_label(76)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_distance)
	# The floor's other objective sits under the first so the pair reads as
	# one instrument: how far to the lift, how much proof the tape still wants.
	_photo = VhsOsd.make_label(40, VhsOsd.INK_DIM)
	_photo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_photo.text = "PHOTOS 0/%d" % PhotoDirector.REQUIRED
	box.add_child(_photo)
	# Evidence warning: blinks while an undocumented anomaly is near, faster
	# the nearer. The one readout in the hunt that cannot be mistaken for
	# tape noise.
	_photo_warn = VhsOsd.make_label(34, VhsOsd.AMBER)
	_photo_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_photo_warn.text = "SOMETHING HERE IS WRONG"
	_photo_warn.visible = false
	box.add_child(_photo_warn)
	_panel.visible = false


func set_photo_proximity(value: float) -> void:
	_photo_proximity = clampf(value, 0.0, 1.0)


func set_photo_progress(count: int, required: int) -> void:
	_photo.text = "PHOTOS %d/%d" % [count, required]
	VhsOsd.set_ink(_photo, VhsOsd.INK if count >= required else VhsOsd.INK_DIM)


func configure(p_player: Player, p_route: DescentRoute, p_run: DescentRun,
		p_world_seed: int, p_theme: int) -> void:
	player = p_player
	route = p_route
	run = p_run
	world_seed = p_world_seed
	theme = p_theme
	# A new floor is a new maze. Whatever was still owed on the last one dies
	# with it rather than following the player out of the lift.
	_true_left = 0.0
	evidence_target = Vector3.INF


func set_active(value: bool) -> void:
	_active = value
	if not value:
		_panel.visible = false


## Payment for an optional recording. The window is only spent while the
## instrument is actually on screen, so a grant made under a television that
## still owns the camera is not quietly burned before the player sees it.
func grant_true_distance(seconds := TRUE_DISTANCE_SECONDS) -> void:
	_true_left = maxf(_true_left, seconds)


## True only while the honest count is both owed and answerable.
func showing_true_distance() -> bool:
	return _true_left > 0.0 and _rooms_left() >= 0


func _rooms_left() -> int:
	if route == null or not is_instance_valid(player):
		return -1
	var cell := Vector2i(floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	if not route.contains(cell):
		return -1
	return route.distance_from_target(cell)


func _process(dt: float) -> void:
	if not _active or not is_instance_valid(player) or route == null \
			or not is_instance_valid(run) or run.suspended or run.ended:
		_panel.visible = false
		return
	# Walking off the route mid-window shows metres again, but does not refund
	# the seconds: the recording bought a stretch of time, not a stretch of map.
	if _true_left > 0.0:
		_true_left = maxf(0.0, _true_left - dt)
	var rooms := _rooms_left() if _true_left > 0.0 else -1
	var wide := rooms >= 0
	var label_text := "ROOMS TO LIFT" if wide else "LIFT"
	var distance_text := ""
	if wide:
		distance_text = "%d" % rooms
	else:
		var target_world := Vector3(
			float(route.target.x) * CELL + CELL * 0.5, 0.0,
			float(route.target.y) * CELL + CELL * 0.5)
		var delta := target_world - player.global_position
		distance_text = "%dm" % maxi(1,
			roundi(Vector2(delta.x, delta.z).length()))
	if label_text != _last_label_text:
		_last_label_text = label_text
		_label.text = label_text
	if distance_text != _last_distance_text:
		_last_distance_text = distance_text
		_distance.text = distance_text
	var viewport_size := Vector2(get_viewport().size)
	if viewport_size != _last_viewport_size or wide != _last_wide:
		_last_viewport_size = viewport_size
		_last_wide = wide
		var scale := VhsOsd.hud_scale(viewport_size)
		var width := 480.0
		_panel.scale = Vector2.ONE * scale
		_panel.size = Vector2(width, 230)
		_panel.position = Vector2(
			viewport_size.x * 0.5 - width * 0.5 * scale,
			VhsOsd.safe_inset(viewport_size).y - 8.0 * scale)
	if not _panel.visible:
		_panel.visible = true
	# Warning blink: 0.9s period far out, 0.3s close in. Two honest tiers —
	# a long sight-line through a doorway is NEARBY, not HERE; calling
	# everything "here" sent players searching the wrong room (2026-08-19).
	# When the tape has refused and granted the evidence counter, the line
	# shows metres to the nearest undocumented anomaly instead of blinking.
	if evidence_target != Vector3.INF:
		var delta := evidence_target - player.global_position
		_photo_warn.text = "EVIDENCE %dm" % maxi(1,
			roundi(Vector2(delta.x, delta.z).length()))
		_photo_warn.visible = true
	elif _photo_proximity > 0.12:
		_photo_warn.text = "SOMETHING HERE IS WRONG" \
			if _photo_proximity >= 0.42 else "SOMETHING WRONG NEARBY"
		_warn_t += dt
		var period := lerpf(0.9, 0.3, _photo_proximity)
		_photo_warn.visible = fmod(_warn_t, period) < period * 0.6
	elif _photo_warn.visible:
		_photo_warn.visible = false
		_warn_t = 0.0
