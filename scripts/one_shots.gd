class_name OneShots
extends Node3D
## Rare distant sounds from elsewhere in the hotel — a structural thud, an
## elevator chime — placed at a random position around the player.

var player: Node3D

var _t := 20.0
var _p3d: AudioStreamPlayer3D


func _ready() -> void:
	_p3d = AudioStreamPlayer3D.new()
	_p3d.max_distance = 40.0
	_p3d.unit_size = 8.0
	_p3d.volume_db = -4.0
	_p3d.bus = "Hall"
	add_child(_p3d)


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or player == null or not player.is_inside_tree():
		return
	_t = randf_range(18.0, 50.0)
	var ang := randf() * TAU
	var dist := randf_range(9.0, 20.0)
	_p3d.position = player.global_position + Vector3(cos(ang) * dist, 1.6, sin(ang) * dist)
	_p3d.stream = SoundBank.thud() if randf() < 0.75 else SoundBank.elev()
	_p3d.pitch_scale = randf_range(0.85, 1.1)
	_p3d.play()
