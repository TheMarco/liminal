extends SceneTree
## Package 3 exit integration: the real consumers, wired beyond fixtures.
## Real DescentHUD metres measured through links, real traversal notifying
## a real audio bridge on transfer batches, real manager propagating its
## graph to spawns, and route guidance shortening across injected link
## cells. Geometry rigs are fixtures where physics requires them; every
## subject under test is a production class.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 40:
		failures.append(message)


func _link_graph() -> TraversalGraph:
	var graph := TraversalGraph.new()
	var link := TraversalLink.new("t", "ra", "rb", Transform3D.IDENTITY,
		Transform3D(Basis(), Vector3(200, 0, 0)), 2.4)
	graph.register_link(link,
		AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	return graph


## The lift instrument must read the through-link distance once it has a
## graph, and legacy raw metres without one.
func _audit_hud_metres() -> void:
	var player := Player.new()
	player.position = Vector3(0, 0.05, 4.5)
	root.add_child(player)
	var bounty := RealmFlashBounty.new()
	bounty.bounds = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	bounty.position = Vector3(200, 0.05, 4.5)
	root.add_child(bounty)
	var hud := DescentHUD.new()
	root.add_child(hud)
	hud.player = player
	hud.flash_bounty = bounty
	hud.set_active(true)
	for i in 2:
		await process_frame
	var raw: String = (hud.get("_distance") as Label).text
	hud.traversal_graph = _link_graph()
	for i in 2:
		await process_frame
	var linked: String = (hud.get("_distance") as Label).text
	_expect(raw == "200m", "raw HUD metres read %s, want 200m" % raw)
	_expect(linked == "9m", "linked HUD metres read %s, want 9m" % linked)
	hud.free()
	bounty.free()
	player.free()


## Transfers must duck the attached bridge without any driver call, and
## the duck must decay back through the normal update.
func _audit_bridge_duck() -> void:
	var fixture := TraversalLinkFixture.new()
	fixture.debug_marks = false
	root.add_child(fixture)
	fixture.build()
	for i in 8:
		await process_frame
	fixture.admit_all()
	_expect(fixture.site_straight.admitted(), "straight site did not admit")
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var bridge := SeamAudioBridge.new()
	trav.set_audio_bridge(bridge)
	var body := SpatialTestBody.create()
	body.position = Vector3(0, 0.05, -0.5)
	root.add_child(body)
	var out: Array = trav.step(1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 1.0)}])
	_expect(out.size() == 1, "crossing body did not transfer")
	_expect(bridge.duck_level() == 1.0,
		"transfer batch did not duck the bridge")
	bridge.update(Vector3.ZERO, [fixture.link_straight],
		fixture.get_world_3d().direct_space_state, 0.2)
	_expect(bridge.duck_level() == 0.0, "duck did not decay")
	body.queue_free()
	fixture.free()


## Spawns must carry the manager's graph so live figures route, see, and
## mirror through links without fixture setup.
func _audit_propagation() -> void:
	var player := Player.new()
	player.level_theme = 3
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	var manager := ShadowFigures.new()
	root.add_child(manager)
	manager.player = player
	manager.allow_reinforcements = true
	var graph := _link_graph()
	manager.traversal_graph = graph
	ShadowWalkerVisual.request_model(0)
	var ready := false
	for i in 600:
		if ShadowWalkerVisual.is_model_ready(0):
			ready = true
			break
		await process_frame
	_expect(ready, "walker model 0 never became ready")
	if not ready:
		manager.free()
		player.free()
		return
	# Typed: the bag is Array[int] and set() drops untyped arrays,
	# which used to fall through to a shuffled refill and flake.
	var bag: Array[int] = [0]
	manager.set("_dark_bag", bag)
	manager.set("_walker_due", false)
	var spawned: bool = manager._spawn_at(Vector3(0, 0.05, 5.5),
		false, 0.0)
	_expect(spawned, "manager refused a clear spawn")
	if spawned:
		var figs := manager.active_figures()
		_expect(figs.size() == 1, "want 1 figure, have %d" % figs.size())
		if figs.size() == 1:
			_expect(figs[0].traversal_graph == graph,
				"spawned figure did not inherit the graph")
	manager.free()
	player.free()


## Injected link cells must shorten route guidance as single steps, which
## is the mechanism the rooms readout rides on.
func _audit_route_cells() -> void:
	var route := DescentRoute.new()
	route.world_seed = 7
	route.theme = 1
	var t0 := Vector2i(1 << 30, 1 << 30)
	var found := false
	for x in range(-40, 40):
		for z in range(-40, 40):
			var a := Vector2i(x, z)
			var b := Vector2i(x + 1, z)
			var c := Vector2i(x + 2, z)
			if route.base_is_wall(a, 0) or route.base_is_wall(b, 1) \
					or route.base_is_wall(b, 0) \
					or route.base_is_wall(c, 1):
				continue
			t0 = a
			found = true
			break
		if found:
			break
	_expect(found, "no open triple in the seed scan")
	if not found:
		return
	var t1 := t0 + Vector2i(1, 0)
	var t2 := t0 + Vector2i(2, 0)
	route.target = t2
	route.set("_origin_distance", {t0: 0, t1: 0, t2: 0})
	route.set_traversal_link_cells([])
	_expect(route.distance_from_target(t0) == 2,
		"plain distance reads %d, want 2"
		% route.distance_from_target(t0))
	route.set_traversal_link_cells([[t0, t2]])
	_expect(route.distance_from_target(t0) == 1,
		"linked distance reads %d, want 1"
		% route.distance_from_target(t0))
	var nxt: Dictionary = route.get("_next")
	_expect(nxt.get(t0) == t2, "route does not step across the link")


func _run() -> void:
	await _audit_hud_metres()
	await _audit_bridge_duck()
	await _audit_propagation()
	_audit_route_cells()
	ShadowWalkerVisual.clear_runtime_caches()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - spatial consumers wired beyond fixtures")
		quit()
	else:
		quit(1)
