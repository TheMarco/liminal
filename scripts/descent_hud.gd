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

const CELL := 12.0
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


func _ready() -> void:
	layer = 2
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.014, 0.010, 0.72)
	panel_style.border_color = Color(0.88, 0.55, 0.16, 0.48)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(9)
	panel_style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)
	_label = Label.new()
	_label.text = "LIFT"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.36))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0))
	_label.add_theme_constant_override("outline_size", 4)
	box.add_child(_label)
	_distance = Label.new()
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance.add_theme_font_size_override("font_size", 30)
	_distance.add_theme_color_override("font_color", Color(0.90, 0.85, 0.73))
	_distance.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0))
	_distance.add_theme_constant_override("outline_size", 4)
	box.add_child(_distance)
	_panel.visible = false


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
	if wide:
		_label.text = "ROOMS TO LIFT"
		_distance.text = "%d" % rooms
	else:
		_label.text = "LIFT"
		var target_world := Vector3(
			float(route.target.x) * CELL + CELL * 0.5, 0.0,
			float(route.target.y) * CELL + CELL * 0.5)
		var delta := target_world - player.global_position
		_distance.text = "%dm" % maxi(1,
			roundi(Vector2(delta.x, delta.z).length()))
	var viewport_size := Vector2(get_viewport().size)
	var scale := clampf(viewport_size.y / 720.0, 1.0, 1.55)
	var width := 224.0 if wide else 150.0
	_panel.scale = Vector2.ONE * scale
	_panel.size = Vector2(width, 92)
	_panel.position = Vector2(viewport_size.x * 0.5 - width * 0.5 * scale,
		14.0 * scale)
	_panel.visible = true
