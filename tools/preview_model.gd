extends Node3D
## Small visual-QA stage for imported models.
## Run:
## godot --path . tools/preview_model.tscn -- \
##   --model=res://models/.../asset.glb --screenshot=/tmp/asset.png
##
## Optional: --scale=N and --rot-x=/--rot-y=/--rot-z= (degrees) preview the
## exact placement transform a chunk will use, which matters for source models
## authored in centimetres or lying on the wrong axis. --keep=NodeName renders
## only that subtree, for picking props out of a whole downloaded building.
## --camera=front|side|top overrides the default three-quarter view, and
## --scale-reference adds a 1m floor grid plus a slab at the player's eye
## height so a prop can be judged against the person who will walk past it.

var _scale_reference := false


func _ready() -> void:
	var model_path := ""
	var screenshot_path := "/tmp/liminal-model-preview.png"
	var trim_old_door := false
	var pre_scale := 1.0
	var pre_rot := Vector3.ZERO
	var keep := ""
	var camera_mode := "iso"
	for arg in OS.get_cmdline_user_args():
		if arg == "--scale-reference":
			_scale_reference = true
		if arg.begins_with("--model="):
			model_path = arg.substr(8)
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.substr(13)
		elif arg.begins_with("--scale="):
			pre_scale = maxf(0.0001, float(arg.substr(8)))
		elif arg.begins_with("--rot-x="):
			pre_rot.x = deg_to_rad(float(arg.substr(8)))
		elif arg.begins_with("--rot-y="):
			pre_rot.y = deg_to_rad(float(arg.substr(8)))
		elif arg.begins_with("--rot-z="):
			pre_rot.z = deg_to_rad(float(arg.substr(8)))
		elif arg.begins_with("--keep="):
			keep = arg.substr(7)
		elif arg.begins_with("--camera="):
			camera_mode = arg.substr(9)
		elif arg == "--trim-old-door":
			trim_old_door = true
	if model_path.is_empty():
		push_error("Pass --model=res://path/to/model.glb")
		get_tree().quit(1)
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("Could not load %s" % model_path)
		get_tree().quit(1)
		return
	var model := packed.instantiate() as Node3D
	if trim_old_door:
		var distant_variant := model.find_child("Null_1", true, false)
		if distant_variant != null:
			var variant_parent := distant_variant.get_parent()
			variant_parent.remove_child(distant_variant)
			distant_variant.free()
	if not keep.is_empty():
		var wanted := model.find_child(keep, true, false) as Node3D
		if wanted == null:
			push_error("No node named %s in %s" % [keep, model_path])
			get_tree().quit(1)
			return
		wanted.get_parent().remove_child(wanted)
		model.free()
		model = wanted
	var holder := Node3D.new()
	add_child(holder)
	model.scale = Vector3.ONE * pre_scale
	model.rotation = pre_rot
	holder.add_child(model)
	var bounds := _visual_bounds(holder)
	holder.position = Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z)
	bounds.position += holder.position
	_build_stage(bounds, camera_mode)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("saved model preview to %s; bounds=%s" % [screenshot_path, bounds])
	get_tree().quit()


func _visual_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		var bounds := mesh_node.global_transform * mesh_node.mesh.get_aabb()
		if first:
			result = bounds
			first = false
		else:
			result = result.merge(bounds)
	return result


## Height of the player's camera in `scripts/player.gd`. A prop that looks
## right in isolation can still be waist-high or towering once it is standing
## next to the person who walks past it, so the audit stage can put that
## reference in frame.
const PLAYER_EYE := 1.62


## A featureless slab exactly as tall as the player's eye, one metre clear of
## the model, plus a 1m floor grid. Nothing about it should read as a
## character — it is a ruler, not a mannequin.
func _build_scale_reference(bounds: AABB) -> void:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, PLAYER_EYE, 0.22)
	post.mesh = box
	post.position = Vector3(bounds.end.x + 0.7, PLAYER_EYE * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.20, 0.20)
	mat.roughness = 0.9
	post.material_override = mat
	add_child(post)
	var grid := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color(0.35, 0.38, 0.42)
	var half := ceili(maxf(3.0, maxf(bounds.size.x, bounds.size.z)))
	lines.surface_begin(Mesh.PRIMITIVE_LINES, grid_mat)
	for i in range(-half, half + 1):
		lines.surface_add_vertex(Vector3(i, 0.01, -half))
		lines.surface_add_vertex(Vector3(i, 0.01, half))
		lines.surface_add_vertex(Vector3(-half, 0.01, i))
		lines.surface_add_vertex(Vector3(half, 0.01, i))
	lines.surface_end()
	grid.mesh = lines
	add_child(grid)


func _build_stage(bounds: AABB, camera_mode := "iso") -> void:
	var extent := maxf(bounds.size.x, bounds.size.z)
	var height := bounds.size.y
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(maxf(4.0, extent * 3.0), 0.08,
		maxf(4.0, extent * 3.0))
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.05
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.13, 0.14, 0.15)
	floor_mat.roughness = 0.72
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	if _scale_reference:
		_build_scale_reference(bounds)
		extent = maxf(extent, bounds.end.x + PLAYER_EYE * 0.5)
		height = maxf(height, PLAYER_EYE)
	var camera := Camera3D.new()
	var reach := maxf(extent, height)
	match camera_mode:
		"front":
			camera.position = Vector3(0, height * 0.55, maxf(1.2, reach * 2.0))
		"side":
			camera.position = Vector3(maxf(1.2, reach * 2.0), height * 0.55, 0)
		"top":
			camera.position = Vector3(0.001, maxf(1.2, reach * 2.0), 0)
		_:
			camera.position = Vector3(extent * 1.25, height * 0.72,
				maxf(1.2, extent * 2.15))
	camera.look_at_from_position(camera.position,
		Vector3(0, height * 0.48, 0), Vector3.UP)
	camera.fov = 48.0
	add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-extent, height * 0.75, extent)
	fill.light_energy = 4.0
	fill.omni_range = maxf(5.0, extent * 4.0)
	add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.39, 0.42)
	env.ambient_light_energy = 0.75
	world.environment = env
	add_child(world)
