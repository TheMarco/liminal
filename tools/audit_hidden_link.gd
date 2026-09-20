extends SceneTree
## Package 3.2 gate: hidden-link dry traversal. Straight and quarter-turn
## mappings on built endpoint nodes, overlap equivalence, mismatch
## rejection, live bidirectional/reverse crossing with real physics,
## anti-jitter hysteresis, high-speed overshoot, clearance refusal, and
## opposite-side paired occupancy.
##
## Run:
##   godot --headless --path . --script tools/audit_hidden_link.gd

var failures: Array[String] = []
var fixture: TraversalLinkFixture


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
	_audit_admission()
	_audit_node_frames()
	_audit_round_trip()
	await _audit_live_crossing()
	await _audit_reverse_crossing()
	await _audit_hysteresis()
	await _audit_high_speed()
	await _audit_clearance_refusal()
	await _audit_opposite_meeting()
	_audit_band_derivation()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - hidden link dry traversal holds")
		quit()
	else:
		quit(1)


func _audit_admission() -> void:
	_expect(fixture.site_straight.admitted(),
		"straight site not admitted")
	_expect(fixture.site_turn.admitted(), "quarter-turn site not admitted")
	_expect(not fixture.site_mismatch.admitted()
		and fixture.site_mismatch.admit_reason() != "",
		"mismatched overlap collider not rejected")


func _audit_node_frames() -> void:
	for site in [fixture.site_straight, fixture.site_turn]:
		var b: Node3D = site.endpoint_b
		var fwd: Vector3 = b.global_transform.basis * Vector3(0, 0, 1)
		_expect(absf(fwd.y) < 0.0001,
			"endpoint B carries a baked half-turn")
		var geo: Node3D = site.paired_geometry
		var h := Basis(Vector3.UP, PI)
		_expect(_basis_close(geo.transform.basis, h),
			"paired geometry child is not exactly one H turn")
		var a: Node3D = site.endpoint_a
		_expect(TraversalLink.frames_valid(a.global_transform,
			b.global_transform), "built endpoint frames invalid")


func _basis_close(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) < 0.0001 \
		and a.y.distance_to(b.y) < 0.0001 \
		and a.z.distance_to(b.z) < 0.0001


func _audit_round_trip() -> void:
	var link: TraversalLink = fixture.link_turn
	var p := Vector3(1.0, 0.5, -2.0)
	var there: Vector3 = link.mapping() * p
	var back: Vector3 = link.inverse_mapping() * there
	_expect(back.distance_to(p) < 0.0001, "A->B->A point drifted")
	var v := Vector3(0.0, 0.0, -3.4)
	var vv: Vector3 = link.inverse_mapping().basis \
		* (link.mapping().basis * v)
	_expect(vv.distance_to(v) < 0.0001, "A->B->A velocity drifted")



func _synced_step(trav: SpatialTraversal, dt: float, motions: Array) -> Array:
	# Teleported rig bodies sync to the physics space on the next tick;
	# clearance casts must see synced positions, as in real play.
	await physics_frame
	return trav.step(dt, motions)


func _body_at(pos: Vector3) -> SpatialTestBody:
	var body := SpatialTestBody.create()
	body.position = pos
	root.add_child(body)
	return body


func _audit_live_crossing() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var notes: Array = []
	trav.set_listener(func(record: Dictionary) -> void:
		notes.append(record))
	# Approach straight-A along -Z from +Z, walking speed.
	var start := Vector3(0, 0.05, 5.0)
	var body := _body_at(start)
	body.planar_velocity = Vector3(0, 0, -3.4)
	var transfers := 0
	for i in 240:
		var from := body.global_position
		await physics_frame
		var out: Array = trav.step(1.0 / 60.0,
			[{"body": body, "from": from}])
		transfers += out.size()
		if transfers > 0:
			break
	_expect(transfers == 1, "live crossing transferred %d times"
		% transfers)
	_expect(notes.size() == 1, "listener not notified once")
	if notes.size() == 1:
		_expect(str(notes[0]["link"]) == fixture.link_straight.id,
			"listener notified for the wrong link")
		var m: Transform3D = fixture.link_straight.mapping()
		var expect: Vector3 = m * notes[0]["result"]
		_expect(body.global_position.distance_to(expect) < 0.01,
			"live mapped position disagrees with M * result")
	body.queue_free()


func _audit_reverse_crossing() -> void:
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var m: Transform3D = fixture.link_straight.mapping()
	# Start just past B on its approach side, walking back through.
	var begin := Vector3(200, 0.05, 2.5)
	var body := _body_at(begin)
	body.planar_velocity = Vector3(0, 0, -3.4)
	var transfers := 0
	for i in 240:
		var from := body.global_position
		await physics_frame
		transfers += trav.step(1.0 / 60.0,
			[{"body": body, "from": from}]).size()
		if transfers > 0:
			break
	_expect(transfers == 1, "reverse crossing transferred %d times"
		% transfers)
	_expect(body.global_position.x > -5.0
		and body.global_position.x < 5.0,
		"reverse crossing did not return near A")
	body.queue_free()


func _audit_hysteresis() -> void:
	# Drain bodies freed by the previous test: queue_free flushes at
	# iteration end, after a bare frame await resumes, so wait out a timer.
	await physics_frame
	await create_timer(0.1).timeout
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var body := _body_at(Vector3(0, 0.05, 0.02))
	var crossings := 0
	# 2cm jitter around the plane must not chatter.
	for i in 12:
		var from := body.global_position
		body.position = Vector3(0, 0.05, 0.02 if i % 2 == 0 else -0.02)
		var stepped: Array = await _synced_step(trav, 1.0 / 60.0,
			[{"body": body, "from": from}])
		crossings += stepped.size()
	_expect(crossings <= 1, "plane jitter chattered: %d" % crossings)
	# A deliberate reverse after clearing the band transfers again.
	var from := body.global_position
	body.position = Vector3(0, 0.05, 1.5)
	await _synced_step(trav,1.0 / 60.0, [{"body": body, "from": from}])
	from = body.global_position
	body.position = Vector3(0, 0.05, -1.5)
	var deliberate: Array = await _synced_step(trav,1.0 / 60.0,
		[{"body": body, "from": from}])
	_expect(deliberate.size() == 1, "deliberate reverse did not transfer")
	body.queue_free()


func _audit_high_speed() -> void:
	# Drain bodies freed by the previous test: queue_free flushes at
	# iteration end, after a bare frame await resumes, so wait out a timer.
	await physics_frame
	await create_timer(0.1).timeout
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var body := _body_at(Vector3(0, 0.05, 1.0))
	# 1.5m single step stays inside the band: transfers.
	var out: Array = await _synced_step(trav,1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 1.0)}])
	_expect(out.is_empty(), "no-motion step transferred")
	body.position = Vector3(0, 0.05, -0.5)
	out = await _synced_step(trav,1.0 / 60.0, [{"body": body,
		"from": Vector3(0, 0.05, 1.0)}])
	_expect(out.size() == 1, "in-band fast step refused")
	# Overshoot is transformed, never snapped to the exit centre:
	# M * (0, .05, -0.5) == (200, .05, +0.5) for the straight link.
	_expect(body.global_position.distance_to(
		Vector3(200, 0.05, 0.5)) < 0.01,
		"crossing snapped instead of transforming overshoot")
	# 5m single step exits beyond the band: refused, never half-mapped.
	trav.note_repositioned(body)
	body.position = Vector3(200, 0.05, -5.0)
	out = await _synced_step(trav,1.0 / 60.0, [{"body": body,
		"from": Vector3(200, 0.05, 1.0)}])
	_expect(out.is_empty()
		and trav.last_refusal() == "exit outside overlap band",
		"out-of-band step was not refused safely")
	body.queue_free()


func _audit_clearance_refusal() -> void:
	# Drain bodies freed by the previous test: queue_free flushes at
	# iteration end, after a bare frame await resumes, so wait out a timer.
	await physics_frame
	await create_timer(0.1).timeout
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	# Camper stands on the mapped exit of a crossing step.
	var m: Transform3D = fixture.link_straight.mapping()
	var exit: Vector3 = m * Vector3(0, 0.05, -0.5)
	var camper := _body_at(exit)
	await physics_frame
	var body := _body_at(Vector3(0, 0.05, 1.0))
	body.position = Vector3(0, 0.05, -0.5)
	var out: Array = await _synced_step(trav,1.0 / 60.0, [
		{"body": camper, "from": camper.global_position},
		{"body": body, "from": Vector3(0, 0.05, 1.0)},
	])
	_expect(out.is_empty(), "transfer into an occupied exit allowed")
	_expect(trav.last_refusal() == "exit occupied",
		"wrong refusal reason: %s" % trav.last_refusal())
	camper.queue_free()
	body.queue_free()


func _audit_opposite_meeting() -> void:
	# Drain bodies freed by the previous test: queue_free flushes at
	# iteration end, after a bare frame await resumes, so wait out a timer.
	await physics_frame
	await create_timer(0.1).timeout
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	# Same-lane opposite crossing swaps sides safely: neither exit is
	# occupied at transfer time, and the pair ends up 200m apart.
	# Bodies spawn at their result spots: creation plus a sync pump
	# registers server positions reliably, unlike same-block teleports.
	var north := _body_at(Vector3(-0.5, 0.05, -0.5))
	var south := _body_at(Vector3(200.5, 0.05, -0.5))
	var out: Array = await _synced_step(trav,1.0 / 60.0, [
		{"body": north, "from": Vector3(-0.5, 0.05, 1.0)},
		{"body": south, "from": Vector3(200.5, 0.05, 1.0)},
	])
	if out.size() != 2:
		print("  INFO meeting refusal: %s north=%s south=%s"
			% [trav.last_refusal(), str(north.global_position),
			str(south.global_position)])
		var space := north.get_world_3d().direct_space_state
		var params := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = Player.BODY_RADIUS
		shape.height = Player.BODY_HEIGHT
		params.shape = shape
		params.transform = Transform3D(Basis(),
			Vector3(200.5, 0.95, 0.5))
		params.collision_mask = 1
		params.exclude = [north.get_rid()]
		for hit in space.intersect_shape(params, 8):
			var collider: Object = hit["collider"]
			print("  INFO hit: %s at %s" % [str(collider),
				str((collider as Node3D).global_position)
				if collider is Node3D else "?"])
	_expect(out.size() == 2, "safe opposite meeting refused: %d"
		% out.size())
	_expect(north.global_position.distance_to(
		south.global_position) > 100.0, "paired volumes overlap")
	north.queue_free()
	south.queue_free()


func _audit_band_derivation() -> void:
	var need := Player.SPRINT_SPEED * HiddenLinkSite.SUPPORTED_MAX_DT \
		+ Player.BODY_RADIUS + HiddenLinkSite.BAND_MARGIN
	_expect(fixture.site_straight.overlap_half_depth() >= need,
		"overlap band smaller than the derived requirement")
	_expect(fixture.site_straight.aperture_fits(Player.BODY_RADIUS),
		"player capsule rejected by the aperture")
	_expect(not fixture.site_straight.aperture_fits(1.3),
		"oversize capsule admitted by the aperture")
