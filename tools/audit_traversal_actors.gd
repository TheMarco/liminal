extends SceneTree
## Package 3.3 gate: actor integration for hidden traversal. Player
## eligibility plus state-preserving transfer application (no teleport
## resets), enemy room-path diversion through the graph adapter, transfer
## application with navigation invalidation and follow-through rerouting,
## reverse objective routing across link cells, and the traversal
## eligibility hook. Live full-AI crossings validate in the campaign
## visit; the mechanics underneath are proven in audit_hidden_link.

class StubFigure extends ShadowFigure:
	func _ready() -> void:
		super._ready()
	func _edge_info(_cell: Vector2i, _dir: int) -> Dictionary:
		return {"wall": false, "t": 6.0, "full_open": true}

var failures: Array[String] = []
var fixture: TraversalLinkFixture
var graph: TraversalGraph


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _run() -> void:
	fixture = TraversalLinkFixture.new()
	root.add_child(fixture)
	fixture.build()
	await physics_frame
	await physics_frame
	fixture.admit_all()
	graph = TraversalGraph.new()
	# Volumes enclose the walking surface: grounded actors rest at y ~= 0.
	graph.register_link(fixture.link_straight,
		AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	_audit_player_eligibility()
	_audit_player_transfer()
	await _audit_enemy_diversion()
	await _audit_enemy_transfer()
	_audit_reverse_routing()
	_audit_allow_hook()
	_audit_freed_body()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - traversal actors hold")
		quit()
	else:
		quit(1)


func _audit_player_eligibility() -> void:
	var player := Player.new()
	player.position = Vector3(0, 0.05, 4.0)
	root.add_child(player)
	# Not yet simulated: airborne reads ineligible.
	_expect(not player.seam_transfer_eligible(),
		"airborne player eligible")
	player.queue_free()
	var grounded := Player.new()
	grounded.position = Vector3(0, 0.05, 4.0)
	root.add_child(grounded)
	# Settle for real: a fixed frame count races the physics accumulator
	# headless, where an iteration may run zero physics steps.
	for i in 90:
		if grounded.is_on_floor():
			break
		await physics_frame
	_expect(grounded.seam_transfer_eligible(),
		"dry grounded player ineligible")
	grounded.set("_on_ladder", true)
	_expect(not grounded.seam_transfer_eligible(),
		"ladder player eligible")
	grounded.set("_on_ladder", false)
	var slide := PoolSlide.new()
	root.add_child(slide)
	grounded.set("_pool_slide", slide)
	_expect(not grounded.seam_transfer_eligible(),
		"sliding player eligible")
	slide.queue_free()
	grounded.queue_free()


func _audit_player_transfer() -> void:
	var player := Player.new()
	root.add_child(player)
	player.global_position = Vector3(0, 0.05, 5.0)
	player.cam.global_position = Vector3(0, 1.427, 5.0)
	player.rotation.y = 0.0
	player.velocity = Vector3(0, 0, -3.4)
	player.set("_prev_pos", Vector3(0, 0.05, 5.2))
	player.set("_curr_pos", Vector3(0, 0.05, 5.0))
	player.set("_stamina", 4.0)
	player.set("_sprint_spent", true)
	player.set("_sprint_toggle_active", true)
	player.set("_bob", 1.2)
	player.set("_step_acc", 0.7)
	player.set("_pitch", -0.1)
	player.set("_flash_charge", 0.5)
	player.set("_traversal_samples", {"k": PackedVector3Array([Vector3.ONE])})
	var m: Transform3D = fixture.link_straight.mapping()
	player.apply_seam_transfer(m)
	_expect(player.global_position.distance_to(
		m * Vector3(0, 0.05, 5.0)) < 0.0001, "player position unmapped")
	_expect(player.velocity.distance_to(
		m.basis * Vector3(0, 0, -3.4)) < 0.0001,
		"player velocity zeroed instead of mapped")
	_expect(absf(wrapf(player.rotation.y - PI, -PI, PI)) < 0.01,
		"player yaw not turned by the mapping")
	_expect(player.get("_prev_pos").distance_to(
		m * Vector3(0, 0.05, 5.2)) < 0.0001, "player history unmapped")
	_expect(player.cam.global_position.distance_to(
		m * Vector3(0, 1.427, 5.0)) < 0.01, "player camera unmapped")
	_expect(player.get("_stamina") == 4.0
		and player.get("_sprint_spent") == true
		and player.get("_sprint_toggle_active") == true,
		"sprint state reset by the transfer")
	_expect(player.get("_bob") == 1.2 and player.get("_step_acc") == 0.7
		and player.get("_pitch") == -0.1, "gait state reset")
	_expect(player.get("_flash_charge") == 0.5, "torch charge reset")
	_expect((player.get("_traversal_samples") as Dictionary).has("k"),
		"traversal samples cleared by the transfer")
	player.queue_free()


func _audit_enemy_diversion() -> void:
	var player := Player.new()
	player.position = Vector3(200, 0.05, 3.0)
	root.add_child(player)
	var figure := StubFigure.new()
	figure.player = player
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 3.0)
	await physics_frame
	figure.traversal_graph = graph
	var target: Vector3 = figure._route_target(1.0 / 60.0)
	_expect(target.distance_to(Vector3(0, 0, 1.0)) < 0.01,
		"figure did not divert to the link exit: %s" % target)
	_expect(figure.get("_route_from") == ShadowFigure.NO_ROOM,
		"legacy room route ran despite the link diversion")
	# Same-side pair without a link hop keeps the legacy room route.
	player.position = Vector3(0, 0.05, 5.0)
	figure.traversal_graph = null
	var legacy: Vector3 = figure._route_target(1.0 / 60.0)
	_expect(legacy.distance_to(player.global_position) < 0.01,
		"legacy same-cell route changed: %s" % legacy)
	figure.queue_free()
	player.queue_free()


func _audit_enemy_transfer() -> void:
	# Flush the diversion's freed bodies: its player would otherwise stand
	# mid-corridor on the reroute line as a live layer-1 blocker.
	await physics_frame
	var player := Player.new()
	player.position = Vector3(200, 0.05, 5.0)
	root.add_child(player)
	var figure := StubFigure.new()
	figure.player = player
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 0.5)
	figure.ground_velocity = Vector3(0, 0, -3.0)
	figure.set("_route_from", Vector2i(5, 5))
	figure.set("_route_goal", Vector2i(6, 6))
	figure.set("_route_waypoint", Vector3(1, 2, 3))
	figure.get("_local_path").set("_target", Vector3(9, 9, 9))
	var m: Transform3D = fixture.link_straight.mapping()
	figure.apply_seam_transfer(m)
	_expect(figure.global_position.distance_to(
		m * Vector3(0, 0.05, 0.5)) < 0.0001, "figure position unmapped")
	_expect(figure.ground_velocity.distance_to(
		m.basis * Vector3(0, 0, -3.0)) < 0.0001,
		"figure velocity unmapped")
	_expect(figure.get("_route_from") == ShadowFigure.NO_ROOM
		and figure.get("_route_waypoint") == Vector3.INF,
		"figure route caches survived the transfer")
	_expect(figure.get("_local_path").get("_target") == Vector3.INF,
		"figure local path survived the transfer")
	# Reroute on the new side: same corridor, direct line to the player.
	var target: Vector3 = figure._route_target(1.0 / 60.0)
	_expect(target.distance_to(player.global_position) < 0.01,
		"figure did not reroute after transfer: %s" % target)
	figure.queue_free()
	player.queue_free()


func _audit_reverse_routing() -> void:
	var ws := WorldGen.level_seed(11, 1)
	var route := DescentRoute.build(ws, 1, 2)
	var topology := DescentTopology.new(ws, 1)
	route.set_topology(topology)
	topology.plan_floor(route)
	route._build_reverse_map()
	var plain: Dictionary = route.get("_target_distance")
	var far := Vector2i.ZERO
	for cell in plain.keys():
		if int(plain[cell]) > int(plain.get(far, -1)):
			far = cell
	var near_target: Vector2i = route.target
	route.set_traversal_link_cells([[far, near_target]])
	route._build_reverse_map()
	var linked: Dictionary = route.get("_target_distance")
	_expect(int(linked[far]) == int(linked[near_target]) + 1,
		"reverse map did not route across the link")
	_expect(int(linked[far]) < int(plain[far]),
		"link did not shorten the objective route")
	route.set_traversal_link_cells([])
	route._build_reverse_map()
	_expect(route.get("_target_distance") == plain,
		"empty link list changed the legacy map")


func _audit_allow_hook() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var out: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 1.0), "allow": false}])
	_expect(out.is_empty(), "ineligible actor transferred")
	_expect(trav.last_refusal() == "actor ineligible",
		"wrong refusal: %s" % trav.last_refusal())
	_expect(body.global_position.distance_to(
		Vector3(0, 0.05, 1.0)) < 0.0001, "refused actor escaped the approach")
	body.queue_free()


## A body freed between sampling and the phase (burn, catch) must not
## error the phase nor strand the bodies listed after it.
func _audit_freed_body() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var dead := SpatialTestBody.create()
	dead.position = Vector3(0, 0.05, -0.5)
	root.add_child(dead)
	var live := SpatialTestBody.create()
	live.position = Vector3(0.5, 0.05, -0.5)
	root.add_child(live)
	dead.free()
	var out: Array = trav.step(1.0 / 60.0, [
		{"body": dead, "from": Vector3(0, 0.05, 1.0)},
		{"body": live, "from": Vector3(0.5, 0.05, 1.0)},
	])
	_expect(out.size() == 1,
		"freed body aborted the phase (out=%d, refusal=%s)"
		% [out.size(), trav.last_refusal()])
	if out.size() == 1:
		_expect((out[0] as Dictionary)["body"] == live,
			"wrong body transferred")
		_expect(live.global_position.x > 100.0,
			"live body did not cross")
	live.queue_free()
