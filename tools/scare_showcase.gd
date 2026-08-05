extends Node3D
## Looping visual QA for the rare Descent presentation beats.
##
## Run:
##   godot --path . tools/scare_showcase.tscn
##
## This deliberately bypasses spawn rarity and topology selection. It uses the
## exact production render/audio paths on small authored sets so VHS damage,
## hallway crossings, and corner-apparition timing can be judged repeatedly.

const TV_SECONDS := 7.0
const HALL_ORIGIN := Vector3(40.0, 0.0, 0.0)
const CORNER_ORIGIN := Vector3(80.0, 0.0, 0.0)

var _player: Player
var _passer: PassingShadows
var _corner: CornerApparitions
var _tv_stage: Node3D
var _hall_stage: Node3D
var _corner_stage: Node3D
var _title: Label
var _detail: Label
var _loop_index := 0
var _capture_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture_dir = arg.substr(14)
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	_build_environment()
	_build_stages()
	_build_overlay()

	_player = Player.new()
	add_child(_player)
	await get_tree().process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.cam.fov = 67.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_passer = PassingShadows.new()
	_passer.player = _player
	add_child(_passer)
	_passer.set_physics_process(false)
	_corner = CornerApparitions.new()
	_corner.player = _player
	add_child(_corner)
	# The showcase drives both effects explicitly. Their production schedulers
	# are Descent-gated and would (correctly) clear a forced corner sighting in
	# this standalone scene on the next physics tick.
	_corner.set_physics_process(false)
	call_deferred("_showcase_loop")


func _showcase_loop() -> void:
	while is_inside_tree():
		_loop_index += 1
		await _show_vhs()
		await _show_hall_crossing()
		await _show_corner_apparition()
		if not _capture_dir.is_empty():
			print("scare showcase captures saved to %s" % _capture_dir)
			get_tree().quit()
			return
		_set_caption("SEQUENCE COMPLETE",
			"Repeating automatically in 3 seconds  •  Close the window to exit")
		await get_tree().create_timer(3.0).timeout


func _show_vhs() -> void:
	_set_stage(_tv_stage)
	_set_caption("1 / 3   VHS DISTORTION",
		"Production video decode through the CRT shader: tracking, tearing, " \
		+ "chroma bleed, grain and scanlines")
	_place_camera(Vector3(-0.42, 1.02, 2.35),
		Vector3(-0.42, 0.68, 0.25))
	await get_tree().create_timer(0.7).timeout

	var ritual := VhsRitual.new()
	ritual.name = "ShowcaseVhs"
	ritual.objective = false
	ritual.world_seed = 918273 + _loop_index
	ritual.setup_key = "showcase:%d" % _loop_index
	var shorts := VhsTapeLibrary.paths(false)
	if not shorts.is_empty():
		ritual._tape_path = shorts[(_loop_index - 1) % shorts.size()]
	_tv_stage.add_child(ritual)
	await get_tree().process_frame
	ritual._on_activated(_player)
	await get_tree().create_timer(2.2).timeout
	if not _capture_dir.is_empty():
		await _capture("01-vhs")
	await get_tree().create_timer(TV_SECONDS - 2.2).timeout
	if ritual._playing:
		ritual.reset_tape()
	# VhsRitual returns to the previous camera over 0.7 seconds.
	await get_tree().create_timer(0.9).timeout
	_player.cam.make_current()
	_player.set_physics_process(false)
	if is_instance_valid(ritual):
		ritual.queue_free()
	await get_tree().process_frame


func _show_hall_crossing() -> void:
	_set_stage(_hall_stage)
	_set_caption("2 / 3   DISTANT HALLWAY CROSSING",
		"The separate moving shadow: centered 18 metres down a narrow hall, " \
		+ "crossing once and disappearing")
	_place_camera(HALL_ORIGIN + Vector3(0.0, Player.CAM_H, 10.0),
		HALL_ORIGIN + Vector3(0.0, 1.35, -10.0))
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(_passer._live):
		_passer._live.queue_free()
		_passer._live = null
	_passer._cross(HALL_ORIGIN + Vector3(0.0, 0.0, -8.0))
	await get_tree().create_timer(0.8).timeout
	if not _capture_dir.is_empty():
		await _capture("02-hall-crossing")
	await get_tree().create_timer(2.6).timeout


func _show_corner_apparition() -> void:
	_set_stage(_corner_stage)
	_set_caption("3 / 3   CORNER APPARITION",
		"The camera rounds a physical corner; a closer stationary silhouette " \
		+ "holds for 2 seconds, then bursts into tiny black smoke particles")
	var cam_start := CORNER_ORIGIN + Vector3(0.0, Player.CAM_H, 5.0)
	var cam_end := CORNER_ORIGIN + Vector3(1.5, Player.CAM_H, 0.0)
	_place_camera(cam_start, CORNER_ORIGIN + Vector3(0.0, 1.2, 0.0))
	await get_tree().create_timer(0.9).timeout
	_corner._clear_live()
	var turn := create_tween().set_parallel(true)
	turn.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_player.cam, "global_position", cam_end, 1.8)
	turn.tween_property(_player.cam, "rotation",
		Vector3(0.0, -PI * 0.5, 0.0), 1.8)
	# Spawn at the first readable beat, while the camera is finishing the turn.
	await get_tree().create_timer(1.15).timeout
	_corner._show(CORNER_ORIGIN + Vector3(7.0, 0.0, 0.0))
	await turn.finished
	await get_tree().create_timer(0.25).timeout
	if not _capture_dir.is_empty():
		await _capture("03-corner-apparition")
	# The static capture lands about 0.65s after reveal. Take a second frame
	# halfway through the actual puff so it can be judged without video.
	await get_tree().create_timer(
		CornerApparitions.HOLD_SECONDS - 0.65
		+ CornerApparitions.FADE_SECONDS * 0.45).timeout
	if not _capture_dir.is_empty():
		await _capture("04-corner-dissolve")
	await get_tree().create_timer(
		CornerApparitions.FADE_SECONDS * 0.55 + 0.35).timeout


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _capture_dir.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved showcase frame: %s" % path)


func _place_camera(at: Vector3, toward: Vector3) -> void:
	_player.global_position = Vector3(at.x, 0.0, at.z)
	_player.cam.global_position = at
	_player.cam.look_at(toward, Vector3.UP)
	_player.cam.make_current()


func _set_stage(active: Node3D) -> void:
	_tv_stage.visible = active == _tv_stage
	_hall_stage.visible = active == _hall_stage
	_corner_stage.visible = active == _corner_stage


func _set_caption(title: String, detail: String) -> void:
	_title.text = title
	_detail.text = detail


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.007, 0.009)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	world.environment = env
	add_child(world)


func _build_stages() -> void:
	_tv_stage = Node3D.new()
	_tv_stage.name = "VhsStage"
	add_child(_tv_stage)
	_box(_tv_stage, Vector3(8.0, 0.10, 7.0), Vector3(0, -0.06, 0.8),
		Color(0.085, 0.075, 0.065))
	_box(_tv_stage, Vector3(8.0, 3.5, 0.15), Vector3(0, 1.75, -0.55),
		Color(0.16, 0.145, 0.12))
	_light(_tv_stage, Vector3(-1.5, 2.5, 1.7), Color(1.0, 0.72, 0.44),
		5.0, 8.0)

	_hall_stage = Node3D.new()
	_hall_stage.name = "HallStage"
	add_child(_hall_stage)
	_box(_hall_stage, Vector3(3.3, 0.10, 40.0),
		HALL_ORIGIN + Vector3(0, -0.06, -7), Color(0.13, 0.115, 0.075))
	_box(_hall_stage, Vector3(0.18, 3.0, 40.0),
		HALL_ORIGIN + Vector3(-1.65, 1.5, -7), Color(0.44, 0.39, 0.20))
	_box(_hall_stage, Vector3(0.18, 3.0, 40.0),
		HALL_ORIGIN + Vector3(1.65, 1.5, -7), Color(0.44, 0.39, 0.20))
	_box(_hall_stage, Vector3(3.3, 0.12, 40.0),
		HALL_ORIGIN + Vector3(0, 3.02, -7), Color(0.30, 0.28, 0.19))
	_box(_hall_stage, Vector3(3.3, 3.0, 0.18),
		HALL_ORIGIN + Vector3(0, 1.5, -27), Color(0.50, 0.47, 0.34))
	_light(_hall_stage, HALL_ORIGIN + Vector3(0, 2.55, -6),
		Color(0.88, 0.92, 0.72), 3.2, 17.0)
	_light(_hall_stage, HALL_ORIGIN + Vector3(0, 2.45, -20),
		Color(0.72, 0.78, 0.62), 4.0, 13.0)

	_corner_stage = Node3D.new()
	_corner_stage.name = "CornerStage"
	add_child(_corner_stage)
	_box(_corner_stage, Vector3(24.0, 0.10, 10.0),
		CORNER_ORIGIN + Vector3(8, -0.06, 1), Color(0.10, 0.105, 0.095))
	# The inside block hides the target from the starting leg. The camera moves
	# around its near-left corner and finishes looking down the right-hand leg.
	_box(_corner_stage, Vector3(10.0, 3.1, 2.0),
		CORNER_ORIGIN + Vector3(7, 1.55, 3), Color(0.42, 0.45, 0.38))
	_box(_corner_stage, Vector3(18.0, 3.1, 0.18),
		CORNER_ORIGIN + Vector3(10, 1.55, -2), Color(0.38, 0.42, 0.36))
	_box(_corner_stage, Vector3(0.18, 3.1, 8.0),
		CORNER_ORIGIN + Vector3(-2, 1.55, 3), Color(0.38, 0.42, 0.36))
	_box(_corner_stage, Vector3(0.18, 3.1, 4.0),
		CORNER_ORIGIN + Vector3(19, 1.55, 0), Color(0.55, 0.57, 0.48))
	_light(_corner_stage, CORNER_ORIGIN + Vector3(5, 2.5, 0),
		Color(0.70, 0.77, 0.63), 3.5, 12.0)
	_light(_corner_stage, CORNER_ORIGIN + Vector3(15, 2.4, 0),
		Color(0.84, 0.83, 0.66), 4.5, 10.0)


func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.88
	node.material_override = mat
	parent.add_child(node)


func _light(parent: Node3D, at: Vector3, colour: Color,
		energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = true
	parent.add_child(light)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 92.0
	panel.color = Color(0.005, 0.006, 0.008, 0.84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_title = Label.new()
	_title.position = Vector2(32, 17)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.92, 0.91, 0.84))
	panel.add_child(_title)
	_detail = Label.new()
	_detail.position = Vector2(32, 50)
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.add_theme_color_override("font_color", Color(0.66, 0.67, 0.63))
	panel.add_child(_detail)
	var footer := Label.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38.0
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.text = "RARE-EVENT SHOWCASE  •  test frequency only  •  normal Descent pacing is unchanged"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.66, 0.67, 0.63))
	layer.add_child(footer)
