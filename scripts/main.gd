extends Node3D
## Entry point and level manager. Eight endless floors share one player:
##   1 — seedy Vegas hotel-casino            (theme 0)
##   2 — sterile Severance-style office      (theme 1)
##   3 — the yellow Backrooms corridors of the Annex (theme 2)
##   4 — an airport terminal at 3 a.m., between every flight (theme 4)
##   5 — an abandoned asylum, beds still made, straps still buckled (theme 5)
##   6 — a high school after the last bell that never rang (theme 6)
##   7 — an abandoned shopping mall with every shutter down (theme 7)
##   8 — an island prison whose cell blocks never end (theme 8)
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
## Seconds of torch handed back per burned figure, and how close one has to get
## before the game says out loud, once, what the torch is for.
const BURN_REFUND := 1.5
const TORCH_HINT_D := 6.0
var _torch_hint_shown := false
var _title_music := false
## What the last `_switch_music` was aiming at. The swap happens behind a 0.6s
## fade, so the live stream lags the intent — guarding on the stream instead
## lets a second call stack another fade tween on the same property.
var _music_target := ""
var _descent_summary: DescentSummary
var _pursuer: DescentPursuer
var _descent_hud: DescentHUD
var _return_prompt: ReturnPrompt

# One mood track per floor.
const MUSIC_TRACKS := {
	0: "res://music/lim1.mp3", 1: "res://music/lim2.mp3",
	4: "res://music/lim5.mp3", 5: "res://music/lim6.mp3",
	6: "res://music/lim4.mp3",
	7: "res://music/lim7.mp3", 8: "res://music/lim8.mp3",
	# lim10 is the user-supplied calm/tranquil loop cut for the Poolrooms;
	# lim3 (ex theme park) is unclaimed again.
	9: "res://music/lim10.mp3",
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
		if opts.descent_floor > 0:
			run.floor_idx = clampi(opts.descent_floor - 1, 0,
				DescentRun.ORDER.size() - 1)
		active_level = run.theme()
		if _attention_override >= 0.0:
			run.attention = _attention_override
		_connect_descent_run()
		run.prepare_floor()
		add_child(run)
		descent_route = DescentRoute.build(_level_seed(active_level),
			active_level, run.floor_idx)
		_print_descent_route()
	if not pos_given:
		if descent:
			var arrival := _descent_arrival(active_level)
			spawn = arrival["position"]
			if not yaw_given:
				yaw = float(arrival["yaw"])
		else:
			spawn = _safe_arrival(active_level, Vector2i.ZERO, DEFAULT_SPAWN)
	print("Liminal Vegas — seed %d" % world_seed)
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
	player.allow_sprint = not descent
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
	var oneshots := OneShots.new()
	oneshots.player = player
	add_child(oneshots)
	_whispers = Whispers.new()
	_whispers.player = player
	_whispers.dev = opts.whispers
	add_child(_whispers)
	_figures = ShadowFigures.new()
	_figures.player = player
	_figures.dev_haunt = opts.haunt
	_figures.dev_haunt_at = opts.haunt_at
	_figures.dev_haunt_at_given = opts.haunt_at_given
	_figures.dev_haunt_variant = opts.haunt_variant
	_figures.stared_away.connect(_on_figure_stared_away)
	_figures.reached_player.connect(_on_figure_reached_player)
	add_child(_figures)
	# Frights raise the pulse; it bleeds away on its own. Wired after the
	# figures exist so it can sample how close the nearest one is.
	_heart = Heartbeat.new()
	_heart.figures = _figures
	_heart.dev = opts.heartbeat
	add_child(_heart)
	# Nothing mutters, haunts or races behind a title or a rule card. The
	# screenshot and --nologo starts release this below.
	_set_presence(Presence.SILENT)
	_figures.seen_by_player.connect(
		func(): _heart.bump(Heartbeat.BUMP_SEEN))
	_figures.burned_away.connect(
		func():
			_heart.bump(Heartbeat.BUMP_BURNED)
			player.add_flashlight_charge(BURN_REFUND))
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
	_figures.suspended = state != Presence.DESCENT
	_whispers.suspended = state == Presence.SILENT
	_heart.suspended = state == Presence.SILENT


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
			descent_route = DescentRoute.build(_level_seed(level), level,
				run.floor_idx)
		cm.descent_floor_idx = run.floor_idx
		cm.descent_route = descent_route
		cm.blackout = run.blackout
		cm.anomalies = run.anomalies
		cm.descent_arrival_used = run.arrival_used
		cm.descent_lift_called = run.lift_called
		cm.descent_lift_wait = run.lift_wait_left
		cm.descent_lift_open = run.lift_open
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
		var car := Chunk.car_interior_point(descent_route.origin,
			descent_route.origin_wall)
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


func _on_descent_lift_arrived() -> void:
	if not descent or run == null or run.ended or cm == null \
			or descent_route == null:
		return
	_sync_descent_chunk_state()
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


## Opens the car the player rode in on, a beat after the floor goes live. Not
## awaited by its caller: the arrival grace is long enough to cover it, and the
## audits' synchronous startup path must not block on a timer.
func _reveal_arrival() -> void:
	if not descent or run == null or run.ended or cm == null \
			or descent_route == null:
		return
	var floor_name: String = DescentRun.NAMES[run.floor_idx]
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
	run.pinned_attention = _attention_override
	if player != null:
		run.player = player
	run.attention_changed.connect(_on_descent_attention)
	run.violation.connect(_on_descent_violation)
	run.blackout_changed.connect(_on_descent_blackout)
	run.passive_changed.connect(_on_descent_passive)
	run.figures = _figures
	run.anomaly_requested.connect(_on_descent_anomaly)
	run.lift_arrived.connect(_on_descent_lift_arrived)
	run.run_ended.connect(_on_descent_ended)


func _begin_descent_floor() -> void:
	if not descent or run == null or run.ended:
		return
	run.player = player
	run.start_floor()
	player.allow_sprint = false
	_set_presence(Presence.DESCENT)
	_ensure_descent_hud()
	_descent_hud.set_active(true)
	_on_descent_attention(run.attention)
	_sync_descent_chunk_state()
	_reveal_arrival()


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
	descent_route = DescentRoute.build(_level_seed(next_theme), next_theme,
		run.floor_idx)
	_print_descent_route()
	var arrival := _descent_arrival(next_theme)
	await _jump_to(next_theme, arrival["position"], false,
		bool(arrival["exact"]), float(arrival["yaw"]))
	_begin_descent_floor()


func _on_descent_exit() -> void:
	if descent and run != null and run.is_last_floor() and not run.ended:
		run.finish(true)


func _on_figure_stared_away() -> void:
	if descent and run != null:
		run.add_stare_violation()


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
	_set_post_corruption(threat)
	if _figures != null:
		_figures.interval_scale = lerpf(1.0, 0.35, threat)
	# Never into a blackout: the player is standing still by rule and this thing
	# has no counter. It waits for the lights.
	if threat >= 0.85 and run != null and not run.suspended \
			and not run.blackout and not is_instance_valid(_pursuer):
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
	run.pursuer_active = true


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
	if is_instance_valid(_pursuer):
		_pursuer.frozen = on
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
		_play_descent_cue(SoundBank.ding(), -10.0)
		_show_event_message("POWER RESTORED — KEEP MOVING")


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
	if _figures != null:
		_figures.passive = on


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


func _on_descent_ended(won: bool) -> void:
	_set_presence(Presence.SILENT)
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)
	if is_instance_valid(_pursuer):
		_pursuer.queue_free()
	_pursuer = null
	if run != null:
		run.pursuer_active = false
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
	descent_route = DescentRoute.build(_level_seed(run.theme()), run.theme(),
		run.floor_idx)
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
	if is_instance_valid(_pursuer):
		_pursuer.queue_free()
	_pursuer = null
	if run != null:
		run.pursuer_active = false
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
	# The chunk config is read at build time, so the mirrored lift clock has to
	# stay current for a target room that streams back in mid-wait.
	if descent and cm != null and run != null and run.lift_called \
			and not run.lift_open:
		cm.descent_lift_wait = run.lift_wait_left
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
	if descent and run != null and run.floor_idx >= DescentRun.ORDER.size() - 2:
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
	descent_route = DescentRoute.build(_level_seed(run.theme()), run.theme(),
		run.floor_idx)
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


func _on_start(selected_descent: bool) -> void:
	_title = null
	_title_music = false
	_set_world_audio(true)
	_switch_music(active_level)
	player.grab_look()
	player.set_process_unhandled_input(true)
	if selected_descent:
		_begin_descent_floor()
	else:
		_set_presence(Presence.WANDER)
	_start_hint_fade()


func _set_mode_hint() -> void:
	if _hint == null:
		return
	if descent:
		_hint.text = "WASD / arrows move   ·   E interact   ·   F flashlight   ·   B video mode   ·   follow the HUD needle   ·   Q title   ·   Esc release mouse"
	else:
		_hint.text = "WASD / arrows move   ·   Shift run   ·   E interact   ·   F flashlight   ·   1-9 floors   ·   V filter   ·   B video mode   ·   Q title   ·   Esc release mouse"


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
