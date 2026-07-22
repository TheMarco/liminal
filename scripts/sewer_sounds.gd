class_name SewerSounds
extends Node3D
## Water life for a sewer cell: the continuous rush of the channel and
## irregular drips echoing off the concrete from ever-different places.

var rush_db := -16.0

var _drip: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	var rush := AudioStreamPlayer3D.new()
	rush.stream = SoundBank.water_rush()
	rush.autoplay = true
	rush.max_distance = 16.0
	rush.unit_size = 4.0
	rush.volume_db = rush_db
	rush.bus = "Hall"
	add_child(rush)
	_drip = AudioStreamPlayer3D.new()
	_drip.stream = SoundBank.randomized(SoundBank.drip(), 1.4, 4.0)
	_drip.max_distance = 18.0
	_drip.unit_size = 5.0
	_drip.volume_db = -10.0
	_drip.bus = "Hall"
	add_child(_drip)
	_t = randf_range(1.5, 7.0)


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = randf_range(2.5, 11.0)
		_drip.position = Vector3(randf_range(-5.0, 5.0), randf_range(0.2, 2.0), randf_range(-5.0, 5.0))
		_drip.play()
