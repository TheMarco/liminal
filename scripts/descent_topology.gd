class_name DescentTopology
extends RefCounted
## Floor-scoped runtime openings layered over deterministic WorldGen geometry.
##
## WorldGen remains pure so seeds and Wander never change. Descent can add a
## supernatural doorway to this resolver, and every runtime consumer shares
## the same answer for rendering, collision, streaming and figure routing.

const SHORTCUT_WIDTH := 3.2
const SHORTCUT_CENTRE := 6.0

var world_seed := 1
var theme := 0
var _shortcuts := {}


func _init(p_world_seed := 1, p_theme := 0) -> void:
	world_seed = p_world_seed
	theme = p_theme


## Mirrors WorldGen's canonical shared-edge convention without exposing its
## private hash helper: east/west share axis 0, south/north share axis 1.
static func canonical_edge(cell: Vector2i, dir: int) -> Dictionary:
	match dir:
		0:
			return {"cell": cell, "axis": 0}
		1:
			return {"cell": cell + Vector2i(-1, 0), "axis": 0}
		2:
			return {"cell": cell, "axis": 1}
		3:
			return {"cell": cell + Vector2i(0, -1), "axis": 1}
	return {"cell": cell, "axis": 0}


static func edge_key(cell: Vector2i, dir: int) -> String:
	var edge := canonical_edge(cell, dir)
	var root: Vector2i = edge["cell"]
	return "%d:%d:%d" % [root.x, root.y, int(edge["axis"])]


func has_shortcut(cell: Vector2i, dir: int) -> bool:
	return _shortcuts.has(edge_key(cell, dir))


func add_shortcut(cell: Vector2i, dir: int) -> bool:
	if dir < 0 or dir >= 4 or has_shortcut(cell, dir) \
			or not WorldGen.is_wall(world_seed, cell, dir, theme):
		return false
	var edge := canonical_edge(cell, dir)
	var key := edge_key(cell, dir)
	_shortcuts[key] = {
		"key": key,
		"cell": edge["cell"],
		"axis": int(edge["axis"]),
		"t": SHORTCUT_CENTRE,
		"w": SHORTCUT_WIDTH,
	}
	return true


func remove_shortcut(cell: Vector2i, dir: int) -> void:
	_shortcuts.erase(edge_key(cell, dir))


func edge_info(cell: Vector2i, dir: int) -> Dictionary:
	var key := edge_key(cell, dir)
	if not _shortcuts.has(key):
		return WorldGen.edge_info(world_seed, cell, dir, theme)
	var shortcut: Dictionary = _shortcuts[key]
	return {
		"wall": false,
		"full_open": false,
		"t": float(shortcut["t"]),
		"w": float(shortcut["w"]),
		"exit_sign": false,
		"runtime_shortcut": true,
	}


func is_wall(cell: Vector2i, dir: int) -> bool:
	return bool(edge_info(cell, dir)["wall"])


func shortcut_count() -> int:
	return _shortcuts.size()


func shortcuts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value in _shortcuts.values():
		out.append((value as Dictionary).duplicate())
	return out
