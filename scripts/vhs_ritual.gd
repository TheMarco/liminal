class_name VhsRitual
extends Node3D
## A wooden table carrying a CRT television and a VCR with a tape already
## inserted. The objective instance gates the lift; rare optional instances use
## the same playback ritual without changing floor progress.
##
## Playing the tape is a commitment: the camera dollies in until the tube
## fills the view, the player is held for the running time, and the rules go
## passive for exactly that long. Backing out early (E or Esc) rewinds it.
## Assignment and finished state leave this node via the `descent_listener`
## group, so optional and objective sets survive chunk streaming.

const TABLE_PATH := "res://models/cc_by/tv_table/tv_table.glb"
const TV_PATH := "res://models/cc_by/retro_television/retro_television.glb"
const VCR_PATH := "res://models/cc_by/old_school_vcr/old_school_vcr.glb"
const TABLE_SCALE := 0.8
const TV_SCALE := 0.105
const VCR_SCALE := 0.01
## Fallback running time for a tape with no footage file.
const TAPE_SECONDS := 24.0
const OPTIONAL_HISS_DB := -21.0
const OPTIONAL_HISS_RANGE := 18.0
const OPTIONAL_CUE_RANGE := 8.5
var world_seed := 1
var floor_idx := 0
var home_cell := Vector2i.ZERO
var setup_key := ""
var objective := true
## Mirrored from run state at build time so a rebuilt room remembers.
var already_watched := false

var _screen: MeshInstance3D
var _screen_mat: ShaderMaterial
var _hit: Interactable
var _voice: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _video: VideoStreamPlayer
var _video_vp: SubViewport
var _cam: Camera3D
var _prev_cam: Camera3D
var _viewer: Player
var _discovery_light: OmniLight3D
var _tape_path := ""
var _playing := false
var _watching := false
var _tape_time := 0.0
var _done := false

static var _scenes := {}


## Audit/test teardown for the shared imported-prop cache.
static func clear_runtime_cache() -> void:
	_scenes.clear()


func _ready() -> void:
	if setup_key.is_empty():
		setup_key = "floor:%d:%s" % [floor_idx,
			"objective" if objective else "cell:%d:%d" % [home_cell.x, home_cell.y]]
	if objective:
		set_meta("descent_ritual", true)
	else:
		set_meta("optional_vhs", true)
		set_meta("optional_vhs_key", setup_key)
	_done = already_watched
	if not objective:
		var listener := _listener()
		if listener != null and listener.has_method("descent_setup_tape_completed"):
			_done = bool(listener.call("descent_setup_tape_completed", setup_key))
	_build_furniture()
	_build_screen()
	_build_audio()
	_build_discovery_cue()
	_build_interactable()
	set_process_unhandled_input(false)
	_present_idle()


func _model(path: String, scl: float, pos: Vector3, yaw := 0.0) -> Node3D:
	var ps: PackedScene = _scenes.get(path)
	if ps == null:
		ps = load(path)
		_scenes[path] = ps
	var inst := ps.instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * scl
	inst.set_meta("attributed_asset", path)
	add_child(inst)
	return inst


func _build_furniture() -> void:
	# Feet rest below each model's origin; lift so the lowest point sits on
	# the floor. Numbers come from the imported AABBs.
	_model(TABLE_PATH, TABLE_SCALE, Vector3(0.0, 0.1131, 0.0))
	_model(TV_PATH, TV_SCALE, Vector3(-0.35, 0.401, 0.02))
	_model(VCR_PATH, VCR_SCALE, Vector3(0.55, 0.401, -0.029))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.78, 1.02, 0.5)
	cs.shape = box
	cs.position = Vector3(0.0, 0.51, 0.0)
	body.add_child(cs)
	add_child(body)


## The tube rectangle, measured from the model's own screen sub-mesh
## (Object_2: 5.529x3.866 raw, centre (-0.615, 2.469)). The z is NOT the
## panel's: the body mesh carries a translucent curved glass dome whose apex
## reaches raw z 2.59 and renders in the transparent pass, so the quad must
## sit proud of THAT apex or the dome draws its faceted ghost over the
## footage at off-axis angles.
func _build_screen() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.578, 0.404)
	_screen = MeshInstance3D.new()
	_screen.mesh = quad
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = load("res://shaders/vhs_tape.gdshader")
	_screen_mat.set_shader_parameter("variant",
		float(posmod(WorldGen.h(world_seed, floor_idx, 7, 9301), 8)))
	_screen.material_override = _screen_mat
	_screen.position = Vector3(-0.4146, 0.6603, 0.296)
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_screen)


func _build_audio() -> void:
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = SoundBank.buzz()
	_hiss.unit_size = 4.0 if not objective else 2.2
	_hiss.max_distance = OPTIONAL_HISS_RANGE if not objective else 10.0
	_hiss.volume_db = OPTIONAL_HISS_DB if not objective else -34.0
	_hiss.bus = SoundBank.HALL_BUS
	_hiss.position = Vector3(-0.35, 0.68, 0.25)
	_hiss.autoplay = true
	add_child(_hiss)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 2.6
	_voice.bus = SoundBank.HALL_BUS
	_voice.position = Vector3(-0.35, 0.68, 0.25)
	_voice.finished.connect(_next_voice)
	add_child(_voice)


## Optional recordings must read as intentional discoveries while the player
## is still moving through the route. The CRT already shows snow; this cold,
## shadowless wall wash and its stronger localized hiss make the set legible
## from the doorway without adding a HUD marker or an expensive shadow pass.
func _build_discovery_cue() -> void:
	if objective:
		return
	_discovery_light = OmniLight3D.new()
	_discovery_light.name = "RecoveredTapeCue"
	_discovery_light.position = Vector3(-0.35, 1.05, 0.45)
	_discovery_light.light_color = Color(0.56, 0.72, 0.92)
	_discovery_light.light_energy = 1.15
	_discovery_light.omni_range = OPTIONAL_CUE_RANGE
	_discovery_light.shadow_enabled = false
	_discovery_light.light_volumetric_fog_energy = 0.0
	_discovery_light.distance_fade_enabled = true
	_discovery_light.distance_fade_begin = 10.0
	_discovery_light.distance_fade_length = 5.0
	add_child(_discovery_light)


## The video decodes into an off-screen viewport whose texture the tube
## shader samples, so the footage sits behind the same curvature, grain and
## scanlines as everything else the television shows. Built on first play.
func _ensure_video() -> bool:
	if _tape_path.is_empty():
		return false
	if _video != null:
		return true
	var stream := load(_tape_path) as VideoStream
	if stream == null:
		return false
	_video_vp = SubViewport.new()
	_video_vp.size = Vector2i(512, 384)
	_video_vp.disable_3d = true
	_video_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_video_vp)
	_video = VideoStreamPlayer.new()
	_video.stream = stream
	_video.expand = true
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Straight to the master bus: the hall reverb send swallowed the voice,
	# and while the camera holds the tube the tape IS the scene's audio.
	_video.volume_db = 2.0
	_video.finished.connect(_on_video_finished)
	_video_vp.add_child(_video)
	_screen_mat.set_shader_parameter("tape_tex", _video_vp.get_texture())
	return true


func _build_interactable() -> void:
	# The whole altar is the target: aiming anywhere at the set from within
	# interaction range reads as "the tape", not just the VCR's own footprint.
	_hit = Interactable.new()
	_hit.name = "DescentTapePlay"
	_hit.position = Vector3(0.0, 0.9, 0.18)
	_hit.add_box(Vector3(1.9, 1.8, 0.95))
	add_child(_hit)
	_hit.activated.connect(_on_activated)


func _on_activated(actor: Node) -> void:
	if _done or _playing:
		return
	_claim_tape()
	_playing = true
	_tape_time = 0.0
	_hit.prompt_text = ""
	_hit.enabled = false
	_screen_mat.set_shader_parameter("playing", 1.0)
	_hiss.volume_db = -40.0
	if _ensure_video():
		_screen_mat.set_shader_parameter("use_footage", 1.0)
		_video_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_video.play()
	else:
		_screen_mat.set_shader_parameter("use_footage", 0.0)
		_next_voice()
	_begin_watch(actor as Player)


## Dolly the view onto the tube and hold the player for the running time.
## The rules go passive for the duration — a moment the game demands cannot
## also be a moment it punishes.
func _begin_watch(viewer: Player) -> void:
	_watching = true
	_viewer = viewer
	set_process_unhandled_input(true)
	get_tree().call_group("descent_listener", "descent_tape_watch", true)
	if _viewer != null:
		_viewer.velocity = Vector3.ZERO
		_viewer.set_physics_process(false)
		_viewer.set_process_unhandled_input(false)
	var vp := get_viewport()
	_prev_cam = vp.get_camera_3d() if vp != null else null
	if _prev_cam == null:
		return
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		add_child(_cam)
	_cam.global_transform = _prev_cam.global_transform
	_cam.make_current()
	# 34cm from the glass: the tube's width spans the full horizontal field
	# of view at fov 50, so the recording IS the screen for its running time.
	var target := global_transform \
		* Transform3D(Basis.IDENTITY, Vector3(-0.4146, 0.6603, 0.607))
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "global_transform", target, 1.2)


func _end_watch() -> void:
	if not _watching:
		return
	_watching = false
	set_process_unhandled_input(false)
	if _cam != null and is_instance_valid(_prev_cam):
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cam, "global_transform",
			_prev_cam.global_transform, 0.7)
		tw.tween_callback(func():
			if is_instance_valid(_prev_cam):
				_prev_cam.make_current()
			_restore_viewer())
	else:
		_restore_viewer()


func _restore_viewer() -> void:
	if _viewer != null and is_instance_valid(_viewer):
		_viewer.set_physics_process(true)
		_viewer.set_process_unhandled_input(true)
	# Release passive protection only after the player can move again. Doing it
	# before the return tween left a frozen, vulnerable 0.7-second window.
	if get_tree() != null:
		get_tree().call_group("descent_listener", "descent_tape_watch", false)
	_viewer = null


## Backing out mid-tape is an interruption: the tape rewinds.
func _unhandled_input(event: InputEvent) -> void:
	if not _watching or not _playing:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_E or key.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		reset_tape()


func _next_voice() -> void:
	if not _playing:
		return
	var pick := Sfx.random_whisper()
	_voice.stream = pick[0]
	_voice.volume_db = pick[1]
	_voice.pitch_scale = 0.82
	_voice.play()


func _on_video_finished() -> void:
	if _playing:
		_finish_tape()


## Walking out on the tape rewinds it. The recording plays for a person in
## the room, not for an empty one.
func reset_tape() -> void:
	if not _playing:
		return
	_playing = false
	_tape_time = 0.0
	if _video != null:
		_video.stop()
		_video_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Ordered optional chapters are completion-driven. Re-claim on the next
	# attempt so a chapter completed at another VCR cannot leave this set pinned
	# to an older interrupted assignment.
	if not objective:
		_tape_path = ""
	_end_watch()
	_present_idle()


func _finish_tape() -> void:
	_playing = false
	_done = true
	if _video != null:
		_video.stop()
		_video_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if objective:
		var chunk := get_parent()
		while chunk != null and not chunk is Chunk:
			chunk = chunk.get_parent()
		if chunk != null:
			chunk.descent_tape_watched = true
	get_tree().call_group("descent_listener", "descent_setup_tape_finished",
		setup_key, objective)
	_end_watch()
	_present_idle()


func _claim_tape() -> void:
	if not _tape_path.is_empty():
		return
	var listener := _listener()
	if listener != null and listener.has_method("descent_tape_for"):
		_tape_path = str(listener.call("descent_tape_for", setup_key, objective))
	if _tape_path.is_empty():
		_tape_path = VhsTapeLibrary.deterministic_fallback(
			world_seed, setup_key, objective)


func _listener() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("descent_listener")


## Streaming may remove a distant chunk while its television owns the camera.
## Restore control immediately rather than leaving the player frozen with a
## dead current camera and paused threats.
func _exit_tree() -> void:
	if _video != null:
		_video.stop()
	if not _watching:
		return
	_watching = false
	_playing = false
	if get_tree() != null:
		get_tree().call_group("descent_listener", "descent_tape_watch", false)
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_restore_viewer()


func _present_idle() -> void:
	_screen_mat.set_shader_parameter("playing", 0.0)
	_screen_mat.set_shader_parameter("progress", 0.0)
	_screen_mat.set_shader_parameter("use_footage", 0.0)
	_screen_mat.set_shader_parameter("watched", 1.0 if _done else 0.0)
	_hiss.volume_db = OPTIONAL_HISS_DB if not objective and not _done else -34.0
	if is_instance_valid(_discovery_light):
		_discovery_light.visible = not _done
	if is_instance_valid(_voice) and _voice.playing:
		_voice.stop()
	if _done:
		_hit.prompt_text = ""
		_hit.enabled = false
	else:
		_hit.prompt_text = "E — play the tape"
		_hit.enabled = true


func _process(dt: float) -> void:
	if is_instance_valid(_discovery_light) and _discovery_light.visible:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0028)
		_discovery_light.light_energy = lerpf(0.88, 1.28, pulse)
	if not _playing:
		return
	if _watching and (_viewer == null or not is_instance_valid(_viewer) \
			or not _viewer.is_inside_tree()):
		reset_tape()
		return
	_tape_time += dt
	if _video == null:
		# Procedural fallback keeps the old contract: stay in the room for
		# the running time, watched from wherever the player stands.
		_screen_mat.set_shader_parameter("progress", _tape_time / TAPE_SECONDS)
		if _player_cell() != home_cell:
			reset_tape()
			return
		if _tape_time >= TAPE_SECONDS:
			_finish_tape()


func _player_cell() -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return home_cell
	var p := cam.global_position
	return Vector2i(floori(p.x / WorldGen.CELL_SIZE), floori(p.z / WorldGen.CELL_SIZE))
