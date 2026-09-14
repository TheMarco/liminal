class_name EnvironmentEvents
extends Node
## Sparse physical reactions that make the building answer the player: local
## power sags and knocks from a room the topology insists is inaccessible.

signal message(text: String)

var player: Player
var level_root: Node3D
var horror_director: HorrorDirector
var descent_mode := false
var _time_left := 38.0
var _busy := false
var theme := 0
var _bag: Array = []
var _last_kind := ""


func _ready() -> void:
	_time_left = randf_range(32.0, 58.0)


func set_level(root: Node3D, floor_theme := 0) -> void:
	level_root = root
	theme = floor_theme
	_bag.clear()
	_last_kind = ""
	# Do not carry a sound from the previous floor through the transition.
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.stop()
			child.queue_free()
	_busy = false
	_time_left = randf_range(24.0, 46.0)


func _process(dt: float) -> void:
	if _busy or player == null or not is_instance_valid(level_root):
		return
	_time_left -= dt
	if _time_left > 0.0:
		return
	if descent_mode and horror_director != null \
			and not horror_director.try_start_ambient(4.0):
		_time_left = randf_range(4.0, 9.0)
		return
	_time_left = randf_range(38.0, 72.0)
	if descent_mode:
		_play_room_event()
		return
	var pick := randf()
	if pick < 0.48:
		_power_sag(0.7, "THE POWER DIPS")
	else:
		_spatial_sound(SoundBank.thud(), 5.0, -8.0)
		message.emit("THREE KNOCKS FROM BEHIND THE WALL")


func terminal_response(page: int) -> void:
	if page % 3 == 2 and not descent_mode:
		_power_sag(1.15, "THE TERMINAL REQUESTS MORE POWER")
	else:
		_spatial_sound(SoundBank.ding(), 2.5, -15.0)


func elevator_response() -> void:
	_spatial_sound(SoundBank.elev(), 1.5, -7.0)


## The room's answer to a successful photograph: non-lethal, uncaptioned,
## deliberately ambiguous about whether something worse just happened.
func photo_response() -> void:
	if player == null:
		return
	if descent_mode:
		# Photographs must not simulate the rule-bearing blackout either.
		if horror_director == null or horror_director.try_start_ambient(4.0):
			_play_room_event()
		return
	var pick := randf()
	if pick < 0.4:
		_power_sag(0.9, "")
	elif pick < 0.7:
		_spatial_sound(SoundBank.thud(), 4.0, -8.0)
	else:
		_spatial_sound(SoundBank.creak(), 3.0, -10.0)


func door_response() -> void:
	_spatial_sound(SoundBank.creak(), 1.2, -13.0)


func next_room_event() -> String:
	if _bag.is_empty():
		_bag = AmbientPalette.kinds(theme)
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_kind:
			var first = _bag[0]
			_bag[0] = _bag.back()
			_bag[_bag.size() - 1] = first
	_last_kind = str(_bag.pop_back())
	return _last_kind


func _play_room_event() -> void:
	var kind := next_room_event()
	_spatial_sound(AmbientPalette.stream(kind), randf_range(5, 9), -11.0 + AmbientPalette.gain_db(kind), true)


func _power_sag(hold: float, caption: String) -> void:
	if _busy or not is_instance_valid(level_root):
		return
	_busy = true
	if not caption.is_empty():
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


func _spatial_sound(stream: AudioStream, distance: float, volume: float, scatter := false) -> void:
	if player == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = stream
	a.volume_db = volume
	a.max_distance = 30.0
	a.unit_size = 4.0
	a.bus = SoundBank.HALL_BUS
	var fwd := -player.cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	if scatter:
		fwd = fwd.rotated(Vector3.UP, randf_range(-PI, PI))
		a.pitch_scale = randf_range(0.94, 1.06)
	add_child(a)
	a.global_position = player.global_position + fwd.normalized() * distance
	a.finished.connect(a.queue_free)
	a.play()
