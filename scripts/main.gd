extends Node3D
## Entry point and level manager. Eight endless floors share one player:
##   1 — seedy Vegas hotel-casino            (theme 0)
##   2 — sterile Severance-style office      (theme 1)
##   3 — dripping sewer works under everything (theme 2)
##   4 — an airport terminal at 3 a.m., between every flight (theme 4)
##   5 — an abandoned asylum, beds still made, straps still buckled (theme 5)
##   6 — a high school after the last bell that never rang (theme 6)
##   7 — an abandoned shopping mall with every shutter down (theme 7)
##   8 — an island prison whose cell blocks never end (theme 8)
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
	7: Vector3(3.2, 0.15, 2.0), 8: Vector3(3.2, 0.15, 2.0),
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
var _whispers: Whispers
var _heart: Heartbeat
var _dying := false
var _music: AudioStreamPlayer
var _title: TitleScreen
var _hint: Label
var _interact_panel: PanelContainer
var _interact_hint: Label
var _event_panel: PanelContainer
var _event_hint: Label
var _event_tween: Tween
var _interact_style: StyleBoxFlat
var _event_style: StyleBoxFlat
var _events: EnvironmentEvents
var descent := false
var run: DescentRun
var descent_route: DescentRoute
var _descent_preparing := false
var _attention_override := -1.0
var _blackout_ambient := -1.0
var _descent_summary: DescentSummary
var _pursuer: DescentPursuer
var _descent_hud: DescentHUD
var _return_prompt: ReturnPrompt

# One mood track per floor.
const MUSIC_TRACKS := {
	0: "res://music/lim1.mp3", 1: "res://music/lim2.mp3",
	2: "res://music/lim3.mp3",
	4: "res://music/lim5.mp3", 5: "res://music/lim6.mp3",
	6: "res://music/lim4.mp3",
	7: "res://music/lim7.mp3", 8: "res://music/lim8.mp3",
}
# A distinct late-run cue gives Descent's final two floors an audible rise in
# pressure without changing Wander mode's established per-level soundtrack.
const DESCENT_LATE_TRACK := "res://music/lim9.mp3"
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
		elif arg == "--mode=descent":
			descent = true
		elif arg.begins_with("--attention="):
			_attention_override = clampf(float(arg.substr(12)), 0.0, 1.0)
	if world_seed == 0:
		world_seed = (randi() & 0x7FFFFFFF) | 1
	if descent:
		run = DescentRun.new()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--descent-floor="):
				run.floor_idx = clampi(int(arg.substr(16)) - 1, 0,
					DescentRun.ORDER.size() - 1)
		active_level = run.theme()
		if _attention_override >= 0.0:
			run.attention = _attention_override
		_connect_descent_run()
		run.prepare_floor()
		add_child(run)
		descent_route = DescentRoute.build(_level_seed(active_level), active_level)
		print("Descent floor %d target %s wall %d, %d edges" % [
			run.floor_idx + 1, descent_route.target, descent_route.target_wall,
			descent_route.graph_distance])
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
	add_to_group("level_manager")
	add_to_group("descent_listener")
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
	player.allow_sprint = not descent
	if descent and run != null:
		run.player = player
	_build_level(active_level, spawn)

	player.position = spawn
	player.rotation.y = yaw
	add_child(player)
	if OS.get_cmdline_user_args().has("--flashlight"):
		player.set_flashlight(true)

	if OS.get_cmdline_user_args().has("--spin"):
		player.dev_spin = true
	if OS.get_cmdline_user_args().has("--audit"):
		_audit_partitions()
		return
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
	_whispers = Whispers.new()
	_whispers.player = player
	# Same gate as the figures: nothing mutters behind a title or a rule card.
	_whispers.suspended = true
	add_child(_whispers)
	_figures = ShadowFigures.new()
	_figures.player = player
	# No haunt timers run behind a title or rule card. Screenshot/--nologo
	# starts explicitly release this gate below.
	_figures.suspended = true
	_figures.stared_away.connect(_on_figure_stared_away)
	_figures.reached_player.connect(_on_figure_reached_player)
	add_child(_figures)
	# Frights raise the pulse; it bleeds away on its own. Wired after the
	# figures exist so it can sample how close the nearest one is.
	_heart = Heartbeat.new()
	_heart.figures = _figures
	_heart.suspended = true
	add_child(_heart)
	_figures.seen_by_player.connect(
		func(): _heart.bump(Heartbeat.BUMP_SEEN))
	_figures.burned_away.connect(
		func(): _heart.bump(Heartbeat.BUMP_BURNED))
	_figures.stared_away.connect(
		func(): _heart.bump(Heartbeat.BUMP_STARED))
	_events = EnvironmentEvents.new()
	_events.player = player
	_events.descent_mode = descent
	_events.set_level(level_root)
	add_child(_events)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -50.0
	add_child(_music)
	_switch_music(active_level)
	_build_ui()
	player.interaction_prompt_changed.connect(_on_interaction_prompt)
	_events.message.connect(_show_event_message)
	if OS.get_cmdline_user_args().has("--caption-preview"):
		_preview_captions()
	_build_title()
	if _title == null:
		if descent:
			_begin_descent_floor()
		else:
			_figures.suspended = false
			_whispers.suspended = false
			_heart.suspended = false
	_maybe_screenshot()
	call_deferred("_settle_initial_arrival")


func _level_seed(level: int) -> int:
	return WorldGen.level_seed(world_seed, level)


func _build_level(level: int, around: Vector3) -> void:
	level_root = Node3D.new()
	add_child(level_root)
	cm = ChunkManager.new()
	cm.world_seed = _level_seed(level)
	cm.theme = level
	cm.player = player
	cm.descent = descent
	if descent:
		if descent_route == null or descent_route.theme != level:
			descent_route = DescentRoute.build(_level_seed(level), level)
		cm.descent_floor_idx = run.floor_idx
		cm.descent_route = descent_route
		cm.blackout = run.blackout
		cm.anomalies = run.anomalies
	level_root.add_child(cm)
	cm.warm_up(Vector2i(floori(around.x / ChunkManager.CELL), floori(around.z / ChunkManager.CELL)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q and _title == null \
				and not _switching and not is_instance_valid(_return_prompt) \
				and not is_instance_valid(_descent_summary):
			get_viewport().set_input_as_handled()
			_show_return_prompt()
			return
		# keys 1..N select the Nth live theme — no gap where the park used to be
		var idx: int = event.physical_keycode - KEY_1
		if not descent and idx >= 0 and idx < WorldGen.THEMES.size():
			_switch_level(WorldGen.THEMES[idx])
		elif not descent and event.physical_keycode == KEY_V:
			_crt = not _crt
			_post.visible = _crt
			_apply_scaling()


func _show_return_prompt() -> void:
	_return_prompt = ReturnPrompt.new()
	_return_prompt.descent = descent
	_return_prompt.confirmed.connect(_confirm_return_to_title)
	_return_prompt.cancelled.connect(_cancel_return_to_title)
	add_child(_return_prompt)
	player.velocity = Vector3.ZERO
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	if descent and run != null:
		run.suspend_rules()
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)


func _cancel_return_to_title() -> void:
	if is_instance_valid(_return_prompt):
		_return_prompt.queue_free()
	_return_prompt = null
	player.set_process_unhandled_input(true)
	player.grab_look()
	if descent and run != null and not run.ended:
		run.resume_rules()
		_figures.suspended = false
		_whispers.suspended = false
		_heart.suspended = false
		if is_instance_valid(_descent_hud):
			_descent_hud.set_active(true)
	else:
		_figures.suspended = false
		_whispers.suspended = false
		_heart.suspended = false


func _confirm_return_to_title() -> void:
	if is_instance_valid(_return_prompt):
		_return_prompt.queue_free()
	_return_prompt = null
	player.set_flashlight(false)
	if descent:
		await _leave_descent()
		return
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	_saved_pos.clear()
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_saved_pos.clear()
	_set_mode_hint()
	_build_title()


func _switch_level(level: int) -> void:
	if descent or _switching or level == active_level:
		return
	var pos: Vector3 = _saved_pos.get(level, Vector3.INF)
	if pos == Vector3.INF:
		pos = _safe_arrival(level, Vector2i.ZERO, DEFAULT_SPAWN)
	_jump_to(level, pos, false)


## Stepping into a swirling portal: emerge in the same cell of another world.
func _on_portal(dest: int, cellv: Vector2i) -> void:
	if descent or _switching or dest == active_level:
		return
	_jump_to(dest, _safe_arrival(dest, cellv, PORTAL_ARRIVE[dest]), true)


## Called by physical lift panels built into selected generated rooms.
func use_elevator(dest: int) -> void:
	if descent or _switching or dest == active_level or not WorldGen.THEMES.has(dest):
		return
	_events.elevator_response()
	_show_event_message("FLOOR %d" % (WorldGen.THEMES.find(dest) + 1))
	_switch_level(dest)


func _connect_descent_run() -> void:
	run.world_seed = world_seed
	run.pinned_attention = _attention_override
	if player != null:
		run.player = player
	run.attention_changed.connect(_on_descent_attention)
	run.violation.connect(_on_descent_violation)
	run.blackout_changed.connect(_on_descent_blackout)
	run.anomaly_requested.connect(_on_descent_anomaly)
	run.run_ended.connect(_on_descent_ended)


func _begin_descent_floor() -> void:
	if not descent or run == null or run.ended:
		return
	run.player = player
	run.start_floor()
	player.allow_sprint = false
	_figures.suspended = false
	_whispers.suspended = false
	_heart.suspended = false
	_ensure_descent_hud()
	_descent_hud.set_active(true)
	_on_descent_attention(run.attention)


func _ensure_descent_hud() -> void:
	if not is_instance_valid(_descent_hud):
		_descent_hud = DescentHUD.new()
		add_child(_descent_hud)
	_descent_hud.configure(player, descent_route, run,
		_level_seed(active_level), active_level)


func suspend_descent_rules() -> void:
	if descent and run != null:
		run.suspend_rules()


func _on_descent_lift() -> void:
	if not descent or run == null or run.ended or _switching \
			or run.is_last_floor():
		return
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)
	run.suspend_rules()
	run.floor_idx += 1
	run.prepare_floor()
	var next_theme := run.theme()
	descent_route = DescentRoute.build(_level_seed(next_theme), next_theme)
	print("Descent floor %d target %s wall %d, %d edges" % [
		run.floor_idx + 1, descent_route.target, descent_route.target_wall,
		descent_route.graph_distance])
	var spawn := _safe_arrival(next_theme, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(next_theme, spawn, false)
	_begin_descent_floor()


func _on_descent_exit() -> void:
	if descent and run != null and run.is_last_floor() and not run.ended:
		run.finish(true)


func _on_figure_stared_away() -> void:
	if descent and run != null:
		run.add_stare_violation()


## One of them reached you. The endless floors cannot be lost, so there it is a
## scare and nothing else; a Descent run ends the same way the pursuer ends it.
## One of them reached you. This is the only way to lose in Wander: the floors
## are endless and cannot be completed, so the run simply ends and you are put
## back at the title. A Descent run ends the way the pursuer already ends it.
##
## Nothing here is recoverable on purpose. The flashlight is the answer, it is
## on a ten-second cell, and letting one close the distance while you decide is
## the mistake being punished.
func _on_figure_reached_player() -> void:
	if _dying:
		return
	_dying = true
	_play_player_death()
	if descent and run != null and not run.ended:
		run.finish(false)
		return
	_die_to_title()


## Not positional: this is the one sound in the game that is not happening
## somewhere in the room.
func _play_player_death() -> void:
	var d := Sfx.random_player_death()
	if d[0] == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = d[0]
	pl.volume_db = float(d[1])
	pl.bus = "Hall"
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()


## Hold on the moment for a beat — long enough to register what reached you —
## then black, then the title. The fade runs slower than a floor change: a lift
## is a transition, this is an ending.
func _die_to_title() -> void:
	_switching = true
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	player.set_flashlight(false)
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	if is_instance_valid(_return_prompt):
		_return_prompt.queue_free()
		_return_prompt = null
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.5).set_delay(0.45)
	await tw.finished
	_figures.despawn()
	_whispers.stop()
	_heart.reset()
	_saved_pos.clear()
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_saved_pos.clear()
	_switching = false
	_dying = false
	_set_mode_hint()
	_build_title()


func _on_descent_attention(_value: float) -> void:
	if not descent:
		return
	var threat := run.threat() if run != null else 0.0
	if _post != null and _post.material is ShaderMaterial:
		(_post.material as ShaderMaterial).set_shader_parameter(
			"noise_amount", 1.0 + threat * 1.6)
	if _figures != null:
		_figures.interval_scale = lerpf(1.0, 0.35, threat)
	if threat >= 0.85 and run != null and not run.suspended \
			and not is_instance_valid(_pursuer):
		_spawn_descent_pursuer()


func _spawn_descent_pursuer() -> void:
	if not descent or run == null or run.ended or run.suspended:
		return
	var ws := _level_seed(active_level)
	var origin := Vector2i(floori(player.global_position.x / 12.0),
		floori(player.global_position.z / 12.0))
	var queue: Array[Vector2i] = [origin]
	var dist := {}
	dist[origin] = 0
	var candidates: Array[Vector2i] = []
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var d := int(dist[at])
		if d >= 4:
			candidates.append(at)
			continue
		for dir in 4:
			if WorldGen.edge_info(ws, at, dir, active_level)["wall"]:
				continue
			var nb: Vector2i = at + WorldGen.DIRV[dir]
			if dist.has(nb):
				continue
			dist[nb] = d + 1
			queue.append(nb)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Vector2i, b: Vector2i):
		return WorldGen.h(ws, a.x, a.y, 2601) \
			< WorldGen.h(ws, b.x, b.y, 2601))
	var chosen := candidates[0]
	for candidate in candidates:
		var point := Vector3(float(candidate.x) * 12.0 + 6.0, 1.4,
			float(candidate.y) * 12.0 + 6.0)
		if not player.cam.is_position_in_frustum(point):
			chosen = candidate
			break
	_pursuer = DescentPursuer.new()
	_pursuer.player = player
	_pursuer.world_seed = ws
	_pursuer.theme = active_level
	_pursuer.speed = lerpf(3.0, 3.75, run.floor_progress())
	_pursuer.position = Vector3(float(chosen.x) * 12.0 + 6.0, 0.0,
		float(chosen.y) * 12.0 + 6.0)
	_pursuer.caught.connect(_on_pursuer_caught)
	level_root.add_child(_pursuer)


func _on_pursuer_caught() -> void:
	if descent and run != null and not run.ended:
		run.finish(false)


func _on_descent_violation(kind: int) -> void:
	if not descent or player == null:
		return
	var message := "RULE BROKEN"
	match kind:
		DescentRun.Rule.STARE:
			message = "RULE BROKEN — LOOK AWAY"
		DescentRun.Rule.STOP:
			message = "RULE BROKEN — KEEP MOVING"
		DescentRun.Rule.BACKTRACK:
			message = "RULE BROKEN — DO NOT GO BACK"
		DescentRun.Rule.BLACKOUT_MOVE:
			message = "RULE BROKEN — STAND STILL"
	_show_event_message(message, true)
	var groan := AudioStreamPlayer3D.new()
	groan.stream = SoundBank.creak()
	groan.volume_db = -11.0
	groan.max_distance = 28.0
	groan.unit_size = 8.0
	add_child(groan)
	groan.global_position = player.global_position + Vector3(0, 1.0, 0)
	groan.finished.connect(groan.queue_free)
	groan.play()
	if _post != null and _post.material is ShaderMaterial:
		var mat := _post.material as ShaderMaterial
		var base := 1.0 + run.threat() * 1.6
		mat.set_shader_parameter("noise_amount", minf(3.0, base + 0.7))
		var tw := create_tween()
		tw.tween_method(_set_post_noise,
			minf(3.0, base + 0.7), base, 0.32)


func _set_post_noise(value: float) -> void:
	if _post != null and _post.material is ShaderMaterial:
		(_post.material as ShaderMaterial).set_shader_parameter(
			"noise_amount", value)


func _on_descent_blackout(on: bool) -> void:
	if not descent or cm == null:
		return
	cm.set_blackout(on)
	if on:
		if _blackout_ambient < 0.0:
			_blackout_ambient = we.environment.ambient_light_energy
		we.environment.ambient_light_energy = 0.003
		_play_descent_cue(SoundBank.thud(), -7.0)
		_show_event_message("BLACKOUT — STAND STILL", true)
	else:
		if _blackout_ambient >= 0.0:
			we.environment.ambient_light_energy = _blackout_ambient
			_blackout_ambient = -1.0
		_play_descent_cue(SoundBank.ding(), -10.0)
		_show_event_message("POWER RESTORED — KEEP MOVING")


func _play_descent_cue(stream: AudioStream, volume: float) -> void:
	var cue := AudioStreamPlayer.new()
	cue.stream = stream
	cue.volume_db = volume
	add_child(cue)
	cue.finished.connect(cue.queue_free)
	cue.play()


func _on_descent_anomaly(at: Vector2i, kind: int) -> void:
	if not descent or cm == null or descent_route == null \
			or at == descent_route.target:
		return
	cm.set_anomaly(at, kind)


func _on_descent_ended(won: bool) -> void:
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)
	if is_instance_valid(_pursuer):
		_pursuer.queue_free()
	_pursuer = null
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_descent_summary(won)


func _show_descent_summary(won: bool) -> void:
	if is_instance_valid(_descent_summary):
		return
	_descent_summary = DescentSummary.new()
	_descent_summary.won = won
	_descent_summary.floor_idx = run.floor_idx
	_descent_summary.elapsed = run.elapsed
	_descent_summary.violations = run.violations
	_descent_summary.world_seed = world_seed
	_descent_summary.retry.connect(_restart_descent)
	_descent_summary.leave.connect(_leave_descent)
	add_child(_descent_summary)


func _restart_descent() -> void:
	if _switching:
		return
	if is_instance_valid(_descent_summary):
		_descent_summary.queue_free()
	_descent_summary = null
	if run != null and run.blackout:
		_on_descent_blackout(false)
	if is_instance_valid(run):
		run.queue_free()
	run = DescentRun.new()
	_connect_descent_run()
	run.prepare_floor()
	add_child(run)
	run.player = player
	descent_route = DescentRoute.build(_level_seed(run.theme()), run.theme())
	print("Descent floor 1 target %s wall %d, %d edges" % [
		descent_route.target, descent_route.target_wall,
		descent_route.graph_distance])
	var spawn := _safe_arrival(run.theme(), Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(run.theme(), spawn, false)
	player.grab_look()
	player.set_process_unhandled_input(true)
	_begin_descent_floor()


func _leave_descent() -> void:
	if _switching:
		return
	if is_instance_valid(_descent_summary):
		_descent_summary.queue_free()
	_descent_summary = null
	if run != null and run.blackout:
		_on_descent_blackout(false)
	if is_instance_valid(run):
		run.queue_free()
	run = null
	descent = false
	descent_route = null
	if is_instance_valid(_descent_hud):
		_descent_hud.queue_free()
	_descent_hud = null
	_saved_pos.clear()
	player.allow_sprint = true
	_events.descent_mode = false
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	_figures.interval_scale = 1.0
	_set_mode_hint()
	_set_post_noise(1.0)
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_saved_pos.clear()
	_build_title()


func terminal_activity(page: int) -> void:
	if _events != null:
		_events.terminal_response(page)


func door_activity() -> void:
	if _events != null:
		_events.door_response()


## Airport gate cells seal a 2.2m apron strip behind curtain glass along
## their anchor wall. If a fixed arrival offset would land inside that strip
## — an inescapable pocket — mirror it across the cell.
func _safe_arrival(level: int, cellv: Vector2i, base: Vector3) -> Vector3:
	var pos := Vector3(cellv.x * 12.0 + base.x, 0.15, cellv.y * 12.0 + base.z)
	# The first school room is a classroom. Its desks rotate to face whichever
	# solid wall owns the board, so a fixed corner can become the back row. Land
	# in the clear teaching aisle between the first row and the teacher's desk.
	if level == 6 and cellv == Vector2i.ZERO:
		var ws6 := _level_seed(6)
		var root := WorldGen.room_id(ws6, cellv)
		var centre := WorldGen.room_centre(ws6, root)
		var front := WorldGen.anchor_wall(ws6, root, 72)
		var facing := Vector2.ZERO
		match front:
			0: facing = Vector2(1.0, 0.0)
			1: facing = Vector2(-1.0, 0.0)
			2: facing = Vector2(0.0, 1.0)
			_: facing = Vector2(0.0, -1.0)
		# Bias into the wide perimeter aisle as well. At the centreline, walking
		# away from the teacher immediately meets the first student desk; here
		# every initial heading has room to resolve before reaching furniture.
		var side := Vector2(facing.y, -facing.x)
		return Vector3(centre.x + facing.x * 2.2 + side.x * 3.0, 0.15,
			centre.y + facing.y * 2.2 + side.y * 3.0)
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
	if not descent:
		_saved_pos[active_level] = player.position
	if via_portal:
		_warp.play()
	else:
		_ding.play()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16 if via_portal else 0.3)
	await tw.finished
	# Detach the outgoing floor immediately. queue_free() alone can leave its
	# collision bodies registered until the end of a busy frame; if the landing
	# probe runs during that overlap, geometry from two floors can make every
	# otherwise-safe candidate appear blocked (seen returning to the school at
	# seed 1760336105, cell -1,0).
	var old_level := level_root
	if is_instance_valid(_pursuer):
		_pursuer.queue_free()
	_pursuer = null
	remove_child(old_level)
	old_level.queue_free()
	_figures.despawn()
	_whispers.stop()
	_heart.reset()
	_switch_music(level)
	active_level = level
	# Let the physics server unregister every outgoing collider before any
	# destination body is created.
	await get_tree().physics_frame
	_build_level(level, pos)
	_events.set_level(level_root)
	player.world_seed = _level_seed(level)
	player.level_theme = level
	await get_tree().physics_frame
	var cellv := Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))
	var safe := ArrivalSafety.find_safe(get_world_3d(), pos, cellv, [player.get_rid()])
	if safe == Vector3.INF:
		push_warning("No audited arrival candidate in theme %d cell %s; using requested position" % [level, cellv])
		safe = pos
	player.teleport(safe)
	we.environment = _build_env(level)
	ambience.queue_free()
	ambience = Ambience.new(level)
	add_child(ambience)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.45 if via_portal else 0.5)
	await tw2.finished
	_switching = false


func _settle_initial_arrival() -> void:
	await get_tree().physics_frame
	if player == null or not is_instance_valid(player):
		return
	var pos := player.global_position
	var cellv := Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))
	var safe := ArrivalSafety.find_safe(get_world_3d(), pos, cellv, [player.get_rid()])
	if safe != Vector3.INF and safe.distance_to(pos) > 0.02:
		player.teleport(safe)


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
func _music_track_for(level: int) -> String:
	if descent and run != null and run.floor_idx >= DescentRun.ORDER.size() - 2:
		return DESCENT_LATE_TRACK
	return MUSIC_TRACKS.get(level, "")


func _switch_music(level: int) -> void:
	var target := _music_track_for(level)
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


## With the CRT on, render a 480-line widescreen source. At a 16:9 viewport the
## uniform 3D scale produces roughly 853x480 before the CRT pass resamples it
## onto a 720x480 anamorphic signal grid — the way a widescreen 480i source uses
## non-square pixels. The shader alternates its two 240-line fields. With the
## tube off the world returns to full native resolution.
func _apply_scaling() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if _crt:
		vp.scaling_3d_scale = clampf(480.0 / float(vp.size.y), 0.05, 1.0)
	else:
		vp.scaling_3d_scale = 1.0
	_apply_hud_scaling()


## Keep captions physically legible when the window is larger than 720p.
## The 3D world can deliberately become low-resolution; the HUD must not.
func _apply_hud_scaling() -> void:
	if _hint == null:
		return
	var viewport_size := Vector2(get_viewport().size)
	var scale := clampf(viewport_size.y / 720.0, 1.0, 1.8)
	_hint.position = Vector2(18.0, 14.0) * scale
	_hint.add_theme_font_size_override("font_size", roundi(15.0 * minf(scale, 1.5)))
	_hint.add_theme_constant_override("outline_size", roundi(2.0 * scale))

	_interact_panel.custom_minimum_size = Vector2(520.0, 54.0) * scale
	_interact_panel.position = Vector2(
		(viewport_size.x - _interact_panel.custom_minimum_size.x) * 0.5,
		viewport_size.y - 100.0 * scale)
	_interact_hint.add_theme_font_size_override("font_size", roundi(24.0 * scale))
	_interact_hint.add_theme_constant_override("outline_size", roundi(2.0 * scale))

	_event_panel.custom_minimum_size = Vector2(640.0, 60.0) * scale
	_event_panel.position = Vector2(
		(viewport_size.x - _event_panel.custom_minimum_size.x) * 0.5,
		viewport_size.y * 0.5 + 150.0 * scale)
	_event_hint.add_theme_font_size_override("font_size", roundi(28.0 * scale))
	_event_hint.add_theme_constant_override("outline_size", roundi(2.0 * scale))

	for style in [_interact_style, _event_style]:
		style.content_margin_left = 18.0 * scale
		style.content_margin_right = 18.0 * scale
		style.content_margin_top = 9.0 * scale
		style.content_margin_bottom = 9.0 * scale
		style.corner_radius_top_left = roundi(7.0 * scale)
		style.corner_radius_top_right = roundi(7.0 * scale)
		style.corner_radius_bottom_left = roundi(7.0 * scale)
		style.corner_radius_bottom_right = roundi(7.0 * scale)


## Shared "Hall" bus: every spatial emitter routes through a soft reverb so
## sounds feel like they happen inside the building.
func _setup_audio_bus() -> void:
	if AudioServer.get_bus_index("Hall") >= 0:
		return
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

	if theme == 7:
		# A 1980s mall after closing. The sodium warmth belongs to the
		# maintenance FIXTURES, not the air: ambient and fog stay near-neutral
		# so white plaster reads white and the lamps read orange against it —
		# a fully saturated ambient painted every surface the same rust.
		env.background_color = Color(0.010, 0.010, 0.011)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.59, 0.54)
		env.ambient_light_energy = 0.30
		env.tonemap_exposure = 1.24
		env.sdfgi_energy = 1.22
		env.glow_enabled = true
		env.glow_intensity = 0.44
		env.glow_bloom = 0.035
		env.fog_light_color = Color(0.105, 0.095, 0.080)
		env.fog_density = 0.0035
		env.volumetric_fog_density = 0.0015
		env.volumetric_fog_albedo = Color(0.72, 0.66, 0.55)
		env.volumetric_fog_length = 54.0
		env.ssao_radius = 1.45
		env.ssao_intensity = 1.35
		return env
	if theme == 8:
		# Cold salt-eaten concrete and green institutional lamps. Dark at the
		# ends of blocks, but readable without forcing the flashlight on.
		env.background_color = Color(0.004, 0.006, 0.005)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.50, 0.58, 0.51)
		env.ambient_light_energy = 0.37
		env.tonemap_exposure = 1.38
		env.sdfgi_energy = 1.16
		env.glow_enabled = true
		env.glow_intensity = 0.36
		env.glow_bloom = 0.025
		env.fog_light_color = Color(0.055, 0.070, 0.060)
		env.fog_density = 0.0045
		env.volumetric_fog_density = 0.0018
		env.volumetric_fog_albedo = Color(0.52, 0.62, 0.54)
		env.volumetric_fog_length = 50.0
		env.ssao_radius = 1.65
		env.ssao_intensity = 1.65
		return env

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
		env.fog_density = 0.006
		env.volumetric_fog_density = 0.0025
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
		env.fog_density = 0.011
		env.volumetric_fog_density = 0.005
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
		env.fog_density = 0.005
		env.volumetric_fog_density = 0.002
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
		env.fog_density = 0.0045
		env.volumetric_fog_density = 0.0022
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
		env.fog_density = 0.003
		env.volumetric_fog_density = 0.0012
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
		env.fog_density = 0.009
		env.volumetric_fog_density = 0.004
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
	_set_mode_hint()
	lb.position = Vector2(18, 14)
	lb.add_theme_font_size_override("font_size", 15)
	lb.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8, 0.9))
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lb.add_theme_constant_override("shadow_offset_x", 1)
	lb.add_theme_constant_override("shadow_offset_y", 1)
	cl.add_child(lb)
	_interact_panel = PanelContainer.new()
	_interact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_panel.visible = false
	_interact_style = StyleBoxFlat.new()
	_interact_style.bg_color = Color(0.025, 0.022, 0.018, 0.78)
	_interact_style.border_color = Color(0.72, 0.53, 0.28, 0.42)
	_interact_style.set_border_width_all(1)
	_interact_panel.add_theme_stylebox_override("panel", _interact_style)
	cl.add_child(_interact_panel)
	_interact_hint = Label.new()
	_interact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_hint.add_theme_font_size_override("font_size", 19)
	_interact_hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	_interact_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_interact_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_interact_hint.add_theme_constant_override("shadow_offset_x", 2)
	_interact_hint.add_theme_constant_override("shadow_offset_y", 2)
	_interact_panel.add_child(_interact_hint)
	_event_panel = PanelContainer.new()
	_event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_panel.modulate.a = 0.0
	_event_style = StyleBoxFlat.new()
	_event_style.bg_color = Color(0.018, 0.017, 0.015, 0.76)
	_event_style.border_color = Color(0.65, 0.62, 0.54, 0.30)
	_event_style.set_border_width_all(1)
	_event_panel.add_theme_stylebox_override("panel", _event_style)
	cl.add_child(_event_panel)
	_event_hint = Label.new()
	_event_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_hint.add_theme_font_size_override("font_size", 15)
	_event_hint.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	_event_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_event_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_event_hint.add_theme_constant_override("shadow_offset_x", 2)
	_event_hint.add_theme_constant_override("shadow_offset_y", 2)
	_event_panel.add_child(_event_hint)
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
	_apply_hud_scaling()


func _on_interaction_prompt(text: String) -> void:
	if _interact_hint != null:
		_interact_hint.text = text
		_interact_panel.visible = not text.is_empty()


func _show_event_message(text: String, alert := false) -> void:
	if _event_hint == null or _event_panel == null:
		return
	_event_style.bg_color = Color(0.035, 0.012, 0.008, 0.84) if alert \
		else Color(0.018, 0.017, 0.015, 0.76)
	_event_style.border_color = Color(0.96, 0.37, 0.18, 0.72) if alert \
		else Color(0.65, 0.62, 0.54, 0.30)
	_event_hint.add_theme_color_override("font_color",
		Color(1.0, 0.72, 0.43) if alert else Color(0.96, 0.93, 0.84))
	_event_hint.text = text
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	_event_panel.modulate.a = 0.0
	_event_tween = create_tween()
	_event_tween.tween_property(_event_panel, "modulate:a", 0.96, 0.18)
	_event_tween.tween_interval(2.2)
	_event_tween.tween_property(_event_panel, "modulate:a", 0.0, 0.7)


## Screenshot-only helper for checking both caption styles without waiting for
## a random event or finding an interactable prop.
func _preview_captions() -> void:
	await get_tree().create_timer(1.0).timeout
	_show_event_message("THE POWER DIPS")
	_on_interaction_prompt("E — QUERY TERMINAL")


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
	if _hint != null:
		_hint.modulate.a = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_process_unhandled_input(false)  # no looking around yet either
	_title = TitleScreen.new()
	_title.mode_selected.connect(_on_mode_selected)
	_title.started.connect(_on_start)
	add_child(_title)
	if descent:
		_title.present_descent(true)


func _on_mode_selected(wants_descent: bool) -> void:
	if wants_descent:
		call_deferred("_prepare_descent")


func _prepare_descent() -> void:
	if descent or _descent_preparing:
		if descent and is_instance_valid(_title):
			_title.set_descent_ready()
		return
	_descent_preparing = true
	descent = true
	player.allow_sprint = false
	player.set_process_unhandled_input(false)
	_saved_pos.clear()
	run = DescentRun.new()
	_connect_descent_run()
	run.prepare_floor()
	add_child(run)
	descent_route = DescentRoute.build(_level_seed(run.theme()), run.theme())
	print("Descent floor 1 target %s wall %d, %d edges" % [
		descent_route.target, descent_route.target_wall,
		descent_route.graph_distance])
	_events.descent_mode = true
	_figures.suspended = true
	_whispers.suspended = true
	_heart.suspended = true
	_set_mode_hint()
	var spawn := _safe_arrival(run.theme(), Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(run.theme(), spawn, false)
	_descent_preparing = false
	if is_instance_valid(_title):
		_title.set_descent_ready()


func _on_start(selected_descent: bool) -> void:
	_title = null
	player.grab_look()
	player.set_process_unhandled_input(true)
	if selected_descent:
		_begin_descent_floor()
	else:
		_figures.suspended = false
		_whispers.suspended = false
		_heart.suspended = false
	_start_hint_fade()


func _set_mode_hint() -> void:
	if _hint == null:
		return
	if descent:
		_hint.text = "WASD / arrows move   ·   E interact   ·   F flashlight   ·   follow the HUD needle   ·   Q title   ·   Esc release mouse"
	else:
		_hint.text = "WASD / arrows move   ·   Shift run   ·   E interact   ·   F flashlight   ·   1-8 floors   ·   V CRT   ·   Q title   ·   Esc release mouse"


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
