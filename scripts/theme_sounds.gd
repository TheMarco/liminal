class_name ThemeSounds
extends Node3D
## Base for the per-theme spatial sound emitters that level builders drop into a
## room: AirportSounds, AsylumSounds, OfficeSounds, and any that follow.
##
## What they share is emitter setup, not behaviour. Each one had the same six
## lines -- new player, stream, max_distance, unit_size, volume_db, bus,
## add_child -- repeated once per sound, eight times across three files, with the
## bus as a bare string. Their timing logic is genuinely different, though: the
## airport sequences a chime into an announcement and rolls a jet on a separate
## clock, the asylum runs three independent countdowns, the office queues a burst
## of keystrokes. Forcing those into one _process template would cost more than
## the duplication did, so only the setup is shared.
##
## Subclasses build their players in _ready with emitter() and keep their own
## _process.


## One positional emitter on the Hall bus. `at` is a local offset, so a sound
## that should come from the ceiling can say so without the caller touching the
## node afterwards.
func emitter(stream: AudioStream, max_distance: float, unit_size: float,
		volume_db: float, at := Vector3.ZERO) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.max_distance = max_distance
	p.unit_size = unit_size
	p.volume_db = volume_db
	p.bus = SoundBank.HALL_BUS
	p.position = at
	add_child(p)
	return p


## Somewhere in the room, at a given height, for a sound that should not come
## from the same spot every time it plays.
func scatter(p: AudioStreamPlayer3D, spread: float, y: float) -> void:
	p.position = Vector3(randf_range(-spread, spread), y, randf_range(-spread, spread))
