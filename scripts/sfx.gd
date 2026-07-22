class_name Sfx
## The recorded layer, over the top of SoundBank's synthesis.
##
## Every gain here was measured, not guessed: the source files land anywhere
## between -12.7 dB and -43.3 dB mean, a thirty-decibel spread, so one shared
## volume would have made the asylum deafening and the airport silent. Each
## trim below brings its file to a common mean, and the TARGET constants set
## where that mean sits relative to the music.
##
## The music plays at MUSIC_DB (-14) and averages -14.3 dB itself, so it sits
## at roughly -28 dB. Everything here is placed under that on purpose — the
## room tone should be something you notice only when it stops.

const DIR := "res://sounds/%s.mp3"

const BED_TARGET := -37.0    # ~9 dB under the music: present, never leading
const WALK_TARGET := -37.0   # transient, so it still cuts through the bed

# theme -> [file, measured mean dB]. The casino and the school have no room
# tone recorded for them yet and borrow the office one — it is the most
# neutral of the four, near-featureless fluorescent air. The casino's own
# recording is of the MACHINES, which belongs on the machines and not humming
# out of an empty corridor; see slots() below.
const BEDS := {
	0: ["sound-office", -40.9],
	1: ["sound-office", -40.9],
	6: ["sound-office", -40.9],
	2: ["sound-sewer-ambient", -32.0],
	4: ["sound-airport", -43.3],
	5: ["sound-asylum", -12.7],
}

# surface -> [file, measured mean dB]
const WALKS := {
	"carpet": ["sound-walking-carpet", -35.6],
	"concrete": ["sound-walking-concrete", -31.5],
	"marble": ["sound-walking-marble", -37.5],
	"wet": ["sound-walking-wet-surface", -35.4],
}

# Positional, not a bed: this is what a bank of machines sounds like from a
# few metres away, so it is placed on the bank and left to 3D attenuation to
# fade it up as you come down the room toward it.
const SLOTS := ["sound-slots", -22.2]
const SLOT_TARGET := -30.0   # at unit_size distance; louder as you close in

const SCARE_MEANS := [-11.0, -8.5, -8.8, -8.5, -9.8, -11.6, -9.5]
const SCARE_TARGET := -10.0   # before 3D attenuation

static var _c := {}


## Loaded once and marked looping — the import ships loop=false, and a room
## tone that stops after thirty seconds is worse than none.
static func _stream(name_key: String, loop: bool) -> AudioStream:
	if _c.has(name_key):
		return _c[name_key]
	var s: AudioStream = load(DIR % name_key)
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = loop
	_c[name_key] = s
	return s


static func has_bed(theme: int) -> bool:
	return BEDS.has(theme)


## The room tone for a floor, already trimmed to sit under the music.
static func bed(theme: int) -> Array:
	var e: Array = BEDS[theme]
	return [_stream(e[0], true), BED_TARGET - float(e[1])]


## The walking loop for a surface. These are continuous recordings — about two
## steps a second — so they are faded in and out with movement rather than
## triggered per stride.
static func walk(surface: String) -> Array:
	var e: Array = WALKS[surface]
	return [_stream(e[0], true), WALK_TARGET - float(e[1])]


## The machines themselves, looping, for a slot bank to emit.
static func slots() -> Array:
	return [_stream(SLOTS[0], true), SLOT_TARGET - float(SLOTS[1])]


static func scare(idx: int) -> Array:
	var i := clampi(idx, 0, SCARE_MEANS.size() - 1)
	return [_stream("sound-jumpscare%d" % (i + 1), false),
		SCARE_TARGET - SCARE_MEANS[i]]
