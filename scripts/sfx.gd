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

# theme -> [file, measured mean dB]. The Annex uses the user-supplied 30-second
# ambient loop as its only continuous score; main.gd explicitly suppresses
# music on that floor. The casino and school borrow the office room tone.
const BEDS := {
	0: ["sound-office", -40.9],
	1: ["sound-office", -40.9],
	2: ["ambient-annex", -54.6],
	6: ["sound-office", -40.9],
	4: ["sound-airport", -43.3],
	5: ["sound-asylum", -12.7],
	7: ["sound-airport", -43.3],
	8: ["sound-asylum", -12.7],
	# Tiled hall over standing water: the airport bed is the only one with the
	# right amount of empty room reverb in it, run quieter than the terminal.
	9: ["sound-airport", -46.0],
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

const SCARE_MEANS := [-11.0, -8.5, -8.8, -8.5, -9.8, -11.6, -9.5,
	-8.1, -9.6, -7.9, -8.4, -11.7]
const SCARE_TARGET := -10.0   # before 3D attenuation

# Muttering in a dead language, from somewhere else in the building. Positional
# and quiet on purpose: this is a layer you half-hear and cannot place, not an
# announcement. It sits well under the scares — a stinger is an event, a whisper
# is only ever a suggestion that the floor is occupied.
const WHISPER_MEANS := [-14.7, -14.8, -14.5, -16.6, -18.0, -15.7, -16.1,
	-16.4, -17.5, -15.9, -18.3]
const WHISPER_TARGET := -26.0   # at unit_size distance, before attenuation

# What one of them sounds like going out under the beam. The kill used to
# borrow a jump-scare pitched up 18%, which was a stand-in — a stinger is the
# sound of something arriving, and this is the sound of something ending.
#
# Far under the scares. This started at -12, a little below a jump-scare, and
# has been cut twice: the player triggers it deliberately, repeatedly, and from
# close range where 3D attenuation has taken almost nothing off it. A startle
# you cause yourself a dozen times an hour is not a startle, it is fatigue.
const DEATH_MEANS := [-7.6, -7.3, -6.5, -10.2, -10.0, -9.6, -7.3]
const DEATH_TARGET := -29.0   # at unit_size distance, before attenuation

# You, when one of them reaches you. Not positional: this is the one sound in
# the game that is not happening somewhere in the room.
#
# Still the loudest thing here, because it plays once and ends the run — but
# -6 was chosen as "the loudest" in the abstract rather than measured against
# anything. It is a full-range recording played dry with no attenuation at all,
# which the scares and deaths both get; matching their target on paper made it
# considerably louder in the ear.
const PLAYER_DEATH_MEANS := [-8.4, -9.1, -9.1, -8.5, -10.8]
const PLAYER_DEATH_TARGET := -15.0

# Your own pulse, so it is never placed in the room. Loops for as long as the
# fright lasts and is mixed at full tension only — `Heartbeat` fades it in from
# silence and back out, so this is the ceiling rather than the level.
const HEARTBEAT := ["sound-heartbeat", -14.3]
const HEARTBEAT_TARGET := -19.0

# Your breathing, riding the same fright as the pulse but joining it later —
# see BREATH_ENTER in Heartbeat. Mild dread is a heartbeat; panting on top of
# it is panic, and panic should be something the game escalates to rather than
# opens with.
#
# Mixed far lower than the pulse despite sitting only two decibels under it on
# paper. Breath is broadband noise in the presence range, where the ear is at
# its most sensitive, while a heartbeat is a low thump — matched by the meter
# they are nowhere near matched by the listener.
const BREATHING := ["sound-breathing", -19.9]
const BREATHING_TARGET := -32.0

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


## How many scares the bank holds. Callers used to hardcode the count, so
## adding recordings left them unreachable — the bank tells you now.
static func scare_count() -> int:
	return SCARE_MEANS.size()


static func scare(idx: int) -> Array:
	var i := clampi(idx, 0, SCARE_MEANS.size() - 1)
	return [_stream("sound-jumpscare%d" % (i + 1), false),
		SCARE_TARGET - SCARE_MEANS[i]]


## A scare that is not the one you just heard. With a dozen in the bank a plain
## random pick still repeats often enough to be noticed, and a stinger you
## recognise is a sound effect rather than a scare.
static var _last_scare_idx := -1


## Pick an index other than the one picked last time. Hearing the same phrase or
## cry twice running reads as a bug in the audio rather than as a coincidence, and
## every randomised set here wants the same rule -- it was written out four times.
## Returns the new index; the caller keeps its own "last" so the sets do not
## interfere with each other.
static func _next_index(count: int, last: int) -> int:
	if count <= 1:
		return 0
	var i := randi() % count
	if i == last:
		i = (i + 1 + randi() % (count - 1)) % count
	return i


static func random_scare() -> Array:
	_last_scare_idx = _next_index(SCARE_MEANS.size(), _last_scare_idx)
	return scare(_last_scare_idx)


static func whisper_count() -> int:
	return WHISPER_MEANS.size()


static func whisper(idx: int) -> Array:
	var i := clampi(idx, 0, WHISPER_MEANS.size() - 1)
	return [_stream("sound-whisper%d" % (i + 1), false),
		WHISPER_TARGET - WHISPER_MEANS[i]]


static var _last_whisper_idx := -1


## Same no-repeat rule as the scares: hearing the same phrase twice running
## turns a voice into a tape.
static func random_whisper() -> Array:
	_last_whisper_idx = _next_index(WHISPER_MEANS.size(), _last_whisper_idx)
	return whisper(_last_whisper_idx)


static func death_count() -> int:
	return DEATH_MEANS.size()


static func death(idx: int) -> Array:
	var i := clampi(idx, 0, DEATH_MEANS.size() - 1)
	return [_stream("sound-demondeath%d" % (i + 1), false),
		DEATH_TARGET - DEATH_MEANS[i]]


static var _last_death_idx := -1


## The kill is the one sound the player deliberately causes, so it is also the
## one they will hear most often in a row. No repeats matters more here than
## anywhere else.
static func random_death() -> Array:
	_last_death_idx = _next_index(DEATH_MEANS.size(), _last_death_idx)
	return death(_last_death_idx)


## Looping. The trim brings it to HEARTBEAT_TARGET at full tension; the caller
## attenuates from there down to silence.
static func heartbeat() -> Array:
	return [_stream(HEARTBEAT[0], true),
		HEARTBEAT_TARGET - float(HEARTBEAT[1])]


## Looping, as above.
static func breathing() -> Array:
	return [_stream(BREATHING[0], true),
		BREATHING_TARGET - float(BREATHING[1])]


static func player_death_count() -> int:
	return PLAYER_DEATH_MEANS.size()


static func player_death(idx: int) -> Array:
	var i := clampi(idx, 0, PLAYER_DEATH_MEANS.size() - 1)
	return [_stream("sound-playerdeath%d" % (i + 1), false),
		PLAYER_DEATH_TARGET - PLAYER_DEATH_MEANS[i]]


static var _last_player_death_idx := -1


static func random_player_death() -> Array:
	_last_player_death_idx = _next_index(PLAYER_DEATH_MEANS.size(), _last_player_death_idx)
	return player_death(_last_player_death_idx)


# --- water --------------------------------------------------------------------
# Only the Poolrooms play these. Getting in and getting out are one-shots at
# the moment the waterline crosses your chest; the wade is a loop whose volume
# follows how hard you are actually pushing through it, so standing still in
# the water is silent rather than a tape running under you.

static func water_enter() -> Array:
	return [_stream("sound-water-enter", false), -6.0]


static func water_exit() -> Array:
	return [_stream("sound-water-exit", false), -6.0]


static func water_wade() -> AudioStream:
	return _stream("sound-water-wade", true)
