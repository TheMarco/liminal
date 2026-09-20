extends SceneTree
## Package 3.5 gate: connectivity revisions and failure handling. Figures
## invalidate navigation caches on revision while permits, presentation,
## and encounter state survive; stale permits refuse loudly; failed
## preparation keeps the old route; suspension before or after exposure
## stops the link with geometry and leases retained.

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
	graph.register_link(fixture.link_straight,
		AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	graph.register_link(fixture.link_turn,
		AABB(Vector3(-6, -1, 44), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, 44), Vector3(12, 4, 12)))
	await _audit_revision_invalidation()
	_audit_permit_lifecycle()
	await _audit_failed_preparation()
	await _audit_suspend_before_exposure()
	await _audit_suspend_after_exposure()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - spatial revisions hold")
		quit()
	else:
		quit(1)


func _pair() -> Dictionary:
	var player := Player.new()
	player.position = Vector3(200, 0.05, 3.0)
	root.add_child(player)
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 3.0)
	return {"player": player, "figure": figure}


func _audit_revision_invalidation() -> void:
	var pair := _pair()
	var figure: ShadowFigure = pair["figure"]
	await physics_frame
	# Seed every navigation cache with stale far-side state.
	figure.set("_route_from", Vector2i(5, 5))
	figure.set("_route_goal", Vector2i(6, 6))
	figure.set("_route_next", Vector2i(6, 6))
	figure.set("_route_waypoint", Vector3(1, 2, 3))
	figure.set("_direct_route_left", 9.0)
	figure.set("_direct_route_clear", true)
	figure.get("_local_path").set("_target", Vector3(9, 9, 9))
	figure.set("_avoid_left", 0.4)
	figure.set("_avoid_direction", Vector3(1, 0, 0))
	figure.set("_recovery_left", 0.3)
	figure.set("_blocked_time", 1.2)
	figure.set("_travel_speed", 2.5)
	figure.set("_catch_presentation", Vector3(7, 7, 7))
	var pos := figure.global_position
	figure.revise_topology()
	_expect(figure.get("_route_from") == ShadowFigure.NO_ROOM
		and figure.get("_route_goal") == ShadowFigure.NO_ROOM
		and figure.get("_route_next") == ShadowFigure.NO_ROOM
		and figure.get("_route_waypoint") == Vector3.INF,
		"room route survived revision")
	_expect(float(figure.get("_direct_route_left")) <= 0.0
		and not bool(figure.get("_direct_route_clear")),
		"direct cache survived revision")
	_expect(figure.get("_local_path").get("_target") == Vector3.INF,
		"local search survived revision")
	_expect(float(figure.get("_avoid_left")) <= 0.0
		and float(figure.get("_recovery_left")) <= 0.0
		and float(figure.get("_blocked_time")) <= 0.0
		and float(figure.get("_travel_speed")) <= 0.0,
		"steering state survived revision")
	_expect(figure.global_position.distance_to(pos) < 0.0001,
		"revision moved the actor")
	_expect(figure.traversal_graph == graph,
		"revision dropped the adapter")
	_expect(figure.get("_catch_presentation").distance_to(
		Vector3(7, 7, 7)) < 0.0001, "revision cleared the presentation")
	# The poll path revises before the next movement decision. Avoidance
	# is the tell: diversion also clears routes, but only a revision
	# clears a held avoidance direction.
	figure.set("_avoid_left", 0.4)
	graph.set_link_enabled("link:turn", false)
	figure._route_target(1.0 / 60.0)
	_expect(float(figure.get("_avoid_left")) <= 0.0,
		"revision did not precede routing")
	graph.set_link_enabled("link:turn", true)
	# Direct flag flips invalidate too, without the setter. Settle the
	# fingerprint first so only the raw flag differs on the next call.
	figure._route_target(1.0 / 60.0)
	figure.set("_avoid_left", 0.4)
	fixture.link_turn.enabled = false
	figure._route_target(1.0 / 60.0)
	_expect(float(figure.get("_avoid_left")) <= 0.0,
		"direct flag flip went unnoticed")
	fixture.link_turn.enabled = true
	pair["figure"].queue_free()
	pair["player"].queue_free()
	await physics_frame


func _audit_permit_lifecycle() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	trav.add_site(fixture.site_turn)
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var permit := trav.issue_permit(body, "link:straight")
	_expect(bool(permit.get("ok")), "readiness refused a live link")
	# Revision noise on the other link: the token stays valid.
	graph.set_link_enabled("link:turn", false)
	var out: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5), "permit": permit}])
	_expect(out.size() == 1, "valid token refused after noise")
	graph.set_link_enabled("link:turn", true)
	# The named link goes down: loud stale refusal, actor held in place.
	body.global_position = Vector3(0, 0.05, -0.5)
	trav.note_repositioned(body)
	graph.set_link_enabled("link:straight", false)
	var out2: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5), "permit": permit}])
	_expect(out2.is_empty(), "stale token transferred")
	_expect(trav.last_refusal() == "stale permit",
		"wrong refusal: %s" % trav.last_refusal())
	_expect(body.global_position.distance_to(
		Vector3(0, 0.05, 0.5)) < 0.0001, "refused actor escaped the approach")
	# A permit for the wrong link fails closed.
	graph.set_link_enabled("link:straight", true)
	body.global_position = Vector3(0, 0.05, -0.5)
	trav.note_repositioned(body)
	var wrong := trav.issue_permit(body, "link:turn")
	var out3: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5), "permit": wrong}])
	_expect(out3.is_empty(), "foreign permit transferred")
	_expect(trav.last_refusal() == "permit names another link",
		"wrong refusal: %s" % trav.last_refusal())
	# Unknown links and dead sites refuse at issue, not at the plane.
	_expect(not bool(trav.issue_permit(body, "link:nope").get("ok")),
		"permit issued for an unknown link")
	body.queue_free()


func _audit_failed_preparation() -> void:
	var player := Player.new()
	player.position = Vector3(0, 0.05, 3.0)
	root.add_child(player)
	var figure := ShadowFigure.new()
	figure.player = player
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 5.0)
	await physics_frame
	# Tilted frames cannot prepare; the ordinary route never notices.
	var site := HiddenLinkSite.new()
	root.add_child(site)
	var bad := site.prepare("link:tilted", Transform3D(Basis(),
		Vector3(0, 0, 0)), Transform3D(
		Basis(Vector3.FORWARD, 0.3), Vector3(200, 0, 0)))
	_expect(not bool(bad["ok"]), "tilted frames prepared")
	_expect(site.link == null, "failed preparation built a link")
	var target: Vector3 = figure._route_target(1.0 / 60.0)
	_expect(target.distance_to(player.global_position) < 0.01,
		"failed preparation broke the old route")
	site.queue_free()
	figure.queue_free()
	player.queue_free()
	await physics_frame


func _audit_suspend_before_exposure() -> void:
	var site := fixture.site_straight
	site.suspend("pacing withdrew the link")
	_expect(not site.link.enabled, "suspension kept the link live")
	_expect(site.admitted(), "suspension dropped the scene")
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var trav := SpatialTraversal.new()
	trav.add_site(site)
	var out: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5)}])
	_expect(out.is_empty(), "suspended link transferred")
	var space := root.get_world_3d().direct_space_state
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), [site.link])
	_expect(not bool(seen["visible"]), "suspended link answered sight")
	# Recovery waits for the occupant rather than sampling through it.
	var early := site.resume(space, [body.global_position])
	_expect(not bool(early["ok"]), "occupied recovery admitted")
	body.queue_free()
	await physics_frame
	var resumed := site.resume(space, [])
	_expect(bool(resumed["ok"]), "recovery refused: %s" % resumed)


func _audit_suspend_after_exposure() -> void:
	var site := fixture.site_straight
	_expect(site.link.enabled, "link down entering exposure")
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var trav := SpatialTraversal.new()
	trav.add_site(site)
	var before := site.streaming_cells()
	var crossed: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5)}])
	_expect(crossed.size() == 1, "exposure crossing failed")
	_expect(body.global_position.distance_to(
		Vector3(200, 0.05, 0.5)) < 0.01, "exposure mislanded")
	site.suspend("arrival floor lost its lease")
	body.global_position = Vector3(0, 0.05, -0.5)
	trav.note_repositioned(body)
	var again: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5)}])
	_expect(again.is_empty(), "suspended link transferred again")
	_expect(body.global_position.distance_to(
		Vector3(0, 0.05, 0.5)) < 0.0001,
		"suspension let the actor escape into continuation")
	_expect(site.streaming_cells() == before,
		"suspension shrank the lease")
	_expect(site.admitted(), "suspension dropped the scene")
	body.queue_free()
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	var resumed := site.resume(space, [])
	_expect(bool(resumed["ok"]), "recovery refused: %s" % resumed)
