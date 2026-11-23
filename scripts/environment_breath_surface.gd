extends Node3D
## Prepared GPU morphs; per-tick CPU work is limited to the small collision grid.
const Profile := preload("res://scripts/environment_breath_profile.gd")
const GRID := Vector2i(24, 18)
## Shader compilation is far costlier than copying a material. Office walls,
## ceilings and hallway waves share source shaders across streamed rooms, so
## compile each morph-capable variant once instead of once per event/mesh.
static var _wrapped_shaders: Dictionary = {}
var targets: Array[Dictionary] = []
var weights := PackedFloat32Array()
var frame: Transform3D
var pieces: Array[Dictionary] = []
var collision: CollisionShape3D
var _flat_grid := PackedVector3Array()
var _grid_heights: Array[PackedFloat32Array] = []
var _triangles := PackedInt32Array()
var _collision_weights := PackedFloat32Array()
var _installed := false
var _spacing := 0.12
## Preparation slicing: at most PREPARE_BATCH_MAX vertices per prepare_step,
## with a ~2ms wall-clock cap checked every PREPARE_BATCH_CHECK vertices, so a
## large wall/ceiling grid cannot stall first activation in a single tick.
## Only pacing moved here; every per-vertex formula below is unchanged.
const PREPARE_BATCH_MAX := 1024
const PREPARE_BATCH_CHECK := 32
const PREPARE_BUDGET_USEC := 2000

var prepared := false
var failed := false
var _pending: Array = []
var _building: Dictionary = {}
var _patch_size: Vector2

func begin_setup(selection: Dictionary, kind: String) -> void:
	var face: SurfaceWear.Face = selection.face
	frame = Transform3D(Basis(face.u, face.v, face.normal), selection.center)
	_patch_size = selection.size
	# At 360/480 lines the dense blend mesh costs more to upload and skin
	# than its extra vertices show. Preserve detail on narrow patches and
	# leave the independently sampled collision surface at full resolution.
	if GameSettings.current != null and int(GameSettings.current.get_value("render_resolution")) <= 1:
		_spacing = clampf(minf(_patch_size.x, _patch_size.y) / 8.0, 0.12, 0.24)
	targets = Profile.targets(kind, _patch_size, float(selection.depth))
	weights.resize(targets.size())
	_pending = [{"mesh": face.mesh, "transform": face.transform}]
	_pending.append_array(selection.companions)

## Live play prepares one bounded work unit per frame, before touching the wall.
func prepare_step() -> void:
	if prepared or failed: return
	if _pending.is_empty():
		_prepare_collision(_patch_size)
		prepared = true
		return
	if _building.is_empty():
		var item: Dictionary = _pending[0]
		failed = not _begin_piece(item.mesh, item.transform)
	elif _building.stage == "anchor":
		failed = not _step_anchor()
	elif _building.stage == "custom":
		failed = not _step_custom()
	elif _building.stage == "morph" and (_building.has("target") or _building.shapes.size() < targets.size()):
		_append_target()
	else:
		failed = not _finish_piece()
		_pending.pop_front()
		_building = {}

## Synchronous path for offline review/audits; gameplay uses prepare_step.
func setup(selection: Dictionary, kind: String) -> bool:
	begin_setup(selection, kind)
	while not prepared and not failed: prepare_step()
	return prepared

func _begin_piece(node: MeshInstance3D, transform_to_room: Transform3D) -> bool:
	if not is_instance_valid(node) or not (node.mesh is BoxMesh or node.mesh is QuadMesh): return false
	var original: Mesh = node.mesh
	var material: Material = node.material_override
	if not (material is StandardMaterial3D or material is ShaderMaterial): return false
	var primitive := original.duplicate() as PrimitiveMesh
	var physical := transform_to_room.basis.get_scale() * original.get_aabb().size
	primitive.set("subdivide_width", clampi(ceili(absf(physical.x) / _spacing), 1, 160))
	primitive.set("subdivide_height", clampi(ceili(absf(physical.y) / _spacing), 1, 96))
	if primitive is BoxMesh: primitive.subdivide_depth = clampi(ceili(absf(physical.z) / _spacing), 1, 160)
	var arrays: Array = primitive.get_mesh_arrays()
	# The node itself stays untouched until pose() installs the finished mesh,
	# so every staged slice below can be discarded safely by restore().
	var from_mesh := frame.affine_inverse() * transform_to_room
	var to_mesh := from_mesh.affine_inverse()
	var normal_in := from_mesh.basis.inverse().transposed()
	var normal_out := from_mesh.basis.transposed()
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var shapes: Array[Array] = []
	_building = {"node": node, "original": original, "material": material,
		"render_material": material, "arrays": arrays, "flags": 0,
		"vertices": arrays[Mesh.ARRAY_VERTEX], "normals": arrays[Mesh.ARRAY_NORMAL],
		"tangents": arrays[Mesh.ARRAY_TANGENT],
		"from_mesh": from_mesh, "to_mesh": to_mesh, "normal_in": normal_in,
		"normal_out": normal_out, "mesh": mesh, "shapes": shapes,
		"stage": "anchor", "cursor": 0}
	return true

# Bake the original axis-aligned triplanar mapping before a wall deforms.
func _step_anchor() -> bool:
	var node: MeshInstance3D = _building.node
	if not is_instance_valid(node): return false
	var material: Material = _building.material
	if not (material is StandardMaterial3D and (material as StandardMaterial3D).uv1_triplanar):
		_building.stage = "custom"
		_building.cursor = 0
		return true
	if not _building.has("anchor"):
		var count: int = (_building.vertices as PackedVector3Array).size()
		var uvs := PackedVector2Array()
		uvs.resize(count)
		var baked := PackedFloat32Array()
		baked.resize(count * 4)
		var mapping := node.global_transform if (material as StandardMaterial3D).uv1_world_triplanar else Transform3D.IDENTITY
		_building["anchor"] = {"uvs": uvs, "tangents": baked,
			"mapping": mapping, "basis": mapping.basis.inverse().transposed()}
	var state: Dictionary = _building.anchor
	var source: StandardMaterial3D = material
	var arrays: Array = _building.arrays
	var vertices: PackedVector3Array = _building.vertices
	var normals: PackedVector3Array = _building.normals
	var uvs: PackedVector2Array = state.uvs
	var baked: PackedFloat32Array = state.tangents
	var mapping: Transform3D = state.mapping
	var normal_basis: Basis = state.basis
	var tangent_basis := normal_basis.inverse()
	var right := (tangent_basis * Vector3.RIGHT).normalized()
	var up := (tangent_basis * Vector3.UP).normalized()
	var forward := (tangent_basis * Vector3.FORWARD).normalized()
	var cursor: int = _building.cursor
	var total := vertices.size()
	var start := Time.get_ticks_usec()
	var end := mini(cursor + PREPARE_BATCH_MAX, total)
	while cursor < end:
		var check := mini(cursor + PREPARE_BATCH_CHECK, end)
		while cursor < check:
			var n := (normal_basis * normals[cursor]).normalized()
			var axis := n.abs().max_axis_index()
			if absf(n[axis]) < 0.9999:
				push_error("Breathing surfaces require axis-aligned triplanar faces: " + source.resource_name)
				return false
			var p := (mapping * vertices[cursor]) * source.uv1_scale + source.uv1_offset
			var t := right
			var b := up
			match axis:
				Vector3.AXIS_X:
					uvs[cursor] = Vector2(-p.z, -p.y)
					t = forward
				Vector3.AXIS_Y:
					uvs[cursor] = Vector2(p.x, p.z)
					b = forward
				Vector3.AXIS_Z:
					uvs[cursor] = Vector2(p.x, -p.y)
			baked[cursor * 4] = t.x
			baked[cursor * 4 + 1] = t.y
			baked[cursor * 4 + 2] = t.z
			baked[cursor * 4 + 3] = signf(normals[cursor].cross(t).dot(b))
			cursor += 1
		if Time.get_ticks_usec() - start >= PREPARE_BUDGET_USEC:
			break
	_building.cursor = cursor
	if cursor < total:
		return true
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = baked
	_building.tangents = baked
	var result := source.duplicate() as StandardMaterial3D
	result.uv1_triplanar = false
	result.uv1_world_triplanar = false
	result.uv1_scale = Vector3.ONE
	result.uv1_offset = Vector3.ZERO
	# Godot ignores height mapping while triplanar is enabled; keep that behavior.
	result.heightmap_enabled = false
	_building.render_material = result
	_building.erase("anchor")
	_building.stage = "custom"
	_building.cursor = 0
	return true

# Rest-attribute pass for native shaders, sliced. Same floats, same order as
# the old inline append loop; pre-sized instead of appended.
func _step_custom() -> bool:
	var node: MeshInstance3D = _building.node
	if not is_instance_valid(node): return false
	var material: Material = _building.material
	if not (material is ShaderMaterial) or material.shader == SurfaceWear.PATCH_SHADER:
		_building.stage = "morph"
		_building.cursor = 0
		return true
	if not _building.has("custom"):
		var count: int = (_building.vertices as PackedVector3Array).size()
		var rest_position := PackedFloat32Array()
		rest_position.resize(count * 3)
		var rest_normal := PackedFloat32Array()
		rest_normal.resize(count * 3)
		_building["custom"] = {"position": rest_position, "normal": rest_normal}
	var state: Dictionary = _building.custom
	var vertices: PackedVector3Array = _building.vertices
	var normals: PackedVector3Array = _building.normals
	var rest_position: PackedFloat32Array = state.position
	var rest_normal: PackedFloat32Array = state.normal
	var cursor: int = _building.cursor
	var total := vertices.size()
	var start := Time.get_ticks_usec()
	var end := mini(cursor + PREPARE_BATCH_MAX, total)
	while cursor < end:
		var check := mini(cursor + PREPARE_BATCH_CHECK, end)
		while cursor < check:
			rest_position[cursor * 3] = vertices[cursor].x
			rest_position[cursor * 3 + 1] = vertices[cursor].y
			rest_position[cursor * 3 + 2] = vertices[cursor].z
			rest_normal[cursor * 3] = normals[cursor].x
			rest_normal[cursor * 3 + 1] = normals[cursor].y
			rest_normal[cursor * 3 + 2] = normals[cursor].z
			cursor += 1
		if Time.get_ticks_usec() - start >= PREPARE_BUDGET_USEC:
			break
	_building.cursor = cursor
	if cursor < total:
		return true
	var arrays: Array = _building.arrays
	arrays[Mesh.ARRAY_CUSTOM0] = rest_position
	arrays[Mesh.ARRAY_CUSTOM1] = rest_normal
	_building.flags = (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	_building.render_material = _wrap_native_shader(material)
	_building.erase("custom")
	_building.stage = "morph"
	_building.cursor = 0
	return true

# Godot packs morph normals as unit vectors: supply complete target poses,
# not normal deltas. Profile weights form a partition so normals stay outward.
# Each target is built in bounded vertex slices across prepare_step calls, in
# target order; the per-vertex formulas are unchanged.
func _append_target() -> void:
	var mesh: ArrayMesh = _building.mesh
	var vertices: PackedVector3Array = _building.vertices
	var normals: PackedVector3Array = _building.normals
	var tangents: PackedFloat32Array = _building.tangents
	var from_mesh: Transform3D = _building.from_mesh
	var to_mesh: Transform3D = _building.to_mesh
	var normal_in: Basis = _building.normal_in
	var normal_out: Basis = _building.normal_out
	if not _building.has("target"):
		mesh.add_blend_shape("pressure_%d" % _building.shapes.size())
		var positions := PackedVector3Array()
		positions.resize(vertices.size())
		var directions := PackedVector3Array()
		directions.resize(vertices.size())
		var tangent_delta := PackedFloat32Array()
		tangent_delta.resize(tangents.size())
		_building["target"] = {"index": _building.shapes.size(), "positions": positions,
			"directions": directions, "delta": tangent_delta, "cursor": 0}
	var state: Dictionary = _building.target
	var target_index: int = state.index
	var target := targets[target_index]
	var positions: PackedVector3Array = state.positions
	var directions: PackedVector3Array = state.directions
	var tangent_delta: PackedFloat32Array = state.delta
	var cursor: int = state.cursor
	var start := Time.get_ticks_usec()
	var end := mini(cursor + PREPARE_BATCH_MAX, vertices.size())
	while cursor < end:
		var check := mini(cursor + PREPARE_BATCH_CHECK, end)
		while cursor < check:
			var p := from_mesh * vertices[cursor]
			var sample := Profile.sample(target, Vector2(p.x, p.y))
			positions[cursor] = vertices[cursor] + to_mesh.basis * Vector3(0, 0, sample.x)
			var n := normal_in * normals[cursor]
			directions[cursor] = (normals[cursor] + normal_out * Vector3(-sample.y * n.z, -sample.z * n.z, 0)).normalized()
			if tangents.size() >= (cursor + 1) * 4:
				var t := from_mesh.basis * Vector3(tangents[cursor*4], tangents[cursor*4+1], tangents[cursor*4+2])
				var delta := (Vector3(tangents[cursor*4], tangents[cursor*4+1], tangents[cursor*4+2]) + to_mesh.basis * Vector3(0, 0, sample.y * t.x + sample.z * t.y)).normalized()
				tangent_delta[cursor*4] = delta.x
				tangent_delta[cursor*4+1] = delta.y
				tangent_delta[cursor*4+2] = delta.z
				tangent_delta[cursor*4+3] = tangents[cursor*4+3]
			cursor += 1
		if Time.get_ticks_usec() - start >= PREPARE_BUDGET_USEC:
			break
	if cursor < vertices.size():
		state.cursor = cursor
		return
	var blend: Array = []
	blend.resize(Mesh.ARRAY_MAX)
	blend[Mesh.ARRAY_VERTEX] = positions
	blend[Mesh.ARRAY_NORMAL] = directions
	if not tangents.is_empty(): blend[Mesh.ARRAY_TANGENT] = tangent_delta
	_building.shapes.append(blend)
	_building.erase("target")

func _finish_piece() -> bool:
	var mesh: ArrayMesh = _building.mesh
	var node: MeshInstance3D = _building.node
	if not is_instance_valid(node): return false
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _building.arrays, _building.shapes, {}, _building.flags)
	if mesh.get_surface_count() != 1: return false
	var margin := 0.0
	for target in targets: margin = maxf(margin, float(target.depth))
	pieces.append({"node": node, "original": _building.original, "material": _building.material,
		"margin": node.extra_cull_margin, "mesh": mesh, "render_material": _building.render_material,
		"expanded_margin": maxf(node.extra_cull_margin, margin)})
	return true

func _wrap_native_shader(source: ShaderMaterial) -> ShaderMaterial:
	var original := source.shader
	var wrapped: Shader = _wrapped_shaders.get(original)
	if wrapped == null:
		var code := original.code
		var start := code.find("void vertex()")
		if start < 0:
			code += "\nvoid vertex() {}\n"
			start = code.find("void vertex()")
		var opening := code.find("{", start)
		var depth := 1
		var end := opening + 1
		while depth > 0 and end < code.length():
			if code[end] == "{": depth += 1
			if code[end] == "}": depth -= 1
			end += 1
		code = code.insert(end - 1, "\nVERTEX=breath_v; NORMAL=breath_n; TANGENT=breath_t; BINORMAL=breath_b;\n")
		code = code.insert(opening + 1, "\nvec3 breath_v=VERTEX; vec3 breath_n=NORMAL; vec3 breath_t=TANGENT; vec3 breath_b=BINORMAL;\nVERTEX=CUSTOM0.xyz; NORMAL=CUSTOM1.xyz;\n")
		wrapped = Shader.new()
		wrapped.code = code
		_wrapped_shaders[original] = wrapped
	var result := source.duplicate() as ShaderMaterial
	result.shader = wrapped
	for uniform in original.get_shader_uniform_list():
		result.set_shader_parameter(uniform.name, source.get_shader_parameter(uniform.name))
	return result


static func clear_runtime_cache() -> void:
	_wrapped_shaders.clear()

func _prepare_collision(size: Vector2) -> void:
	for y in range(GRID.y + 1):
		for x in range(GRID.x + 1):
			_flat_grid.append(Vector3((float(x)/GRID.x-0.5)*size.x, (float(y)/GRID.y-0.5)*size.y, 0))
	for target in targets:
		var heights := PackedFloat32Array()
		for p in _flat_grid: heights.append(Profile.sample(target, Vector2(p.x,p.y)).x)
		_grid_heights.append(heights)
	for y in GRID.y:
		for x in GRID.x:
			var a := y*(GRID.x+1)+x
			var b := a+1
			var c := a+GRID.x+1
			var d := c+1
			_triangles.append_array([a,c,b,b,c,d])
	var body := StaticBody3D.new()
	body.transform = frame
	add_child(body)
	collision = CollisionShape3D.new()
	collision.shape = ConcavePolygonShape3D.new()
	# The room retains its original wall; this surface only fills the new bow.
	collision.shape.backface_collision = true
	collision.disabled = true
	body.add_child(collision)

func pose(values: PackedFloat32Array) -> void:
	if not prepared or values.size() != targets.size(): return
	if _installed and values == weights: return
	var previous := weights
	weights = values.duplicate()
	var nonzero := false
	for i in weights.size():
		weights[i] = clampf(weights[i], 0.0, 1.0)
		nonzero = nonzero or weights[i] > 0.00001
	if not nonzero:
		restore()
		return
	for piece in pieces:
		var node: MeshInstance3D = piece.node
		if not is_instance_valid(node): continue
		if not _installed:
			node.mesh = piece.mesh
			node.material_override = piece.render_material
			node.extra_cull_margin = piece.expanded_margin
		for i in weights.size():
			if not _installed or weights[i] != previous[i]:
				node.set_blend_shape_value(i, weights[i])
	_installed = true

func height_at(point: Vector2) -> float:
	var height := 0.0
	for i in targets.size(): height += Profile.sample(targets[i], point).x * weights[i]
	return height

func sync_collision() -> void:
	if collision == null: return
	if not _installed:
		collision.disabled = true
		return
	if not collision.disabled and _collision_weights == weights: return
	var positions := _flat_grid.duplicate()
	for k in weights.size():
		if weights[k] <= 0: continue
		var heights := _grid_heights[k]
		for i in positions.size(): positions[i].z += heights[i]*weights[k]
	var faces := PackedVector3Array()
	faces.resize(_triangles.size())
	for i in _triangles.size(): faces[i] = positions[_triangles[i]]
	(collision.shape as ConcavePolygonShape3D).set_faces(faces)
	_collision_weights = weights
	collision.disabled = false

func restore() -> void:
	# Cancellation restores synchronously; deferred _exit_tree must not write
	# again after blackout (or another material owner) has taken over.
	# Preparation never touches the node until pose() installs the finished
	# mesh, so dropping staging mid-build leaves originals exactly as they
	# were; the halted effect must then stay inert instead of preparing an
	# empty collision shell on the next tick.
	var staging := not _pending.is_empty() or not _building.is_empty()
	_pending.clear()
	_building = {}
	if staging and not prepared:
		failed = true
	if not _installed: return
	for piece in pieces:
		var node: MeshInstance3D = piece.node
		if is_instance_valid(node):
			node.mesh = piece.original
			node.material_override = piece.material
			node.extra_cull_margin = piece.margin
	if collision != null: collision.disabled = true
	weights.fill(0.0)
	_installed = false

func originals_restored() -> bool:
	for piece in pieces:
		var node: MeshInstance3D = piece.node
		if not is_instance_valid(node): return false
		if node.mesh != piece.original or node.material_override != piece.material or node.extra_cull_margin != piece.margin: return false
	return collision == null or collision.disabled

func _exit_tree() -> void:
	restore()
## The hallway wave uses the same rest-UV and tangent bake as a breathing wall.
## Its private helper yields to the wave's shared frame budget between batches.
func anchor_wave_triplanar(source: StandardMaterial3D, node: MeshInstance3D, arrays: Array,
		check_budget: Callable) -> StandardMaterial3D:
	_building = {"node": node, "material": source, "arrays": arrays,
		"vertices": arrays[Mesh.ARRAY_VERTEX], "normals": arrays[Mesh.ARRAY_NORMAL],
		"cursor": 0, "stage": "anchor"}
	while _building.stage == "anchor":
		await check_budget.call()
		if not _step_anchor():
			_building.clear()
			return null
	var result: StandardMaterial3D = _building.render_material
	_building.clear()
	return result
