class_name AmbientPalette
extends RefCounted
## Finite room sounds. Never lift arrivals, voices or blackout cues.
const PALETTES := {
	0: ["knocks", "trolley", "vent"],
	1: ["printer", "vent", "ticking"],
	2: ["ballast", "ticking", "creak"],
	4: ["trolley", "vent", "metal"],
	5: ["trolley", "pipes", "creak"],
	6: ["ticking", "metal", "ballast"],
	7: ["metal", "trolley", "vent"],
	8: ["metal", "pipes", "knocks"],
	9: ["pipes", "drips", "vent"],
	10: ["printer", "vent", "ballast"],
	11: ["organic", "pipes", "creak"],
}
## User-provided replacements; preloads also make the export dependencies explicit.
const RECORDINGS := {
	"trolley": preload("res://sounds/room_events/trolley.mp3"),
	"vent": preload("res://sounds/room_events/vent.mp3"),
	"printer": preload("res://sounds/room_events/printer.mp3"),
	"ticking": preload("res://sounds/room_events/ticking.mp3"),
	"ballast": preload("res://sounds/room_events/ballast.mp3"),
	"metal": preload("res://sounds/room_events/metal.mp3"),
	"pipes": preload("res://sounds/room_events/pipes.mp3"),
	"drips": preload("res://sounds/room_events/drips.mp3"),
	"organic": preload("res://sounds/room_events/organic.mp3"),
}
## Measured RMS difference from each previous source, before the existing -11 dB
## event gain and distance attenuation. Preserve the mix without altering MP3s.
const GAIN_DB := {
	"trolley": 6.4, "vent": -4.2, "printer": -0.6,
	"ticking": 9.5, "ballast": -4.8, "metal": -7.5,
	"pipes": 6.8, "drips": -1.9, "organic": 5.3,
}

static func kinds(theme: int) -> Array:
	return PALETTES.get(theme, ["knocks", "creak", "vent"]).duplicate()

static func stream(kind: String) -> AudioStream:
	if kind == "knocks": return SoundBank.thud()
	if kind == "creak": return SoundBank.creak()
	var recording: AudioStreamMP3 = RECORDINGS.get(kind, RECORDINGS["vent"])
	recording.loop = false
	return recording

static func gain_db(kind: String) -> float:
	return float(GAIN_DB.get(kind, 0.0 if kind in ["knocks", "creak"] else GAIN_DB["vent"]))
