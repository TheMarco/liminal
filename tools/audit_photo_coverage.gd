extends "res://tools/lib/audit_base.gd"
## Photography coverage audit: every REQUIRED anomaly on the boot floor must
## be capturable from at least one player stance. Guards the class of bug
## where an anomaly exists, the EVIDENCE counter points at it, and no stance
## can frame it (2026-08-19: a GIANT's own walk-blocker collider occluded
## its sample points from 16/16 stances and stranded the floor at 2/3).
## Run: godot --headless --path . --script tools/audit_photo_coverage.gd \
##   -- --mode=descent --seed=7 --nologo

func run() -> void:
	var game := await boot_game(7)
	var director: PhotoDirector = game._photo_director
	var camera: PhotoCamera = game._photo_camera
	expect(director != null and camera != null, "photo layer missing")
	var checked := 0
	for at in director.plan:
		if not bool(director.plan[at]["required"]):
			continue
		game.cm.warm_up(at)
		var ok := await await_until(func() -> bool:
			return director._live.has(at) \
				and is_instance_valid(director._live[at]) \
				and director._live[at].is_inside_tree(), 8000)
		expect(ok, "required anomaly %s did not spawn" % str(at))
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
		for dist in [3.5, 6.0]:
			for ang in 8:
				var dirv := Vector3(cos(TAU * ang / 8.0), 0,
					sin(TAU * ang / 8.0))
				var stand := mid + dirv * float(dist)
				stand.y = 0.15
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
		expect(frames > 0, "required %s type %d capturable from 0/16 stances"
			% [str(at), anomaly.type])
		checked += 1
	expect(checked == director.required_count(),
		"expected %d required anomalies, checked %d" % [
			director.required_count(), checked])
	await teardown_game(game)
	finish("photo coverage: %d required anomalies capturable" % checked)
