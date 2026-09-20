extends SceneTree
## Package 3.4 gate: bounded one-link perception. Direct sight preferred,
## linked sight verified as two real rays with summed range, aperture
## misses and wall blocks rejected, contact with presentation poses, peer
## mapping without rays, and audio path selection with an honest fallback.

const CAUGHT_SEQUENCE := preload("res://scripts/caught_sequence.gd")

var failures: Array[String] = []
var fixture: TraversalLinkFixture
var space: PhysicsDirectSpaceState3D
var links: Array


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
	space = root.get_world_3d().direct_space_state
	links = [fixture.link_straight]
	_audit_direct()
	_audit_linked_sight()
	await _audit_blocked_link()
	_audit_aperture_miss()
	_audit_disabled_link()
	_audit_contact()
	_audit_peer_mapping()
	_audit_apparent_pose()
	await _audit_audio_path()
	await _audit_figure_sight()
	await _audit_catch_framing()
	_audit_ambient_exclusion()
	await physics_frame
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - spatial queries hold")
		quit()
	else:
		quit(1)


func _audit_direct() -> void:
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 4.0),
		Vector3(0, 1.4, 0.5), links)
	_expect(bool(seen["visible"]), "open corridor sight invisible")
	_expect(str(seen["via_link"]) == "", "direct sight took a link")
	_expect(absf(float(seen["distance"]) - 3.5) < 0.01,
		"direct distance wrong: %s" % seen["distance"])
	_expect((seen["apparent"] as Vector3).distance_to(
		Vector3(0, 1.4, 0.5)) < 0.0001, "direct apparent moved")
	# Corridor side wall blocks the diagonal out of the passage.
	var walled := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(30, 1.4, 3.0), [])
	_expect(not bool(walled["visible"]), "sight through side wall")


func _audit_linked_sight() -> void:
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(bool(seen["visible"]), "linked sight invisible")
	_expect(str(seen["via_link"]) == "link:straight",
		"wrong link: %s" % seen["via_link"])
	_expect(absf(float(seen["distance"]) - 6.0) < 0.01,
		"linked distance not summed: %s" % seen["distance"])
	_expect((seen["apparent"] as Vector3).distance_to(
		Vector3(0, 1.4, -3.0)) < 0.01,
		"wrong apparent pose: %s" % seen["apparent"])
	_expect((seen["crossing"] as Vector3).distance_to(
		Vector3(0, 1.4, 0.0)) < 0.01,
		"wrong crossing: %s" % seen["crossing"])
	# Reverse direction answers symmetrically.
	var back := SpatialQuery.sight(space, Vector3(200, 1.4, 3.0),
		Vector3(0, 1.4, 3.0), links)
	_expect(bool(back["visible"]), "reverse linked sight invisible")
	_expect(absf(float(back["distance"]) - 6.0) < 0.01,
		"reverse distance wrong: %s" % back["distance"])


func _audit_blocked_link() -> void:
	# A crate on the destination half blocks the mapped ray only.
	var crate := _solid_box(Vector3(200, 1.0, 1.5), Vector3(2.0, 2.0, 0.5))
	await physics_frame
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(not bool(seen["visible"]),
		"sight through destination occluder")
	crate.queue_free()
	await physics_frame
	var clear_again := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(bool(clear_again["visible"]),
		"sight did not recover after occluder removal")
	# A crate on the source half blocks the source ray the same way.
	var crate2 := _solid_box(Vector3(0, 1.0, 1.5), Vector3(2.0, 2.0, 0.5))
	await physics_frame
	var seen2 := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(not bool(seen2["visible"]), "sight through source occluder")
	crate2.queue_free()
	await physics_frame


func _audit_aperture_miss() -> void:
	# Mapped segment crosses the seam plane outside the passage width.
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(196, 1.4, 3.0), links)
	_expect(not bool(seen["visible"]), "sight past the aperture edge")
	# A mapped segment crossing the plane above the passage misses too.
	var over := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 5.0, 3.0), links)
	_expect(not bool(over["visible"]), "sight over the aperture top")


func _audit_disabled_link() -> void:
	fixture.link_straight.enabled = false
	var seen := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(not bool(seen["visible"]), "disabled link answered sight")
	var felt := SpatialQuery.apparent_position(Vector3(0, 0.05, 3.0),
		Vector3(200, 0.05, 3.0), links)
	_expect(felt.distance_to(Vector3(200, 0.05, 3.0)) < 0.0001,
		"disabled link mapped a peer")
	fixture.link_straight.enabled = true
	var back := SpatialQuery.sight(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(bool(back["visible"]), "reenabled link silent")


func _audit_contact() -> void:
	# Nose to nose through the seam: mapped reach, mapped presentation.
	var touch := SpatialQuery.contact(space, Vector3(0, 0.9, 0.5),
		Vector3(200, 0.9, -0.5), 1.0, links)
	_expect(bool(touch["touching"]), "linked contact missed")
	_expect(str(touch["via_link"]) == "link:straight",
		"contact lost its link")
	_expect((touch["presentation"] as Vector3).distance_to(
		Vector3(0, 0.9, 0.5)) < 0.01,
		"wrong contact presentation: %s" % touch["presentation"])
	# Out of mapped reach is no catch.
	var far := SpatialQuery.contact(space, Vector3(0, 0.9, 2.5),
		Vector3(200, 0.9, -0.5), 1.0, links)
	_expect(not bool(far["touching"]), "contact past mapped reach")
	# Direct contact keeps the real pose.
	var direct := SpatialQuery.contact(space, Vector3(0, 0.9, 1.0),
		Vector3(0, 0.9, 1.5), 1.0, links)
	_expect(bool(direct["touching"]), "direct contact missed")
	_expect((direct["presentation"] as Vector3).distance_to(
		Vector3(0, 0.9, 1.5)) < 0.0001, "direct presentation moved")


func _audit_peer_mapping() -> void:
	var mapped := SpatialQuery.apparent_position(Vector3(0, 0.05, 0.5),
		Vector3(200, 0.05, -0.5), links)
	_expect(mapped.distance_to(Vector3(0, 0.05, 0.5)) < 0.01,
		"peer unmapped: %s" % mapped)
	var same := SpatialQuery.apparent_position(Vector3(0, 0.05, 1.0),
		Vector3(0, 0.05, 4.0), links)
	_expect(same.distance_to(Vector3(0, 0.05, 4.0)) < 0.0001,
		"same-side peer moved")
	var dist := SpatialQuery.mapped_distance(Vector3(0, 0.05, 0.5),
		Vector3(200, 0.05, -0.5), links)
	_expect(absf(dist) < 0.01, "mapped distance wrong: %s" % dist)


func _audit_apparent_pose() -> void:
	# Straight links mirror heading: a peer walking away on the far side
	# approaches on this side.
	var pose := SpatialQuery.apparent_pose(Vector3(0, 0.05, 0.5),
		Vector3(200, 0.05, -0.5), links)
	_expect(str(pose["via_link"]) == "link:straight",
		"pose lost its link")
	var mapped_v := (pose["basis"] as Basis) * Vector3(0, 0, -3.0)
	_expect(mapped_v.distance_to(Vector3(0, 0, 3.0)) < 0.01,
		"peer velocity unmirrored: %s" % mapped_v)
	var direct := SpatialQuery.apparent_pose(Vector3(0, 0.05, 1.0),
		Vector3(0, 0.05, 4.0), links)
	_expect(str(direct["via_link"]) == "",
		"same-side pose took a link")
	_expect((direct["basis"] as Basis).is_equal_approx(Basis.IDENTITY),
		"direct basis not identity")
	# Quarter-turn coincidence answers with a rigid basis.
	var turn := SpatialQuery.apparent_pose(Vector3(0, 1.4, 53.0),
		Vector3(197, 1.4, 50.0), [fixture.link_turn])
	_expect(str(turn["via_link"]) == "link:turn",
		"turn pose missed: %s" % turn["via_link"])
	_expect((turn["position"] as Vector3).distance_to(
		Vector3(0, 1.4, 53.0)) < 0.01,
		"turn coincidence off: %s" % turn["position"])
	_expect(absf((turn["basis"] as Basis).determinant() - 1.0) < 0.01,
		"turn basis not a rotation")


func _audit_audio_path() -> void:
	# Clear direct line wins over any link.
	var direct := SpatialQuery.audio_path(space, Vector3(0, 1.4, 4.0),
		Vector3(0, 1.4, 0.5), links)
	_expect(str(direct["via_link"]) == "", "direct audio took a link")
	_expect(absf(float(direct["distance"]) - 3.5) < 0.01,
		"direct audio distance wrong")
	# Blocked direct with an open link bridges with summed distance.
	var wall := _solid_box(Vector3(15, 1.4, 3.0), Vector3(0.5, 3.0, 3.0))
	await physics_frame
	var bridged := SpatialQuery.audio_path(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(str(bridged["via_link"]) == "link:straight",
		"audio did not bridge")
	_expect(absf(float(bridged["distance"]) - 6.0) < 0.01,
		"bridged audio distance wrong: %s" % bridged["distance"])
	_expect((bridged["position"] as Vector3).distance_to(
		Vector3(0, 1.4, -3.0)) < 0.01, "bridged audio misplaced")
	wall.queue_free()
	await physics_frame
	# Nothing audible: honest direct fallback, never silence.
	fixture.link_straight.enabled = false
	var wall2 := _solid_box(Vector3(15, 1.4, 3.0), Vector3(0.5, 3.0, 3.0))
	await physics_frame
	var fallback := SpatialQuery.audio_path(space, Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0), links)
	_expect(str(fallback["via_link"]) == "", "fallback claimed a link")
	_expect((fallback["position"] as Vector3).distance_to(
		Vector3(200, 1.4, 3.0)) < 0.0001, "fallback moved the emitter")
	fixture.link_straight.enabled = true
	wall2.queue_free()
	await physics_frame


func _audit_figure_sight() -> void:
	var graph := TraversalGraph.new()
	graph.register_link(fixture.link_straight,
		AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)),
		AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	var player := Player.new()
	player.position = Vector3(200, 0.05, 3.0)
	root.add_child(player)
	var figure := ShadowFigure.new()
	figure.player = player
	# Seen before: no first-sighting stinger, whose cached stream and
	# server-side playback cannot be released before exit.
	figure.set("_seen", true)
	root.add_child(figure)
	figure.global_position = Vector3(0, 0.05, 3.0)
	await physics_frame
	# Legacy first: a wall stands between the distant pair.
	_expect(not figure._clear_line(Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0)), "legacy sight crossed the wall")
	figure.traversal_graph = graph
	_expect(figure._clear_line(Vector3(0, 1.4, 3.0),
		Vector3(200, 1.4, 3.0)), "figure blind through open link")
	var seen := figure._seam_sight(Vector3(200, 1.4, 3.0),
		Vector3(0, 1.4, 3.0))
	_expect(absf(float(seen["distance"]) - 6.0) < 0.01,
		"figure sight range wrong: %s" % seen["distance"])
	# A mirror-coincident peer reads on this side with mirrored velocity.
	# No ticks between placement and checks: full AI would drift the pair.
	var peer := ShadowFigure.new()
	peer.player = player
	peer.set("_seen", true)
	root.add_child(peer)
	peer.global_position = Vector3(200, 0.05, -0.5)
	figure.global_position = Vector3(0, 0.05, 0.5)
	peer.ground_velocity = Vector3(0, 0, -3.0)
	_expect(figure._peer_position(peer).distance_to(
		Vector3(0, 0.05, 0.5)) < 0.01,
		"peer unmapped: %s" % figure._peer_position(peer))
	_expect(figure._peer_velocity(peer).distance_to(
		Vector3(0, 0, 3.0)) < 0.01, "peer velocity unmapped")
	# Heartbeat proximity follows the mapped distance: 0.3m each side of
	# the seam reads closer than adjacent rooms, not 200m apart.
	player.position = Vector3(200, 0.05, 0.3)
	figure.global_position = Vector3(0, 0.05, 0.3)
	var figures := ShadowFigures.new()
	figures.player = player
	figures.traversal_graph = graph
	figures._figs.append(figure)
	_expect(figures.nearest_distance() < 1.0,
		"nearest distance unmapped: %s" % figures.nearest_distance())
	figures.traversal_graph = null
	_expect(figures.nearest_distance() > 100.0,
		"legacy nearest distance changed")
	figures.free()
	peer.queue_free()
	figure.queue_free()
	player.queue_free()
	await physics_frame


func _audit_catch_framing() -> void:
	var player := Player.new()
	player.position = Vector3(0, 0.05, 3.0)
	root.add_child(player)
	await physics_frame
	var figure := ShadowFigure.new()
	figure.player = player
	figure.set("_seen", true)
	root.add_child(figure)
	figure.global_position = Vector3(200, 0.05, 3.0)
	await physics_frame
	figure.global_position = Vector3(200, 0.05, 3.0)
	var seq := CAUGHT_SEQUENCE.new()
	root.add_child(seq)
	seq.begin(player, figure, Vector3(0, 0.05, 2.0))
	_expect(seq.get("_from").distance_to(Vector3(0, 0.05, 2.0)) < 0.0001,
		"catch did not frame the presentation")
	_expect(bool(seq.get("_span_freeze")), "spanning catch unfrozen")
	seq._sample(0.4)
	_expect(figure.global_position.distance_to(
		Vector3(200, 0.05, 3.0)) < 0.0001,
		"spanning catch dragged the body")
	seq.restore()
	seq.queue_free()
	# Legacy framing still walks the body to the player.
	var seq2 := CAUGHT_SEQUENCE.new()
	root.add_child(seq2)
	figure.global_position = Vector3(0, 0.05, 1.5)
	seq2.begin(player, figure)
	seq2._sample(0.4)
	_expect(figure.global_position.distance_to(
		Vector3(0, 0.05, 1.5)) > 0.005,
		"legacy catch framing changed")
	seq2.restore()
	seq2.queue_free()
	figure.queue_free()
	player.queue_free()
	await physics_frame


func _audit_ambient_exclusion() -> void:
	var passers := PassingShadows.new()
	passers.exclude_volume(AABB(Vector3(-6, -1, -6), Vector3(12, 4, 12)))
	_expect(passers._excluded(Vector3(0, 1.0, 0.0)),
		"passer entered the site envelope")
	_expect(not passers._excluded(Vector3(50, 1.0, 0.0)),
		"passer excluded outside the envelope")
	var corners := CornerApparitions.new()
	corners.exclude_volume(AABB(Vector3(194, -1, -6), Vector3(12, 4, 12)))
	_expect(corners._excluded(Vector3(200, 1.0, 0.0)),
		"corner apparition entered the site envelope")
	_expect(not corners._excluded(Vector3(0, 1.0, 0.0)),
		"corner apparition excluded outside the envelope")
	passers.free()
	corners.free()


func _solid_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body
