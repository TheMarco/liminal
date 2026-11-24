extends RefCounted
## Conservative, read-only discovery of usable wall surfaces.

const BAND_FINISHES := {
	0: ["darkwood", "crown"], 4: ["steel"], 5: ["asy_tile"],
	6: ["sch_red", "charcoal"],
	7: ["brass", "mall_trim", "mall_ceramic", "mall_rose_stone", "mall_wall", "mall_brass"],
	8: ["prison_dado", "prison_iron"],
}

class WallClearance:
	var to_face: Transform3D
	var obstacles: Array[AABB] = []
	var bands: Array[Dictionary] = []

static func candidates(chunk: Chunk, kind := "breath", compact := false, camera: Camera3D = null) -> Array[Dictionary]:
	var scanner := SurfaceWear.new()
	scanner.host = chunk
	scanner.ctx = chunk._build_context
	for child in chunk.get_children(): scanner._scan(child, Transform3D.IDENTITY, -1)
	var blockers: Array[Dictionary] = []
	for node: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null and node.visible:
			blockers.append({"mesh": node, "transform": relative(node, chunk), "bounds": node.mesh.get_aabb()})
	if kind == "ceiling": return ceiling_candidates(scanner, blockers, chunk, camera)
	var per_face: Dictionary[SurfaceWear.Face, WallClearance] = {}
	var result := _wall_candidates(scanner.walls, blockers, chunk, kind, compact, camera, per_face)
	if result.is_empty() and not compact:
		result = _wall_candidates(scanner.walls, blockers, chunk, kind, true, camera, per_face)
	return result


static func _wall_candidates(walls: Array[SurfaceWear.Face], blockers: Array[Dictionary],
		chunk: Chunk, kind: String, compact: bool, camera: Camera3D,
		per_face: Dictionary[SurfaceWear.Face, WallClearance]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for face in walls:
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh): continue
		if face.size.x < 2.3 or face.size.y < 1.7: continue
		var clearance: WallClearance = per_face.get(face)
		var base_size := Vector2(minf(3.8, face.size.x - 0.3), minf(2.4, face.size.y - 0.3))
		if compact: base_size *= 0.65
		for lateral in [0.0, -0.22, 0.22]:
			var center: Vector3 = face.center + face.u * (face.size.x - base_size.x) * float(lateral)
			var heights := [face.center.y, chunk._floor_h() + (2.1 if compact else 1.5)] if kind == "breath" else [chunk._floor_h() + (2.1 if compact else 1.5)]
			for height: float in heights:
				center.y = clampf(height, face.center.y - (face.size.y - base_size.y) * 0.5 + 0.05, face.center.y + (face.size.y - base_size.y) * 0.5 - 0.05)
				# Visibility depends on the surface and center, not the fitted size.
				# Skip unseen walls before checking every size against room meshes.
				if camera != null and not visible({"face": face, "center": center}, chunk, camera): continue
				if clearance == null:
					clearance = _wall_clearance(face, blockers, chunk)
					per_face[face] = clearance
				var fitted := fit_wall(face, center, clearance, kind, compact)
				if fitted.is_empty(): continue
				var candidate := {"face": face, "center": center, "size": fitted.size,
					"depth": fitted.depth, "companions": clearance.bands}
				# Filter before the bounded result fills. Outer shell walls and the
				# backs of corridor walls otherwise consume every candidate slot.
				result.append(candidate)
				if result.size() >= 12: return result
	return result


static func fit_wall(face: SurfaceWear.Face, center: Vector3, clearance: WallClearance,
		kind: String, compact: bool) -> Dictionary:
	var offset := center - face.center
	var limit := Vector2(face.size.x - 2.0 * absf(offset.dot(face.u)) - 0.3,
		face.size.y - 2.0 * absf(offset.dot(face.v)) - 0.3)
	var sizes := [Vector2(2.47, 1.56)] if compact else (
		[Vector2(6.0, 3.6), Vector2(5.0, 3.0), Vector2(3.8, 2.4)]
		if kind == "breath" else [Vector2(3.8, 2.4)])
	var depths := [0.35] if compact or kind != "breath" else [0.65, 0.50, 0.35]
	var local_center := clearance.to_face * center
	# Fill the wall first; if the deepest bow is blocked, keep the panel broad
	# and try a shallower breath before reducing its footprint.
	for desired: Vector2 in sizes:
		var size := Vector2(minf(desired.x, limit.x), minf(desired.y, limit.y))
		if size.x < 1.5 or size.y < 1.2: continue
		for depth: float in depths:
			# The moving surface retains 1.6 m of space beyond the deepest bow.
			var envelope := AABB(local_center + Vector3(-size.x/2, -size.y/2, -0.015),
				Vector3(size.x, size.y, depth + 1.615))
			var clear := true
			for bounds in clearance.obstacles:
				if envelope.intersects(bounds):
					clear = false
					break
			if clear: return {"size": size, "depth": depth}
	return {}

static func ceiling_candidates(scanner: SurfaceWear, blockers: Array[Dictionary], chunk: Chunk, camera: Camera3D = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for face: SurfaceWear.Face in scanner.ceilings:
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh): continue
		if face.normal.y > -0.98: continue
		for desired in [Vector2(5.0, 4.0), Vector2(4.0, 3.2),
				Vector2(3.0, 2.5), Vector2(2.0, 1.8)]:
			var size := Vector2(minf(desired.x, face.size.x - 0.3), minf(desired.y, face.size.y - 0.3))
			if size.x < 1.5 or size.y < 1.5: continue
			for ox in [0.0, -0.25, 0.25]:
				for oy in [0.0, -0.25, 0.25]:
					var offset := Vector2(ox, oy) * face.size
					if absf(offset.x) + size.x / 2 + 0.1 > face.size.x / 2 or absf(offset.y) + size.y / 2 + 0.1 > face.size.y / 2: continue
					var center := face.center + face.u * offset.x + face.v * offset.y
					if camera != null and not visible({"face": face, "center": center}, chunk, camera): continue
					var frame := Transform3D(Basis(face.u, face.v, face.normal), center)
					for depth in [0.45, 0.35]:
						# Preserve 2.25 m of standing headroom at the peak.
						if center.y - float(depth) < chunk._floor_h() + 2.25: continue
						# Leave lights, vents, beams, wear overlays and junctions untouched.
						var envelope := AABB(Vector3(-size.x/2-0.08, -size.y/2-0.08, -0.02),
							Vector3(size.x+0.16, size.y+0.16, float(depth)+0.22))
						var clear := true
						for blocker in blockers:
							if blocker.mesh == face.mesh: continue
							if envelope.intersects(frame.affine_inverse() * blocker.transform * blocker.bounds):
								clear = false
								break
						if clear:
							result.append({"face": face, "center": center, "size": size,
								"depth": depth, "companions": []})
							if result.size() >= 6: return result
							break
	return result

static func visible(selection: Dictionary, chunk: Chunk, camera: Camera3D) -> bool:
	var center := chunk.to_global(selection.center)
	var delta := center - camera.global_position
	var ceiling: bool = selection.face.normal.y < -0.98
	if delta.length() < (1.2 if ceiling else 1.5) or delta.length() > 14.0 or not camera.is_position_in_frustum(center): return false
	if camera.get_parent() is Player:
		# The bow becomes legible about two seconds after selection. A nearby
		# wall that the walking player will already have passed is a wasted beat.
		var motion: Vector3 = camera.get_parent().velocity * 2.0
		if (delta - motion).dot(-camera.global_basis.z) < 1.0: return false
	var normal: Vector3 = chunk.global_basis * selection.face.normal
	# A 3.55m corridor leaves only 1.775m to either wall. The old 2m
	# perpendicular minimum excluded both sides even when safely ahead.
	# actor_clear still reserves the swept body before and during the motion.
	if normal.dot(camera.global_position - center) < (0.6 if ceiling else 1.3): return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, center + normal * 0.08)
	if camera.get_parent() is CollisionObject3D: ray.exclude = [camera.get_parent().get_rid()]
	return camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func _wall_clearance(face: SurfaceWear.Face, blockers: Array[Dictionary], chunk: Chunk) -> WallClearance:
	# All candidate patches on a face share its axes. Project each mesh once
	# for this search and move the clearance envelope for each trial position.
	var clearance := WallClearance.new()
	clearance.to_face = Transform3D(Basis(face.u, face.v, face.normal), face.center).affine_inverse()
	var finishes: Array = BAND_FINISHES.get(chunk.theme, [])
	for item in blockers:
		var mesh: MeshInstance3D = item.mesh
		if mesh == face.mesh: continue
		var bounds: AABB = clearance.to_face * item.transform * item.bounds
		if _is_wall_band(mesh, bounds, face.size, chunk, finishes):
			clearance.bands.append(item)
		else:
			clearance.obstacles.append(bounds)
	return clearance


static func _is_wall_band(mesh: MeshInstance3D, bounds: AABB, face_size: Vector2,
		chunk: Chunk, finishes: Array) -> bool:
	# Only generated wall strips: same backing plane and span, shallow depth,
	# direct room child, and a known architectural finish. Furniture stays solid.
	if mesh.get_parent() != chunk or not mesh.mesh is BoxMesh: return false
	if mesh.material_override == null or mesh.material_override.resource_name not in finishes: return false
	# The Mall cornice and its brass lip project farther than a dado.
	var mall_cornice := chunk.theme == 7 and mesh.material_override.resource_name in ["mall_wall", "mall_brass"]
	var max_front := 0.25 if mall_cornice else 0.13
	var max_back := 0.22 if mall_cornice else 0.04
	if bounds.position.z < -0.015 or bounds.position.z > max_back or bounds.end.z > max_front: return false
	if bounds.size.x < face_size.x * 0.95 or bounds.size.y >= bounds.size.x: return false
	if absf(bounds.position.x + face_size.x * 0.5) > 0.08 or absf(bounds.end.x - face_size.x * 0.5) > 0.08: return false
	return bounds.end.y >= -face_size.y * 0.5 and bounds.position.y <= face_size.y * 0.5


static func relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result
