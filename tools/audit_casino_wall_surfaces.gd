extends "res://tools/lib/audit_base.gd"
## Tall Vegas finishes must meet, not overlap, and only follow real walls.

const EPS := 0.001
var chunks_checked := 0
var samples_checked := 0
var segment_cases := 0
var edge_kinds := {}
var styles := {}


func _bounds(mesh: MeshInstance3D) -> AABB:
	return mesh.transform * mesh.mesh.get_aabb()


func _walls(chunk: Chunk) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in chunk.get_children():
		if child is not MeshInstance3D or child.mesh is not BoxMesh:
			continue
		var mat: Material = child.material_override
		if mat != null and (mat == Mats.band_paint() \
				or mat.resource_name.begins_with("wallpaper_variant_")):
			result.append(child)
	return result


func _coplanar_pairs(walls: Array[MeshInstance3D], label: String) -> void:
	for i in walls.size():
		for j in range(i + 1, walls.size()):
			if walls[i].material_override == walls[j].material_override:
				continue
			var a := _bounds(walls[i])
			var b := _bounds(walls[j])
			for axis in [0, 2]:
				var along := 2 if axis == 0 else 0
				if a.size[axis] > Chunk.T + EPS or b.size[axis] > Chunk.T + EPS:
					continue
				var overlap_y := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
				var overlap_u := minf(a.end[along], b.end[along]) - maxf(a.position[along], b.position[along])
				if overlap_y <= EPS or overlap_u <= EPS:
					continue
				var same_face := absf(a.position[axis] - b.position[axis]) < EPS \
					or absf(a.end[axis] - b.end[axis]) < EPS
				expect(not same_face, "%s has competing coplanar finishes (%s / %s)" % [
					label, walls[i].material_override.resource_name, walls[j].material_override.resource_name])


func _solid_at(chunk: Chunk, point: Vector3) -> bool:
	for child in chunk.body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var box: AABB = child.transform * AABB(-child.shape.size * 0.5, child.shape.size)
			if box.has_point(point):
				return true
	return false


func _structure(ws: int, cell: Vector2i) -> void:
	var chunk := Chunk.new(ws, cell, 0, null, true)
	chunk._build_floor_ceiling()
	chunk._build_walls()
	var walls := _walls(chunk)
	var label := "seed %d cell %s" % [ws, cell]
	_coplanar_pairs(walls, label)
	styles[chunk.style] = true
	for dir in 4:
		var info := chunk._edge_info(cell, dir)
		var closed := bool(info["wall"])
		var full := bool(info["full_open"])
		var neighbour_h := Chunk.cell_ceil_h(ws, cell + WorldGen.DIRV[dir], 0)
		var kind := "wall" if closed else ("open" if full else "door")
		edge_kinds[kind] = true
		var plane := Chunk.S - Chunk.T * 0.5 if dir == 0 or dir == 2 else Chunk.T * 0.5
		var along: Array[float] = [1.0, 3.0, 6.0, 9.0, 11.0]
		if not closed and not full:
			along.append(float(info["t"]))
		for u in along:
			# Stay away from a doorway cut's exact edge/casing.
			if not closed and not full and absf(absf(u - float(info["t"])) - float(info["w"]) * 0.5) < 0.2:
				continue
			for y in [1.5, 2.5, 3.1, 3.3, 4.8, 6.2]:
				if y >= chunk.ceil_h:
					continue
				var expected := closed
				if not closed:
					expected = (chunk.ceil_h - neighbour_h >= 0.1 and y >= neighbour_h) if full else \
						(y >= Chunk.DOOR_TOP or absf(u - float(info["t"])) >= float(info["w"]) * 0.5)
				var point := Vector3(plane, y, u) if dir < 2 else Vector3(u, y, plane)
				var covering := 0
				for wall in walls:
					if _bounds(wall).has_point(point):
						covering += 1
						expect((wall.material_override == Mats.band_paint()) == (y >= Chunk.H),
							"%s dir %d has wrong finish at height %.2f" % [label, dir, y])
				expect(covering == (1 if expected else 0),
					"%s dir %d at %s: expected wall=%s, found %d surfaces" % [label, dir, point, expected, covering])
				expect(_solid_at(chunk, point) == expected,
					"%s dir %d collider no longer matches wall/opening at %s" % [label, dir, point])
				samples_checked += 1
	# Neon can only exist where a wall supports it at the same height.
	for child in chunk.get_children():
		if child is not MeshInstance3D or child.mesh is not BoxMesh \
				or absf(child.position.y - (Chunk.H + 0.18)) > EPS:
			continue
		if child.material_override not in [Mats.neon_pink(), Mats.neon_amber()]:
			continue
		var backing: Vector3 = child.position
		if child.scale.x < child.scale.z:
			backing.x = Chunk.T * 0.5 if backing.x < Chunk.S * 0.5 else Chunk.S - Chunk.T * 0.5
		else:
			backing.z = Chunk.T * 0.5 if backing.z < Chunk.S * 0.5 else Chunk.S - Chunk.T * 0.5
		expect(_solid_at(chunk, backing), "%s has unsupported upper neon" % label)
	chunk.free()
	chunks_checked += 1


func _segments() -> void:
	var cases := {
		"solid": Vector4(0.0, 12.0, 0.0, 6.4),
		"jamb": Vector4(0.0, 4.0, 0.0, 6.4),
		"header": Vector4(4.0, 8.0, 2.25, 6.4),
		"upper": Vector4(1.0, 11.0, 3.2, 6.4),
		"lower": Vector4(1.0, 11.0, 0.0, 3.2),
	}
	for dir in 4:
		for kind in cases:
			var c := Chunk.new(WorldGen.level_seed(240721, 0), Vector2i(-2, 6), 0, null, true)
			c.style = WorldGen.STYLE_GRAND
			var r: Vector4 = cases[kind]
			var plane := Chunk.S - Chunk.T * 0.5 if dir == 0 or dir == 2 else Chunk.T * 0.5
			c._wall_seg(dir, plane, r.x, r.y, r.z, r.w)
			var walls := _walls(c)
			_coplanar_pairs(walls, kind)
			var mesh_volume := 0.0
			var collider_volume := 0.0
			for wall in walls:
				var b := _bounds(wall)
				mesh_volume += b.get_volume()
				expect(b.position.y >= r.z - EPS and b.end.y <= r.w + EPS,
					"%s exceeds requested vertical span" % kind)
				expect(b.position.y >= Chunk.H - EPS if wall.material_override == Mats.band_paint() \
					else b.end.y <= Chunk.H + EPS, "%s finish crosses the datum" % kind)
			for child in c.body.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:
					var size: Vector3 = child.shape.size
					collider_volume += size.x * size.y * size.z
			var expected_volume := (r.y - r.x) * (r.w - r.z) * Chunk.T
			expect(absf(mesh_volume - expected_volume) < EPS, "%s dir %d visual volume changed" % [kind, dir])
			expect(absf(collider_volume - expected_volume) < EPS, "%s dir %d collision volume changed" % [kind, dir])
			expect(walls.size() == (2 if r.z < Chunk.H - EPS and r.w > Chunk.H + EPS else 1),
				"%s dir %d has wrong finish count" % [kind, dir])
			c.free()
			segment_cases += 1


func run() -> void:
	# Keep the exact reported geometry fixture even if the bounded scan changes.
	_structure(WorldGen.level_seed(240721, 0), Vector2i(-2, 6))
	for base in [240721, 1, 9137]:
		var ws := WorldGen.level_seed(base, 0)
		var hits := 0
		for x in range(-8, 9):
			for z in range(-8, 9):
				var cell := Vector2i(x, z)
				if WorldGen.cell_style(ws, cell, 0) not in [WorldGen.STYLE_GRAND, WorldGen.STYLE_BALLROOM]:
					continue
				_structure(ws, cell)
				hits += 1
				if hits >= 8:
					break
			if hits >= 8:
				break
	expect(chunks_checked >= 10, "too few actual tall-room fixtures")
	expect(styles.has(WorldGen.STYLE_GRAND) and styles.has(WorldGen.STYLE_BALLROOM), "missed a tall Vegas style")
	expect(edge_kinds.size() == 3, "missed solid, partial, or fully open boundary cases")
	_segments()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("CASINO_WALL_SURFACES chunks=%d samples=%d segment_cases=%d" % [chunks_checked, samples_checked, segment_cases])
	finish("casino wall surfaces")
