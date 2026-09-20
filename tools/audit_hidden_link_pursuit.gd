extends SceneTree
## Package 3.4 gate: live pursuit across a hidden link. A crossing player
## keeps sight of a look-back pursuer with no silhouette doubling; opposite
## sides meet with peer separation; seam catches fire only with a verified
## path; torches do not burn through occluders; Pool Girl runs and the
## hound stages at scale; bridged audio crossfades without restarting.

var failures: Array[String] = []
var fixture: TraversalLinkFixture
var graph: TraversalGraph
var caught := false


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
	await _audit_lookback_pursuit()
	_audit_opposite_meeting()
	await _audit_seam_catch()
	await _audit_blocked_catch()
	await _audit_wall_blocked_torch()
	_audit_pool_girl_and_hound()
	_audit_audio_bridge()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - hidden link pursuit holds")
		quit()
	else:
		quit(1)


func _figure_at(at: Vector3, model := 0) -> ShadowFigure:
	var figure := ShadowFigure.new()
	figure.player = _player_ref
	figure.walker_model_index = model
	figure.traversal_graph = graph
	figure.set("_seen", true)
	figure.grace = 0.0
	root.add_child(figure)
	figure.global_position = at
	figure.get("_walker").set_manifestation(1.0)
	return figure


var _player_ref: Player


func _audit_lookback_pursuit() -> void:
	_player_ref = Player.new()
	_player_ref.position = Vector3(0, 0.05, 0.5)
	root.add_child(_player_ref)
	var figure := _figure_at(Vector3(0, 0.05, 4.0))
	for tick in 90:
		if _player_ref.is_on_floor():
			break
		await physics_frame
	_expect(_player_ref.seam_transfer_eligible(),
		"settled player ineligible to cross")
	var eye := _player_ref.global_position + Vector3(0, 1.4, 0)
	var antesight: Dictionary = figure._seam_sight(eye,
		figure.global_position + Vector3(0, 1.4, 0))
	_expect(bool(antesight["visible"]), "pursuer unseen before crossing")
	# The player walks the seam while the pursuer closes behind.
	_player_ref.global_position = Vector3(0, 0.05, -0.5)
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var out: Array = trav.step(1.0 / 60.0, [{"body": _player_ref,
		"from": Vector3(0, 0.05, 0.5),
		"allow": _player_ref.seam_transfer_eligible()}])
	_expect(out.size() == 1, "look-back crossing did not transfer")
	await process_frame
	await process_frame
	# The proxy's existence proves render-clock wiring; sync explicitly so
	# the pose comparison cannot straddle a physics tick.
	figure._sync_seam_proxy()
	var postsight: Dictionary = figure._seam_sight(
		_player_ref.global_position + Vector3(0, 1.4, 0),
		figure.global_position + Vector3(0, 1.4, 0))
	_expect(bool(postsight["visible"]),
		"pursuer lost across the crossing")
	_expect(str(postsight["via_link"]) == "link:straight",
		"post-crossing sight bypassed the link")
	# Exactly one render-only twin, pose-locked, both halves clipped.
	var proxy: SeamActorProxy = figure.get("_seam_proxy")
	_expect(is_instance_valid(proxy), "pursuer grew no proxy")
	var played := (figure.get("_walker").get("_animation_player")
		as AnimationPlayer).current_animation_position
	_expect(played > 0.0, "pursuer never animated, pose check vacuous")
	if is_instance_valid(proxy):
		_expect(proxy.walker.model_index == 0, "proxy restyled")
		_expect(proxy.walker.proxy_mode, "proxy advances itself")
		_expect(_bone_pose(proxy.walker).is_equal_approx(
			_bone_pose(figure.get("_walker"))),
			"proxy pose drifted")
		_expect(_clip_on(figure.get("_walker")),
			"original unclipped while paired")
		_expect(_clip_on(proxy.walker), "proxy unclipped")
		_expect(_no_bodies(proxy), "proxy carries collision")
		var proxies := 0
		for node in root.get_children():
			if node is SeamActorProxy:
				proxies += 1
		_expect(proxies == 1, "silhouette doubled: %d" % proxies)
	figure.queue_free()
	_player_ref.queue_free()
	_player_ref = null
	await physics_frame


func _bone_pose(walker: ShadowWalkerVisual) -> Transform3D:
	var skeleton := walker.skeleton()
	var t := Transform3D.IDENTITY
	t.origin = skeleton.get_bone_pose_position(0)
	t.basis = Basis(skeleton.get_bone_pose_rotation(0)) \
		.scaled(skeleton.get_bone_pose_scale(0))
	return t


func _clip_on(walker: ShadowWalkerVisual) -> bool:
	for material in walker.get("_materials"):
		if (material as ShaderMaterial).get_shader_parameter(
				&"clip_enabled") != 1.0:
			return false
	for material in walker.get("_halo_materials"):
		if (material as ShaderMaterial).get_shader_parameter(
				&"clip_enabled") != 1.0:
			return false
	return true


func _no_bodies(node: Node) -> bool:
	if node is CollisionObject3D or node is AudioStreamPlayer \
			or node is AudioStreamPlayer3D:
		return false
	for child in node.get_children():
		if not _no_bodies(child):
			return false
	return true


func _audit_opposite_meeting() -> void:
	_player_ref = Player.new()
	_player_ref.position = Vector3(100, 0.05, 30.0)
	root.add_child(_player_ref)
	var a := _figure_at(Vector3(0, 0.05, 1.0))
	var b := _figure_at(Vector3(200, 0.05, 1.0))
	# Head-on through the seam: the mapped peer 2m ahead steers the lane.
	var steered: Vector3 = a._avoid_peers(Vector3(0, 0, -1), 3.0,
		1.0 / 60.0)
	_expect(steered.normalized().angle_to(Vector3(0, 0, -1)) > 0.1,
		"seam peer did not steer: %s" % steered)
	_expect(not a._peer_clear(Vector3(0, 0.05, -1.5)),
		"walked into the mapped peer")
	a.traversal_graph = null
	_expect(a._peer_clear(Vector3(0, 0.05, -1.5)),
		"legacy peer check changed")
	a.queue_free()
	b.queue_free()
	_player_ref.queue_free()
	_player_ref = null


func _audit_seam_catch() -> void:
	caught = false
	_player_ref = Player.new()
	_player_ref.position = Vector3(200, 0.05, 0.5)
	root.add_child(_player_ref)
	var figure := _figure_at(Vector3(0, 0.05, 2.0))
	figure.reached_player.connect(func() -> void: caught = true)
	var trav := SpatialTraversal.new()
	trav.add_site(fixture.site_straight)
	var transferred := false
	for tick in 180:
		var pre := figure.global_position
		await physics_frame
		if not is_instance_valid(figure):
			break
		var out: Array = trav.step(1.0 / 60.0, [
			{"body": figure, "from": pre, "allow": true},
			{"body": _player_ref, "from": _player_ref.global_position,
				"allow": false},
		])
		transferred = transferred or not out.is_empty()
		if caught:
			break
	_expect(caught, "pursuer never caught across the seam")
	_expect(not transferred, "catch needed a crossing first")
	_expect(is_instance_valid(figure)
		and figure.get("_catch_presentation") != Vector3.INF,
		"spanning catch framed the distant body")
	figure.queue_free()
	_player_ref.queue_free()
	_player_ref = null
	await physics_frame


func _audit_blocked_catch() -> void:
	caught = false
	_player_ref = Player.new()
	_player_ref.position = Vector3(200, 0.05, 0.5)
	root.add_child(_player_ref)
	var figure := _figure_at(Vector3(0, 0.05, 2.0))
	figure.reached_player.connect(func() -> void: caught = true)
	# A crate across the mapped ray: the pursuer closes but never catches.
	var crate := _solid_box(Vector3(200, 1.2, 0.25), Vector3(2.0, 2.0, 0.3))
	await physics_frame
	for tick in 120:
		await physics_frame
		if not is_instance_valid(figure) or caught:
			break
	_expect(not caught, "catch fired through the occluder")
	_expect(figure.global_position.z < 1.9,
		"blocker stalled the pursuit itself")
	crate.queue_free()
	figure.queue_free()
	_player_ref.queue_free()
	_player_ref = null
	await physics_frame


func _audit_wall_blocked_torch() -> void:
	_player_ref = Player.new()
	_player_ref.position = Vector3(200, 0.05, 3.0)
	root.add_child(_player_ref)
	await physics_frame
	_player_ref.flashlight.visible = true
	var figure := _figure_at(Vector3(0, 0.05, 2.0))
	await physics_frame
	var cam := _player_ref.cam
	cam.global_position = Vector3(200, 1.4, 3.0)
	cam.rotation = Vector3.ZERO
	figure.set("_burn", 0.0)
	var aim: float = figure._beam_aim(cam)
	var sighted := figure._clear_line(cam.global_position,
		figure.global_position + Vector3(0, figure._eye_h, 0))
	_expect(sighted, "linked figure unsighted for the torch")
	_expect(figure._in_beam(cam, aim, sighted), "torch missed the link")
	for tick in 30:
		await physics_frame
	_expect(float(figure.get("_burn")) > 0.0, "linked torch never heated")
	# The same geometry with an occluder: no sight, no beam, no heat.
	var crate := _solid_box(Vector3(200, 1.2, 0.25), Vector3(2.0, 2.0, 0.3))
	await physics_frame
	figure.set("_burn", 0.0)
	var sighted2 := figure._clear_line(cam.global_position,
		figure.global_position + Vector3(0, figure._eye_h, 0))
	_expect(not sighted2, "torch sight crossed the occluder")
	_expect(not figure._in_beam(cam, figure._beam_aim(cam), sighted2),
		"torch burned through the occluder")
	for tick in 30:
		await physics_frame
	_expect(float(figure.get("_burn")) <= 0.0, "occluded torch heated")
	crate.queue_free()
	figure.queue_free()
	_player_ref.queue_free()
	_player_ref = null
	await physics_frame


func _audit_pool_girl_and_hound() -> void:
	_player_ref = Player.new()
	root.add_child(_player_ref)
	await physics_frame
	var girl := _figure_at(Vector3(0, 0.05, 3.0), 10)
	girl.get("_walker").set_ground_speed(4.5, true)
	_expect((girl.get("_walker") as ShadowWalkerVisual).locomotion_clip()
		== &"run", "Pool Girl never broke into her run")
	girl.queue_free()
	var hound := _figure_at(Vector3(0, 0.05, 3.0), 9)
	var presentation: Node3D = hound.get("_walker").get("_presentation")
	_expect(absf(presentation.scale.x - 1.55 / 0.75) < 0.01,
		"hound staged at the wrong scale: %s" % presentation.scale)
	hound.queue_free()
	_player_ref.queue_free()
	_player_ref = null
	await physics_frame


func _audit_audio_bridge() -> void:
	var bridge := SeamAudioBridge.new()
	var owner := Node3D.new()
	owner.position = Vector3(0, 0, 1.0)
	root.add_child(owner)
	var voice := AudioStreamPlayer3D.new()
	voice.stream = _silent_loop()
	voice.volume_db = -14.0
	voice.position = Vector3(0, 0.4, 0)
	owner.add_child(voice)
	voice.play()
	bridge.track(voice, owner)
	var space := root.get_world_3d().direct_space_state
	bridge.update(Vector3(200, 1.4, 3.0), [fixture.link_straight], space,
		1.0 / 60.0)
	# Heard through the seam at its apparent seat, not 200m off.
	_expect(voice.global_position.distance_to(
		Vector3(200, 0.4, -1.0)) < 0.01,
		"voice misbridged: %s" % voice.global_position)
	_expect(voice.playing, "bridge restarted the voice")
	bridge.notify_crossed()
	bridge.update(Vector3(200, 1.4, 0.5), [fixture.link_straight], space,
		1.0 / 60.0)
	_expect(bridge.duck_level() > 0.0, "crossing never ducked")
	_expect(voice.playing, "crossfade restarted the voice")
	_expect(voice.volume_db < -14.0, "crossfade never dipped")
	for tick in 20:
		bridge.update(Vector3(200, 1.4, 0.5), [fixture.link_straight],
			space, 1.0 / 60.0)
	_expect(bridge.duck_level() <= 0.0, "duck never recovered")
	_expect(absf(voice.volume_db - -14.0) < 0.01, "voice never recovered")
	owner.queue_free()
	await physics_frame


func _silent_loop() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.data = PackedByteArray([128])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


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
