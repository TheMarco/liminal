extends Node3D
## Entry point and level manager. Ten endless floors share one player:
##   1 — seedy Vegas hotel-casino            (theme 0)
##   2 — sterile Severance-style office      (theme 1)
##   3 — the yellow Backrooms corridors of the Annex (theme 2)
##   4 — an airport terminal at 3 a.m., between every flight (theme 4)
##   5 — an abandoned asylum, beds still made, straps still buckled (theme 5)
##   6 — a high school after the last bell that never rang (theme 6)
##   7 — an abandoned shopping mall with every shutter down (theme 7)
##   8 — an island prison whose cell blocks never end (theme 8)
##   9 — flooded white-tile Poolrooms (theme 9)
##   0 — the monumental concrete Monolith (theme 10)
##   - — the organic mirror-campus called the Bloom (theme 11)
## The number key is an index into WorldGen.THEMES, NOT the theme id — theme 3
## was a derelict theme park, cut, and the rest keep their original ids so every
## existing seed still generates the world it always did.
## Switching floors fades to black, rebuilds the world with that floor's theme,
## and restores your position on that floor. Physical elevators own their
## chime; menu/debug/descent transitions must never impersonate one.

@export var world_seed: int = 0

const DEFAULT_SPAWN := Vector3(6.0, 0.15, 2.0)
# Safe arrival offsets within a cell, per theme, for portal jumps. Only a hint:
# _safe_arrival() sweeps outward from here for somewhere the player actually
# fits. WorldGen.portal() can return any live theme, so every entry in
# WorldGen.THEMES needs one -- Pool Rooms was added as theme 9 without one, and
# arriving through a portal into the Poolrooms read PORTAL_ARRIVE[9] and failed
# the jump. PORTAL_ARRIVE_DEFAULT keeps the next added theme from doing it again.
#
# The y component is clearance ABOVE the destination cell's floor, matching
# ArrivalSafety.STANDING_CLEARANCE -- not an absolute world height. It reads the
# same as it always did, but _safe_arrival now adds Chunk.cell_floor_h() to it,
# which is what makes the Poolrooms' raised dry slab arrive correctly.
const PORTAL_ARRIVE_DEFAULT := Vector3(3.2, 0.15, 2.0)
const PORTAL_ARRIVE := {
	0: Vector3(3.2, 0.15, 2.0), 1: Vector3(3.2, 0.15, 2.0),
	2: Vector3(3.2, 0.15, 2.0),
	4: Vector3(3.2, 0.15, 2.0), 5: Vector3(3.2, 0.15, 2.0),
	6: Vector3(3.2, 0.15, 2.0),
	7: Vector3(3.2, 0.15, 2.0), 8: Vector3(3.2, 0.15, 2.0),
	9: Vector3(3.2, 0.15, 2.0),
	10: Vector3(3.2, 0.15, 2.0),
	11: Vector3(3.2, 0.15, 2.0),
}

## What the ambient presence systems are allowed to do right now. Only three
## combinations of {figures, whispers, heartbeat} are ever wanted, and they were
## previously spelled out three lines at a time in eleven places -- including the
## one that carries the Wander regression contract, that Wander runs with no
## hostile figures but a live soundscape. Naming the states puts that contract in
## _set_presence instead of in eleven copies that have to agree.
enum Presence {
	SILENT,   ## title card, rule card, return prompt, death, end of a run
	WANDER,   ## the pressure-free browser: ambience live, no hostile figures
	DESCENT,  ## a run in progress: everything live
}

## Command line, parsed once in _ready. Dev-flag consumers read it from here
## rather than each re-parsing OS.get_cmdline_user_args().
var opts := CliOptions.new()
var player: Player
var level_root: Node3D
var cm: ChunkManager
var we: WorldEnvironment
var ambience: Ambience
var active_level := 0
var _saved_pos := {}
var _switching := false
var _fade: ColorRect
var _warp: AudioStreamPlayer
var _post: ColorRect
var _crt := true
enum PostMode { CRT, FOUND_FOOTAGE }
var _post_mode := PostMode.CRT
var _crt_material: ShaderMaterial
var _found_footage_material: ShaderMaterial
var _post_signal_corruption := 0.0
var _post_minor_at := 0.0
var _post_major_at := 0.0
var _post_glitch_until := 0.0
var _post_damage_until := 0.0
var _post_glitch_active := false
var _post_glitch_major := false
var _post_glitch_jitter := 0.006
var _post_glitch_tracking := 0.18
var _post_glitch_aberration := 0.0035
var _post_glitch_noise := 0.10
var _post_damage_intensity := 0.0
var _bench := false
var _bench_t := 0.0
var _bench_frames := 0
var _bench_worst := 0.0
var _bench_slow := 0
var _bench_prev := Vector3.ZERO
var _bench_steps: Array[float] = []
var _figures: ShadowFigures
var _passers: PassingShadows
var _corner_apparitions: CornerApparitions
var _whispers: Whispers
var _director: HorrorDirector
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
var _battery_panel: PanelContainer
var _battery_bar: ProgressBar
var _charging_panel: PanelContainer
var _charging_bar: ProgressBar
var _events: EnvironmentEvents
var descent := false
var run: DescentRun
var descent_route: DescentRoute
var _descent_progress: DescentProgress
var _intro_state: IntroPlaybackState
var _descent_intro: DescentIntro
var _progress_enabled := false
var _descent_preparing := false
var _pending_new_descent_intro := false
var _attention_override := -1.0
var _blackout_ambient := -1.0
var _blackout_locate_cue := 0
var _pending_shortcut_reveal := false
## Environmental bleed presentation: captured baselines for this floor's fog
## and the next floor's targets, plus the rising next-floor room tone.
var _bleed_base_fog := Color.BLACK
var _bleed_base_density := 0.0
var _bleed_next_fog := Color.BLACK
var _bleed_next_density := 0.0
var _bleed_captured := false
var _bleed_bed: AudioStreamPlayer
## Seconds of torch handed back per burned figure, and how close one has to get
## before the game says out loud, once, what the torch is for.
const BURN_REFUND := 0.25
const TORCH_HINT_D := 6.0
var _torch_hint_shown := false
var _title_music := false
## What the last `_switch_music` was aiming at. The swap happens behind a 0.6s
## fade, so the live stream lags the intent — guarding on the stream instead
## lets a second call stack another fade tween on the same property.
var _music_target := ""
var _descent_summary: DescentSummary
var _descent_hud: DescentHUD
var _return_prompt: ReturnPrompt

# One mood track per floor.
const MUSIC_TRACKS := {
	0: "res://music/lim1.mp3", 1: "res://music/lim2.mp3",
	4: "res://music/lim5.mp3", 5: "res://music/lim6.mp3",
	6: "res://music/lim4.mp3",
	7: "res://music/lim7.mp3", 8: "res://music/lim8.mp3",
	9: "res://music/lim3.mp3",
}
# A distinct late-run cue gives Descent's final two floors an audible rise in
# pressure without changing Wander mode's established per-level soundtrack.
const DESCENT_LATE_TRACK := "res://music/lim9.mp3"
const MUSIC_DB := -14.0
## The title has its own track, and nothing else. The world behind the card is
## already built and already running, but it is not meant to be heard yet:
## room tone, slot banks, fluorescent hum and the odd distant knock under a
## title card read as a mix that has not been mastered, not as atmosphere.
const TITLE_MUSIC := "res://music/title.mp3"


func _ready() -> void:
	randomize()
	opts = CliOptions.parse()
	# Command-line starts are isolated QA/dev worlds. Only a normal title-screen
	# session may read or write the player's real Descent checkpoint.
	_progress_enabled = not opts.descent and not opts.skips_title() \
		and not opts.quick_exit()
	_descent_progress = DescentProgress.new()
	_intro_state = IntroPlaybackState.new()
	var spawn := opts.spawn if opts.spawn_given else DEFAULT_SPAWN
	var pos_given := opts.spawn_given
	var yaw := opts.yaw
	var yaw_given := opts.yaw_given
	if opts.world_seed != 0:
		world_seed = opts.world_seed
	# --level takes a THEME id, not a key index, so old commands still work
	if opts.active_level != 0:
		active_level = opts.active_level
	descent = descent or opts.descent
	if opts.found_footage:
		_post_mode = PostMode.FOUND_FOOTAGE
	if opts.attention >= 0.0:
		_attention_override = opts.attention
	if world_seed == 0:
		world_seed = (randi() & 0x7FFFFFFF) | 1
	if descent:
		run = DescentRun.new()
		# The seed varies rooms and routes inside the fixed story order.
		run.world_seed = world_seed
		if opts.descent_floor > 0:
			run.floor_idx = clampi(opts.descent_floor - 1, 0,
				DescentRun.FLOOR_COUNT - 1)
		active_level = run.theme()
		if _attention_override >= 0.0:
			run.attention = _attention_override
		_connect_descent_run()
		run.prepare_floor()
		add_child(run)
		descent_route = _create_descent_route(active_level, run.floor_idx)
		_print_descent_route()
	if not pos_given:
		if descent:
			var arrival := _descent_arrival(active_level)
			spawn = arrival["position"]
			if not yaw_given:
				yaw = float(arrival["yaw"])
		else:
			spawn = _safe_arrival(active_level, Vector2i.ZERO, DEFAULT_SPAWN)
	print("It wants you to stay — seed %d" % world_seed)
	# Audits and screenshot helpers intentionally quit after a few seconds;
	# don't leave background resource workers alive during their forced exit.
	if not opts.quick_exit():
		Chunk.request_prop_preloads()
	add_to_group("portal_listener")
	add_to_group("level_manager")
	add_to_group("descent_listener")
	if opts.notaa:
		get_viewport().use_taa = false
	# dev: start with the tube off, so screenshots show the raw full-res render
	if opts.nocrt:
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
	player.water_y = _water_level_for(active_level)
	# Sprint is legal in Descent since 2026-08-05 — it feeds attention instead
	# of being switched off. The run charges it; the controller stays ignorant.
	player.allow_sprint = true
	if descent and run != null:
		run.player = player
	_build_level(active_level, spawn)

	player.position = spawn
	player.rotation.y = yaw
	add_child(player)
	# Live tuning panel for the Poolrooms. Dragging a slider beats editing a
	# constant, rebuilding and guessing from a screenshot.
	if opts.tune:
		add_child(PoolTuner.new())
	if opts.flashlight:
		player.set_flashlight(true)

	if opts.spin:
		player.dev_spin = true
	if opts.audit:
		_audit_partitions()
		return
	if opts.chunktime:
		ChunkManager._dev_timing = true
	if opts.bench:
		# walk forward while turning — the exact motion that looks choppy
		player.dev_spin = true
		player.dev_walk = true
		_bench = true
	ambience = Ambience.new(active_level)
	add_child(ambience)
	_director = HorrorDirector.new()
	add_child(_director)
	if run != null:
		run.horror_director = _director
	var oneshots := OneShots.new()
	oneshots.player = player
	oneshots.horror_director = _director
	add_child(oneshots)
	_whispers = Whispers.new()
	_whispers.player = player
	_whispers.horror_director = _director
	_whispers.dev = opts.whispers
	add_child(_whispers)
	_figures = ShadowFigures.new()
	_figures.player = player
	_figures.horror_director = _director
	_figures.topology = descent_route.topology \
		if descent_route != null else null
	_passers = PassingShadows.new()
	_passers.player = player
	_passers.horror_director = _director
	_passers.topology = descent_route.topology \
		if descent_route != null else null
	_passers.dev_force = opts.passer
	add_child(_passers)
	_corner_apparitions = CornerApparitions.new()
	_corner_apparitions.player = player
	_corner_apparitions.horror_director = _director
	_corner_apparitions.dev_force = opts.passer
	add_child(_corner_apparitions)
	_figures.dev_haunt = opts.haunt
	_figures.dev_haunt_at = opts.haunt_at
	_figures.dev_haunt_at_given = opts.haunt_at_given
	_figures.dev_haunt_variant = opts.haunt_variant
	_figures.reached_player.connect(_on_figure_reached_player)
	add_child(_figures)
	# Frights raise the pulse; it bleeds away on its own. Wired after the
	# figures exist so it can sample how close the nearest one is.
	_heart = Heartbeat.new()
	_heart.figures = _figures
	_heart.dev = opts.heartbeat
	add_child(_heart)
	_passers.revealed.connect(
		func():
			if _corner_apparitions != null:
				_corner_apparitions.defer_for(
					CornerApparitions.SHARED_QUIET_SECONDS))
	_corner_apparitions.revealed.connect(
		func(_texture_key: String):
			_heart.bump(Heartbeat.BUMP_SEEN)
			_camera_damage_hit(0.32)
			if _passers != null:
				_passers.defer_for(CornerApparitions.SHARED_QUIET_SECONDS))
	# Nothing mutters, haunts or races behind a title or a rule card. The
	# screenshot and --nologo starts release this below.
	_set_presence(Presence.SILENT)
	_figures.seen_by_player.connect(
		func(): _heart.bump(Heartbeat.BUMP_SEEN))
	_figures.burned_away.connect(
		func():
			_heart.bump(Heartbeat.BUMP_BURNED)
			player.add_flashlight_charge(BURN_REFUND))
	_events = EnvironmentEvents.new()
	_events.player = player
	_events.horror_director = _director
	_events.descent_mode = descent
	_events.set_level(level_root)
	add_child(_events)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -50.0
	add_child(_music)
	# Decide before the first note: `_build_title` runs several lines later, and
	# starting a floor track only to crossfade it out is audible.
	_title_music = _will_show_title()
	if _title_music:
		_set_world_audio(false)
	_switch_music(active_level)
	_build_ui()
	player.interaction_prompt_changed.connect(_on_interaction_prompt)
	_events.message.connect(_show_event_message)
	if opts.caption_preview:
		_preview_captions()
	_build_title()
	if _title == null:
		if descent:
			_begin_descent_floor()
		else:
			# Wander is the pressure-free level browser: keep hostile figures
			# disabled while leaving the ambient soundscape active.
			_set_presence(Presence.WANDER)
	_maybe_screenshot()
	call_deferred("_settle_initial_arrival")


## The Wander contract lives here: hostile figures run only during a Descent,
## while whispers and the heartbeat are silenced only behind a card. Anything
## that changes what the player can hear or meet should change state here rather
## than assign the three flags directly.
func _set_presence(state: Presence) -> void:
	if _director != null:
		_director.enabled = state == Presence.DESCENT
		var presentation_hold := state == Presence.SILENT
		if state == Presence.DESCENT and run != null:
			presentation_hold = run.watching or run.arrival_grace > 0.0
		_director.set_scripted_hold(presentation_hold)
	_figures.suspended = state != Presence.DESCENT
	if _passers != null:
		_passers.suspended = state != Presence.DESCENT
	if _corner_apparitions != null:
		_corner_apparitions.suspended = state != Presence.DESCENT
	_whispers.suspended = state == Presence.SILENT
	_heart.suspended = state == Presence.SILENT


func _level_seed(level: int) -> int:
	return WorldGen.level_seed(world_seed, level)


func _create_descent_route(level: int, floor_idx: int) -> DescentRoute:
	_pending_shortcut_reveal = false
	var route := DescentRoute.build(_level_seed(level), level, floor_idx)
	route.set_topology(DescentTopology.new(_level_seed(level), level))
	if run != null:
		run.set_route(route)
	return route


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
			descent_route = _create_descent_route(level, run.floor_idx)
		cm.descent_floor_idx = run.floor_idx
		cm.descent_route = descent_route
		cm.descent_topology = descent_route.topology
		cm.descent_base_seed = world_seed
		run.target_cell = descent_route.target
		cm.blackout = run.blackout
		cm.anomalies = run.anomalies
		cm.descent_arrival_used = run.arrival_used
		cm.descent_lift_called = run.lift_called
		cm.descent_lift_wait = run.lift_wait_left
		cm.descent_lift_open = run.lift_open
		cm.descent_broken_station_tried = run.broken_station_tried
	if _passers != null:
		_passers.configure(_level_seed(level), level)
		_passers.run = run
		_passers.topology = descent_route.topology \
			if descent_route != null else null
	if _figures != null:
		_figures.topology = descent_route.topology \
			if descent_route != null else null
		# Gates the tuned archetypes' debuts; the roster grows as the run
		# deepens instead of only spawning faster.
		_figures.floor_idx = run.floor_idx if descent and run != null else 99
		# Attention rarely changes right at arrival, so the theme's spawn
		# pacing is applied here too rather than waiting for the next
		# attention_changed to recompute it.
		if descent and run != null:
			_figures.interval_scale = lerpf(1.0, 0.35, run.threat()) \
				* run.figure_interval_scale()
	if _corner_apparitions != null:
		_corner_apparitions.configure(_level_seed(level), level)
		_corner_apparitions.run = run
	level_root.add_child(cm)
	cm.warm_up(Vector2i(floori(around.x / ChunkManager.CELL), floori(around.z / ChunkManager.CELL)))


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_descent_intro):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q and _title == null \
				and not _switching and not is_instance_valid(_return_prompt) \
				and not is_instance_valid(_descent_summary):
			get_viewport().set_input_as_handled()
			_show_return_prompt()
			return
		# keys 1..N select the Nth live theme — no gap where the park used to be
		var idx: int = event.physical_keycode - KEY_1
		if not descent and event.physical_keycode == KEY_0:
			_switch_level(10)
		elif not descent and (event.physical_keycode == KEY_MINUS \
				or event.physical_keycode == KEY_KP_SUBTRACT):
			_switch_level(11)
		elif not descent and idx >= 0 and idx < mini(9, WorldGen.THEMES.size()):
			_switch_level(WorldGen.THEMES[idx])
		elif event.physical_keycode == KEY_V:
			_crt = not _crt
			_post.visible = _crt
			_apply_scaling()
		elif event.physical_keycode == KEY_B:
			_toggle_post_mode()


func _show_return_prompt() -> void:
	_return_prompt = ReturnPrompt.new()
	_return_prompt.descent = descent
	_return_prompt.confirmed.connect(_confirm_return_to_title)
	_return_prompt.cancelled.connect(_cancel_return_to_title)
	add_child(_return_prompt)
	player.velocity = Vector3.ZERO
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_presence(Presence.SILENT)
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
		_set_presence(Presence.DESCENT)
		if is_instance_valid(_descent_hud):
			_descent_hud.set_active(true)
	else:
		_set_presence(Presence.WANDER)


func _confirm_return_to_title() -> void:
	if is_instance_valid(_return_prompt):
		_return_prompt.queue_free()
	_return_prompt = null
	player.set_flashlight(false)
	if descent:
		await _leave_descent()
		return
	_set_presence(Presence.SILENT)
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
	_jump_to(dest, _safe_arrival(dest, cellv,
		PORTAL_ARRIVE.get(dest, PORTAL_ARRIVE_DEFAULT)), true)


## Called by physical lift panels built into selected generated rooms.
func use_elevator(dest: int) -> void:
	if descent or _switching or dest == active_level or not WorldGen.THEMES.has(dest):
		return
	_events.elevator_response()
	_show_event_message("FLOOR %d" % (WorldGen.THEMES.find(dest) + 1))
	_switch_level(dest)


## Where a Descent floor begins: standing inside the sealed arrival car, facing
## its shut doors. `exact` tells `_jump_to` to trust the point rather than run
## ArrivalSafety over it — a 2.2m car can never satisfy the escape-direction
## test, and the interior is authored clear by construction.
func _descent_arrival(theme: int) -> Dictionary:
	if descent_route != null and descent_route.origin_wall >= 0:
		var floor_y := Chunk.cell_floor_h(_level_seed(theme),
			descent_route.origin, theme)
		var car := Chunk.car_interior_point(descent_route.origin,
			descent_route.origin_wall, floor_y)
		car["exact"] = true
		return car
	var cellv := descent_route.origin if descent_route != null else Vector2i.ZERO
	return {
		"position": _safe_arrival(theme, cellv, DEFAULT_SPAWN),
		"yaw": PI,
		"exact": false,
	}


func _print_descent_route() -> void:
	if descent_route == null or run == null:
		return
	print("Descent floor %d — arrive %s wall %d → target %s wall %d, %d edges (%.0fm), band %d-%d" % [
		run.floor_idx + 1, descent_route.origin, descent_route.origin_wall,
		descent_route.target, descent_route.target_wall,
		descent_route.graph_distance, descent_route.walk_metres(),
		descent_route.min_dist, descent_route.max_dist])


## Called by the objective chunk when the plate is pressed. The run owns the
## clock so the wait survives that room streaming out behind the player.
func descent_lift_called(seconds: float) -> void:
	if not descent or run == null or run.ended:
		return
	run.call_lift()
	run.lift_wait_left = maxf(run.lift_wait_left, seconds)
	_sync_descent_chunk_state()
	_show_event_message("LIFT CALLED")


## The ritual television has taken (or released) the player's view. The run
## holds the rules passive for exactly that long.
func descent_tape_watch(on: bool) -> void:
	if run != null:
		run.watching = on
	if _director != null:
		_director.set_scripted_hold(on)
	if on and _whispers != null:
		_whispers.stop()
	# The recording owns the screen: no needle over the footage, and nothing
	# in the building moves until it lets go — the ambient figures are held by
	# the run's passive state.
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(not on)
	# The tape also owns the soundtrack: score and room tone hold their
	# breath for it and pick up where they left off.
	if _music != null:
		_music.stream_paused = on
	if is_instance_valid(_bleed_bed):
		_bleed_bed.stream_paused = on
	_set_ambience_paused(on)


## A television claims its recording only when the player presses play. This
## keeps an endless streamed world from consuming the no-repeat deck merely by
## building distant chunks. Objective sets request the long-form pool; optional
## discoveries request the short-form pool.
func descent_tape_for(setup_key: String, long_form: bool) -> String:
	if not descent or run == null or run.ended:
		return ""
	return run.tape_for_setup(setup_key, long_form)


func descent_setup_tape_completed(setup_key: String) -> bool:
	return run != null and run.setup_tape_completed(setup_key)


## An optional recording is a detour with no obligation attached, so it has to
## pay for itself or a player who knows the loop will walk past every one. What
## it buys is the honest room count for a few seconds — never a direction, so
## finding the lift remains the floor. The objective set stands in the lift's
## own room and would be paying for an answer the player is already standing on.
func descent_setup_tape_finished(setup_key: String, objective: bool) -> void:
	if not descent or run == null or run.ended:
		return
	run.mark_setup_tape_completed(setup_key)
	if objective:
		descent_tape_finished()
		return
	if is_instance_valid(_descent_hud):
		_descent_hud.grant_true_distance()
		if _descent_hud.showing_true_distance():
			_show_event_message("THE TAPE COUNTS THE ROOMS AHEAD")


func _set_ambience_paused(paused: bool) -> void:
	if ambience == null or not is_instance_valid(ambience):
		return
	var stack: Array[Node] = [ambience]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stream_paused = paused
		elif node is AudioStreamPlayer3D:
			(node as AudioStreamPlayer3D).stream_paused = paused


## The floor's tape ran to its end with the player in the room. One of the
## lift's three demands is now met for good — the tape never rewinds itself.
func descent_tape_finished() -> void:
	if not descent or run == null or run.ended:
		return
	run.mark_tape_watched()
	_sync_descent_chunk_state()
	_show_event_message("THE TAPE ENDS")
	# Finishing the tape costs something: one directed arrival, behind the
	# player, a beat after the camera has handed the room back. The countdown
	# only runs once the passive hold releases, so it never lands under the
	# dolly-back.
	if _figures != null:
		_figures.force_encounter(2.2)


## The run's one dead charging station just collapsed under the player's
## press. Caption the death, record the spring so a rebuilt chunk stays
## sprung, and send what the dark owes a player standing torchless beside a
## machine that lied to them.
func descent_station_died() -> void:
	if not descent or run == null or run.ended:
		return
	run.broken_station_tried = true
	_sync_descent_chunk_state()
	_show_event_message("THE STATION IS DEAD", true)
	if _figures != null:
		_figures.force_encounter(1.4)


## The car turned an unready player away at the threshold.
func descent_commit_refused(reason: String) -> void:
	if not descent:
		return
	_show_event_message(reason, true)
	_camera_damage_hit(0.25)


func _on_descent_lift_cancelled() -> void:
	if not descent or cm == null or descent_route == null:
		return
	_sync_descent_chunk_state()
	var chunk: Chunk = cm.chunks.get(descent_route.target)
	if chunk != null:
		chunk.reset_descent_lift()
	_show_event_message("THE CALL DIED — THE ROOM WAS LEFT", true)


func _on_descent_lift_arrived() -> void:
	if not descent or run == null or run.ended or cm == null \
			or descent_route == null:
		return
	_sync_descent_chunk_state()
	_show_event_message("THE LIFT IS HERE")
	var chunk := cm.chunk_at(descent_route.target)
	if chunk != null and chunk.has_descent_lift():
		chunk.open_descent_lift()
	else:
		# Out of streaming range: it still arrived, and it will be standing open
		# when the player walks back into the room.
		_play_descent_cue(SoundBank.ding(), -20.0)


func descent_ride_rumble(amount: float) -> void:
	if player != null and is_instance_valid(player):
		player.set_rumble(amount)


func descent_arrival_spent() -> void:
	# Freeing the outgoing floor makes its arrival area report the player as
	# having left it. That fires after `prepare_floor()` has already reset the
	# next floor's state, so without this gate the car the player is about to be
	# teleported into would be built shut and dead around them.
	if descent and run != null and not _switching:
		run.arrival_used = true
		_sync_descent_chunk_state()


func _sync_descent_chunk_state() -> void:
	if cm == null or run == null:
		return
	cm.descent_arrival_used = run.arrival_used
	cm.descent_lift_called = run.lift_called
	cm.descent_lift_wait = run.lift_wait_left
	cm.descent_lift_open = run.lift_open
	cm.descent_tape_watched = run.tape_watched
	cm.descent_broken_station_tried = run.broken_station_tried


## Opens the car the player rode in on, a beat after the floor goes live. Not
## awaited by its caller: the arrival grace is long enough to cover it, and the
## audits' synchronous startup path must not block on a timer.
func _reveal_arrival() -> void:
	if not descent or run == null or run.ended or cm == null \
			or descent_route == null:
		return
	var floor_name: String = run.floor_name()
	if descent_route.origin_wall < 0:
		_show_event_message("FLOOR %d — %s" % [
			run.floor_idx + 1, floor_name.to_upper()])
		return
	player.set_rumble(0.22)
	var settle := create_tween()
	settle.tween_method(func(v: float): player.set_rumble(v), 0.22, 0.0, 1.1)
	await get_tree().create_timer(0.85).timeout
	if not descent or run == null or run.ended or cm == null:
		return
	var chunk := cm.chunk_at(descent_route.origin)
	if chunk != null and chunk.has_descent_arrival():
		_play_descent_cue(SoundBank.ding(), -8.0)
		chunk.open_descent_arrival()
	_show_event_message("FLOOR %d — %s" % [
		run.floor_idx + 1, floor_name.to_upper()])


func _connect_descent_run() -> void:
	run.world_seed = world_seed
	if _director != null:
		run.horror_director = _director
	run.pinned_attention = _attention_override
	if _progress_enabled and _descent_progress.has_checkpoint() \
			and _descent_progress.run_seed == world_seed:
		run.restore_short_tape_cycle(_descent_progress.seen_short_tapes,
			_descent_progress.completed_beginning_tapes)
	if player != null:
		run.player = player
	run.floor_reached.connect(_on_descent_floor_reached)
	run.short_tape_claimed.connect(_on_short_tape_claimed)
	run.short_tape_cycle_restarted.connect(_on_short_tape_cycle_restarted)
	run.beginning_tape_completed.connect(_on_beginning_tape_completed)
	run.attention_changed.connect(_on_descent_attention)
	run.violation.connect(_on_descent_violation)
	run.blackout_changed.connect(_on_descent_blackout)
	run.passive_changed.connect(_on_descent_passive)
	run.anomaly_requested.connect(_on_descent_anomaly)
	run.blackout_doorway_requested.connect(_on_blackout_doorway)
	run.lift_arrived.connect(_on_descent_lift_arrived)
	run.lift_cancelled.connect(_on_descent_lift_cancelled)
	run.blackout_locate_changed.connect(_on_blackout_locate)
	run.blackout_ambush.connect(_on_blackout_ambush)
	run.run_ended.connect(_on_descent_ended)


func _on_descent_floor_reached(floor_idx: int) -> void:
	if _progress_enabled:
		_descent_progress.reach_floor(world_seed, floor_idx)


func _on_short_tape_claimed(path: String) -> void:
	if _progress_enabled and _descent_progress.run_seed == world_seed:
		_descent_progress.record_short_tape(path)


func _on_short_tape_cycle_restarted() -> void:
	if _progress_enabled and _descent_progress.run_seed == world_seed:
		_descent_progress.reset_short_tape_cycle()


func _on_beginning_tape_completed(completed_count: int) -> void:
	if _progress_enabled and _descent_progress.run_seed == world_seed:
		_descent_progress.record_beginning_tapes_completed(completed_count)


func _begin_descent_floor() -> void:
	if not descent or run == null or run.ended:
		return
	if _director != null:
		_director.reset_floor()
		_director.enabled = true
		_director.set_pressure(run.threat())
	run.player = player
	run.start_floor()
	player.allow_sprint = false
	_set_presence(Presence.DESCENT)
	_ensure_descent_hud()
	_descent_hud.set_active(true)
	_on_descent_attention(run.attention)
	_sync_descent_chunk_state()
	_prepare_bleed()
	_reveal_arrival()
	if opts.play_tape:
		_dev_play_tape()


## Screenshot-run helper for `--play-tape`: walk into the objective room and
## press play without a human at the keys.
func _dev_play_tape() -> void:
	await get_tree().create_timer(0.4).timeout
	if cm == null or descent_route == null:
		return
	var chunk: Chunk = cm.chunks.get(descent_route.target)
	if chunk == null:
		return
	var ritual := chunk.get_node_or_null("DescentRitual")
	if ritual != null:
		ritual._on_activated(player)


## Capture what this floor looks and sounds like clean, and what the next one
## will pull it toward. The ratchet in _process does the rest.
func _prepare_bleed() -> void:
	_bleed_captured = false
	if is_instance_valid(_bleed_bed):
		_bleed_bed.queue_free()
	_bleed_bed = null
	if run == null or run.is_last_floor():
		return
	var next_theme: int = run.order()[run.floor_idx + 1]
	if cm != null:
		cm.bleed_theme = next_theme
		cm.bleed = run.bleed
	var env := we.environment
	if env != null:
		_bleed_base_fog = env.fog_light_color
		_bleed_base_density = env.fog_density
		var next_env := _build_env(next_theme)
		_bleed_next_fog = next_env.fog_light_color
		_bleed_next_density = next_env.fog_density
		_bleed_captured = true
	if Sfx.has_bed(next_theme):
		var bed: Array = Sfx.bed(next_theme)
		_bleed_bed = AudioStreamPlayer.new()
		_bleed_bed.stream = bed[0]
		_bleed_bed.volume_db = -60.0
		add_child(_bleed_bed)
		_bleed_bed.play()


func _update_bleed() -> void:
	if not descent or run == null or run.ended or run.suspended \
			or cm == null or descent_route == null or player == null:
		return
	if run.is_last_floor():
		return
	var pc := Vector2i(floori(player.position.x / 12.0),
		floori(player.position.z / 12.0))
	var d := maxi(absi(pc.x - descent_route.target.x),
		absi(pc.y - descent_route.target.y))
	var closeness := 1.0 - clampf((float(d) - 1.0) / 7.0, 0.0, 1.0)
	if closeness > run.bleed:
		run.bleed = closeness
	cm.bleed = run.bleed
	if run.bleed <= 0.0:
		return
	if _bleed_captured and we.environment != null:
		var mixv := run.bleed * 0.65
		we.environment.fog_light_color = _bleed_base_fog.lerp(
			_bleed_next_fog, mixv)
		we.environment.fog_density = lerpf(_bleed_base_density,
			_bleed_next_density, run.bleed * 0.5)
	if is_instance_valid(_bleed_bed):
		_bleed_bed.volume_db = lerpf(-58.0, -30.0, run.bleed)


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
	descent_route = _create_descent_route(next_theme, run.floor_idx)
	_print_descent_route()
	var arrival := _descent_arrival(next_theme)
	await _jump_to(next_theme, arrival["position"], false,
		bool(arrival["exact"]), float(arrival["yaw"]))
	_begin_descent_floor()


func _on_descent_exit() -> void:
	if descent and run != null and run.is_last_floor() and not run.ended:
		run.finish(true)


## One of them reached you during Descent. Wander deliberately keeps the figure
## system suspended; the guard below also makes a stale signal harmless.
##
## Nothing here is recoverable on purpose. The flashlight is the answer, it is
## on a ten-second cell, and letting one close the distance while you decide is
## the mistake being punished.
func _on_figure_reached_player() -> void:
	if not descent:
		_figures.despawn()
		return
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
	pl.bus = SoundBank.HALL_BUS
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
	_set_presence(Presence.SILENT)
	if is_instance_valid(_return_prompt):
		_return_prompt.queue_free()
		_return_prompt = null
	# Hand the music over now, at the top of the two seconds of black. The
	# floor track fades out and the title track is already up by the time the
	# card appears — the death cry still carries, because it is on a bus that
	# stays live until `_build_title` silences the building.
	_title_music = true
	_switch_music(active_level)
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
	if _director != null:
		_director.set_pressure(threat)
	_set_post_corruption(threat)
	if _figures != null:
		_figures.interval_scale = lerpf(1.0, 0.35, threat) \
			* (run.figure_interval_scale() if run != null else 1.0)


## The flat direction from the player toward the next route cell, or zero when
## the player is off the route (or standing on the target). Feeds the whisper
## bias; deliberately never rendered.
func _whisper_route_bias() -> Vector3:
	if descent_route == null or player == null:
		return Vector3.ZERO
	var cell := Vector2i(floori(player.global_position.x / 12.0),
		floori(player.global_position.z / 12.0))
	var next := descent_route.next_from(cell)
	if next == cell:
		return Vector3.ZERO
	var centre := Vector3((float(next.x) + 0.5) * 12.0, 0.0,
		(float(next.y) + 0.5) * 12.0)
	var dirv := centre - player.global_position
	dirv.y = 0.0
	return dirv.normalized() if dirv.length() > 0.5 else Vector3.ZERO


func _on_descent_violation(kind: int) -> void:
	if not descent or player == null:
		return
	var message := "RULE BROKEN"
	match kind:
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
	if _crt_material != null:
		var base := 1.0 + run.threat() * 1.6
		_crt_material.set_shader_parameter(
			"noise_amount", minf(3.0, base + 0.7))
		var tw := create_tween()
		tw.tween_method(_set_post_noise,
			minf(3.0, base + 0.7), base, 0.32)
	_camera_damage_hit(0.78)


func _set_post_noise(value: float) -> void:
	if _crt_material != null:
		_crt_material.set_shader_parameter("noise_amount", value)


## Drive both recording treatments from the same supernatural pressure. The
## CRT gets stronger snow; the found-footage mode loses color and tracking.
func _set_post_corruption(amount: float) -> void:
	_post_signal_corruption = clampf(amount, 0.0, 1.0)
	_set_post_noise(1.0 + _post_signal_corruption * 1.6)
	_apply_found_footage_state()


func _camera_damage_hit(intensity := 1.0) -> void:
	_post_damage_intensity = clampf(intensity, 0.0, 1.0)
	_post_damage_until = Time.get_ticks_msec() * 0.001 + 0.15
	_apply_found_footage_state()


func _on_descent_blackout(on: bool) -> void:
	if not descent or cm == null:
		return
	cm.set_blackout(on)
	if on:
		if _blackout_ambient < 0.0:
			_blackout_ambient = we.environment.ambient_light_energy
		we.environment.ambient_light_energy = 0.003
		_play_descent_cue(SoundBank.thud(), -7.0)
		_show_event_message("BLACKOUT — STAND STILL · THE TORCH STILL WORKS", true)
	else:
		if _blackout_ambient >= 0.0:
			we.environment.ambient_light_energy = _blackout_ambient
			_blackout_ambient = -1.0
		_blackout_locate_cue = 0
		if _pending_shortcut_reveal:
			_pending_shortcut_reveal = false
			_play_descent_cue(SoundBank.creak(), -7.0)
			_play_descent_cue(SoundBank.thud(), -13.0)
			_show_event_message("POWER RESTORED — SOMETHING OPENED NEARBY", true)
		else:
			# A failed preflight postpones the blackout, so this path is only a
			# defensive fallback for teardown/level-switch races.
			_play_descent_cue(SoundBank.ding(), -10.0)
			_show_event_message("POWER RESTORED")


## Something in the dark heard the player move. It closes in three audible
## steps; the fourth is `_on_blackout_ambush`.
func _on_blackout_locate(value: float) -> void:
	if not descent or _dying:
		return
	var step := 0
	if value >= 0.85:
		step = 3
	elif value >= 0.6:
		step = 2
	elif value >= 0.3:
		step = 1
	if step <= _blackout_locate_cue:
		if step == 0:
			_blackout_locate_cue = 0
		return
	_blackout_locate_cue = step
	_play_descent_cue(SoundBank.creak(), -18.0 + 5.0 * step)
	if step >= 2:
		_play_descent_cue(SoundBank.thud(), -20.0 + 5.0 * step)
	if step == 3:
		_camera_damage_hit(0.35)


## It found them. The player never sees what it was — one frame of something
## at the lens, the loudest sound in the game, and the run is over.
func _on_blackout_ambush() -> void:
	if not descent or run == null or run.ended or _dying:
		return
	_dying = true
	_blackout_locate_cue = 0
	var pick := Sfx.random_scare()
	_play_descent_cue(pick[0], -2.0)
	_camera_damage_hit(1.0)
	_play_player_death()
	run.finish(false)


## The rules have the player pinned. Nothing arrives and nothing closes until
## they are free to act again.
## Say it once, the first time something gets close enough to matter. The
## briefing lists the building's rules; it does not say what the figures are or
## what answers them, and finding that out by dying is not a fair lesson.
func _check_torch_hint() -> void:
	if _torch_hint_shown or _switching or _dying or player == null \
			or _figures == null or _figures.suspended:
		return
	if _title != null or not player.is_inside_tree():
		return
	if _figures.nearest_distance() > TORCH_HINT_D:
		return
	_torch_hint_shown = true
	_show_event_message("IT IS COMING — F TO BURN IT", true)


func _on_descent_passive(on: bool) -> void:
	if _director != null:
		_director.set_scripted_hold(on and (run == null or not run.blackout))
	if _figures != null:
		_figures.passive = on
	if _corner_apparitions != null:
		_corner_apparitions.passive = on


func _play_descent_cue(stream: AudioStream, volume: float) -> void:
	var cue := AudioStreamPlayer.new()
	cue.stream = stream
	cue.volume_db = volume
	add_child(cue)
	cue.finished.connect(cue.queue_free)
	cue.play()


func _on_descent_anomaly(at: Vector2i, kind: int) -> void:
	if not descent or cm == null or descent_route == null \
			or at == descent_route.target or at == descent_route.origin:
		return
	cm.set_anomaly(at, kind)


func _on_blackout_doorway(proposal: Dictionary,
		assistance_requested: bool) -> void:
	if not descent or cm == null or run == null or descent_route == null \
			or descent_route.topology == null or proposal.is_empty():
		return
	var edge_cell: Vector2i = proposal["cell"]
	var dir := int(proposal["dir"])
	var before := descent_route.distance_from_target(run._cell)
	if not descent_route.topology.add_shortcut(edge_cell, dir):
		return
	descent_route.refresh_topology()
	var after := descent_route.distance_from_target(run._cell)
	var other: Vector2i = edge_cell + WorldGen.DIRV[dir]
	cm.descent_topology = descent_route.topology
	cm.rebuild_cells(_shortcut_rebuild_cells(edge_cell, other))
	if _figures != null:
		_figures.topology = descent_route.topology
	if _passers != null:
		_passers.topology = descent_route.topology
	var far_side_distance := descent_route.distance_from_target(other)
	var verified_help := assistance_requested and before >= 0 \
		and far_side_distance >= 0 \
		and before - far_side_distance >= DescentRoute.MERCY_MIN_SAVING
	if verified_help:
		run.mark_helpful_doorway_created()
	_pending_shortcut_reveal = true
	print("blackout doorway %s dir=%d, route %d -> %d, assistance=%s" % [
		edge_cell, dir, before, after, verified_help])


## Furniture for a merged room belongs to its root chunk and can extend into
## every member. Rebuilding the whole owning room makes its ordinary
## doorway-clearance pass see the supernatural edge as well in every zone.
func _shortcut_rebuild_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for endpoint in [a, b]:
		var is_corridor := WorldGen.annex_corridor_axis(
			descent_route.world_seed, endpoint) != 0 \
			if descent_route.theme == 2 else \
			WorldGen.corridor(descent_route.world_seed, endpoint) != 0
		if is_corridor:
			if not out.has(endpoint):
				out.append(endpoint)
			continue
		var root := WorldGen.annex_room_id(
			descent_route.world_seed, endpoint) \
			if descent_route.theme == 2 else \
			WorldGen.room_id(descent_route.world_seed, endpoint)
		for x in range(root.x - 1, root.x + 2):
			for y in range(root.y - 1, root.y + 2):
				var member := Vector2i(x, y)
				var member_root := WorldGen.annex_room_id(
					descent_route.world_seed, member) \
					if descent_route.theme == 2 else \
					WorldGen.room_id(descent_route.world_seed, member)
				if member_root == root \
						and not out.has(member):
					out.append(member)
	return out


func _on_descent_ended(won: bool) -> void:
	_set_presence(Presence.SILENT)
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	player.set_rumble(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_descent_summary(won)


func _show_descent_summary(won: bool) -> void:
	if is_instance_valid(_descent_summary):
		return
	_descent_summary = DescentSummary.new()
	_descent_summary.won = won
	_descent_summary.floor_idx = run.floor_idx
	_descent_summary.floor_display = run.floor_name()
	_descent_summary.elapsed = run.elapsed
	_descent_summary.violations = run.violations
	_descent_summary.world_seed = world_seed
	_descent_summary.continue_floor_idx = _continue_floor_idx()
	_descent_summary.continue_run.connect(_continue_descent)
	_descent_summary.restart_run.connect(_restart_descent)
	_descent_summary.new_run.connect(_new_descent)
	_descent_summary.leave.connect(_leave_descent)
	add_child(_descent_summary)


func _continue_floor_idx() -> int:
	if _progress_enabled and _descent_progress.has_checkpoint() \
			and _descent_progress.run_seed == world_seed:
		return _descent_progress.deepest_floor
	return run.floor_idx if run != null else 0


func _continue_descent() -> void:
	if _progress_enabled and _descent_progress.has_checkpoint():
		world_seed = _descent_progress.run_seed
	await _resume_descent_at(_continue_floor_idx())


func _restart_descent() -> void:
	if _progress_enabled and _descent_progress.has_checkpoint():
		world_seed = _descent_progress.run_seed
	await _resume_descent_at(0)


func _new_descent() -> void:
	world_seed = _fresh_descent_seed()
	await _play_descent_intro()
	_commit_new_descent_checkpoint()
	# This entry comes from the results screen rather than `_on_start`, so it
	# must release the audio hold that the title path releases there.
	_music.stream_paused = false
	_set_world_audio(true)
	await _resume_descent_at(0)


func _resume_descent_at(floor_idx: int) -> void:
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
	run.floor_idx = clampi(floor_idx, 0, DescentRun.FLOOR_COUNT - 1)
	_connect_descent_run()
	run.prepare_floor()
	add_child(run)
	run.player = player
	player.reset_descent_resources()
	_dying = false
	_blackout_locate_cue = 0
	descent_route = _create_descent_route(run.theme(), run.floor_idx)
	_print_descent_route()
	var arrival := _descent_arrival(run.theme())
	await _jump_to(run.theme(), arrival["position"], false,
		bool(arrival["exact"]), float(arrival["yaw"]))
	player.grab_look()
	player.set_process_unhandled_input(true)
	_begin_descent_floor()


func _leave_descent() -> void:
	if _switching:
		return
	player.set_flashlight(false)
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
	if is_instance_valid(_bleed_bed):
		_bleed_bed.queue_free()
	_bleed_bed = null
	_bleed_captured = false
	if is_instance_valid(_descent_hud):
		_descent_hud.queue_free()
	_descent_hud = null
	_saved_pos.clear()
	player.allow_sprint = true
	player.set_rumble(0.0)
	_events.descent_mode = false
	_set_presence(Presence.SILENT)
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
	# base.y is clearance ABOVE this cell's floor, not an absolute height. Every
	# floor is flat at zero except the Poolrooms' dry styles, which are a raised
	# slab; this used to hardcode 0.15 and discard base.y, which asked to place
	# the player 1.27m inside that slab.
	var floor_y := Chunk.cell_floor_h(_level_seed(level), cellv, level)
	var pos := Vector3(cellv.x * 12.0 + base.x, floor_y + base.y,
		cellv.y * 12.0 + base.z)
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
		return Vector3(centre.x + facing.x * 2.2 + side.x * 3.0, floor_y + base.y,
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


func _jump_to(level: int, pos: Vector3, via_portal: bool, exact := false,
		yaw := NAN) -> void:
	_switching = true
	if not descent:
		_saved_pos[active_level] = player.position
	if via_portal:
		_warp.play()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16 if via_portal else 0.3)
	await tw.finished
	# Detach the outgoing floor immediately. queue_free() alone can leave its
	# collision bodies registered until the end of a busy frame; if the landing
	# probe runs during that overlap, geometry from two floors can make every
	# otherwise-safe candidate appear blocked (seen returning to the school at
	# seed 1760336105, cell -1,0).
	var old_level := level_root
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
	player.water_y = _water_level_for(level)
	await get_tree().physics_frame
	var cellv := Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))
	var safe := pos
	# An authored arrival car interior is clear by construction but sealed, so
	# the escape-direction half of ArrivalSafety can never pass inside one. Trust
	# the point, but still refuse to drop the player into solid geometry.
	var trusted := exact and ArrivalSafety.is_clear(get_world_3d(), pos,
		[player.get_rid()]) \
		and ArrivalSafety.has_floor(get_world_3d(), pos, [player.get_rid()])
	if not trusted:
		if exact:
			push_warning("Descent arrival car interior was not clear in theme %d cell %s; falling back" % [level, cellv])
		safe = ArrivalSafety.find_safe(get_world_3d(), pos, cellv, [player.get_rid()])
		if safe == Vector3.INF:
			# Last resort. Standing the player on whatever is under the requested
			# point beats teleporting into it: the old behaviour used `pos`
			# unchanged, which buried them and left Godot's depenetration to pick a
			# direction. Report the style and the floor datum, because the useful
			# distinction is "furniture in the way" versus "this floor is not where
			# the caller thinks it is".
			var support := ArrivalSafety.support_top(get_world_3d(), pos.x, pos.z,
				pos.y, [player.get_rid()])
			safe = pos if support == -INF \
				else Vector3(pos.x, support + ArrivalSafety.STANDING_CLEARANCE, pos.z)
			push_error(("No audited arrival candidate in theme %d cell %s " +
				"(style %d, floor y %.2f, requested y %.2f); using %s") % [
					level, cellv, WorldGen.cell_style(_level_seed(level), cellv, level),
					Chunk.cell_floor_h(_level_seed(level), cellv, level), pos.y,
					"supported point" if support != -INF else "requested position"])
	player.teleport(safe)
	if is_finite(yaw):
		player.rotation.y = yaw
	we.environment = _build_env(level)
	ambience.queue_free()
	ambience = Ambience.new(level)
	add_child(ambience)
	# Descent prepares its first floor while the card is still up, and a death
	# returns through here on its way back to one. A fresh room tone must not
	# undo the silence either of those is holding — and `Ambience` starts itself
	# in `_ready`, so this has to come after it is in the tree.
	if _title_music:
		ambience.stop()
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.45 if via_portal else 0.5)
	await tw2.finished
	_switching = false


func _settle_initial_arrival() -> void:
	await get_tree().physics_frame
	if player == null or not is_instance_valid(player):
		return
	# A Descent run starts inside its sealed arrival car. Re-probing that point
	# would "rescue" the player straight back out through the shut doors.
	if descent and descent_route != null and descent_route.origin_wall >= 0:
		return
	var pos := player.global_position
	var cellv := Vector2i(floori(pos.x / 12.0), floori(pos.z / 12.0))
	var safe := ArrivalSafety.find_safe(get_world_3d(), pos, cellv, [player.get_rid()])
	if safe != Vector3.INF and safe.distance_to(pos) > 0.02:
		player.teleport(safe)


func _process(dt: float) -> void:
	_check_torch_hint()
	_update_post_effects()
	_update_flashlight_hud()
	_update_bleed()
	# Once the mercy system has proven a stall, the whispers stop being
	# uniformly random and lean toward where the route actually continues.
	if descent and _whispers != null and run != null:
		_whispers.bias_dir = _whisper_route_bias() if run.mercy_armed \
			else Vector3.ZERO
	# The chunk config is read at build time, so the mirrored lift clock has to
	# stay current for a target room that streams back in mid-wait.
	if descent and cm != null and run != null and run.lift_called \
			and not run.lift_open:
		cm.descent_lift_wait = run.lift_wait_left
		# The summon wait is scored by the figures instead of blackouts: the
		# building answers the call with everything except the car.
		if _figures != null:
			_figures.interval_scale = minf(_figures.interval_scale,
				lerpf(0.6, 0.3, run.floor_progress()))
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
	# The Annex is deliberately scored only by its dedicated ambient bed—even
	# during Descent's late-floor music override.
	if level == 2:
		return ""
	if descent and run != null and run.floor_idx >= DescentRun.FLOOR_COUNT - 2:
		return DESCENT_LATE_TRACK
	return MUSIC_TRACKS.get(level, "")


## Screenshot and `--nologo` starts go straight into the world with no card.
func _will_show_title() -> bool:
	return not opts.skips_title()


## While the title is up the track is fixed, whatever floor is loaded behind it.
func _switch_music(level: int) -> void:
	var target := TITLE_MUSIC if _title_music else _music_track_for(level)
	if target == _music_target:
		return
	_music_target = target
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -50.0, 0.6)
	tw.tween_callback(func():
		if target == "":
			_music.stop()
			return
		var st: AudioStreamMP3 = load(target)
		st.loop = true
		_music.stream = st
		# The title track starts at the top. A floor track is joined partway in,
		# because you are walking into a building that was already playing.
		_music.play(0.0 if _title_music else randf() * 20.0))
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

	_battery_panel.custom_minimum_size = Vector2(238.0, 52.0) * scale
	_battery_panel.position = Vector2(18.0, viewport_size.y - 78.0 * scale)
	_charging_panel.custom_minimum_size = Vector2(360.0, 66.0) * scale
	_charging_panel.position = Vector2(
		(viewport_size.x - _charging_panel.custom_minimum_size.x) * 0.5,
		viewport_size.y - 174.0 * scale)

	for style in [_interact_style, _event_style]:
		style.content_margin_left = 18.0 * scale
		style.content_margin_right = 18.0 * scale
		style.content_margin_top = 9.0 * scale
		style.content_margin_bottom = 9.0 * scale
		style.corner_radius_top_left = roundi(7.0 * scale)
		style.corner_radius_top_right = roundi(7.0 * scale)
		style.corner_radius_bottom_left = roundi(7.0 * scale)
		style.corner_radius_bottom_right = roundi(7.0 * scale)


func _toggle_post_mode() -> void:
	if _post == null or _crt_material == null \
			or _found_footage_material == null:
		return
	_post_mode = PostMode.FOUND_FOOTAGE \
		if _post_mode == PostMode.CRT else PostMode.CRT
	_post.material = _found_footage_material \
		if _post_mode == PostMode.FOUND_FOOTAGE else _crt_material
	if _post_mode == PostMode.FOUND_FOOTAGE:
		_schedule_post_glitches(Time.get_ticks_msec() * 0.001)
		_apply_found_footage_state()
	if _title == null:
		_show_event_message(
			"VIDEO MODE — RECOVERED TAPE"
			if _post_mode == PostMode.FOUND_FOOTAGE
			else "VIDEO MODE — 480i CRT"
		)
	_set_mode_hint()


func _schedule_post_glitches(now: float) -> void:
	_post_minor_at = now + randf_range(1.5, 5.0)
	_post_major_at = now + randf_range(10.0, 28.0)
	_post_glitch_active = false


func _start_post_glitch(major: bool, now: float) -> void:
	_post_glitch_active = true
	_post_glitch_major = major
	if major:
		_post_glitch_until = now + randf_range(0.12, 0.42)
		_post_glitch_jitter = randf_range(0.025, 0.05)
		_post_glitch_tracking = randf_range(0.55, 1.0)
		_post_glitch_noise = randf_range(0.22, 0.48)
		_post_glitch_aberration = randf_range(0.012, 0.02)
		_post_major_at = now + randf_range(10.0, 28.0)
	else:
		_post_glitch_until = now + randf_range(0.04, 0.16)
		_post_glitch_jitter = randf_range(0.012, 0.028)
		_post_glitch_aberration = randf_range(0.006, 0.013)
		_post_minor_at = now + randf_range(1.5, 5.0)
	_apply_found_footage_state()


func _update_post_effects() -> void:
	if _found_footage_material == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	var changed := false
	if _post_damage_intensity > 0.0 and now >= _post_damage_until:
		_post_damage_intensity = 0.0
		changed = true
	if _post_glitch_active and now >= _post_glitch_until:
		_post_glitch_active = false
		changed = true
	if _post_mode == PostMode.FOUND_FOOTAGE and _crt:
		if _post_minor_at <= 0.0 or _post_major_at <= 0.0:
			_schedule_post_glitches(now)
		if not _post_glitch_active:
			if now >= _post_major_at:
				_start_post_glitch(true, now)
				return
			if now >= _post_minor_at:
				_start_post_glitch(false, now)
				return
	if changed:
		_apply_found_footage_state()


func _apply_found_footage_state() -> void:
	if _found_footage_material == null:
		return
	var corruption := _post_signal_corruption
	var jitter := lerpf(0.006, 0.032, corruption)
	var tracking := lerpf(0.18, 0.85, corruption)
	var noise := lerpf(0.10, 0.42, corruption)
	var aberration := 0.0035
	var saturation_value := lerpf(0.72, 0.30, corruption)
	var shake := 0.0015
	var exposure := 0.06
	if _post_glitch_active:
		jitter = maxf(jitter, _post_glitch_jitter)
		aberration = maxf(aberration, _post_glitch_aberration)
		if _post_glitch_major:
			tracking = maxf(tracking, _post_glitch_tracking)
			noise = maxf(noise, _post_glitch_noise)
	if _post_damage_intensity > 0.0:
		shake = lerpf(0.003, 0.012, _post_damage_intensity)
		aberration = maxf(aberration,
			lerpf(0.006, 0.018, _post_damage_intensity))
		exposure = lerpf(0.10, 0.30, _post_damage_intensity)
	_found_footage_material.set_shader_parameter(
		"horizontal_jitter", jitter)
	_found_footage_material.set_shader_parameter(
		"tracking_damage", tracking)
	_found_footage_material.set_shader_parameter("static_noise", noise)
	_found_footage_material.set_shader_parameter(
		"chromatic_aberration", aberration)
	_found_footage_material.set_shader_parameter(
		"saturation", saturation_value)
	_found_footage_material.set_shader_parameter("camera_shake", shake)
	_found_footage_material.set_shader_parameter(
		"exposure_pumping", exposure)


## Everything the building makes — all twenty-four spatial emitters, the
## whispers, the heartbeat, the slot banks — routes through "Hall", so one bus
## mute covers the lot. `Ambience` is the exception: it is a plain
## AudioStreamPlayer on Master, so it is stopped by hand.
func _set_world_audio(on: bool) -> void:
	var idx := AudioServer.get_bus_index(SoundBank.HALL_BUS)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not on)
	if is_instance_valid(ambience):
		if on:
			if not ambience.playing:
				ambience.play()
		else:
			ambience.stop()


## Shared "Hall" bus: every spatial emitter routes through a soft reverb so
## sounds feel like they happen inside the building.
func _setup_audio_bus() -> void:
	if AudioServer.get_bus_index(SoundBank.HALL_BUS) >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, SoundBank.HALL_BUS)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.8
	rev.damping = 0.5
	rev.wet = 0.25
	AudioServer.add_bus_effect(idx, rev)


## The floor's WorldEnvironment. Kept as a method because _switch_level and the
## runtime audits call it; the settings themselves live in EnvBuilder.
func _build_env(theme: int) -> Environment:
	return EnvBuilder.build(theme)


func _build_ui() -> void:
	# Screen treatment over the 3D view, under UI. V enables/disables it and B
	# changes recording media between the established CRT and recovered tape.
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = load("res://shaders/post.gdshader")
	# these floors run far darker than an arcade cabinet — push the tube
	_crt_material.set_shader_parameter("bright_boost", 1.4)
	_found_footage_material = ShaderMaterial.new()
	_found_footage_material.shader = load(
		"res://shaders/found_footage.gdshader")
	_post.material = _found_footage_material \
		if _post_mode == PostMode.FOUND_FOOTAGE else _crt_material
	_post.visible = _crt
	post_layer.add_child(_post)
	add_child(post_layer)
	_schedule_post_glitches(Time.get_ticks_msec() * 0.001)
	_apply_found_footage_state()

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

	_battery_panel = PanelContainer.new()
	_battery_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var battery_style := StyleBoxFlat.new()
	battery_style.bg_color = Color(0.018, 0.025, 0.028, 0.84)
	battery_style.border_color = Color(0.25, 0.70, 0.82, 0.55)
	battery_style.set_border_width_all(1)
	battery_style.set_corner_radius_all(5)
	battery_style.set_content_margin_all(9.0)
	_battery_panel.add_theme_stylebox_override("panel", battery_style)
	cl.add_child(_battery_panel)
	var battery_box := VBoxContainer.new()
	battery_box.add_theme_constant_override("separation", 4)
	_battery_panel.add_child(battery_box)
	var battery_label := Label.new()
	battery_label.text = "FLASHLIGHT"
	battery_label.add_theme_font_size_override("font_size", 13)
	battery_label.add_theme_color_override("font_color", Color(0.66, 0.88, 0.94))
	battery_box.add_child(battery_label)
	_battery_bar = ProgressBar.new()
	_battery_bar.show_percentage = false
	_battery_bar.max_value = 1.0
	_battery_bar.value = 1.0
	_battery_bar.custom_minimum_size = Vector2(220, 11)
	var battery_bg := StyleBoxFlat.new()
	battery_bg.bg_color = Color(0.035, 0.055, 0.06, 0.95)
	var battery_fill := StyleBoxFlat.new()
	battery_fill.bg_color = Color(0.25, 0.82, 0.92)
	_battery_bar.add_theme_stylebox_override("background", battery_bg)
	_battery_bar.add_theme_stylebox_override("fill", battery_fill)
	battery_box.add_child(_battery_bar)

	_charging_panel = PanelContainer.new()
	_charging_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charging_panel.visible = false
	var charge_style := StyleBoxFlat.new()
	charge_style.bg_color = Color(0.012, 0.038, 0.028, 0.90)
	charge_style.border_color = Color(0.30, 1.0, 0.52, 0.72)
	charge_style.set_border_width_all(1)
	charge_style.set_corner_radius_all(6)
	charge_style.set_content_margin_all(11.0)
	_charging_panel.add_theme_stylebox_override("panel", charge_style)
	cl.add_child(_charging_panel)
	var charge_box := VBoxContainer.new()
	charge_box.add_theme_constant_override("separation", 6)
	_charging_panel.add_child(charge_box)
	var charge_label := Label.new()
	charge_label.text = "CHARGING — E OR F TO DISCONNECT"
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_label.add_theme_font_size_override("font_size", 15)
	charge_label.add_theme_color_override("font_color", Color(0.58, 1.0, 0.72))
	charge_box.add_child(charge_label)
	_charging_bar = ProgressBar.new()
	_charging_bar.show_percentage = false
	_charging_bar.max_value = 1.0
	_charging_bar.custom_minimum_size = Vector2(338, 14)
	var charge_bg := StyleBoxFlat.new()
	charge_bg.bg_color = Color(0.025, 0.09, 0.06, 1.0)
	var charge_fill := StyleBoxFlat.new()
	charge_fill.bg_color = Color(0.30, 1.0, 0.52)
	_charging_bar.add_theme_stylebox_override("background", charge_bg)
	_charging_bar.add_theme_stylebox_override("fill", charge_fill)
	charge_box.add_child(_charging_bar)
	# fullscreen fade for level transitions
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_fade)
	add_child(cl)
	_warp = AudioStreamPlayer.new()
	_warp.stream = SoundBank.warp()
	_warp.volume_db = -6.0
	add_child(_warp)
	_apply_hud_scaling()


func _update_flashlight_hud() -> void:
	if player == null or _battery_bar == null:
		return
	var level := player.flashlight_charge()
	_battery_bar.value = level
	_charging_bar.value = level
	_charging_panel.visible = player.is_charging()
	var fill := _battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color(0.95, 0.28, 0.18) if level < 0.15 else (
			Color(1.0, 0.66, 0.20) if level < 0.35 else Color(0.25, 0.82, 0.92))


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


## The title menu and its dedicated information pages, over the already-running
## world.
## Skipped for `--screenshot=` runs, which want the view and not the titles.
func _build_title() -> void:
	if opts.skips_title():
		# These starts never show a card, so the world was never silenced.
		_title_music = false
		_set_world_audio(true)
		_start_hint_fade()
		return
	if _hint != null:
		_hint.modulate.a = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_process_unhandled_input(false)  # no looking around yet either
	_title_music = true
	_set_world_audio(false)
	_switch_music(active_level)
	_title = TitleScreen.new()
	if _progress_enabled and _descent_progress != null \
			and _descent_progress.has_checkpoint():
		var checkpoint_theme: int = DescentRun.order_for(
			_descent_progress.run_seed)[_descent_progress.deepest_floor]
		_title.configure_descent_progress(true,
			_descent_progress.deepest_floor,
			str(DescentRun.THEME_NAMES[checkpoint_theme]))
	_title.descent_requested.connect(_on_descent_requested)
	_title.started.connect(_on_start)
	add_child(_title)
	if descent:
		_title.present_descent(true)


func _on_descent_requested(entry: int) -> void:
	call_deferred("_prepare_descent", entry)


func _prepare_descent(entry: int) -> void:
	if descent or _descent_preparing:
		if descent and is_instance_valid(_title):
			_title.set_descent_ready()
		return
	_descent_preparing = true
	descent = true
	_pending_new_descent_intro = entry == TitleScreen.DescentEntry.NEW
	var floor_idx := _apply_descent_entry(entry)
	player.allow_sprint = false
	player.set_process_unhandled_input(false)
	player.reset_descent_resources()
	_saved_pos.clear()
	run = DescentRun.new()
	run.floor_idx = floor_idx
	_connect_descent_run()
	run.prepare_floor()
	add_child(run)
	descent_route = _create_descent_route(run.theme(), run.floor_idx)
	_print_descent_route()
	_events.descent_mode = true
	_set_presence(Presence.SILENT)
	_set_mode_hint()
	var arrival := _descent_arrival(run.theme())
	await _jump_to(run.theme(), arrival["position"], false,
		bool(arrival["exact"]), float(arrival["yaw"]))
	_descent_preparing = false
	if is_instance_valid(_title):
		_title.set_descent_ready()


func _apply_descent_entry(entry: int) -> int:
	if not _progress_enabled:
		return 0
	if entry == TitleScreen.DescentEntry.CONTINUE \
			and _descent_progress.has_checkpoint():
		world_seed = _descent_progress.run_seed
		return _descent_progress.deepest_floor
	if entry == TitleScreen.DescentEntry.RESTART \
			and _descent_progress.has_checkpoint():
		world_seed = _descent_progress.run_seed
		return 0
	world_seed = _fresh_descent_seed()
	return 0


func _fresh_descent_seed() -> int:
	var previous := _descent_progress.run_seed \
		if _descent_progress != null and _descent_progress.has_checkpoint() else 0
	var candidate := (randi() & 0x7FFFFFFF) | 1
	while candidate == previous:
		candidate = (randi() & 0x7FFFFFFF) | 1
	return candidate


func _on_start(selected_descent: bool) -> void:
	_title = null
	_title_music = false
	if selected_descent and _pending_new_descent_intro:
		_pending_new_descent_intro = false
		await _play_descent_intro()
		_commit_new_descent_checkpoint()
	_finish_mode_start(selected_descent)


func _finish_mode_start(selected_descent: bool) -> void:
	_music.stream_paused = false
	_set_world_audio(true)
	_switch_music(active_level)
	player.grab_look()
	player.set_process_unhandled_input(true)
	if selected_descent:
		_begin_descent_floor()
	else:
		_set_presence(Presence.WANDER)
	_start_hint_fade()


func _play_descent_intro() -> void:
	if is_instance_valid(_descent_intro):
		await _descent_intro.completed
		return
	_set_presence(Presence.SILENT)
	_set_world_audio(false)
	# Score lives on Master beside the movie. Pause it explicitly while the
	# Hall bus and ambience are silent, leaving the intro's own audio untouched.
	_music.stream_paused = true
	player.velocity = Vector3.ZERO
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_descent_intro = DescentIntro.new(_intro_state.has_viewed())
	add_child(_descent_intro)
	var watched_to_end: bool = await _descent_intro.completed
	_descent_intro = null
	if watched_to_end:
		var error := _intro_state.mark_viewed()
		if error != OK:
			push_warning("Could not save intro playback state (error %d)" % error)


func _commit_new_descent_checkpoint() -> void:
	if _progress_enabled:
		_descent_progress.start_new(world_seed)


func _set_mode_hint() -> void:
	if _hint == null:
		return
	if descent:
		_hint.text = "WASD / arrows move   ·   E interact   ·   F flashlight   ·   B video mode   ·   the counter knows how far   ·   Q title   ·   Esc release mouse"
	else:
		_hint.text = "WASD / arrows move   ·   Shift run   ·   E interact   ·   F flashlight   ·   1-9 floors / 0 Monolith / − Bloom   ·   V filter   ·   B video mode   ·   Q title   ·   Esc release mouse"


## Dev helper: `godot --path . -- --screenshot=/tmp/shot.png` renders a couple
## of seconds and saves a frame, for checking visuals from the command line.
func _maybe_screenshot() -> void:
	if opts.screenshot.is_empty():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(2.5).timeout
	print("player at ", player.global_position)
	get_viewport().get_texture().get_image().save_png(opts.screenshot)
	get_tree().quit()


## The Poolrooms are the only floor with standing water. Everywhere else the
## surface is parked far below the world so the player's wading and ladder
## code costs nothing and can never trigger.
func _water_level_for(level: int) -> float:
	return Chunk.POOL_WATER_Y if level == 9 else -1.0e9
