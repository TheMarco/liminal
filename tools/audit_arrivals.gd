extends SceneTree
## Builds real 3x3 destination neighbourhoods and tests the same capsule/floor
## resolver used at runtime. It covers both fixed portal offsets and arbitrary
## saved positions. Default: 16 base seeds × every live source floor.
## Run: godot --headless --path . --script tools/audit_arrivals.gd -- [seeds]

## The real table, not a copy of it. This used to mirror main.PORTAL_ARRIVE by
## hand, and the mirror is exactly why theme 9 went untested: the Poolrooms were
## added without an entry here, the missing key aborted _init, and because an
## `extends SceneTree` audit that aborts never reaches quit() it idled instead of
## failing. Reading main's own constants cannot drift.
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


func _portal_cell(ws: int, theme: int) -> Array:
	# Gym portals are deliberately sparse in the school. Search a broad ring so
	# the audit measures real arrivals instead of treating rarity as bad footing.
	for r in 49:
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if maxi(absi(x), absi(z)) != r:
					continue
				var c := Vector2i(x, z)
				var dest := WorldGen.portal(ws, c, theme)
				if dest >= 0:
					return [c, dest]
	return []


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if not args.is_empty() else 16
	seed_count = clampi(seed_count, 1, 64)
	var tested := 0
	var moved := 0
	var saved_tested := 0
	var min_exits := 99
	var failures := 0
	for si in seed_count:
		var base := WorldGen.h(8675309, si * 17, si * 31, 1901) | 1
		for source_theme in WorldGen.THEMES:
			var source_seed := _level_seed(base, source_theme)
			var portal := _portal_cell(source_seed, source_theme)
			if portal.is_empty():
				failures += 1
				print("FAIL no portal found seed=%d source=%d" % [base, source_theme])
				continue
			var cellv: Vector2i = portal[0]
			var dest: int = portal[1]
			var dest_seed := _level_seed(base, dest)
			var level := Node3D.new()
			get_root().add_child(level)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var cc := cellv + Vector2i(dx, dz)
					var chunk := Chunk.new(dest_seed, cc, dest)
					chunk.position = Vector3(float(cc.x) * 12.0, 0, float(cc.y) * 12.0)
					level.add_child(chunk)
			await physics_frame
			var off: Vector3 = Main.PORTAL_ARRIVE.get(dest,
				Main.PORTAL_ARRIVE_DEFAULT)
			var desired := _arrival_point(dest_seed, cellv, dest, off)
			var safe := ArrivalSafety.find_safe(level.get_world_3d(), desired, cellv)
			if safe == Vector3.INF:
				failures += 1
				if failures <= 12:
					print("FAIL seed=%d %d->%d cell=%s style=%d" % [base,
						source_theme, dest, cellv, WorldGen.cell_style(dest_seed, cellv, dest)])
			else:
				var exits := ArrivalSafety.escape_count(level.get_world_3d(), safe)
				min_exits = mini(min_exits, exits)
				if safe.distance_to(desired) > 0.05:
					moved += 1
				tested += 1
			# Floor-number travel restores the player's last position, which may
			# be beside furniture rather than at the fixed portal offset. Exercise
			# representative corners and the centre of every real destination.
			for saved_off in SAVED_OFFSETS:
				var saved := _arrival_point(dest_seed, cellv, dest, Vector3(
					saved_off.x, ArrivalSafety.STANDING_CLEARANCE, saved_off.y))
				var saved_safe := ArrivalSafety.find_safe(
					level.get_world_3d(), saved, cellv)
				if saved_safe == Vector3.INF:
					failures += 1
					if failures <= 12:
						print("FAIL saved arrival seed=%d dest=%d cell=%s offset=%s" % [
							base, dest, cellv, saved_off])
				else:
					saved_tested += 1
			_stop_audio(level)
			level.free()
			await process_frame
			await physics_frame
	# The spawn cell, which nothing tested. main._ready and main._switch_level both
	# land on cell (0,0) with DEFAULT_SPAWN, but WorldGen.portal never returns the
	# spawn cell so the loop above can never reach it. That gap hid a deterministic
	# fault: WorldGen.cell_style returns POOL_DECK for theme 9 at the origin on
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

	print("arrival audit: %d seeds, %d real portal destinations" % [seed_count, tested])
	print("  spawn-cell probes: %d" % spawn_tested)
	print("  saved-position probes: %d | relocated portal points: %d | minimum escape rays: %d" % [
		saved_tested, moved, min_exits])
	if failures == 0:
		print("  PASS — every arrival has capsule clearance, supported floor, and 2+ escape directions")
	else:
		print("  FAIL — %d unsafe or missing destinations" % failures)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)


func _stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
