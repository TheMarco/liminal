extends SceneTree
## Smoke-test the generated E-key interactions without relying on a particular
## camera path. Office terminals are deliberately non-interactive authored
## units; swing doors and lift calls remain usable.
## Run: godot --headless --path . --script tools/audit_interactions.gd

const BASE_SEED := 1563747281


func _init() -> void:
	call_deferred("_run")


func _level_seed(theme: int) -> int:
	return WorldGen.level_seed(BASE_SEED, theme)


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


func _door_leaf_moved_away(pivot: Node3D, actor: Node3D, dir: int) -> bool:
	var leaf_local := Vector3(0, 0, 1) if dir == 0 else Vector3.RIGHT
	var parent := pivot.get_parent() as Node3D
	var closed_leaf_world := parent.global_transform.basis * leaf_local
	var open_leaf_world := pivot.global_transform.basis * leaf_local
	var leaf_displacement := open_leaf_world - closed_leaf_world
	var toward_actor := actor.global_position - pivot.global_position
	return leaf_displacement.dot(toward_actor) < -0.01


func _run() -> void:
	var failures := []
	var office_ws := _level_seed(1)
	var terminal_cell := _find_cell(office_ws, 1, func(c: Vector2i) -> bool:
		return WorldGen.room_id(office_ws, c) == c \
			and WorldGen.cell_style(office_ws, c, 1) == WorldGen.OFFICE_CUBICLES)
	var tc := _chunk(office_ws, 1, terminal_cell)
	var workstations := 0
	var authored_terminals := 0
	var custom_screens := 0
	for n in tc.find_children("*", "Node3D", true, false):
		if n.has_meta("office_workstation"):
			workstations += 1
		if str(n.get_meta("attributed_asset", "")) == Chunk.OFFICE_TERMINAL_PATH:
			authored_terminals += 1
		if n.has_meta("office_terminal_custom_screen"):
			custom_screens += 1
	if workstations == 0:
		failures.append("office workstations not built")
	elif authored_terminals != workstations:
		failures.append("not every office workstation uses the authored VT100")
	elif custom_screens != authored_terminals:
		failures.append("not every office VT100 uses the custom Liminal screen")
	if _hit(tc, "E — query terminal") != null:
		failures.append("office still contains an E-query terminal")

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

	var annex_ws := _level_seed(2)
	var annex_lift_cell := _find_cell(annex_ws, 2, func(c: Vector2i) -> bool:
		return WorldGen.elevator_cell(annex_ws, c, 2))
	var alc := _chunk(annex_ws, 2, annex_lift_cell)
	var annex_headers := alc.find_children("*", "MeshInstance3D", true, false) \
		.filter(func(n: Node) -> bool:
			return n.has_meta("elevator_indicator_header"))
	var annex_labels := alc.find_children("*", "Label3D", true, false) \
		.filter(func(n: Node) -> bool:
			return n.has_meta("elevator_indicator_label"))
	if annex_headers.size() != 1 or annex_labels.size() != 1:
		failures.append("Annex elevator indicator was not built exactly once")
	else:
		var header := annex_headers[0] as MeshInstance3D
		var label := annex_labels[0] as Label3D
		var top := float(header.get_meta("elevator_indicator_top", INF))
		var ceiling := float(header.get_meta(
			"elevator_indicator_ceiling", -INF))
		if top > ceiling - 0.039:
			failures.append("Annex elevator indicator still penetrates ceiling")
		if label.position.y >= ceiling - 0.08 \
				or label.font_size > 56:
			failures.append("Annex elevator number is not using compact layout")
		var elevator_wall := WorldGen.anchor_wall(
			annex_ws, annex_lift_cell, 1701, 2)
		for node in alc.find_children("*", "Node3D", true, false):
			if node.has_meta("annex_ac_dir") \
					and int(node.get_meta("annex_ac_dir")) == elevator_wall:
				failures.append("Annex AC overlaps the elevator host wall")

	var door_cell := _find_cell(office_ws, 1, func(c: Vector2i) -> bool:
		return _has_working_door(office_ws, 1, c))
	var dc := _chunk(office_ws, 1, door_cell)
	var door := _hit(dc, "E — open door")
	if door == null:
		failures.append("working swing door not built")
	else:
		var pivot := door.get_parent() as Node3D
		var door_dir := int(pivot.get_meta("door_dir", -1))
		var actor := Node3D.new()
		get_root().add_child(actor)
		var normal_local := Vector3.RIGHT if door_dir == 0 else Vector3(0, 0, 1)
		var normal_world := (dc.global_transform.basis * normal_local).normalized()
		actor.global_position = pivot.global_position + normal_world * 1.5
		var before: float = pivot.rotation.y
		door.interact(actor)
		await create_timer(0.7).timeout
		if door.prompt_text != "E — close door" \
				or absf(pivot.rotation.y - before) < 0.5:
			failures.append("door did not complete its opening motion")
		if not _door_leaf_moved_away(pivot, actor, door_dir):
			failures.append("door opened toward the actor from its first side")
		var first_angle := pivot.rotation.y
		door.interact(actor)
		await create_timer(0.7).timeout
		if absf(pivot.rotation.y) > 0.01 or door.prompt_text != "E — open door":
			failures.append("door did not return to its closed position")
		actor.global_position = pivot.global_position - normal_world * 1.5
		door.interact(actor)
		await create_timer(0.7).timeout
		if not _door_leaf_moved_away(pivot, actor, door_dir):
			failures.append("door opened toward the actor from its opposite side")
		if signf(first_angle) == signf(pivot.rotation.y):
			failures.append("door did not reverse its swing between approach sides")
		actor.queue_free()

	var prison_ws := _level_seed(8)
	var prison_door_cell := _find_cell(prison_ws, 8, func(c: Vector2i) -> bool:
		return _has_working_door(prison_ws, 8, c))
	var pdc := _chunk(prison_ws, 8, prison_door_cell)
	var prison_door := _hit(pdc, "E — open door")
	if prison_door == null:
		failures.append("working prison swing door not built")
	else:
		var authored_leaf := false
		for node in prison_door.get_parent().find_children("*", "Node3D", true,
				false):
			if bool(node.get_meta("interactive_prison_door", false)) \
					and str(node.get_meta("attributed_asset", "")) == \
					Chunk.SOLITARY_CELL_DOOR_PATH:
				authored_leaf = true
				break
		if not authored_leaf:
			failures.append("prison swing door did not use the authored cell leaf")

	print("interaction audit: office=%s elevator=%s annex_elevator=%s door=%s prison_door=%s" % [
		terminal_cell, lift_cell, annex_lift_cell, door_cell, prison_door_cell])
	if failures.is_empty():
		print("  PASS — office uses authored VT100s without E prompts; lift responds; selected door opens away from both approach sides")
	else:
		for failure in failures:
			print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)
