extends "res://tools/lib/audit_base.gd"
## Run: godot --headless --path . --script tools/audit_test_mode.gd -- --test-mode

const SEED := 405195947
const FLOOR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
	KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS]
const THEMES := [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]


func key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func fingerprint(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"


func run() -> void:
	var normal := CliOptions.parse_args([])
	expect(not normal.test_mode and not normal.descent and not normal.skips_title(),
		"ordinary startup changed")
	var cli_descent := CliOptions.parse_args(["--mode=descent", "--nologo"])
	expect(cli_descent.descent and not cli_descent.test_mode, "ordinary CLI Descent gained floor keys")
	for args in [["--test-mode"], ["--test-mode", "--descent-floor=8", "--seed=12345"],
			["--descent-floor=8", "--seed=12345", "--test-mode"]]:
		var options := CliOptions.parse_args(PackedStringArray(args))
		expect(options.test_mode and options.descent and options.skips_title(),
			"test flag did not select direct Descent")
		expect(not options.quick_exit(), "interactive test mode exits automatically")
		if args.size() > 1:
			expect(options.descent_floor == 8 and options.world_seed == 12345,
				"test flag lost initial floor or seed")
	var protected_files := [DescentProgress.SAVE_PATH, DescentProgress.SAVE_PATH + ".bak",
		IntroPlaybackState.SAVE_PATH]
	var before := {}
	for path in protected_files:
		before[path] = fingerprint(path)
	var game := await boot_game(SEED)
	expect(game.opts.test_mode and game.descent and game._title == null,
		"test startup is not direct Descent")
	expect(not game._progress_enabled, "test mode can write campaign progress")
	expect(game._intro_state._save_path == IntroPlaybackState.TEST_SAVE_PATH,
		"intro still uses normal watch history")
	var television_history := IntroPlaybackState.new()
	expect(television_history._save_path == IntroPlaybackState.TEST_SAVE_PATH,
		"new TVs still use normal watch history")
	# Exercise the selected default profile without writing into the user's directory.
	var test_history := "/tmp/liminal-test-history-%d.cfg" % OS.get_process_id()
	IntroPlaybackState.default_save_path = test_history
	game._intro_state._save_path = test_history
	expect(game._intro_state.mark_video_viewed("audit:test-mode") == OK,
		"isolated watch history could not save")
	var reopened := IntroPlaybackState.new()
	expect(reopened.has_viewed_video("audit:test-mode"), "TVs do not share isolated watch history")
	for i in FLOOR_KEYS.size():
		expect(game._floor_theme_for_key(FLOOR_KEYS[i]) == THEMES[i], "incorrect floor key mapping")
	expect(game._floor_theme_for_key(KEY_KP_SUBTRACT) == 11, "keypad minus mapping missing")
	expect(game._floor_theme_for_key(KEY_P) == -1, "album key became a floor key")

	var initial_run_id: int = game.run.get_instance_id()
	game.opts.test_mode = false
	for code in FLOOR_KEYS:
		game._unhandled_input(key(code))
	expect(game.run.get_instance_id() == initial_run_id and not game._switching,
		"normal Descent accepted a debug floor key")
	game.opts.test_mode = true
	game._unhandled_input(key(KEY_2, false))
	game._unhandled_input(key(KEY_2, true, true))
	game._jump_test_floor(999)
	expect(game.run.get_instance_id() == initial_run_id, "release/echo/invalid destination triggered a jump")
	_expect_guards(game)

	var image := Image.create(8, 8, false, Image.FORMAT_RGB8)
	image.fill(Color.DARK_GREEN)
	game._on_album_photograph(image, {"floor": 1, "caption": "test-mode audit"})
	expect(not game._photo_album_store._persistent and game._photo_album_store.entries.size() == 1,
		"test photograph did not remain in the session album")
	for i in FLOOR_KEYS.size():
		var previous_run_id: int = game.run.get_instance_id()
		# Includes reselecting the current floor, immediate post-arrival jumps,
		# a raised camera, and an interrupted charge.
		if i == 1:
			game._photo_camera._raise(true)
		if i == 2:
			game.player._flash_charge = 1.0
			game.player.start_charging(game.level_root)
		if i == 5:
			game.run.blackout = true
			game._on_descent_blackout(true)
		game._unhandled_input(key(FLOOR_KEYS[i]))
		expect(game._switching, "floor key did not start transition: %s" % FLOOR_KEYS[i])
		game._unhandled_input(key(KEY_0)) # Must not replace an in-flight destination.
		var finished := await await_until(func(): return not game._switching, 60000)
		expect(finished, "floor transition timed out")
		if not finished:
			break
		await physics_frame
		expect(game.run.get_instance_id() != previous_run_id, "jump retained stale run")
		expect(game.descent and game.active_level == THEMES[i] and game.run.theme() == THEMES[i],
			"jump became Wander or chose wrong theme")
		expect(game.run.floor_idx == DescentRun.FIXED_ORDER.find(THEMES[i]),
			"theme uses wrong campaign depth")
		expect(game._vf_frame.recording_day_offset == game.run.floor_idx,
			"recovered-tape date did not advance with campaign depth")
		expect(game.cm.descent and game.cm.descent_floor_idx == game.run.floor_idx,
			"generated world lost Descent state")
		expect(game.descent_route == game.run.route and game.descent_route.theme == THEMES[i],
			"route does not match current run")
		expect(game._photo_camera.enabled and game._photo_camera.run == game.run \
			and game._photo_camera.director == game._photo_director and not game._photo_camera._raised,
			"camera retained stale run/viewfinder")
		expect(not game._figures.suspended and game._director.enabled and not game.run.suspended,
			"jump disabled Descent threats/rules")
		expect(not game.run.tape_watched and not game.run.lift_called \
			and not game.run.blackout and not game.cm.blackout \
			and game._photo_director.documented_count() == 0,
			"jump did not reset objectives")
		expect(not game.player.is_charging() and game.player.flashlight_charge() > 0.99,
			"jump retained charging/depleted resources")
		expect(not game._progress_enabled and game._photo_album_store.entries.size() == 1,
			"jump wrote campaign or lost session photos")
		var excluded: Array[RID] = [game.player.get_rid()]
		# The live body settles onto its floor during fade-in. At the exact
		# contact plane, rounding can count that supporting slab as an overlap
		# (observed on Data Center/Bloom). Keep a small probe clearance, as the
		# arrival resolver does, without moving the actual player.
		var probe: Vector3 = game.player.global_position + Vector3.UP * 0.03
		var clear := ArrivalSafety.is_clear(game.get_world_3d(), probe, excluded)
		if not clear:
			_print_arrival_contacts(game, excluded)
		expect(clear, "destination arrival overlaps geometry: theme %d" % THEMES[i])
		expect(ArrivalSafety.has_floor(game.get_world_3d(), game.player.global_position, excluded),
			"destination arrival has no floor")
		print("TEST_MODE_FLOOR key=%s theme=%d campaign=%d" % [
			OS.get_keycode_string(FLOOR_KEYS[i]), game.active_level, game.run.floor_idx + 1])
	for path in protected_files:
		expect(fingerprint(path) == before[path], "normal save changed: " + path)
	await teardown_game(game)
	IntroPlaybackState.default_save_path = IntroPlaybackState.SAVE_PATH
	finish("test-mode CLI, all 11 live Descent jumps, guards, resources and save isolation")


func _print_arrival_contacts(game: Node, excluded: Array[RID]) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = ArrivalSafety.RADIUS
	shape.height = ArrivalSafety.HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,
		game.player.global_position + Vector3.UP * ArrivalSafety.HEIGHT * 0.5)
	query.collision_mask = 1
	query.exclude = excluded
	print("ARRIVAL CONTACT theme=%d position=%s clear_at_3cm=%s" % [game.active_level,
		game.player.global_position, ArrivalSafety.is_clear(game.get_world_3d(),
		game.player.global_position + Vector3.UP * 0.03, excluded)])
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider: CollisionObject3D = hit.collider
		var owner: CollisionShape3D = collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape))
		print("  %s bounds=%s" % [owner.get_path(), owner.global_transform * owner.shape.get_debug_mesh().get_aabb()])


func _expect_guards(game: Node) -> void:
	var initial_run_id: int = game.run.get_instance_id()
	for field in ["_dying", "_quitting", "_descent_preparing", "_switching"]:
		game.set(field, true)
		game._unhandled_input(key(KEY_2))
		expect(game.run.get_instance_id() == initial_run_id, "jump ignored guard: " + field)
		game.set(field, false)
	for field in ["watching", "ended"]:
		game.run.set(field, true)
		game._unhandled_input(key(KEY_2))
		expect(game.run.get_instance_id() == initial_run_id, "jump ignored run guard: " + field)
		game.run.set(field, false)
	paused = true
	game._unhandled_input(key(KEY_2))
	expect(game.run.get_instance_id() == initial_run_id, "jump while paused")
	paused = false
	for entry in [["_title", TitleScreen.new()], ["_pause_menu", PauseMenu.new()],
		["_return_prompt", ReturnPrompt.new()], ["_descent_summary", DescentSummary.new()],
		["_descent_intro", DescentIntro.new()], ["_photo_album", PhotoAlbum.new()]]:
		game.set(entry[0], entry[1])
		game._unhandled_input(key(KEY_2))
		expect(game.run.get_instance_id() == initial_run_id, "jump through modal: " + entry[0])
		game.set(entry[0], null)
		entry[1].free()
	game._photo_camera._capturing = true
	game._unhandled_input(key(KEY_2))
	game._photo_camera._capturing = false
	game._photo_camera._review_left = 1.0
	game._unhandled_input(key(KEY_2))
	game._photo_camera._review_left = 0.0
	game._photo_camera._doorway_reveal_left = 1.0
	game._unhandled_input(key(KEY_2))
	game._photo_camera._doorway_reveal_left = 0.0
	expect(game.run.get_instance_id() == initial_run_id, "jump interrupted camera work")
	game.cm._staged_cells.append(Vector2i.ZERO)
	game._unhandled_input(key(KEY_2))
	game.cm._staged_cells.clear()
	expect(game.run.get_instance_id() == initial_run_id, "jump interrupted staged mutation")
	if is_instance_valid(game._realm_visit):
		var original_phase: int = game._realm_visit.phase
		for phase in [RealmExcursion.Phase.ENTERING, RealmExcursion.Phase.VISITING, RealmExcursion.Phase.RETURNING]:
			game._realm_visit.phase = phase
			game._unhandled_input(key(KEY_2))
			expect(game.run.get_instance_id() == initial_run_id, "jump interrupted realm excursion")
		game._realm_visit.phase = original_phase
