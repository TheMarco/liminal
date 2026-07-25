class_name Heartbeat
extends AudioStreamPlayer
## Your pulse, which the building is allowed to raise.
##
## Frights push a tension value up; it bleeds away on its own. Volume and rate
## both follow it, so a scare is not merely louder — the beat quickens, and
## then slows as nothing further happens. Non-positional, because this is the
## one sound that is not in the room with you.
##
## The decay is what makes it work. A heartbeat that snaps off the moment the
## figure fades is a sound effect; one that is still going twenty seconds later,
## slowly settling while you stand in an empty corridor deciding whether to
## turn around, is the thing the frights are actually for.

## Tension added by each kind of event, before clamping.
const BUMP_SEEN := 0.85       # one of them is on screen and you have seen it
const BUMP_BURNED := 0.45     # you killed it, but you were close enough to
const BUMP_STARED := 0.22     # you faced one down without the torch

## Seconds for a full-tension fright to bleed back to nothing, once whatever
## caused it has gone. Long on purpose.
const CALM_TIME := 26.0
## Tension below this is not worth hearing; the player is calm.
const FLOOR := 0.035
## How close a figure has to be before its presence alone sustains tension —
## you can hear your own pulse when something is in the room, not only when it
## startled you.
const NEAR_D := 9.0
const NEAR_HOLD := 0.42       # tension that proximity alone will maintain

## Rate scaling. A frightened heart is faster, not just louder.
const RATE_CALM := 0.86
const RATE_PANIC := 1.26
## Volume is dropped this far at zero tension before the player is stopped.
const SILENT_DB := -34.0

## Breathing rides the same fright, but only joins above this. Mild dread is a
## pulse; panting over the top of it is panic, and the two arriving together
## gives the game nowhere to escalate to. Below the threshold you are only
## aware of your heart.
const BREATH_ENTER := 0.44
const BREATH_RATE_CALM := 0.90
const BREATH_RATE_PANIC := 1.18
const BREATH_SILENT_DB := -30.0

var figures: ShadowFigures
var suspended := false

var _tension := 0.0
var _base_db := 0.0
var _breath: AudioStreamPlayer
var _breath_db := 0.0
var _dev := false


func _ready() -> void:
	_dev = OS.get_cmdline_user_args().has("--heartbeat")
	var br := Sfx.breathing()
	if br[0] != null:
		# A child rather than a second stream on this node: both layers have to
		# be audible at once, at independent levels and rates.
		_breath = AudioStreamPlayer.new()
		_breath.stream = br[0]
		_breath_db = float(br[1])
		_breath.bus = "Hall"
		_breath.volume_db = _breath_db + BREATH_SILENT_DB
		add_child(_breath)
	var hb := Sfx.heartbeat()
	if hb[0] == null:
		return
	stream = hb[0]
	_base_db = float(hb[1])
	bus = "Hall"
	volume_db = _base_db + SILENT_DB


## A fright. Raises tension, never lowers it — a second scare while you are
## still recovering from the first should compound, not reset.
func bump(amount: float) -> void:
	if suspended:
		return
	_tension = clampf(_tension + amount, 0.0, 1.0)
	if _dev:
		print("heartbeat: +%.2f -> %.2f" % [amount, _tension])


## Level change: whatever frightened you is in a building you have left.
func reset() -> void:
	_tension = 0.0
	if playing:
		stop()
	volume_db = _base_db + SILENT_DB
	if _breath != null:
		if _breath.playing:
			_breath.stop()
		_breath.volume_db = _breath_db + BREATH_SILENT_DB


func tension() -> float:
	return _tension


func _process(dt: float) -> void:
	if suspended:
		if playing:
			_tension = maxf(0.0, _tension - dt / CALM_TIME)
			_apply()
		return
	# Something standing close by holds the pulse up without needing to startle
	# you again. It cannot raise tension past NEAR_HOLD on its own — being
	# stalked is a background dread, and a jump is still a jump.
	var near := _nearest()
	if near < NEAR_D and _tension < NEAR_HOLD:
		var closeness := 1.0 - (near / NEAR_D)
		_tension = minf(NEAR_HOLD, _tension + closeness * dt * 0.55)
	else:
		_tension = maxf(0.0, _tension - dt / CALM_TIME)
	_apply()


func _apply() -> void:
	_apply_breath()
	if _tension <= FLOOR:
		if playing:
			stop()
		return
	if not playing:
		play()
	# Curved rather than linear: the top of the range is where a fright lives,
	# and a linear map spends most of its travel on levels you cannot hear.
	var t := sqrt(_tension)
	volume_db = _base_db + SILENT_DB * (1.0 - t)
	pitch_scale = lerpf(RATE_CALM, RATE_PANIC, t)


## The second layer, on its own curve. It is silent until BREATH_ENTER and then
## climbs across whatever range is left, so it arrives as a change rather than
## as more of the same.
func _apply_breath() -> void:
	if _breath == null:
		return
	if _tension <= BREATH_ENTER:
		if _breath.playing:
			_breath.stop()
		return
	if not _breath.playing:
		_breath.play()
	var b := (_tension - BREATH_ENTER) / maxf(1.0 - BREATH_ENTER, 0.001)
	b = sqrt(clampf(b, 0.0, 1.0))
	_breath.volume_db = _breath_db + BREATH_SILENT_DB * (1.0 - b)
	_breath.pitch_scale = lerpf(BREATH_RATE_CALM, BREATH_RATE_PANIC, b)


## Distance to the closest live figure, or a large number when the floor is
## empty. Proximity is a real part of dread and costs nothing to sample.
func _nearest() -> float:
	if figures == null or not is_instance_valid(figures):
		return 1e9
	return figures.nearest_distance()
