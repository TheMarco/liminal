class_name EnvironmentEvents
extends Node
## Sparse physical reactions that make the building answer the player: local
## power sags, a lift arriving where there is no lobby, and knocks from a room
## the topology insists is inaccessible.

signal message(text: String)

var player: Player
var level_root: Node3D
var _time_left := 38.0
var _busy := false


func _ready() -> void:
	_time_left = randf_range(32.0, 58.0)


func set_level(root: Node3D) -> void:
	level_root = root
	_busy = false
	_time_left = randf_range(24.0, 46.0)


func _process(dt: float) -> void:
	if _busy or player == null or not is_instance_valid(level_root):
		return
	_time_left -= dt
	if _time_left > 0.0:
		return
	_time_left = randf_range(38.0, 72.0)
	var pick := randf()
	if pick < 0.48:
		_power_sag(0.7, "THE POWER DIPS")
	elif pick < 0.76:
		_spatial_sound(SoundBank.elev(), 9.0, -11.0)
		message.emit("AN ELEVATOR ARRIVES SOMEWHERE ELSE")
	else:
		_spatial_sound(SoundBank.thud(), 5.0, -8.0)
		message.emit("THREE KNOCKS FROM BEHIND THE WALL")


func terminal_response(page: int) -> void:
	if page % 3 == 2:
		_power_sag(1.15, "THE TERMINAL REQUESTS MORE POWER")
	else:
		_spatial_sound(SoundBank.ding(), 2.5, -15.0)


func elevator_response() -> void:
	_spatial_sound(SoundBank.elev(), 1.5, -7.0)


func door_response() -> void:
	_spatial_sound(SoundBank.creak(), 1.2, -13.0)


func _power_sag(hold: float, caption: String) -> void:
	if _busy or not is_instance_valid(level_root):
		return
	_busy = true
	message.emit(caption)
	var lights: Array[OmniLight3D] = []
	var energy := {}
	for n in level_root.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if l.global_position.distance_to(player.global_position) > 24.0:
			continue
		lights.append(l)
		energy[l] = l.light_energy
		if l is FlickerLight:
			l.set_process(false)
		create_tween().tween_property(l, "light_energy", 0.015, 0.16)
	_spatial_sound(SoundBank.thud(), 4.0, -14.0)
	await get_tree().create_timer(hold).timeout
	for l in lights:
		if not is_instance_valid(l):
			continue
		create_tween().tween_property(l, "light_energy", float(energy[l]), 0.65)
		if l is FlickerLight:
			l.set_process(true)
	_busy = false


func _spatial_sound(stream: AudioStream, distance: float, volume: float) -> void:
	if player == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = volume
	a.max_distance = 30.0
	a.unit_size = 4.0
	a.bus = "Hall"
	var fwd := -player.cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	add_child(a)
	a.global_position = player.global_position + fwd.normalized() * distance
	a.finished.connect(a.queue_free)
	a.play()
