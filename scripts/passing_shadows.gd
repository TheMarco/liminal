class_name PassingShadows
extends Node
## Set dressing, not a threat: once in a long while a silhouette crosses the
## player's narrow hallway in the distance and is gone in about two seconds.
## It does nothing, chases nothing, and by the time the player reaches the
## spot there is nothing there and never was. The walk itself is authored
## footage whose lateral traversal is baked into the flipbook.

signal revealed

const CELL := 12.0
## Sheets live in ShadowFigure.FLIPBOOKS/BODY like every other apparition;
## each spawn mirrors at random, so four sheets are eight walks.
const SHEETS := ["passer1", "passer2", "passer3", "passer4"]
const HEIGHT := 2.05
## The source walks were authored at roughly this pace. Playing the 24 sampled
## poses at the hostile ghosts' 12fps compressed a human crossing into 2s and
## made it look like a fast-forwarded video.
const CROSS_SECONDS := 3.4
const MIN_D := 14.0
const MAX_D := 26.0
## The player must actually be looking along the hall, not out through a side
## doorway from a room. This also keeps the crossing in the distant view.
const HALL_AHEAD_DOT := 0.82
const NARROW_ANNEX_MAX := 4.8
const BROAD_THEMES := [4, 7, 9]
const QUIET_MIN := 55.0
const QUIET_MAX := 130.0
const RETRY_MIN := 7.0
const RETRY_MAX := 14.0

var player: Player
var run: DescentRun
var topology: DescentTopology
var horror_director: HorrorDirector
var world_seed := 1
var theme := 0
var suspended := true
var dev_force := false

var _t := 20.0
var _live: Node3D


func _ready() -> void:
	if dev_force:
		# Screenshot verification fires at ~2.5s and a walk lasts ~2s, so the
		# forced spawn has to land just before the shutter.
		_t = 1.9


func configure(p_world_seed: int, p_theme: int) -> void:
	world_seed = p_world_seed
	theme = p_theme


## Another transient sighting just fired. Keep the two visual-scare systems
## from stacking closely enough to feel like a scripted sequence.
func defer_for(seconds: float) -> void:
	_t = maxf(_t, seconds)


func _physics_process(dt: float) -> void:
	if suspended or player == null or not player.is_inside_tree() \
			or is_instance_valid(_live):
		return
	if not ResourceLoader.exists("res://textures/ghosts/%s.webp" % SHEETS[0]):
		return
	if run != null and (run.blackout or run.watching or run.suspended):
		return
	_t -= dt
	if _t > 0.0:
		return
	if _attempt():
		if dev_force:
			print("[passer] crossing spawned")
		_t = 3.0 if dev_force else randf_range(QUIET_MIN, QUIET_MAX)
	else:
		if dev_force:
			print("[passer] no candidate opening in range")
		_t = 0.4 if dev_force else randf_range(RETRY_MIN, RETRY_MAX)


func _attempt() -> bool:
	var cam := player.cam
	if cam == null:
		return false
	var pc := Vector2i(floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	var axis := _narrow_corridor_axis(pc)
	if axis == 0:
		return false
	var fwd3 := -cam.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var along := Vector2(1.0, 0.0) if axis == 1 else Vector2(0.0, 1.0)
	if absf(fwd.dot(along)) < HALL_AHEAD_DOT:
		return false
	var sign_along := 1 if fwd.dot(along) >= 0.0 else -1
	var dir := (0 if sign_along > 0 else 1) if axis == 1 \
		else (2 if sign_along > 0 else 3)
	var step: Vector2i = WorldGen.DIRV[dir]
	var candidates: Array = []
	var previous := pc
	for distance_cells in range(1, 4):
		if not _corridor_continues(previous, dir, axis):
			break
		var cell: Vector2i = pc + step * distance_cells
		if _narrow_corridor_axis(cell) != axis:
			break
		var point := Vector3((float(cell.x) + 0.5) * CELL,
			Chunk.cell_floor_h(world_seed, cell, theme),
			(float(cell.y) + 0.5) * CELL)
		var flat := Vector2(point.x, point.z)
		var to := flat - Vector2(player.global_position.x,
			player.global_position.z)
		var d := to.length()
		if d >= MIN_D and d <= MAX_D \
				and fwd.dot(to / d) >= HALL_AHEAD_DOT \
				and _clear_line(cam.global_position,
					point + Vector3(0, 1.4, 0)):
			candidates.append([point, d])
		previous = cell
	if candidates.is_empty():
		return false
	var pick: Array = candidates[randi() % candidates.size()]
	if horror_director != null \
			and not horror_director.try_start_visual(CROSS_SECONDS):
		return false
	if dev_force:
		print("[passer] crossing at %s, %.1fm" % [pick[0], pick[1]])
	_cross(pick[0])
	return true


## 0 means room/intersection/broad concourse; 1 and 2 are genuinely narrow
## horizontal/vertical hallways. Annex has explicit physical width metadata.
func _narrow_corridor_axis(cell: Vector2i) -> int:
	if BROAD_THEMES.has(theme):
		return 0
	if theme == 2:
		var annex_axis := WorldGen.annex_corridor_axis(world_seed, cell)
		if annex_axis == 1:
			return annex_axis if WorldGen.annex_horizontal_width(
				world_seed, cell.y) <= NARROW_ANNEX_MAX else 0
		if annex_axis == 2:
			return annex_axis if WorldGen.annex_vertical_width(
				world_seed, cell.x) <= NARROW_ANNEX_MAX else 0
		return 0
	return WorldGen.corridor(world_seed, cell)


func _corridor_continues(cell: Vector2i, dir: int, axis: int) -> bool:
	var edge := topology.edge_info(cell, dir) if topology != null else \
		WorldGen.edge_info(world_seed, cell, dir, theme)
	if bool(edge["wall"]):
		return false
	var neighbour: Vector2i = cell + WorldGen.DIRV[dir]
	if _narrow_corridor_axis(neighbour) != axis:
		return false
	if theme == 2:
		return (axis == 1 and dir <= 1) or (axis == 2 and dir >= 2)
	return WorldGen.corridor_link(world_seed, cell, dir)


func _cross(at: Vector3) -> void:
	var sheet: String = SHEETS[randi() % SHEETS.size()]
	var fb: Array = ShadowFigure.FLIPBOOKS[sheet]
	var body: Array = ShadowFigure.BODY[sheet]
	var seconds := CROSS_SECONDS
	var qh := HEIGHT / (float(body[2]) - float(body[1]))
	var qw := qh * float(body[0])

	var pivot := Node3D.new()
	# The ghost shader faces this plane toward the camera. The sheet itself
	# carries the sideways walk, centered across the distant corridor.
	pivot.position = at
	add_child(pivot)
	_live = pivot

	var quad := MeshInstance3D.new()
	quad.mesh = Chunk.QUAD
	quad.scale = Vector3(qw, qh, 1.0)
	quad.material_override = ShadowFigure._mat_for(sheet)
	quad.position = Vector3(0, qh * (0.5 - float(body[1])), 0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A passer is one authored traversal, never a looping ghost animation.
	# Drive its frame explicitly so renderer time, pause/time-scale changes, or
	# a delayed first draw can never wrap it from the far edge back to frame 0.
	var n := float(fb[2])
	quad.set_instance_shader_parameter("flip_frame", 0.0)
	quad.set_instance_shader_parameter("flip_blend", 1.0)
	quad.set_instance_shader_parameter("flip",
		1.0 if randi() % 2 == 0 else 0.0)
	quad.set_instance_shader_parameter("fade", 1.0)
	quad.set_instance_shader_parameter("dissolve_seed", randf())
	quad.set_instance_shader_parameter("burn", 0.0)
	quad.set_instance_shader_parameter("ignite", 0.0)
	quad.set_instance_shader_parameter("sway", 0.0)
	pivot.add_child(quad)

	# The shock is the sound arriving with the sight.
	var sting := AudioStreamPlayer3D.new()
	var pick := Sfx.random_scare()
	sting.stream = pick[0]
	sting.volume_db = pick[1]
	sting.max_distance = 40.0
	sting.unit_size = 9.0
	sting.position = Vector3(0, 1.4, 0)
	pivot.add_child(sting)
	sting.play()
	revealed.emit()

	# Advance monotonically to the last frame and disappear at the exit edge.
	# The final 0.18s softens only the offscreen tail; there is no modulo clock.
	var tw := pivot.create_tween().set_parallel(true)
	tw.tween_method(func(frame: float):
		if is_instance_valid(quad):
			quad.set_instance_shader_parameter("flip_frame", frame),
		0.0, n - 0.001, seconds)
	tw.tween_method(func(v: float):
		if is_instance_valid(quad):
			quad.set_instance_shader_parameter("fade", v),
		1.0, 0.0, 0.18).set_delay(maxf(0.0, seconds - 0.18))
	tw.chain().tween_callback(_finish_cross.bind(pivot))


func _finish_cross(node: Node3D) -> void:
	if _live == node:
		_live = null
	if is_instance_valid(node):
		node.queue_free()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
