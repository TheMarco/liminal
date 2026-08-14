class_name ShadowFigure
extends Node3D
## One of them. A real human silhouette (CC0/CC-BY photo-traced cutouts in
## textures/ghosts/) on a cylindrical billboard, edges eaten by drifting
## noise. Watching it does not stop it and cannot banish it: it walks at you
## slowly while you hold it in view, and closes hard the moment you cannot see
## it. It follows through several rooms before distance can finally shed it;
## the torch or its touch can end the encounter sooner.

const FADE_T := 0.95

## The creep. Watching a figure never freezes it — it keeps coming, slowly
## enough that a player with a plan has time to execute it.
const ADVANCE_SPD := 1.25
## The weeping-angel speed. While it is genuinely off screen — or behind
## something — it does not creep, it closes. Turning your back is the expensive
## act, and the distance you lose for it has to be large enough to read as a
## jump when you turn round again, not as a slow walk you merely missed.
const UNSEEN_SPD := 4.5
## Ground it must gain while unobserved before looking back at it is its own
## event. Below this it was only walking; at or above it, it lunged.
const REVEAL_GAIN := 2.0
const REVEAL_SCARE_GAP := 3.0
const ADVANCE_MIN := 1.05   # it has you at arm's length
## Coming out from behind cover costs it a beat, which gives the player a fair
## window to aim after the figure has walked around an obstruction.
const REVEAL_HOLD := 0.6
## The widest camera-facing cutout is roughly 1.3m across. Movement reserves
## that entire silhouette, not just an invisible point at its feet, so no part
## of a ghost can protrude through a wall while it approaches.
## Slimmer than the visual silhouette on purpose: at 0.68 the capsule could
## not fit the narrower generated doorways at all, so a pursuing figure hit
## the frame and stalled there. A little visual overlap at a jamb is a fair
## price for it actually coming through the door.
const MOVE_RADIUS := 0.52
## The visible cutout can loom above an ordinary person, but its movement
## sweep must fit below the 2.25m lintel used by most generated doorways.
## At 2.55m the capsule hit the header even when perfectly centred in the
## opening, so doorway-aware routing alone could never make it cross.
const MOVE_HEIGHT := 2.08
const MOVE_LOOKAHEAD := 0.18
const ROUTE_REPATH_TIME := 0.5
const ROUTE_SEARCH_RADIUS := 32
const DOORWAY_CROSS_INSET := 0.28
## A player has to put real architecture behind them to escape an encounter.
## The figure follows through this many room boundaries, then may give up only
## while the player remains in a different room.
const CHASE_DOOR_LIMIT := 3
const NO_ROOM := Vector2i(2147483647, 2147483647)

## Per-variant behaviour: [creep m/s, unseen m/s, burn s, unseen park m,
## chase doors]. The first four variants are the baseline; the last three are
## archetypes a player learns to recognise, so late floors can introduce a new
## idea instead of only shortening the spawn interval.
## HARD CONSTRAINT on every row: (park − ADVANCE_MIN) / creep ≥ burn. That
## inequality IS the always-a-burn-window guarantee the 3.6m park exists for;
## the ghost room audit enforces it over this whole table.
const TUNING := {
	REVENANT: [1.25, 4.5, 1.5, 3.6, 3],
	DROWNED:  [1.25, 4.5, 1.5, 3.6, 3],
	PILGRIM:  [1.25, 4.5, 1.5, 3.6, 3],
	TRAILING: [1.25, 4.5, 1.5, 3.6, 3],
	# The one you cannot outwalk: slow, but follows through five doors, so the
	# usual three-room escape leaves it still coming.
	GAOLER:   [0.90, 4.5, 1.5, 3.6, 5],
	# Parks close out of the dark. The window is tight (1.08s of creep against
	# a 1.0s burn) and the answer is fast — deliberately the game's hardest
	# margin, and why its burn is the shortest.
	REACHER:  [1.25, 4.5, 1.0, 2.4, 3],
	# One speed, seen or not. Watching it buys nothing, so the only answers
	# are the torch or architecture. 1.59s of creep from its park still
	# clears the full 1.5s burn.
	DRIFTER:  [1.60, 1.60, 1.5, 3.6, 3],
}
## The unseen lunge parks here, short of the kill. It may only take the last
## metres while being watched, so however hard it closed in the dark there is
## always time to raise the torch: 2.55m of creep at 1.25 m/s is a full burn
## plus margin.
const UNSEEN_MIN := 3.6

## Flashlight burn. The beam has to stay on it; look away and the progress
## bleeds back. It keeps coming the whole time.
const BURN_TIME := 1.5
const BURN_DRAIN := 1.7
## The torch's own cone is 46 degrees, which would let a figure burn while it
## sat near the edge of the frame. Aiming should mean aiming.
const BURN_CONE := 0.34
const BURN_FADE := 1.25     # the spectacular one runs longer than a stare-out
# Not an angle any more: a cone guessed at the frustum and got it wrong at
# the frame edges, so a figure could appear plainly on screen and stay
# silent. Camera3D.is_position_in_frustum is the real test.
const SCARE_GAP := 6.0      # only stops two figures stacking stingers

signal burned_away
signal reached_player
## Fired the first frame this figure is genuinely on screen, alongside its
## stinger — the moment the player registers that something is there.
signal seen_by_player

## Descent may add a real doorway while this figure is alive. Sharing the
## floor resolver keeps its BFS and exact jamb waypoint on rendered geometry.
var topology: DescentTopology

## WAITING is the Descent anomaly that is already standing in the corner when
## you walk in. It is a full figure — it burns, it kills, it feeds the
## heartbeat — it simply holds its ground until the player is in its room.
enum Mode { AMBIENT, WAITING }
## Seven of them, and every one is animated. The static photo-traced cutouts
## that came before were replaced wholesale: a still silhouette standing
## perfectly motionless reads as a decal the moment it shares a frame with one
## that breathes, so the roster is animated or it is nothing.
enum { REVENANT, DROWNED, PILGRIM, TRAILING, GAOLER, REACHER, DRIFTER }

# variant -> [texture sheet, height m, width factor, flip, floats]
const LOOKS := {
	REVENANT: ["wraith_anim", 2.05, 1.0, false, true],
	DROWNED:  ["wraith2", 1.98, 1.0, false, false],
	PILGRIM:  ["wraith3", 2.02, 1.0, true, false],
	TRAILING: ["wraith4", 2.24, 1.0, false, true],
	GAOLER:   ["wraith5", 2.10, 1.0, true, false],
	REACHER:  ["wraith6", 1.96, 1.0, false, false],
	DRIFTER:  ["wraith7", 2.18, 1.0, true, true],
}
# sheet -> [aspect (w/h of ONE FRAME), feet, head]
# feet/head are where the body actually starts and stops inside a frame, as a
# fraction of frame height measured up from the bottom. These are grids, so the
# numbers describe a single cell and the shader does the addressing.
# Produced by tools/build_flipbook.py, which prints them.
const BODY := {
	"wraith_anim": [0.615, 0.014, 1.000],
	"wraith2":     [0.535, 0.000, 1.000],
	"wraith3":     [0.642, 0.000, 1.000],
	"wraith4":     [0.441, 0.010, 1.000],
	"wraith5":     [0.625, 0.000, 1.000],
	"wraith6":     [0.559, 0.003, 1.000],
	"wraith7":     [0.448, 0.003, 1.000],
	# The passing-shadow walk cycles. Measured from the built sheets: the
	# figure traverses the frame, so the box is roughly as wide as it is tall
	# and the crossing distance is baked into the animation.
	"passer1":     [1.007, 0.052, 1.000],
	"passer2":     [1.135, 0.052, 0.997],
	"passer3":     [0.899, 0.087, 0.997],
	"passer4":     [1.167, 0.337, 0.990],
}
# Every sheet carries its own soft smoke edge, so the shader must not carve a
# new one on top.
const SOFT := ["wraith_anim", "wraith2", "wraith3", "wraith4", "wraith5",
	"wraith6", "wraith7", "passer1", "passer2", "passer3", "passer4"]

## Animated cutouts: [columns, rows, frames, playback fps]. Godot's only video
## codec is Theora, which carries no alpha, so an animated apparition is a
## sprite sheet whose frames the ghost shader cycles by offsetting UVs. Built
## from source loops by tools/build_flipbook.py.
const FLIPBOOKS := {
	"wraith_anim": [6, 4, 24, 12.0],
	"wraith2":     [6, 4, 24, 12.0],
	"wraith3":     [6, 4, 24, 12.0],
	"wraith4":     [6, 4, 24, 12.0],
	"wraith5":     [6, 4, 24, 12.0],
	"wraith6":     [6, 4, 24, 12.0],
	"wraith7":     [6, 4, 24, 12.0],
	"passer1":     [6, 4, 24, 12.0],
	"passer2":     [6, 4, 24, 12.0],
	"passer3":     [6, 4, 24, 12.0],
	"passer4":     [6, 4, 24, 12.0],
}
## Cutouts whose own colour is worth keeping. All seven have lit eyes — one
## pair is green rather than red — and those are the only pixels allowed to
## survive the black-absence treatment.
const COLOURED := ["wraith_anim", "wraith2", "wraith3", "wraith4", "wraith5",
	"wraith6", "wraith7"]

## The loop must never be legible as a loop. A sprite sheet running at a fixed
## rate is read as an animated cutout within about two seconds of being looked
## at, no matter how good the frames are. So the script drives the frame rather
## than the shader's clock: under the player's gaze it plays slow and stalls at
## random intervals, and while it is unwatched it runs fast. Turning back finds
## it in a pose it was never seen reaching, which is the same trick the movement
## already plays with distance.
const ANIM_OBSERVED_RATE := 0.55
const ANIM_UNSEEN_RATE := 1.30
const ANIM_HOLD_MIN := 0.16
const ANIM_HOLD_MAX := 0.42
const ANIM_HOLD_GAP_MIN := 1.4
const ANIM_HOLD_GAP_MAX := 4.2

static var _mats := {}
## Shared across every figure: a scare that fires twice in a minute is a
## sound effect, not a scare. Wall-clock so it survives level switches.
static var _last_scare := -1000.0
## The reveal cue keeps its own clock. It is allowed to fire much more often
## than a first-sighting stinger, because it is the payoff for a thing the
## player just did rather than an announcement they had no part in.
static var _last_reveal := -1000.0

var player: Player
var variant := REVENANT
var mode := Mode.AMBIENT
var grace := 0.9            # can't be stared away until this runs out
var announce := false       # a soft footstep as it arrives
## Set by ShadowFigures before the node enters the tree. Only the WAITING
## anomaly still cares: it holds its ground until the player enters its room.
## An active figure tracks its own crossed-room chase budget separately.
var origin_room := NO_ROOM

## The variant's row from TUNING, read once in _ready.
var _creep_spd := ADVANCE_SPD
var _unseen_spd := UNSEEN_SPD
var _burn_time := BURN_TIME
var _unseen_min := UNSEEN_MIN
var _chase_limit := CHASE_DOOR_LIMIT

var _quad: MeshInstance3D
## Private stream. World dressing draws from the global generator while chunks
## build, and a figure is built inside that: every extra global randf() here
## shifts every prop authored after it and moves the world hash. Anything added
## to this script from now on must draw from here.
var _rng := RandomNumberGenerator.new()
var _anim_frame := 0.0
var _anim_fps := 0.0
var _anim_count := 0.0
var _anim_hold := 0.0
var _anim_next_hold := 0.0
var _fade := -1.0
var _fade_len := FADE_T
var _bob_t := 0.0
var _bob_base := 0.0
var _floats := false
var _eye_h := 1.4
var _seen := false
var _shiver: AudioStreamPlayer3D
var _burn := 0.0
var _burning := false
var _sway := 0.0
## Set by ShadowFigures while the rules have the player pinned. It still burns
## and still fades — it simply does not close the distance.
var suppressed := false
var _was_sighted := true
var _reveal := 0.0
## Whether the player could actually see it last frame — in frustum AND not
## behind anything. The seeing is what governs how fast it closes: watched,
## it creeps; unseen, it lunges.
var _observed := false
var _lost_dist := INF
var _avoid_sign := 0.0
var _avoid_angle := 0.0
var _route_left := 0.0
var _route_from := NO_ROOM
var _route_goal := NO_ROOM
var _route_waypoint := Vector3.INF
var _chase_room := NO_ROOM
var _chase_doors := 0
var _giving_up := false
var _move_shape: CapsuleShape3D
var _move_query: PhysicsShapeQueryParameters3D


static func _mat_for(texname: String) -> ShaderMaterial:
	if _mats.has(texname):
		return _mats[texname]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ghost.gdshader")
	# Flipbook sheets are WebP: a two dozen frame grid is an order of magnitude
	# larger than a single cutout, and PNG is the wrong trade at that size.
	var ext := "webp" if FLIPBOOKS.has(texname) else "png"
	m.set_shader_parameter("tex",
		load("res://textures/ghosts/%s.%s" % [texname, ext]))
	m.set_shader_parameter("noise_tex", Mats.detail_noise())
	if SOFT.has(texname):
		m.set_shader_parameter("erode_amt", 0.10)
		m.set_shader_parameter("edge0", 0.04)
		m.set_shader_parameter("edge1", 0.94)
		m.set_shader_parameter("edge_blur", 2.6)
	if FLIPBOOKS.has(texname):
		var fb: Array = FLIPBOOKS[texname]
		m.set_shader_parameter("flip_cols", float(fb[0]))
		m.set_shader_parameter("flip_rows", float(fb[1]))
		m.set_shader_parameter("flip_count", float(fb[2]))
		m.set_shader_parameter("flip_fps", float(fb[3]))
	if COLOURED.has(texname):
		m.set_shader_parameter("keep_colour", 1.0)
		m.set_shader_parameter("colour_gain", 1.0)
	_mats[texname] = m
	return m



func _ready() -> void:
	var tune: Array = TUNING[variant]
	_creep_spd = float(tune[0])
	_unseen_spd = float(tune[1])
	_burn_time = float(tune[2])
	_unseen_min = float(tune[3])
	_chase_limit = int(tune[4])
	var look: Array = LOOKS[variant]
	var body: Array = BODY[look[0]]
	var s := randf_range(0.96, 1.08)
	# LOOKS gives how tall the figure stands, not how tall its file is: blow
	# the quad up so the body inside it comes out at that height, then drop it
	# so the feet — not the haze under them — land on the floor.
	var h: float = look[1] * s
	var qh: float = h / (float(body[2]) - float(body[1]))
	var w: float = qh * float(body[0]) * float(look[2])
	_floats = look[4]
	_eye_h = h * 0.78
	_quad = MeshInstance3D.new()
	_quad.mesh = Chunk.QUAD
	_quad.scale = Vector3(w, qh, 1.0)
	_quad.material_override = _mat_for(look[0])
	_quad.position = Vector3(0, qh * (0.5 - float(body[1]))
		+ (0.06 if _floats else 0.0), 0)
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# ShaderMaterial is cached per texture; per-instance uniforms keep mirrored
	# poses and dissolves independent when several use the same cutout.
	_quad.set_instance_shader_parameter("fade", 1.0)
	_quad.set_instance_shader_parameter("flip", 1.0 if look[3] else 0.0)
	_quad.set_instance_shader_parameter("dissolve_seed", randf())
	_quad.set_instance_shader_parameter("burn", 0.0)
	_quad.set_instance_shader_parameter("ignite", 0.0)
	_quad.set_instance_shader_parameter("sway", 0.0)
	# Two of them on screen must not be marching in lockstep.
	_quad.set_instance_shader_parameter("flip_phase", randf())
	add_child(_quad)
	# The script owns the frame from here (see _animate), so the sheet's own
	# clock is overridden immediately rather than for one frame showing pose 0.
	if FLIPBOOKS.has(look[0]):
		var fb: Array = FLIPBOOKS[look[0]]
		_anim_count = float(fb[2])
		# No two figures share a playback rate, so even two of the same sheet
		# never fall into step.
		_anim_fps = float(fb[3]) * _rng.randf_range(0.86, 1.14)
		_anim_frame = _rng.randf() * _anim_count
		_anim_next_hold = _rng.randf_range(ANIM_HOLD_GAP_MIN, ANIM_HOLD_GAP_MAX)
		_quad.set_instance_shader_parameter("flip_frame", _anim_frame)
	_bob_base = position.y
	_bob_t = randf() * TAU
	if player != null:
		_move_shape = CapsuleShape3D.new()
		_move_shape.radius = MOVE_RADIUS
		_move_shape.height = MOVE_HEIGHT
		_move_query = PhysicsShapeQueryParameters3D.new()
		_move_query.shape = _move_shape
		_move_query.exclude = [player.get_rid()]
		_move_query.collision_mask = 1
		_move_query.collide_with_areas = false
		_move_query.collide_with_bodies = true
	_shiver = AudioStreamPlayer3D.new()
	_shiver.stream = SoundBank.shiver()
	_shiver.max_distance = 24.0
	_shiver.unit_size = 6.0
	_shiver.volume_db = -14.0
	_shiver.bus = SoundBank.HALL_BUS
	add_child(_shiver)
	# A world-placed figure is not on the haunt manager's books, so it hands
	# itself over: the manager owns the signal wiring that makes a kill refund
	# the torch, a stare cost attention and a contact end the run.
	if mode == Mode.WAITING:
		get_tree().call_group("figure_manager", "adopt", self)
	if announce:
		var sh := AudioStreamPlayer3D.new()
		sh.stream = SoundBank.randomized(SoundBank.step_carpet(), 1.2, 2.0)
		sh.pitch_scale = 0.68
		sh.max_distance = 22.0
		sh.unit_size = 6.0
		sh.volume_db = -14.0
		sh.bus = SoundBank.HALL_BUS
		add_child(sh)
		sh.play()


## Drives the sprite sheet's frame instead of letting the shader run it on a
## fixed clock. Under the gaze it plays slow and stalls; unwatched it runs on.
func _animate(dt: float, observed: bool) -> void:
	if _anim_count <= 0.0:
		return
	var rate := ANIM_UNSEEN_RATE
	if observed:
		rate = ANIM_OBSERVED_RATE
		# The stalls only ever happen while it is being looked at. Motion that
		# hitches under direct observation reads as something whose movement is
		# not coming from a body, and it costs no art to do.
		if _anim_hold > 0.0:
			_anim_hold -= dt
			rate = 0.0
		else:
			_anim_next_hold -= dt
			if _anim_next_hold <= 0.0:
				_anim_hold = _rng.randf_range(ANIM_HOLD_MIN, ANIM_HOLD_MAX)
				_anim_next_hold = _rng.randf_range(ANIM_HOLD_GAP_MIN, ANIM_HOLD_GAP_MAX)
				rate = 0.0
	else:
		_anim_hold = 0.0
	if rate <= 0.0:
		return
	_anim_frame = fmod(_anim_frame + _anim_fps * rate * dt, _anim_count)
	_quad.set_instance_shader_parameter("flip_frame", _anim_frame)


func _physics_process(dt: float) -> void:
	if player == null or not player.is_inside_tree():
		queue_free()
		return
	# A waiting figure is a fixture of its own room until the player walks into
	# that room. From that moment it is an ordinary encounter in every respect,
	# including its full multi-door chase budget.
	if mode == Mode.WAITING:
		var here := room_for(player, player.global_position)
		if here == room_for(player, global_position):
			mode = Mode.AMBIENT
			origin_room = here
			grace = maxf(grace, 0.6)
	if mode == Mode.AMBIENT:
		_update_chase_lifetime()
	if grace > 0.0:
		grace -= dt
	if _floats:
		# it does not stand. it hangs.
		_bob_t += dt
		position.y = _bob_base + 0.03 + sin(_bob_t * 1.1) * 0.035
	var cam := player.cam
	var eye := global_position + Vector3(0, _eye_h, 0)
	var to := eye - cam.global_position
	var dist := to.length()
	var fwd := -cam.global_transform.basis.z
	var aim := fwd.angle_to(to.normalized())
	var sighted := _clear_line(cam.global_position, eye)
	# Coming out from behind cover costs it a beat.
	if sighted and not _was_sighted:
		_reveal = REVEAL_HOLD
	_was_sighted = sighted
	if _reveal > 0.0:
		_reveal = maxf(0.0, _reveal - dt)
	# Whether the player can see it at all. Seen, it only creeps — but it
	# never stops. Take your eyes off it entirely and it closes hard.
	var observed := sighted and (cam.is_position_in_frustum(eye)
		or cam.is_position_in_frustum(global_position
			+ Vector3(0, _eye_h * 0.55, 0)))
	if observed != _observed:
		if observed:
			# You turned back into it. If it used the dark to cover real ground,
			# that is an event in its own right and gets its own cue.
			if _lost_dist < INF and _lost_dist - dist >= REVEAL_GAIN \
					and _fade < 0.0 and _seen:
				_reveal_scare()
		else:
			_lost_dist = dist
		_observed = observed
	if mode == Mode.AMBIENT and _fade < 0.0 and not suppressed \
			and _reveal <= 0.0 and grace <= 0.0:
		_advance(dt, observed)
	_animate(dt, observed)
	_sway += dt
	_quad.set_instance_shader_parameter("sway",
		sin(_sway * 0.9 + _bob_t))
	# The torch burns it away far faster than a stare, and keeps burning only
	# while the beam stays on it.
	if _fade < 0.0 and grace <= 0.0 and _in_beam(cam, aim, sighted):
		_burn = minf(_burn_time, _burn + dt)
		if not _burning:
			_burning = true
		if _burn >= _burn_time:
			_ignite()
			return
	else:
		_burning = false
		_burn = maxf(0.0, _burn - dt * BURN_DRAIN)
	_quad.set_instance_shader_parameter("burn", _burn / _burn_time)
	# The stinger belongs to the moment it is ON SCREEN — not the moment it is
	# placed, which can be behind a wall or outside the frame entirely. Test
	# the real frustum at three heights, because a tall figure can have its
	# middle in view while its head and feet are not, then confirm something
	# is not standing in the way.
	if not _seen and _fade < 0.0:
		var base := global_position
		var visible := cam.is_position_in_frustum(base + Vector3(0, _eye_h, 0)) \
			or cam.is_position_in_frustum(base + Vector3(0, _eye_h * 0.55, 0)) \
			or cam.is_position_in_frustum(base + Vector3(0, 0.2, 0))
		if visible and (sighted
				or _clear_line(cam.global_position, base + Vector3(0, _eye_h * 0.55, 0))):
			_seen = true
			_maybe_scare()
	if _fade >= 0.0:
		_fade -= dt
		# Normalise against the length this particular exit started with: a burn
		# runs longer than a stare-out and a seize is shorter, and dividing all
		# three by FADE_T would make two of them jump.
		_quad.set_instance_shader_parameter("fade",
			clampf(_fade / maxf(_fade_len, 0.001), 0.0, 1.0))
		if _fade <= 0.0:
			queue_free()


## Count doors the figure itself successfully follows through. Once it has
## crossed enough, separation into different rooms lets it give up. Returning
## to its room during that dissolve restores it immediately: natural escape
## must never make a figure vanish beside the player. Burns and contact keep
## their own terminal fades and are intentionally unaffected.
func _update_chase_lifetime() -> void:
	var ghost_room := room_for(player, global_position)
	var player_room := room_for(player, player.global_position)
	if _chase_room == NO_ROOM:
		_chase_room = ghost_room
	elif ghost_room != _chase_room:
		_chase_room = ghost_room
		_chase_doors += 1
	if _giving_up:
		if ghost_room == player_room:
			_giving_up = false
			_fade = -1.0
			_fade_len = FADE_T
			_quad.set_instance_shader_parameter("fade", 1.0)
		return
	if _chase_doors >= _chase_limit and ghost_room != player_room \
			and _fade < 0.0:
		_giving_up = true
		_fade = FADE_T
		_fade_len = FADE_T


## Something the player has actually laid eyes on and which is still out there.
## The stop rule asks this before charging: you are allowed to stop for it.
func is_pressing() -> bool:
	return _seen and _fade < 0.0


## One step closer, never through a wall and never past arm's length. A capsule
## reserves the figure's grounded movement body. When the direct route is
## blocked, a stable left/right preference makes it skirt the obstruction
## instead of vibrating between two equally valid directions.
func _advance(dt: float, observed := true) -> void:
	var player_to := player.global_position - global_position
	player_to.y = 0.0
	var player_d := player_to.length()
	if player_d < 0.001:
		return
	var step := (_creep_spd if observed else _unseen_spd) * dt
	# An unseen figure never completes the kill: it closes to its park distance
	# and waits there. Only the watched creep takes the last metres, so the
	# player always sees it coming and always has a burn window. Keyed on
	# observation, not on speed, because the Drifter moves at one speed either
	# way and must still park in the dark.
	if not observed:
		if player_d <= _unseen_min:
			return
		step = minf(step, player_d - _unseen_min)
	elif player_d - step <= ADVANCE_MIN:
		# The lit torch is a ward. While the beam lives it comes to arm's
		# length and looms there; the kill waits for the dark — a dead cell,
		# or a hand that switches off too soon.
		if player.flashlight != null and player.flashlight.visible:
			step = maxf(0.0, player_d - ADVANCE_MIN)
			if step <= 0.0001:
				return
		else:
			_seize()
			return
	# Chasing the player's exact position only works while both actors share a
	# cell. Across a wall it makes local avoidance orbit the wall indefinitely,
	# even when a real opening is a few metres to one side. Route over generated
	# open edges and aim beyond the next doorway so the capsule commits through
	# the opening before resuming its chase.
	var target := _route_target(dt)
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.001:
		return
	step = minf(step, d)
	var direct := to / d
	if _can_move(direct, step):
		global_position += direct * step
		_avoid_sign = 0.0
		_avoid_angle = 0.0
		return
	# Commit to the last detour that worked before re-scanning. Re-choosing
	# from scratch every frame ping-ponged between mirror-image angles at a
	# doorway, which read as the figure shivering against the frame.
	if _avoid_angle != 0.0:
		var held := direct.rotated(Vector3.UP,
			deg_to_rad(_avoid_angle) * _avoid_sign)
		if _can_move(held, step):
			global_position += held * step
			return
	var signs := [_avoid_sign, -_avoid_sign] if _avoid_sign != 0.0 else [-1.0, 1.0]
	# Shallow angles preserve forward pressure; the final wider choices let it
	# follow a long partition until a doorway or wall end becomes available.
	for angle_deg in [28.0, 52.0, 76.0, 92.0, 112.0, 138.0]:
		for side: float in signs:
			var dirv := direct.rotated(Vector3.UP, deg_to_rad(angle_deg) * side)
			if _can_move(dirv, step):
				global_position += dirv * step
				_avoid_sign = side
				_avoid_angle = angle_deg
				return
	# Boxed in: hold the ground rather than shiver against the geometry.
	_avoid_angle = 0.0


func _route_target(dt: float) -> Vector3:
	var start := _cell_for(global_position)
	var goal := _cell_for(player.global_position)
	if start == goal:
		_clear_route()
		return player.global_position
	_route_left -= dt
	if _route_left <= 0.0 or start != _route_from or goal != _route_goal:
		_route_left = ROUTE_REPATH_TIME
		_route_from = start
		_route_goal = goal
		var next := _next_route_cell(start, goal)
		_route_waypoint = _doorway_waypoint(start, next) \
			if next != start else Vector3.INF
	return _route_waypoint if _route_waypoint != Vector3.INF \
		else global_position


func _clear_route() -> void:
	_route_left = 0.0
	_route_from = NO_ROOM
	_route_goal = NO_ROOM
	_route_waypoint = Vector3.INF


func _next_route_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var parent := {}
	parent[start] = start
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == goal:
			break
		if maxi(absi(cell.x - start.x), absi(cell.y - start.y)) \
				>= ROUTE_SEARCH_RADIUS:
			continue
		for dir in 4:
			if _edge_info(cell, dir)["wall"]:
				continue
			var neighbor: Vector2i = cell + WorldGen.DIRV[dir]
			if parent.has(neighbor):
				continue
			parent[neighbor] = cell
			queue.append(neighbor)
	if not parent.has(goal):
		return start
	var at := goal
	while parent[at] != start:
		at = parent[at]
	return at


func _doorway_waypoint(from: Vector2i, to: Vector2i) -> Vector3:
	var dir := WorldGen.DIRV.find(to - from)
	if dir < 0:
		return global_position
	var edge: Dictionary = _edge_info(from, dir)
	var along := float(edge["t"])
	match dir:
		0:
			return Vector3(float(from.x + 1) * Chunk.S + DOORWAY_CROSS_INSET,
				global_position.y, float(from.y) * Chunk.S + along)
		1:
			return Vector3(float(from.x) * Chunk.S - DOORWAY_CROSS_INSET,
				global_position.y, float(from.y) * Chunk.S + along)
		2:
			return Vector3(float(from.x) * Chunk.S + along,
				global_position.y, float(from.y + 1) * Chunk.S + DOORWAY_CROSS_INSET)
		_:
			return Vector3(float(from.x) * Chunk.S + along,
				global_position.y, float(from.y) * Chunk.S - DOORWAY_CROSS_INSET)


func _edge_info(cell: Vector2i, dir: int) -> Dictionary:
	if topology != null:
		return topology.edge_info(cell, dir)
	return WorldGen.edge_info(player.world_seed, cell, dir,
		player.level_theme)


static func _cell_for(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / Chunk.S), floori(at.z / Chunk.S))


func _can_move(dirv: Vector3, step: float) -> bool:
	var probe := maxf(step, MOVE_LOOKAHEAD)
	var candidate := global_position + dirv * probe
	_move_query.transform = Transform3D(Basis.IDENTITY,
		candidate + Vector3(0, MOVE_HEIGHT * 0.5 + 0.04, 0))
	return player.get_world_3d().direct_space_state \
		.intersect_shape(_move_query, 1).is_empty()


static func room_for(p: Player, at: Vector3) -> Vector2i:
	var cell := _cell_for(at)
	return WorldGen.annex_room_id(p.world_seed, cell) \
		if p.level_theme == 2 else WorldGen.room_id(p.world_seed, cell)


## Is the torch actually on it? The light is mounted on the camera, so this is
## a tighter cone around where you are already looking — plus the beam's reach.
func _in_beam(cam: Camera3D, aim: float, sighted: bool) -> bool:
	var lamp := player.flashlight
	if lamp == null or not lamp.visible or not sighted:
		return false
	if global_position.distance_to(cam.global_position) > lamp.spot_range:
		return false
	return aim < BURN_CONE


## Burned out by the beam. This is the loud one: the silhouette tears apart from
## a bright front rather than quietly thinning, throws light on the walls around
## it, and screams on the way out.
func _ignite() -> void:
	_fade = BURN_FADE
	_fade_len = BURN_FADE
	_burning = false
	# Latch the consuming front. `burn` is released so the charge glow stops
	# fighting it; from here the exit is driven by the one-way fade.
	_quad.set_instance_shader_parameter("burn", 0.0)
	_quad.set_instance_shader_parameter("ignite", 1.0)
	burned_away.emit()
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.86, 0.94, 1.0)
	flash.light_energy = 7.5
	flash.omni_range = 7.0
	flash.shadow_enabled = false
	flash.position = Vector3(0, _eye_h, 0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, BURN_FADE * 0.8)
	# Its own recording rather than a jump-scare pitched up: a stinger is the
	# sound of something arriving, and this is the sound of something ending.
	var sc := Sfx.random_death()
	var pl := AudioStreamPlayer3D.new()
	pl.stream = sc[0]
	pl.volume_db = float(sc[1])
	# A shade either side of its own pitch, so seven recordings do not become
	# seven familiar noises once you have burned a few dozen.
	pl.pitch_scale = randf_range(0.93, 1.06)
	pl.unit_size = 8.0
	pl.max_distance = 34.0
	pl.bus = SoundBank.HALL_BUS
	var host := get_parent()
	if host != null:
		host.add_child(pl)
		pl.global_position = global_position + Vector3(0, _eye_h, 0)
		pl.finished.connect(pl.queue_free)
		pl.play()


## It got to you. The owning game mode decides the outcome.
func _seize() -> void:
	if _fade >= 0.0:
		return
	_fade = 0.45
	_fade_len = 0.45
	# The sound of this belongs to the player, not to the room, so the owner
	# plays it non-positionally. All that happens here is the lunge: the figure
	# surges the last of the distance and is gone into the frame.
	reached_player.emit()


## Fired the first frame this figure is actually on screen. No dice roll:
## seeing one and hearing nothing is the thing that reads as broken, so every
## figure you lay eyes on gets its stinger. The only gate is a few seconds so
## two arriving together do not stack.
func _maybe_scare() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_scare < SCARE_GAP:
		return
	_last_scare = now
	seen_by_player.emit()
	var sc := Sfx.random_scare()
	var pl := AudioStreamPlayer3D.new()
	pl.stream = sc[0]
	pl.volume_db = float(sc[1])
	pl.unit_size = 8.0
	pl.max_distance = 30.0
	pl.bus = SoundBank.HALL_BUS
	# hung on the parent, not on us: this figure stops existing in FADE_T
	# seconds and would take the sound with it half a second in
	var host := get_parent()
	if host == null:
		return
	host.add_child(pl)
	pl.global_position = global_position + Vector3(0, 1.4, 0)
	pl.finished.connect(pl.queue_free)
	pl.play()


## You looked away and it used the time. This is deliberately not the arrival
## stinger: that one is airy and says something is there, while this is pitched
## down and pushed louder because it has to say the thing MOVED, and it lands
## while the player is already looking at the proof.
func _reveal_scare() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_reveal < REVEAL_SCARE_GAP:
		return
	_last_reveal = now
	# The pulse should spike for this exactly as it does for a first sighting.
	seen_by_player.emit()
	var sc := Sfx.random_scare()
	var pl := AudioStreamPlayer3D.new()
	pl.stream = sc[0]
	pl.volume_db = float(sc[1]) + 3.0
	pl.pitch_scale = randf_range(0.68, 0.80)
	pl.unit_size = 8.0
	pl.max_distance = 30.0
	pl.bus = SoundBank.HALL_BUS
	var host := get_parent()
	if host == null:
		return
	host.add_child(pl)
	pl.global_position = global_position + Vector3(0, _eye_h, 0)
	pl.finished.connect(pl.queue_free)
	pl.play()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit["position"].distance_to(b) < 1.2
