extends SceneTree
## Package 3.6 gate: a live player walks the straight seam tick by tick
## under real physics (dev_walk drive, visit-tool stepping loop). Asserts
## admission, exactly one a_to_b transfer with arrival pose M, no
## ping-pong on continued forward motion, and one b_to_a transfer on the
## walked return. Regression test for the visit-walkthrough fall: prior
## crossing coverage teleported the body and handed step() an explicit
## segment, so a dead live loop could hide behind green gates.

var failures: Array[String] = []
var transfers: Array = []
var fell := false


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 40:
		failures.append(message)


## The production actor hooks perform crossing inside the movement tick.
func _tick(player: Player, trav: SpatialTraversal,
		extra: Array = []) -> void:
	trav.bind_actor(player)
	for body in extra:
		if not is_instance_valid(body):
			continue
		trav.bind_actor(body)
	await physics_frame
	if not is_instance_valid(player):
		return
	if player.global_position.y < -0.5:
		fell = true
	for body in extra:
		if is_instance_valid(body) \
				and (body as Node3D).global_position.y < -0.5:
			fell = true


func _run() -> void:
	var fixture := TraversalLinkFixture.new()
	fixture.debug_marks = false
	root.add_child(fixture)
	fixture.build()
	for i in 8:
		await process_frame
	fixture.admit_all()
	_expect(fixture.site_straight.admitted(),
		"straight site did not admit: %s"
		% fixture.site_straight.admit_reason())
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	trav.set_listener(func(record: Dictionary) -> void:
		transfers.append(record))
	var graph := fixture.graph_for(fixture.site_straight)
	var player := Player.new()
	player.position = Vector3(0, 0.05, 2.0)
	root.add_child(player)
	for i in 30:
		await physics_frame
	_expect(player.is_on_floor(), "player never settled on the floor")
	_expect(player.seam_transfer_eligible(),
		"settled walking player ineligible to cross")
	# Leg 1: walk forward through the seam.
	player.dev_walk = true
	for i in 600:
		await _tick(player, trav)
		if transfers.size() >= 1 or fell:
			break
	_expect(not fell, "player fell into the void before any crossing")
	_expect(transfers.size() == 1,
		"forward walk produced %d transfers, want 1" % transfers.size())
	if transfers.size() == 1:
		var first: Dictionary = transfers[0]
		_expect(str(first["direction"]) == "a_to_b",
			"forward walk went %s" % first["direction"])
		var want: Vector3 = fixture.link_straight.mapping() \
			* (first["result"] as Vector3)
		_expect(player.global_position.distance_to(want) < 0.1,
			"arrival %s not at M(result) %s"
			% [player.global_position, want])
		_expect(absf(player.global_position.x - 200.0) < 0.1,
			"arrival not on the B side: %s" % player.global_position)
	# Leg 2: keep walking; the Schmitt trigger must not re-fire.
	var mark := transfers.size()
	for i in 180:
		await _tick(player, trav)
		if player.global_position.z > 2.0 or fell:
			break
	_expect(not fell, "player fell after the crossing")
	_expect(transfers.size() == mark,
		"%d extra transfers on continued forward motion"
		% (transfers.size() - mark))
	# Leg 3: turn around, walk back across the same seam.
	player.dev_walk = false
	player.rotate_y(PI)
	await physics_frame
	player.dev_walk = true
	for i in 600:
		await _tick(player, trav)
		if transfers.size() > mark or fell:
			break
	player.dev_walk = false
	_expect(not fell, "player fell during the return walk")
	_expect(transfers.size() == mark + 1,
		"return walk produced %d transfers, want 1"
		% (transfers.size() - mark))
	if transfers.size() == mark + 1:
		var back: Dictionary = transfers[mark]
		_expect(str(back["direction"]) == "b_to_a",
			"return walk went %s" % back["direction"])
		_expect(absf(player.global_position.x) < 0.1,
			"return arrival not on the A side: %s" % player.global_position)
	_expect(str(trav.last_refusal()).is_empty(),
		"unexpected refusal recorded: %s" % trav.last_refusal())
	# Leg 4: a live pursuer chases the walking player through the seam.
	# The manual retest logged player crossings only, so the enemy half
	# of the walkthrough is unproven without this leg. Face the seam
	# first: leg 3 leaves the player facing away, and walking into the
	# pursuer reads as a catch, not a chase.
	player.rotate_y(PI)
	await physics_frame
	player.dev_walk = true
	var figure := ShadowFigure.new()
	figure.player = player
	figure.traversal_graph = graph
	figure.set("_seen", true)
	figure.grace = 0.0
	figure.position = Vector3(0, 0.05, 5.5)
	root.add_child(figure)
	# Keep the normal encounter budget: a seam is not a room transition.
	var figure_xfers := 0
	var trail: Array = []
	var figure_valid := true
	for i in 1800:
		if not is_instance_valid(figure):
			figure_valid = false
			break
		await _tick(player, trav, [figure])
		if not is_instance_valid(figure):
			figure_valid = false
			break
		if i % 60 == 0:
			trail.append("%s fade=%s giveup=%s doors=%s rooms=%s/%s" % [
				figure.global_position, figure.get("_fade"),
				figure.get("_giving_up"), figure.get("_chase_doors"),
				ShadowFigure.room_for(player,
					figure.global_position),
				ShadowFigure.room_for(player,
					player.global_position)])
		for r in transfers:
			if r["body"] == figure:
				figure_xfers += 1
		if figure_xfers >= 1 or fell:
			break
	player.dev_walk = false
	# Count once: the loop above tallies cumulatively per tick.
	figure_xfers = 0
	for r in transfers:
		if figure_valid and r["body"] == figure:
			figure_xfers += 1
	_expect(not fell, "someone fell during the pursuit leg")
	_expect(figure_valid,
		"pursuer freed itself mid-chase at %s (trail %s, refusal %s)"
		% [figure.global_position if is_instance_valid(figure) else "?",
			trail, trav.last_refusal()])
	_expect(figure_xfers >= 1,
		"live pursuer never crossed (trail %s, refusal: %s)"
		% [trail, trav.last_refusal()])
	if is_instance_valid(figure):
		figure.free()
	player.free()
	fixture.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - live seam walk crosses once each way, pursuer follows")
		quit()
	else:
		quit(1)
