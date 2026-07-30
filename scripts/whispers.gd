class_name Whispers
extends Node3D
## Muttering in a dead language, from somewhere else on the floor.
##
## Its own layer, deliberately: the room tone is a continuous bed you stop
## hearing, and the one-shots are structural — a thud, a lift chime. A voice is
## neither. It is placed in the world rather than in your head, so it arrives
## from a direction, falls off with distance, and is gone before you have
## finished turning toward it.
##
## Everything here is tuned to stay under the threshold of certainty. Too loud
## or too often and it stops being a building that might be occupied and starts
## being a soundtrack telling you it is.

## Far enough to be somewhere else, near enough to carry.
const NEAR := 11.0
const FAR := 26.0
## Never in the tiny fraction of a sphere directly behind your head — that
## reads as someone standing at your shoulder, which is a scare, and scares
## belong to the figures.
const BEHIND_ARC := 0.55

var player: Player
var suspended := false

var _t := 0.0
var _p3d: AudioStreamPlayer3D
var _dev := false
## Set by main from CliOptions before this enters the tree.
var dev := false


func _ready() -> void:
	_p3d = AudioStreamPlayer3D.new()
	# A voice loses its highs across a room long before it loses its body, so
	# the attenuation is gentler than the one-shots and the reach is longer.
	_p3d.max_distance = 44.0
	_p3d.unit_size = 10.0
	_p3d.bus = SoundBank.HALL_BUS
	add_child(_p3d)
	_t = randf_range(25.0, 60.0)
	if dev:
		_t = 1.5          # dev: hear one almost immediately
		_dev = true


## Level switch or portal jump: whatever was muttering stays behind.
func stop() -> void:
	if is_instance_valid(_p3d):
		_p3d.stop()
	_t = randf_range(20.0, 45.0)


func _process(dt: float) -> void:
	if suspended or player == null or not player.is_inside_tree():
		return
	_t -= dt
	if _t > 0.0:
		return
	# Long gaps. Eleven recordings would still wear out fast at one a minute,
	# and the silence between them is what makes one land.
	_t = randf_range(38.0, 105.0) * (0.25 if _dev else 1.0)
	if _p3d.playing:
		return
	var fwd := -player.cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var ang := randf() * TAU
	var dirv := Vector3(sin(ang), 0, cos(ang))
	if dirv.dot(fwd) < -1.0 + BEHIND_ARC:
		ang += PI * 0.5
		dirv = Vector3(sin(ang), 0, cos(ang))
	var dist := randf_range(NEAR, FAR)
	var w := Sfx.random_whisper()
	if w[0] == null:
		return
	_p3d.stream = w[0]
	_p3d.volume_db = float(w[1])
	# Slightly below its recorded pitch, always. A whisper that sits high reads
	# as a person; dropped a little it reads as the building.
	_p3d.pitch_scale = randf_range(0.86, 0.97)
	_p3d.global_position = player.global_position \
		+ dirv * dist + Vector3(0, randf_range(0.4, 2.1), 0)
	_p3d.play()
	if _dev:
		print("whisper at %.0f deg, %.0fm, %.1f dB, pitch %.2f" % [
			rad_to_deg(ang), dist, _p3d.volume_db, _p3d.pitch_scale])
