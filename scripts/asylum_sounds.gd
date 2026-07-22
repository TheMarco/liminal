class_name AsylumSounds
extends Node3D
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
	_drip = AudioStreamPlayer3D.new()
	_drip.stream = SoundBank.randomized(SoundBank.drip(), 1.35, 4.0)
	_drip.max_distance = 16.0
	_drip.unit_size = 4.0
	_drip.volume_db = -14.0
	_drip.bus = "Hall"
	add_child(_drip)
	_clang = AudioStreamPlayer3D.new()
	_clang.stream = SoundBank.randomized(SoundBank.clang(), 1.2, 3.0)
	_clang.max_distance = 26.0
	_clang.unit_size = 7.0
	_clang.volume_db = -13.0
	_clang.bus = "Hall"
	add_child(_clang)
	_moan = AudioStreamPlayer3D.new()
	_moan.stream = SoundBank.randomized(SoundBank.moan(), 1.18, 2.0)
	_moan.max_distance = 24.0
	_moan.unit_size = 6.0
	_moan.volume_db = -16.0
	_moan.bus = "Hall"
	add_child(_moan)
	_td = randf_range(3.0, 14.0)
	_tc = randf_range(20.0, 70.0)
	_tm = randf_range(50.0, 160.0)


func _process(dt: float) -> void:
	_td -= dt
	if _td <= 0.0:
		_td = randf_range(4.0, 16.0)
		_drip.position = Vector3(randf_range(-5.0, 5.0), randf_range(0.3, 2.2), randf_range(-5.0, 5.0))
		_drip.play()
	_tc -= dt
	if _tc <= 0.0:
		_tc = randf_range(25.0, 90.0)
		_clang.position = Vector3(randf_range(-9.0, 9.0), 1.2, randf_range(-9.0, 9.0))
		_clang.play()
	_tm -= dt
	if _tm <= 0.0:
		_tm = randf_range(70.0, 200.0)
		_moan.position = Vector3(randf_range(-8.0, 8.0), 1.4, randf_range(-8.0, 8.0))
		_moan.play()
