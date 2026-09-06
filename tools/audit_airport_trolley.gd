extends SceneTree
## Authored trolley bounds, cached resources, nested ranks and supported loads.
## godot --headless --path . --script tools/audit_airport_trolley.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("TROLLEY_AUDIT: " + message)


func local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


func check_load(bag: Node3D, cart: Node3D) -> void:
	var closest := INF
	for mi: MeshInstance3D in bag.find_children("*", "MeshInstance3D", true, false):
		var xf := local_transform(mi, cart)
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var p := xf * vertex
				closest = minf(closest, p.y - (0.322 + 0.055 * p.z))
	check(absf(closest) < 0.012, "Backpack floats above or penetrates its platform")


func run() -> void:
	check(Chunk._prop_preload_paths().has(Chunk.AIRPORT_TROLLEY_PATH), "Missing startup preload")
	check(Chunk.theme_prop_paths(4).has(Chunk.AIRPORT_TROLLEY_PATH), "Missing airport preload")
	var chunk := Chunk.new(WorldGen.level_seed(4242, 4), Vector2i.ZERO, 4)
	var shared_mesh: Mesh
	var shared_material: Material
	var ranks := 0
	var loads := 0
	var empty := 0
	var triangles := 0
	var first := chunk.get_child_count()
	var body_first := chunk.body.get_child_count()
	chunk._level_builder._air_trolley(Vector3.ZERO, 0.0, 7, 0)
	check(first == chunk.get_child_count() and body_first == chunk.body.get_child_count(),
		"Zero-count rank left geometry or a collider")
	for salt in range(7, 19):
		for count in [1, 2, 3]:
			for yaw in [0.0, PI / 2.0, 0.37]:
				first = chunk.get_child_count()
				body_first = chunk.body.get_child_count()
				chunk._level_builder._air_trolley(Vector3(6, 0, 6), yaw, salt, count)
				check(chunk.get_child_count() == first + 1, "Rank must be one complete furnishing")
				check(chunk.body.get_child_count() == body_first + 1, "Expected one collider per rank")
				if chunk.get_child_count() != first + 1 or chunk.body.get_child_count() != body_first + 1:
					continue
				var rank := chunk.get_child(first) as Node3D
				var collider := chunk.body.get_child(body_first) as CollisionShape3D
				var shape := collider.shape as BoxShape3D
				check(shape != null, "Expected simple box collision")
				check(collider.get_meta("furnishing_group", -1) == rank.get_meta("furnishing_group", -2),
					"Rank collision and visuals do not cull together")
				check(rank.get_child_count() == count, "Wrong number of carts in rank")
				var rank_loads := 0
				for k in rank.get_child_count():
					var cart := rank.get_child(k) as Node3D
					check(cart.position.is_equal_approx(Vector3(0, 0, 0.55 * k)), "Nesting pitch changed")
					var mi := cart.find_child("AirportTrolley_Game", true, false) as MeshInstance3D
					check(mi != null, "Authored trolley mesh is missing")
					if mi == null:
						continue
					check(mi.mesh.get_surface_count() == 1, "Trolley uses extra material surfaces")
					var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
					check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
						"Baked PBR maps are missing")
					if shared_mesh == null:
						shared_mesh = mi.mesh
						shared_material = mat
					else:
						check(mi.mesh == shared_mesh and mat == shared_material, "Repeated carts duplicate resources")
					var arrays := mi.mesh.surface_get_arrays(0)
					triangles = arrays[Mesh.ARRAY_INDEX].size() / 3
					check(triangles > 0 and triangles <= 5000, "Trolley exceeded 5,000 triangles")
					if shape != null:
						var xf := collider.transform.affine_inverse() * rank.transform * local_transform(mi, rank)
						var bounds := xf * mi.mesh.get_aabb()
						for axis in 3:
							check(bounds.position[axis] >= -shape.size[axis] * 0.5 - 0.002
								and bounds.end[axis] <= shape.size[axis] * 0.5 + 0.002,
								"Cart extends outside the rank collider")
					for child in cart.get_children():
						if not child.has_meta("airport_trolley_load"):
							continue
						rank_loads += 1
						check(k == count - 1, "Loaded cart would intersect the next cart's sign panel")
						check_load(child as Node3D, cart)
				check(rank_loads <= 1, "More than one backpack spawned per rank")
				loads += rank_loads
				empty += 1 if rank_loads == 0 else 0
				ranks += 1
	check(loads > 0 and empty > 0, "Both loaded and empty carts must be exercised")
	chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("TROLLEY_AUDIT: %d ranks, %d supported loads, %d triangles/cart, failures=%d" % [ranks, loads, triangles, failures])
	quit(1 if failures else 0)
