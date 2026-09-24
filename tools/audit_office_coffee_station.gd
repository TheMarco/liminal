extends SceneTree
## A doorway may clear the breakroom counter, but must never leave its
## coffee maker or an invisible collider behind.
## godot --headless --path . --script tools/audit_office_coffee_station.gd

const SEEDS := [258467861, 1021555651]
const COUNTER := "res://models/scenario/office/breakroom_counter.glb"
const MAKER := "res://models/scenario/office/coffee_maker.glb"

var failures: Array[String] = []
var rooms := 0
var full_breakrooms := 0
var stations := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	for base_seed in SEEDS:
		var ws := WorldGen.level_seed(base_seed, 1)
		var sampled := 0
		for x in range(-10, 11):
			for z in range(-10, 11):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell \
						or WorldGen.cell_style(ws, cell, 1) != WorldGen.OFFICE_BREAK:
					continue
				var chunk := Chunk.new(ws, cell, 1)
				_check_room(chunk, base_seed, cell)
				chunk.free()
				rooms += 1
				sampled += 1
				if sampled >= 10:
					break
			if sampled >= 10:
				break
	_check(rooms >= 10, "sample did not contain enough breakrooms")
	_check(stations == full_breakrooms,
		"a full breakroom lost its coffee station")
	for failure in failures:
		print("FAIL " + failure)
	print("office coffee station: %d rooms, %d full breakrooms with stations, %d failures" % [
		rooms, stations, failures.size()])
	Chunk.finish_prop_preloads()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)


func _check_room(chunk: Chunk, base_seed: int, cell: Vector2i) -> void:
	var station: Node3D
	var counter: Node3D
	var maker: Node3D
	for child in chunk.find_children("*", "Node3D", true, false):
		if str(child.get_meta("atomic_furnishing", "")) == "office_coffee_station":
			station = child
		match str(child.get_meta("office_model", "")):
			COUNTER: counter = child
			MAKER: maker = child
	var label := "seed %d cell %s" % [base_seed, cell]
	if chunk._resolved_room_split().is_empty():
		full_breakrooms += 1
		_check(station != null, label + " lost the full breakroom coffee station")
	_check((station != null) == (counter != null) \
		and (station != null) == (maker != null), label + " has an orphaned coffee component")
	_check(chunk.doorway_clearance_violations() == 0,
		label + " blocks a doorway")
	_check(chunk.atomic_furnishing_support_violations() == 0,
		label + " has unsupported furniture or orphaned collision")
	if station == null:
		return
	stations += 1
	_check(station.is_ancestor_of(counter) and station.is_ancestor_of(maker),
		label + " coffee models are not grouped with the counter")
	_check(absf(maker.position.y - 0.9) < 0.001,
		label + " coffee maker is not resting at counter height")
	var group_id := int(station.get_meta("furnishing_group", -1))
	var colliders := 0
	for shape in chunk.body.get_children():
		if int(shape.get_meta("furnishing_group", -1)) == group_id:
			colliders += 1
	_check(colliders == 1, label + " counter collider is not grouped with its visuals")
