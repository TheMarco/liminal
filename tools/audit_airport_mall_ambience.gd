extends "res://tools/audit_shared_sounds.gd"
## Distinct room-tone recordings, looping playback and level matching.

func run() -> void:
	var streams: Array[AudioStreamMP3] = []
	for theme in [4, 7]:
		var key := "sound-airport" if theme == 4 else "sound-mall"
		var path := "res://sounds/%s.mp3" % key
		check(Sfx.has_bed(theme), "missing ambient bed: " + key)
		check(Sfx.BEDS[theme][0] == key, "wrong floor mapping: " + key)
		var bed := Sfx.bed(theme)
		var stream := bed[0] as AudioStreamMP3
		check(stream != null, "not an MP3 stream: " + key)
		if stream == null:
			continue
		streams.append(stream)
		check(stream.resource_path == path, "wrong source file: " + key)
		check(stream == Sfx.bed(theme)[0], "source not cached: " + key)
		check(stream.loop and is_zero_approx(stream.loop_offset), "loop disabled/offset: " + key)
		check(absf(stream.get_length() - 30.0) < .03, "unexpected loop length: " + key)
		var raw := stream.duplicate() as AudioStreamMP3
		raw.loop = false
		var source := measure(raw)
		var mixed := source + Vector2.ONE * float(bed[1])
		check(absf(mixed.x - Sfx.BED_TARGET) < .15, "room tone no longer mix-matched: " + key)
		check(mixed.y < -12.0, "insufficient headroom: " + key)
		var ambience := Ambience.new(theme)
		check(ambience.stream == stream, "Ambience wired to wrong file: " + key)
		check(is_equal_approx(ambience.volume_db, float(bed[1])), "Ambience gain mismatch: " + key)
		ambience.free()
		var playback := stream.instantiate_playback()
		playback.start(stream.get_length() - .05)
		var frames := playback.mix_audio(1.0, roundi(AudioServer.get_mix_rate() * .15))
		check(playback.get_loop_count() > 0, "playback did not wrap: " + key)
		var energy := 0.0
		for frame in frames.slice(roundi(AudioServer.get_mix_rate() * .06)):
			energy += frame.length_squared()
		check(energy > .000001, "silent after loop seam: " + key)
		playback.stop()
		print("%s: %.3f s, gain %+.1f dB, mixed RMS %.2f dBFS, peak %.2f dBFS" % [key, stream.get_length(), bed[1], mixed.x, mixed.y])
	check(streams.size() == 2, "both ambient tracks must load")
	if streams.size() == 2:
		check(streams[0] != streams[1], "Airport and Mall still share one cached stream")
		check(streams[0].data != streams[1].data, "Airport and Mall contain identical recordings")
	print("AIRPORT_MALL_AMBIENCE: failures=%s" % [failures])
	quit(0 if failures.is_empty() else 1)
