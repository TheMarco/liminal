extends SceneTree
## Smoke-test the three generated E-key interactions without relying on a
## particular camera path: one terminal record, one swing door, one lift call.
## Run: godot --headless --path . --script tools/audit_interactions.gd

const BASE_SEED := 1563747281


func _init() -> void:
	call_deferred("_run")


func _level_seed(theme: int) -> int:
	if theme == 0:
		return BASE_SEED
	var salt := 348039917
	if theme == 2: salt = 715827883
	elif theme == 4: salt = 536870923
	elif theme == 5: salt = 998244353
	elif theme == 6: salt = 179424673
	return ((BASE_SEED ^ salt) & 0x7FFFFFFF) | 1


func _find_cell(ws: int, theme: int, predicate: Callable) -> Vector2i:
	for r in 33:
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if maxi(absi(x), absi(z)) != r:
					continue
				var c := Vector2i(x, z)
				if predicate.call(c):
					return c
	return WorldGen.NO_HALL


func _has_working_door(ws: int, theme: int, c: Vector2i) -> bool:
	for dir in [0, 2]:
		var info := WorldGen.edge_info(ws, c, dir, theme)
		if info["wall"] or info["full_open"] or float(info["w"]) > 2.25:
			continue
		if float(info["w"]) - 0.12 >= 0.82 \
				and WorldGen.h(ws, c.x, c.y, 1760 + dir + theme * 11) % 100 < 14:
			return true
	return false


func _chunk(ws: int, theme: int, c: Vector2i) -> Chunk:
	var chunk := Chunk.new(ws, c, theme)
	chunk.position = Vector3(float(c.x) * 12.0, 0, float(c.y) * 12.0)
	get_root().add_child(chunk)
	return chunk


func _hit(chunk: Chunk, prefix: String) -> Interactable:
	for n in chunk.find_children("*", "Interactable", true, false):
		var hit := n as Interactable
		if hit.prompt_text.begins_with(prefix):
			return hit
	return null


func _run() -> void:
	var failures := []
	var office_ws := _level_seed(1)
	var terminal_cell := _find_cell(office_ws, 1, func(c: Vector2i) -> bool:
		return WorldGen.room_id(office_ws, c) == c \
			and WorldGen.cell_style(office_ws, c, 1) == WorldGen.OFFICE_CUBICLES)
	var tc := _chunk(office_ws, 1, terminal_cell)
	var terminal := _hit(tc, "E — query terminal")
	if terminal == null:
		failures.append("usable terminal not built")
	else:
		var page := int(terminal.get_meta("page", -1))
		terminal.interact(null)
		if int(terminal.get_meta("page", -1)) == page \
				or terminal.prompt_text != "E — next record":
			failures.append("terminal did not advance its record")

	var lift_cell := _find_cell(office_ws, 1, func(c: Vector2i) -> bool:
		return WorldGen.elevator_cell(office_ws, c, 1))
	var lc := _chunk(office_ws, 1, lift_cell)
	var lift := _hit(lc, "E — elevator")
	if lift == null:
		failures.append("working elevator not built")
	else:
		lift.interact(null)
		if lift.enabled or lift.prompt_text != "ELEVATOR ARRIVING":
			failures.append("elevator call did not lock and begin arrival")

	var door_cell := _find_cell(office_ws, 1, func(c: Vector2i) -> bool:
		return _has_working_door(office_ws, 1, c))
	var dc := _chunk(office_ws, 1, door_cell)
	var door := _hit(dc, "E — open door")
	if door == null:
		failures.append("working swing door not built")
	else:
		var before: float = (door.get_parent() as Node3D).rotation.y
		door.interact(null)
		await create_timer(0.7).timeout
		if door.prompt_text != "E — close door" \
				or absf((door.get_parent() as Node3D).rotation.y - before) < 0.5:
			failures.append("door did not complete its opening motion")

	print("interaction audit: terminal=%s elevator=%s door=%s" % [
		terminal_cell, lift_cell, door_cell])
	if failures.is_empty():
		print("  PASS — terminal advances; lift responds; selected door opens")
	else:
		for failure in failures:
			print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)
