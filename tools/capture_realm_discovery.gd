extends SceneTree
## Render the clue from the ordinary incoming doorway, then prove the lens
## still supplies the reveal. Run with -- --mode=descent --nologo --seed=21 --descent-floor=2.
const OUT := "/tmp/liminal-realm-discovery"
var game: Node3D
var view: SubViewport

func _init() -> void:
	call_deferred("run_test")

func shot(label: String) -> void:
	for i in 6:
		await process_frame
	view.get_texture().get_image().save_png(OUT.path_join(label + ".png"))

func run_test() -> void:
	Engine.max_fps = 60
	create_timer(75.0, true).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	view.add_child(game)
	game._set_presence(game.Presence.SILENT)
	game.run.set_physics_process(false)
	game.run.resume_rules(0.0)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	var record: Dictionary = game.descent_route.realm_door_hint
	assert(float(record.discovery_facing) >= 0.85, "mall doorway is outside the central approach view")
	var eye: Vector3 = record.discovery_origin
	var forward: Vector3 = record.discovery_forward
	game.player.teleport(eye - Vector3.UP * Player.CAM_H)
	game.player.rotation.y = atan2(-forward.x, -forward.z)
	game.player.cam.global_position = eye
	game.player.cam.rotation = Vector3(0.0, game.player.rotation.y, 0.0)
	game.cm.stream_focus = game.player.global_position
	var visit: RealmExcursion = game._realm_visit
	while visit.phase == RealmExcursion.Phase.PREPARING or not is_instance_valid(visit.window):
		await process_frame
	game.run.resume_rules(0.0)
	game.run.arrival_grace = 0.0
	visit.set_process(false)
	visit._door_leak.finish()
	visit._door_leak.cooldown = 0.0
	visit._door_leak.pulses = 0
	visit._discovery_started = false
	game._hint.visible = false
	game._event_panel.visible = false
	await shot("01-ordinary-approach")
	visit._process(0.01)
	assert(visit.preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden realm is still rendering behind the seal")
	print("DISCOVERY VIEW: eye=%s patch=%s facing=%s in_room=%s in_view=%s" % [game.player.cam.global_position,
		visit._door_leak.global_position, -game.player.cam.global_basis.z, visit._entrance_in_room(), visit._leak_in_view()])
	assert(visit._door_leak.active, "glyph patch is not visible from the real incoming doorway")
	assert(game._figures._new_spawn_hold > 0.0)
	var held_time := visit._door_leak.elapsed
	visit._door_leak.update_cue(1.0, true, true)
	assert(visit._door_leak.elapsed == held_time, "held leak did not freeze")
	visit._process(0.65)
	await shot("02-glyph-leak")
	assert(not visit.seal.opened, "clue opened the door without a photo")
	visit._process(1.3)
	assert(not visit._door_leak.active and visit._door_leak.visible, "nothing remains between pulses")
	await shot("03-glyph-residue")
	game._photo_camera._raise(true)
	visit._process(0.01)
	assert(not visit._door_leak.visible)
	assert(visit.preview.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "lens view has no live preview")
	assert(visit.preview.size.y == roundi(view.size.y * view.scaling_3d_scale), "preview ignores the game's render scale")
	await shot("04-camera-reveals-office")
	game._photo_camera._lower()
	visit._door_leak.cooldown = 0.0
	visit._process(0.6)
	assert(visit._door_leak.pulses == 2, "unphotographed clue never repeated")
	# The real approach used to be silent until the exact room boundary was
	# crossed, the arrival timer expired AND the player faced the wall.
	# Start in the preceding room, looking back, with arrival grace intact.
	game.player.teleport(eye - forward * 2.4 - Vector3.UP * Player.CAM_H)
	game.player.cam.global_position = eye - forward * 2.4
	game.player.cam.rotation.y += PI
	game.run.arrival_grace = 4.0
	visit._door_leak.finish()
	visit._door_leak.cooldown = 0.0
	visit._discovery_started = false
	game._figures._new_spawn_hold = 0.0
	assert(not visit._entrance_in_room(), "adjacent approach fixture is still inside entrance room")
	assert(visit._leak_line_of_sight(), "actual incoming doorway does not have a clear sightline")
	assert(not visit._leak_in_view(), "look-away fixture faces the wall")
	visit._process(0.6)
	assert(visit._door_leak.visible and not visit._entrance_hum.stream_paused, "approach stays silent while looking away or in arrival grace")
	assert(not visit._discovery_started and game._figures._new_spawn_hold == 0.0, "offscreen signal consumed first-view grace")
	visit._process(2.0)
	assert(not visit._door_leak.active and visit._door_leak.visible)
	# Turn during the former six-second blank period: residue must be visible
	# and the first-view hold must begin now, not back while facing away.
	game.player.cam.rotation.y -= PI
	visit._process(0.01)
	assert(visit._leak_in_view() and visit._discovery_started and game._figures._new_spawn_hold > 0.0)
	await shot("05-adjacent-room-residue")
	# Move laterally behind the ordinary wall beside the incoming opening.
	var blocked_eye := eye - forward * 2.4 + Vector3.RIGHT * 4.0
	game.player.teleport(blocked_eye - Vector3.UP * Player.CAM_H)
	game.player.cam.global_position = blocked_eye
	visit._process(0.05)
	assert(not visit._entrance_in_room() and not visit._leak_line_of_sight(), "blocked approach fixture has no wall")
	assert(not visit._door_leak.visible and visit._entrance_hum.stream_paused, "cue leaks through unrelated solid wall")
	print("REALM DISCOVERY CAPTURE PASS: facing %.2f; eye %s; forward %s; %s" % [record.discovery_facing, eye, forward, OUT])
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
