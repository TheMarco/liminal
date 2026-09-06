extends SceneTree
## Production-lighting review of the casino landmarks and real photograph flow.
## godot --path . --minimized --audio-driver Dummy --disable-render-loop \
## --script tools/capture_casino_landmarks.gd -- --mode=descent --nologo --seed=7
var view: SubViewport
var game: Node3D
const OUT := "res://build/gameplay-review"

func _init() -> void:
	call_deferred("run")

func draw(frames := 12) -> void:
	for i in frames:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)

func shot(name: String) -> void:
	game._osd_layer.visible = false
	game._descent_hud.visible = false
	await draw()
	view.get_texture().get_image().save_png(OUT.path_join(name + ".png"))

func run() -> void:
	Engine.max_fps = 120
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	game = load("res://scenes/main.tscn").instantiate()
	game.world_seed = 7
	view.add_child(game)
	await draw(90)
	game._set_presence(game.Presence.SILENT)
	game.run.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process(false)
	game._post_process.set_enabled(false)
	game._osd_layer.visible = false
	view.scaling_3d_scale = 1.0
	var cam: Camera3D = game.player.cam
	for at in game.descent_route.casino_landmarks:
		var kind: String = game.descent_route.casino_landmarks[at]
		var base := Vector3(at.x * 12.0, 0, at.y * 12.0)
		game.player.teleport(base + Vector3(6, 0.15, 6))
		game.cm.stream_focus = base + Vector3(6, 0, 6)
		game.cm.warm_up(at)
		await draw(30)
		var chunk: Chunk = game.cm.chunk_at(at)
		cam.fov = 74
		if kind == CasinoLandmarks.LAST_CHANCE:
			var cabinet: Node3D
			for node in chunk.get_children():
				if node.has_meta("powered") and node.get_meta("powered"):
					cabinet = node
			var target := cabinet.global_position + Vector3(0, 1.5, 0)
			cam.global_position = target + cabinet.global_basis.z * 4.3 + Vector3(-1.0, 0.3, 0)
			cam.look_at(target)
		elif kind == CasinoLandmarks.LOUNGE:
			cam.global_position = base + Vector3(2.1, 1.7, 9.7)
			cam.look_at(base + Vector3(6, 0.5, 6))
		else:
			var plate: Label3D = chunk.find_child("NumberPlate", true, false)
			assert(plate != null, "Numbered landmark door missing")
			cam.global_position = plate.global_position + plate.global_basis.z * 2.45 + Vector3(0.35, -0.15, 0)
			cam.look_at(plate.global_position + Vector3(0, -0.3, 0))
		await shot(kind)
		if kind == CasinoLandmarks.PHONE:
			var camera: PhotoCamera = game._photo_camera
			# Frame the actual door from the traversable corridor and exercise the
			# same shutter, snapshot layers, credit, review and reveal as play.
			camera.set_process(false)
			camera._raise(true)
			await draw(3)
			assert(camera._captured_anomalies().has(game._photo_director._live[at]), "Numbered door not capturable")
			await camera._take_photo()
			assert(camera._review_resolves.size() > 0, "Door did not defer its reveal")
			var plate: Label3D = chunk.find_child("NumberPlate", true, false)
			assert(plate.text == "104", "Door changed before the print was lowered")
			await shot("door-print-106")
			camera._review_left = 0.01
			camera._process(0.02)
			camera._lower()
			assert(plate.text == "106", "Door did not change after lowering print")
			await shot("door-real-106")
	game._open_settings(false)
	await shot("pause-settings")
	game._close_settings()
	print("GAMEPLAY_REVIEW PASS: three landmarks; real shutter 104 / print106 / real106; pause UI")
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()
