extends SceneTree
func _init() -> void:
	var hits := 0
	var checked := 0
	for si in 6:
		var base := WorldGen.h(5150, si * 31, si * 53, 909) | 1
		var ws := WorldGen.level_seed(base, 4)
		for x in range(-7, 8):
			for z in range(-7, 8):
				var c := Vector2i(x, z)
				var st := WorldGen.cell_style(ws, c, 4)
				if st != WorldGen.AIR_CONCOURSE: continue
				var is_anchor := WorldGen.room_id(ws, c) == c
				var is_corr := WorldGen.corridor(ws, c) != 0
				checked += 1
				var chunk := Chunk.new(ws, c, 4)
				var cases := []; var seats := []
				for n in chunk.find_children("*", "Node3D", true, false):
					var t := str(n.get_meta("atomic_furnishing", ""))
					if t == "suitcase": cases.append(n)
					elif t == "airport_seat_row": seats.append(n)
				for cs in cases:
					for sr in seats:
						var d := Vector2(cs.position.x - sr.position.x,
							cs.position.z - sr.position.z).length()
						if d < 1.3:
							hits += 1
							if hits <= 5:
								print("OVERLAP cell=%s anchor=%s corridor=%s  gap=%.2fm" % [
									c, is_anchor, is_corr, d])
				chunk.free()
	print("concourse cells checked: %d | suitcase-in-seats: %d" % [checked, hits])
	quit()
