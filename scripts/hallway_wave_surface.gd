extends Node3D
## Native geometry and matching collision, prepared in bounded main-thread slices.
## Preparation owns a private signal, so freeing this node cancels its coroutines.
signal _prepare_continue
const Profile := preload("res://scripts/hallway_wave_profile.gd")
const Native := preload("res://scripts/environment_breath_surface.gd")
const Placement := preload("res://scripts/environment_breath_placement.gd")
const Layout := preload("res://scripts/hallway_wave_placement.gd")
var frame: Transform3D
var width := 3.55
var height := 3.0
var phase := 0.0
var pieces: Array[Dictionary] = []
var colliders: Array[Dictionary] = []
var attachments: Array[Dictionary] = []
var ready_to_pose := false
var failure := ""
var installed := false
var _last_lo := -1
var prepared := false
var failed := false
var max_prepare_step_ms := 0.0
var _deadline := 0
var _cancelled := false
const PREPARE_BUDGET_USEC := 2000

func begin_setup(chunk: Chunk, axis: int, lane_width: float, lane_height: float) -> void:
	_prepare(chunk, axis, lane_width, lane_height)

func prepare_step() -> void:
	if prepared or failed or _cancelled: return
	var begin := Time.get_ticks_usec()
	_deadline = begin + PREPARE_BUDGET_USEC
	_prepare_continue.emit()
	max_prepare_step_ms = maxf(max_prepare_step_ms, (Time.get_ticks_usec()-begin)/1000.0)

func _budget() -> void:
	if Time.get_ticks_usec() >= _deadline:
		await _prepare_continue

func _prepare(chunk: Chunk, axis: int, lane_width: float, lane_height: float) -> void:
	await _prepare_continue
	var success: bool = await _build(chunk, axis, lane_width, lane_height)
	failed = not success
	prepared = success
	if failed: restore()

func setup(chunk: Chunk, axis: int, lane_width: float, lane_height: float) -> bool:
	begin_setup(chunk, axis, lane_width, lane_height)
	while not prepared and not failed:
		prepare_step()
		await get_tree().process_frame
	return prepared

func _build(chunk: Chunk, axis: int, lane_width: float, lane_height: float) -> bool:
	# Refuse the whole room before touching geometry; skipping the belt alone
	# would still let its supporting floor rise through the stationary deck.
	failure = Layout.exclusions(chunk)
	if not failure.is_empty(): return false
	width = lane_width
	height = lane_height
	frame = Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT) if axis == 1 else Basis.IDENTITY, Vector3(6, chunk._floor_h(), 6))
	# A child helper cannot leak if preparation is cancelled between slices.
	var native := Native.new()
	add_child(native)
	if chunk.theme == 9:
		for node in chunk.find_children("*", "MeshInstance3D", true, false):
			if node.has_meta("pool_water_surface") or node.is_in_group("pool_water_surfaces"):
				failure = "Pool wave is restricted to dry architecture"
				native.free()
				return false
	for node: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree(): continue
		var xf := frame.affine_inverse() * Placement.relative(node, chunk)
		var bounds: AABB = xf * node.mesh.get_aabb()
		if bounds.position.x > width/2+0.65 or bounds.end.x < -width/2-0.65: continue
		if bounds.position.z >= 6 or bounds.end.z <= -6: continue
		var original := node.mesh
		if original is ArrayMesh and original.get_blend_shape_count() > 0:
			failure = "Existing mesh animation needs a dedicated adapter: " + str(node.get_path())
			native.free()
			return false
		var source := original
		if original is BoxMesh or original is PlaneMesh or original is QuadMesh:
			source = original.duplicate()
			var metres := original.get_aabb().size * xf.basis.get_scale().abs()
			source.set("subdivide_width", clampi(ceili(metres.x/0.24)-1, 0, 64))
			if source is BoxMesh:
				source.subdivide_height = clampi(ceili(metres.y/0.24)-1, 0, 64)
				source.subdivide_depth = clampi(ceili(metres.z/0.24)-1, 0, 64)
			else:
				# QuadMesh inherits PlaneMesh: its second subdivision is called
				# depth even when the plane is oriented in XY.
				source.subdivide_depth = clampi(ceili(maxf(metres.y, metres.z)/0.24)-1, 0, 64)
		var motion := ArrayMesh.new()
		motion.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for k in Profile.KEYS: motion.add_blend_shape("wave_%d" % k)
		var materials: Array[Material] = []
		var overrides: Array[Material] = []
		for s in source.get_surface_count():
			if source is ArrayMesh and source.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				failure = "Non-triangle surface: " + str(node.get_path())
				native.free()
				return false
			# Primitive/imported mesh arrays can be shared by multiple instances.
			# Rest attributes and UV baking must never mutate the source arrays.
			var arrays := source.surface_get_arrays(s).duplicate(true)
			var material := node.get_active_material(s)
			overrides.append(node.get_surface_override_material(s))
			if not (material is StandardMaterial3D or material is ShaderMaterial):
				failure = "Unsupported native material: " + str(node.get_path())
				native.free()
				return false
			var flags := 0
			if source is ArrayMesh:
				for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
					flags |= source.surface_get_format(s) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
			if material is StandardMaterial3D and material.uv1_triplanar and _axis_aligned(material, node, arrays):
				material = native._anchor_triplanar(material, node, arrays)
				if material == null:
					failure = "Non-planar triplanar material: " + str(node.get_path())
					native.free()
					return false
			elif material is ShaderMaterial:
				var mutates_vertex := RegEx.new()
				mutates_vertex.compile("\\b(VERTEX|NORMAL|TANGENT|BINORMAL)\\s*[+*/-]?=")
				if mutates_vertex.search(_vertex_body(material.shader.code)) != null:
					failure = "Native vertex animation needs a dedicated adapter: " + str(node.get_path())
					native.free()
					return false
				var rest := PackedFloat32Array()
				var normals := PackedFloat32Array()
				for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]: rest.append_array([v.x,v.y,v.z])
				for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: normals.append_array([n.x,n.y,n.z])
				arrays[Mesh.ARRAY_CUSTOM0] = rest
				arrays[Mesh.ARRAY_CUSTOM1] = normals
				flags &= ~((Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
				flags |= (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
				material = native._wrap_native_shader(material)
			materials.append(material)
			var shapes: Array[Array] = []
			var samples: Dictionary = await _samples(arrays, xf)
			for k in Profile.KEYS:
				shapes.append(await _shape(arrays, xf, float(k)/(Profile.KEYS-1), samples))
				await _budget()
			motion.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes, {}, flags)
			if motion.get_surface_count() != s+1:
				failure = "Could not preserve mesh surface: " + str(node.get_path())
				native.free()
				return false
		pieces.append({"node": node, "original": original, "motion": motion, "materials": materials, "overrides": overrides, "override": node.material_override, "margin": node.extra_cull_margin})
		await _budget()
	native.free()
	for node: CollisionShape3D in chunk.find_children("*", "CollisionShape3D", true, false):
		if node.disabled: continue
		# Area volumes are not solid architecture; concave shapes cannot retain
		# their overlap semantics (notably the Airport travelator triggers).
		if node.get_parent() is Area3D: continue
		if not node.get_parent() is StaticBody3D:
			failure = "Moving physics body needs an adapter: " + str(node.get_path())
			return false
		var xf := frame.affine_inverse() * Placement.relative(node, chunk)
		var original := node.shape
		if original == null: continue
		var bounds: AABB = xf * original.get_debug_mesh().get_aabb()
		if bounds.position.x > width/2+0.65 or bounds.end.x < -width/2-0.65: continue
		if bounds.position.z >= 6 or bounds.end.z <= -6: continue
		var arrays: Array = []
		var primitive: PrimitiveMesh
		if original is ConvexPolygonShape3D:
			arrays = await _convex_arrays(original, xf)
			if arrays.is_empty():
				failure = "Convex surface unavailable or over subdivision budget: " + str(node.get_path())
				return false
		elif original is BoxShape3D:
			var box := BoxMesh.new()
			box.size = original.size
			var metres: Vector3 = original.size * xf.basis.get_scale().abs()
			# Collision need not carry the visual tile grid. 65 cm chords keep
			# floor deviation small while avoiding two full room meshes per tick.
			box.subdivide_width = clampi(ceili(metres.x/0.65)-1, 0, 32)
			box.subdivide_height = clampi(ceili(metres.y/0.65)-1, 0, 16)
			box.subdivide_depth = clampi(ceili(metres.z/0.65)-1, 0, 32)
			primitive = box
		elif original is CylinderShape3D:
			var cylinder := CylinderMesh.new()
			cylinder.height = original.height
			cylinder.top_radius = original.radius
			cylinder.bottom_radius = original.radius
			cylinder.radial_segments = 32
			cylinder.rings = maxi(1, ceili(original.height/0.3))
			primitive = cylinder
		else:
			failure = "Unsupported " + original.get_class() + ": " + str(node.get_path())
			return false
		if primitive != null: arrays = primitive.get_mesh_arrays()
		var keys: Array[PackedVector3Array] = []
		var inverse := xf.affine_inverse()
		for k in Profile.KEYS:
			var points := PackedVector3Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				points.append(inverse * Profile.deform(xf*vertices[i], float(k)/(Profile.KEYS-1), width, height))
				if i % 128 == 127: await _budget()
			keys.append(points)
			await _budget()
		var motion := ConcavePolygonShape3D.new()
		motion.backface_collision = true
		colliders.append({"node": node, "original": original, "motion": motion, "keys": keys, "indices": arrays[Mesh.ARRAY_INDEX]})
	for node: Node3D in chunk.find_children("*", "Node3D", true, false):
		if node is Light3D or node is Label3D:
			var xf := frame.affine_inverse() * Placement.relative(node, chunk)
			var center: Vector3 = node.get_aabb().get_center() if node is Label3D else Vector3.ZERO
			attachments.append({"node": node, "rest": node.transform, "frame": xf, "center": center, "to_parent": node.transform * xf.affine_inverse()})
	# Install at the exact rest pose incrementally, not in the first wave tick.
	for piece in pieces:
		_install_piece(piece)
		installed = true
		await _budget()
	_last_lo = 0
	ready_to_pose = true
	return true

func _vertex_body(code: String) -> String:
	var start := code.find("void vertex()")
	if start < 0: return ""
	var opening := code.find("{", start)
	var end := opening+1
	var depth := 1
	while end < code.length() and depth > 0:
		if code[end] == "{": depth += 1
		if code[end] == "}": depth -= 1
		end += 1
	return code.substr(opening+1, end-opening-2)

func _convex_arrays(shape: ConvexPolygonShape3D, xf: Transform3D) -> Array:
	# Godot 4.7 exposes both wire edges and filled hull faces in the debug
	# mesh. get_faces() selects the triangles, retaining the authored hull.
	var faces := shape.get_debug_mesh().get_faces()
	if faces.is_empty(): return []
	var pending: Array[PackedVector3Array] = []
	for i in range(0, faces.size(), 3): pending.append(PackedVector3Array([faces[i], faces[i+1], faces[i+2]]))
	var vertices := PackedVector3Array()
	while not pending.is_empty():
		if pending.size() % 128 == 0: await _budget()
		if vertices.size()+pending.size()*3 > 30000: return []
		var triangle: PackedVector3Array = pending.pop_back()
		var longest := -1
		var length_sq := 0.45*0.45
		for i in 3:
			var distance := (xf.basis*(triangle[(i+1)%3]-triangle[i])).length_squared()
			if distance > length_sq:
				longest = i
				length_sq = distance
		if longest < 0:
			vertices.append_array(triangle)
		else:
			var a := triangle[longest]
			var b := triangle[(longest+1)%3]
			var c := triangle[(longest+2)%3]
			var middle := (a+b)*0.5
			pending.append(PackedVector3Array([a,middle,c]))
			pending.append(PackedVector3Array([middle,b,c]))
	var indices := PackedInt32Array()
	indices.resize(vertices.size())
	for i in indices.size(): indices[i] = i
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

func _axis_aligned(material: StandardMaterial3D, node: MeshInstance3D, arrays: Array) -> bool:
	var basis := node.global_basis.inverse().transposed() if material.uv1_world_triplanar else Basis.IDENTITY
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		var direction := (basis*n).normalized().abs()
		if direction[direction.max_axis_index()] < 0.9999: return false
	# Curved fixtures keep their native triplanar material; only planar room
	# faces use the exact rest-UV bake, where the projections are equivalent.
	return true

func _samples(arrays: Array, xf: Transform3D) -> Dictionary:
	var points := PackedVector3Array()
	var fields := PackedVector3Array()
	var derivatives: Array[Basis] = []
	var along_min := INF
	var along_max := -INF
	const E := 0.005
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var p := xf * vertices[i]
		along_min = minf(along_min, p.z)
		along_max = maxf(along_max, p.z)
		points.append(p)
		fields.append(Profile.field(p, width, height))
		derivatives.append(Basis(
			(Profile.field(p+Vector3.RIGHT*E,width,height)-Profile.field(p-Vector3.RIGHT*E,width,height))/(2*E),
			(Profile.field(p+Vector3.UP*E,width,height)-Profile.field(p-Vector3.UP*E,width,height))/(2*E),
			Vector3.ZERO))
		if i % 64 == 63: await _budget()
	return {"points": points, "fields": fields, "derivatives": derivatives, "along_min": along_min, "along_max": along_max}

func _shape(arrays: Array, xf: Transform3D, at: float, samples: Dictionary) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = normals
	if not tangents.is_empty(): result[Mesh.ARRAY_TANGENT] = tangents
	var center := lerpf(-6.0-Profile.BAND, 6.0+Profile.BAND, at)
	# Most keys never reach a small prop. Reuse its exact rest arrays instead
	# of transforming tens of thousands of leaves/pebbles for zero movement.
	# Include the derivative stencil so boundary normals remain identical.
	if at <= 0.0 or at >= 1.0 or samples.along_min > center+Profile.BAND+0.005 or samples.along_max < center-Profile.BAND-0.005:
		return result
	var positions := vertices.duplicate()
	var directions := normals.duplicate()
	var ts := tangents.duplicate()
	var inverse := xf.affine_inverse()
	# Most room vertices share the same longitudinal grid coordinates.
	var pulses := {}
	for i in vertices.size():
		if i % 64 == 63: await _budget()
		var p: Vector3 = samples.points[i]
		var field: Vector3 = samples.fields[i]
		var derivative: Basis = samples.derivatives[i]
		if not pulses.has(p.z):
			pulses[p.z] = Vector2(Profile.pulse(p.z, at), (Profile.pulse(p.z+0.005, at)-Profile.pulse(p.z-0.005, at))/0.01)
		var wave: Vector2 = pulses[p.z]
		if wave == Vector2.ZERO: continue
		positions[i] = inverse * (p + field * wave.x)
		var j := inverse.basis * Basis(Vector3.RIGHT+derivative.x*wave.x, Vector3.UP+derivative.y*wave.x, Vector3.BACK+field*wave.y) * xf.basis
		directions[i] = (j.inverse().transposed() * normals[i]).normalized()
		if ts.size() >= (i+1)*4:
			var t := (j * Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])).normalized()
			ts[i*4] = t.x
			ts[i*4+1] = t.y
			ts[i*4+2] = t.z
	result[Mesh.ARRAY_VERTEX] = positions
	result[Mesh.ARRAY_NORMAL] = directions
	if not ts.is_empty(): result[Mesh.ARRAY_TANGENT] = ts
	return result

func _install_piece(piece: Dictionary) -> void:
	var node: MeshInstance3D = piece.node
	node.mesh = piece.motion
	node.material_override = null
	node.extra_cull_margin = piece.margin + Profile.AMPLITUDE*2
	for s in piece.materials.size(): node.set_surface_override_material(s, piece.materials[s])
	for k in Profile.KEYS: node.set_blend_shape_value(k, 1.0 if k == 0 else 0.0)

func pose(value: float) -> void:
	if not ready_to_pose: return
	phase = clampf(value, 0.0, 1.0)
	if phase <= 0 or phase >= 1:
		restore()
		return
	var at := phase*(Profile.KEYS-1)
	var lo := mini(Profile.KEYS-2, floori(at))
	var mix := at-lo
	for piece in pieces:
		var node: MeshInstance3D = piece.node
		if not installed:
			_install_piece(piece)
			node.set_blend_shape_value(0, 0.0)
		elif _last_lo >= 0 and _last_lo != lo:
			node.set_blend_shape_value(_last_lo, 0.0)
			node.set_blend_shape_value(_last_lo+1, 0.0)
		node.set_blend_shape_value(lo, 1.0-mix)
		node.set_blend_shape_value(lo+1, mix)
	for item in attachments:
		var xf: Transform3D = item.frame
		var center: Vector3 = item.center
		var point := xf * center
		if item.node is Label3D:
			xf.basis = Profile.posed_jacobian(point, phase, width, height) * xf.basis
		xf.origin = Profile.posed(point, phase, width, height) - xf.basis * center
		item.node.transform = item.to_parent * xf
	installed = true
	_last_lo = lo

func sync_collision() -> void:
	if not installed: return
	var at := phase*(Profile.KEYS-1)
	var lo := mini(Profile.KEYS-2, floori(at))
	for item in colliders:
		var a: PackedVector3Array = item.keys[lo]
		var b: PackedVector3Array = item.keys[lo+1]
		var points := a.duplicate()
		var mix := at-lo
		# Interpolate each indexed vertex once, not once per triangle corner.
		for i in points.size(): points[i] = a[i].lerp(b[i], mix)
		var indices: PackedInt32Array = item.indices
		var faces := PackedVector3Array()
		faces.resize(indices.size())
		for i in indices.size(): faces[i] = points[indices[i]]
		item.motion.set_faces(faces)
		item.node.shape = item.motion

func restore() -> void:
	if not installed: return
	for item in pieces:
		if not is_instance_valid(item.node): continue
		item.node.mesh = item.original
		item.node.material_override = item.override
		item.node.extra_cull_margin = item.margin
		for s in item.overrides.size(): item.node.set_surface_override_material(s, item.overrides[s])
	for item in colliders:
		if is_instance_valid(item.node): item.node.shape = item.original
	for item in attachments:
		if is_instance_valid(item.node): item.node.transform = item.rest
	installed = false
	_last_lo = -1

func _exit_tree() -> void:
	_cancelled = true
	restore()

func originals_restored() -> bool:
	if installed: return false
	for item in pieces:
		if not is_instance_valid(item.node) or item.node.mesh != item.original or item.node.material_override != item.override: return false
		if item.node.extra_cull_margin != item.margin: return false
		for s in item.overrides.size():
			if item.node.get_surface_override_material(s) != item.overrides[s]: return false
	for item in colliders:
		if not is_instance_valid(item.node) or item.node.shape != item.original: return false
	for item in attachments:
		if not is_instance_valid(item.node) or not item.node.transform.is_equal_approx(item.rest): return false
	return true
