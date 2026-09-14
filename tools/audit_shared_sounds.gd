extends SceneTree
## Source-level mix and runtime contract checks, not an ear-verified final mix.
const MEAN_TARGETS := {"buzz": -17.82, "drip": -24.83, "moan": -16.30, "pa_voice": -30.57, "shiver": -28.35}
const DURATIONS := {"buzz": 7.96, "drip": 0.8, "moan": 3.08, "pa_voice": 4.48, "shiver": 0.88}
const ROOM_TARGETS := {"trolley": -16.09, "vent": -14.63, "printer": -20.61, "ticking": -33.61, "ballast": -24.43, "metal": -30.00, "pipes": -20.06, "drips": -25.86, "organic": -16.02}
var failures: Array[String] = []

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func measure(stream: AudioStream, gain_db := 0.0) -> Vector2:
	var playback := stream.instantiate_playback()
	playback.start()
	var frames := playback.mix_audio(1.0, roundi(stream.get_length() * AudioServer.get_mix_rate()))
	playback.stop()
	var energy := 0.0
	var peak := 0.0
	for sample in frames:
		energy += sample.length_squared()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return Vector2(linear_to_db(sqrt(energy / (frames.size() * 2.0))) + gain_db, linear_to_db(peak) + gain_db)

func run() -> void:
	var streams := {"buzz": SoundBank.buzz(), "drip": SoundBank.drip(), "moan": SoundBank.moan(), "pa_voice": SoundBank.pa_voice(), "shiver": SoundBank.shiver()}
	check(SoundBank.RECORDINGS.size() == streams.size(), "recording registry mismatch")
	for key in streams:
		var wav: AudioStreamWAV = streams[key]
		check(wav == SoundBank._recording(key), "recording not cached: " + str(key))
		check(wav.resource_path == "res://sounds/shared/%s.wav" % key, "wrong source: " + str(key))
		check(wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.stereo, "unexpected PCM format: " + str(key))
		check(absf(wav.get_length() - float(DURATIONS[key])) < 0.002, "duration changed: " + str(key))
		check(wav.loop_mode == (AudioStreamWAV.LOOP_FORWARD if key == "buzz" else AudioStreamWAV.LOOP_DISABLED), "wrong loop mode: " + str(key))
		var stats := measure(wav)
		check(absf(stats.x - float(MEAN_TARGETS[key])) < 0.35, "mix target changed: " + str(key))
		check(stats.y < -4.5, "insufficient source headroom: " + str(key))
		print("Shared %s: %.3f s, mean %.2f dBFS, peak %.2f dBFS" % [key, wav.get_length(), stats.x, stats.y])
	var buzz: AudioStreamWAV = streams.buzz
	check(buzz.loop_begin == 0 and buzz.loop_end == roundi(buzz.get_length() * buzz.mix_rate), "buzz loop bounds wrong")
	var seam := Vector2(buzz.data.decode_s16(0), buzz.data.decode_s16(2)) - Vector2(buzz.data.decode_s16(buzz.data.size() - 4), buzz.data.decode_s16(buzz.data.size() - 2))
	check(maxf(absf(seam.x), absf(seam.y)) / 32768.0 < 0.01, "buzz seam has a large discontinuity")
	for key in ROOM_TARGETS:
		var stats := measure(AmbientPalette.stream(key), AmbientPalette.gain_db(key))
		check(absf(stats.x - float(ROOM_TARGETS[key])) < 0.15, "room mix target changed: " + str(key))
		check(stats.y - 11.0 < -5.0, "room event lacks emitter headroom: " + str(key))
		print("Room %s: matched source mean %.2f dBFS, peak after event gain %.2f dBFS" % [key, stats.x, stats.y - 11.0])
	var asylum := AsylumSounds.new()
	root.add_child(asylum)
	asylum.set_process(false)
	check((asylum._drip.stream as AudioStreamRandomizer).get_stream(0) == streams.drip, "Asylum drip not replaced")
	check((asylum._moan.stream as AudioStreamRandomizer).get_stream(0) == streams.moan, "Asylum moan not replaced")
	check(asylum._drip.volume_db == -14.0 and asylum._moan.volume_db == -16.0, "Asylum emitter gains changed")
	var airport := AirportSounds.new()
	root.add_child(airport)
	airport.set_process(false)
	check(airport._voice.stream == streams.pa_voice and airport._voice.volume_db == -14.0, "Airport voice source/gain wrong")
	airport._t = 100.0
	airport._voice_in = 1.6
	airport._process(1.5)
	check(not airport._voice.playing, "PA voice started early")
	airport._process(0.11)
	check(airport._voice.playing, "PA voice did not start after chime delay")
	asylum._drip.play()
	asylum._moan.play()
	var hum := AudioStreamPlayer.new()
	hum.stream = buzz
	root.add_child(hum)
	hum.play()
	await create_timer(8.3).timeout
	check(hum.playing, "buzz stopped instead of looping")
	check(not asylum._drip.playing and not asylum._moan.playing and not airport._voice.playing, "one-shot did not finish")
	hum.stop()
	hum.free()
	asylum.free()
	airport.free()
	await create_timer(0.1).timeout
	print("Shared sound / replacement mix failures: %s" % [failures])
	quit(0 if failures.is_empty() else 1)
