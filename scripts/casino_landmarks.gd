class_name CasinoLandmarks
extends RefCounted
## Authored identities attached once to the base route. They survive streaming
## and topology changes; the graph's actual doors remain the authority.

const LAST_CHANCE := "last_chance"
const LOUNGE := "sunken_lounge"
const PHONE := "red_telephone"

static func plan(route: DescentRoute) -> Dictionary:
	var out := {}
	if route.theme != 0:
		return out
	var rooms: Array[Vector2i] = []
	var halls: Array[Vector2i] = []
	var seen := {}
	for at in route.path_from_origin():
		var room := WorldGen.room_id(route.world_seed, at)
		if seen.has(room) or room == route.origin or room == route.target:
			continue
		seen[room] = true
		if WorldGen.corridor(route.world_seed, room) != 0:
			halls.append(room)
		else:
			rooms.append(room)
	# A rare route can be almost entirely passages. Landmark furnishing
	# replaces hallway partitions, so one passage cell can open into a room.
	if rooms.is_empty() and not halls.is_empty():
		rooms.append(halls.pop_front())
	if rooms.is_empty():
		return out
	out[rooms[0]] = LAST_CHANCE
	# Prefer an actual hotel passage. A route without one gets a short inserted
	# passage in a spare room, with circulation around both open ends.
	if not halls.is_empty():
		out[halls[0]] = PHONE
	elif rooms.size() > 2:
		out[rooms[1]] = PHONE
	var candidates: Array[Vector2i] = []
	for room in rooms:
		if not out.has(room):
			candidates.append(room)
	if candidates.is_empty():
		for hall in halls:
			if not out.has(hall):
				candidates.append(hall)
	if not candidates.is_empty():
		var pick := candidates[candidates.size() / 2]
		for room in candidates:
			if WorldGen.room_size(route.world_seed, room) == 1:
				pick = room
				break
		out[pick] = LOUNGE
	return out

static func style_for(kind: String, original: int) -> int:
	match kind:
		LAST_CHANCE: return WorldGen.STYLE_SLOTS
		LOUNGE: return WorldGen.STYLE_LOUNGE
		PHONE: return original if original == WorldGen.STYLE_HALLWAY else WorldGen.STYLE_EMPTY
	return original

static var _ring: AudioStreamWAV

static func telephone_ring() -> AudioStreamWAV:
	if _ring != null:
		return _ring
	var samples := PackedFloat32Array()
	samples.resize(int(SoundBank.RATE * 12.0))
	for i in int(SoundBank.RATE * 2.0):
		var t := float(i) / SoundBank.RATE
		var beat := fmod(t, 1.0)
		var envelope := minf(1.0, beat * 60.0) * clampf((0.62 - beat) * 30.0, 0.0, 1.0)
		var tremolo := 0.55 + 0.45 * sin(TAU * 24.0 * t)
		samples[i] = envelope * tremolo * (sin(TAU * 760.0 * t) * 0.22 + sin(TAU * 1010.0 * t) * 0.12)
	_ring = SoundBank._wav(samples, true)
	return _ring
