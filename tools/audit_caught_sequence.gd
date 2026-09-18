extends "res://tools/lib/audit_base.gd"
## Exercise the real fatal-contact path, not just a disconnected animation.
## godot --headless --path . --script tools/audit_caught_sequence.gd -- --mode=descent --nologo

const SEQUENCE := preload("res://scripts/caught_sequence.gd")

func _figure(game: Node) -> ShadowFigure:
	var figure := ShadowFigure.new()
	figure.player = game.player
	figure.variant = ShadowFigure.GAOLER
	var forward: Vector3 = -game.player.cam.global_basis.z
	forward.y = 0.0
	figure.position = game.player.global_position + forward.normalized()
	game.add_child(figure)
	figure.set_physics_process(false)
	game._figures.adopt(figure)
	return figure


func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture-caught"):
		return
	if label == "results":
		await create_timer(1.1).timeout
	for i in 3:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	root.get_texture().get_image().save_png("/tmp/liminal-caught-%s.png" % label)


func _settle_preview(game: Node) -> void:
	# This test finishes floors in fractions of a second. Let the unrelated
	# first-door asset coroutine finish before replacing/freeing its owner.
	if not is_instance_valid(game._realm_visit):
		return
	var visit: RealmExcursion = game._realm_visit
	expect(await await_until(func(): return visit._preview_resources_ready \
		and (not visit._building or visit.phase != RealmExcursion.Phase.PREPARING), 30000),
		"unrelated realm preview did not settle before catch test")
	# Graphical audits may run unfocused. Resume before setting up the fatal
	# path, or a focus-loss menu obscures every capture while assertions pass.
	if is_instance_valid(game._pause_menu):
		game._close_settings()


func run() -> void:
	var game := await boot_game(918273)
	expect(game.descent and not game._progress_enabled, "audit must use isolated Descent CLI mode")
	game._set_presence(game.Presence.SILENT)
	game.run.suspended = true
	await _settle_preview(game)
	game.player.emergency_flash_held = true
	var saved := _figure(game)
	saved._seize()
	expect(not game.run.ended and not is_instance_valid(game._caught_sequence),
		"emergency flash incorrectly started fatal presentation")
	expect(not game.player.emergency_flash_held
		and saved._quad.get_instance_shader_parameter("ignite") == 1.0,
		"emergency flash did not consume its charge and burn the exact figure")
	game._figures.despawn()
	await process_frame
	var catcher := _figure(game)
	var other := _figure(game)
	other.global_position += game.player.cam.global_basis.x * 3.0
	game.player.head_bob_strength = 1.0
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player_start: Vector3 = game.player.global_position
	var camera_start: Transform3D = game.player.cam.global_transform
	# Simulate a shutter still waiting for its renderer. The fatal event must
	# lock held-input physics immediately, not after this wait is over.
	game._photo_camera._capturing = true
	catcher._seize()
	expect(game.run.ended and game.run.death_cause == DescentRun.DeathCause.FIGURE,
		"fatal catch did not end rules immediately")
	expect(game._figures.catching_figure == catcher, "manager lost exact catching actor")
	expect(is_instance_valid(game._caught_sequence) and not is_instance_valid(game._descent_summary),
		"summary bypassed the caught beat")
	expect(not game.player.is_processing() and not game.player.is_physics_processing()
		and not game.player.is_processing_unhandled_input(), "player not frozen during shutter wait")
	expect(not other.is_physics_processing(), "another hostile kept moving during death")
	expect(not game._osd_layer.visible, "caught beat still shows interaction/battery/event HUD")
	await create_timer(0.07).timeout
	expect(game.player.global_position.is_equal_approx(player_start), "held input moved the dead player")
	expect(game.player.cam.global_transform.is_equal_approx(camera_start), "shutter wait moved camera")
	game._photo_camera._capturing = false
	await process_frame
	await process_frame
	var sequence: CanvasLayer = game._caught_sequence
	sequence.set_process(false)
	sequence._sample(0.20)
	expect(not game.player.cam.global_transform.is_equal_approx(camera_start), "normal comfort setting has no caught motion")
	expect(catcher.global_position.distance_to(player_start) < 1.0,
		"actual catcher did not close the final stretch")
	expect(is_zero_approx(sequence._curtain.color.a), "cut went black before the grab could register")
	await _capture("grab")
	sequence._sample(SEQUENCE.LAND_AT)
	expect(game.player.cam.global_position.y < camera_start.origin.y - 0.75,
		"visible catch never fell to floor level")
	expect(game.player.global_position.is_equal_approx(player_start), "fall moved the collision body")
	await _capture("floor")
	sequence._sample(SEQUENCE.LOOM_AT)
	expect(not is_instance_valid(game._pause_menu), "focus-loss menu obscured the caught review")
	var toward_head: Vector3 = (catcher.global_transform * Vector3(0, catcher._eye_h, 0) \
		- game.player.cam.global_position).normalized()
	expect((-game.player.cam.global_basis.z).dot(toward_head) > 0.95,
		"fallen camera does not frame the real catcher overhead")
	expect(is_zero_approx(sequence._curtain.color.a), "fade hides the overhead reveal")
	expect(not catcher.global_basis.is_equal_approx(Basis.IDENTITY), "catcher never leans over the player")
	await _capture("loom")
	sequence._sample((SEQUENCE.FADE_START + SEQUENCE.BLACK_AT) * 0.5)
	expect(sequence._curtain.color.a > 0.0 and sequence._curtain.color.a < 1.0,
		"overhead reveal did not fade smoothly")
	await _capture("fade")
	sequence._sample(SEQUENCE.BLACK_AT)
	expect(is_equal_approx(sequence._curtain.color.a, 1.0), "caught beat never reached black")
	await _capture("black")
	sequence._process(SEQUENCE.DURATION)
	expect(is_instance_valid(game._descent_summary) and game._caught_sequence == null,
		"caught completion did not show exactly one results screen and release controller")
	expect(game.player.is_processing() and game.player.is_physics_processing(), "caught completion left player processing locked")
	expect(game.player.cam.global_transform.is_equal_approx(camera_start), "caught completion failed to restore camera")
	expect(game._descent_summary.from_black, "results flashed the room back after the cut to black")
	expect(not game.player.is_processing_unhandled_input(), "results screen accidentally enabled gameplay input")
	expect(game._figures.active_figures().is_empty(), "caught actors survived onto results screen")
	await _capture("results")
	# Continue through the production path to catch frozen-player regressions.
	await game._resume_descent_at(0)
	expect(not game.run.ended and game.player.is_processing() and game.player.is_physics_processing()
		and game.player.is_processing_unhandled_input(), "continue did not restore playable state")
	game._set_presence(game.Presence.SILENT)
	game.run.suspended = true
	await _settle_preview(game)
	game.player.head_bob_strength = 0.0
	game._post_process.set_enabled(false)
	var no_motion_pose: Transform3D = game.player.cam.global_transform
	var no_motion_fov: float = game.player.cam.fov
	game._on_blackout_ambush()
	expect(game.run.death_cause == DescentRun.DeathCause.BLACKOUT_MOVEMENT,
		"blackout catch lost its death cause")
	sequence = game._caught_sequence
	expect(is_instance_valid(sequence), "blackout catch skipped its short ending")
	if is_instance_valid(sequence):
		sequence.set_process(false)
		expect(is_equal_approx(sequence._duration, SEQUENCE.UNSEEN_DURATION),
			"unseen blackout attack gained an empty overhead hold")
		for at in [0.05, 0.20, 0.45, 0.70]:
			sequence._sample(at)
			expect(game.player.cam.global_transform.is_equal_approx(no_motion_pose)
				and is_equal_approx(game.player.cam.fov, no_motion_fov), "zero motion changed camera pose/FOV")
			expect(not game._post_process.is_enabled(), "caught beat turned VHS back on")
		sequence._process(SEQUENCE.DURATION)
	expect(is_instance_valid(game._descent_summary), "blackout catch never finished")
	await teardown_game(game)
	# Cancellation restores original disabled flags as well as enabled ones.
	var host := Node3D.new()
	root.add_child(host)
	var subject := Player.new()
	host.add_child(subject)
	subject.set_process(false)
	subject.set_physics_process(false)
	var pose := subject.cam.global_transform
	var interrupted := SEQUENCE.new()
	host.add_child(interrupted)
	interrupted.begin(subject)
	interrupted._sample(0.25)
	interrupted.free()
	expect(subject.cam.global_transform.is_equal_approx(pose)
		and not subject.is_processing() and not subject.is_physics_processing(), "interrupted sequence did not restore original state")
	host.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	# Let this long async frame release its camera Transform3D/Variant locals
	# before Godot tears down the Variant pool.
	call_deferred("finish", "fatal floor fall/loom/fade, shutter/input freeze, emergency save, blackout, comfort, cleanup and retry")
