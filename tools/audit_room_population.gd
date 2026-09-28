extends SceneTree
## Office rooms and Airport overflow halls need their core furniture after
## doorway clearance. The Annex keeps its intentional vacant rooms.
## godot --headless --path . --script tools/audit_room_population.gd --nologo

const SEEDS := [258467861, 1021555651]
const OFFICE_STYLES := [WorldGen.OFFICE_EMPTY, WorldGen.OFFICE_CUBICLES,
	WorldGen.OFFICE_STORAGE, WorldGen.OFFICE_BREAK, WorldGen.OFFICE_BOARDROOM]
const DESK_PATH := "res://models/scenario/office/office_desk.glb"
const BREAK_PATH := "res://models/scenario/office/breakroom_table.glb"
const BOARD_PATH := "res://models/scenario/office/boardroom_table.glb"

var failures: Array[String] = []
var rooms := 0
var large_offices := 0
var airport_halls := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _groups(chunk: Chunk, kind: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in chunk.find_children("*", "Node3D", true, false):
		if str(node.get_meta("atomic_furnishing", "")) == kind:
			result.append(node as Node3D)
	return result


func _contains_model(group: Node, path: String) -> bool:
	for node in group.find_children("*", "Node3D", true, false):
		if str(node.get_meta("office_model", "")) == path:
			return true
	return false


func _chairs_supported(chunk: Chunk, label: String) -> void:
	for node in chunk.find_children("*", "Node3D", true, false):
		if str(node.get_meta("surface_wear_prop", "")) != "office_task_chair":
			continue
		var parent := node.get_parent()
		var supported := false
		while parent != null and parent != chunk:
			if str(parent.get_meta("atomic_furnishing", "")) in [
					"office_workstation", "office_small_workstation",
					"office_break_table_set", "office_boardroom_table_set"]:
				supported = true
				break
			parent = parent.get_parent()
		_check(supported, label + " has a chair without its desk or table")


func _check_office(ws: int, cell: Vector2i, style: int) -> void:
	var chunk := Chunk.new(ws, cell, 1)
	var label := "Office seed %d cell %s style %d" % [ws, cell, style]
	var span := chunk._room_span()
	var large := chunk.room_n >= 2 or span.x > 12.1 or span.y > 12.1
	var workstations := _groups(chunk, "office_workstation")
	var shelves := _groups(chunk, "shelf_unit")
	var tables := _groups(chunk, "office_break_table_set")
	var board_tables := _groups(chunk, "office_boardroom_table_set")
	_chairs_supported(chunk, label)
	_check(chunk.doorway_clearance_violations() == 0,
		label + " blocks a doorway")
	_check(chunk.atomic_furnishing_support_violations() == 0,
		label + " has unsupported or orphaned furniture")
	if style == WorldGen.OFFICE_CUBICLES or style == WorldGen.OFFICE_EMPTY and large:
		_check(not workstations.is_empty(), label + " has no desks")
		for desk in workstations:
			_check(_contains_model(desk, DESK_PATH), label + " desk assembly lost its desk")
	elif style == WorldGen.OFFICE_STORAGE or style == WorldGen.OFFICE_EMPTY:
		_check(shelves.size() >= (2 if large else 1), label + " has too few stock racks")
	elif style == WorldGen.OFFICE_BREAK:
		_check(tables.size() >= (2 if large else 1), label + " has too few seating islands")
		for table in tables:
			_check(_contains_model(table, BREAK_PATH), label + " break table has only chairs")
	elif style == WorldGen.OFFICE_BOARDROOM:
		_check(board_tables.size() == 1, label + " lost its boardroom table")
		for table in board_tables:
			_check(_contains_model(table, BOARD_PATH), label + " boardroom has only chairs")
	rooms += 1
	if large:
		large_offices += 1
	chunk.free()


func _check_airport(ws: int, cell: Vector2i) -> void:
	var chunk := Chunk.new(ws, cell, 4)
	var rows := _groups(chunk, "airport_seat_row")
	var label := "Airport seed %d cell %s hall" % [ws, cell]
	_check(rows.size() >= mini(2, chunk.room_n),
		label + " has too little seating for its size")
	_check(chunk.doorway_clearance_violations() == 0,
		label + " blocks a doorway")
	_check(chunk.atomic_furnishing_support_violations() == 0,
		label + " has unsupported or orphaned seating")
	rooms += 1
	airport_halls += 1
	chunk.free()


func _run() -> void:
	for base in SEEDS:
		for theme in [1, 4]:
			var ws := WorldGen.level_seed(base, theme)
			var sampled := {}
			for x in range(-12, 13):
				for z in range(-12, 13):
					var cell := Vector2i(x, z)
					if WorldGen.room_id(ws, cell) != cell \
							or not WorldGen.room_split(ws, cell, theme).is_empty():
						continue
					var style := WorldGen.cell_style(ws, cell, theme)
					if theme == 1 and style not in OFFICE_STYLES:
						continue
					if theme == 4 and style != WorldGen.AIR_HALL:
						continue
					var size := WorldGen.room_size(ws, cell)
					var key := "%d:%d:%d" % [theme, style,
						1 if size >= 4 else (2 if size >= 2 else 0)]
					if int(sampled.get(key, 0)) >= 3:
						continue
					if theme == 1:
						_check_office(ws, cell, style)
					else:
						_check_airport(ws, cell)
					sampled[key] = int(sampled.get(key, 0)) + 1
	_check(large_offices > 0, "sample found no large Office room")
	_check(airport_halls > 0, "sample found no Airport overflow hall")
	for failure in failures:
		print("FAIL " + failure)
	print("room population: %d rooms, %d large offices, %d airport halls, %d failures" % [
		rooms, large_offices, airport_halls, failures.size()])
	Chunk.finish_prop_preloads()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)
