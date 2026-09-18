class_name ShadowFigure
extends Node3D
## One of them. A real human silhouette (CC0/CC-BY photo-traced cutouts in
## textures/ghosts/) in a curved layered apparition, edges eaten by drifting
## noise. Watching it does not stop it and cannot banish it: it walks at you
## slowly while you hold it in view, and closes hard the moment you cannot see
## it. It follows through several rooms before distance can finally shed it;
## the torch or its touch can end the encounter sooner.

const FADE_T := 0.95
const WISP_SHADER := preload("res://shaders/ghost_wisp.gdshader")
## Local fog density at full presence. The env's volumetric fog is thin
## (~0.0016), so even a modest local volume reads as the air going wrong
## around the figure without becoming an opaque blob.
const GLOOM_DENSITY := 0.65

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
## Dynamic actors do not have physics bodies of their own. Reserve this much
## horizontal space explicitly so multiple pursuers cannot walk through one
## another as their routes converge on the player.
const PEER_SEPARATION := 1.4
## Pool decks, dry halls and bridges share this height. Water has no collider;
## its basin floor must never count as ground for an enemy. Reserve the feet
## as well as the centre so a walker cannot cut across the lip of a pool.
const POOL_SUPPORT_OFFSETS := [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0),
	Vector2(0, 1), Vector2(0, -1), Vector2(0.707107, 0.707107),
	Vector2(-0.707107, 0.707107), Vector2(0.707107, -0.707107),
	Vector2(-0.707107, -0.707107)]
const ROUTE_REPATH_TIME := 0.5
const DOORWAY_CROSS_INSET := MOVE_RADIUS + 0.40
const ROUTE_MAX_EXPANSIONS := 4096
const SPEED_PER_LEVEL := 0.03
const ACCELERATION := 3.5
const BRAKING := 9.0
## Navigation is allowed a few frames to publish a path, never enough time to
## read as an idle enemy. After this the actor actively walks a clear escape
## arc while both routing layers rebuild behind it.
const BLOCKED_REPLAN_SECONDS := 0.22
const RECOVERY_HOLD_SECONDS := 0.48
const RECOVERY_PROBE := 0.46
const RECOVERY_ANGLES := [0.0, -30.0, 30.0, -55.0, 55.0, -85.0, 85.0,
	-120.0, 120.0, 180.0]
## At range, a skinned walker keeps describing a forward arc while it turns.
## A zero floor made every sharp path correction look like an AI stall.
const FAR_TURN_SPEED_SCALE := 0.18
## This was the encounter lifetime before the 3D roster was introduced. Keep
## the smoother long-range routing, but retire a pursuer after it has crossed
## enough real room boundaries while separated from the player. Without this,
## surviving walkers accumulated permanently at the three-enemy hard cap.
const CHASE_DOOR_LIMIT := 3
const NO_ROOM := Vector2i(2147483647, 2147483647)

## Per-variant behaviour: [creep m/s, unseen m/s, burn s,
## near-approach radius, chase doors].
## Inside that radius even unseen actors ease to creep, never stop. The lit
## torch ward and one-shot approach warning retain the player's response window.
const TUNING := {
	REVENANT: [1.25, 4.5, 1.5, 3.6, 3],
	DROWNED:  [1.25, 4.5, 1.5, 3.6, 3],
	PILGRIM:  [1.25, 4.5, 1.5, 3.6, 3],
	TRAILING: [1.25, 4.5, 1.5, 3.6, 3],
	# The gaoler keeps its original identity: slower, but willing to follow
	# through five doors before the player can finally shed it.
	GAOLER:   [0.90, 4.5, 1.5, 3.6, 5],
	REACHER:  [1.25, 4.5, 1.0, 2.4, 3],
	DRIFTER:  [1.60, 1.60, 1.5, 3.6, 3],
}
## Distance at which the unseen rush finishes easing to the normal creep.
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
## Once, immediately before this actor's first possible approach. A listener
## may synchronously hold it for a visual warning without disabling the torch.
signal approach_starting(figure: ShadowFigure)

## Descent may add a real doorway while this figure is alive. Sharing the
## floor resolver keeps its BFS and exact jamb waypoint on rendered geometry.
var topology: DescentTopology

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
	"wraith_anim": [0.615, 0.049, 1.000],
	"wraith2":     [0.535, 0.000, 1.000],
	"wraith3":     [0.642, 0.000, 1.000],
	"wraith4":     [0.441, 0.010, 1.000],
	"wraith5":     [0.625, 0.056, 1.000],
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
## Sheets drawn with a ground shadow under the figure, as the fraction of the
## frame it occupies measured up from the bottom. The apparitions do not cast
## one, so the shader discards everything below this line — and the feet entry
## in BODY above starts at the same place, so the body still lands on the floor
## rather than hovering the height of the discarded band.
const BASE_CUT := {
	"wraith_anim": 0.049,
	"wraith5": 0.056,
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
static var _layered_mats := {}
## Shared across every figure: a scare that fires twice in a minute is a
## sound effect, not a scare. Wall-clock so it survives level switches.
static var _last_scare := -1000.0
## The reveal cue keeps its own clock. It is allowed to fire much more often
## than a first-sighting stinger, because it is the payoff for a thing the
## player just did rather than an announcement they had no part in.
static var _last_reveal := -1000.0

var player: Player
var variant := REVENANT
## Explicit prototype flag only. The seven animated 2D apparitions remain the
## ordinary path and no asset or variant is replaced on disk.
var use_walker_prototype := false
## Selected by ShadowFigures from a shuffled roster before this node enters the
## tree. Kept separate from the gameplay archetype in `variant`: appearance and
## pursuit behavior are deliberately independent.
var walker_model_index := 0
## Campaign progression, separate from archetype eligibility and spawn pacing.
var completed_levels := 0
var ground_velocity := Vector3.ZERO
var _travel_speed := 0.0
var _blocked_time := 0.0
var _avoid_direction := Vector3.ZERO
var _avoid_left := 0.0
var _recovery_direction := Vector3.ZERO
var _recovery_left := 0.0
var grace := 0.9            # legacy reveal hold; moving walkers get contact safety only
var announce := false       # a soft footstep as it arrives

## The variant's row from TUNING, read once in _ready.
var _creep_spd := ADVANCE_SPD
var _unseen_spd := UNSEEN_SPD
var _burn_time := BURN_TIME
var _unseen_min := UNSEEN_MIN
var _chase_limit := CHASE_DOOR_LIMIT

var _quad: GhostVisual
var _walker: ShadowWalkerVisual
## Matter it sheds and darkness it gathers: true-3D wisp particles and a local
## fog volume surround the layered body. Both follow `fade`.
var _wisps: GPUParticles3D
var _gloom: FogVolume
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
## Eased beam-on-it strength, for the shader's relief. Not the burn charge.
var _torch := 0.0
## The light the kill throws on the room, driven per frame rather than tweened
## so it can flicker.
var _flash: OmniLight3D
## One-shot sibling, not a child: its bright tail must survive the actor being
## freed at the end of the burn animation.
var _burn_particles: ShadowBurnFragments
var _burn_disintegration_started := false
var _sway := 0.0
## Set by ShadowFigures while the rules have the player pinned. It still burns
## and still fades — it simply does not close the distance.
var suppressed := false
var _approach_announced := false
var _approach_hold := 0.0
var _was_sighted := true
var _reveal := 0.0
## Whether the player could actually see it last frame — in frustum AND not
## behind anything. The seeing is what governs how fast it closes: watched,
## it creeps; unseen, it lunges.
var _observed := false
var _lost_dist := INF
var _local_path := GhostLocalPath.new()
var _route_left := 0.0
var _route_from := NO_ROOM
var _route_goal := NO_ROOM
var _route_next := NO_ROOM
var _route_waypoint := Vector3.INF
var _chase_room := NO_ROOM
var _chase_doors := 0
var _giving_up := false
var _move_shape: CapsuleShape3D
var _move_query: PhysicsShapeQueryParameters3D


## Body transmission on the RECOVERED TAPE pass (1.0 is the clean tube's).
## 0.25: on the tape the body has to be a hole, because every lift the tape
## adds (grain, black floor, bloom, chroma smear) is a lift toward grey. A
## wider noise-veiled body floor was tried 2026-08-19 and made it worse — the
## veil IS grey; do not bring it back.
const TAPE_DENSITY := 0.25
static var _tape_look := false


## The recording mode changed: every cached body material follows. The tape
## pass greys the frame, so figures close down to keep their contrast.
static func set_tape_look(tape: bool) -> void:
	_tape_look = tape
	for m in _mats.values():
		_apply_look(m as ShaderMaterial, tape)


static func _apply_look(m: ShaderMaterial, tape: bool) -> void:
	m.set_shader_parameter("density", TAPE_DENSITY if tape else 1.0)


## The approved body uses consistent density in both recording modes. Keep its
## material separate from the screen-absorbing walk-by shadows in _mat_for().
static func make_visual(texname: String) -> GhostVisual:
	if _layered_mats.has(texname):
		var cached: ShaderMaterial = _layered_mats[texname]
		var layout: Array = FLIPBOOKS.get(texname, [1, 1, 1, 1.0])
		return GhostVisual.new(cached, int(layout[2]), float(layout[3]))
	var m := ShaderMaterial.new()
	m.shader = GhostVisual.SHADER
	var ext := "webp" if FLIPBOOKS.has(texname) else "png"
	m.set_shader_parameter("tex", load("res://textures/ghosts/%s.%s" % [texname, ext]))
	m.set_shader_parameter("noise_tex", Mats.detail_noise())
	var fb: Array = FLIPBOOKS.get(texname, [1, 1, 1, 1.0])
	m.set_shader_parameter("flip_cols", float(fb[0]))
	m.set_shader_parameter("flip_rows", float(fb[1]))
	m.set_shader_parameter("flip_count", float(fb[2]))
	m.set_shader_parameter("base_cut", float(BASE_CUT.get(texname, 0.0)))
	m.set_shader_parameter("keep_colour", 1.0 if COLOURED.has(texname) else 0.0)
	_layered_mats[texname] = m
	return GhostVisual.new(m, int(fb[2]), float(fb[3]))


static func _mat_for(texname: String) -> ShaderMaterial:
	if _mats.has(texname):
		return _mats[texname]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ghost.gdshader")
	_apply_look(m, _tape_look)
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
	if BASE_CUT.has(texname):
		m.set_shader_parameter("base_cut", float(BASE_CUT[texname]))
	if COLOURED.has(texname):
		m.set_shader_parameter("keep_colour", 1.0)
		m.set_shader_parameter("colour_gain", 1.0)
	_mats[texname] = m
	return m



func _ready() -> void:
	add_to_group(&"hostile_shadow_figure")
	var tune: Array = TUNING[variant]
	_creep_spd = float(tune[0])
	_unseen_spd = float(tune[1])
	_burn_time = float(tune[2])
	_unseen_min = float(tune[3])
	_chase_limit = int(tune[4])
	if use_walker_prototype:
		_create_walker_visual()
	else:
		_create_layered_visual()
	_build_presence()
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


func _create_layered_visual() -> void:
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
	_quad = make_visual(look[0])
	_quad.scale = Vector3(w, qh, 1.0)
	_quad.position = Vector3(0, qh * (0.5 - float(body[1]))
		+ (0.06 if _floats else 0.0), 0)
	# ShaderMaterial is cached per texture; per-instance uniforms keep mirrored
	# poses and dissolves independent when several use the same cutout.
	_set_visual_parameter("fade", 1.0)
	_set_visual_parameter("flip", 1.0 if look[3] else 0.0)
	_set_visual_parameter("dissolve_seed", randf())
	_set_visual_parameter("burn", 0.0)
	_set_visual_parameter("ignite", 0.0)
	_set_visual_parameter("sway", 0.0)
	# Two of them on screen must not be marching in lockstep.
	_set_visual_parameter("flip_phase", randf())
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
		_set_visual_parameter("flip_frame", _anim_frame)
		# Temporal smoothing and echo: the fractional frame the script already
		# feeds blends between poses (looping back through frame 0), and the
		# two previous poses linger as a faint analog smear. The observation
		# stalls in _animate freeze the fraction too, so a held pose stays
		# perfectly still.
		_set_visual_parameter("flip_blend", 1.0)
		_set_visual_parameter("flip_loop", 1.0)
		_set_visual_parameter("trail_amt", 0.55)


func _create_walker_visual() -> void:
	_walker = ShadowWalkerVisual.new()
	_walker.name = "ShadowWalkerPrototype"
	_walker.model_index = walker_model_index
	# The authored front is +Z. Face the target before becoming visible, rather
	# than spending the arrival standing still while making a half-turn.
	if is_instance_valid(player) and player.is_inside_tree():
		var direction := player.global_position - global_position
		_walker.rotation.y = atan2(direction.x, direction.z)
	add_child(_walker)
	_walker.manifestation_changed.connect(_on_walker_manifestation_changed)
	# This model has a grounded authored walk, so its feet stay on the real floor.
	_floats = false
	_eye_h = 1.66
	_set_visual_parameter(&"fade", 1.0)
	_set_visual_parameter(&"burn", 0.0)
	_set_visual_parameter(&"ignite", 0.0)
	_set_visual_parameter(&"fragmented", 0.0)
	_set_visual_parameter(&"torch", 0.0)


func _on_walker_manifestation_changed(value: float) -> void:
	if _wisps != null:
		_wisps.emitting = value > 0.05 and not _burn_disintegration_started
		_wisps.visible = value > 0.001 and not _burn_disintegration_started
		_wisps.transparency = 1.0 - value
	if _gloom != null and _gloom.material != null:
		(_gloom.material as FogMaterial).density = GLOOM_DENSITY * 0.28 * value


func _set_visual_parameter(parameter: StringName, value: Variant) -> void:
	if _quad != null:
		_quad.set_instance_shader_parameter(parameter, value)
	elif _walker != null:
		_walker.set_instance_shader_parameter(parameter, value)


## The figure's additional 3D presence: shed wisps and gathered darkness.
## These retain their existing world-space movement around the layered body.
static var _presence_cache := {}


## Immutable particle resources are shared; emitter/fog state stays per actor.
## Preparing the next encounter must not rebuild a turbulence shader and ramp.
static func prewarm_presence(prototype: bool) -> Dictionary:
	if _presence_cache.has(prototype):
		return _presence_cache[prototype]
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.42, 0.88, 0.24) if prototype \
		else Vector3(0.28, 0.95, 0.10)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.025 if prototype else 0.04
	pm.initial_velocity_max = 0.12 if prototype else 0.16
	pm.gravity = Vector3(0, 0.075 if prototype else 0.10, 0)
	pm.scale_min = 0.14 if prototype else 0.4
	pm.scale_max = 0.38 if prototype else 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.35, Color(1, 1, 1, 0.6))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var mote := QuadMesh.new()
	mote.size = Vector2(0.22, 0.22) if prototype else Vector2(0.46, 0.46)
	var mat := ShaderMaterial.new()
	mat.shader = WISP_SHADER
	mote.material = mat
	_presence_cache[prototype] = {"process": pm, "mesh": mote}
	return _presence_cache[prototype]


func _build_presence() -> void:
	_wisps = GPUParticles3D.new()
	var prototype := _walker != null
	var resources := prewarm_presence(prototype)
	_wisps.amount = 36 if prototype else 14
	_wisps.lifetime = 1.15 if prototype else 2.4
	# Grow the mist with the materialization. Preprocessing simulated nearly a
	# second of particles in one render frame at every spawn, causing a hitch.
	_wisps.preprocess = 0.0 if prototype else 1.4
	_wisps.local_coords = false
	_wisps.process_material = resources.process
	_wisps.draw_pass_1 = resources.mesh
	_wisps.position = Vector3(0, 0.96 if prototype else 1.05, 0)
	add_child(_wisps)

	_gloom = FogVolume.new()
	_gloom.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_gloom.size = Vector3(1.9, 2.8, 1.9)
	var fog := FogMaterial.new()
	fog.density = GLOOM_DENSITY * (0.28 if prototype else 1.0)
	fog.albedo = Color(0.04, 0.04, 0.05)
	_gloom.material = fog
	_gloom.position = Vector3(0, 1.25, 0)
	add_child(_gloom)
	if prototype:
		_on_walker_manifestation_changed(_walker._manifestation)


func _spawn_burn_particles() -> void:
	if _walker == null:
		return
	var reduced := GameSettings.current != null \
		and bool(GameSettings.current.values.get("reduced_flashing", false))
	# Area-weighted samples cover the complete currently posed GLB rather than
	# inheriting vertex clumps from whichever topology that model happened to use.
	# Thousands of sub-centimetre fragments, rather than a sparse shell of large
	# pieces, reproduce the final intact silhouette on the handoff frame.
	var samples := _walker.burn_surface_samples(1800 if reduced else 5200)
	var points: PackedVector3Array = samples.get("points", PackedVector3Array())
	if points.is_empty():
		return
	var peak := _walker.burn_peak()
	var fragments := ShadowBurnFragments.new()
	fragments.name = "WalkerBurnDisintegration"
	var host := get_parent()
	if host == null:
		return
	host.add_child(fragments)
	# Samples are in ShadowWalkerVisual local space, not ShadowFigure space.
	# Preserve the visual's exact current yaw/pose at the one-frame handoff;
	# dropping this basis made the fragment body appear to flip or mirror.
	fragments.global_transform = _walker.global_transform
	fragments.configure(samples, minf(1.45, peak) if reduced else peak)
	_burn_particles = fragments


## Drives the sprite sheet's frame instead of letting the shader run it on a
## fixed clock. Under the gaze it plays slow and stalls; unwatched it runs on.
func _animate(dt: float, observed: bool) -> void:
	if _walker != null:
		_walker.animate(dt, observed)
		return
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
	_set_visual_parameter("flip_frame", _anim_frame)


func _physics_process(dt: float) -> void:
	if player == null or not player.is_inside_tree():
		queue_free()
		return
	if _walker != null:
		_walker.begin_motion_frame()
	ground_velocity = Vector3.ZERO
	# Room crossings define the original encounter lifetime. Movement and path
	# finding remain fully active until a clean, separated-room retirement.
	_update_chase_lifetime()
	if grace > 0.0:
		grace -= dt
	# Pause/passive holds do not spend the warning's reaction window.
	var approach_was_held := _approach_hold > 0.0
	if approach_was_held and not suppressed:
		_approach_hold = maxf(0.0, _approach_hold - dt)
	if _floats:
		# it does not stand. it hangs.
		_bob_t += dt
		position.y = _bob_base + 0.03 + sin(_bob_t * 1.1) * 0.035
	var cam := player.cam
	var eye := global_position + Vector3(0, _eye_h, 0)
	var to := eye - cam.global_position
	var dist := to.length()
	var aim := _beam_aim(cam)
	var sighted := _clear_line(cam.global_position, eye)
	# Only the initial reveal has a reaction hold. Repeated furniture occlusion
	# must not keep resetting a stop timer during an otherwise continuous chase.
	if _walker == null and sighted and not _was_sighted and not _approach_announced:
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
	if _fade < 0.0 and not suppressed \
			and (_walker != null or (_reveal <= 0.0 and grace <= 0.0)):
		if not _approach_announced:
			_approach_announced = true
			approach_starting.emit(self)
		# Respect any explicit listener hold; walkers normally move through their
		# arrival warning. Never replay the announcement on later LOS changes.
		if not approach_was_held and _approach_hold <= 0.0:
			_advance(dt, observed)
	if ground_velocity.length_squared() < 0.000001:
		_travel_speed = 0.0
	_animate(dt, observed)
	_sway += dt
	_set_visual_parameter("sway",
		sin(_sway * 0.9 + _bob_t))
	# What the beam REVEALS, as distinct from what it burns. The two share a
	# gesture but not a timescale: the surface lights the instant the light
	# lands on it, while the heat needs a second and a half to build. Eased so
	# a wavering aim breathes across the folds instead of strobing them.
	var beam := _in_beam(cam, aim, sighted)
	var want := 0.0
	if beam and _fade < 0.0:
		want = clampf(1.0 - dist / maxf(player.flashlight.spot_range, 0.001),
			0.0, 1.0)
		want = 0.35 + 0.65 * want
	_torch = move_toward(_torch, want, dt * (6.0 if want > _torch else 3.0))
	_set_visual_parameter("torch", _torch)
	# The torch burns it away far faster than a stare, and keeps burning only
	# while the beam stays on it.
	if _fade < 0.0 and (grace <= 0.0 or _walker != null) and beam:
		_burn = minf(_burn_time, _burn + dt)
		if not _burning:
			_burning = true
		if _burn >= _burn_time:
			_ignite()
			return
	else:
		_burning = false
		_burn = maxf(0.0, _burn - dt * BURN_DRAIN)
	_set_visual_parameter("burn", _burn / _burn_time)
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
		var left := clampf(_fade / maxf(_fade_len, 0.001), 0.0, 1.0)
		_set_visual_parameter("fade", left)
		# The shed matter and the gathered dark go with the body.
		if _wisps != null:
			_wisps.emitting = left > 0.35
			if _walker != null:
				_wisps.visible = left > 0.02 and not _burn_disintegration_started
		if _gloom != null and _gloom.material != null:
			(_gloom.material as FogMaterial).density = GLOOM_DENSITY \
				* (0.28 if _walker != null else 1.0) * left
		if _flash != null:
			var t := 1.0 - left
			var flick := 0.78 + 0.22 * sin(t * 71.0) * sin(t * 23.0 + _bob_t)
			if _walker != null:
				# A fast, whole-body flare that remains bright long enough to read,
				# then falls with the creature instead of climbing through it.
				var env := smoothstep(0.0, 0.30, t) \
					* (1.0 - smoothstep(0.45, 1.0, t))
				_flash.light_energy = 0.45 * env * flick
				_flash.position.y = _eye_h * (0.35 + 0.60 * t)
			else:
				# Envelope follows the legacy front up the body; the flicker on top
				# separates a fire from a lamp on a dimmer.
				var env := smoothstep(0.0, 0.30, t) \
					* (1.0 - smoothstep(0.45, 1.0, t))
				_flash.light_energy = 6.4 * env * flick
				_flash.position.y = _eye_h * (0.35 + 0.60 * t)
		if _fade <= 0.0:
			queue_free()


## Restore the pre-3D encounter lifetime. A pursuer follows through its room
## budget, then dissolves only after it and the player are in different rooms.
## If the player re-enters its room during that dissolve, the chase resumes;
## this prevents a creature from vanishing alongside the player.
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
			_set_visual_parameter("fade", 1.0)
			if _wisps != null:
				_wisps.emitting = true
				_wisps.visible = true
			if _gloom != null and _gloom.material != null:
				(_gloom.material as FogMaterial).density = GLOOM_DENSITY \
					* (0.28 if _walker != null else 1.0)
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
## blocked, a bounded local path reserves the whole route around furniture.
func hold_approach(seconds: float) -> void:
	_approach_hold = maxf(_approach_hold, maxf(0.0, seconds))


func _advance(dt: float, observed := true) -> void:
	ground_velocity = Vector3.ZERO
	if _walker != null:
		_walker.begin_motion_frame()
	if _approach_hold > 0.0 or dt <= 0.0:
		return
	# Bound both steering and travel on a hitch, rather than bounding yaw alone
	# while letting the actor travel a full long frame in the wrong direction.
	var frame_dt := dt
	dt = minf(dt, 0.1)
	_recovery_left = maxf(0.0, _recovery_left - dt)
	var player_to := player.global_position - global_position
	player_to.y = 0.0
	var player_d := player_to.length()
	var speed := pursuit_speed(observed, player_d)
	var contact_clear := false
	if player_d <= ADVANCE_MIN + speed * dt:
		contact_clear = _clear_line(global_position + Vector3.UP,
			player.global_position + Vector3.UP)
	if player_d <= ADVANCE_MIN + 0.015 and contact_clear:
		# Arrival grace protects the player from invisible contact, not from a
		# visibly frozen monster. Walk and animate during the materialization.
		if _walker != null and (grace > 0.0 or _walker._manifestation < 0.95):
			_travel_speed = 0.0
			return
		# The lit torch is a ward. While the beam lives it comes to arm's
		# length and looms there; the kill waits for the dark — a dead cell,
		# or a hand that switches off too soon.
		if player.flashlight != null and player.flashlight.visible:
			_travel_speed = 0.0
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
	target.y = global_position.y
	var reach := ADVANCE_MIN if target.distance_to(player.global_position) < 0.1 else 0.0
	var reachable := func(point: Vector3) -> bool:
		return _clear_line(point + Vector3.UP, player.global_position + Vector3.UP)
	# A player in the water has no legal dry endpoint. Take the closest reachable
	# deck position instead, and resume pursuit when they climb out.
	# A complete path is preferable, but an incremental safe prefix is always
	# useful. Refusing partial progress made an exhausted furniture search return
	# the actor's own position and hold it there for seconds at a time.
	target = _local_path.waypoint(global_position, target, dt, _clear_travel,
		reach, reachable, true)
	var to := target - global_position
	to.y = 0.0
	var d := to.length()
	var route_waiting := d < 0.001
	var direct := to / d if not route_waiting else player_to.normalized()
	if direct.length_squared() < 0.0001:
		return
	if route_waiting:
		# The recovery direction owns this short leg; do not clamp its movement
		# back to the zero-length navigation result that triggered recovery.
		d = RECOVERY_PROBE
	direct = _avoid_peers(direct, speed, dt)
	# A missing room hop or an in-flight/failed local search may temporarily
	# yield no waypoint. Never turn that implementation detail into an idle
	# monster: take a physically clear wall-following step and keep replanning.
	if route_waiting or _blocked_time >= BLOCKED_REPLAN_SECONDS \
			or _recovery_left > 0.0:
		var recovery := _recovery_step_direction(direct)
		if recovery != Vector3.ZERO:
			direct = recovery
	if _walker != null:
		# Steer continuously toward the actual local-path step. Translation is
		# always along the body's authored +Z axis, so its route becomes a real
		# left/right arc rather than a sideways slide or stop-and-snap pivot.
		var alignment := _walker.face_world_direction(direct, dt)
		# A complete reversal still has to plant and turn; ordinary corners keep
		# moving, but slow down in proportion to their steering error so the turn
		# radius remains believable at both creep and unseen chase speeds.
		var curve_speed := smoothstep(0.0, 0.985, alignment)
		if player_d > ADVANCE_MIN + 1.0:
			curve_speed = maxf(curve_speed, FAR_TURN_SPEED_SCALE)
		speed *= curve_speed
		# Short approach to a waypoint needs a tighter turn radius. Without this
		# the walker can circle a path corner forever without reaching it.
		if alignment < 0.985:
			speed = minf(speed, d * ShadowWalkerVisual.TURN_SPEED * 0.65)
		var forward := _walker.forward_world()
		_travel_speed = move_toward(_travel_speed, speed,
			(ACCELERATION if speed > _travel_speed else BRAKING) * dt)
		direct = forward
	else:
		_travel_speed = speed
	var step := minf(_travel_speed * dt, d)
	if contact_clear:
		step = minf(step, maxf(0.0, player_d - ADVANCE_MIN))
	# Sweep the entire segment against geometry AND other bodies. If a turn is
	# temporarily blocked, brake and keep rotating along the real route.
	var destination := global_position + direct * step
	# Keep a little turning room in front of a curved walker. Driving exactly
	# onto the wall's contact skin can leave no numerically valid sideways arc
	# into an adjacent narrow doorway, even though the planned route is open.
	var probe := maxf(step, 0.18) if _walker != null else step
	if step > 0.00001 and _peer_clear(destination) and _can_move(direct, probe):
		# Report movement over the actual frame, not its clamped simulation step,
		# so a hitch cannot advance the clip farther than the body travelled.
		ground_velocity = (destination - global_position) / frame_dt
		global_position = destination
		_blocked_time = 0.0
		if _walker != null:
			_walker.set_ground_speed(ground_velocity.length())
	else:
		_travel_speed = 0.0
		var before := _blocked_time
		_blocked_time += dt
		# Keep the body visibly walking while it searches/turns. A stopped clip at
		# range reads as dead AI even when a route slice is still being computed.
		if _walker != null and player_d > ADVANCE_MIN + 0.25:
			_walker.set_ground_speed(maxf(_creep_spd * 0.52, speed * 0.35))
		if before < BLOCKED_REPLAN_SECONDS \
				and _blocked_time >= BLOCKED_REPLAN_SECONDS:
			_local_path.invalidate()
			_clear_route()
			_recovery_left = 0.0


func _recovery_step_direction(preferred: Vector3) -> Vector3:
	preferred.y = 0.0
	if preferred.length_squared() < 0.0001:
		preferred = Vector3.BACK
	preferred = preferred.normalized()
	if _recovery_left > 0.0 and _recovery_direction != Vector3.ZERO:
		var held_destination := global_position \
			+ _recovery_direction * RECOVERY_PROBE
		if _peer_clear(held_destination) \
				and _clear_travel(global_position, held_destination):
			return _recovery_direction
	var player_direction := player.global_position - global_position
	player_direction.y = 0.0
	if player_direction.length_squared() > 0.0001:
		player_direction = player_direction.normalized()
	else:
		player_direction = preferred
	var best := Vector3.ZERO
	var best_score := -INF
	for degrees: float in RECOVERY_ANGLES:
		var direction := preferred.rotated(Vector3.UP, deg_to_rad(degrees))
		var destination := global_position + direction * RECOVERY_PROBE
		if not _peer_clear(destination) \
				or not _clear_travel(global_position, destination):
			continue
		# Prefer real route/player progress, but permit a backwards leg when a U
		# or furniture pocket can only be escaped by first walking away.
		var score := direction.dot(preferred) * 1.4 \
			+ direction.dot(player_direction) * 0.8 \
			- absf(degrees) / 720.0
		if score > best_score:
			best_score = score
			best = direction
	if best != Vector3.ZERO:
		_recovery_direction = best
		_recovery_left = RECOVERY_HOLD_SECONDS
	return best


func pursuit_speed(observed: bool, distance: float) -> float:
	# The unseen rush eases to the normal approach speed, never a stationary
	# "park". Every completed campaign floor adds three percent to both speeds.
	var rush := 0.0 if observed else smoothstep(_unseen_min, _unseen_min + 2.0, distance)
	return lerpf(_creep_spd, _unseen_spd, rush) \
		* (1.0 + SPEED_PER_LEVEL * clampi(completed_levels, 0, DescentRun.FLOOR_COUNT - 1))


func _peers() -> Array[ShadowFigure]:
	var peers: Array[ShadowFigure] = []
	for node in get_tree().get_nodes_in_group(&"hostile_shadow_figure"):
		var other := node as ShadowFigure
		if other != null and other != self and not other.is_queued_for_deletion() \
				and not other.suppressed and other._fade < 0.0 \
				and not other._giving_up \
				and other.get_world_3d() == get_world_3d() \
				and absf(other.global_position.y - global_position.y) < MOVE_HEIGHT:
			peers.append(other)
	return peers


func _avoid_peers(desired: Vector3, speed: float, dt: float) -> Vector3:
	_avoid_left -= dt
	var peers := _peers()
	if peers.is_empty():
		return desired
	# Sample short swept velocity corridors before contact. Both actors prefer
	# their own right, so head-on encounters separate to opposite world sides.
	# A held direction penalizes left/right dithering as their positions change.
	var horizon := clampf(speed * 0.65, 1.8, 3.2)
	var best := desired
	var best_score := INF
	for degrees in [0.0, -20.0, 20.0, -40.0, 40.0, -65.0, 65.0, -90.0, 90.0,
			-120.0, 120.0, -150.0, 150.0, 180.0]:
		var direction := desired.rotated(Vector3.UP, deg_to_rad(degrees))
		var score := absf(degrees) / 90.0 + (0.07 if degrees > 0.0 else 0.0)
		if _avoid_left > 0.0:
			score += (1.0 - direction.dot(_avoid_direction)) * 0.8
		var near_peer := false
		for other in peers:
			var relative := other.global_position - global_position
			relative.y = 0.0
			if relative.length() > horizon + PEER_SEPARATION + 2.0:
				continue
			near_peer = true
			var travel := direction * horizon - other.ground_velocity * 0.65
			var t := clampf(relative.dot(travel) / maxf(travel.length_squared(), 0.001), 0.0, 1.0)
			var gap := (relative - travel * t).length()
			score += maxf(0.0, PEER_SEPARATION + 0.30 - gap) * 12.0
		if not near_peer:
			return desired
		if not _clear_travel(global_position, global_position + direction * horizon):
			continue
		if score < best_score:
			best_score = score
			best = direction
	if best.dot(desired) < 0.99:
		_avoid_direction = best
		_avoid_left = 0.5
	return best


func _peer_clear(destination: Vector3) -> bool:
	var travel := destination - global_position
	travel.y = 0.0
	for other in _peers():
		var relative := other.global_position - global_position
		relative.y = 0.0
		var t := clampf(relative.dot(travel) / maxf(travel.length_squared(), 0.000001), 0.0, 1.0)
		var closest := (relative - travel * t).length()
		# Recovery from an externally placed overlap must be allowed to increase
		# separation; the old endpoint-only test trapped both actors forever.
		var minimum := minf(PEER_SEPARATION, relative.length())
		if closest < minimum - 0.00001 \
				or (relative - travel).length() < minimum - 0.00001:
			return false
	return true


func _route_target(dt: float) -> Vector3:
	var start := _cell_for(global_position)
	var goal := _cell_for(player.global_position)
	# Finish clearing the jamb before turning within the destination cell.
	if start == _route_next and _route_waypoint != Vector3.INF \
			and global_position.distance_to(_route_waypoint) > 0.18:
		return _route_waypoint
	if start == goal:
		_clear_route()
		return player.global_position
	_route_left -= dt
	if _route_left <= 0.0 or start != _route_from or goal != _route_goal:
		_route_left = ROUTE_REPATH_TIME
		_route_from = start
		_route_goal = goal
		_route_next = _next_route_cell(start, goal)
		_route_waypoint = _doorway_waypoint(start, _route_next) \
			if _route_next != start else Vector3.INF
	# Falling back to our own position was a permanent hard-freeze path: local
	# navigation quite reasonably considered that target complete. Let the
	# collision-aware partial router advance toward the player while the room
	# graph retries on its normal clock.
	return _route_waypoint if _route_waypoint != Vector3.INF \
		else player.global_position


func _clear_route() -> void:
	_route_left = 0.0
	_route_from = NO_ROOM
	_route_goal = NO_ROOM
	_route_next = NO_ROOM
	_route_waypoint = Vector3.INF


func _next_route_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	# Goal-directed search, not a fixed distance cutoff. A bounded search that
	# has not reached a very distant goal still returns its best frontier hop.
	var frontier: Array[Dictionary] = []
	GhostLocalPath._push(frontier, {"at": start, "score": _route_distance(start, goal)})
	var parent := {start: start}
	var costs := {start: 0.0}
	var closed := {}
	var cell := start
	while not frontier.is_empty() and closed.size() < ROUTE_MAX_EXPANSIONS:
		cell = GhostLocalPath._pop(frontier).at
		if closed.has(cell):
			continue
		if cell == goal:
			break
		closed[cell] = true
		for dir in 4:
			if _edge_info(cell, dir)["wall"]:
				continue
			var neighbor: Vector2i = cell + WorldGen.DIRV[dir]
			var cost := float(costs[cell]) + 1.0
			if closed.has(neighbor) or cost >= float(costs.get(neighbor, INF)):
				continue
			parent[neighbor] = cell
			costs[neighbor] = cost
			GhostLocalPath._push(frontier, {"at": neighbor,
				"score": cost + _route_distance(neighbor, goal)})
	if cell != goal:
		if frontier.is_empty():
			return start
		cell = frontier[0].at
	if cell == start:
		return start
	var at := cell
	while parent[at] != start:
		at = parent[at]
	return at


static func _route_distance(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y))


func streaming_cells() -> Array[Vector2i]:
	# Local routing is explicitly allowed to skirt one cell around the actor.
	# Keep that whole search footprint resident; forcing only the current and
	# next cells left far-away enemies with no floor/collision data for a valid
	# side detour, so every support ray rejected it and the enemy froze.
	var centre := _cell_for(global_position)
	var cells: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			cells.append(centre + Vector2i(x, y))
	if _route_next != NO_ROOM:
		if not cells.has(_route_next):
			cells.append(_route_next)
	return cells


func _doorway_waypoint(from: Vector2i, to: Vector2i) -> Vector3:
	var dir := WorldGen.DIRV.find(to - from)
	if dir < 0:
		return global_position
	var edge: Dictionary = _edge_info(from, dir)
	var along := float(edge["t"])
	var waypoint := _edge_waypoint(from, dir, along)
	if player.level_theme == 9:
		# A connected basin can occupy the middle of a full-width opening. Aim
		# through a dry section of that same opening, not through its water lane.
		var cross := Vector3(WorldGen.DIRV[dir].x, 0, WorldGen.DIRV[dir].y) \
			* DOORWAY_CROSS_INSET * 2.0
		if _clear_travel(waypoint - cross, waypoint):
			return waypoint
		var half_width := Chunk.S * 0.5 if bool(edge.get("full_open", false)) \
			else float(edge.get("w", 0.0)) * 0.5
		var low := maxf(MOVE_RADIUS, along - half_width + MOVE_RADIUS)
		var high := minf(Chunk.S - MOVE_RADIUS, along + half_width - MOVE_RADIUS)
		for step in range(1, ceili(Chunk.S / GhostLocalPath.GRID) + 1):
			for sign_dir: float in [-1.0, 1.0]:
				var candidate := along + step * GhostLocalPath.GRID * sign_dir
				if candidate < low or candidate > high:
					continue
				var dry_waypoint := _edge_waypoint(from, dir, candidate)
				if _clear_travel(dry_waypoint - cross, dry_waypoint):
					return dry_waypoint
	return waypoint


func _edge_waypoint(from: Vector2i, dir: int, along: float) -> Vector3:
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
	return _clear_travel(global_position, global_position + dirv * step)


static func pool_deck_clear(p: Player, at: Vector3, radius: float) -> bool:
	if p.level_theme != 9:
		return true
	if absf(at.y - Chunk.POOL_DRY_Y) > 0.12:
		return false
	var space := p.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	for offset: Vector2 in POOL_SUPPORT_OFFSETS:
		var point := Vector3(at.x + offset.x * radius, Chunk.POOL_DRY_Y,
			at.z + offset.y * radius)
		query.from = point + Vector3.UP * 0.08
		query.to = point - Vector3.UP * 0.08
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.9:
			return false
	return true


func _clear_travel(from: Vector3, to: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	_move_query.transform = Transform3D(Basis.IDENTITY,
		to + Vector3(0, MOVE_HEIGHT * 0.5 + 0.04, 0))
	_move_query.motion = Vector3.ZERO
	if not space.intersect_shape(_move_query, 1).is_empty():
		return false
	_move_query.transform.origin = from + Vector3(0, MOVE_HEIGHT * 0.5 + 0.04, 0)
	_move_query.motion = to - from
	if space.cast_motion(_move_query)[0] < 1.0:
		return false
	# Sample support along the segment too: a clear capsule above a hole is
	# not a walkable detour, and smoothing must not jump over that hole.
	var samples := maxi(1, ceili(from.distance_to(to) / GhostLocalPath.GRID))
	for index in range(1, samples + 1):
		var foot := from.lerp(to, float(index) / samples)
		if player.level_theme == 9:
			if not pool_deck_clear(player, foot, MOVE_RADIUS):
				return false
			continue
		var query := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.2,
			foot - Vector3.UP * 0.6, 1, [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.72:
			return false
	return true


static func room_for(p: Player, at: Vector3) -> Vector2i:
	var cell := _cell_for(at)
	return WorldGen.annex_room_id(p.world_seed, cell) \
		if p.level_theme == 2 else WorldGen.room_id(p.world_seed, cell)


## Angle from the camera's forward axis to the nearest part of the FIGURE,
## not to its fixed eye point. At arm's length the body fills a third of the
## frame: aiming square at the chest put the eye point ~25 degrees off axis,
## outside BURN_CONE, so the beam neither lit nor burned a looming figure
## (reported 2026-08-20). Sample the body axis at three heights, take the
## best, and credit the silhouette's own angular half-width — capped so
## "aiming should mean aiming" still holds at range.
func _beam_aim(cam: Camera3D) -> float:
	var fwd := -cam.global_transform.basis.z
	var best := TAU
	for h in [0.2, _eye_h * 0.55, _eye_h]:
		var to := global_position + Vector3(0, float(h), 0) \
			- cam.global_position
		if to.length_squared() < 1e-6:
			return 0.0
		best = minf(best, fwd.angle_to(to.normalized()))
	var dist := maxf(
		global_position.distance_to(cam.global_position), 0.001)
	# The card is about 0.9m wide.
	best -= minf(atan(0.45 / dist), 0.6)
	return maxf(best, 0.0)


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
func _ignite(refund_torch := true, play_sound := true) -> void:
	_fade = BURN_FADE
	_fade_len = BURN_FADE
	_burning = false
	# Latch the terminal ignition. `burn` is released so the charge glow stops
	# fighting it; from here the exit is driven by the one-way fade.
	_set_visual_parameter("burn", 0.0)
	_set_visual_parameter("ignite", 1.0)
	_set_visual_parameter("fragmented", 0.0)
	if _walker != null:
		# Dark ambient wisps would muddy the white-hot breakup. The dedicated
		# particle sibling now owns the visible matter leaving the silhouette.
		if _wisps != null:
			_wisps.emitting = false
			_wisps.visible = false
		_burn_disintegration_started = true
		# The complete posed fragment body replaces the black mesh on this exact
		# frame. There is no intact flare or spotted erosion phase underneath it.
		_spawn_burn_particles()
		_set_visual_parameter("fragmented", 1.0)
	if refund_torch:
		burned_away.emit()
	# The room should be lit by the thing burning, which means the light has to
	# follow the front rather than announce the kill: it comes up as the flame
	# crosses the body and falls away with it. A cold flash at full energy on
	# frame one lit the walls blue while the figure itself was going orange.
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.70, 0.38)
	_flash.light_energy = 0.0
	_flash.omni_range = 2.5 if _walker != null else 8.0
	_flash.shadow_enabled = false
	_flash.set_meta("visible_source",
		"walker_burning_body_and_particles" if _walker != null else "burning_apparition")
	# The walker ignites as one body; legacy apparitions retain their travelling
	# burn-front light position.
	_flash.position = Vector3(0, _eye_h * (0.55 if _walker != null else 0.35), 0)
	add_child(_flash)
	# Its own recording rather than a jump-scare pitched up: a stinger is the
	# sound of something arriving, and this is the sound of something ending.
	if play_sound:
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
	# Consume the save here: only this exact catching figure is destroyed.
	if is_instance_valid(player) and player.try_emergency_flash():
		_ignite(false)
		return
	_fade = 0.45
	_fade_len = 0.45
	# The sound of this belongs to the player, not to the room, so the owner
	# plays it non-positionally. Descent and the temporary realm take over this
	# exact figure for their caught sequence; the owning mode decides whether
	# that sequence ends the run or only the one-shot excursion.
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
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	# Figures have no physics body to ignore at the endpoint. The former 1.2m
	# tolerance explicitly treated a thin wall near the target as transparent.
	return hit.is_empty()
