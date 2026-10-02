extends RefCounted
## Original indoor kentia silhouette. Opaque folded leaflets give the fronds
## volume without alpha sorting, crossed billboards or per-leaf draw calls.
static var _fronds: ArrayMesh

static func clear_runtime_cache() -> void:
	_fronds = null

static func build(scene: ChunkSceneWriter, p: Vector3, yaw: float) -> void:
	var mark := scene.collider_mark()
	var root := scene.furnishing_pivot(p, yaw, "mall_palm_planter")
	scene.model_cylinder(root, Vector3(0, 0.06, 0), 0.30, 0.12, Mats.mall_rose_stone())
	scene.model_cylinder(root, Vector3(0, 0.34, 0), 0.31, 0.50, Mats.mall_ceramic(true))
	scene.model_cylinder(root, Vector3(0, 0.60, 0), 0.27, 0.035, Mats.darkwood())
	ProceduralDetails.attach(root, "mall_kentia_stems_v1", func(d: ProceduralDetails):
		d.ring(Vector3(0, 0.59, 0), 0.29, 0.028, Mats.mall_brass())
		for stem in 3:
			var base := Vector3(float(stem - 1) * 0.075, 0.61, 0)
			var tip := Vector3(float(stem - 1) * 0.15, 1.91 + float(stem) * 0.12, 0.05)
			d.tube(base, tip, 0.025, Mats.mall_palm_stem())
		for frond in 11:
			for segment in 10:
				d.tube(_spine(frond, float(segment) / 10.0),
					_spine(frond, float(segment + 1) / 10.0), 0.006, Mats.plant())
	)
	if _fronds == null: _fronds = _build_fronds()
	var leaves := MeshInstance3D.new()
	leaves.mesh = _fronds
	leaves.material_override = Mats.mall_palm_leaf()
	root.add_child(leaves)
	# The same collision envelope as the former potted plant. Flexible leaves
	# stay above the player's shoulders and never create an invisible barrier.
	scene.collider_cylinder(p + Vector3(0, 0.5, 0), 0.32, 1.0)
	scene.bind_furnishing_colliders(root, mark)

static func _spine(frond: int, t: float) -> Vector3:
	var a := float(frond) * 2.399963
	var spread := 0.85 + float(frond % 3) * 0.14
	var crown := Vector3(float(frond % 3 - 1) * 0.15, 1.91 + float(frond % 3) * 0.12, 0.05)
	return crown + Vector3(cos(a) * spread * t,
		sin(t * PI * 0.92) * 0.49 - t * t * 0.24, sin(a) * spread * t)

static func _build_fronds() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in 11:
		var a := float(frond) * 2.399963
		var lateral := Vector3(-sin(a), 0, cos(a))
		var forward := Vector3(cos(a), 0, sin(a))
		for j in range(1, 14):
			var t := float(j) / 15.0
			var base := _spine(frond, t)
			var length := sin(t * PI) * 0.32 + 0.055
			for sign_value in [-1.0, 1.0]:
				var side: Vector3 = lateral * sign_value
				var tip: Vector3 = base + side * length + forward * 0.15 + Vector3(0, -0.15 * t, 0)
				var color := Color(0.72 + float(frond % 3) * 0.1, 0.84, 0.68)
				for segment in 4:
					var points: Array[Vector3] = []
					for end in 2:
						var u := float(segment + end) / 4.0
						var mid: Vector3 = base.lerp(tip, u) + Vector3.UP * sin(u * PI) * 0.035
						var width := sin(u * PI) * 0.029
						points.append_array([mid - forward * width,
							mid + Vector3.UP * width * 0.24, mid + forward * width])
					for indices in [[0, 3, 1], [1, 3, 4], [1, 4, 2], [2, 4, 5]]:
						var normal := (points[indices[1]] - points[indices[0]]).cross(points[indices[2]] - points[indices[0]]).normalized()
						if normal.length_squared() < 0.01: continue
						if normal.y < 0: normal = -normal
						for index: int in indices:
							var point := points[index]
							surface.set_normal(normal)
							surface.set_color(color)
							surface.set_uv(Vector2(point.x, point.z))
							surface.add_vertex(point)
	return surface.commit()
