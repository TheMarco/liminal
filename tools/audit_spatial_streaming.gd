extends SceneTree
## Package 3.5 gate: link leases and streaming. Endpoint footprints with
## approach/exit bands lease before traversal; far ends live outside the
## player radius on site leases alone; enemy lookahead covers the exit
## cell; occupied teardown refuses; unload/reload preserves link identity;
## lost resources degrade without dropping the floor.

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
	_audit_footprint()
	_audit_enemy_lookahead()
	await _audit_lease_lifecycle()
	await _audit_degraded_retention()
	_audit_occupied_teardown()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - spatial streaming holds")
		quit()
	else:
		quit(1)


func _audit_footprint() -> void:
	var a := TraversalGraph.world_cell(Vector3.ZERO)
	var b := TraversalGraph.world_cell(Vector3(200, 0, 0))
	_expect(absi(a.x - b.x) > ChunkManager.UNLOAD_R,
		"fixture ends share the player radius")
	var cells: Array[Vector2i] = fixture.site_straight.streaming_cells()
	_expect(cells.has(a), "lease omits endpoint A")
	_expect(cells.has(b), "lease omits endpoint B")
	for sample in [Vector3(0, 0, 3.0), Vector3(0, 0, -3.0),
			Vector3(200, 0, 3.0), Vector3(200, 0, -3.0)]:
		_expect(cells.has(TraversalGraph.world_cell(sample)),
			"lease omits band sample %s" % sample)


func _audit_enemy_lookahead() -> void:
	var player := Player.new()
	player.position = Vector3(200, 0.05, 3.0)
	root.add_child(player)
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 3.0)
	# The far-side exit cell, not the current approach: arrival collision
	# must exist before the crossing lands.
	var exit_cell := TraversalGraph.world_cell(Vector3(200, 0, 1.0))
	_expect(figure.streaming_cells().has(exit_cell),
		"lookahead omits the exit cell")
	figure.traversal_graph = null
	_expect(not figure.streaming_cells().has(exit_cell),
		"legacy streaming changed")
	figure.queue_free()
	player.queue_free()


func _audit_lease_lifecycle() -> void:
	var manager := ChunkManager.new()
	manager.world_seed = 99173
	manager.theme = 10
	root.add_child(manager)
	manager.set_process(false)
	var player := CharacterBody3D.new()
	manager.add_child(player)
	manager.player = player
	player.position = Vector3(6.0, 1.0, 6.0)
	manager.warm_up(Vector2i.ZERO)
	manager._process(1.0 / 60.0)
	var cells: Array[Vector2i] = fixture.site_straight.streaming_cells()
	var far := TraversalGraph.world_cell(Vector3(200, 0, 0))
	manager.set_site_cells(cells)
	_pump(manager, func() -> bool: return manager.chunk_at(far) != null,
		"far end never built on its site lease")
	_expect(manager.chunk_at(far).body != null,
		"far end built without collision")
	var mapping: Transform3D = fixture.link_straight.mapping()
	# Enemy-only lease retains the far end after the site lease drops.
	manager.set_site_cells([])
	manager.set_hostile_cells([far])
	for tick in 5:
		manager._process(1.0 / 60.0)
	_expect(manager.chunk_at(far) != null,
		"hostile lease dropped the far end")
	# Nothing holds it: the far end unloads.
	manager.set_hostile_cells([])
	_pump(manager, func() -> bool: return manager.chunk_at(far) == null,
		"far end never unloaded")
	# Re-lease rebuilds the same link state, not a new connection.
	manager.set_site_cells(cells)
	_pump(manager, func() -> bool: return manager.chunk_at(far) != null,
		"far end never rebuilt")
	_expect(fixture.link_straight.mapping().is_equal_approx(mapping),
		"reload changed the link mapping")
	_expect(fixture.link_straight.enabled, "reload disabled the link")
	_expect(fixture.site_straight.admitted(),
		"reload unadmitted the site")
	manager.free()
	await physics_frame


## Run the manager until done or the cap, failing unless done.
func _pump(manager: ChunkManager, done: Callable, message: String) -> void:
	for tick in 120:
		manager._process(1.0 / 60.0)
		if bool(done.call()):
			return
	_expect(false, "%s (queued %d)" % [message, manager.queued.size()])


func _audit_degraded_retention() -> void:
	var site := fixture.site_straight
	var before: Array[Vector2i] = site.streaming_cells()
	site.note_resource_lost("arrival lease revoked")
	_expect(not site.link.enabled, "lost resource kept the link live")
	_expect(site.admitted(), "lost resource dropped the scene")
	_expect(site.streaming_cells() == before,
		"lost resource shrank the lease")
	_expect(site.faults().size() == 1
		and str(site.faults()[0]["reason"]) == "arrival lease revoked",
		"fault went unreported")
	_expect(not site.suspended().is_empty(), "suspension unrecorded")
	# Traversal and perception stop, actors stay put.
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var trav := SpatialTraversal.new()
	trav.add_site(site)
	var out: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 0.5)}])
	_expect(out.is_empty(), "suspended link transferred")
	_expect(body.global_position.distance_to(
		Vector3(0, 0.05, 0.5)) < 0.0001, "suspended link let an actor escape into continuation")
	body.queue_free()
	await physics_frame
	# Recovery re-proves the bands and resumes the same link.
	var space := root.get_world_3d().direct_space_state
	var resumed := site.resume(space, [])
	_expect(bool(resumed["ok"]), "recovery refused: %s" % resumed)
	_expect(site.link.enabled and site.suspended().is_empty(),
		"recovery left the link down")
	_expect(site.faults().size() == 1, "recovery rewrote history")


func _audit_occupied_teardown() -> void:
	var site := fixture.site_straight
	var refused := site.request_release([Vector3(0, 0.05, 1.0)])
	_expect(not bool(refused["ok"]), "occupied teardown allowed")
	_expect(site.admitted(), "refused teardown unadmitted the site")
	var freed := site.request_release([Vector3(50, 0.05, 50.0)])
	_expect(bool(freed["ok"]), "empty teardown refused: %s" % freed)
	_expect(not site.admitted() and not site.link.enabled,
		"teardown left the link live")
	# The fixture link returns to service for no one after this; restore
	# it anyway so audit order never matters.
	var space := root.get_world_3d().direct_space_state
	site.admit(space)
