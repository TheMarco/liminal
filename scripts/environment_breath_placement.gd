extends RefCounted
## Conservative, read-only discovery of usable wall surfaces.

static func candidates(chunk: Chunk, kind := "breath", compact := false) -> Array[Dictionary]:
	var scanner := SurfaceWear.new()
	scanner.host = chunk
	scanner.ctx = chunk._build_context
	for child in chunk.get_children(): scanner._scan(child, Transform3D.IDENTITY, -1)
	var blockers: Array[Dictionary] = []
	for node: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null and node.visible:
			blockers.append({"mesh": node, "transform": relative(node, chunk), "bounds": node.mesh.get_aabb()})
	if kind == "ceiling": return ceiling_candidates(scanner, blockers, chunk)
	var result: Array[Dictionary] = []
	for face: SurfaceWear.Face in scanner.walls:
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh): continue
		if face.size.x < 2.3 or face.size.y < 1.7: continue
		var bands := wall_bands(face, blockers, chunk)
		var size := Vector2(minf(3.8, face.size.x - 0.3), minf(2.4, face.size.y - 0.3))
		if compact: size *= 0.65
		for lateral in [0.0, -0.22, 0.22]:
			var center: Vector3 = face.center + face.u * (face.size.x - size.x) * float(lateral)
			center.y = clampf(chunk._floor_h() + (2.1 if compact else 1.5), face.center.y - (face.size.y - size.y) * 0.5 + 0.05, face.center.y + (face.size.y - size.y) * 0.5 - 0.05)
			var frame := Transform3D(Basis(face.u, face.v, face.normal), center)
			# Keep 1.6m of empty space in front of the maximum live 35cm bow.
			var envelope := AABB(Vector3(-size.x/2, -size.y/2, -0.015), Vector3(size.x, size.y, 1.965))
			var clear := true
			for blocker in blockers:
				if blocker.mesh == face.mesh or bands.has(blocker): continue
				var bounds: AABB = frame.affine_inverse() * blocker.transform * blocker.bounds
				if envelope.intersects(bounds):
					clear = false
					break
			if clear:
				result.append({"face": face, "center": center, "size": size, "depth": 0.35, "companions": bands})
				if result.size() >= 12: return result
	return candidates(chunk, kind, true) if result.is_empty() and not compact else result

static func ceiling_candidates(scanner: SurfaceWear, blockers: Array[Dictionary], chunk: Chunk) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for face: SurfaceWear.Face in scanner.ceilings:
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh): continue
		# Preserve standing headroom even at the maximum runtime depth.
		if face.normal.y > -0.98 or face.center.y - 0.35 < chunk._floor_h() + 2.25: continue
		for desired in [Vector2(3.0, 2.5), Vector2(2.0, 1.8)]:
			var size := Vector2(minf(desired.x, face.size.x - 0.3), minf(desired.y, face.size.y - 0.3))
			if size.x < 1.5 or size.y < 1.5: continue
			for ox in [0.0, -0.25, 0.25]:
				for oy in [0.0, -0.25, 0.25]:
					var offset := Vector2(ox, oy) * face.size
					if absf(offset.x) + size.x / 2 + 0.1 > face.size.x / 2 or absf(offset.y) + size.y / 2 + 0.1 > face.size.y / 2: continue
					var center := face.center + face.u * offset.x + face.v * offset.y
					var frame := Transform3D(Basis(face.u, face.v, face.normal), center)
					# Leave lights, vents, beams, wear overlays and wall junctions
					# completely untouched; do not deform through attached fixtures.
					var envelope := AABB(Vector3(-size.x/2-0.08, -size.y/2-0.08, -0.02), Vector3(size.x+0.16, size.y+0.16, 0.57))
					var clear := true
					for blocker in blockers:
						if blocker.mesh == face.mesh: continue
						if envelope.intersects(frame.affine_inverse() * blocker.transform * blocker.bounds):
							clear = false
							break
					if clear:
						result.append({"face": face, "center": center, "size": size, "depth": 0.35, "companions": []})
						if result.size() >= 6: return result
	return result

static func visible(selection: Dictionary, chunk: Chunk, camera: Camera3D) -> bool:
	var center := chunk.to_global(selection.center)
	var delta := center - camera.global_position
	var ceiling: bool = selection.face.normal.y < -0.98
	if delta.length() < (1.2 if ceiling else 3.5) or delta.length() > 14.0 or not camera.is_position_in_frustum(center): return false
	var normal: Vector3 = chunk.global_basis * selection.face.normal
	if normal.dot(camera.global_position - center) < (0.6 if ceiling else 2.0): return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, center + normal * 0.08)
	if camera.get_parent() is CollisionObject3D: ray.exclude = [camera.get_parent().get_rid()]
	return camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func wall_bands(face: SurfaceWear.Face, blockers: Array[Dictionary], chunk: Chunk) -> Array[Dictionary]:
	# Only generated wall strips: same backing plane and span, shallow depth,
	# direct room child, and a known architectural finish. Furniture stays solid.
	var finishes: Array = {
		0: ["darkwood", "crown"], 4: ["steel"], 5: ["asy_tile"],
		6: ["sch_red", "charcoal"], 7: ["brass", "mall_trim"],
		8: ["prison_dado", "prison_iron"],
	}.get(chunk.theme, [])
	var bands: Array[Dictionary] = []
	var wall_frame := Transform3D(Basis(face.u, face.v, face.normal), face.center)
	for item: Dictionary in blockers:
		var mesh: MeshInstance3D = item.mesh
		if mesh == face.mesh or mesh.get_parent() != chunk or not mesh.mesh is BoxMesh:
			continue
		if mesh.material_override == null or not mesh.material_override.resource_name in finishes:
			continue
		var bounds: AABB = wall_frame.affine_inverse() * item.transform * item.bounds
		if bounds.position.z < -0.015 or bounds.position.z > 0.04 or bounds.end.z > 0.13:
			continue
		if bounds.size.x < face.size.x * 0.95 or bounds.size.y >= bounds.size.x:
			continue
		if absf(bounds.position.x + face.size.x * 0.5) > 0.08 or absf(bounds.end.x - face.size.x * 0.5) > 0.08:
			continue
		if bounds.end.y < -face.size.y * 0.5 or bounds.position.y > face.size.y * 0.5:
			continue
		bands.append(item)
	return bands


static func relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result
