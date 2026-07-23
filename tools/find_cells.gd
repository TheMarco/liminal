extends SceneTree
## Dev: find a cell of a given style near the origin, so a screenshot can be
## aimed at an actual corridor / gym / cafeteria instead of hunting for one.
## Run: godot --headless --path . --script tools/find_cells.gd -- <seed> <theme>

const NAMES := {
	6: "ballroom", 15: "boardroom", 25: "cistern", 47: "foodcourt",
	57: "chapel", 68: "auditorium",
	60: "corridor", 61: "classroom", 62: "cafeteria", 63: "bathroom",
	64: "gym", 65: "library", 66: "lab", 67: "admin",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ws := int(args[0]) if args.size() > 0 else 4242
	var theme := int(args[1]) if args.size() > 1 else 6
	# main.gd salts the base seed per level; mirror it for every non-casino floor.
	if theme != 0:
		var salt := 348039917
		if theme == 2: salt = 715827883
		elif theme == 4: salt = 536870923
		elif theme == 5: salt = 998244353
		elif theme == 6: salt = 179424673
		ws = ((ws ^ salt) & 0x7FFFFFFF) | 1
	var found := {}
	var elevator := WorldGen.NO_HALL
	for r in 14:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := Vector2i(x, y)
				var st: int = WorldGen.cell_style(ws, c, theme)
				if found.has(st):
					if elevator == WorldGen.NO_HALL and WorldGen.elevator_cell(ws, c, theme):
						elevator = c
					continue
				found[st] = c
				if elevator == WorldGen.NO_HALL and WorldGen.elevator_cell(ws, c, theme):
					elevator = c
	if args.size() > 3:
		var q := Vector2i(int(args[2]), int(args[3]))
		print("cell %s: style=%s root=%s size=%d corridor=%d" % [q,
			NAMES.get(WorldGen.cell_style(ws, q, theme), str(WorldGen.cell_style(ws, q, theme))),
			WorldGen.room_id(ws, q), WorldGen.room_size(ws, WorldGen.room_id(ws, q)),
			WorldGen.corridor(ws, q)])
		for dir in 4:
			var edge := WorldGen.edge_info(ws, q, dir, theme)
			if not edge["wall"]:
				print("  edge %d: %s t=%.2f w=%.2f" % [dir,
					"open" if edge["full_open"] else "doorway", edge["t"], edge["w"]])
		quit()
		return
	for st in found:
		var c: Vector2i = found[st]
		print("%-10s cell %s  ->  --pos=%.1f,%.1f" % [
			NAMES.get(st, str(st)), c, float(c.x) * 12.0 + 6.0, float(c.y) * 12.0 + 6.0])
	if elevator != WorldGen.NO_HALL:
		print("elevator   cell %s wall=%d  ->  --pos=%.1f,%.1f" % [elevator,
			WorldGen.anchor_wall(ws, elevator, 1701),
			float(elevator.x) * 12.0 + 6.0, float(elevator.y) * 12.0 + 6.0])
	quit()
