extends SceneTree
## Runtime renderer, actual rooms: -- --kind=travel --theme=1 --capture --out-dir=...
const Placement := preload("res://scripts/environment_breath_placement.gd")
const Profile := preload("res://scripts/environment_breath_profile.gd")
const Surface := preload("res://scripts/environment_breath_surface.gd")
const Cleanup := preload("res://tools/lib/audit_cleanup.gd")
var kind := "breath"
var theme := 1
var capture := false
var frames := 48
var no_shadows := false
var out_dir := "/tmp/liminal-breath-shapes"
var effect: Node3D
var elapsed := 0.0
var running := false
var room: Chunk
var label: Label

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="): kind = arg.trim_prefix("--kind=")
		if arg.begins_with("--theme="): theme = int(arg.trim_prefix("--theme="))
		if arg.begins_with("--out-dir="): out_dir = arg.trim_prefix("--out-dir=")
		if arg == "--capture": capture = true
		if arg == "--no-shadows": no_shadows = true
		if arg.begins_with("--frames="): frames = maxi(3, int(arg.trim_prefix("--frames=")))
	call_deferred("start")

func start() -> void:
	if not theme in WorldGen.THEMES or not kind in ["breath", "travel", "ceiling"]:
		printerr("Unknown theme or shape")
		quit(2)
		return
	root.size = Vector2i(1280, 800)
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	var selection: Dictionary = {}
	for at in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		room = Chunk.new(WorldGen.level_seed(980712989, theme), at, theme)
		var choices := Placement.candidates(room, kind)
		if not choices.is_empty():
			selection = choices[0]
			break
		room.free()
		room = null
	if selection.is_empty():
		printerr("No clear wall found for ", kind)
		quit(1)
		return
	root.add_child(room)
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(theme)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 68.0
	var center: Vector3 = selection.center
	# An oblique view makes the bow's depth readable on plain painted walls.
	cam.position = center + selection.face.normal * 1.6 + selection.face.u * 2.4
	if kind == "ceiling":
		cam.position = center + selection.face.u * 1.1 + selection.face.v * 1.1
		cam.position.y = room._floor_h() + 1.5
	cam.look_at(center)
	cam.current = true
	var torch := SpotLight3D.new()
	torch.position = Vector3(0.1, -0.1, -0.06)
	torch.light_color = Color(0.88, 0.93, 1.0)
	torch.light_energy = 4.5
	torch.spot_range = 21.0
	torch.spot_angle = 46.0
	torch.spot_attenuation = 1.15
	torch.shadow_enabled = not no_shadows
	cam.add_child(torch)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 18)
	label.add_theme_font_size_override("font_size", 19)
	label.text = "%s — %s" % [DescentRun.THEME_NAMES[theme], kind]
	layer.add_child(label)
	effect = Surface.new()
	room.add_child(effect)
	var begin := Time.get_ticks_usec()
	if not effect.setup(selection, kind):
		printerr("Effect setup failed")
		quit(1)
		return
	var setup_ms := (Time.get_ticks_usec()-begin)/1000.0
	print("Setup ms: ", setup_ms)
	if not capture:
		running = true
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var max_collision_ms := 0.0
	for i in frames:
		effect.pose(Profile.weights(kind, float(i) / (frames - 1)))
		begin = Time.get_ticks_usec()
		effect.sync_collision()
		max_collision_ms = maxf(max_collision_ms, (Time.get_ticks_usec()-begin)/1000.0)
		for warm in 4:
			await process_frame
			RenderingServer.force_draw(false, 1.0/60.0)
		var img := root.get_texture().get_image()
		if img.save_png(out_dir.path_join("frame_%03d.png" % i)) != OK:
			quit(1)
			return
		if i == frames / 2: img.save_png(out_dir.path_join("peak.png"))
	effect.restore()
	var ok: bool = effect.originals_restored()
	var report := {"kind": kind, "theme": theme, "restored": ok, "frames": frames, "setup_ms": setup_ms,
		"duration": Profile.duration(kind), "max_collision_ms": max_collision_ms}
	FileAccess.open(out_dir.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	room.queue_free()
	await process_frame
	await Cleanup.release(self)
	quit(0 if ok else 1)

func _process(dt: float) -> bool:
	if running:
		elapsed += dt
		var phase := fmod(elapsed, Profile.duration(kind)) / Profile.duration(kind)
		var values := Profile.weights(kind, phase)
		effect.pose(values)
		effect.sync_collision()
		label.text = "%s — %s\nCycle %.1f / %.1f s • deformation %.0f%%" % [DescentRun.THEME_NAMES[theme], kind, phase * Profile.duration(kind), Profile.duration(kind), values[0] * 100.0]
	return false
