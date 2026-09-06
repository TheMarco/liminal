extends "res://tools/lib/audit_base.gd"
## Photography coverage audit: every planned anomaly on the boot floor must
## be capturable from at least one player stance. Guards the class of bug
## where an anomaly exists, the EVIDENCE counter points at it, and no stance
## can frame it (2026-08-19: a GIANT's own walk-blocker collider occluded
## its sample points from 16/16 stances and stranded the floor at 2/3;
## 2026-08-20: prison cell fronts hid valid generic wall placements).
## Run: godot --headless --path . --script tools/audit_photo_coverage.gd \
##   -- --mode=descent --seed=7 --nologo

func run() -> void:
	var seed := arg_int(0, 7, 1, 0x7fffffff)
	var game := await boot_game(seed)
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	expect(director != null and camera != null, "photo layer missing")
	var checked := 0
	for at in director.plan:
		game.cm.stream_focus = Vector3(at.x * 12.0 + 6, 0.0, at.y * 12.0 + 6)
		game.cm.warm_up(at)
		var ok := await await_until(func() -> bool:
			return director._live.has(at) \
				and is_instance_valid(director._live[at]) \
				and director._live[at].is_inside_tree(), 8000)
		expect(ok, "planned anomaly %s did not spawn" % str(at))
		if not ok:
			continue
		var anomaly: PhotoAnomaly = director._live[at]
		var points := anomaly.photo_points()
		expect(not points.is_empty(), "%s exposes no points" % str(at))
		if points.is_empty():
			continue
		var mid: Vector3 = points[0]
		if points.size() > 1:
			mid = (points[0] + points[1]) * 0.5
		var frames := 0
		for dist in [1.8, 3.5, 6.0]:
			for ang in 8:
				var dirv := Vector3(cos(TAU * ang / 8.0), 0,
					sin(TAU * ang / 8.0))
				var stand := mid + dirv * float(dist)
				var stand_cell := Vector2i(
					floori(stand.x / WorldGen.CELL_SIZE),
					floori(stand.z / WorldGen.CELL_SIZE))
				var stand_chunk: Chunk = game.cm.chunk_at(stand_cell)
				if stand_chunk == null:
					game.cm.warm_up(stand_cell)
					stand_chunk = game.cm.chunk_at(stand_cell)
				if stand_chunk == null:
					continue
				var floor_h := Chunk.cell_floor_h(director.world_seed,
					stand_cell, director.theme)
				var local_stand: Vector3 = stand - stand_chunk.global_position
				local_stand.y = floor_h
				# A ray from inside furniture is not proof a player can take the
				# photograph. Require enough clear space for the real 0.38m x 1.8m
				# capsule before accepting this framing stance.
				if not stand_chunk._floor_spot_clear(local_stand, 0.38, 1.8):
					continue
				stand.y = floor_h + 0.15
				game.player.teleport(stand)
				var eye: Vector3 = game.player.cam.global_position
				var flat := Vector2(mid.x - eye.x, mid.z - eye.z)
				game.player.rotation.y = atan2(-flat.x, -flat.y)
				game.player.cam.rotation = Vector3(
					atan2(mid.y - eye.y, flat.length()),
					game.player.rotation.y, 0.0)
				await physics_frame
				if camera._captured_anomalies().has(anomaly):
					frames += 1
		var style := WorldGen.cell_style(director.world_seed, at, director.theme)
		expect(frames > 0,
			"planned %s type %d style %d capturable from 0/24 legal stances"
			% [str(at), anomaly.type, style])
		checked += 1
	expect(checked == director.plan.size(),
		"expected %d planned anomalies, checked %d" % [
			director.plan.size(), checked])
	await teardown_game(game)
	finish("photo coverage: seed %d, %d planned anomalies capturable" % [
		seed, checked])
