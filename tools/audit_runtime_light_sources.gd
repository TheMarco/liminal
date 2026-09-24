extends SceneTree
## Construct representative chunks in every theme/style and verify that every
## active direct light has a visible, emissive source nearby. Also covers the
## route-only casino landmarks that ordinary world generation cannot select.
## This is a sampling audit, not a proof for every procedural seed or camera.
##
## godot --headless --path . --script tools/audit_runtime_light_sources.gd

const SEEDS := [20260807, 240721, 405195947]
const SAMPLES_PER_STYLE := 3
const MAX_SOURCE_DISTANCE := 1.2

var _failures: Array[String] = []
var _chunks := 0
var _lights := 0
var _sources := {}


func _init() -> void:
	call_deferred("_run")


func _emits(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null:
		return false
	# Both the ordinary world and eye-only anomaly layer are visible in play.
	if mesh.layers & ~(PhotoAnomaly.PHOTO_LAYER | PhotoAnomaly.PRINT_LAYER) == 0:
		return false
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		if material is BaseMaterial3D and material.emission_enabled:
			return true
		# A shader mentioning EMISSION is not proof of light: several floor and
		# water shaders write zero or reflected colour there. The intentional
		# dynamic shader cues are audited separately from generated fixtures.
	return false


func _distance(p: Vector3, mesh: MeshInstance3D, transform: Transform3D) -> float:
	var box: AABB = transform * mesh.mesh.get_aabb()
	var nearest := Vector3(
		clampf(p.x, box.position.x, box.end.x),
		clampf(p.y, box.position.y, box.end.y),
		clampf(p.z, box.position.z, box.end.z))
	return nearest.distance_to(p)


func _gather(node: Node, parent_transform: Transform3D,
		parent_visible: bool, emitters: Array[Dictionary], lights: Array[Dictionary]) -> void:
	var transform := parent_transform
	var visible := parent_visible
	if node is Node3D:
		transform *= (node as Node3D).transform
		visible = visible and (node as Node3D).visible
	if not visible:
		return
	if node is MeshInstance3D and _emits(node as MeshInstance3D):
		emitters.append({"mesh": node, "transform": transform})
	elif node is Light3D and (node as Light3D).light_energy > 0.0:
		lights.append({"light": node, "position": transform.origin})
	for child in node.get_children():
		_gather(child, transform, visible, emitters, lights)


func _scan_chunk(chunk: Chunk, label: String) -> void:
	_chunks += 1
	var emitters: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	_gather(chunk, Transform3D.IDENTITY, true, emitters, lights)
	for item in lights:
		var light: Light3D = item.light
		_lights += 1
		var source := str(light.get_meta("visible_source", ""))
		_sources[source] = int(_sources.get(source, 0)) + 1
		if source.is_empty():
			_failures.append("%s: unlabelled active %s" % [label, light.name])
			continue
		var closest := INF
		for emitter in emitters:
			closest = minf(closest, _distance(item.position,
				emitter.mesh, emitter.transform))
		if closest > MAX_SOURCE_DISTANCE:
			_failures.append("%s: %s is %.2fm from a visible emitter" % [
				label, source, closest])
	chunk.free()


func _scan_generated(base_seed: int) -> void:
	for theme in WorldGen.THEMES:
		var seed := WorldGen.level_seed(base_seed, theme)
		var selected := {}
		for x in range(-16, 17):
			for z in range(-16, 17):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(seed, cell, theme)
				if not selected.has(style):
					selected[style] = []
				if selected[style].size() < SAMPLES_PER_STYLE:
					selected[style].append(cell)
		for style in selected:
			for cell: Vector2i in selected[style]:
				_scan_chunk(Chunk.new(seed, cell, theme),
					"seed=%d theme=%d style=%d cell=%s" % [
						base_seed, theme, style, cell])
		print("LIGHT_SOURCE_AUDIT seed=%d theme=%d styles=%d" % [
			base_seed, theme, selected.size()])


func _scan_landmarks(base_seed: int) -> void:
	var route := DescentRoute.build(base_seed, 0, 0)
	for room in route.casino_landmarks:
		var kind := str(route.casino_landmarks[room])
		var spec := ChunkBuildSpec.new()
		spec.descent = true
		spec.floor_idx = 0
		spec.base_seed = route.world_seed
		spec.casino_landmark = kind
		_scan_chunk(Chunk.new(route.world_seed, room, 0, spec),
			"seed=%d casino_landmark=%s cell=%s" % [base_seed, kind, room])


func _scan_rare_rooms(base_seed: int) -> void:
	var prison_seed := WorldGen.level_seed(base_seed, 8)
	var execution := ChunkBuildSpec.NO_CELL
	for x in range(-48, 49):
		for z in range(-48, 49):
			var cell := Vector2i(x, z)
			var root_cell := WorldGen.room_id(prison_seed, cell)
			if root_cell != cell or WorldGen.room_size(prison_seed, cell) < 2:
				continue
			if WorldGen.cell_style(prison_seed, cell, 8) not in [
				WorldGen.PRISON_GUARD, WorldGen.PRISON_INDUSTRY,
				WorldGen.PRISON_VISITATION, WorldGen.PRISON_ROTUNDA]:
				continue
			if WorldGen.r01(prison_seed, cell.x, cell.y, 7715) \
					< Chunk.PRISON_EXECUTION_CHANCE:
				execution = cell
				break
		if execution != ChunkBuildSpec.NO_CELL:
			break
	if execution == ChunkBuildSpec.NO_CELL:
		_failures.append("seed=%d: no execution chamber found" % base_seed)
	else:
		_scan_chunk(Chunk.new(prison_seed, execution, 8),
			"seed=%d execution_chamber cell=%s" % [base_seed, execution])
	var route := DescentRoute.build(base_seed, 0, 0)
	var spec := ChunkBuildSpec.new()
	spec.descent = true
	spec.floor_idx = 0
	spec.base_seed = route.world_seed
	spec.target = true
	spec.target_wall = 0
	_scan_chunk(Chunk.new(route.world_seed, route.target, 0, spec),
		"seed=%d descent_elevator cell=%s" % [base_seed, route.target])


func _run() -> void:
	for base_seed in SEEDS:
		_scan_generated(base_seed)
		_scan_landmarks(base_seed)
		_scan_rare_rooms(base_seed)
	for source in ["execution_chamber_pendant", "elevator_ceiling_panel",
			"lounge_floor_lamp_bulb", "telephone_indicator"]:
		if not _sources.has(source):
			_failures.append("required rare fixture not exercised: %s" % source)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	if _failures.is_empty():
		print("PASS runtime_light_sources: %d chunks, %d active lights, %d source types" % [
			_chunks, _lights, _sources.size()])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL runtime_light_sources: %d failures in %d chunks / %d lights" % [
		_failures.size(), _chunks, _lights])
	quit(1)
