extends SceneTree
## Airport collision/visual parity audit. Any body-height collision footprint
## must be substantially covered by visible geometry at the same height.
## Run: godot --headless --path . --script tools/audit_airport_colliders.gd -- [seeds] [radius]


func _mesh_bounds(node: Node, parent_xf: Transform3D, out: Array[AABB]) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.visible:
			out.append(xf * mi.get_aabb())
	for child in node.get_children():
		_mesh_bounds(child, xf, out)


func _barrier_glass(node: Node, report: Dictionary) -> void:
	if node.has_meta("airport_barrier_glass"):
		report["panes"] = int(report["panes"]) + 1
		# Anything subtler still disappears against the black apron at a shallow
		# angle and functions as an invisible wall even when a mesh exists.
		if float(node.get_meta("barrier_alpha", 0.0)) < 0.55:
			report["violations"] = int(report["violations"]) + 1
	for child in node.get_children():
		_barrier_glass(child, report)


func _collision_bounds(cs: CollisionShape3D) -> AABB:
	var size := Vector3.ZERO
	if cs.shape is BoxShape3D:
		size = (cs.shape as BoxShape3D).size
	elif cs.shape is CylinderShape3D:
		var cyl := cs.shape as CylinderShape3D
		size = Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0)
	elif cs.shape is CapsuleShape3D:
		var cap := cs.shape as CapsuleShape3D
		size = Vector3(cap.radius * 2.0, cap.height, cap.radius * 2.0)
	if size == Vector3.ZERO:
		return AABB()
	return cs.transform * AABB(-size * 0.5, size)


func _coverage(collision: AABB, meshes: Array[AABB]) -> float:
	var relevant: Array[AABB] = []
	for source in meshes:
		if source.end.y < collision.position.y - 0.08 \
				or source.position.y > collision.end.y + 0.08:
			continue
		var grown := source.grow(0.07)
		if grown.end.x < collision.position.x or grown.position.x > collision.end.x \
				or grown.end.z < collision.position.z or grown.position.z > collision.end.z:
			continue
		relevant.append(grown)
	if relevant.is_empty():
		return 0.0
	var hit := 0
	var samples := 7
	for ix in samples:
		for iz in samples:
			var px := lerpf(collision.position.x, collision.end.x,
				(float(ix) + 0.5) / float(samples))
			var pz := lerpf(collision.position.z, collision.end.z,
				(float(iz) + 0.5) / float(samples))
			for mesh in relevant:
				if px >= mesh.position.x and px <= mesh.end.x \
						and pz >= mesh.position.z and pz <= mesh.end.z:
					hit += 1
					break
	return float(hit) / float(samples * samples)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 6, 1, 20)
	var radius := clampi(int(args[1]) if args.size() > 1 else 7, 2, 12)
	var failures := 0
	var checked := 0
	var worst: Array = []
	var glass_report := {"panes": 0, "violations": 0}
	for si in seed_count:
		var base := WorldGen.h(984211, si * 41, si * 67, 2401) | 1
		var ws := WorldGen.level_seed(base, 4)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var c := Vector2i(x, z)
				var chunk := Chunk.new(ws, c, 4)
				var meshes: Array[AABB] = []
				_mesh_bounds(chunk, Transform3D.IDENTITY, meshes)
				_barrier_glass(chunk, glass_report)
				for child in chunk.body.get_children():
					var cs := child as CollisionShape3D
					if cs == null or cs.disabled:
						continue
					var bounds := _collision_bounds(cs)
					# Ignore floors, ramps and ceilings; this audit is about
					# barriers encountered by the player's body.
					if bounds.size == Vector3.ZERO or bounds.end.y <= 0.30 \
							or bounds.position.y >= 2.25:
						continue
					checked += 1
					var coverage := _coverage(bounds, meshes)
					if coverage < 0.48:
						worst.append([coverage, base, c,
							WorldGen.cell_style(ws, c, 4), bounds])
						if coverage < 0.20:
							failures += 1
				chunk.free()
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(20, worst.size()):
		var row: Array = worst[i]
		print("  coverage=%.2f seed=%d cell=%s style=%d bounds=%s" % [
			row[0], row[1], row[2], row[3], row[4]])
	print("airport collider audit: %d seeds, radius %d, %d body-height colliders" % [
		seed_count, radius, checked])
	print("  readable collision-glass panes: %d | violations: %d" % [
		glass_report["panes"], glass_report["violations"]])
	failures += int(glass_report["violations"])
	if int(glass_report["panes"]) == 0:
		failures += 1
		print("FAIL — collision-glass visibility audit was not exercised")
	if failures == 0:
		print("  PASS — every airport barrier is backed by visible geometry")
	else:
		print("  FAIL — %d effectively invisible airport barriers" % failures)
	quit(0 if failures == 0 else 1)
