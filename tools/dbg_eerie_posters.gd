extends SceneTree
## Prints ready-to-use screenshot viewpoints for the exact-text poster mounts
## and Airport lightboxes added to the themed wall-art system.
## Run: godot --headless --path . --script tools/dbg_eerie_posters.gd -- \
##   [base_seed] [radius]

const THEME_NAMES := {
	1: "office", 2: "annex", 4: "airport", 5: "asylum",
	6: "school", 7: "mall", 8: "prison",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var base := int(args[0]) if args.size() > 0 else 1065674081
	var radius := clampi(int(args[1]) if args.size() > 1 else 7, 3, 12)
	for theme in [1, 2, 4, 5, 6, 7, 8]:
		var ws := WorldGen.level_seed(base, theme)
		var shown := 0
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if shown >= 2:
					break
				var chunk := Chunk.new(ws, Vector2i(x, z), theme)
				var origin := Vector3(float(x) * Chunk.S, 0.0, float(z) * Chunk.S)
				for node in chunk.find_children("*", "Node3D", true, false):
					if theme == 4 and not node.has_meta("airport_poster_lightbox"):
						continue
					var path := str(node.get_meta("wall_art_path", ""))
					if path.is_empty():
						path = str(node.get_meta("airport_poster_path", ""))
					if not path.contains("/posters/poster-%s-" % THEME_NAMES[theme]):
						continue
					var mount := node as Node3D
					var world := origin + mount.position
					var facing := Vector3(sin(mount.rotation.y), 0.0,
						cos(mount.rotation.y))
					var stand := world + facing * 2.65
					print("theme=%d cell=%s path=%s" % [theme,
						Vector2i(x, z), path])
					print("  --level=%d --pos=%.2f,%.2f --yaw=%.1f" % [
						theme, stand.x, stand.z, rad_to_deg(mount.rotation.y)])
					shown += 1
					if shown >= 2:
						break
				chunk.free()
			if shown >= 2:
				break
		print("theme %d poster viewpoints: %d" % [theme, shown])
	quit()
