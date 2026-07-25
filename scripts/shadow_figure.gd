class_name ShadowFigure
extends Node3D
## One of them. A real human silhouette (CC0/CC-BY photo-traced cutouts in
## textures/ghosts/) on a cylindrical billboard, edges eaten by drifting
## noise. It watches for your attention: look straight at it — after a
## moment's grace, long enough to be sure you saw something — and it stops
## existing. Walk at it and it is gone sooner. It never closes the distance.

const GAZE_ANG := 0.22      # radians off screen-centre that counts as looking
## Looking at one used to banish it in half a second, which would make the
## flashlight pointless. A stare now HOLDS it — it cannot move while you are
## looking — and wears it down slowly. The torch is the fast way.
const GAZE_TIME := 3.0
const NEAR_D := 5.0         # only applies to the ones that do not advance
const FADE_T := 0.95

## It closes the distance unless you are looking straight at it. Freezing it on
## the whole camera frustum was far too generous: that is a seventy degree cone,
## and a figure you have noticed is a figure you keep on screen, so nothing ever
## moved. Holding it now costs you your centre of vision — anything you have
## merely clocked in the corner of your eye is still coming.
const ADVANCE_SPD := 1.25
const ADVANCE_MIN := 1.05   # it has you at arm's length
## Half-angle that counts as looking straight at it. Wider than the stare that
## wears it down, so holding one still is easier than banishing it.
const HOLD_CONE := 0.42

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

signal stared_away
signal burned_away
signal reached_player
## Fired the first frame this figure is genuinely on screen, alongside its
## stinger — the moment the player registers that something is there.
signal seen_by_player

enum Mode { AMBIENT, INERT, PURSUER }
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
}
# Every sheet carries its own soft smoke edge, so the shader must not carve a
# new one on top.
const SOFT := ["wraith_anim", "wraith2", "wraith3", "wraith4", "wraith5",
	"wraith6", "wraith7"]

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
}
## Cutouts whose own colour is worth keeping. All seven have lit eyes — one
## pair is green rather than red — and those are the only pixels allowed to
## survive the black-absence treatment.
const COLOURED := ["wraith_anim", "wraith2", "wraith3", "wraith4", "wraith5",
	"wraith6", "wraith7"]

static var _mats := {}
## Shared across every figure: a scare that fires twice in a minute is a
## sound effect, not a scare. Wall-clock so it survives level switches.
static var _last_scare := -1000.0

var player: Player
var variant := REVENANT
var mode := Mode.AMBIENT
var grace := 0.9            # can't be stared away until this runs out
var announce := false       # a soft footstep as it arrives

var _quad: MeshInstance3D
var _gaze := 0.0
var _life := 0.0
var _fade := -1.0
var _fade_len := FADE_T
var _drift := Vector3.ZERO
var _bob_t := 0.0
var _bob_base := 0.0
var _floats := false
var _eye_h := 1.4
var _seen := false
var _shiver: AudioStreamPlayer3D
var _burn := 0.0
var _burning := false
var _held := false          # frozen because you are looking at it
var _sway := 0.0


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
	_bob_base = position.y
	_bob_t = randf() * TAU
	_life = randf_range(10.0, 19.0)
	# Almost all of them stalk. A leaver now and then keeps the behaviour from
	# being one rule you can read off a single encounter, but at eight percent
	# they were common enough to be the first thing a player saw.
	if mode == Mode.AMBIENT and randf() < (0.07 if _floats else 0.03):
		# Some are already leaving — but only ever straight away from you,
		# never across you. The billboard turns to face the camera whatever it
		# does, so sideways travel is a cutout sliding on rails with its legs
		# held still; going away is just distance opening up. Fixed at the
		# moment it appears, so it walks a line rather than tracking you.
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() > 0.01:
			_drift = away.normalized() * randf_range(0.2, 0.35)
	_shiver = AudioStreamPlayer3D.new()
	_shiver.stream = SoundBank.shiver()
	_shiver.max_distance = 24.0
	_shiver.unit_size = 6.0
	_shiver.volume_db = -14.0
	_shiver.bus = "Hall"
	add_child(_shiver)
	if announce:
		var sh := AudioStreamPlayer3D.new()
		sh.stream = SoundBank.randomized(SoundBank.step_carpet(), 1.2, 2.0)
		sh.pitch_scale = 0.68
		sh.max_distance = 22.0
		sh.unit_size = 6.0
		sh.volume_db = -14.0
		sh.bus = "Hall"
		add_child(sh)
		sh.play()


func _physics_process(dt: float) -> void:
	if mode == Mode.INERT:
		return
	if player == null or not player.is_inside_tree():
		queue_free()
		return
	_life -= dt
	if grace > 0.0:
		grace -= dt
	if _drift != Vector3.ZERO:
		position += _drift * dt
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
	var stared := grace <= 0.0 and aim < GAZE_ANG and sighted
	# It only ever moves while you cannot see it. In frame, it is a photograph.
	# The few that are already walking away are leavers and never turn back:
	# one thing cannot be both retreating and stalking.
	_held = aim < HOLD_CONE and sighted
	if _fade < 0.0 and not _held and grace <= 0.0 and _drift == Vector3.ZERO:
		_advance(dt)
	_sway += dt
	_quad.set_instance_shader_parameter("sway",
		sin(_sway * 0.9 + _bob_t) * (0.0 if _held else 1.0))
	# The torch burns it away far faster than a stare, and keeps burning only
	# while the beam stays on it.
	if _fade < 0.0 and grace <= 0.0 and _in_beam(cam, aim, sighted):
		_burn = minf(BURN_TIME, _burn + dt)
		if not _burning:
			_burning = true
		if _burn >= BURN_TIME:
			_ignite()
			return
	else:
		_burning = false
		_burn = maxf(0.0, _burn - dt * BURN_DRAIN)
	_quad.set_instance_shader_parameter("burn", _burn / BURN_TIME)
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
		if visible and (_clear_line(cam.global_position, eye)
				or _clear_line(cam.global_position, base + Vector3(0, _eye_h * 0.55, 0))):
			_seen = true
			_maybe_scare()
	if stared:
		_gaze += dt
	# NEAR_D used to delete anything that got within five metres, which would
	# stop an advancing figure dead before it could ever reach you. It now only
	# applies to the ones standing still.
	var too_close := dist < NEAR_D and _drift != Vector3.ZERO
	if _fade < 0.0 and (_gaze > GAZE_TIME or too_close or _life <= 0.0):
		_fade = FADE_T
		_fade_len = FADE_T
		if _gaze > GAZE_TIME:
			stared_away.emit()
		if _gaze > GAZE_TIME or too_close:
			_shiver.play()  # it noticed you noticing
	if _fade >= 0.0:
		_fade -= dt
		# Normalise against the length this particular exit started with: a burn
		# runs longer than a stare-out and a seize is shorter, and dividing all
		# three by FADE_T would make two of them jump.
		_quad.set_instance_shader_parameter("fade",
			clampf(_fade / maxf(_fade_len, 0.001), 0.0, 1.0))
		if _fade <= 0.0:
			queue_free()


## One step closer, but never through a wall and never past arm's length. The
## billboard always faces the camera, so travel toward you is the only motion
## that does not read as a cutout sliding on rails.
##
## It walks through whatever is in the way. Testing the path against geometry
## was tried and abandoned: rooms are full of furniture and split by partitions,
## so a figure stopped the first time its line clipped a table or a sofa back
## and then stood there until it faded — which is indistinguishable from one
## that never moved. Widening the search to seven angles did not help, because
## a partition spans the whole room and blocks all of them.
##
## Passing through is also the truer answer. It is an apparition, it is only
## ever seen in glimpses, and a shape that comes through the furniture is worse
## than one politely walking around it. The path converges on the player, who is
## always standing in navigable space, so it arrives in the open.
func _advance(dt: float) -> void:
	var to := player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.001:
		return
	var step := ADVANCE_SPD * dt
	if d - step <= ADVANCE_MIN:
		_seize()
		return
	# Horizontal only — `to.y` was zeroed above, so the height it hangs at is
	# already correct and must not be written back. Copying `position.y` into
	# `_bob_base` here made the floating variants levitate: the hover offset is
	# applied from `_bob_base` every frame, so feeding the result back in added
	# it again on the next one, and they rose at nearly two metres a second.
	position += (to / d) * step


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
	pl.bus = "Hall"
	var host := get_parent()
	if host != null:
		host.add_child(pl)
		pl.global_position = global_position + Vector3(0, _eye_h, 0)
		pl.finished.connect(pl.queue_free)
		pl.play()


## It got to you. In the endless floors this is a scare and nothing more; the
## owner decides whether a Descent run survives it.
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
	pl.bus = "Hall"
	# hung on the parent, not on us: this figure stops existing in FADE_T
	# seconds and would take the sound with it half a second in
	var host := get_parent()
	if host == null:
		return
	host.add_child(pl)
	pl.global_position = global_position + Vector3(0, 1.4, 0)
	pl.finished.connect(pl.queue_free)
	pl.play()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit["position"].distance_to(b) < 1.2
