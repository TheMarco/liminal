class_name OfficeSounds
extends Node3D
## Ambient life for a cubicle cluster: sparse bursts of keyboard typing from
## no one in particular, and the occasional terminal beep.

var _keys: AudioStreamPlayer3D
var _beep: AudioStreamPlayer3D
var _t := 0.0
var _queue: Array = []


func _ready() -> void:
	_keys = AudioStreamPlayer3D.new()
	_keys.stream = SoundBank.randomized(SoundBank.key_click(), 1.25, 3.0)
	_keys.max_polyphony = 3
	_keys.max_distance = 18.0
	_keys.unit_size = 4.0
	_keys.volume_db = -12.0
	_keys.bus = "Hall"
	add_child(_keys)
	_beep = AudioStreamPlayer3D.new()
	_beep.stream = SoundBank.randomized(SoundBank.ding(), 1.08, 2.0)
	_beep.pitch_scale = 2.2
	_beep.max_distance = 20.0
	_beep.unit_size = 5.0
	_beep.volume_db = -20.0
	_beep.bus = "Hall"
	add_child(_beep)
	_t = randf_range(2.0, 8.0)


func _process(dt: float) -> void:
	if not _queue.is_empty():
		_queue[0] -= dt
		if _queue[0] <= 0.0:
			_keys.play()
			_queue.pop_front()
	_t -= dt
	if _t <= 0.0:
		_t = randf_range(6.0, 18.0)
		if randf() < 0.12:
			_beep.play()
			return
		var d := 0.0
		for i in randi_range(5, 14):
			_queue.append(d)
			d += randf_range(0.06, 0.14)
