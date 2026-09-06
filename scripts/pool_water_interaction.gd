extends Node3D
## Player-owned, bounded water disturbances. Only nearby disturbed surfaces
## get a private material; untouched water keeps the shared zero-event shader.
## Movement submits contact on the physics clock; existing waves/spray decay
## on the render clock, including when a recording temporarily stops movement.

const SURFACE_GROUP := &"pool_water_surfaces"
const WATER_LAYER := preload("res://scripts/pool_reflection_probe.gd").WATER_LAYER
const DRY := -1.0e9
const MAX_EVENTS := 12
const EVENT_LIFE := 2.8
const REACH := 3.2
const MAX_DROPS := 96
const MAX_SHEETS := 3

var clock := 0.0
var events: Array[Dictionary] = []
var _surfaces: Array[MeshInstance3D] = []
var _materials := {}
var _refresh_left := 0.0
var _initialized := false
var _wet := false
var _previous := Vector3.ZERO
var _travel := 0.0
var _step_side := 1.0
var _entry_cooldown := 0.0
var _body := Vector3.ZERO
var _direction := Vector2(0, -1)
var _speed := 0.0
var _depth := 0.0
var _spray: MultiMeshInstance3D
var _spray_material: ShaderMaterial
var _drop_cursor := 0
var _spray_until := 0.0
var _sheets: Array[MeshInstance3D] = []
var _sheet_cursor := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 74219
	_build_spray()
	set_process(false)

func _exit_tree() -> void:
	_restore_materials()

## Reset at teleports, floor changes and camera-owned motion boundaries.
## First contact after a reset seeds history without manufacturing a splash.
func reset() -> void:
	_initialized = false
	_wet = false
	_speed = 0.0
	_travel = 0.0
	_entry_cooldown = 0.0
	_refresh_left = 0.0
	events.clear()
	_surfaces.clear()
	_restore_materials()
	if _spray != null:
		_spray.visible = false
		for i in MAX_DROPS: _spray.multimesh.set_instance_custom_data(i, Color(0, 0, 0, -100))
	for sheet in _sheets:
		sheet.visible = false
		sheet.material_override.set_shader_parameter("born", -100.0)
	_spray_until = 0.0
	set_process(false)

func _restore_materials() -> void:
	for surface in _materials:
		if is_instance_valid(surface):
			var pair: Array = _materials[surface]
			if surface.material_override == pair[1]: surface.material_override = pair[0]
	_materials.clear()

func _refresh_surfaces(at: Vector3) -> void:
	_surfaces.clear()
	for node in get_tree().get_nodes_in_group(SURFACE_GROUP):
		var surface := node as MeshInstance3D
		if surface == null or not surface.mesh is PlaneMesh: continue
		if surface.get_world_3d() != get_world_3d(): continue
		if distance_to_surface(surface, at) < 12.0: _surfaces.append(surface)
	_refresh_left = 0.20

static func distance_to_surface(surface: MeshInstance3D, at: Vector3) -> float:
	var local := surface.to_local(at)
	var half: Vector2 = (surface.mesh as PlaneMesh).size * 0.5
	return Vector2(maxf(absf(local.x) - half.x, 0.0),
		maxf(absf(local.z) - half.y, 0.0)).length()

## Use the mesh's actual transformed footprint, then reject solid coping,
## rounded corners and piers occupying the water line. Exclude the player.
func surface_height(at: Vector3, exclude: Array[RID] = []) -> float:
	if _refresh_left <= 0.0: _refresh_surfaces(at)
	var height := DRY
	for surface in _surfaces:
		if not is_instance_valid(surface) or not surface.is_inside_tree(): continue
		if distance_to_surface(surface, at) > 0.001: continue
		if surface.has_meta("pool_water_outline"):
			var local := surface.to_local(at)
			if not Geometry2D.is_point_in_polygon(Vector2(local.x, local.z),
					surface.get_meta("pool_water_outline")):
				continue
		height = maxf(height, surface.global_position.y)
	if height == DRY: return DRY
	var point := Vector3(at.x, height, at.z)
	var query := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 0.04, point - Vector3.UP * 0.06, 1, exclude)
	query.hit_from_inside = true
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return DRY
	return height

## Accept the post-slide position and PRE-slide vertical velocity: landing
## can zero velocity in the same tick that a fast fall crosses the surface.
func sample_motion(dt: float, at: Vector3, horizontal: Vector2,
		vertical: float, height: float) -> void:
	_refresh_left -= dt
	_entry_cooldown = maxf(0.0, _entry_cooldown - dt)
	var depth := height - at.y
	var previous_water_y := _body.y
	var wet := height > -1.0e8 and depth > (0.015 if not _wet else -0.025) and depth < 1.85
	var travelled := Vector2(at.x - _previous.x, at.z - _previous.z).length()
	# Large corrections must never draw a trail through intervening rooms.
	if _initialized and at.distance_to(_previous) > maxf(1.0, dt * 14.0):
		reset()
	_body = Vector3(at.x, height, at.z)
	_speed = horizontal.length() if wet else 0.0
	_depth = clampf(depth, 0.0, 1.4) if wet else 0.0
	if _speed > 0.05: _direction = horizontal.normalized()
	if not _initialized:
		_initialized = true
		_wet = wet
		_previous = at
		return
	if wet and not _wet and _entry_cooldown <= 0.0:
		var impact := clampf((-vertical - 0.5) / 4.5, 0.0, 1.0)
		_add_event(_body, 0.48 + impact * 0.52, _direction, 0.0)
		if vertical < -1.1: _splash(_body, impact, horizontal)
		_entry_cooldown = 0.65
		_travel = 0.0
	elif not wet and _wet:
		_add_event(Vector3(at.x, previous_water_y, at.z), 0.22, _direction, 1.0)
	if wet and _wet and _speed > 0.18:
		_travel += travelled
		if _travel >= 0.46:
			_travel = fmod(_travel, 0.46)
			_step_side = -_step_side
			var side := Vector2(-_direction.y, _direction.x) * _step_side * 0.16
			var step_at := _body + Vector3(side.x, 0, side.y)
			var strength := clampf(_speed / 2.2, 0.0, 1.0) * lerpf(0.38, 0.68, clampf(_depth, 0, 1))
			_add_event(step_at, strength, _direction, 1.0)
	if wet and _speed > 0.05: set_process(true)
	_wet = wet
	_previous = at

func _add_event(at: Vector3, strength: float, direction: Vector2, kind: float) -> void:
	if events.size() == MAX_EVENTS: events.pop_front()
	events.append({"at": at, "born": clock, "strength": strength,
		"direction": direction, "kind": kind})
	set_process(true)

func _process(dt: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body != null and not body.is_physics_processing():
		_speed = 0.0
		_initialized = false
	advance(dt)

## Also used by deterministic motion captures; no dependence on shader TIME.
func advance(dt: float) -> void:
	clock += dt
	while not events.is_empty() and clock - float(events[0]["born"]) > EVENT_LIFE:
		events.pop_front()
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	a.resize(MAX_EVENTS)
	b.resize(MAX_EVENTS)
	for i in events.size():
		var event := events[i]
		var at: Vector3 = event["at"]
		var direction: Vector2 = event["direction"]
		a[i] = Vector4(at.x, at.z, event["born"], event["strength"])
		b[i] = Vector4(direction.x, direction.y, event["kind"], at.y)
	var needed := {}
	for surface in _surfaces:
		if not is_instance_valid(surface) or not surface.is_inside_tree(): continue
		var near := _speed > 0.05 and absf(surface.global_position.y - _body.y) < 0.07 \
			and distance_to_surface(surface, _body) < 1.4
		if not near:
			for event in events:
				var at: Vector3 = event["at"]
				if absf(surface.global_position.y - at.y) < 0.07 and distance_to_surface(surface, at) < REACH:
					near = true
					break
		if not near: continue
		needed[surface] = true
		if not _materials.has(surface):
			var original := surface.material_override as ShaderMaterial
			if original == null: continue
			var material := original.duplicate() as ShaderMaterial
			_materials[surface] = [original, material]
			surface.material_override = material
		var material: ShaderMaterial = _materials[surface][1]
		material.set_shader_parameter("fx_clock", clock)
		material.set_shader_parameter("fx_count", events.size())
		material.set_shader_parameter("fx_events", a)
		material.set_shader_parameter("fx_shapes", b)
		material.set_shader_parameter("fx_body", Vector4(_body.x, _body.z, _body.y, _speed))
		material.set_shader_parameter("fx_motion", Vector3(_direction.x, _direction.y, _depth))
	for surface in _materials.keys():
		if needed.has(surface): continue
		if is_instance_valid(surface) and surface.material_override == _materials[surface][1]:
			surface.material_override = _materials[surface][0]
		_materials.erase(surface)
	if _spray != null:
		_spray.visible = clock < _spray_until
		if _spray.visible: _spray_material.set_shader_parameter("fx_clock", clock)
	for sheet in _sheets:
		var material := sheet.material_override as ShaderMaterial
		var age := clock - float(material.get_shader_parameter("born"))
		sheet.visible = age >= 0 and age < 0.65
		if sheet.visible: material.set_shader_parameter("fx_clock", clock)
	if events.is_empty() and _speed <= 0.05 and clock >= _spray_until:
		set_process(false)

func _build_spray() -> void:
	if _spray != null: return
	_spray_material = ShaderMaterial.new()
	_spray_material.shader = preload("res://shaders/pool_splash_drop.gdshader")
	# Water composites the opaque scene with alpha=1. Spray must draw after
	# that surface, while retaining depth tests against deck and walls.
	_spray_material.render_priority = 1
	var drop := SphereMesh.new()
	drop.radius = 0.0038
	drop.height = 0.018
	drop.radial_segments = 6
	drop.rings = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.instance_count = MAX_DROPS
	multi.mesh = drop
	for i in MAX_DROPS: multi.set_instance_custom_data(i, Color(0, 0, 0, -100))
	_spray = MultiMeshInstance3D.new()
	_spray.multimesh = multi
	_spray.material_override = _spray_material
	_spray.layers = WATER_LAYER
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray.visible = false
	add_child(_spray)
	# A tessellated radial water sheet. The shader gives its crest a short,
	# irregular ballistic arc; small drops separate from it as it collapses.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 64:
		for band in 4:
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var uv := Vector2((sector + corner.x) / 64.0, (band + corner.y) / 4.0)
				st.set_uv(uv)
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3.ZERO)
	var mesh := st.commit()
	for i in MAX_SHEETS:
		var sheet := MeshInstance3D.new()
		sheet.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/pool_splash_sheet.gdshader")
		material.render_priority = 1
		material.set_shader_parameter("normal_tex", Mats.pool_water().get_shader_parameter("normal_tex"))
		material.set_shader_parameter("born", -100.0)
		sheet.material_override = material
		sheet.layers = WATER_LAYER
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.custom_aabb = AABB(Vector3(-1.2, -0.1, -1.2), Vector3(2.4, 1.5, 2.4))
		sheet.visible = false
		_sheets.append(sheet)
		add_child(sheet)

func _splash(at: Vector3, impact: float, horizontal: Vector2) -> void:
	if _spray == null: _build_spray()
	var amount := int(lerpf(20, 36, impact))
	for i in amount:
		var angle := TAU * float(i) / amount + _rng.randf_range(-0.12, 0.12)
		var radial := Vector2(cos(angle), sin(angle))
		var v := radial * _rng.randf_range(0.45, 1.15) * (0.65 + impact * 0.65)
		v += horizontal * 0.60
		var up := _rng.randf_range(1.0, 2.3) * (0.65 + impact * 0.65)
		var origin := at + Vector3(radial.x * 0.23, 0.035, radial.y * 0.23)
		var scale_drop := _rng.randf_range(0.7, 1.5)
		_spray.multimesh.set_instance_transform(_drop_cursor, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_drop), origin))
		_spray.multimesh.set_instance_custom_data(_drop_cursor, Color(v.x, up, v.y, clock))
		_drop_cursor = (_drop_cursor + 1) % MAX_DROPS
	_spray.custom_aabb = AABB(at - Vector3(3, 1, 3), Vector3(6, 4, 6))
	_spray_until = clock + 0.85
	var sheet := _sheets[_sheet_cursor]
	sheet.position = at + Vector3.UP * 0.006
	var material := sheet.material_override as ShaderMaterial
	material.set_shader_parameter("born", clock)
	material.set_shader_parameter("impact", impact)
	material.set_shader_parameter("drift", horizontal * 0.45)
	material.set_shader_parameter("seed_phase", _rng.randf() * TAU)
	_sheet_cursor = (_sheet_cursor + 1) % MAX_SHEETS
