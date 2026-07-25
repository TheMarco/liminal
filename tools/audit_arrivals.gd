extends SceneTree
## Builds real 3x3 destination neighbourhoods and tests the same capsule/floor
## resolver used at runtime. It covers both fixed portal offsets and arbitrary
## saved positions. Default: 16 base seeds × every live source floor.
## Run: godot --headless --path . --script tools/audit_arrivals.gd -- [seeds]

const ARRIVE := {
	0: Vector2(3.2, 2.0), 1: Vector2(3.2, 2.0), 2: Vector2(3.9, 1.0),
	4: Vector2(3.2, 2.0), 5: Vector2(3.2, 2.0), 6: Vector2(3.2, 2.0),
	7: Vector2(3.2, 2.0), 8: Vector2(3.2, 2.0),
}
const SAVED_OFFSETS := [
	Vector2(1.0, 1.0), Vector2(6.0, 6.0), Vector2(11.0, 11.0),
]


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
			var off: Vector2 = ARRIVE[dest]
			var desired := Vector3(float(cellv.x) * 12.0 + off.x, 0.15,
				float(cellv.y) * 12.0 + off.y)
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
				var saved := Vector3(float(cellv.x) * 12.0 + saved_off.x, 0.0,
					float(cellv.y) * 12.0 + saved_off.y)
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
	print("arrival audit: %d seeds, %d real portal destinations" % [seed_count, tested])
	print("  saved-position probes: %d | relocated portal points: %d | minimum escape rays: %d" % [
		saved_tested, moved, min_exits])
	if failures == 0:
		print("  PASS — every arrival has capsule clearance, supported floor, and 2+ escape directions")
	else:
		print("  FAIL — %d unsafe or missing destinations" % failures)
	SoundBank._c.clear()
	Sfx._c.clear()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)


func _stop_audio(root: Node) -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
