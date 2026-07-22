class_name AirportSounds
extends Node3D
## Terminal PA life: a gentle three-tone chime, then a muffled announcement
## in no language you can place. Every few minutes a heavy jet rolls somewhere
## far out on a runway you will never see.

var _chime: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _jet: AudioStreamPlayer3D
var _t := 0.0
var _voice_in := -1.0


func _ready() -> void:
	_chime = AudioStreamPlayer3D.new()
	_chime.stream = SoundBank.pa_chime()
	_chime.max_distance = 30.0
	_chime.unit_size = 7.0
	_chime.volume_db = -12.0
	_chime.bus = "Hall"
	_chime.position = Vector3(0, 4.6, 0)
	add_child(_chime)
	_voice = AudioStreamPlayer3D.new()
	_voice.stream = SoundBank.pa_voice()
	_voice.max_distance = 26.0
	_voice.unit_size = 6.0
	_voice.volume_db = -14.0
	_voice.bus = "Hall"
	_voice.position = Vector3(0, 4.6, 0)
	add_child(_voice)
	_jet = AudioStreamPlayer3D.new()
	_jet.stream = SoundBank.jet_far()
	_jet.max_distance = 46.0
	_jet.unit_size = 12.0
	_jet.volume_db = -10.0
	_jet.bus = "Hall"
	_jet.position = Vector3(0, 2.0, 0)
	add_child(_jet)
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
