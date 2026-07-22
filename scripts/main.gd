extends Node3D
## Entry point and level manager. Five endless floors share one player:
##   1 — seedy Vegas hotel-casino            (theme 0)
##   2 — sterile Severance-style office      (theme 1)
##   3 — dripping sewer works under everything (theme 2)
##   4 — an airport terminal at 3 a.m., between every flight (theme 4)
##   5 — an abandoned asylum, beds still made, straps still buckled (theme 5)
##   6 — a high school after the last bell that never rang (theme 6)
## The number key is an index into WorldGen.THEMES, NOT the theme id — theme 3
## was a derelict theme park, cut, and the rest keep their original ids so every
## existing seed still generates the world it always did.
## Switching floors fades to black with an elevator chime, rebuilds the world
## with that floor's theme and seed, and restores your position on that floor.

@export var world_seed: int = 0

const DEFAULT_SPAWN := Vector3(6.0, 0.15, 2.0)
# Safe arrival offsets within a cell, per theme, for portal jumps.
const PORTAL_ARRIVE := {
	0: Vector3(3.2, 0.15, 2.0), 1: Vector3(3.2, 0.15, 2.0),
	2: Vector3(3.9, 0.15, 1.0),
	4: Vector3(3.2, 0.15, 2.0), 5: Vector3(3.2, 0.15, 2.0),
	6: Vector3(3.2, 0.15, 2.0),
}

var player: Player
var level_root: Node3D
var cm: ChunkManager
var we: WorldEnvironment
var ambience: Ambience
var active_level := 0
var _saved_pos := {}
var _switching := false
var _fade: ColorRect
var _ding: AudioStreamPlayer
var _warp: AudioStreamPlayer
var _post: ColorRect
var _crt := true
var _bench := false
var _bench_t := 0.0
var _bench_frames := 0
var _bench_worst := 0.0
var _bench_slow := 0
var _bench_prev := Vector3.ZERO
var _bench_steps: Array[float] = []
var _figures: ShadowFigures
var _music: AudioStreamPlayer
var _title: TitleScreen
var _hint: Label

# One mood track per floor.
const MUSIC_TRACKS := {
	0: "res://music/lim1.mp3", 1: "res://music/lim2.mp3",
	2: "res://music/lim3.mp3",
	4: "res://music/lim5.mp3", 5: "res://music/lim6.mp3",
	6: "res://music/lim4.mp3",
}
const MUSIC_DB := -14.0


func _ready() -> void:
	randomize()
	var spawn := DEFAULT_SPAWN
	var pos_given := false
	var yaw := PI  # face into the room
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = int(arg.substr(7))
		elif arg.begins_with("--pos="):
			var parts := arg.substr(6).split(",")
			if parts.size() >= 2:
				spawn = Vector3(float(parts[0]), 0.15, float(parts[1]))
				pos_given = true
		elif arg.begins_with("--yaw="):
			yaw = deg_to_rad(float(arg.substr(6)))
		elif arg.begins_with("--level="):
			# --level takes a THEME id, not a key index, so old commands still work
			var lv := int(arg.substr(8))
			active_level = lv if WorldGen.THEMES.has(lv) else 0
	if world_seed == 0:
		world_seed = (randi() & 0x7FFFFFFF) | 1
	if not pos_given:
		spawn = _safe_arrival(active_level, Vector2i.ZERO, DEFAULT_SPAWN)
	print("Liminal Vegas — seed %d" % world_seed)
	# Audits and screenshot helpers intentionally quit after a few seconds;
	# don't leave background resource workers alive during their forced exit.
	var quick_exit := OS.get_cmdline_user_args().has("--audit")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			quick_exit = true
	if not quick_exit:
		Chunk.request_prop_preloads()
	add_to_group("portal_listener")
	if OS.get_cmdline_user_args().has("--notaa"):
		get_viewport().use_taa = false
	# dev: start with the tube off, so screenshots show the raw full-res render
	if OS.get_cmdline_user_args().has("--nocrt"):
		_crt = false
	_apply_scaling()
	get_viewport().size_changed.connect(_apply_scaling)
	_setup_audio_bus()

	we = WorldEnvironment.new()
	we.environment = _build_env(active_level)
	add_child(we)

	player = Player.new()
	player.world_seed = _level_seed(active_level)
	player.level_theme = active_level
	_build_level(active_level, spawn)

	player.position = spawn
	player.rotation.y = yaw
	add_child(player)

	if OS.get_cmdline_user_args().has("--spin"):
		player.dev_spin = true
	if OS.get_cmdline_user_args().has("--audit"):
		_audit_partitions()
	if OS.get_cmdline_user_args().has("--chunktime"):
		ChunkManager._dev_timing = true
	if OS.get_cmdline_user_args().has("--bench"):
		# walk forward while turning — the exact motion that looks choppy
		player.dev_spin = true
		player.dev_walk = true
		_bench = true
	ambience = Ambience.new(active_level)
	add_child(ambience)
	var oneshots := OneShots.new()
	oneshots.player = player
	add_child(oneshots)
	_figures = ShadowFigures.new()
	_figures.player = player
	add_child(_figures)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -50.0
	add_child(_music)
	_switch_music(active_level)
	_build_ui()
	_build_title()
	_maybe_screenshot()


func _level_seed(level: int) -> int:
	if level == 0:
		return world_seed
	var salt := 348039917
	if level == 2:
		salt = 715827883
	elif level == 4:
		salt = 536870923
	elif level == 5:
		salt = 998244353
	elif level == 6:
		salt = 179424673
	return ((world_seed ^ salt) & 0x7FFFFFFF) | 1


func _build_level(level: int, around: Vector3) -> void:
	level_root = Node3D.new()
	add_child(level_root)
	cm = ChunkManager.new()
	cm.world_seed = _level_seed(level)
	cm.theme = level
	cm.player = player
	level_root.add_child(cm)
	cm.warm_up(Vector2i(floori(around.x / ChunkManager.CELL), floori(around.z / ChunkManager.CELL)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# keys 1..N select the Nth live theme — no gap where the park used to be
		var idx: int = event.physical_keycode - KEY_1
		if idx >= 0 and idx < WorldGen.THEMES.size():
			_switch_level(WorldGen.THEMES[idx])
		elif event.physical_keycode == KEY_V:
			_crt = not _crt
			_post.visible = _crt
			_apply_scaling()


func _switch_level(level: int) -> void:
	if _switching or level == active_level:
		return
	var pos: Vector3 = _saved_pos.get(level, Vector3.INF)
	if pos == Vector3.INF:
		pos = _safe_arrival(level, Vector2i.ZERO, DEFAULT_SPAWN)
	_jump_to(level, pos, false)


## Stepping into a swirling portal: emerge in the same cell of another world.
func _on_portal(dest: int, cellv: Vector2i) -> void:
	if _switching or dest == active_level:
		return
	_jump_to(dest, _safe_arrival(dest, cellv, PORTAL_ARRIVE[dest]), true)


## Airport gate cells seal a 2.2m apron strip behind curtain glass along
## their anchor wall. If a fixed arrival offset would land inside that strip
## — an inescapable pocket — mirror it across the cell.
func _safe_arrival(level: int, cellv: Vector2i, base: Vector3) -> Vector3:
	var pos := Vector3(cellv.x * 12.0 + base.x, 0.15, cellv.y * 12.0 + base.z)
	if level != 4:
		return pos
	var ws := _level_seed(4)
	if WorldGen.cell_style(ws, cellv, 4) != WorldGen.AIR_GATE:
		return pos
	var wdir := WorldGen.anchor_wall(ws, cellv, 310)
	if wdir == 3 and base.z < 2.4:
		pos.z = cellv.y * 12.0 + (12.0 - base.z)
	elif wdir == 2 and base.z > 9.6:
		pos.z = cellv.y * 12.0 + (12.0 - base.z)
	elif wdir == 1 and base.x < 2.4:
		pos.x = cellv.x * 12.0 + (12.0 - base.x)
	elif wdir == 0 and base.x > 9.6:
		pos.x = cellv.x * 12.0 + (12.0 - base.x)
	return pos


func _jump_to(level: int, pos: Vector3, via_portal: bool) -> void:
	_switching = true
	_saved_pos[active_level] = player.position
	if via_portal:
		_warp.play()
	else:
		_ding.play()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16 if via_portal else 0.3)
	await tw.finished
	level_root.queue_free()
	_figures.despawn()
	_switch_music(level)
	active_level = level
	_build_level(level, pos)
	player.teleport(pos)
	player.world_seed = _level_seed(level)
	player.level_theme = level
	we.environment = _build_env(level)
	ambience.queue_free()
	ambience = Ambience.new(level)
	add_child(ambience)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.45 if via_portal else 0.5)
	_switching = false


func _process(dt: float) -> void:
	if not _bench:
		return
	_bench_t += dt
	_bench_frames += 1
	_bench_worst = maxf(_bench_worst, dt)
	if dt > 1.0 / 55.0:
		_bench_slow += 1
	# per-RENDERED-frame translation: if it only advances on physics ticks the
	# steps come out uneven (some frames 0, some double) — that is the judder
	var pp := player.cam.global_position
	var step := pp.distance_to(_bench_prev)
	_bench_prev = pp
	if _bench_frames > 2:
		_bench_steps.append(step)
	if _bench_t >= 3.0:
		if _bench_steps.size() > 10:
			var mn := 1e9
			var mx := 0.0
			var sum := 0.0
			for v in _bench_steps:
				mn = minf(mn, v)
				mx = maxf(mx, v)
				sum += v
			var avg := sum / float(_bench_steps.size())
			var zero := 0
			for v in _bench_steps:
				if v < avg * 0.25:
					zero += 1
			print("  per-frame CAMERA move: avg %.4fm  min %.4f  max %.4f  (max/avg %.2fx)  stalled frames %d/%d" % [
				avg, mn, mx, mx / maxf(avg, 0.0001), zero, _bench_steps.size()])
			_bench_steps.clear()
		print("fps %.1f | frame avg %.2fms worst %.2fms | frames over 18ms: %d/%d | physics %d Hz" % [
			float(_bench_frames) / _bench_t, 1000.0 * _bench_t / float(_bench_frames),
			1000.0 * _bench_worst, _bench_slow, _bench_frames,
			Engine.physics_ticks_per_second])
		_bench_t = 0.0
		_bench_frames = 0
		_bench_worst = 0.0
		_bench_slow = 0


## Dev: count partitions that would have ended inside a doorway.
func _audit_partitions() -> void:
	for th in WorldGen.THEMES:
		var ws := _level_seed(th)
		var splits := 0
		var old_bad := 0
		var new_bad := 0
		var dropped := 0
		for cx in range(-30, 31):
			for cz in range(-30, 31):
				var c := Vector2i(cx, cz)
				var sp := WorldGen.room_split(ws, WorldGen.room_id(ws, c), th)
				if sp.is_empty() or WorldGen.room_id(ws, c) != c:
					continue
				splits += 1
				var ax: bool = sp[0]
				var want: float = sp[1]
				var blocked := WorldGen.crossing_openings(ws, c, th, ax)
				for b in blocked:
					if absf(want - b.x) < b.y:
						old_bad += 1
						if old_bad <= 3:
							print("   was-broken cell %s  (centre %.0f, %.0f)" % [c, c.x * 12.0 + 6.0, c.y * 12.0 + 6.0])
						break
				var got := WorldGen.partition_offset(ws, c, th, ax, want)
				if got < 0.0:
					ax = not ax
					got = WorldGen.partition_offset(ws, c, th, ax, want)
					blocked = WorldGen.crossing_openings(ws, c, th, ax)
				if got < 0.0:
					dropped += 1
					continue
				for b in blocked:
					if absf(got - b.x) < b.y:
						new_bad += 1
						break
		print("theme %d: %d partitions | split a doorway BEFORE: %d | NOW: %d | skipped: %d" % [
			th, splits, old_bad, new_bad, dropped])
	get_tree().quit()


## Crossfade the floor's mood track in; unknown floors fade to silence.
func _switch_music(level: int) -> void:
	var target: String = MUSIC_TRACKS.get(level, "")
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -50.0, 0.6)
	tw.tween_callback(func():
		if target == "":
			_music.stop()
			return
		var st: AudioStreamMP3 = load(target)
		st.loop = true
		_music.stream = st
		_music.play(randf() * 20.0))
	if target != "":
		tw.tween_property(_music, "volume_db", MUSIC_DB, 1.6)


## With the CRT on, genuine 240-line source footage: the 3D world renders at
## 240p and gets bilinearly stretched onto the tube, and the CRT pass then lays
## its 240 scanlines over the top 1:1. With the CRT off there is no tube to
## match, so the world renders at full native resolution instead.
func _apply_scaling() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if _crt:
		vp.scaling_3d_scale = clampf(240.0 / float(vp.size.y), 0.05, 1.0)
	else:
		vp.scaling_3d_scale = 1.0


## Shared "Hall" bus: every spatial emitter routes through a soft reverb so
## sounds feel like they happen inside the building.
func _setup_audio_bus() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Hall")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.8
	rev.damping = 0.5
	rev.wet = 0.25
	AudioServer.add_bus_effect(idx, rev)


func _build_env(theme: int) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	# real-time GI: bounce light, color bleed, emissive surfaces lighting rooms
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.15
	env.sdfgi_bounce_feedback = 0.4

	if theme == 6:
		# after hours: the strips are still on, cold and even, and the polished
		# floor throws them back. Bright enough to see all the way down, which
		# is the problem.
		env.background_color = Color(0.02, 0.021, 0.024)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.72, 0.75, 0.80)
		env.ambient_light_energy = 0.42
		env.tonemap_exposure = 1.2
		env.sdfgi_energy = 1.2
		env.glow_enabled = true
		env.glow_intensity = 0.42
		env.glow_bloom = 0.03
		env.fog_light_color = Color(0.12, 0.13, 0.14)
		env.fog_density = 0.016
		env.volumetric_fog_density = 0.007
		env.volumetric_fog_albedo = Color(0.80, 0.82, 0.86)
		env.volumetric_fog_length = 48.0
		env.ssao_radius = 1.4
		env.ssao_intensity = 1.3
		return env
	if theme == 5:
		# the asylum: bile-green dark, dust hanging in dead fluorescent light
		env.background_color = Color(0.005, 0.007, 0.004)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.58, 0.44)
		env.ambient_light_energy = 0.17
		env.tonemap_exposure = 1.25
		env.sdfgi_energy = 1.15
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_bloom = 0.04
		env.fog_light_color = Color(0.05, 0.065, 0.045)
		env.fog_density = 0.03
		env.volumetric_fog_density = 0.014
		env.volumetric_fog_albedo = Color(0.62, 0.72, 0.55)
		env.volumetric_fog_length = 44.0
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.6
		return env
	if theme == 4:
		# 3 a.m. departure hall: cold white light dissolving into black glass
		env.background_color = Color(0.006, 0.009, 0.018)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.70, 0.85)
		env.ambient_light_energy = 0.22
		env.tonemap_exposure = 1.25
		env.sdfgi_energy = 1.2
		env.glow_enabled = true
		env.glow_intensity = 0.4
		env.glow_bloom = 0.03
		env.fog_light_color = Color(0.10, 0.12, 0.16)
		env.fog_density = 0.015
		env.volumetric_fog_density = 0.005
		env.volumetric_fog_albedo = Color(0.75, 0.82, 0.95)
		env.volumetric_fog_length = 56.0
		env.ssao_radius = 1.3
		env.ssao_intensity = 1.1
		return env
	if theme == 2:
		# black water and green rot; the dark leans cold, not warm
		env.background_color = Color(0.004, 0.006, 0.005)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.35, 0.45, 0.38)
		env.ambient_light_energy = 0.16
		env.tonemap_exposure = 1.25
		env.sdfgi_energy = 1.15
		env.glow_enabled = true
		env.glow_intensity = 0.45
		env.glow_bloom = 0.04
		env.fog_light_color = Color(0.04, 0.07, 0.05)
		env.fog_density = 0.019
		env.volumetric_fog_density = 0.011
		env.volumetric_fog_albedo = Color(0.5, 0.68, 0.55)
		env.volumetric_fog_length = 40.0
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.7
	elif theme == 1:
		# sterile daylight-white: corridors dissolve into bright haze
		env.background_color = Color(0.55, 0.58, 0.55)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.9, 0.86)
		env.ambient_light_energy = 0.45
		env.tonemap_exposure = 1.25
		env.sdfgi_energy = 1.3
		env.glow_enabled = true
		env.glow_intensity = 0.3
		env.glow_bloom = 0.02
		env.fog_light_color = Color(0.72, 0.76, 0.72)
		env.fog_density = 0.009
		env.volumetric_fog_density = 0.003
		env.volumetric_fog_albedo = Color(0.9, 0.95, 0.9)
		env.volumetric_fog_length = 48.0
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.0
	else:
		# warm smoky casino dusk
		env.background_color = Color(0.02, 0.013, 0.018)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.45, 0.36, 0.30)
		env.ambient_light_energy = 0.19
		env.tonemap_exposure = 1.3
		env.sdfgi_energy = 1.1
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_bloom = 0.05
		env.fog_light_color = Color(0.23, 0.15, 0.11)
		env.fog_density = 0.026
		env.volumetric_fog_density = 0.011
		env.volumetric_fog_albedo = Color(0.9, 0.78, 0.62)
		env.volumetric_fog_length = 48.0
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.4
	return env


func _build_ui() -> void:
	# CRT tube finish over the 3D view, under UI (V toggles)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	# these floors run far darker than an arcade cabinet — push the tube
	pm.set_shader_parameter("bright_boost", 1.4)
	_post.material = pm
	_post.visible = _crt
	post_layer.add_child(_post)
	add_child(post_layer)

	var cl := CanvasLayer.new()
	cl.layer = 2
	var lb := Label.new()
	_hint = lb
	lb.text = "WASD / arrows move   ·   Shift run   ·   1-6 switch floors   ·   swirling portals jump worlds   ·   V toggles CRT   ·   Esc release mouse"
	lb.position = Vector2(18, 14)
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8, 0.9))
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lb.add_theme_constant_override("shadow_offset_x", 1)
	lb.add_theme_constant_override("shadow_offset_y", 1)
	cl.add_child(lb)
	# fullscreen fade for level transitions
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_fade)
	add_child(cl)
	_ding = AudioStreamPlayer.new()
	_ding.stream = SoundBank.elev()
	_ding.volume_db = -8.0
	add_child(_ding)
	_warp = AudioStreamPlayer.new()
	_warp.stream = SoundBank.warp()
	_warp.volume_db = -6.0
	add_child(_warp)


## The strip along the top says the same as the title screen; it goes once you
## have been walking a while. Timed from the start, not from the titles — the
## point is to still be there for your first few steps.
func _start_hint_fade() -> void:
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(_hint, "modulate:a", 0.0, 2.5)


## The logo, the keys, and one instruction, over the already-running world.
## Skipped for `--screenshot=` runs, which want the view and not the titles.
func _build_title() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot=") or arg == "--nologo":
			_start_hint_fade()
			return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_process_unhandled_input(false)  # no looking around yet either
	_title = TitleScreen.new()
	_title.started.connect(_on_start)
	add_child(_title)


func _on_start() -> void:
	_title = null
	player.grab_look()
	player.set_process_unhandled_input(true)
	_start_hint_fade()


## Dev helper: `godot --path . -- --screenshot=/tmp/shot.png` renders a couple
## of seconds and saves a frame, for checking visuals from the command line.
func _maybe_screenshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			var path := arg.substr(13)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			await get_tree().create_timer(2.5).timeout
			print("player at ", player.global_position)
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
