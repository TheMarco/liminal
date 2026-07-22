class_name ShadowFigure
extends Node3D
## One of them. A real human silhouette (CC0/CC-BY photo-traced cutouts in
## textures/ghosts/) on a cylindrical billboard, edges eaten by drifting
## noise. It watches for your attention: look straight at it — after a
## moment's grace, long enough to be sure you saw something — and it stops
## existing. Walk at it and it is gone sooner. It never closes the distance.

const GAZE_ANG := 0.22      # radians off screen-centre that counts as looking
const GAZE_TIME := 0.5      # how long a direct look survives
const NEAR_D := 5.0         # closer than this and it refuses to exist
const FADE_T := 0.4
# Not an angle any more: a cone guessed at the frustum and got it wrong at
# the frame edges, so a figure could appear plainly on screen and stay
# silent. Camera3D.is_position_in_frustum is the real test.
const SCARE_GAP := 6.0      # only stops two figures stacking stingers

enum { GAUNT, WRAITH, TALL, CRAWLER, CHILD, WATCHER,
	COAT, GOWN, HUSK, KNIFE, AXEMAN, HORNED, SMOKE }

# variant -> [texture file, height m, width factor, flip, floats]
const LOOKS := {
	GAUNT:   ["man_bald", 1.86, 1.0, false, false],
	WRAITH:  ["woman_walk", 1.78, 1.0, false, true],
	TALL:    ["man_bald", 2.35, 0.72, true, false],
	CRAWLER: ["man_shirt", 1.86, 1.0, false, false],
	CHILD:   ["girl", 1.24, 1.0, false, false],
	WATCHER: ["woman_walk", 1.7, 1.05, true, true],
	COAT:    ["coat", 1.90, 1.0, false, false],
	GOWN:    ["gown", 1.86, 1.0, true, true],
	HUSK:    ["husk", 1.94, 1.0, false, false],
	KNIFE:   ["knife", 1.88, 1.0, false, false],
	AXEMAN:  ["axeman", 1.92, 1.0, true, false],
	HORNED:  ["horned", 2.38, 1.0, false, false],
	SMOKE:   ["smoke", 2.30, 1.0, true, true],
}
# texture -> [aspect (w/h of the file), feet, head]
# feet/head are where the body actually starts and stops inside the file, as a
# fraction of file height measured up from the bottom. The traced cutouts fill
# their file, but the painted ones carry smoke and haze past the body at both
# ends — sizing a quad to the file stands the husk 1.69m tall with its feet
# floating 16cm off the floor. Numbers from `mask_silhouette.py --measure`.
const BODY := {
	"man_bald":   [0.311, 0.006, 0.994],
	"man_shirt":  [0.289, 0.002, 0.998],
	"woman_walk": [0.279, 0.006, 0.994],
	"girl":       [0.418, 0.004, 0.996],
	"coat":       [0.322, 0.021, 0.980],
	"gown":       [0.277, 0.029, 0.982],
	"husk":       [0.484, 0.086, 0.984],
	"knife":      [0.371, 0.033, 0.986],
	"axeman":     [0.469, 0.057, 0.984],
	"horned":     [0.441, 0.023, 0.973],
	"smoke":      [0.432, 0.033, 0.973],
}
# Painted cutouts, masked off white by tools/mask_silhouette.py. They keep
# their own soft edges, so the shader must not carve a new one.
const SOFT := ["coat", "gown", "husk", "knife", "axeman", "horned", "smoke"]

static var _mats := {}
## Shared across every figure: a scare that fires twice in a minute is a
## sound effect, not a scare. Wall-clock so it survives level switches.
static var _last_scare := -1000.0

var player: Player
var variant := GAUNT
var grace := 0.9            # can't be stared away until this runs out
var announce := false       # a soft footstep as it arrives

var _quad: MeshInstance3D
var _gaze := 0.0
var _life := 0.0
var _fade := -1.0
var _drift := Vector3.ZERO
var _bob_t := 0.0
var _bob_base := 0.0
var _floats := false
var _eye_h := 1.4
var _seen := false
var _shiver: AudioStreamPlayer3D


static func _mat_for(texname: String) -> ShaderMaterial:
	if _mats.has(texname):
		return _mats[texname]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ghost.gdshader")
	m.set_shader_parameter("tex", load("res://textures/ghosts/%s.png" % texname))
	m.set_shader_parameter("noise_tex", Mats.detail_noise())
	if SOFT.has(texname):
		m.set_shader_parameter("erode_amt", 0.14)
		m.set_shader_parameter("edge0", 0.1)
		m.set_shader_parameter("edge1", 1.1)
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
	add_child(_quad)
	_bob_base = position.y
	_bob_t = randf() * TAU
	_life = randf_range(10.0, 19.0)
	if randf() < (0.45 if _floats else 0.22):
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
	var stared := grace <= 0.0 and fwd.angle_to(to.normalized()) < GAZE_ANG \
		and _clear_line(cam.global_position, eye)
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
	if _fade < 0.0 and (_gaze > GAZE_TIME or dist < NEAR_D or _life <= 0.0):
		_fade = FADE_T
		if _gaze > GAZE_TIME or dist < NEAR_D:
			_shiver.play()  # it noticed you noticing
	if _fade >= 0.0:
		_fade -= dt
		_quad.set_instance_shader_parameter("fade", clampf(_fade / FADE_T, 0.0, 1.0))
		if _fade <= 0.0:
			queue_free()


## Fired the first frame this figure is actually on screen. No dice roll:
## seeing one and hearing nothing is the thing that reads as broken, so every
## figure you lay eyes on gets its stinger. The only gate is a few seconds so
## two arriving together do not stack.
func _maybe_scare() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _last_scare < SCARE_GAP:
		return
	_last_scare = now
	var sc := Sfx.scare(randi() % 7)
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
