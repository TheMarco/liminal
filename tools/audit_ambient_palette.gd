extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var events := EnvironmentEvents.new()
	root.add_child(events)
	events.set_process(false)
	var expected := ["trolley", "vent", "printer", "ticking", "ballast", "metal", "pipes", "drips", "organic"]
	check(AmbientPalette.RECORDINGS.size() == expected.size(), "room recording count changed")
	var reached := {}
	for kind in expected:
		check(AmbientPalette.RECORDINGS.has(kind), "room recording not registered: %s" % kind)
		var recording: AudioStream = AmbientPalette.stream(kind)
		if recording == null:
			check(false, "missing room recording: %s" % kind)
		else:
			check(recording is AudioStreamMP3, "room recording is not MP3: %s" % kind)
			if recording is AudioStreamMP3:
				check(not recording.loop, "room recording loops: %s" % kind)
			check(recording.resource_path == "res://sounds/room_events/%s.mp3" % kind, "wrong room recording path: %s" % kind)
			check(recording == AmbientPalette.stream(kind), "room recording is not cached: %s" % kind)
			check(recording.get_length() > 0 and recording.get_length() <= 4, "invalid event duration: %s" % kind)
	for alias in ["knocks", "creak"]:
		var alias_stream: AudioStream = AmbientPalette.stream(alias)
		if alias_stream == null:
			check(false, "missing alias stream: %s" % alias)
		else:
			check(alias_stream is AudioStreamWAV, "alias is not WAV: %s" % alias)
			if alias_stream is AudioStreamWAV:
				check(alias_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "alias loops: %s" % alias)
			var expected_alias: AudioStream = SoundBank.thud() if alias == "knocks" else SoundBank.creak()
			check(alias_stream == expected_alias, "alias does not use SoundBank resource: %s" % alias)
			check(alias_stream == AmbientPalette.stream(alias), "alias is not cached: %s" % alias)
	var level := Node3D.new()
	root.add_child(level)
	for theme in AmbientPalette.PALETTES:
		events.set_level(level, theme)
		var previous := ""
		var seen := {}
		for i in 30:
			var kind := events.next_room_event()
			check(kind != previous, "immediate ambient repeat")
			previous = kind
			seen[kind] = true
			reached[kind] = true
			var recording: AudioStream = AmbientPalette.stream(kind)
			if recording == null:
				check(false, "palette references missing event")
			else:
				check(recording.get_length() > 0 and recording.get_length() <= 4, "invalid event duration")
		check(seen.size() == 3, "floor does not use all variants")
	for kind in expected:
		check(reached.has(kind), "palettes never reach event: %s" % kind)
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	events.player = player
	events.descent_mode = true
	var director := HorrorDirector.new()
	director.enabled = true
	root.add_child(director)
	events.horror_director = director
	director.set_scripted_hold(true)
	events._time_left = 0
	events._process(1)
	check(events.get_child_count() == 0, "event ignores pacing hold")
	events.photo_response()
	check(events.get_child_count() == 0 and not events._busy, "photo fakes darkness/ignores hold")
	director.set_scripted_hold(false)
	events._bag = ["trolley"]
	events._time_left = 0
	events._process(1)
	check(events.get_child_count() == 1, "eligible event did not start")
	var sound: AudioStreamPlayer3D = events.get_child(0)
	check(is_finite(sound.volume_db), "event volume is not finite")
	check(is_equal_approx(sound.volume_db, -11.0 + AmbientPalette.gain_db("trolley")), "event volume meter trim mismatch")
	events.set_level(level, 9)
	check(not sound.playing, "audio leaks across floors")
	await process_frame
	check(events.get_child_count() == 0, "old event not cleaned up")
	events._bag = ["trolley"]
	events._play_room_event()
	check(events.get_child_count() == 1, "imported event did not start")
	await create_timer(4.0).timeout
	await process_frame
	check(events.get_child_count() == 0, "completed event player not freed")
	events.free()
	director.free()
	player.free()
	level.free()
	print("Ambient palette failures: %s" % [failures])
	quit(0 if failures.is_empty() else 1)
