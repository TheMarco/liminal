class_name SlotSounds
extends AudioStreamPlayer3D
## A bank of machines, still running attract mode to an empty room. The
## recording loops continuously and 3D attenuation does the work: it is
## inaudible across the floor and unmistakable once you are among them, so
## walking toward a slot room fades it up on its own.
##
## This used to be synthesized pentatonic dings scheduled in bursts. The
## recording replaced them — see sounds/sound-slots.mp3 and Sfx.slots().


func _ready() -> void:
	var s := Sfx.slots()
	stream = s[0]
	volume_db = float(s[1])
	# volume_db is the level at unit_size metres; inside that it climbs
	unit_size = 4.0
	max_distance = 26.0
	bus = "Hall"
	# machines in different rooms are not in lockstep
	play(randf() * 25.0)
