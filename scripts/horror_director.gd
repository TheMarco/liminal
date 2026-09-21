class_name HorrorDirector
extends Node
## A deliberately small pacing authority. Individual horror systems still own
## their geometry, probability and behaviour; this node only prevents unrelated
## beats from talking over one another and guarantees a breath after major danger.

const HOSTILE_RECOVERY_EARLY := 10.0
const HOSTILE_RECOVERY_LATE := 6.0
const BLACKOUT_RECOVERY_EARLY := 8.0
const BLACKOUT_RECOVERY_LATE := 5.0
const VISUAL_RECOVERY := 4.0
const WHISPER_RECOVERY := 1.5
const AMBIENT_RECOVERY := 0.8

var enabled := false
var pressure := 0.0
var scripted_hold := false

var _hostile_count := 0
var _blackout_active := false
var _visual_left := 0.0
var _whisper_left := 0.0
var _ambient_left := 0.0
var _recovery_left := 0.0


func _physics_process(dt: float) -> void:
	advance(dt)


## Public clock hook keeps the state machine deterministic in its focused audit.
func advance(dt: float) -> void:
	_visual_left = maxf(0.0, _visual_left - dt)
	_whisper_left = maxf(0.0, _whisper_left - dt)
	_ambient_left = maxf(0.0, _ambient_left - dt)
	_recovery_left = maxf(0.0, _recovery_left - dt)


func reset_floor() -> void:
	_hostile_count = 0
	_blackout_active = false
	_visual_left = 0.0
	_whisper_left = 0.0
	_ambient_left = 0.0
	_recovery_left = 0.0
	scripted_hold = false


func set_pressure(value: float) -> void:
	pressure = clampf(value, 0.0, 1.0)


func set_scripted_hold(on: bool) -> void:
	scripted_hold = on
	if on:
		# A tape, card or arrival presentation owns the mix from this frame on.
		_visual_left = 0.0
		_whisper_left = 0.0
		_ambient_left = 0.0


func can_start_hostile() -> bool:
	if not enabled:
		return true
	# Reinforcements are part of one hostile encounter, not a competing beat.
	if _hostile_count > 0:
		return not scripted_hold and not _blackout_active
	return not scripted_hold and not _blackout_active \
		and _visual_left <= 0.0 and _whisper_left <= 0.0 \
		and _ambient_left <= 0.0 and _recovery_left <= 0.0


func set_hostile_count(value: int, start_recovery := true) -> void:
	var previous := _hostile_count
	_hostile_count = maxi(0, value)
	if enabled and start_recovery and previous > 0 and _hostile_count == 0:
		_recovery_left = maxf(_recovery_left, lerpf(
			HOSTILE_RECOVERY_EARLY, HOSTILE_RECOVERY_LATE, pressure))


func try_start_blackout(priority := false) -> bool:
	if not enabled:
		return true
	if scripted_hold or _blackout_active:
		return false
	if not priority and (_hostile_count > 0 or _visual_left > 0.0 \
			or _whisper_left > 0.0 or _ambient_left > 0.0 \
			or _recovery_left > 0.0):
		return false
	if priority:
		# A scheduled power failure is the floor's architectural beat, not a
		# disposable ambience attempt. Figures are made passive by DescentRun for
		# its duration; clear lesser channels so they cannot starve it for minutes.
		_visual_left = 0.0
		_whisper_left = 0.0
		_ambient_left = 0.0
		_recovery_left = 0.0
	_blackout_active = true
	return true


func end_blackout() -> void:
	if not _blackout_active:
		return
	_blackout_active = false
	if enabled:
		_recovery_left = maxf(_recovery_left, lerpf(
			BLACKOUT_RECOVERY_EARLY, BLACKOUT_RECOVERY_LATE, pressure))


func try_start_visual(seconds: float) -> bool:
	if not enabled:
		return true
	if not _can_start_quiet_beat():
		return false
	_visual_left = maxf(0.1, seconds)
	_recovery_left = maxf(_recovery_left, _visual_left + VISUAL_RECOVERY)
	return true


func try_start_whisper(seconds: float) -> bool:
	if not enabled:
		return true
	if not _can_start_quiet_beat():
		return false
	_whisper_left = maxf(0.1, seconds)
	_recovery_left = maxf(_recovery_left, _whisper_left + WHISPER_RECOVERY)
	return true


func try_start_ambient(seconds: float) -> bool:
	if not enabled:
		return true
	if not _can_start_quiet_beat():
		return false
	_ambient_left = maxf(0.1, seconds)
	_recovery_left = maxf(_recovery_left, _ambient_left + AMBIENT_RECOVERY)
	return true


func _can_start_quiet_beat() -> bool:
	return not scripted_hold and not _blackout_active and _hostile_count == 0 \
		and _visual_left <= 0.0 and _whisper_left <= 0.0 \
		and _ambient_left <= 0.0 and _recovery_left <= 0.0


func snapshot() -> Dictionary:
	return {
		"hostiles": _hostile_count,
		"blackout": _blackout_active,
		"visual": _visual_left,
		"whisper": _whisper_left,
		"ambient": _ambient_left,
		"recovery": _recovery_left,
		"hold": scripted_hold,
	}
