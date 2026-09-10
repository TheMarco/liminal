extends SceneTree
## Earn the actual realm photo, return with it, and exercise real catch paths.
const OUT := "/tmp/liminal-emergency-flash"
var game: Node3D
var view: SubViewport
var saves := 0
var catches := 0
var burns := 0

func _init() -> void:
	call_deferred("run_test")

func shot(label: String) -> void:
	for i in 5:
		await process_frame
	view.get_texture().get_image().save_png(OUT.path_join(label + ".png"))

func figure(at: Vector3, manager: ShadowFigures) -> ShadowFigure:
	var f := ShadowFigure.new()
	f.player = game.player
	game.add_child(f)
	f.global_position = at
	f.set_physics_process(false)
	manager.adopt(f)
	return f

func run_test() -> void:
	Engine.max_fps = 60
	var bolt := FlashBoltMesh.build(2.05, 1.15, 0.32)
	assert(bolt.get_aabb().size.is_equal_approx(Vector3(1.15, 2.05, 0.32)))
	var mesh_arrays := bolt.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 60, "bolt extrusion is missing faces")
	for index in range(0, vertices.size(), 3):
		assert((vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).dot(normals[index]) < -0.0001, "bolt has reversed or degenerate faces")
	create_timer(75.0, true).timeout.connect(func():
		push_error("EMERGENCY FLASH AUDIT TIMEOUT")
		quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING:
		await process_frame
	assert(visit.phase == RealmExcursion.Phase.WAITING)
	assert(is_instance_valid(visit.bounty), "no reachable prize in generated realm")
	assert(visit.bounty.walk_distance > 0.0 and visit.bounty.walk_distance <= 36.0)
	assert(visit.bounty.visible_from_entry, "seed 21 reward is hidden from the entrance")
	assert(not visit.bounty.source_asset.is_empty(), "bounty did not use an existing furnished location")
	game.run.resume_rules(0.0)
	game._set_presence(game.Presence.SILENT)
	game.player.emergency_flash_used.connect(func(): saves += 1)
	for anomaly in game._photo_director._live_doors.values():
		if anomaly.id == visit.seal.photo_id:
			game._photo_director.mark_documented(anomaly.id)
			anomaly.resolve()
			break
	var evidence: Array = game._photo_director.documented_ids().duplicate()
	var hud: DescentHUD = game._descent_hud
	assert(hud.flash_bounty == null, "flash locator leaked into the source floor")
	hud.grant_true_distance()
	var true_distance_left := hud._true_left
	await visit.enter()
	visit.set_process(false)
	visit.threats.suspended = true
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var entry_camera: Camera3D = game.player.cam
	entry_camera.global_position = visit.destination_position + Vector3.UP * Player.CAM_H
	entry_camera.rotation = Vector3(0.0, visit.destination_yaw, 0.0)
	assert(entry_camera.is_position_in_frustum(visit.bounty.bounds.get_center()), "prize is outside initial view")
	for child in visit.bounty.get_children():
		if child is MeshInstance3D or child is Label3D:
			assert(child.layers & 1, "reward cue needs the camera to be seen")
	assert(not visit.bounty.bounds.has_point(visit.bounty._lamp.position), "reward light buried inside prop")
	await shot("00-reward-from-entrance")
	assert(hud._panel.visible and hud._label.text == "FLASH", "realm flash locator is missing")
	assert(not hud._evidence_row.visible, "realm shows source-floor objectives")
	var entry_range := int(hud._distance.text.trim_suffix("m"))
	var delta: Vector3 = visit.bounty.to_global(visit.bounty.bounds.get_center()) - game.player.global_position
	assert(entry_range == maxi(1, roundi(Vector2(delta.x, delta.z).length())), "flash locator uses wrong position or units")
	assert(is_equal_approx(hud._true_left, true_distance_left), "visit spent source recording's room-count time")
	game._show_return_prompt()
	await process_frame
	assert(not hud._panel.visible, "flash locator stayed visible over quit confirmation")
	game._cancel_return_to_title()
	await process_frame
	assert(hud._panel.visible and game.run.suspended, "cancel quit failed to restore locator independently of source rules")
	var held_transform := visit.bounty._icon.transform
	visit.bounty.set_hold(true)
	await create_timer(0.10).timeout
	assert(visit.bounty._icon.transform.is_equal_approx(held_transform), "bolt moved while the visit was held")
	visit.bounty.set_hold(false)
	game.player.teleport(visit.bounty.approach)
	var camera: Camera3D = game.player.cam
	camera.global_position = visit.bounty.approach + Vector3.UP * Player.CAM_H
	camera.look_at(visit.bounty.bounds.get_center())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(not game.player.emergency_flash_held and not game._flash_icon.held)
	await shot("01-empty-icon-and-bounty")
	assert(int(hud._distance.text.trim_suffix("m")) < entry_range, "flash range did not fall when approaching")
	var photo: PhotoCamera = game._photo_camera
	photo._raise()
	assert(not hud._panel.visible, "flash locator covers the viewfinder")
	photo._lower()
	await process_frame
	assert(hud._panel.visible, "lowering camera lost the flash locator")
	photo._raise()
	assert(photo._captured_anomalies().has(visit.bounty), "prize cannot be framed from its checked approach")
	# A wall placed between this proven approach and the prize must block it.
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 3.0, 0.22)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = camera.global_position.lerp(visit.bounty.framing_points(camera)[0], 0.45)
	await physics_frame
	await physics_frame
	assert(not photo._captured_anomalies().has(visit.bounty), "bounty captured through a wall")
	wall.free()
	await physics_frame
	await shot("02-viewfinder-bounty")
	await photo._take_photo()
	assert(visit.bounty_captured and not game.player.emergency_flash_held, "prize banked before safe return")
	assert(game._photo_director.documented_ids() == evidence, "bounty changed source evidence")
	assert(game._photo_album_store.entries.back().anomaly_ids.has(visit.bounty_id))
	assert("emergency flash" in game._photo_album_store.entries.back().caption)
	photo.finish_for_transition()
	await process_frame
	assert(not hud._panel.visible, "photographed flash still has a locator")
	photo._raise()
	assert(not photo._captured_anomalies().has(visit.bounty), "same bounty paid twice")
	assert(photo._captured_anomalies(true).has(visit.bounty), "documented bounty disappeared from viewfinder")
	photo.finish_for_transition()
	# The very same interception must work inside the excursion, before it can
	# trigger a caught return. A previously owned charge may be spent here.
	game.player.grant_emergency_flash()
	var realm_attacker := figure(game.player.global_position + Vector3.FORWARD, visit.threats)
	realm_attacker._seize()
	assert(saves == 1 and visit.phase == RealmExcursion.Phase.VISITING)
	assert(realm_attacker._fade == ShadowFigure.BURN_FADE and not game.player.emergency_flash_held)
	# The live award/use signals must update the checkpoint, not just the HUD.
	var save_path := "/tmp/emergency_flash_runtime_%d.cfg" % Time.get_ticks_usec()
	game._descent_progress = DescentProgress.new(save_path)
	game._descent_progress.start_new(game.world_seed)
	game._progress_enabled = true
	visit.elapsed = RealmExcursion.DURATION
	await visit.collapse()
	assert(visit.phase == RealmExcursion.Phase.SPENT)
	assert(game.player.emergency_flash_held and game._flash_icon.held)
	assert(DescentProgress.new(save_path).emergency_flash_held, "award was not saved")
	game.player.emergency_flash_held = false
	game._restore_emergency_flash()
	assert(game.player.emergency_flash_held, "Continue failed to restore flash")
	assert(not game.award_emergency_flash("duplicate"), "more than one flash stored")
	assert(game._photo_director.documented_ids() == evidence)
	assert(game._photo_album_store.entries.back().flash_status == "FLASH READY")
	game.player.set_physics_process(false)
	game.player.set_process(false)
	await shot("03-filled-icon")
	assert(hud.flash_bounty == null and hud._panel.visible and hud._evidence_row.visible, "source objectives did not return")
	assert(hud._label.text in ["LIFT", "ROOMS TO LIFT"], "realm flash locator leaked after return")
	var forward: Vector3 = -game.player.cam.global_basis.z
	var attacker := figure(game.player.global_position + forward * 1.0, game._figures)
	var nearby := figure(game.player.global_position + forward * 3.0 + Vector3.RIGHT, game._figures)
	game._figures.burned_away.connect(func(): burns += 1)
	# Observe forwarding without invoking the asynchronous result-screen flow.
	game._figures.reached_player.disconnect(game._on_figure_reached_player)
	game._figures.reached_player.connect(func(): catches += 1)
	var battery: float = game.player.flashlight_charge()
	photo._raise() # A save must still be visible while using the camera.
	attacker._seize()
	assert(saves == 2 and catches == 0 and not game.run.ended and not game._dying)
	assert(not game.player.emergency_flash_held and not game._flash_icon.held)
	assert(attacker._fade == ShadowFigure.BURN_FADE and nearby._fade < 0.0, "flash affected another attacker")
	assert(burns == 0 and is_equal_approx(game.player.flashlight_charge(), battery), "save refunded normal flashlight")
	assert(not photo._raised and game._osd_layer.visible)
	assert(game._event_hint.text == "SAVED BY THE FLASH")
	assert("FLASH SPENT" in game._photo_album_store.entries.back().flash_status)
	attacker._seize()
	assert(saves == 2 and catches == 0, "dying attacker caught twice")
	await shot("04-saved-by-flash")
	assert(game._event_hint.text == "SAVED BY THE FLASH", "save message was immediately overwritten")
	assert(not DescentProgress.new(save_path).emergency_flash_held, "spent flash would resurrect on Continue")
	nearby._seize()
	assert(catches == 1 and saves == 2, "second catch received unrequested immunity")
	assert(not game.player.emergency_flash_held)
	print("EMERGENCY FLASH PASS: visible 3D glyph bolt, correct mesh winding, held motion, reachable photograph, occlusion, no duplicate reward, safe-return banking, realm save, exact attacker kill, bystander untouched, next catch fatal, HUD, message, album, no torch refund")
	game._descent_progress.clear_from_disk()
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
