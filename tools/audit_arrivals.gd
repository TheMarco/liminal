extends SceneTree
## Verifies Wander's retired-portal contract, then builds representative 3x3
## destination neighbourhoods and tests the same capsule/floor resolver used by
## first-time and restored number-key travel. Default: 16 seeds × every floor.
## Run: godot --headless --path . --script tools/audit_arrivals.gd -- [seeds]

## Use Main's real spawn constant so the audit cannot drift from runtime travel.
const Main := preload("res://scripts/main.gd")

const SAVED_OFFSETS := [
	Vector2(1.0, 1.0), Vector2(6.0, 6.0), Vector2(11.0, 11.0),
]


## The position the game actually asks for. main._safe_arrival adds the cell's
## floor datum to the offset's y, so the probe has to as well -- and both now read
## Chunk.cell_floor_h, so neither can drift from the other again.
func _arrival_point(ws: int, cellv: Vector2i, theme: int, off: Vector3) -> Vector3:
	return Vector3(float(cellv.x) * 12.0 + off.x,
		Chunk.cell_floor_h(ws, cellv, theme) + off.y,
		float(cellv.y) * 12.0 + off.z)


func _init() -> void:
	call_deferred("_run")


func _level_seed(base: int, theme: int) -> int:
	return WorldGen.level_seed(base, theme)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if not args.is_empty() else 16
	seed_count = clampi(seed_count, 1, 64)
	var portal_checks := 0
	var moved := 0
	var invalid_saved := 0
	var saved_tested := 0
	var min_exits := 99
	var failures := 0
	for si in seed_count:
		var base := WorldGen.h(8675309, si * 17, si * 31, 1901) | 1
		for theme in WorldGen.THEMES:
			var ws := _level_seed(base, theme)
			# Scan enough real world coordinates to catch any accidental return of
			# the former probabilistic portal predicate.
			for x in range(-12, 13):
				for z in range(-12, 13):
					portal_checks += 1
					if WorldGen.portal(ws, Vector2i(x, z), theme) >= 0:
						failures += 1
						if failures <= 12:
							print("FAIL Wander portal seed=%d theme=%d cell=(%d,%d)" % [
								base, theme, x, z])
			var cellv := Vector2i(2 + ((si + theme) % 3),
				-3 + ((si * 2 + theme) % 5))
			var level := Node3D.new()
			get_root().add_child(level)
			var chunks: Array[Chunk] = []
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var cc := cellv + Vector2i(dx, dz)
					var chunk := Chunk.new(ws, cc, theme)
					chunk.position = Vector3(float(cc.x) * 12.0, 0, float(cc.y) * 12.0)
					level.add_child(chunk)
					chunks.append(chunk)
			await physics_frame
			for chunk in chunks:
				if chunk.portal_dest >= 0 \
						or not chunk.find_children("*", "Portal", true, false).is_empty():
					failures += 1
					if failures <= 12:
						print("FAIL chunk built a traversable portal seed=%d theme=%d cell=%s" % [
							base, theme, chunk.cell])
			# Floor-number travel restores the player's last position, which may
			# be beside furniture. Exercise representative corners and the centre.
			for saved_off in SAVED_OFFSETS:
				var saved := _arrival_point(ws, cellv, theme, Vector3(
					saved_off.x, ArrivalSafety.STANDING_CLEARANCE, saved_off.y))
				# Runtime only records positions at which the player was genuinely
				# standing. Do not manufacture a restoration case inside a rack or
				# wall; that is an impossible saved state, not an arrival failure.
				if not ArrivalSafety.is_clear(level.get_world_3d(), saved) \
						or not ArrivalSafety.has_floor(level.get_world_3d(), saved) \
						or ArrivalSafety.escape_count(level.get_world_3d(), saved) < 2:
					invalid_saved += 1
					continue
				var saved_safe := ArrivalSafety.find_safe(
					level.get_world_3d(), saved, cellv)
				if saved_safe == Vector3.INF:
					failures += 1
					if failures <= 12:
						print("FAIL saved arrival seed=%d theme=%d cell=%s offset=%s" % [
							base, theme, cellv, saved_off])
				else:
					var exits := ArrivalSafety.escape_count(level.get_world_3d(), saved_safe)
					min_exits = mini(min_exits, exits)
					if saved_safe.distance_to(saved) > 0.05:
						moved += 1
					saved_tested += 1
			_stop_audio(level)
			level.free()
			await process_frame
			await physics_frame
	# main._ready and a first-time number-key switch both land on cell (0,0) with
	# DEFAULT_SPAWN. A past gap here hid a deterministic fault:
	# WorldGen.cell_style returns POOL_DECK for theme 9 at the origin on
	# every seed, POOL_DECK is a dry style, and its floor is a raised slab -- so
	# every entry to floor 9 asked to place the player inside it.
	var spawn_tested := 0
	for si in seed_count:
		var base := WorldGen.h(8675309, si * 17, si * 31, 1901) | 1
		for theme in WorldGen.THEMES:
			var ws := _level_seed(base, theme)
			var level := Node3D.new()
			get_root().add_child(level)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var cc := Vector2i(dx, dz)
					var chunk := Chunk.new(ws, cc, theme)
					chunk.position = Vector3(float(cc.x) * 12.0, 0, float(cc.y) * 12.0)
					level.add_child(chunk)
			await physics_frame
			var want := _arrival_point(ws, Vector2i.ZERO, theme, Main.DEFAULT_SPAWN)
			var got := ArrivalSafety.find_safe(level.get_world_3d(), want,
				Vector2i.ZERO)
			# Height, not just success. ArrivalSafety will lift a request onto
			# whatever supports it, so "not INF" only proves the resolver recovered
			# -- it passes just as happily when the requested datum is a metre wrong.
			# Moving sideways to dodge furniture is fine; moving vertically means the
			# caller does not know where this floor is, which is the actual defect.
			if got == Vector3.INF:
				failures += 1
				if failures <= 12:
					print("FAIL spawn cell seed=%d theme=%d style=%d floor_y=%.2f" % [
						base, theme, WorldGen.cell_style(ws, Vector2i.ZERO, theme),
						Chunk.cell_floor_h(ws, Vector2i.ZERO, theme)])
			elif absf(got.y - want.y) > 0.05:
				failures += 1
				if failures <= 12:
					print(("FAIL spawn datum seed=%d theme=%d style=%d: asked y=%.2f, " +
						"resolver had to stand the player at y=%.2f") % [
							base, theme, WorldGen.cell_style(ws, Vector2i.ZERO, theme),
							want.y, got.y])
			else:
				spawn_tested += 1
			_stop_audio(level)
			level.free()
			await process_frame
			await physics_frame

	print("arrival audit: %d seeds, %d Wander cells portal-free" % [
		seed_count, portal_checks])
	print("  spawn-cell probes: %d" % spawn_tested)
	print(("  saved-position probes: %d | impossible points skipped: %d | "
		+ "relocated saved points: %d | minimum escape rays: %d") % [
		saved_tested, invalid_saved, moved, min_exits])
	if failures == 0:
		print("  PASS — no Wander portals; every arrival has capsule clearance, supported floor, and 2+ escape directions")
	else:
		print("  FAIL — %d unsafe or missing destinations" % failures)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)


func _stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
