extends Node
## Owns one in-flight CPU calculation. It stays under the scene root so a
## streamed-out corridor can release its work without waiting on a worker.

class Geometry:
	const Profile := preload("res://scripts/hallway_wave_profile.gd")

	var shapes: Array[Array] = []
	var stop := Semaphore.new()

	func calculate(arrays: Array, xf: Transform3D, keys: Array, width: float, height: float) -> void:
		if stop.try_wait(): return
		var samples := _samples(arrays, xf, width, height)
		if samples.is_empty(): return
		for k: int in keys:
			if stop.try_wait(): return
			var shape := _shape(arrays, xf, float(k) / (Profile.KEYS - 1), samples)
			if shape.is_empty(): return
			shapes.append(shape)

	func _samples(arrays: Array, xf: Transform3D, width: float, height: float) -> Dictionary:
		var points := PackedVector3Array()
		var fields := PackedVector3Array()
		var derivatives: Array[Basis] = []
		var along_min := INF
		var along_max := -INF
		const E := 0.005
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cross_sections: Dictionary[Vector2, int] = {}
		for i in vertices.size():
			var p := xf * vertices[i]
			along_min = minf(along_min, p.z)
			along_max = maxf(along_max, p.z)
			points.append(p)
			# The displacement field is constant along the corridor. Grid rows
			# sharing x/y also share both transverse derivatives.
			var xy := Vector2(p.x, p.y)
			var prior: int = cross_sections.get(xy, -1)
			if prior >= 0:
				fields.append(fields[prior])
				derivatives.append(derivatives[prior])
			else:
				cross_sections[xy] = i
				fields.append(Profile.field(p, width, height))
				derivatives.append(Basis(
					(Profile.field(p+Vector3.RIGHT*E,width,height)-Profile.field(p-Vector3.RIGHT*E,width,height))/(2*E),
					(Profile.field(p+Vector3.UP*E,width,height)-Profile.field(p-Vector3.UP*E,width,height))/(2*E),
					Vector3.ZERO))
			if i % 256 == 255 and stop.try_wait(): return {}
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
		var pulses: Dictionary[float, Vector2] = {}
		var points: PackedVector3Array = samples.points
		var fields: PackedVector3Array = samples.fields
		var derivatives: Array[Basis] = samples.derivatives
		for i in vertices.size():
			if i % 256 == 255 and stop.try_wait(): return []
			var p := points[i]
			if not pulses.has(p.z):
				pulses[p.z] = Vector2(Profile.pulse(p.z, at), (Profile.pulse(p.z+0.005, at)-Profile.pulse(p.z-0.005, at))/0.01)
			var wave: Vector2 = pulses[p.z]
			if wave == Vector2.ZERO: continue
			var field := fields[i]
			var derivative := derivatives[i]
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


var _task := -1
var _geometry: Geometry


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func start(geometry: Geometry, arrays: Array, xf: Transform3D, keys: Array, width: float, height: float) -> void:
	_geometry = geometry
	_task = WorkerThreadPool.add_task(geometry.calculate.bind(arrays, xf, keys, width, height),
		false, "Prepare hallway wave vertices")


func collect_if_ready() -> bool:
	if _task < 0: return true
	if not WorkerThreadPool.is_task_completed(_task): return false
	_finish()
	return true


func _finish() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_geometry = null


func retire() -> void:
	if collect_if_ready():
		queue_free()
		return
	_geometry.stop.post()
	set_process(true)


func _process(_delta: float) -> void:
	# Only abandoned jobs poll here. Live jobs are polled by their corridor.
	if collect_if_ready():
		set_process(false)
		queue_free()


func _exit_tree() -> void:
	# The root can leave before another process frame when quitting the game.
	if _task >= 0:
		_geometry.stop.post()
		_finish()
