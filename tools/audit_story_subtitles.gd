extends "res://tools/lib/audit_base.gd"

func run() -> void:
	var tracks := StorySubtitles.tracks()
	var paths := VhsTapeLibrary.all_paths()
	paths.append("res://videos/intro/liminal_intro.ogv")
	paths.append("res://videos/intro/photo_tutorial.ogv")
	for path in paths:
		expect(tracks.has(path), "missing subtitle track: " + path)
		var track: Array = tracks.get(path, [])
		var nonverbal := path.ends_with("liminal_intro.ogv") or path.ends_with("short_random_06.ogv")
		expect(nonverbal or not track.is_empty(), "dialogue recording has no cues: " + path)
		var probe := VideoStreamPlayer.new()
		probe.stream = load(path)
		var duration := probe.get_stream_length()
		probe.free()
		var previous_end := 0.0
		for cue: Dictionary in track:
			expect(float(cue.start) >= previous_end and float(cue.end) > float(cue.start),
				"overlapping/out-of-order subtitle in " + path)
			expect(float(cue.end) <= duration + 0.1, "subtitle extends past movie: " + path)
			expect(str(cue.text).split("\n").size() <= 2, "subtitle exceeds two lines: " + path)
			previous_end = float(cue.end)
	var sample: Array = [{"start": 1.0, "end": 2.0, "text": "FIRST"},
		{"start": 3.0, "end": 4.0, "text": "SECOND"}]
	expect(StorySubtitles.caption_at(sample, 0.9).is_empty(), "caption appeared before speech")
	expect(StorySubtitles.caption_at(sample, 1.0) == "FIRST", "cue start missed")
	expect(StorySubtitles.caption_at(sample, 2.0).is_empty(), "caption lingered after cue")
	expect(StorySubtitles.caption_at(sample, 3.5) == "SECOND", "later playback cue missed")
	expect(StorySubtitles.caption_at(sample, 1.5) == "FIRST", "rewind did not restore earlier cue")
	var old_settings := GameSettings.current
	var model := GameSettings.new("/tmp/liminal_subtitle_audit_%d.cfg" % OS.get_process_id())
	GameSettings.current = model
	var video := VideoStreamPlayer.new()
	video.stream = load("res://videos/tapes/tape_02.ogv")
	root.add_child(video)
	var captions := StorySubtitles.new()
	root.add_child(captions)
	captions.attach(video)
	# A wide test cue makes this independent of decoder scheduling.
	captions._track = [{"start": 0.0, "end": 60.0, "text": "A readable caption"}]
	video.play()
	model.set_value("story_subtitles", true)
	captions._update_caption()
	expect(captions.visible and captions._label.text == "A readable caption", "enabled captions not visible")
	model.set_value("story_subtitles", false)
	expect(not captions.visible, "setting did not hide captions immediately")
	model.set_value("story_subtitles", true)
	video.stop()
	captions._update_caption()
	expect(not captions.visible, "stopped movie retained its caption")
	captions.free()
	video.free()
	GameSettings.current = old_settings
	finish("story subtitles")
