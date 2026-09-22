extends Node
## One quiet looping bed per architecture event, audible only while in view.
## Uses the existing world-audio bus and never changes music or monster voices.
const TRACKS := ["sn1", "sn2", "sn3", "sn4", "sn5", "sn6"]
const LEVEL_DB := -22.0
const ATTACK := 0.8
const RELEASE := 1.2
var voice: AudioStreamPlayer
var gain := 0.0
var wanted := false
var event_active := false
var track_index := -1
var _rng := RandomNumberGenerator.new()
var _streams: Array[AudioStreamMP3] = []

func _ready() -> void:
	_rng.randomize()
	voice = AudioStreamPlayer.new()
	voice.bus = SoundBank.GAME_BUS if AudioServer.get_bus_index(SoundBank.GAME_BUS) >= 0 else "Master"
	voice.volume_db = -80.0
	add_child(voice)
	for track in TRACKS:
		# ResourceLoader follows import remaps in exported builds too.
		var source := load("res://sounds/supernatural/%s.mp3" % track) as AudioStreamMP3
		var stream: AudioStreamMP3 = source.duplicate() if source != null else null
		if stream != null:
			stream.loop = true
			_streams.append(stream)

func begin_event() -> void:
	# Normal pacing prevents overlap; debug interruption must not stack loops.
	stop_now()
	if _streams.is_empty(): return
	var next := _rng.randi_range(0, _streams.size()-1)
	if _streams.size() > 1 and next == track_index:
		next = (next + _rng.randi_range(1, _streams.size()-1)) % _streams.size()
	track_index = next
	voice.stream = _streams[track_index]
	event_active = true

func set_in_view(in_view: bool) -> void:
	wanted = event_active and in_view

func end_event() -> void:
	event_active = false
	wanted = false

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	if voice == null: return
	if wanted and not voice.playing: voice.play()
	gain = move_toward(gain, 1.0 if wanted else 0.0, dt/(ATTACK if wanted else RELEASE))
	# Smoothstep amplitude avoids an audible step at either end of the fade.
	voice.volume_linear = db_to_linear(LEVEL_DB) * smoothstep(0.0, 1.0, gain)
	if gain == 0.0 and voice.playing: voice.stop()

func stop_now() -> void:
	wanted = false
	event_active = false
	gain = 0.0
	if voice != null:
		voice.stop()
		voice.volume_db = -80.0

func _exit_tree() -> void:
	stop_now()
