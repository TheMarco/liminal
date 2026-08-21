class_name CliOptions
extends RefCounted
## Every `--flag` the game accepts, parsed once.
##
## main.gd previously called OS.get_cmdline_user_args() from sixteen places, and
## three other scripts re-parsed it for their own dev flags. Each site invented
## its own prefix arithmetic, and the "is this a headless/QA start?" test was
## written out three times with slightly different bodies -- which is how
## audit_wander_mode.gd came to be run without the `--nologo` it documents.
##
## Flags are documented in README under "Run it". Anything unrecognised is
## ignored, as before: the engine's own arguments arrive on this list too.

# --- world selection ---
var world_seed := 0
var active_level := 0            # a THEME id, not a key index
var spawn := Vector3.ZERO
var spawn_given := false
var yaw := PI                    # face into the room
var yaw_given := false

# --- mode ---
var descent := false
var descent_floor := -1          # 1-based on the command line, -1 when absent
var attention := -1.0            # -1 when not overridden

# --- presentation ---
## RECOVERED TAPE is the default recording mode (owner, 2026-08-20);
## --crt-mode boots the clean tube instead, B still toggles live.
var found_footage := true
var nocrt := false
var notaa := false
var nologo := false
var screenshot := ""
## Seconds to run before the frame is captured. The default is enough for the
## world to stream in, but not for anything the director gates behind the
## arrival presentation: a figure cannot spawn at all until that hold lifts, so
## photographing one needs a longer run.
var shot_delay := 2.5

# --- dev ---
var audit := false
var bench := false
var chunktime := false
var spin := false
var flashlight := false
var tune := false
var caption_preview := false
var haunt := false
var haunt_at := Vector3.ZERO
var haunt_at_given := false
## Dev: auto-press play on the objective room's tape right after floor start,
## so screenshot runs can verify the zoom and the footage.
var play_tape := false
## Dev: force frequent passing-shadow and corner-apparition attempts.
var passer := false
var photo_debug := false
## Dev: after the arrival hold, auto-raise the camera and fire the shutter
## 0.7s later so screenshot runs can verify both camera presentation states.
var photo_shoot := false
var haunt_variant := -1
var whispers := false
var heartbeat := false


static func parse() -> CliOptions:
	return parse_args(OS.get_cmdline_user_args())


## Split out from parse() so a test can feed it an argument list.
static func parse_args(args: PackedStringArray) -> CliOptions:
	var o := CliOptions.new()
	for arg in args:
		if arg.begins_with("--seed="):
			o.world_seed = int(arg.substr(7))
		elif arg.begins_with("--pos="):
			var parts := arg.substr(6).split(",")
			if parts.size() >= 2:
				o.spawn = Vector3(float(parts[0]), 0.15, float(parts[1]))
				o.spawn_given = true
		elif arg.begins_with("--yaw="):
			o.yaw = deg_to_rad(float(arg.substr(6)))
			o.yaw_given = true
		elif arg.begins_with("--level="):
			var lv := int(arg.substr(8))
			o.active_level = lv if WorldGen.THEMES.has(lv) else 0
		elif arg == "--mode=descent":
			o.descent = true
		elif arg.begins_with("--descent-floor="):
			o.descent_floor = int(arg.substr(16))
		elif arg.begins_with("--attention="):
			o.attention = clampf(float(arg.substr(12)), 0.0, 1.0)
		elif arg == "--found-footage":
			o.found_footage = true
		elif arg == "--crt-mode":
			o.found_footage = false
		elif arg == "--nocrt":
			o.nocrt = true
		elif arg == "--notaa":
			o.notaa = true
		elif arg == "--nologo":
			o.nologo = true
		elif arg.begins_with("--screenshot="):
			o.screenshot = arg.substr(13)
		elif arg.begins_with("--shot-delay="):
			o.shot_delay = maxf(0.1, float(arg.substr(13)))
		elif arg == "--audit":
			o.audit = true
		elif arg == "--bench":
			o.bench = true
		elif arg == "--chunktime":
			o.chunktime = true
		elif arg == "--spin":
			o.spin = true
		elif arg == "--flashlight":
			o.flashlight = true
		elif arg == "--tune":
			o.tune = true
		elif arg == "--caption-preview":
			o.caption_preview = true
		elif arg == "--haunt":
			o.haunt = true
		elif arg == "--play-tape":
			o.play_tape = true
		elif arg == "--passer":
			o.passer = true
		elif arg == "--photo-debug":
			o.photo_debug = true
		elif arg == "--photo-shoot":
			o.photo_shoot = true
		elif arg.begins_with("--haunt-at="):
			var parts := arg.substr(11).split(",")
			if parts.size() >= 2:
				o.haunt_at = Vector3(float(parts[0]), 0, float(parts[1]))
				o.haunt_at_given = true
			if parts.size() >= 3:
				o.haunt_variant = int(parts[2])
		elif arg == "--whispers":
			o.whispers = true
		elif arg == "--heartbeat":
			o.heartbeat = true
	return o


## True when the run goes straight into the world with no title card. Screenshot
## and --nologo starts both skip it, and the world audio is therefore never
## silenced on the way in.
func skips_title() -> bool:
	return nologo or not screenshot.is_empty()


## Audits and screenshot helpers quit after a few seconds. Don't leave background
## glTF workers alive during their forced exit.
func quick_exit() -> bool:
	return audit or not screenshot.is_empty()
