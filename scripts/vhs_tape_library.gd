class_name VhsTapeLibrary
extends RefCounted
## Runtime catalogue for converted recordings in videos/tapes. Keeping the
## directory authoritative means a newly imported .ogv joins the next session
## without another hand-maintained list in gameplay code. A small explicit
## exclusion set preserves converted footage that belongs to other game systems.

const TAPE_DIR := "res://videos/tapes"
const LONG_MIN_SECONDS := 30.0
const BEGINNING_PREFIX := "short_beginning_"
const RANDOM_PREFIX := "short_random_"
const RESERVED_GAME_ASSETS: Array[String] = [
	"res://videos/tapes/tape_06.ogv",
	"res://videos/tapes/tape_07.ogv",
	"res://videos/tapes/tape_08.ogv",
	"res://videos/tapes/tape_09.ogv",
]

static var _all: Array[String] = []
static var _short: Array[String] = []
static var _long: Array[String] = []
static var _beginning: Array[String] = []
static var _random: Array[String] = []


static func paths(long_form := false) -> Array[String]:
	_scan()
	return (_long if long_form else _short).duplicate()


static func all_paths() -> Array[String]:
	_scan()
	return _all.duplicate()


static func beginning_paths() -> Array[String]:
	_scan()
	return _beginning.duplicate()


static func random_paths() -> Array[String]:
	_scan()
	return _random.duplicate()


static func beginning_index(path: String) -> int:
	_scan()
	return _beginning.find(path)


## Mandatory Descent recordings are story chapters, not random draws. The
## sorted catalogue is their authored order: chapter one belongs to floor one,
## chapter two to floor two, and so on. Production has one chapter for each of
## the ten non-final floors; cycling remains a defensive fallback for an
## incomplete development checkout.
static func objective_chapter(floor_idx: int) -> String:
	var chapters := paths(true)
	if chapters.is_empty():
		return ""
	return chapters[posmod(floor_idx, chapters.size())]


static func _scan() -> void:
	if not _all.is_empty():
		return
	var found: Array[String] = []
	if DirAccess.dir_exists_absolute(TAPE_DIR):
		for filename in DirAccess.get_files_at(TAPE_DIR):
			if filename.get_extension().to_lower() == "ogv":
				found.append(TAPE_DIR.path_join(filename))
	found.sort()
	for path in found:
		if RESERVED_GAME_ASSETS.has(path):
			continue
		var stream := load(path) as VideoStream
		if stream == null:
			continue
		var filename := path.get_file()
		var authored_short := filename.begins_with(BEGINNING_PREFIX) \
			or filename.begins_with(RANDOM_PREFIX)
		var probe := VideoStreamPlayer.new()
		probe.stream = stream
		var duration := probe.get_stream_length()
		probe.free()
		_all.append(path)
		if authored_short or duration < LONG_MIN_SECONDS:
			_short.append(path)
			if filename.begins_with(BEGINNING_PREFIX):
				_beginning.append(path)
			else:
				_random.append(path)
		else:
			_long.append(path)


static func shuffled_random(base_seed: int, cycle: int) -> Array[String]:
	var deck := random_paths()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base_seed) ^ (cycle * 104729 + 0x7A9E5)
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: String = deck[i]
		deck[i] = deck[j]
		deck[j] = held
	return deck


static func deterministic_fallback(base_seed: int, key: String,
		long_form := false) -> String:
	var library := paths(long_form)
	if library.is_empty():
		return ""
	return library[posmod(hash(key) ^ base_seed, library.size())]
