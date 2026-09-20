class_name ShadowWalkerVisual
extends Node3D
## Animated 3D presentation for the hostile monster roster. ShadowFigure still
## owns pursuit, pathing, collision, audio, torch rules and the caught sequence.

signal manifestation_changed(value: float)

const MODEL_PATHS := [
	"res://models/provided/hollow_watcher/Meshy_AI_The_Hollow_Watcher_Walking.glb",
	"res://models/provided/model2/model2.glb",
	"res://models/provided/model3/Meshy_AI_The_Hollow_Watcher_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/model4/model4.glb",
	"res://models/provided/trenchwalker/Meshy_AI_Ashen_Trenchwalker_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/harlequin/Meshy_AI_Hooded_Harlequin_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/plague_surgeon/Meshy_AI_The_Plague_Surgeon_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/silent_visitor/Meshy_AI_The_Silent_Visitor_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/veiled_matron/Meshy_AI_The_Veiled_Matron_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/hound/monster6-dog.glb",
	"res://models/provided/horror_girl/Meshy_AI_horror_girl_hair_cove_biped_Animation_Walking_withSkin.glb",
	"res://models/provided/faceless_enforcer/Meshy_AI_The_Faceless_Enforcer_biped_Animation_Walking_withSkin.glb",
]
## Optional second locomotion clips. The body and skeleton come from the walk
## scene above; these scenes contribute animation data only.
const RUN_MODEL_PATHS := {
	10: "res://models/provided/horror_girl/Meshy_AI_horror_girl_hair_cove_biped_Animation_Running_withSkin.glb",
}
const BODY_SHADER := preload("res://shaders/shadow_walker.gdshader")
const HALO_SHADER := preload("res://shaders/shadow_walker_halo.gdshader")
const GHOST_SHADER := preload("res://shaders/ghost_walker.gdshader")
const GHOST_HALO_SHADER := preload("res://shaders/ghost_walker_halo.gdshader")
## The supplied walkers use the standard Mixamo metre-scale skeleton. Keep
## this per model so a future roster addition cannot silently inherit the
## wrong physical scale.
const SOURCE_HEIGHTS := [1.7, 1.7, 1.7, 1.7, 1.7, 1.7, 1.7, 1.7, 1.7, 0.75, 1.7, 1.7]
## The hound ships as a centimetre-scale Unreal export with a 0.01 Armature
## node, so it needs a 100x prescale before the target-height scaling or it
## renders two centimetres tall. Everything else is authored in metres.
const MODEL_PRESCALE := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 100.0, 1.0, 1.0]
const TARGET_HEIGHT := 2.08
## The hound stages smaller than the humanoids: between its 0.75m authored
## size and the 2.08m roster standard.
const MODEL_TARGET_HEIGHTS := [2.08, 2.08, 2.08, 2.08, 2.08, 2.08, 2.08, 2.08, 2.08, 1.55, 2.08, 2.08]
## Ghost roster members render as cold translucent apparitions (own body and
## halo shaders) instead of the black shadow treatment. The manifestation,
## fade and burn parameters drive the same state machine in both styles.
const GHOST_RENDER := [false, false, false, false, true, true, true, true, true, true, true, true]
const APPEAR_SECONDS := 0.8
## A heavy human-sized silhouette should visibly pivot, not snap toward a new
## path node. At 135 degrees/sec a right-angle turn takes about two-thirds of
## a second; the capped frame delta prevents a hitch from consuming the turn.
const TURN_SPEED := deg_to_rad(135.0)
const TURN_ACCELERATION := deg_to_rad(540.0)
## Metres/sec covered by the planted toe at playback 1.0, measured from each
## imported clip at TARGET_HEIGHT (tools/measure_walker_stride.gd). The old
## guessed 2.9 value left the planted foot sliding forward with the body.
# Metres/sec of planted-foot travel at playback 1.0, measured from the Hollow
# Watcher's authored Mixamo walk at TARGET_HEIGHT.
const WALK_CYCLE_SPEEDS := [1.98, 1.98, 1.98, 1.965, 1.85, 1.65, 1.82, 1.72, 1.72, 1.98, 1.755, 1.72]
## Planted-foot travel at playback 1.0 for optional run clips. Kept separate
## from gameplay speed so animation cadence can match whatever the AI chooses.
const RUN_CYCLE_SPEEDS := {10: 1.73}

## Retain completed requests so a spawn's readiness check and visual creation
## share the same decoded scene, including after the loader request is consumed.
static var _model_scenes: Dictionary = {}
static var _run_model_scenes: Dictionary = {}
static var _walking_clips: Dictionary = {}
static var _running_clips: Dictionary = {}

var _presentation: Node3D
var _model: Node3D
var _animation_player: AnimationPlayer
var _materials: Array[ShaderMaterial] = []
var _halo_materials: Array[ShaderMaterial] = []
var _parameters := {
	&"fade": 1.0,
	&"burn": 0.0,
	&"ignite": 0.0,
	&"fragmented": 0.0,
	&"torch": 0.0,
}
var _manifestation := 0.0
var _transition: Tween
var _closeup := false
var _phase := 0.0
var _skeleton: Skeleton3D
## Render-only seam mirror: skips the arrival tween so the first sync owns
## every visible parameter, and never advances its own animation player.
var proxy_mode := false
var _movement_ratio := 0.0
var _locomotion_clip := &"walk"
var _turn_velocity := 0.0
## Assigned before entering the tree. Keeping the selection on the visual makes
## caught sequences and focused captures reproduce the exact spawned monster.
var model_index := 0


func _ready() -> void:
	_phase = randf() * 19.0
	_build_model()
	set_manifestation(0.0)
	if not proxy_mode:
		appear(APPEAR_SECONDS)


func _build_model() -> void:
	_presentation = Node3D.new()
	_presentation.name = "AnimatedShadowWalker"
	model_index = clampi(model_index, 0, MODEL_PATHS.size() - 1)
	_presentation.scale = Vector3.ONE * (MODEL_TARGET_HEIGHTS[model_index] / float(SOURCE_HEIGHTS[model_index]))
	add_child(_presentation)
	var model_scene := _model_scene(model_index)
	if model_scene == null:
		push_error("Could not load shadow walker model %d" % model_index)
		return
	_model = model_scene.instantiate() as Node3D
	_model.name = "WalkingFigure_%02d" % (model_index + 1)
	_model.scale = Vector3.ONE * MODEL_PRESCALE[clampi(model_index, 0, MODEL_PRESCALE.size() - 1)]
	_presentation.add_child(_model)
	_prepare_materials(_model)
	_prepare_animation(_model)
	if _model != null:
		_normalize_model_origin()


func _prepare_materials(root: Node) -> void:
	var ghost: bool = GHOST_RENDER[clampi(model_index, 0, GHOST_RENDER.size() - 1)]
	var body_shader: Shader = GHOST_SHADER if ghost else BODY_SHADER
	var halo_shader: Shader = GHOST_HALO_SHADER if ghost else HALO_SHADER
	var specs := [
		[0.020, 0.016, 0.011], [0.032, 0.010, 0.008],
		[0.044, 0.005, 0.005], [0.056, 0.003, 0.002],
	] if ghost else [
		[0.018, 0.30, 0.010],
		[0.045, 0.17, 0.007],
		[0.090, 0.080, 0.004],
		[0.160, 0.034, 0.002],
		[0.250, 0.012, 0.001],
	]
	for mesh in _meshes(root):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			var material := ShaderMaterial.new()
			material.shader = body_shader
			material.set_shader_parameter(&"noise_tex", Mats.detail_noise())
			material.set_shader_parameter(&"phase", _phase)
			material.set_shader_parameter(&"burn_peak", burn_peak())
			if source != null and source.albedo_texture != null:
				material.set_shader_parameter(&"albedo_tex", source.albedo_texture)
			mesh.set_surface_override_material(surface, material)
			_materials.append(material)
		# A nested set of expanded shells convolves the silhouette's
		# alpha, so the black body and its falloff are one continuous image.
		# Unlike a refractive backdrop, this cannot read as a second transparent
		# object sitting behind the creature.
		var previous_halo: ShaderMaterial
		# Width and opacity approximate a Gaussian from dense core to light tail.
		# Each shell is the same skinned mesh, so the defocus follows the walk.
		for spec in specs:
			_append_halo(mesh, halo_shader, spec, previous_halo)
			previous_halo = _halo_materials[_halo_materials.size() - 1]


func _append_halo(mesh: MeshInstance3D, shader: Shader, spec: Array,
		previous_halo: ShaderMaterial) -> void:
	var halo := ShaderMaterial.new()
	halo.shader = shader
	halo.set_shader_parameter(&"phase", _phase)
	halo.set_shader_parameter(&"noise_tex", Mats.detail_noise())
	halo.set_shader_parameter(&"halo_width", spec[0])
	halo.set_shader_parameter(&"halo_alpha", spec[1])
	halo.set_shader_parameter(&"halo_emission", spec[2])
	# Veils always draw after every body part: mesh parts sort independently
	# and a nearly-opaque part drawn after another part's veil would erase it,
	# flipping on and off as the camera moves.
	halo.render_priority = 1
	if previous_halo == null:
		mesh.material_overlay = halo
	else:
		previous_halo.next_pass = halo
	_halo_materials.append(halo)


func _prepare_animation(root: Node) -> void:
	_animation_player = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		push_error("Shadow walker model %d is missing an AnimationPlayer" % model_index)
		return
	var clip := StringName()
	for candidate in _animation_player.get_animation_list():
		if "walk" in String(candidate).to_lower():
			clip = candidate
			break
	if clip == StringName():
		for candidate in _animation_player.get_animation_list():
			if String(candidate).to_lower() != "reset":
				clip = candidate
				break
	if clip == StringName():
		push_error("Shadow walker model %d is missing a walking clip" % model_index)
		return
	# Imported glTF clips default to one-shot. Duplicate only the animation
	# resource, keeping the imported scene immutable, and loop the walk locally.
	var source := _animation_player.get_animation(clip)
	if not _walking_clips.has(source):
		var loop := source.duplicate(true) as Animation
		loop.loop_mode = Animation.LOOP_LINEAR
		_walking_clips[source] = loop
	var walking: Animation = _walking_clips[source]
	var runtime := AnimationLibrary.new()
	runtime.add_animation(&"walk", walking)
	var run_scene := _run_model_scene(model_index)
	if run_scene != null:
		var run_root := run_scene.instantiate()
		var run_player := run_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if run_player != null:
			var run_name := StringName()
			for candidate in run_player.get_animation_list():
				if "run" in String(candidate).to_lower() \
						and run_player.get_animation(candidate).length > 0.25:
					run_name = candidate
					break
			if run_name != StringName():
				var run_source := run_player.get_animation(run_name)
				if not _running_clips.has(run_source):
					var run_loop := run_source.duplicate(true) as Animation
					run_loop.loop_mode = Animation.LOOP_LINEAR
					_running_clips[run_source] = run_loop
				runtime.add_animation(&"run", _running_clips[run_source])
		run_root.free()
	_animation_player.add_animation_library(&"runtime", runtime)
	# Advance from the same physics sample as translation. An autonomous idle
	# clock can play an extra fraction of a step after the actor brakes/turns.
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation_player.play(&"runtime/walk")
	_animation_player.speed_scale = 0.0
	_animation_player.advance(0.0)


## Measure the posed mesh in its own frames and stage it on the origin.
## Imports are trusted for shape but not for staging: the hound's skeleton is
## offset from its scene origin, which used to sink it into the floor, push it
## metres behind its slot, shrink its culling box to centimetres, and let the
## ghost foot-fade erase everything below local zero. Only gross offsets move;
## a mid-stride frame legitimately leans humanoids by ~10cm, which stays.
func _normalize_model_origin() -> void:
	if _model == null or _presentation == null:
		return
	var box := AABB()
	var first := true
	for mesh in _meshes(_model):
		if mesh.mesh == null:
			continue
		var local_points := PackedVector3Array()
		for surface in mesh.mesh.get_surface_count():
			local_points.append_array(
				_posed_surface_vertices(mesh, surface, true))
		if local_points.is_empty():
			continue
		var local_box := AABB(local_points[0], Vector3.ZERO)
		for point in local_points:
			local_box = local_box.expand(point)
		_set_mesh_foot_base(mesh, local_box.position.y - 0.005)
		mesh.custom_aabb = mesh.mesh.get_aabb().merge(local_box).grow(0.2)
		var staged: AABB = global_transform.affine_inverse() \
			* (mesh.global_transform * local_box)
		box = staged if first else box.merge(staged)
		first = false
	if first:
		return
	var center := box.get_center()
	var shift := Vector3(-center.x, -box.position.y, -center.z)
	shift.x = 0.0 if absf(shift.x) < 0.15 else shift.x
	shift.y = 0.0 if absf(shift.y) < 0.15 else shift.y
	shift.z = 0.0 if absf(shift.z) < 0.15 else shift.z
	if shift.length() > 0.0001:
		_model.position += shift / _presentation.scale.x


func _set_mesh_foot_base(mesh: MeshInstance3D, foot_base: float) -> void:
	for surface in mesh.mesh.get_surface_count():
		var mat := mesh.get_surface_override_material(surface) as ShaderMaterial
		if mat != null and mat.shader == GHOST_SHADER:
			mat.set_shader_parameter(&"foot_base", foot_base)


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child in root.get_children():
		result.append_array(_meshes(child))
	return result


## Sample the actual animated surface at the current walk pose. ARRAY_BONES
## indices address Skin binds, whose inverse bind pose is combined with the
## skeleton's current global bone pose exactly as the GPU skinning path does.
## Returning points in this visual's local space lets the death emitter inherit
## the walker's precise silhouette, scale and pose instead of approximating it
## with a second humanoid-shaped cloud.
func burn_surface_points(max_points := 520) -> PackedVector3Array:
	var surface_points := PackedVector3Array()
	for mesh_instance in _meshes(_model):
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			surface_points.append_array(_posed_surface_vertices(mesh_instance, surface))
	if surface_points.size() <= max_points:
		return surface_points
	var sampled := PackedVector3Array()
	for index in max_points:
		# A half-step stratified sample spans the complete indexed vertex buffer
		# without allocating or shuffling a second large array at death time.
		var source_index := mini(surface_points.size() - 1,
			floori((float(index) + 0.5) * surface_points.size() / max_points))
		sampled.append(surface_points[source_index])
	return sampled


## Area-weighted samples avoid inheriting each GLB's arbitrary vertex density.
## Every point and normal comes from a triangle of the currently posed mesh, so
## the detached fragment cloud is a complete copy of the visible body surface.
func burn_surface_samples(max_samples := 1200) -> Dictionary:
	var triangle_vertices := PackedVector3Array()
	var triangle_normals := PackedVector3Array()
	var cumulative_area := PackedFloat32Array()
	var total_area := 0.0
	for mesh_instance in _meshes(_model):
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			if mesh_instance.mesh.surface_get_primitive_type(surface) \
					!= Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var posed := _posed_surface_vertices(mesh_instance, surface)
			if arrays.is_empty() or posed.size() < 3:
				continue
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
				if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var corner_count := indices.size() if not indices.is_empty() else posed.size()
			for corner in range(0, corner_count - 2, 3):
				var ia := indices[corner] if not indices.is_empty() else corner
				var ib := indices[corner + 1] if not indices.is_empty() else corner + 1
				var ic := indices[corner + 2] if not indices.is_empty() else corner + 2
				if ia < 0 or ib < 0 or ic < 0 or ia >= posed.size() \
						or ib >= posed.size() or ic >= posed.size():
					continue
				var a := posed[ia]
				var b := posed[ib]
				var c := posed[ic]
				var cross := (b - a).cross(c - a)
				var area := cross.length() * 0.5
				if area <= 0.0000001:
					continue
				total_area += area
				triangle_vertices.append_array(PackedVector3Array([a, b, c]))
				triangle_normals.append(cross.normalized())
				cumulative_area.append(total_area)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	if total_area <= 0.0 or cumulative_area.is_empty():
		return {"points": points, "normals": normals}
	var rng := RandomNumberGenerator.new()
	rng.seed = 9187 + model_index * 104729 + int(_phase * 100000.0)
	for index in max_samples:
		var area_target := (float(index) + rng.randf()) / max_samples * total_area
		var triangle := mini(cumulative_area.size() - 1,
			cumulative_area.bsearch(area_target))
		var a := triangle_vertices[triangle * 3]
		var b := triangle_vertices[triangle * 3 + 1]
		var c := triangle_vertices[triangle * 3 + 2]
		var root := sqrt(rng.randf())
		var across := rng.randf()
		points.append(a * (1.0 - root) + b * (root * (1.0 - across))
			+ c * (root * across))
		normals.append(triangle_normals[triangle])
	return {"points": points, "normals": normals}


func _posed_surface_vertices(mesh_instance: MeshInstance3D,
		surface: int, mesh_local := false) -> PackedVector3Array:
	var frame := mesh_instance.global_transform.affine_inverse() \
		if mesh_local else global_transform.affine_inverse()
	var arrays := mesh_instance.mesh.surface_get_arrays(surface)
	if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return PackedVector3Array()
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var result := PackedVector3Array()
	if vertices.is_empty():
		return result
	var skeleton := mesh_instance.get_node_or_null(
		mesh_instance.skeleton) as Skeleton3D
	var skin := mesh_instance.skin
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] \
		if arrays[Mesh.ARRAY_BONES] is PackedInt32Array else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] \
		if arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array else PackedFloat32Array()
	var influences := weights.size() / vertices.size() if not weights.is_empty() else 0
	for vertex_index in vertices.size():
		var point := vertices[vertex_index]
		var posed := false
		if skeleton != null and skin != null and influences > 0 \
				and bones.size() >= (vertex_index + 1) * influences:
			var skinned := Vector3.ZERO
			var weight_total := 0.0
			for influence in influences:
				var array_index := vertex_index * influences + influence
				var weight := weights[array_index]
				var bind_index := bones[array_index]
				if weight <= 0.0001 or bind_index < 0 \
						or bind_index >= skin.get_bind_count():
					continue
				var bone_index := skin.get_bind_bone(bind_index)
				if bone_index < 0:
					bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
				if bone_index < 0 or bone_index >= skeleton.get_bone_count():
					continue
				var skinning_transform := skeleton.get_bone_global_pose(bone_index) \
					* skin.get_bind_pose(bind_index)
				skinned += (skinning_transform * point) * weight
				weight_total += weight
			if weight_total > 0.0001:
				skinned /= weight_total
				point = frame * (skeleton.global_transform * skinned)
				posed = true
		if not posed:
			point = frame * (mesh_instance.global_transform * point)
		result.append(point)
	return result


func animate(dt: float, _observed: bool) -> void:
	if _animation_player == null:
		return
	_animation_player.speed_scale = 0.16 if _closeup else _movement_ratio
	_animation_player.advance(maxf(dt, 0.0))


func begin_motion_frame() -> void:
	_movement_ratio = 0.0


func set_movement_ratio(value: float) -> void:
	_movement_ratio = maxf(value, 0.0)


func set_ground_speed(metres_per_second: float, running := false) -> void:
	var wanted := &"run" if running and has_run_cycle() else &"walk"
	if wanted != _locomotion_clip:
		_locomotion_clip = wanted
		# Both clips use the same Meshy skeleton. A short blend hides the phase
		# discontinuity without delaying the readable deck/water gait change.
		_animation_player.play(StringName("runtime/" + String(wanted)), 0.12)
	var cycle_speed := run_cycle_speed() if wanted == &"run" else walk_cycle_speed()
	set_movement_ratio(metres_per_second / cycle_speed)


func walk_cycle_speed() -> float:
	return WALK_CYCLE_SPEEDS[clampi(model_index, 0, WALK_CYCLE_SPEEDS.size() - 1)]


func has_run_cycle() -> bool:
	return _animation_player != null and _animation_player.has_animation(&"runtime/run")


func run_cycle_speed() -> float:
	return float(RUN_CYCLE_SPEEDS.get(model_index, walk_cycle_speed()))


func locomotion_clip() -> StringName:
	return _locomotion_clip


func forward_world() -> Vector3:
	var forward := global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 \
		else Vector3.BACK


func face_world_position(target: Vector3, dt := 1.0 / 60.0) -> void:
	var direction := target - global_position
	face_world_direction(direction, dt)


## Turn the supplied model's authored +Z front into its real direction of
## travel. Returns how closely it is aligned so ShadowFigure can wait through
## a sharp turn instead of translating sideways while the body catches up.
func face_world_direction(direction: Vector3, dt := 1.0 / 60.0) -> float:
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return 1.0
	direction = direction.normalized()
	# This supplied glTF's authored front is +Z (opposite Godot's conventional
	# forward). Aim that axis along the next genuine pathing step, not at the
	# player: across a doorway those are different vectors, and aiming at the
	# player made the walking animation visibly strafe through every turn.
	var forward := forward_world()
	var error := wrapf(atan2(direction.x, direction.z)
		- atan2(forward.x, forward.z), -PI, PI)
	var wanted := clampf(error * 5.0, -TURN_SPEED, TURN_SPEED)
	_turn_velocity = move_toward(_turn_velocity, wanted, TURN_ACCELERATION * dt)
	var turn := _turn_velocity * dt
	if signf(turn) == signf(error) and absf(turn) > absf(error):
		turn = error
		_turn_velocity = 0.0
	global_rotate(Vector3.UP, turn)
	return forward_world().dot(direction)


func set_instance_shader_parameter(parameter: StringName, value: Variant) -> void:
	if not _parameters.has(parameter):
		return
	_parameters[parameter] = value
	_set_parameter(parameter, value)


func _set_parameter(parameter: StringName, value: Variant) -> void:
	for material in _materials:
		material.set_shader_parameter(parameter, value)
	for material in _halo_materials:
		material.set_shader_parameter(parameter, value)


func set_manifestation(value: float) -> void:
	_manifestation = clampf(value if is_finite(value) else 0.0, 0.0, 1.0)
	_set_parameter(&"manifestation", _manifestation)
	if is_instance_valid(_presentation):
		_presentation.visible = _manifestation > 0.0001
	manifestation_changed.emit(_manifestation)


## World-space seam clip on every body and halo pass. Deliberately outside
## _parameters: each side of a mirror pair keeps its own half-space.
func set_seam_clip(plane: Vector4, enabled: bool) -> void:
	_set_parameter(&"clip_plane", plane)
	_set_parameter(&"clip_enabled", 1.0 if enabled else 0.0)


func skeleton() -> Skeleton3D:
	if not is_instance_valid(_skeleton):
		_skeleton = null
		if is_instance_valid(_model):
			var found := _model.find_children("*", "Skeleton3D", true,
				false)
			if not found.is_empty():
				_skeleton = found[0] as Skeleton3D
	return _skeleton


## Become the other walker's exact rendered twin: local transform, every
## bone pose, material state, noise phase, and closeup treatment. The
## animation player is never touched, so no blend or advance can drift.
func mirror_from(other: ShadowWalkerVisual) -> void:
	transform = other.transform
	var src := other.skeleton()
	var dst := skeleton()
	if src != null and dst != null:
		var n := mini(src.get_bone_count(), dst.get_bone_count())
		for i in n:
			dst.set_bone_pose_rotation(i, src.get_bone_pose_rotation(i))
			dst.set_bone_pose_position(i, src.get_bone_pose_position(i))
			dst.set_bone_pose_scale(i, src.get_bone_pose_scale(i))
	for key in other._parameters:
		set_instance_shader_parameter(key, other._parameters[key])
	set_manifestation(other._manifestation)
	if other._closeup != _closeup:
		set_closeup_mode(other._closeup)
	if other._phase != _phase:
		_phase = other._phase
		_set_parameter(&"phase", _phase)


func appear(duration := 0.7) -> void:
	_transition_to(1.0, duration)


func disappear(duration := 0.8) -> void:
	_transition_to(0.0, duration)


func _transition_to(target: float, duration: float) -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if duration <= 0.0:
		set_manifestation(target)
		return
	_transition = create_tween()
	_transition.tween_method(set_manifestation, _manifestation,
		clampf(target, 0.0, 1.0), duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT)


func set_closeup_mode(enabled: bool) -> void:
	_closeup = enabled
	# Reduce the emissive rim at arm's length so the caught shot retains the
	# textured face and limbs instead of blowing them into a flat outline.
	for material in _materials:
		material.set_shader_parameter(&"effect_strength", 0.46 if enabled else 1.0)
	for material in _halo_materials:
		material.set_shader_parameter(&"effect_strength", 0.46 if enabled else 1.0)


func is_closeup_mode() -> bool:
	return _closeup


## Internal rendering remains HDR in either mode, but only an active HDR
## window receives the display's extra highlight headroom.
func burn_peak() -> float:
	var window := get_window()
	if HdrOutput.is_active(window):
		# Tiny sub-centimetre shards cover only a fraction of a resolved pixel. A
		# wall panel can display its 6.5x emission across whole pixels; these need
		# roughly twice that source radiance to resolve equally hot after TAA.
		# Real HDR/XDR output then receives additional highlight headroom.
		return clampf(HdrOutput.output_max_linear_value(window) * 5.0, 12.0, 32.0)
	return 12.0


func animation_player() -> AnimationPlayer:
	return _animation_player


static func model_count() -> int:
	return MODEL_PATHS.size()


## Audit/test teardown only. Normal play keeps decoded scenes and extracted
## animation clips for the process lifetime. A short headless run can exit
## while the signature model requested by ShadowFigures is still decoding;
## consume those requests before clearing the caches so Godot does not report
## the loader's zero-ref bookkeeping object as leaked.
static func clear_runtime_caches() -> void:
	for path in MODEL_PATHS:
		_finish_threaded_request(path)
	for path in RUN_MODEL_PATHS.values():
		_finish_threaded_request(str(path))
	_model_scenes.clear()
	_run_model_scenes.clear()
	_walking_clips.clear()
	_running_clips.clear()


static func _finish_threaded_request(path: String) -> void:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(path)


## The manager requests only the next shuffled design. These source models are
## texture-heavy; preparing it eagerly would make every level pay its full
## startup and memory cost before a single monster had appeared.
static func request_model(index: int) -> void:
	if index < 0 or index >= MODEL_PATHS.size():
		return
	if not _model_scenes.has(index):
		var path: String = MODEL_PATHS[index]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path, "PackedScene")
	if RUN_MODEL_PATHS.has(index) and not _run_model_scenes.has(index):
		var run_path: String = RUN_MODEL_PATHS[index]
		var run_status := ResourceLoader.load_threaded_get_status(run_path)
		if run_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(run_path, "PackedScene")


## Poll without ever waiting for decoding. Managers leave their selected model
## in the shuffle bag until this succeeds; only completed requests can be taken.
static func is_model_ready(index: int) -> bool:
	if index < 0 or index >= MODEL_PATHS.size():
		return false
	request_model(index)
	if not _model_scenes.has(index):
		var path: String = MODEL_PATHS[index]
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			return false
		var scene := ResourceLoader.load_threaded_get(path) as PackedScene
		if scene == null:
			return false
		_model_scenes[index] = scene
	if RUN_MODEL_PATHS.has(index) and not _run_model_scenes.has(index):
		var run_path: String = RUN_MODEL_PATHS[index]
		if ResourceLoader.load_threaded_get_status(run_path) != ResourceLoader.THREAD_LOAD_LOADED:
			return false
		var run_scene := ResourceLoader.load_threaded_get(run_path) as PackedScene
		if run_scene == null:
			return false
		_run_model_scenes[index] = run_scene
	return true


static func _model_scene(index: int) -> PackedScene:
	if index < 0 or index >= MODEL_PATHS.size():
		return null
	if _model_scenes.has(index):
		return _model_scenes[index] as PackedScene
	if ResourceLoader.load_threaded_get_status(MODEL_PATHS[index]) \
			== ResourceLoader.THREAD_LOAD_LOADED and is_model_ready(index):
		return _model_scenes[index] as PackedScene
	# Standalone previews and focused visual audits may instantiate directly.
	# Gameplay managers must pass is_model_ready before adding their figure, so
	# their creation path always takes the cached branch above.
	var scene := load(MODEL_PATHS[index]) as PackedScene
	if scene != null:
		_model_scenes[index] = scene
	return scene


static func _run_model_scene(index: int) -> PackedScene:
	if not RUN_MODEL_PATHS.has(index):
		return null
	if _run_model_scenes.has(index):
		return _run_model_scenes[index] as PackedScene
	var path: String = RUN_MODEL_PATHS[index]
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		var threaded := ResourceLoader.load_threaded_get(path) as PackedScene
		if threaded != null:
			_run_model_scenes[index] = threaded
			return threaded
	# Standalone previews and focused audits may instantiate directly.
	var scene := load(path) as PackedScene
	if scene != null:
		_run_model_scenes[index] = scene
	return scene


func _exit_tree() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
