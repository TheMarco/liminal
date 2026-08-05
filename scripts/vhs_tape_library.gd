class_name VhsTapeLibrary
extends RefCounted
## Runtime catalogue for every converted recording in videos/tapes. Keeping the
## directory authoritative means a newly imported .ogv joins the next session
## without another hand-maintained list in gameplay code.

const TAPE_DIR := "res://videos/tapes"
const LONG_MIN_SECONDS := 30.0

static var _all: Array[String] = []
static var _short: Array[String] = []
static var _long: Array[String] = []


static func paths(long_form := false) -> Array[String]:
	_scan()
	return (_long if long_form else _short).duplicate()


static func all_paths() -> Array[String]:
	_scan()
	return _all.duplicate()


## Mandatory Descent recordings are story chapters, not random draws. The
## sorted catalogue is their authored order: chapter one belongs to floor one,
## chapter two to floor two, and so on. During development there may be fewer
## than the ten required recordings; cycling keeps every objective playable
## until the remaining files are added without changing the chapters already
## present.
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
		var stream := load(path) as VideoStream
		if stream == null:
			continue
		var probe := VideoStreamPlayer.new()
		probe.stream = stream
		var duration := probe.get_stream_length()
		probe.free()
		_all.append(path)
		if duration >= LONG_MIN_SECONDS:
			_long.append(path)
		else:
			_short.append(path)


static func shuffled(base_seed: int, cycle: int, long_form := false) -> Array[String]:
	var deck := paths(long_form)
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
