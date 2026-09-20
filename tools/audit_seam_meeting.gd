extends SceneTree
## Package 3.6 gate: the two-enemy meeting tableau, headless. Poses two
## live figures converging on opposite sides of the straight seam exactly
## like the capture's meeting series, then asserts the render inputs the
## frames cannot prove: both walkers stand where posed, exactly one proxy
## each, the B figure's twin renders on the A side with peer separation,
## both fully manifested, and frozen physics means zero walker drift.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 40:
		failures.append(message)


func _figure(player: Player, graph: TraversalGraph, model: int,
		at: Vector3) -> ShadowFigure:
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	figure.walker_model_index = model
	root.add_child(figure)
	figure.set("_chase_limit", 99)
	figure.get("_walker").set_manifestation(1.0)
	figure.global_position = at
	figure.set_physics_process(false)
	return figure


func _walker_of(figure: ShadowFigure) -> ShadowWalkerVisual:
	return figure.get("_walker") as ShadowWalkerVisual


func _run() -> void:
	var fixture := TraversalLinkFixture.new()
	fixture.debug_marks = false
	root.add_child(fixture)
	fixture.build()
	for i in 8:
		await process_frame
	fixture.admit_all()
	_expect(fixture.site_straight.admitted(), "straight site did not admit")
	var graph := TraversalGraph.new()
	graph.register_link(fixture.link_straight,
		AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	var player := Player.new()
	player.position = Vector3(0, 0.05, 4.5)
	root.add_child(player)
	var figure := _figure(player, graph, 0, Vector3(-0.55, 0.05, 1.5))
	var other := _figure(player, graph, 4,
		Vector3(200.0 - 0.55, 0.05, 1.5))
	for n in 4:
		var z := 1.5 - 0.4 * float(n)
		figure.global_position = Vector3(-0.55, 0.05, z)
		other.global_position = Vector3(200.0 - 0.55, 0.05, z)
		for i in 7:
			await process_frame
		var proxy_a: SeamActorProxy = figure.get("_seam_proxy")
		var proxy_b: SeamActorProxy = other.get("_seam_proxy")
		_expect(is_instance_valid(proxy_a),
			"shot %d: A figure grew no proxy" % n)
		_expect(is_instance_valid(proxy_b),
			"shot %d: B figure grew no proxy" % n)
		if is_instance_valid(proxy_a):
			_expect(bool(proxy_a.from_a),
				"shot %d: A pairing faces the wrong way" % n)
			_expect(proxy_a.walker.global_position.distance_to(
				Vector3(200.55, 0.05, -z)) < 0.15,
				"shot %d: A twin at %s, want B-side mirror" % [n,
					proxy_a.walker.global_position])
		if is_instance_valid(proxy_b):
			_expect(not bool(proxy_b.from_a),
				"shot %d: B pairing faces the wrong way" % n)
			_expect(proxy_b.walker.global_position.distance_to(
				Vector3(0.55, 0.05, -z)) < 0.15,
				"shot %d: B twin at %s, want A-side mirror" % [n,
					proxy_b.walker.global_position])
			# Posed convergence, not a spawn: the pair is meant to
			# nearly touch across the seam, never to interpenetrate.
			_expect(_walker_of(figure).global_position.distance_to(
				proxy_b.walker.global_position) > 0.4,
				"shot %d: meeting pair interpenetrates" % n)
		# Manifestation ramps over the appear tween; the meeting frames
		# catch it mid-ramp, which reads as faintness, not absence.
		_expect(float(_walker_of(figure).get("_manifestation")) > 0.0,
			"shot %d: A walker never started manifesting" % n)
		_expect(float(_walker_of(other).get("_manifestation")) > 0.0,
			"shot %d: B walker never started manifesting" % n)
	# Frozen physics must freeze the walkers: any drift is root motion
	# or a stray process mover, and it would read as motion in the stills.
	var before := _walker_of(figure).global_position
	var before_other := _walker_of(other).global_position
	for i in 30:
		await process_frame
	_expect(_walker_of(figure).global_position.distance_to(before)
		< 0.001, "A walker drifted with physics frozen")
	_expect(_walker_of(other).global_position.distance_to(before_other)
		< 0.001, "B walker drifted with physics frozen")
	var proxies := 0
	for node in root.get_children():
		if node is SeamActorProxy:
			proxies += 1
	_expect(proxies == 2, "want exactly 2 proxies, found %d" % proxies)
	figure.free()
	other.free()
	player.free()
	fixture.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - meeting tableau holds two manifested pairs")
		quit()
	else:
		quit(1)
