class_name AirportSounds
extends ThemeSounds
## Terminal PA life: a gentle three-tone chime, then a muffled announcement
## in no language you can place. Every few minutes a heavy jet rolls somewhere
## far out on a runway you will never see.

var _chime: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _jet: AudioStreamPlayer3D
var _t := 0.0
var _voice_in := -1.0


func _ready() -> void:
	# The PA hangs at ceiling height; the jet is somewhere outside at ground level.
	_chime = emitter(SoundBank.pa_chime(), 30.0, 7.0, -12.0, Vector3(0, 4.6, 0))
	_voice = emitter(SoundBank.pa_voice(), 26.0, 6.0, -14.0, Vector3(0, 4.6, 0))
	_jet = emitter(SoundBank.jet_far(), 46.0, 12.0, -10.0, Vector3(0, 2.0, 0))
	_t = randf_range(10.0, 60.0)


func _process(dt: float) -> void:
	if _voice_in > 0.0:
		_voice_in -= dt
		if _voice_in <= 0.0:
			_voice.pitch_scale = randf_range(0.9, 1.08)
			_voice.play()
	_t -= dt
	if _t <= 0.0:
		_t = randf_range(50.0, 140.0)
		if randf() < 0.3:
			_jet.pitch_scale = randf_range(0.85, 1.05)
			_jet.play()
		else:
			_chime.play()
			_voice_in = 1.6
