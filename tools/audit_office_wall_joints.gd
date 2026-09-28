extends "res://tools/lib/audit_base.gd"
## Exercise all sixteen wall arrangements around a grid vertex, including
## convex corners, straight runs, T-junctions and free ends. Compare rendered
## and collision occupancy against a continuous, square-corner wall footprint.

class JointChunk extends Chunk:
	var rays := 0 # north, east, south, west

	func _edge_info(at: Vector2i, dir: int) -> Dictionary:
		var ray := -1
		if dir < 2 and at.x + (1 if dir == 0 else 0) == 0:
			if at.y == -1: ray = 0
			elif at.y == 0: ray = 2
		elif dir >= 2 and at.y + (1 if dir == 2 else 0) == 0:
			if at.x == 0: ray = 1
			elif at.x == -1: ray = 3
		return {"full_open": ray < 0 or (rays & (1 << ray)) == 0}


func _contains(boxes: Array[AABB], point: Vector3) -> bool:
	for box in boxes:
		if box.has_point(point): return true
	return false


func _solid(mask: int, point: Vector3) -> bool:
	var n := (mask & 1) != 0
	var e := (mask & 2) != 0
	var s := (mask & 4) != 0
	var w := (mask & 8) != 0
	var in_x := absf(point.x) < Chunk.T
	var in_z := absf(point.z) < Chunk.T
	# Adjacent runs share a filled square corner; solitary ends stop at
	# the vertex and straight runs retain their ordinary rectangular span.
	var corner := (n or s) and (e or w) and in_x and in_z
	return corner or (in_x and ((n and point.z < 0) or (s and point.z > 0))) \
		or (in_z and ((w and point.x < 0) or (e and point.x > 0)))


func run() -> void:
	for mask in 16:
		var visible: Array[AABB] = []
		var collision: Array[AABB] = []
		for cell in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i.ZERO]:
			var chunk := JointChunk.new(240721, cell, 1, null, true)
			chunk.rays = mask
			var origin := Vector3(cell.x * Chunk.S, 0, cell.y * Chunk.S)
			for dir in 4:
				if not chunk._edge_solid(cell, dir): continue
				var plane := Chunk.S - Chunk.T / 2.0 if dir == 0 or dir == 2 else Chunk.T / 2.0
				chunk._wall_seg(dir, plane, 0, Chunk.S, 0, Chunk.HOFF)
			for child in chunk.get_children():
				if child is MeshInstance3D:
					var box: AABB = child.transform * child.get_aabb()
					box.position += origin
					visible.append(box)
			for child in chunk.body.get_children():
				var size: Vector3 = child.shape.size
				collision.append(AABB(child.position + origin - size / 2.0, size))
			chunk.free()
		for x in [-0.225, -0.075, 0.075, 0.225]:
			for z in [-0.225, -0.075, 0.075, 0.225]:
				var point := Vector3(x, 1.5, z)
				var want := _solid(mask, point)
				expect(_contains(visible, point) == want,
					"visual gap/overhang at mask %d point %s" % [mask, point])
				expect(_contains(collision, point) == want,
					"collision gap/overhang at mask %d point %s" % [mask, point])
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("Office wall joints: 16 arrangements, 256 visual/collision samples")
