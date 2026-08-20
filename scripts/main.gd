extends Node3D
## Entry point and level manager. Eleven endless floors share one player:
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
const MUTATION_REVEAL_EFFECT := preload(
	"res://scripts/mutation_reveal_effect.gd")
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
var _transitions: LevelTransitionController
var _switching: bool:
	get:
		return _transitions != null and _transitions.is_switching()
	set(value):
		if _transitions != null:
			_transitions.set_switching(value)
var _fade: ColorRect
var _warp: AudioStreamPlayer
var _post_process: PostProcessController
var _post_enabled := true
var _found_footage_requested := false
var _dev_tools: BenchmarkDevController
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
var _vf_frame: VhsOsd.Frame
var _battery_meter: VhsOsd.Meter
var _stamina_meter: VhsOsd.Meter
var _charging_panel: VBoxContainer
var _charging_label: Label
var _charging_meter: VhsOsd.Meter
var _events: EnvironmentEvents
var _photo_director: PhotoDirector
var _photo_camera: PhotoCamera
var _photo_debug := false
var _photo_sweep_hinted := false
var _osd_layer: CanvasLayer
var _halo_amt := 0.0
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
var _pending_mutation_reveal := false
var _pending_mutation_reveal_at := Vector3.INF
var _pending_mutation_reveal_descriptor := {}
var _mutation_coordinator: DescentMutationCoordinator
## Environmental bleed presentation: captured baselines for this floor's fog
## and the next floor's targets, plus the rising next-floor room tone.
var _bleed_base_fog := Color.BLACK
var _bleed_base_density := 0.0
var _bleed_next_fog := Color.BLACK
var _bleed_next_density := 0.0
var _bleed_captured := false
var _bleed_bed: AudioStreamPlayer
## VCR playback temporarily owns the mix. Preserve the pre-existing game-bus
## state so leaving a tape cannot accidentally unmute a title/transition hold.
var _tape_audio_held := false
var _tape_game_bus_was_muted := false
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
		_found_footage_requested = true
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
		_post_enabled = false
	_photo_debug = opts.photo_debug
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
	_dev_tools = BenchmarkDevController.new()
	add_child(_dev_tools)
	# Live tuning panel for the Poolrooms. Dragging a slider beats editing a
	# constant, rebuilding and guessing from a screenshot.
	if opts.tune:
		add_child(PoolTuner.new())
	if opts.flashlight:
		player.set_flashlight(true)

	if opts.spin:
		player.dev_spin = true
	if opts.audit:
		_dev_tools.audit_partitions(world_seed)
		get_tree().quit()
		return
	if opts.chunktime:
		ChunkManager._dev_timing = true
	if opts.bench:
		_dev_tools.start_benchmark(player)
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
			_post_process.damage_hit(0.32)
			if _passers != null:
				_passers.defer_for(CornerApparitions.SHARED_QUIET_SECONDS))
	# Nothing mutters, haunts or races behind a title or a rule card. The
	# screenshot and --nologo starts release this below.
	_set_presence(Presence.SILENT)
	_figures.seen_by_player.connect(
		func(): _heart.bump(Heartbeat.BUMP_SEEN))
	_figures.spawned.connect(func(): _post_process.glitch_burst())
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
	_photo_camera = PhotoCamera.new()
	_photo_camera.player = player
	_photo_camera.run = run
	_photo_camera.director = _photo_director
	_photo_camera.figures = _figures
	_photo_camera.events = _events
	_photo_camera.enabled = descent
	add_child(_photo_camera)
	_photo_camera.photo_documented.connect(_on_photo_documented)
	_photo_camera.first_raise.connect(
		func(): _show_event_message("PHOTOGRAPH WHAT IS WRONG"))
	_music = AudioStreamPlayer.new()
	_music.bus = SoundBank.GAME_BUS
	_music.volume_db = -50.0
	add_child(_music)
	# Decide before the first note: `_build_title` runs several lines later, and
	# starting a floor track only to crossfade it out is audible.
	_title_music = _will_show_title()
	if _title_music:
		_set_world_audio(false)
	_switch_music(active_level)
	_build_ui()
	_configure_level_transitions()
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
	_dev_tools.schedule_screenshot(player, get_viewport(), opts.screenshot,
		opts.shot_delay)
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
	_discard_pending_mutation_reveal()
	var route_started := Time.get_ticks_usec()
	var route := DescentRoute.build(_level_seed(level), level, floor_idx)
	var route_ready := Time.get_ticks_usec()
	var topology := DescentTopology.new(_level_seed(level), level)
	route.set_topology(topology)
	topology.plan_floor(route)
	var topology_ready := Time.get_ticks_usec()
	var total_ms := float(topology_ready - route_started) / 1000.0
	if total_ms >= 8.0:
		print("Descent planning: route %.1fms, realities %.1fms, total %.1fms" % [
			float(route_ready - route_started) / 1000.0,
			float(topology_ready - route_ready) / 1000.0, total_ms])
	if _progress_enabled and _descent_progress.has_checkpoint() \
			and _descent_progress.run_seed == world_seed:
		var saved := _descent_progress.mutation_state_for_floor(floor_idx)
		if not saved.is_empty() and int(saved.get("generation", 0)) \
				== DescentTopology.GENERATION_VERSION:
			var visited_signatures: Array[String] = []
			var raw_signatures: Variant = saved.get("visited_signatures", [])
			if raw_signatures is Array or raw_signatures is PackedStringArray:
				for value in raw_signatures:
					visited_signatures.append(str(value))
			topology.restore_signatures(
				str(saved.get("signature", "")), visited_signatures)
	route.refresh_topology()
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
		cm.descent_tape_watched = run.tape_watched
		cm.descent_broken_station_tried = run.broken_station_tried
		if _progress_enabled and _descent_progress.has_checkpoint() \
				and _descent_progress.run_seed == world_seed:
			cm.restore_runtime_state(
				_descent_progress.runtime_state_for_floor(run.floor_idx))
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
		_corner_apparitions.topology = descent_route.topology \
			if descent_route != null else null
	if descent:
		if _photo_director == null:
			_photo_director = PhotoDirector.new()
			_photo_director.debug_visible = _photo_debug
			add_child(_photo_director)
			_photo_director.documented_changed.connect(_update_photo_line)
		var known_photo_ids: Array = []
		if _progress_enabled and _descent_progress.has_checkpoint() \
				and _descent_progress.run_seed == world_seed:
			known_photo_ids = _descent_progress.photo_ids_for_floor(
				run.floor_idx)
		# Connected before warm_up so the first streamed cells can already
		# carry their evidence.
		_photo_director.configure(descent_route, run.floor_idx, cm,
			known_photo_ids)
		if _photo_camera != null:
			_photo_camera.director = _photo_director
		if _photo_debug:
			for at in _photo_director.plan:
				print("photo anomaly %s type %d required %s at %s" % [
					_photo_director.plan[at]["id"],
					int(_photo_director.plan[at]["type"]),
					str(_photo_director.plan[at]["required"]), str(at)])
	Chunk.prewarm_theme_content(_level_seed(level), level)
	level_root.add_child(cm)
	if descent:
		_configure_mutation_coordinator()
	cm.warm_up(Vector2i(floori(around.x / ChunkManager.CELL), floori(around.z / ChunkManager.CELL)))


func _configure_mutation_coordinator() -> void:
	_mutation_coordinator = DescentMutationCoordinator.new()
	_mutation_coordinator.configure(cm, run, descent_route, player,
		_figures, _passers, _mutation_mode_ready,
		_persist_committed_mutation)
	_mutation_coordinator.committed.connect(_on_mutation_committed)


func _configure_level_transitions() -> void:
	_transitions = LevelTransitionController.new()
	add_child(_transitions)
	var port := LevelTransitionPort.new()
	port.active_level = func() -> int: return active_level
	port.set_active_level = func(value: int) -> void: active_level = value
	port.descent_mode = func() -> bool: return descent
	port.player = func() -> Player: return player
	port.world_3d = func() -> World3D: return get_world_3d()
	port.level_seed = _level_seed
	port.level_root = func() -> Node3D: return level_root
	port.detach_level = func(outgoing: Node3D) -> void: remove_child(outgoing)
	port.reset_floor_presence = _reset_transition_presence
	port.switch_music = _switch_music
	port.prepare_destination = _prepare_transition_destination
	port.build_level = _build_level
	port.post_build = _finish_transition_build
	port.sealed_descent_arrival = func() -> bool:
		return descent and descent_route != null \
			and descent_route.origin_wall >= 0
	_transitions.configure(port, _fade, _warp, DEFAULT_SPAWN,
		PORTAL_ARRIVE, PORTAL_ARRIVE_DEFAULT)


func _reset_transition_presence() -> void:
	_figures.despawn()
	_whispers.stop()
	_heart.reset()


func _prepare_transition_destination(level: int, pos: Vector3,
		exact: bool, yaw: float) -> Dictionary:
	if descent and (descent_route == null or descent_route.theme != level):
		descent_route = _create_descent_route(level, run.floor_idx)
		_print_descent_route()
		return _descent_arrival(level)
	return {"position": pos, "exact": exact, "yaw": yaw}


func _finish_transition_build(level: int) -> void:
	_events.set_level(level_root)
	player.world_seed = _level_seed(level)
	player.level_theme = level
	player.water_y = _water_level_for(level)
	we.environment = _build_env(level)
	ambience.queue_free()
	ambience = Ambience.new(level)
	add_child(ambience)
	if _title_music:
		ambience.stop()


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
			_post_enabled = _post_process.toggle_enabled()
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
	_transitions.clear_saved_positions()
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_transitions.clear_saved_positions()
	_set_mode_hint()
	_build_title(true)


func _switch_level(level: int) -> void:
	_transitions.switch_wander(level)


## Stepping into a swirling portal: emerge in the same cell of another world.
func _on_portal(dest: int, cellv: Vector2i) -> void:
	_transitions.enter_portal(dest, cellv)


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
	_set_tape_audio_hold(on)
	# The recording owns the screen: no needle over the footage, and nothing
	# in the building moves until it lets go — the ambient figures are held by
	# the run's passive state.
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(not on)
	# The footage fills the screen alone: the whole camcorder OSD (frame,
	# REC, meters, captions) leaves with the viewfinder, not just the needle.
	if _osd_layer != null:
		_osd_layer.visible = not on
	# Playback's CRT look lives on the TV's own screen shader; the
	# full-screen pass would double it over the whole display.
	if _post_process != null:
		_post_process.hold_for_tape(on)
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
## The altar asks before playing the objective tape: is the floor proven?
## An empty plan (a degenerate route that could place nothing) never
## soft-locks the run.
func descent_photo_requirement_met() -> bool:
	if not descent or _photo_director == null \
			or _photo_director.plan.is_empty():
		return true
	return _photo_director.requirement_met()


func descent_photo_refusal_caption() -> String:
	var count := 0
	if _photo_director != null:
		count = _photo_director.documented_count()
	return "THE TAPE WANTS PROOF — PHOTOGRAPH WHAT IS WRONG — %d/%d" % [
		count, PhotoDirector.REQUIRED]


func _on_photo_documented(_anomaly_id: String, count: int,
		required: int, caption: String) -> void:
	# The circle on the print says where; the caption names the wrongness —
	# without it a counted shot of something subtle read as arbitrary.
	if caption.is_empty():
		_show_event_message("PHOTOGRAPH %d / %d" % [count, required])
	else:
		_show_event_message("PHOTOGRAPH %d / %d — %s" % [
			count, required, caption])
	# The last photograph gets a heading without waiting for a tape refusal:
	# at REQUIRED-1 the EVIDENCE counter comes up on its own (2026-08-19 —
	# hunting the final anomaly blind was the feature's last frustration).
	# A live counter walks to the next nearest target; satisfaction retires it.
	if is_instance_valid(_descent_hud):
		if count >= required:
			_descent_hud.evidence_target = Vector3.INF
		elif count == required - 1 \
				or _descent_hud.evidence_target != Vector3.INF:
			_grant_evidence_hint()
	if _post_process != null:
		_post_process.damage_hit(0.12)
	if _progress_enabled and _descent_progress.has_checkpoint() \
			and _descent_progress.run_seed == world_seed \
			and _photo_director != null and run != null:
		_descent_progress.record_photo_ids(run.floor_idx,
			_photo_director.documented_ids())


func _update_photo_line(count: int, required: int) -> void:
	if is_instance_valid(_descent_hud):
		_descent_hud.set_photo_progress(count, required)


func _on_photo_proximity(value: float, los: float) -> void:
	if _vf_frame != null:
		_vf_frame.interference = value
	if is_instance_valid(_descent_hud):
		_descent_hud.set_photo_proximity(los)
	# The first time the warning lands, say how the hunt works — the nearest
	# anomaly may be photo-only writing, invisible until the sweep.
	if los > 0.14 and not _photo_sweep_hinted and descent and run != null \
			and not run.ended:
		_photo_sweep_hinted = true
		_show_event_message("RAISE THE CAMERA (C) — SWEEP UNTIL IT FOCUSES")


func descent_commit_refused(reason: String) -> void:
	if not descent:
		return
	_show_event_message(reason, true)
	_post_process.damage_hit(0.25)
	# A photo refusal is the one place the hunt can dead-end (the route spine
	# is not mandatory, so a floor can be walked without meeting evidence).
	# The building relents: the HUD counts metres to the nearest undocumented
	# anomaly for the rest of the floor.
	_grant_evidence_hint()


func _grant_evidence_hint() -> void:
	if _photo_director == null or player == null \
			or not is_instance_valid(_descent_hud):
		return
	if _photo_director.requirement_met():
		return
	_descent_hud.evidence_target = _photo_director.nearest_undocumented(
		player.global_position)


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
		_queue_photo_brief()
		return
	player.set_rumble(0.22)
	var settle := create_tween()
	settle.tween_method(func(v: float): player.set_rumble(v), 0.22, 0.0, 1.1)
	var reveal_delay := create_tween()
	reveal_delay.tween_interval(0.85)
	reveal_delay.tween_callback(_finish_reveal_arrival.bind(floor_name))


func _finish_reveal_arrival(floor_name: String) -> void:
	if not descent or run == null or run.ended or cm == null:
		return
	var chunk := cm.chunk_at(descent_route.origin)
	if chunk != null and chunk.has_descent_arrival():
		_play_descent_cue(SoundBank.ding(), -8.0)
		chunk.open_descent_arrival()
	_show_event_message("FLOOR %d — %s" % [
		run.floor_idx + 1, floor_name.to_upper()])
	_queue_photo_brief()


## The floor's second objective, told once per arrival right after the floor
## card: the tape wants evidence, and the counter beside the lift distance
## keeps score. Floor 1 spells the rule out; later floors just restate it.
func _queue_photo_brief() -> void:
	if not descent or _photo_director == null \
			or _photo_director.plan.is_empty() \
			or _photo_director.requirement_met():
		return
	var brief := create_tween()
	brief.tween_interval(3.3)
	brief.tween_callback(_show_photo_brief)


func _show_photo_brief() -> void:
	if not descent or run == null or run.ended or _photo_director == null \
			or _photo_director.requirement_met():
		return
	var count := _photo_director.documented_count()
	var required := _photo_director.required_count()
	if run.floor_idx == 0 and count == 0:
		_show_event_message(
			"THE TAPE WANTS PROOF — PHOTOGRAPH %d THINGS THAT ARE WRONG"
			% required)
	else:
		_show_event_message("PHOTOGRAPH WHAT IS WRONG — %d/%d"
			% [count, required])


func _connect_descent_run() -> void:
	run.world_seed = world_seed
	if _director != null:
		run.horror_director = _director
	# Runs are created at boot, at a summary restart and from the title; the
	# camera must follow the live one or it stays dead outside CLI boots.
	if _photo_camera != null:
		_photo_camera.run = run
		_photo_camera.enabled = true
	run.pinned_attention = _attention_override
	run.blackout_mutation_validator = _can_commit_blackout_mutation
	run.blackout_mutation_ranker = _rank_blackout_mutation_visibility
	run.blackout_mutation_fallback_ranker = _rank_blackout_mutation_frustum
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
	run.blackout_mutation_requested.connect(_on_blackout_mutation)
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
	# Descent converts sprint time into attention; leaving the controller enabled
	# makes that existing risk/reward rule reachable.
	player.allow_sprint = true
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
	var delay := create_tween()
	delay.tween_interval(0.4)
	delay.tween_callback(_dev_play_tape_now)


func _dev_play_tape_now() -> void:
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
		_bleed_bed.bus = SoundBank.GAME_BUS
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
	var pc := Vector2i(floori(player.position.x / WorldGen.CELL_SIZE),
		floori(player.position.z / WorldGen.CELL_SIZE))
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
	if _photo_director != null:
		_descent_hud.set_photo_progress(_photo_director.documented_count(),
			_photo_director.required_count())


func suspend_descent_rules() -> void:
	if descent and run != null:
		run.suspend_rules()


func _on_descent_lift() -> void:
	if not descent or run == null or run.ended or _switching \
			or run.is_last_floor():
		return
	if is_instance_valid(_descent_hud):
		_descent_hud.set_active(false)
	_persist_current_runtime_state()
	run.suspend_rules()
	run.floor_idx += 1
	run.prepare_floor()
	var next_theme := run.theme()
	# Route/reality planning happens only after the fade reaches black.
	descent_route = null
	await _jump_to(next_theme, Vector3.INF, false, true)
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
	_transitions.clear_saved_positions()
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_transitions.clear_saved_positions()
	_switching = false
	_dying = false
	_set_mode_hint()
	_build_title(true)


func _on_descent_attention(_value: float) -> void:
	if not descent:
		return
	var threat := run.threat() if run != null else 0.0
	if _director != null:
		_director.set_pressure(threat)
	_post_process.set_corruption(threat)
	if _figures != null:
		_figures.interval_scale = lerpf(1.0, 0.35, threat) \
			* (run.figure_interval_scale() if run != null else 1.0)


## The flat direction from the player toward the next route cell, or zero when
## the player is off the route (or standing on the target). Feeds the whisper
## bias; deliberately never rendered.
func _whisper_route_bias() -> Vector3:
	if descent_route == null or player == null:
		return Vector3.ZERO
	var cell := Vector2i(floori(player.global_position.x / WorldGen.CELL_SIZE),
		floori(player.global_position.z / WorldGen.CELL_SIZE))
	var next := descent_route.next_from(cell)
	if next == cell:
		return Vector3.ZERO
	var centre := Vector3((float(next.x) + 0.5) * WorldGen.CELL_SIZE, 0.0,
		(float(next.y) + 0.5) * WorldGen.CELL_SIZE)
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
	groan.bus = SoundBank.HALL_BUS
	groan.stream = SoundBank.creak()
	groan.volume_db = -11.0
	groan.max_distance = 28.0
	groan.unit_size = 8.0
	add_child(groan)
	groan.global_position = player.global_position + Vector3(0, 1.0, 0)
	groan.finished.connect(groan.queue_free)
	groan.play()
	var base := 1.0 + run.threat() * 1.6
	_post_process.pulse_noise(minf(3.0, base + 0.7), base, 0.32)
	_post_process.damage_hit(0.78)


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
		if _pending_mutation_reveal:
			_pending_mutation_reveal = false
			if _pending_mutation_reveal_at != Vector3.INF:
				_play_descent_cue_at(SoundBank.creak(), -2.0,
					_pending_mutation_reveal_at)
				_spawn_mutation_reveal(_pending_mutation_reveal_at,
					_pending_mutation_reveal_descriptor)
			else:
				_play_descent_cue(SoundBank.creak(), -7.0)
			# Promise the glow only when a positioned reveal actually
			# spawned; a bare architectural change gets an honest caption.
			_play_descent_cue(SoundBank.thud(), -13.0)
			if _pending_mutation_reveal_at != Vector3.INF:
				_show_event_message("POWER RESTORED — FOLLOW THE GLOW", true)
			else:
				_show_event_message("POWER RESTORED — SOMETHING CHANGED", true)
			_pending_mutation_reveal_at = Vector3.INF
			_pending_mutation_reveal_descriptor = {}
		else:
			# A failed preflight postpones the blackout, so this path is only a
			# defensive fallback for teardown/level-switch races.
			_play_descent_cue(SoundBank.ding(), -10.0)
			_show_event_message("POWER RESTORED")


func _spawn_mutation_reveal(at: Vector3,
		descriptor: Dictionary = {}) -> Node3D:
	# Blackouts cannot overlap, but clearing a surviving effect makes this safe
	# under dev forcing and level-transition races as well.
	for old in get_tree().get_nodes_in_group("mutation_reveal_effect"):
		if is_instance_valid(old):
			old.queue_free()
	var reveal := MUTATION_REVEAL_EFFECT.new() as Node3D
	add_child(reveal)
	reveal.global_position = at
	if reveal.has_method("configure"):
		reveal.call("configure", descriptor)
	return reveal


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
		_post_process.damage_hit(0.35)


## It found them. The player never sees what it was — one frame of something
## at the lens, the loudest sound in the game, and the run is over.
func _on_blackout_ambush() -> void:
	if not descent or run == null or run.ended or _dying:
		return
	_dying = true
	_blackout_locate_cue = 0
	var pick := Sfx.random_scare()
	_play_descent_cue(pick[0], -2.0)
	_post_process.damage_hit(1.0)
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
	cue.bus = SoundBank.GAME_BUS
	cue.stream = stream
	cue.volume_db = volume
	add_child(cue)
	cue.finished.connect(cue.queue_free)
	cue.play()


func _play_descent_cue_at(stream: AudioStream, volume: float,
		at: Vector3) -> void:
	var cue := AudioStreamPlayer3D.new()
	cue.stream = stream
	cue.volume_db = volume
	cue.unit_size = 5.0
	cue.max_distance = 36.0
	cue.bus = SoundBank.HALL_BUS
	add_child(cue)
	cue.global_position = at
	cue.finished.connect(cue.queue_free)
	cue.play()


func _on_descent_anomaly(at: Vector2i, kind: int) -> void:
	if not descent or cm == null or descent_route == null \
			or at == descent_route.target or at == descent_route.origin:
		return
	cm.set_anomaly(at, kind)


func _on_blackout_mutation(proposal: TopologyDelta,
		assistance_requested: bool) -> void:
	if _mutation_coordinator != null:
		_mutation_coordinator.begin(proposal, assistance_requested)


func _mutation_mode_ready() -> bool:
	return descent and not _switching and not _dying


func _persist_committed_mutation(topology: DescentTopology) -> void:
	if not _progress_enabled or _descent_progress.run_seed != world_seed:
		return
	var visited_signatures: Array[String] = []
	for state_id in topology.state_history():
		visited_signatures.append(topology.state_signature(state_id))
	_descent_progress.record_mutation_state(run.floor_idx,
		topology.current_state_id(), topology.state_history(),
		topology.state_signature(), visited_signatures)
	_persist_current_runtime_state()


func _persist_current_runtime_state() -> void:
	if not _progress_enabled or _descent_progress == null \
			or _descent_progress.run_seed != world_seed \
			or run == null or cm == null:
		return
	_descent_progress.record_runtime_state(
		run.floor_idx, cm.runtime_state_snapshot())


func _on_mutation_committed(_transaction: DescentMutationTransaction,
		reveal_at: Vector3, reveal: Dictionary) -> void:
	_discard_pending_mutation_reveal()
	_pending_mutation_reveal = true
	_pending_mutation_reveal_at = reveal_at
	_pending_mutation_reveal_descriptor = reveal.duplicate()


func _discard_pending_mutation_reveal() -> void:
	var ghost: Variant = _pending_mutation_reveal_descriptor.get("ghost", null)
	if is_instance_valid(ghost) and ghost is Node:
		(ghost as Node).free()
	_pending_mutation_reveal = false
	_pending_mutation_reveal_at = Vector3.INF
	_pending_mutation_reveal_descriptor = {}


## Generated topology proves that a state is globally navigable. This final
## live preflight proves that swapping its rooms now will not materialize a
## wall around an actor, interrupt a demanded interaction, or detach a charge
## cable from a station that is about to be rebuilt.
func _can_commit_blackout_mutation(proposal: TopologyDelta) -> bool:
	return _mutation_coordinator != null \
		and _mutation_coordinator.can_commit(proposal)


func _rank_blackout_mutation_visibility(proposal: TopologyDelta) -> float:
	return _mutation_coordinator.visibility_rank(proposal) \
		if _mutation_coordinator != null \
		else DescentMutationCoordinator.NO_VISIBLE_WITNESS


func _rank_blackout_mutation_frustum(proposal: TopologyDelta) -> float:
	return _mutation_coordinator.visibility_rank(proposal, false) \
		if _mutation_coordinator != null \
		else DescentMutationCoordinator.NO_VISIBLE_WITNESS


func _on_descent_ended(won: bool) -> void:
	_persist_current_runtime_state()
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
	descent_route = null
	await _jump_to(run.theme(), Vector3.INF, false, true)
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
	if _photo_camera != null:
		_photo_camera.enabled = false
		_photo_camera.run = null
	if is_instance_valid(_bleed_bed):
		_bleed_bed.queue_free()
	_bleed_bed = null
	_bleed_captured = false
	if is_instance_valid(_descent_hud):
		_descent_hud.queue_free()
	_descent_hud = null
	_transitions.clear_saved_positions()
	player.allow_sprint = true
	player.set_rumble(0.0)
	_events.descent_mode = false
	_set_presence(Presence.SILENT)
	_figures.interval_scale = 1.0
	_set_mode_hint()
	_post_process.set_noise(1.0)
	var spawn := _safe_arrival(0, Vector2i.ZERO, DEFAULT_SPAWN)
	await _jump_to(0, spawn, false)
	_transitions.clear_saved_positions()
	_build_title(true)


func terminal_activity(page: int) -> void:
	if _events != null:
		_events.terminal_response(page)


func door_activity() -> void:
	if _events != null:
		_events.door_response()


## Compatibility seam for audits and older callers; policy is controller-owned.
func _safe_arrival(level: int, cellv: Vector2i, base: Vector3) -> Vector3:
	if _transitions != null:
		return _transitions.safe_arrival(level, cellv, base)
	return LevelTransitionController.safe_arrival_for_seed(
		level, cellv, base, _level_seed(level))


func _jump_to(level: int, pos: Vector3, via_portal: bool, exact := false,
		yaw := NAN) -> void:
	await _transitions.jump_to(level, pos, via_portal, exact, yaw)


func _settle_initial_arrival() -> void:
	await _transitions.settle_initial_arrival()


func _process(dt: float) -> void:
	_check_torch_hint()
	_post_process.update()
	_update_entity_halo(dt)
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
	if _dev_tools != null:
		_dev_tools.update(dt)


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


## With the post pass on, render a 480-line widescreen source (≈854x480 at
## 16:9, bilinear). The CRT material resamples that onto its 720x320 signal
## grid; the RECOVERED TAPE material runs an 854x480 grid so it degrades the
## real SD picture — bandwidth, not pixel count. With the tube off the world
## returns to full native resolution.
func _apply_scaling() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if _post_enabled:
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
	var scale := VhsOsd.hud_scale(viewport_size)
	var inset := VhsOsd.safe_inset(viewport_size)
	# Every size here assumes the OSD is read THROUGH the tube: the post pass
	# emulates a 320-row signal, so no text may drop under ~5% of the
	# viewport height (about 16 emulated rows) and everything sits inside the
	# title-safe area the viewfinder brackets mark.
	if _vf_frame != null:
		_vf_frame.inset = inset
		_vf_frame.arm = 40.0 * scale
		_vf_frame.line = 3.0 * scale
		_vf_frame.rec_font_size = roundi(40.0 * scale)
	# The controls strip is a centred menu line low in the frame, clear of the
	# REC lamp, the counters and the meters; it fades out on its own timer.
	_hint.size = Vector2(viewport_size.x - inset.x * 2.0, 84.0 * scale)
	_hint.position = Vector2(inset.x, viewport_size.y - inset.y - 168.0 * scale)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", roundi(32.0 * scale))

	_interact_panel.custom_minimum_size = Vector2(760.0, 80.0) * scale
	_interact_panel.position = Vector2(
		(viewport_size.x - _interact_panel.custom_minimum_size.x) * 0.5,
		viewport_size.y - inset.y - 100.0 * scale)
	_interact_hint.add_theme_font_size_override("font_size", roundi(50.0 * scale))

	_event_panel.custom_minimum_size = Vector2(
		viewport_size.x - inset.x * 2.0, 88.0 * scale)
	_event_panel.position = Vector2(inset.x, viewport_size.y * 0.5 + 24.0 * scale)
	_event_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_hint.custom_minimum_size = Vector2(
		viewport_size.x - inset.x * 2.0, 0.0)
	_event_hint.add_theme_font_size_override("font_size", roundi(56.0 * scale))

	_battery_meter.font_size = roundi(40.0 * scale)
	_battery_meter.size = Vector2(320.0, 94.0) * scale
	_battery_meter.position = Vector2(
		viewport_size.x - inset.x - 12.0 * scale - _battery_meter.size.x,
		inset.y + 6.0 * scale)

	_stamina_meter.font_size = roundi(40.0 * scale)
	_stamina_meter.size = Vector2(320.0, 86.0) * scale
	_stamina_meter.position = Vector2(inset.x + 12.0 * scale,
		viewport_size.y - inset.y - 6.0 * scale - _stamina_meter.size.y)

	_charging_label.add_theme_font_size_override("font_size", roundi(44.0 * scale))
	_charging_meter.custom_minimum_size = Vector2(640.0, 40.0) * scale
	_charging_panel.custom_minimum_size = Vector2(640.0 * scale, 0.0)
	_charging_panel.position = Vector2(
		(viewport_size.x - 640.0 * scale) * 0.5,
		viewport_size.y - inset.y - 220.0 * scale)


func _toggle_post_mode() -> void:
	if _post_process == null:
		return
	var label := _post_process.toggle_mode()
	ShadowFigure.set_tape_look(_post_process.is_found_footage())
	if _title == null:
		_show_event_message("VIDEO MODE — " + label)
	_set_mode_hint()


## Everything the game makes routes through Game. Spatial sounds first pass
## through Hall for reverb; Hall then sends into Game. Master is deliberately
## reserved for the VCR recording while it owns the screen.
func _set_world_audio(on: bool) -> void:
	var idx := AudioServer.get_bus_index(SoundBank.GAME_BUS)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not on)
	if is_instance_valid(ambience):
		if on:
			if not ambience.playing:
				ambience.play()
		else:
			ambience.stop()


## Shared buses: Game owns the mute boundary; Hall adds reverb to spatial
## emitters and then feeds Game.
func _setup_audio_bus() -> void:
	var game_idx := AudioServer.get_bus_index(SoundBank.GAME_BUS)
	if game_idx < 0:
		game_idx = AudioServer.bus_count
		AudioServer.add_bus(game_idx)
		AudioServer.set_bus_name(game_idx, SoundBank.GAME_BUS)
	AudioServer.set_bus_send(game_idx, "Master")
	var idx := AudioServer.get_bus_index(SoundBank.HALL_BUS)
	if idx >= 0:
		AudioServer.set_bus_send(idx, SoundBank.GAME_BUS)
		return
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, SoundBank.HALL_BUS)
	AudioServer.set_bus_send(idx, SoundBank.GAME_BUS)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.8
	rev.damping = 0.5
	rev.wet = 0.25
	AudioServer.add_bus_effect(idx, rev)


func _set_tape_audio_hold(on: bool) -> void:
	var idx := AudioServer.get_bus_index(SoundBank.GAME_BUS)
	if idx < 0:
		return
	if on:
		if _tape_audio_held:
			return
		_tape_audio_held = true
		_tape_game_bus_was_muted = AudioServer.is_bus_mute(idx)
		AudioServer.set_bus_mute(idx, true)
	elif _tape_audio_held:
		AudioServer.set_bus_mute(idx, _tape_game_bus_was_muted)
		_tape_audio_held = false


## The floor's WorldEnvironment. Kept as a method because _switch_level and the
## runtime audits call it; the settings themselves live in EnvBuilder.
func _build_env(theme: int) -> Environment:
	return EnvBuilder.build(theme)


func _build_ui() -> void:
	# Screen treatment over the 3D view, under UI. V enables/disables it and B
	# changes recording media between the established CRT and recovered tape.
	_post_process = PostProcessController.new()
	add_child(_post_process)
	_post_process.setup(self, _found_footage_requested, _post_enabled)
	ShadowFigure.set_tape_look(_post_process.is_found_footage())

	var cl := CanvasLayer.new()
	cl.layer = 2
	_osd_layer = cl
	var lb := VhsOsd.make_label(16, Color(0.92, 0.96, 0.90, 0.80))
	_hint = lb
	_set_mode_hint()
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(lb)
	# Viewfinder chrome first so every other readout draws over it.
	_vf_frame = VhsOsd.Frame.new()
	cl.add_child(_vf_frame)
	if _photo_camera != null:
		_photo_camera.proximity_changed.connect(_on_photo_proximity)

	_interact_panel = PanelContainer.new()
	_interact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_panel.visible = false
	_interact_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cl.add_child(_interact_panel)
	_interact_hint = VhsOsd.make_label(28)
	_interact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_panel.add_child(_interact_hint)

	_event_panel = PanelContainer.new()
	_event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_panel.modulate.a = 0.0
	_event_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cl.add_child(_event_panel)
	_event_hint = VhsOsd.make_label(30)
	_event_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_panel.add_child(_event_hint)

	_battery_meter = VhsOsd.Meter.new()
	_battery_meter.text = "BATT"
	_battery_meter.battery_glyph = true
	_battery_meter.segments = 5
	_battery_meter.right_align = true
	cl.add_child(_battery_meter)

	_stamina_meter = VhsOsd.Meter.new()
	_stamina_meter.text = "SPRINT"
	_stamina_meter.segments = 10
	_stamina_meter.low_threshold = Player.STAMINA_REARM / Player.STAMINA_MAX
	_stamina_meter.warn_threshold = 0.35
	cl.add_child(_stamina_meter)

	_charging_panel = VBoxContainer.new()
	_charging_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charging_panel.visible = false
	_charging_panel.add_theme_constant_override("separation", 6)
	cl.add_child(_charging_panel)
	_charging_label = VhsOsd.make_label(26)
	_charging_label.text = "CHARGING · E OR F TO DISCONNECT"
	_charging_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charging_panel.add_child(_charging_label)
	_charging_meter = VhsOsd.Meter.new()
	_charging_meter.blink_when_low = false
	_charging_meter.segments = 12
	_charging_meter.low_threshold = -1.0
	_charging_meter.warn_threshold = -1.0
	_charging_panel.add_child(_charging_meter)
	# fullscreen fade for level transitions
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_fade)
	add_child(cl)
	_warp = AudioStreamPlayer.new()
	_warp.bus = SoundBank.GAME_BUS
	_warp.stream = SoundBank.warp()
	_warp.volume_db = -6.0
	add_child(_warp)
	_apply_hud_scaling()


## The recording breaks around the thing it cannot hold: project the nearest
## live figure into screen space and hand the post pass an interference halo.
## Rises fast, decays slow, so a figure crossing a doorway leaves a wake.
func _update_entity_halo(dt: float) -> void:
	if _post_process == null or player == null:
		return
	var target := 0.0
	var pos := Vector2(0.5, 0.5)
	var radius := 0.25
	# Presence is distance only: the nearest hostile figure, in frame or at
	# your back, feeds the tape's corruption ladder.
	var presence := 0.0
	if descent and _figures != null and not _dying:
		var cam := player.cam
		var viewport_size := Vector2(get_viewport().size)
		for figure in _figures.active_figures():
			var head: Vector3 = figure.global_position + Vector3(0, 1.2, 0)
			var d := cam.global_position.distance_to(head)
			presence = maxf(presence, clampf(1.0 - (d - 2.0) / 18.0, 0.0, 1.0))
			if cam.is_position_behind(head):
				continue
			if d > 24.0:
				continue
			var s := clampf(1.0 - (d - 2.0) / 22.0, 0.0, 1.0) * 0.55
			if s <= target:
				continue
			target = s
			pos = cam.unproject_position(head) / viewport_size
			radius = clampf(1.3 / maxf(d, 1.5), 0.07, 0.28)
	_halo_amt = lerpf(_halo_amt, target,
		minf(1.0, dt * (10.0 if target > _halo_amt else 3.5)))
	if _halo_amt > 0.001 or target > 0.0:
		_post_process.set_entity_halo(pos, radius, _halo_amt)
	_post_process.set_presence(presence)


func _update_flashlight_hud() -> void:
	if player == null or _battery_meter == null:
		return
	var level := player.flashlight_charge()
	_battery_meter.value = level
	_charging_meter.value = level
	_charging_panel.visible = player.is_charging()
	_stamina_meter.value = player.stamina()


func _on_interaction_prompt(text: String) -> void:
	if _interact_hint != null:
		_interact_hint.text = text
		_interact_panel.visible = not text.is_empty()


func _show_event_message(text: String, alert := false) -> void:
	if _event_hint == null or _event_panel == null:
		return
	VhsOsd.set_ink(_event_hint, VhsOsd.RED if alert else VhsOsd.INK)
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
	var delay := create_tween()
	delay.tween_interval(1.0)
	delay.tween_callback(_finish_preview_captions)


func _finish_preview_captions() -> void:
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
func _build_title(force := false) -> void:
	# skips_title() means "boot straight into play" — it must not also mean
	# "Q can never reach the title again": in every --mode=descent session
	# the Y confirm silently dumped the player into a titleless wander world
	# (2026-08-19). Boot skips; deliberate returns force.
	if opts.skips_title() and not force:
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
	player.allow_sprint = true
	player.set_process_unhandled_input(false)
	player.reset_descent_resources()
	_transitions.clear_saved_positions()
	run = DescentRun.new()
	run.floor_idx = floor_idx
	_connect_descent_run()
	run.prepare_floor()
	add_child(run)
	descent_route = null
	_events.descent_mode = true
	_set_presence(Presence.SILENT)
	_set_mode_hint()
	await _jump_to(run.theme(), Vector3.INF, false, true)
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
		_hint.text = "WASD move  ·  Shift sprint  ·  E use  ·  F torch  ·  C camera + Space photo  ·  B mode  ·  Q title"
	else:
		_hint.text = "WASD move  ·  Shift run  ·  E use  ·  F torch  ·  1-9 / 0 / − floors  ·  V filter  ·  B mode  ·  Q title"


## The Poolrooms are the only floor with standing water. Everywhere else the
## surface is parked far below the world so the player's wading and ladder
## code costs nothing and can never trigger.
func _water_level_for(level: int) -> float:
	return Chunk.POOL_WATER_Y if level == 9 else -1.0e9
