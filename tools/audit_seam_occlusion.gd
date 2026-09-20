extends SceneTree
## Omnidirectional geometry proof (stronger than any individual FOV).
## Legal heads, both directions, horizontal/vertical rays and dense points
## throughout both unmatched exterior openings.

var failures: Array[String] = []
var blocked := 0
var equivalent := 0

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok and failures.size() < 30:
		failures.append(message)

func _run() -> void:
	var fixture := TraversalLinkFixture.new()
	root.add_child(fixture)
	fixture.build()
	await physics_frame
	await physics_frame
	var space := fixture.get_world_3d().direct_space_state
	for site in [fixture.site_straight, fixture.site_turn]:
		var a: Transform3D = site.link.endpoint_a
		var m: Transform3D = site.link.mapping()
		for x in [-0.81, 0.0, 0.81]:
			for z in [-2.0, -0.05, 0.0, 0.05, 2.0]:
				for y in [0.65, 1.4, 1.9]:
					var source := a * Vector3(x, y, z)
					for side in [-1.0, 1.0]:
						for offset in [-1.1, -0.55, 0.0, 0.55, 1.1]:
							for height in [0.1, 1.0, 2.6]:
								var target := a * Vector3(side * 6.3, height, -side * 8.0 + offset)
								for transform in [Transform3D.IDENTITY, m]:
									var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(transform * source, transform * target, 1))
									_expect(not hit.is_empty(), "exterior visible from %s to %s" % [transform * source, transform * target])
									blocked += 1
					for azimuth in 24:
						for elevation in [-1.1, -0.4, 0.07, 0.5, 1.1]:
							var angle := TAU * (float(azimuth) + 0.173) / 24.0
							var direction := a.basis * Vector3(sin(angle) * cos(elevation), sin(elevation), cos(angle) * cos(elevation))
							var target := source + direction * 40.0
							var ha := space.intersect_ray(PhysicsRayQueryParameters3D.create(source, target, 1))
							var hb := space.intersect_ray(PhysicsRayQueryParameters3D.create(m * source, m * target, 1))
							_expect(not ha.is_empty() and not hb.is_empty(), "open geometry ray")
							if ha.is_empty() or hb.is_empty():
								continue
							_expect((m * ha["position"]).distance_to(hb["position"]) < 0.003, "mapped hit position differs")
							_expect((m.basis * ha["normal"]).distance_to(hb["normal"]) < 0.003, "mapped hit normal differs")
							equivalent += 1
	# End caps must not make occlusion trivially pass.
	for origin in [Vector3.ZERO, Vector3(200, 0, 0)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin + Vector3(-8, 1, 8), origin + Vector3(0, 1, 8), 1))
		_expect(hit.is_empty(), "ordinary room entrance is sealed")
	fixture.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		print("  FAIL " + failure)
	print("  %d exterior rays; %d mapped geometry comparisons" % [blocked, equivalent])
	print("  PASS - bent passage occlusion and mapped geometry" if failures.is_empty() else "  FAIL - bent passage")
	quit(0 if failures.is_empty() else 1)
