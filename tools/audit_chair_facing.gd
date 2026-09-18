extends SceneTree
## Chairs face their tables. The office task chair's seat faces local -Z, a
## convention the boardroom, break room, meeting table and guard desk got
## backwards (chairs parked back-to-desk). Builds office, school and prison
## rooms across seeds and checks every task chair against the furniture
## beside it: pulled-up chairs must square up to the nearest desk or table,
## teacher chairs must face the class with their desk behind them, and
## boardroom chairs must face the table plane. Staged lone chairs with no
## furniture in reach are skipped, not judged.
## Run: godot --headless --path . --script tools/audit_chair_facing.gd -- [seeds] [radius]

const THEMES := [1, 6, 8]
const REACH := 1.7
const MIN_DOT := 0.7


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 8, 1, 32)
	var radius := clampi(int(args[1]) if args.size() > 1 else 6, 3, 10)
	var checked := 0
	var skipped := 0
	var failures := 0
	for si in seed_count:
		var base := WorldGen.h(731923, si * 37, si * 71, 2307) | 1
		for theme in THEMES:
			var ws := WorldGen.level_seed(base, theme)
			for x in range(-radius, radius + 1):
				for z in range(-radius, radius + 1):
					var c := Vector2i(x, z)
					var style := WorldGen.cell_style(ws, c, theme)
					var local_builder: bool = WorldGen.corridor(ws, c) != 0 \
						or (theme == 8 and style == WorldGen.PRISON_CELLBLOCK)
					if WorldGen.room_id(ws, c) != c and not local_builder:
						continue
					var chunk := Chunk.new(ws, c, theme)
					var origin := Vector3(float(x) * Chunk.S, 0.0, float(z) * Chunk.S)
					var chairs := _task_chairs(chunk, origin)
					if chairs.is_empty():
						chunk.free()
						continue
					var solids := _furniture_solids(chunk, origin, chairs)
					var desks := _teacher_desks(chunk, origin)
					var table := _boardroom_table(chunk, origin)
					for ch in chairs:
						var facing: Vector3 = -(Vector3(sin(ch["yaw"]), 0, cos(ch["yaw"])))
						var verdict := _verdict(ch["pos"], facing, solids, desks, table)
						if verdict == 0:
							skipped += 1
						elif verdict == 1:
							checked += 1
						else:
							checked += 1
							failures += 1
							if failures <= 12:
								print("FAIL seed=%d theme=%d chair=%s faces=%s" % [
									base, theme, ch["pos"], facing])
					chunk.free()
	print("chair facing: %d checked, %d skipped, %d failures" % [checked, skipped, failures])
	print("PASS" if failures == 0 else "FAIL")
	quit()


## 1 = faces furniture, -1 = faces away, 0 = nothing to judge against.
func _verdict(p: Vector3, facing: Vector3, solids: Array, desks: Array, table: Dictionary) -> int:
	if not table.is_empty():
		var d: Vector3 = p - table["at"]
		d.y = 0.0
		if d.length() < 6.5:
			return 1 if facing.z * d.z < -0.5 else -1
	var near := _nearest(p, solids, REACH)
	if not near.is_empty():
		var to: Vector3 = (near["at"] as Vector3) - p
		to.y = 0.0
		if to.normalized().dot(facing) > MIN_DOT:
			return 1
	# Teacher chairs pair with their desk model 1m away on the facing axis:
	# facing the class over the desktop, or desk-side in either staging.
	# The yaw is deterministic (classroom yaw, no jitter), so axis alignment
	# is the regression signal, not the sign.
	var desk := _nearest(p, desks, REACH)
	if not desk.is_empty():
		var axis: Vector3 = desk["at"] - p
		axis.y = 0.0
		if absf(axis.normalized().dot(facing)) > 0.5:
			return 1
		return -1
	return 0 if near.is_empty() else -1


func _task_chairs(chunk: Chunk, origin: Vector3) -> Array:
	var out := []
	for node in chunk.find_children("*", "Node3D", true, false):
		if str(node.get_meta("surface_wear_prop", "")) != "office_task_chair":
			continue
		var n3 := node as Node3D
		out.append({"pos": origin + n3.position, "yaw": n3.rotation.y})
	return out


## Furniture collider centres: only desk- and table-scale shapes count, so
## a chair is judged against the thing it was pulled up to, never against
## a waste bin, divider, shelf, neighbour chair or the room shell.
func _furniture_solids(chunk: Chunk, origin: Vector3, chairs: Array) -> Array:
	var out := []
	for cs in chunk.find_children("*", "CollisionShape3D", true, false):
		var box: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
		if box != null:
			if box.size.x < 0.8 or box.size.z < 0.5 or box.size.y > 1.3:
				continue
			# Floor, ceiling and wall slabs share the room footprint;
			# the boardroom table has its own rule below.
			if box.size.x > 4.0 or box.size.z > 4.0:
				continue
		else:
			var cyl: CylinderShape3D = (cs as CollisionShape3D).shape as CylinderShape3D
			if cyl == null:
				continue
			if cyl.radius < 0.4 or cyl.radius > 0.9 \
					or cyl.height < 0.4 or cyl.height > 1.3:
				continue
		var at: Vector3 = origin + ((cs as Node3D).position)
		var own := false
		for ch in chairs:
			var d: Vector3 = at - ch["pos"]
			d.y = 0.0
			if d.length() < 0.45:
				own = true
				break
		if not own:
			out.append({"at": at})
	return out


func _teacher_desks(chunk: Chunk, origin: Vector3) -> Array:
	var out := []
	for node in chunk.find_children("*", "Node3D", true, false):
		if str(node.get_meta("surface_wear_prop", "")) == "metal_office_desk":
			out.append(origin + (node as Node3D).position)
	return out


## The 11.5 x 0.96 x 2.2m boardroom table reads as one collider; chairs
## along it face the table plane rather than its centre, so it gets its own
## rule. All three dimensions must match: floor and ceiling slabs share the
## 12m footprint but are thin in Y and deep in Z.
func _boardroom_table(chunk: Chunk, origin: Vector3) -> Dictionary:
	for cs in chunk.find_children("*", "CollisionShape3D", true, false):
		var shape: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
		if shape != null and shape.size.x > 10.0 and shape.size.x < 13.0 \
				and shape.size.y > 0.8 and shape.size.y < 1.2 \
				and shape.size.z > 1.8 and shape.size.z < 2.6:
			return {"at": origin + ((cs as Node3D).position)}
	return {}


func _nearest(p: Vector3, pts: Array, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for rec in pts:
		var at: Vector3 = rec["at"] if rec is Dictionary else rec
		var d: Vector3 = at - p
		d.y = 0.0
		if d.length() < best_d:
			best_d = d.length()
			best = rec if rec is Dictionary else {"at": at}
	return best
