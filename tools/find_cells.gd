extends SceneTree
## Dev: find a cell of a given style near the origin, so a screenshot can be
## aimed at an actual corridor / gym / cafeteria instead of hunting for one.
## Run: godot --headless --path . --script tools/find_cells.gd -- <seed> <theme>

const NAMES := {
	6: "ballroom", 15: "boardroom", 25: "cistern", 47: "foodcourt",
	57: "chapel", 68: "auditorium",
	60: "corridor", 61: "classroom", 62: "cafeteria", 63: "bathroom",
	64: "gym", 65: "library", 66: "lab", 67: "admin",
	70: "mall corridor", 71: "mall store", 72: "anchor store",
	73: "mall food court", 74: "mall atrium", 75: "mall service",
	76: "mall kiosks", 77: "mall cinema",
	80: "prison corridor", 81: "cellblock", 82: "cells", 83: "mess hall",
	84: "showers", 85: "guard room", 86: "industry",
	87: "visitation", 88: "rotunda",
}
const ANCHOR_LOCAL_STYLES := [
	WorldGen.SEWER_BASIN,
	WorldGen.AIR_GATE, WorldGen.AIR_CHECKIN, WorldGen.AIR_ESCALATOR,
	WorldGen.AIR_TRANSIT,
	WorldGen.MALL_CORRIDOR, WorldGen.MALL_STORE, WorldGen.MALL_FOODCOURT,
	WorldGen.MALL_ATRIUM, WorldGen.MALL_CINEMA,
	WorldGen.PRISON_CORRIDOR, WorldGen.PRISON_CELLBLOCK,
	WorldGen.PRISON_CELLS, WorldGen.PRISON_SHOWER, WorldGen.PRISON_GUARD,
	WorldGen.PRISON_VISITATION, WorldGen.PRISON_INDUSTRY,
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ws := int(args[0]) if args.size() > 0 else 4242
	var theme := int(args[1]) if args.size() > 1 else 6
	# main.gd salts the base seed per level; mirror it for every non-casino floor.
	ws = WorldGen.level_seed(ws, theme)
	var found := {}
	var found_score := {}
	var elevator := WorldGen.NO_HALL
	var camera_corridor := WorldGen.NO_HALL
	var projector_classroom := WorldGen.NO_HALL
	var mall_storefront := WorldGen.NO_HALL
	var mall_storefront_wall := -1
	var mall_exit := WorldGen.NO_HALL
	var mall_exit_wall := -1
	for r in 14:
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := Vector2i(x, y)
				var st: int = WorldGen.cell_style(ws, c, theme)
				if camera_corridor == WorldGen.NO_HALL and st == WorldGen.SCH_CORRIDOR \
						and WorldGen.r01(ws, c.x, c.y, 309) < 0.36:
					camera_corridor = c
				var root := WorldGen.room_id(ws, c)
				var n := WorldGen.room_size(ws, root)
				if projector_classroom == WorldGen.NO_HALL \
						and st == WorldGen.SCH_CLASSROOM and c == root \
						and WorldGen.anchor_wall(ws, c, 72) >= 0 \
						and WorldGen.r01(ws, c.x, c.y, 74) < 0.5:
					projector_classroom = c
				if theme == 7 and (mall_storefront == WorldGen.NO_HALL \
						or mall_exit == WorldGen.NO_HALL):
					for dir in 4:
						var edge := WorldGen.edge_info(ws, c, dir, theme)
						var retail := st == WorldGen.MALL_CORRIDOR \
							or st == WorldGen.MALL_ATRIUM \
							or st == WorldGen.MALL_KIOSKS
						if mall_storefront == WorldGen.NO_HALL and retail \
								and edge["wall"] \
								and WorldGen.r01(ws, c.x, c.y, 40 + dir) < 0.78:
							mall_storefront = c
							mall_storefront_wall = dir
						if mall_exit == WorldGen.NO_HALL and (dir == 0 or dir == 2) \
								and not edge["wall"] and not edge["full_open"] \
								and edge["exit_sign"]:
							mall_exit = c
							mall_exit_wall = dir
				var score := 1 if WorldGen.corridor(ws, c) != 0 else n * 10
				if c == root:
					score += 3
				if c == root and WorldGen.room_split(ws, root, theme).is_empty():
					score += 5
				# Prefer a representative, furnished anchor over the first tiny
				# partition or non-anchor member encountered by the ring scan.
				if not found.has(st) or score > int(found_score[st]):
					found[st] = c
					found_score[st] = score
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
		var rc := Vector2(float(c.x) * 12.0 + 6.0, float(c.y) * 12.0 + 6.0) \
			if ANCHOR_LOCAL_STYLES.has(st) \
			else WorldGen.room_centre(ws, WorldGen.room_id(ws, c))
		print("%-10s cell %s  ->  --pos=%.1f,%.1f" % [
			NAMES.get(st, str(st)), c, rc.x, rc.y])
	if elevator != WorldGen.NO_HALL:
		print("elevator   cell %s wall=%d  ->  --pos=%.1f,%.1f" % [elevator,
			WorldGen.anchor_wall(ws, elevator, 1701),
			float(elevator.x) * 12.0 + 6.0, float(elevator.y) * 12.0 + 6.0])
	if mall_storefront != WorldGen.NO_HALL:
		print("storefront cell %s wall=%d  ->  --pos=%.1f,%.1f" % [
			mall_storefront, mall_storefront_wall,
			float(mall_storefront.x) * 12.0 + 6.0,
			float(mall_storefront.y) * 12.0 + 6.0])
	if mall_exit != WorldGen.NO_HALL:
		print("mall exit   cell %s wall=%d  ->  --pos=%.1f,%.1f" % [
			mall_exit, mall_exit_wall,
			float(mall_exit.x) * 12.0 + 6.0,
			float(mall_exit.y) * 12.0 + 6.0])
	if camera_corridor != WorldGen.NO_HALL:
		var along_x := WorldGen.corridor(ws, camera_corridor) == 1
		var yaw := 0.0 if along_x else PI / 2.0
		var cam_side := -2.05 if WorldGen.r01(ws, camera_corridor.x,
			camera_corridor.y, 308) < 0.5 else 2.05
		var cam_t := -4.55 if WorldGen.r01(ws, camera_corridor.x,
			camera_corridor.y, 307) < 0.5 else 4.55
		var local := Vector3(cam_t, 2.48, cam_side).rotated(Vector3.UP, yaw)
		var mount := Vector3(float(camera_corridor.x) * 12.0 + 6.0, 0,
			float(camera_corridor.y) * 12.0 + 6.0) + local
		var lens_yaw := yaw + PI if cam_side > 0.0 else yaw
		print("camera hall cell %s  ->  --pos=%.1f,%.1f" % [camera_corridor,
			float(camera_corridor.x) * 12.0 + 6.0,
			float(camera_corridor.y) * 12.0 + 6.0])
		print("  mount=(%.2f, %.2f, %.2f) lens_yaw=%.1fdeg" % [
			mount.x, mount.y, mount.z, rad_to_deg(lens_yaw)])
	if projector_classroom != WorldGen.NO_HALL:
		var prc := WorldGen.room_centre(ws,
			WorldGen.room_id(ws, projector_classroom))
		print("projector classroom %s wall=%d  ->  --pos=%.1f,%.1f" % [
			projector_classroom,
			WorldGen.anchor_wall(ws, projector_classroom, 72),
			prc.x, prc.y])
	quit()
