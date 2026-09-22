extends SceneTree
## Cross-level native corridor proof. Never loads or changes a campaign save.
const Surface := preload("res://tools/lib/hallway_wave_preview_surface.gd")
const Profile := preload("res://scripts/hallway_wave_profile.gd")
const Layout := preload("res://tools/lib/hallway_wave_preview_layout.gd")
var room: Chunk
var effect: Node3D
var elapsed := 0.0
var running := false
var capture := false
var label: Label
var check_physics := false
var check_walk := false
var no_gi := false
var output := "/tmp/liminal-hallway-wave"
var theme := 1
var requested_axis := 0
var world: Node3D
var layer: CanvasLayer
var busy := true
const PREVIEW_THEMES := [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	check_physics = "--check-physics" in OS.get_cmdline_user_args()
	check_walk = "--check-walk" in OS.get_cmdline_user_args()
	check_physics = check_physics or check_walk
	no_gi = "--diagnostic-no-gi" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="): theme = int(arg.trim_prefix("--theme="))
		if arg.begins_with("--axis="): requested_axis = int(arg.trim_prefix("--axis="))
	if theme != 1 or requested_axis != 0: output += "-%d-axis%d" % [theme, requested_axis]
	if no_gi: output += "-no-gi"
	root.window_input.connect(_input)
	call_deferred("start")

func start() -> void:
	root.size = Vector2i(1280, 800)
	# This proof builds one room, not a streamed world. Synchronous native
	# prop loads avoid racing unrelated threaded imports in the dummy renderer.
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var seed_value := WorldGen.level_seed(980712989, theme)
	var layout := Layout.find(seed_value, theme, requested_axis)
	var excluded: Array[Vector2i] = []
	# Preview the same supported mechanism-free rooms used by gameplay.
	while not layout.is_empty():
		room = Chunk.new(seed_value, layout.cell, theme)
		if Layout.exclusions(room).is_empty():
			world.add_child(room)
			break
		excluded.append(layout.cell)
		# Reject before _ready creates interactive models and rendering state.
		room.free()
		layout = Layout.find(seed_value, theme, requested_axis, excluded)
	if layout.is_empty():
		printerr("No supported dry straight corridor: theme=", theme)
		quit(1)
		return
	var axis: int = layout.axis
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(theme)
	if no_gi: env.environment.sdfgi_enabled = false
	world.add_child(env)
	effect = Surface.new()
	room.add_child(effect)
	var cam := Camera3D.new()
	world.add_child(cam)
	var basis := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT) if axis == 1 else Basis.IDENTITY
	cam.position = Vector3(6, room._floor_h(), 6) + basis * Vector3(-0.55, 1.5, -5.2)
	cam.look_at(Vector3(6, room._floor_h(), 6) + basis * Vector3(0, 1.7, 3))
	cam.current = true
	cam.fov = 72
	if capture:
		var torch := SpotLight3D.new()
		torch.position = Vector3(0.1, -0.1, -0.06)
		torch.light_color = Color(0.88, 0.93, 1.0)
		torch.light_energy = 4.5
		torch.spot_range = 21.0
		torch.spot_angle = 46.0
		torch.shadow_enabled = true
		cam.add_child(torch)
	layer = CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(16,16)
	label.text = "Preparing native corridor — isolated proof, not gameplay"
	layer.add_child(label)
	await process_frame
	var begin := Time.get_ticks_msec()
	if not await effect.setup(room, axis, layout.width, layout.height):
		printerr("Wave preparation refused: ", effect.failure)
		quit(1)
		return
	print("Wave prepared: ", Time.get_ticks_msec()-begin, " ms; max_slice_ms=",effect.max_prepare_step_ms,"; meshes=", effect.pieces.size(), " colliders=", effect.colliders.size())
	if check_physics:
		await _check_player()
		return
	if not capture:
		var player := Player.new()
		player.position = effect.frame * Vector3(-0.45, 0.08, -4.6)
		player.rotation.y = -PI/2 if axis == 1 else PI
		world.add_child(player)
		player.set_flashlight(true)
		running = true
		busy = false
		return
	DirAccess.make_dir_recursive_absolute(output)
	for phase in [0.0, 0.4, 0.5, 0.6, 1.0]:
		effect.pose(phase)
		begin = Time.get_ticks_usec()
		effect.sync_collision()
		print("phase=", phase, " collision_ms=", (Time.get_ticks_usec()-begin)/1000.0)
		label.text = "%s native corridor — phase %.2f" % [DescentRun.THEME_NAMES[theme], phase]
		for warm in 5:
			await process_frame
			RenderingServer.force_draw(false, 1.0/60)
		if not DisplayServer.get_name() == "headless":
			root.get_texture().get_image().save_png(output.path_join("phase_%.2f.png" % phase))
	effect.restore()
	var restored: bool = effect.originals_restored()
	print("Original resources and attachments restored: ", restored)
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if restored else 1)

func _physics_process(dt: float) -> bool:
	if running:
		elapsed += dt
		var phase := fmod(elapsed, Profile.DURATION+2) / Profile.DURATION
		effect.pose(minf(phase, 1.0))
		effect.sync_collision()
		label.text = "%s — WASD / Shift / mouse • F: flashlight • Esc: release mouse\nN/P: next/previous dry level • isolated proof, not campaign • cycle %.1f s" % [DescentRun.THEME_NAMES[theme], fmod(elapsed, 10.0)]
	return false

func _input(event: InputEvent) -> void:
	if busy or capture or check_physics: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_N or key == KEY_P:
			busy = true
			call_deferred("_switch", 1 if key == KEY_N else -1)

func _switch(direction: int) -> void:
	running = false
	effect.restore()
	world.queue_free()
	layer.queue_free()
	await process_frame
	await process_frame
	theme = PREVIEW_THEMES[posmod(PREVIEW_THEMES.find(theme)+direction, PREVIEW_THEMES.size())]
	elapsed = 0
	await start()

func _check_player() -> void:
	var player := Player.new()
	player.position = effect.frame * Vector3(0, 0.08, 3 if check_walk else 0)
	player.basis = effect.frame.basis
	root.add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12: await physics_frame
	var maximum_error := 0.0
	var max_ms := 0.0
	var slowest := {}
	var initial := player.position
	var max_in_motion_ms := 0.0
	for i in range(1, 481):
		# Walk against the approaching wave for one second, staying in this
		# isolated cell. Normal Player collision, acceleration and floor snap.
		player.dev_walk = check_walk and i > 120 and i <= 180
		var phase := float(i)/480
		var begin := Time.get_ticks_usec()
		effect.pose(phase)
		var pose_done := Time.get_ticks_usec()
		effect.sync_collision()
		var elapsed_ms := (Time.get_ticks_usec()-begin)/1000.0
		if i > 1 and i < 480: max_in_motion_ms = maxf(max_in_motion_ms, elapsed_ms)
		if elapsed_ms > max_ms:
			max_ms = elapsed_ms
			slowest = {"phase": phase, "pose_ms": (pose_done-begin)/1000.0, "collision_ms": elapsed_ms-(pose_done-begin)/1000.0}
		await physics_frame
		var local: Vector3 = effect.frame.affine_inverse() * player.position
		var expected := Profile.posed(Vector3(local.x, 0, local.z), phase, effect.width, effect.height).y
		maximum_error = maxf(maximum_error, absf(local.y-expected))
	var restored: bool = effect.originals_restored()
	print("PLAYER CHECK max_floor_error=", maximum_error, " max_update_ms=", max_ms, " originals_restored=", restored)
	print("Slowest update: ", JSON.stringify(slowest))
	print("In-motion max_ms=", max_in_motion_ms, " walk_distance=", initial.distance_to(player.position))
	var moved := not check_walk or initial.distance_to(player.position) > 0.75
	player.queue_free()
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if maximum_error < 0.12 and restored and moved else 1)
