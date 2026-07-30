class_name AsylumSounds
extends ThemeSounds
## Life the asylum should not have: water dripping through the ceiling,
## iron struck somewhere down the ward, and — rarely — a moan from a room
## that has been empty for forty years.

var _drip: AudioStreamPlayer3D
var _clang: AudioStreamPlayer3D
var _moan: AudioStreamPlayer3D
var _td := 0.0
var _tc := 0.0
var _tm := 0.0


func _ready() -> void:
	_drip = emitter(SoundBank.randomized(SoundBank.drip(), 1.35, 4.0), 16.0, 4.0, -14.0)
	_clang = emitter(SoundBank.randomized(SoundBank.clang(), 1.2, 3.0), 26.0, 7.0, -13.0)
	_moan = emitter(SoundBank.randomized(SoundBank.moan(), 1.18, 2.0), 24.0, 6.0, -16.0)
	_td = randf_range(3.0, 14.0)
	_tc = randf_range(20.0, 70.0)
	_tm = randf_range(50.0, 160.0)


func _process(dt: float) -> void:
	_td -= dt
	if _td <= 0.0:
		_td = randf_range(4.0, 16.0)
		scatter(_drip, 5.0, randf_range(0.3, 2.2))
		_drip.play()
	_tc -= dt
	if _tc <= 0.0:
		_tc = randf_range(25.0, 90.0)
		scatter(_clang, 9.0, 1.2)
		_clang.play()
	_tm -= dt
	if _tm <= 0.0:
		_tm = randf_range(70.0, 200.0)
		scatter(_moan, 8.0, 1.4)
		_moan.play()
