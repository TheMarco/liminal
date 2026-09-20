extends SceneTree
## Review regressions: blocked crossing/retry, pre-motion paired occupancy,
## real observation, normal encounter budget, ordinary-room port routing.

var failures: Array[String] = []
var fixture: TraversalLinkFixture
var graph: TraversalGraph

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok and failures.size() < 30:
		failures.append(message)

func _run() -> void:
	fixture = TraversalLinkFixture.new()
	root.add_child(fixture)
	fixture.build()
	await physics_frame
	await physics_frame
	fixture.admit_all()
	graph = fixture.graph_for(fixture.site_straight)
	_audit_refusal_retry()
	await _audit_live_contracts()
	_audit_ports()
	await _audit_room_to_room(fixture.site_straight)
	await _audit_room_to_room(fixture.site_turn)
	fixture.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		print("  FAIL " + failure)
	print("  PASS - seam safety and ordinary-room pursuit" if failures.is_empty() else "  FAIL - seam safety")
	quit(0 if failures.is_empty() else 1)

func _audit_refusal_retry() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var body := Node3D.new()
	var camper := Node3D.new()
	root.add_child(body)
	root.add_child(camper)
	body.position = Vector3(0, 0.05, -0.5)
	camper.position = Vector3(200, 0.05, 0.5)
	var out := trav.step(1.0 / 60.0, [{"body": body, "from": Vector3(0, 0.05, 0.5)},
		{"body": camper, "from": camper.position}])
	_expect(out.is_empty() and body.position.z > 0.0, "blocked actor escaped into continuation")
	camper.free()
	var before := body.position
	body.position.z = -0.5
	out = trav.step(1.0 / 60.0, [{"body": body, "from": before}])
	_expect(out.size() == 1 and absf(body.position.x - 200) < 0.01, "cleared landing could not retry")
	body.free()

func _audit_live_contracts() -> void:
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.position = Vector3(0, 0.05, 1)
	player.cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 1))
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.suppressed = true
	figure.set("_seen", true)
	root.add_child(figure)
	figure.set_physics_process(false)
	figure.position = Vector3(200, 0.05, 0.3)
	await physics_frame
	await physics_frame
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	trav.bind_actor(player)
	trav.bind_actor(figure)
	var desired := Vector3(0, 0.05, -0.5)
	var permitted := trav.constrain_motion(player, player.position, desired)
	_expect(permitted.z > 0.05, "mapped peer did not constrain player before motion")
	var mapped_peer := fixture.link_straight.inverse_mapping() * figure.position
	_expect(permitted.distance_to(mapped_peer) >= Player.BODY_RADIUS * 2 - 0.001, "pre-motion paired capsules overlap")
	figure._physics_process(0.0)
	_expect(bool(figure.get("_observed")), "visible mapped enemy still unobserved")
	player.cam.rotate_y(PI)
	figure._physics_process(0.0)
	_expect(not bool(figure.get("_observed")), "looking away still counts as observation")
	figure.position = Vector3(0, 0.05, 0.1)
	figure._update_chase_lifetime()
	var doors: int = figure.get("_chase_doors")
	figure.position.z = -0.1
	figure.apply_seam_transfer(fixture.link_straight.mapping())
	figure._update_chase_lifetime()
	_expect(int(figure.get("_chase_doors")) == doors, "seam consumed encounter room budget")
	_expect(not bool(figure.get("_giving_up")), "normal-budget pursuer retired at seam")
	figure.free()
	player.free()
	await physics_frame

func _audit_ports() -> void:
	var outside_a := graph.locate(Vector3(-8, 0, 8))
	var outside_b := graph.locate(Vector3(192, 0, 8))
	var path := graph.route(outside_a, outside_b, 64)
	_expect(path == [outside_a, fixture.link_straight.region_a, fixture.link_straight.region_b, outside_b], "room-to-room route misses a physical port: %s" % [path])
	graph.set_link_enabled(fixture.link_straight.id, false)
	for side in [fixture.link_straight.region_a, fixture.link_straight.region_b]:
		var steps := graph.neighbors(side)
		_expect(steps.size() == 1 and steps[0]["kind"] == "port", "disabled link strands site occupant")
	graph.set_link_enabled(fixture.link_straight.id, true)
	_expect(graph.locate(Vector3(0, 0, -1)).begins_with("grid:"), "decorative continuation owns a site region")

func _audit_room_to_room(site: HiddenLinkSite) -> void:
	var chase_graph := fixture.graph_for(site)
	var player := Player.new()
	player.position = site.link.endpoint_b * Vector3(-8, 0.05, 8)
	player.basis = site.link.endpoint_b.basis * Basis(Vector3.UP, PI * 0.5)
	root.add_child(player)
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = chase_graph
	figure.position = site.link.endpoint_a * Vector3(-8, 0.05, 8)
	figure.set("_seen", true)
	root.add_child(figure)
	var trav := SpatialTraversal.new()
	trav.add_site(site)
	trav.bind_actor(player)
	trav.bind_actor(figure)
	var transfers: Array = []
	trav.set_listener(func(record: Dictionary) -> void: transfers.append(record))
	var reached := false
	for tick in 4800:
		await physics_frame
		if not is_instance_valid(figure):
			break
		if figure.global_position.distance_to(player.global_position) < 2.5:
			reached = true
			break
	_expect(reached, "normal-budget pursuer never reached other ordinary room; final=%s" % [figure.global_position if is_instance_valid(figure) else Vector3.INF])
	_expect(transfers.size() == 1, "room-to-room chase needs exactly one transfer, got %d" % transfers.size())
	if is_instance_valid(figure):
		figure.free()
	player.free()
