extends SceneTree
## Find actual generated slides by open-edge traversal from Descent arrival.
## Coordinate proximity and a nonzero global prop count do not prove access.
const BASES := [473692151, 240721, 1, 7117, 31337, 1029384756, 918273645,
	246813579, 135792468, 777777777, 314159265, 271828182]
const MAX_HOPS := 8
var failures: Array[String] = []
var totals := [0, 0, 0]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for base: int in BASES:
		var ws := WorldGen.level_seed(base, 9)
		var route := DescentRoute.build(ws, 9, 8)
		# State zero uses the seeded edges. Geometry receives the same resolver
		# and arrival/target flags as ChunkManager's initial Descent build.
		var topology := DescentTopology.new(ws, 9)
		var queue: Array[Vector2i] = [route.origin]
		var distances := {route.origin: 0}
		var seen_rooms := {}
		var nearest := [-1, -1, -1]
		var nearest_cells := [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			var hops: int = distances[cell]
			var owner := WorldGen.room_id(ws, cell)
			if not seen_rooms.has(owner):
				seen_rooms[owner] = true
				if WorldGen.pool_equipment_kind(ws, owner) >= 0:
					var spec := ChunkBuildSpec.new()
					spec.descent = true
					spec.floor_idx = 8
					spec.base_seed = base
					spec.topology = topology
					spec.target = owner == route.target
					spec.target_wall = route.target_wall
					spec.arrival = owner == route.origin and route.origin_wall >= 0
					spec.arrival_wall = route.origin_wall
					var chunk := Chunk.new(ws, owner, 9, spec)
					var plan: Dictionary = chunk.get_meta("pool_equipment_plan", {})
					if not plan.is_empty():
						var kind := int(plan["kind"])
						totals[kind] += 1
						if nearest[kind] < 0:
							nearest[kind] = hops
							nearest_cells[kind] = owner
					chunk.free()
			if hops == MAX_HOPS:
				continue
			for dir in 4:
				var next := cell + Vector2i(WorldGen.DIRV[dir])
				if distances.has(next) or WorldGen.is_wall(ws, cell, dir, 9):
					continue
				distances[next] = hops + 1
				queue.append(next)
		print("POOL AVAILABILITY base=%d arrival=%s nearest_hops=%s cells=%s rooms=%d" % [
			base, route.origin, nearest, nearest_cells, seen_rooms.size()])
		if nearest[1] < 0 and nearest[2] < 0:
			failures.append("No slide within %d open-edge hops of arrival, base=%d" % [MAX_HOPS, base])
		await process_frame
	if totals[1] < 30 or totals[2] < 10:
		failures.append("Local neighborhoods lack slide variety: %s" % totals)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		printerr("FAIL " + failure)
	print("POOL AVAILABILITY %s across %d Descent seeds: board/straight/spiral=%s" % [
		"PASS" if failures.is_empty() else "FAIL", BASES.size(), totals])
	quit(0 if failures.is_empty() else 1)
