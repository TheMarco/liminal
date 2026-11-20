class_name CornerApparitions
extends Node
## Rare, harmless Descent sightings. Nearby reachable standing points are
## observed continuously: a point has to be physically hidden by architecture,
## then become clear and enter the camera cone as the player moves around it.
## That hidden -> visible transition is the corner. The figure only comes into
## existence on that first clear beat, holds still for two seconds, and dissolves.

signal revealed(texture_key: String)

const CELL := WorldGen.CELL_SIZE
const MIN_REVEAL_D := 4.5
const MAX_REVEAL_D := 16.0
const REVEAL_DOT := 0.78
const HIDDEN_MIN_SECONDS := 0.30
const EXPOSED_GRACE_SECONDS := 1.40
const SCAN_SECONDS := 0.16
const CONNECTED_DEPTH := 2
const HOLD_SECONDS := 2.0
const FADE_SECONDS := 1.35
const SILHOUETTE_HANDOFF_SECONDS := 0.20
const SMOKE_PARTICLE_COUNT := 320
const SHARED_QUIET_SECONDS := 50.0

## These are intentionally rarer than the distant walking shadows. A normal
## floor generally gets zero or one; a long, exploratory floor may get two.
const FIRST_MIN := 28.0
const FIRST_MAX := 58.0
const QUIET_MIN := 135.0
const QUIET_MAX := 250.0

## texture key -> [standing height in metres, source aspect]
const LOOKS := {
	"corner_hooded_robe": [2.22, 0.404],
	"corner_girl_ragged": [1.34, 0.311],
	"corner_girl_lace": [1.31, 0.426],
	"corner_hooded_man": [1.92, 0.342],
	"corner_woman_gown": [1.88, 0.357],
}

var player: Player
var run: DescentRun
var topology: DescentTopology
var horror_director: HorrorDirector
var world_seed := 1
var theme := 0
var suspended := true
var passive := false
## Shared with `--passer`: short clocks for QA.
var dev_force := false

var reveal_count := 0
var _rng := RandomNumberGenerator.new()
var _t := 60.0
var _scan_left := 0.0
var _hidden_since := {}
var _exposed_until := {}
var _live: Node3D
var _last_look := ""
var _standing_shape: CapsuleShape3D
var _standing_query: PhysicsShapeQueryParameters3D
var _standing_player_rid := RID()

static var _smoke_shapes: Dictionary[String, PackedVector3Array] = {}
static var _smoke_mesh: QuadMesh
static var _smoke_scale: Curve
static var _smoke_alpha: Gradient


func configure(p_world_seed: int, p_theme: int) -> void:
	world_seed = p_world_seed
	theme = p_theme
	_rng.seed = WorldGen.h(world_seed, theme, 0, 3109)
	_clear_observations()
	_clear_live()
	_scan_left = 0.0
	_t = 0.5 if dev_force else _rng.randf_range(FIRST_MIN, FIRST_MAX)


## A distant crossing shadow has just fired. Drop an unseen candidate and keep
## enough silence between visual stings for the next one to be surprising.
func defer_for(seconds: float) -> void:
	_clear_observations()
	if not is_instance_valid(_live):
		_t = maxf(_t, seconds)


func _physics_process(dt: float) -> void:
	if _unsafe():
		_clear_observations()
		_clear_live()
		return
	if is_instance_valid(_live):
		return
	_t = maxf(0.0, _t - dt)
	_scan_left -= dt
	if _scan_left > 0.0:
		return
	_scan_left = SCAN_SECONDS
	_scan_visibility()


func _unsafe() -> bool:
	if suspended or passive or player == null or not player.is_inside_tree():
		return true
	return run != null and (run.ended or run.suspended or run.blackout or run.watching)


## Pure topology hook used by the audit. Every row describes a walk with one
## ninety-degree turn: origin -> bend -> target. Both constituent edges are
## authoritative `WorldGen.edge_info` openings. A second target step is offered
## where the corridor continues, which puts some figures much farther away.
static func topology_candidates(p_world_seed: int, p_theme: int,
		origin: Vector2i, p_topology: DescentTopology = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for first_dir in 4:
		if bool(_resolved_edge_info(p_world_seed, p_theme, p_topology,
				origin, first_dir)["wall"]):
			continue
		var bend: Vector2i = origin + WorldGen.DIRV[first_dir]
		for turn_dir in 4:
			if turn_dir == first_dir or turn_dir == WorldGen.OPP[first_dir]:
				continue
			if bool(_resolved_edge_info(p_world_seed, p_theme, p_topology,
					bend, turn_dir)["wall"]):
				continue
			var target: Vector2i = bend + WorldGen.DIRV[turn_dir]
			out.append({
				"origin": origin,
				"bend": bend,
				"target_cell": target,
				"first_dir": first_dir,
				"turn_dir": turn_dir,
				"turn_steps": 1,
			})
			if not bool(_resolved_edge_info(p_world_seed, p_theme, p_topology,
					target, turn_dir)["wall"]):
				out.append({
					"origin": origin,
					"bend": bend,
					"target_cell": target + WorldGen.DIRV[turn_dir],
					"first_dir": first_dir,
					"turn_dir": turn_dir,
					"turn_steps": 2,
				})
	return out


static func _resolved_edge_info(p_world_seed: int, p_theme: int,
		p_topology: DescentTopology, at: Vector2i, dir: int) -> Dictionary:
	return p_topology.edge_info(at, dir) if p_topology != null else \
		WorldGen.edge_info(p_world_seed, at, dir, p_theme)


func _scan_visibility() -> void:
	var cam := player.cam
	if cam == null:
		return
	var origin := Vector2i(floori(player.global_position.x / CELL),
		floori(player.global_position.z / CELL))
	var now := float(Time.get_ticks_msec()) / 1000.0
	var active := {}
	var ready: Array[Dictionary] = []
	for cell in _connected_cells(origin):
		if cell == origin:
			continue
		var target := _cell_point(cell)
		var distance := player.global_position.distance_to(target)
		if distance < MIN_REVEAL_D or distance > MAX_REVEAL_D:
			continue
		active[cell] = true
		var sight := target + Vector3(0, 1.05, 0)
		var clear := _clear_line(cam.global_position, sight)
		_record_visibility(cell, clear, now)
		if _t > 0.0 or not clear or not _freshly_exposed(cell, now):
			continue
		var dot := _view_dot(cam, sight)
		if dot < REVEAL_DOT or not _standing_room(target):
			continue
		ready.append({"target": target, "dot": dot, "distance": distance})

	# Forget rooms that have fallen outside the local reachable neighbourhood.
	# An old hidden sample must never turn into an apparition after a teleport.
	for cell in _hidden_since.keys():
		if not active.has(cell):
			_hidden_since.erase(cell)
	for cell in _exposed_until.keys():
		if not active.has(cell) or float(_exposed_until[cell]) < now:
			_exposed_until.erase(cell)

	if ready.is_empty():
		return
	# Prefer the reveal most squarely inside the view. This is evaluated on the
	# first clear scan, so the figure is already visible when it is created.
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a["dot"]) * 1.35 \
			- float(a["distance"]) / MAX_REVEAL_D * 0.48
		var b_score := float(b["dot"]) * 1.35 \
			- float(b["distance"]) / MAX_REVEAL_D * 0.48
		return a_score > b_score)
	var at: Vector3 = ready[0]["target"]
	_clear_observations()
	if horror_director != null and not horror_director.try_start_visual(
			HOLD_SECONDS + FADE_SECONDS):
		_t = _rng.randf_range(4.0, 8.0)
		return
	_show(at)


func _connected_cells(origin: Vector2i) -> Array[Vector2i]:
	return connected_cells_for(world_seed, theme, origin, topology,
		CONNECTED_DEPTH)


## Pure resolver hook used by mutation audits and the live scanner alike.
static func connected_cells_for(p_world_seed: int, p_theme: int,
		origin: Vector2i, p_topology: DescentTopology = null,
		max_depth := CONNECTED_DEPTH) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [origin]
	var depth := {origin: 0}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		var cell_depth: int = depth[cell]
		if cell_depth >= max_depth:
			continue
		for dir in 4:
			if bool(_resolved_edge_info(
					p_world_seed, p_theme, p_topology, cell, dir)["wall"]):
				continue
			var neighbour: Vector2i = cell + WorldGen.DIRV[dir]
			if depth.has(neighbour):
				continue
			depth[neighbour] = cell_depth + 1
			queue.append(neighbour)
	return queue


## Record a real visibility transition. Merely looking at an already-clear
## point cannot spawn anything: it must first have stayed behind architecture.
func _record_visibility(cell: Vector2i, clear: bool, now: float) -> void:
	if not clear:
		if not _hidden_since.has(cell):
			_hidden_since[cell] = now
		_exposed_until.erase(cell)
		return
	if _hidden_since.has(cell):
		var hidden_at := float(_hidden_since[cell])
		if now - hidden_at >= HIDDEN_MIN_SECONDS:
			_exposed_until[cell] = now + EXPOSED_GRACE_SECONDS
		_hidden_since.erase(cell)


func _freshly_exposed(cell: Vector2i, now: float) -> bool:
	return _exposed_until.has(cell) and float(_exposed_until[cell]) >= now


func _view_dot(cam: Camera3D, sight: Vector3) -> float:
	var to_sight := sight - cam.global_position
	if to_sight.length_squared() < 0.001:
		return 1.0
	return (-cam.global_transform.basis.z).normalized().dot(
		to_sight.normalized())


## Kept separate from the topology/reveal gate so the focused audit can verify
## the exact visual, audio and lifetime contract without constructing a level.
func _show(at: Vector3) -> void:
	var started := Time.get_ticks_usec()
	var keys := LOOKS.keys()
	var key: String = str(keys[_rng.randi_range(0, keys.size() - 1)])
	if keys.size() > 1 and key == _last_look:
		key = str(keys[(keys.find(key) + 1 + _rng.randi_range(
			0, keys.size() - 2)) % keys.size()])
	_last_look = key
	var look: Array = LOOKS[key]
	var height := float(look[0]) * _rng.randf_range(0.96, 1.04)
	var width := height * float(look[1])

	var pivot := Node3D.new()
	pivot.name = "CornerApparition"
	pivot.position = at
	pivot.set_meta("corner_apparition", true)
	pivot.set_meta("texture_key", key)
	add_child(pivot)
	_live = pivot

	var quad := _make_silhouette(key, width, height, _rng.randf())
	pivot.add_child(quad)

	var sting := AudioStreamPlayer3D.new()
	sting.bus = SoundBank.HALL_BUS
	sting.name = "RevealSting"
	var scare := Sfx.random_scare()
	sting.stream = scare[0]
	sting.volume_db = scare[1]
	sting.max_distance = 42.0
	sting.unit_size = 10.0
	sting.position = Vector3(0, 1.1, 0)
	pivot.add_child(sting)
	sting.play()

	reveal_count += 1
	RuntimeDiagnostics.mark("corner_apparition_revealed", {"look": key,
		"setup_ms": (Time.get_ticks_usec() - started) / 1000.0})
	if dev_force:
		print("corner apparition revealed: %s at %s" % [key, at])
	revealed.emit(key)
	_t = 4.0 if dev_force else _rng.randf_range(QUIET_MIN, QUIET_MAX)
	var tw := pivot.create_tween()
	tw.tween_interval(HOLD_SECONDS)
	tw.tween_callback(_spawn_smoke_puff.bind(pivot, key, width, height))
	tw.tween_method(func(value: float):
		if is_instance_valid(quad):
			quad.set_instance_shader_parameter("fade", value),
		1.0, 0.0, SILHOUETTE_HANDOFF_SECONDS)
	tw.tween_interval(FADE_SECONDS - SILHOUETTE_HANDOFF_SECONDS)
	tw.tween_callback(_finish_live.bind(pivot))


static func _make_silhouette(key: String, width: float, height: float,
		dissolve_seed: float) -> GhostVisual:
	var quad := ShadowFigure.make_visual(key)
	quad.name = "Silhouette"
	quad.scale = Vector3(width, height, 1.0)
	quad.position.y = height * 0.5
	quad.set_instance_shader_parameter("fade", 1.0)
	quad.set_instance_shader_parameter("flip", 0.0)
	quad.set_instance_shader_parameter("dissolve_seed", dissolve_seed)
	quad.set_instance_shader_parameter("dissolve_smoke", 1.0)
	quad.set_instance_shader_parameter("burn", 0.0)
	quad.set_instance_shader_parameter("ignite", 0.0)
	quad.set_instance_shader_parameter("sway", 0.0)
	return quad


## Draw the same layered bodies and particle mesh as the live scare. The
## caller owns this isolated sample root for the duration of floor loading.
static func prepare_render_samples(samples: Node3D) -> void:
	var keys := LOOKS.keys()
	for i in keys.size():
		var key: String = keys[i]
		var height: float = LOOKS[key][0]
		var width: float = height * LOOKS[key][1]
		var body := _make_silhouette(key, width, height, 0.5)
		body.position.x = (i - (keys.size() - 1) * 0.5) * 1.5
		samples.add_child(body)
		_smoke_shape(key)
	# All looks use the same particle mesh and material. Keep one emitter
	# drawing through the warmup's lighting changes, clear of the silhouettes.
	var smoke := _add_smoke_puff(samples, keys[0], 0.8, 2.0)
	if smoke != null:
		smoke.position.z = 1.0
		smoke.one_shot = false
		smoke.preprocess = 0.2
	for i in Sfx.SCARE_MEANS.size():
		Sfx.scare(i)


static func _smoke_shape(key: String) -> PackedVector3Array:
	if _smoke_shapes.has(key):
		return _smoke_shapes[key]
	var points := PackedVector3Array()
	var texture := load("res://textures/ghosts/%s.png" % key) as Texture2D
	if texture == null:
		return points
	var image := texture.get_image()
	if image == null or image.is_empty():
		return points
	if image.is_compressed() and image.decompress() != OK:
		return points

	# Store body-relative coordinates once. Warming a look must never advance
	# the live encounter RNG or change the time or appearance of its first reveal.
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var attempts := 0
	while points.size() < SMOKE_PARTICLE_COUNT \
			and attempts < SMOKE_PARTICLE_COUNT * 80:
		attempts += 1
		var u := rng.randf()
		var v := rng.randf()
		var pixel := image.get_pixel(
			mini(int(u * float(image.get_width())), image.get_width() - 1),
			mini(int(v * float(image.get_height())), image.get_height() - 1))
		if pixel.a < 0.32:
			continue
		points.append(Vector3(u - 0.5, 0.5 - v, rng.randf_range(-0.018, 0.018)))
	_smoke_shapes[key] = points
	return points


func _spawn_smoke_puff(pivot: Node3D, key: String,
		width: float, height: float) -> void:
	if not is_instance_valid(pivot):
		return
	var started := Time.get_ticks_usec()
	var smoke := _add_smoke_puff(pivot, key, width, height)
	if smoke != null:
		RuntimeDiagnostics.mark("corner_apparition_dissolve", {"look": key,
			"particles": smoke.amount, "setup_ms": (Time.get_ticks_usec() - started) / 1000.0})


static func _add_smoke_puff(pivot: Node3D, key: String,
		width: float, height: float) -> CPUParticles3D:
	var points := _smoke_shape(key)
	if points.is_empty():
		return null

	var smoke := CPUParticles3D.new()
	smoke.name = "SilhouetteSmokePuff"
	smoke.position = Vector3(0.0, height * 0.5, 0.0)
	smoke.amount = points.size()
	smoke.lifetime = FADE_SECONDS
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.randomness = 0.68
	smoke.local_coords = true
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var body_scale := Transform3D(Basis.from_scale(Vector3(width, height, 1.0)), Vector3.ZERO)
	smoke.emission_points = body_scale * points
	smoke.direction = Vector3.RIGHT
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.14
	smoke.initial_velocity_max = 0.56
	smoke.gravity = Vector3.ZERO
	smoke.damping_min = 0.08
	smoke.damping_max = 0.30
	smoke.scale_amount_min = 0.65
	smoke.scale_amount_max = 1.80
	smoke.visibility_aabb = AABB(
		Vector3(-width, -height, -0.8),
		Vector3(width * 2.0, height * 2.0, 1.6))

	_prepare_smoke_resources()
	smoke.scale_amount_curve = _smoke_scale
	smoke.color_ramp = _smoke_alpha
	smoke.mesh = _smoke_mesh
	smoke.emitting = false
	pivot.add_child(smoke)
	smoke.restart()
	smoke.emitting = true
	return smoke


static func _prepare_smoke_resources() -> void:
	if _smoke_mesh != null:
		return
	_smoke_scale = Curve.new()
	_smoke_scale.add_point(Vector2(0.0, 0.42))
	_smoke_scale.add_point(Vector2(0.16, 1.0))
	_smoke_scale.add_point(Vector2(1.0, 0.72))
	_smoke_alpha = Gradient.new()
	_smoke_alpha.offsets = PackedFloat32Array([0.0, 0.12, 0.58, 1.0])
	_smoke_alpha.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.46),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/corner_smoke_particle.gdshader")
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2(0.085, 0.085)
	_smoke_mesh.material = material


func _finish_live(node: Node3D) -> void:
	if _live == node:
		_live = null
	if is_instance_valid(node):
		node.queue_free()


func _clear_observations() -> void:
	_hidden_since.clear()
	_exposed_until.clear()


func _clear_live() -> void:
	if is_instance_valid(_live):
		_live.queue_free()
	_live = null


func _cell_point(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * CELL,
		Chunk.cell_floor_h(world_seed, cell, theme),
		(float(cell.y) + 0.5) * CELL)


func _standing_room(at: Vector3) -> bool:
	if _standing_query == null:
		_standing_shape = CapsuleShape3D.new()
		_standing_shape.radius = 0.38
		_standing_shape.height = 1.8
		_standing_query = PhysicsShapeQueryParameters3D.new()
		_standing_query.shape = _standing_shape
		_standing_query.collide_with_areas = false
		_standing_query.collision_mask = 1
	var player_rid := player.get_rid()
	if player_rid != _standing_player_rid:
		_standing_player_rid = player_rid
		_standing_query.exclude = [player_rid]
	_standing_query.transform = Transform3D(
		Basis.IDENTITY, at + Vector3(0, 0.96, 0))
	return player.get_world_3d().direct_space_state.intersect_shape(
		_standing_query, 1).is_empty()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
