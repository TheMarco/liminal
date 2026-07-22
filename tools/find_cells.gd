extends SceneTree
## Dev: find a cell of a given style near the origin, so a screenshot can be
## aimed at an actual corridor / gym / cafeteria instead of hunting for one.
## Run: godot --headless --path . --script tools/find_cells.gd -- <seed> <theme>

const NAMES := {
	60: "corridor", 61: "classroom", 62: "cafeteria", 63: "bathroom",
	64: "gym", 65: "library", 66: "lab", 67: "admin",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ws := int(args[0]) if args.size() > 0 else 4242
	var theme := int(args[1]) if args.size() > 1 else 6
	# main.gd salts the world seed per level; mirror that for level 6
	if theme == 6:
		ws = ((ws ^ 179424673) & 0x7FFFFFFF) | 1
	var found := {}
	for r in 14:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := Vector2i(x, y)
				var st: int = WorldGen.cell_style(ws, c, theme)
				if found.has(st):
					continue
				found[st] = c
	if args.size() > 3:
		var q := Vector2i(int(args[2]), int(args[3]))
		print("cell %s: style=%s root=%s size=%d corridor=%d" % [q,
			NAMES.get(WorldGen.cell_style(ws, q, theme), str(WorldGen.cell_style(ws, q, theme))),
			WorldGen.room_id(ws, q), WorldGen.room_size(ws, WorldGen.room_id(ws, q)),
			WorldGen.corridor(ws, q)])
		quit()
		return
	for st in found:
		var c: Vector2i = found[st]
		print("%-10s cell %s  ->  --pos=%.1f,%.1f" % [
			NAMES.get(st, str(st)), c, float(c.x) * 12.0 + 6.0, float(c.y) * 12.0 + 6.0])
	quit()
