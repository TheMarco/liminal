class_name OfficeSounds
extends ThemeSounds
## Ambient life for a cubicle cluster: sparse bursts of keyboard typing from
## no one in particular, and the occasional terminal beep.

var _keys: AudioStreamPlayer3D
var _beep: AudioStreamPlayer3D
var _t := 0.0
var _queue: Array = []


func _ready() -> void:
	_keys = emitter(SoundBank.randomized(SoundBank.key_click(), 1.25, 3.0), 18.0, 4.0, -12.0)
	# Overlapping keystrokes within one burst, so the typing does not sound
	# metronomic.
	_keys.max_polyphony = 3
	_beep = emitter(SoundBank.randomized(SoundBank.ding(), 1.08, 2.0), 20.0, 5.0, -20.0)
	_beep.pitch_scale = 2.2
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
