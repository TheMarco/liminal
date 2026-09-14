extends SceneTree
## Offline preparation of user-supplied audio. No runtime decoding or synthesis.
## Run with --audio-driver Dummy; mix_audio resamples to the server's mix rate.
const SOURCES := "res://art/shared_sound_sources"
const OUTPUT := "res://sounds/shared"
const SETTINGS := {
	"buzz": {"file": "buzz.mp3", "gain_db": -11.6, "loop": true},
	"drip": {"file": "drip.mp3", "gain_db": 8.0, "loop": false},
	"moan": {"file": "moan.mp3", "gain_db": -4.9, "loop": false},
	"pa_voice": {"file": "pa-voice.mp3", "gain_db": -13.0, "loop": false},
	"shiver": {"file": "shiver.mp3", "gain_db": -3.9, "loop": false},
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for key in SETTINGS:
		var settings: Dictionary = SETTINGS[key]
		var source := AudioStreamMP3.load_from_file(SOURCES.path_join(settings.file))
		if source == null:
			push_error("Cannot load replacement: " + str(key))
			quit(1)
			return
		source.loop = false
		var playback := source.instantiate_playback()
		playback.start()
		var frames := playback.mix_audio(1.0, roundi(source.get_length() * AudioServer.get_mix_rate()))
		playback.stop()
		if settings.loop:
			# Overlap the last 40 ms with the first 40 ms; begin playback after
			# the overlapped head so the wrap continues at the next sample.
			var overlap := mini(roundi(AudioServer.get_mix_rate() * 0.04), frames.size() / 4)
			var original := frames
			frames = original.slice(overlap)
			for i in overlap:
				frames[frames.size() - overlap + i] = original[original.size() - overlap + i].lerp(original[i], float(i) / float(overlap - 1))
		var gain := db_to_linear(float(settings.gain_db))
		var data := PackedByteArray()
		data.resize(frames.size() * 4)
		var peak := 0.0
		for i in frames.size():
			var sample := frames[i] * gain
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			data.encode_s16(i * 4, roundi(clampf(sample.x, -1.0, 1.0) * 32767.0))
			data.encode_s16(i * 4 + 2, roundi(clampf(sample.y, -1.0, 1.0) * 32767.0))
		if peak >= 1.0:
			push_error("Replacement would clip: " + str(key))
			quit(1)
			return
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.stereo = true
		wav.mix_rate = roundi(AudioServer.get_mix_rate())
		wav.data = data
		var error := wav.save_to_wav(ProjectSettings.globalize_path(OUTPUT.path_join(str(key) + ".wav")))
		if error != OK:
			push_error("Cannot save replacement: " + str(key))
			quit(1)
			return
		print("Prepared %s: %.3f s, %.1f dB gain, %.1f dB peak, loop=%s" % [key, wav.get_length(), settings.gain_db, linear_to_db(peak), settings.loop])
	quit()
