extends "res://tools/lib/audit_base.gd"
## GPU regression: illuminate a fixed neutral wall with the real Airport main
## fixture, then retreat the camera while keeping the same wall patch framed.
## Verifies actual pixels, not just fade-property values. No fog/GI can mask it.
const OUT := "res://build/light-distance-review"
var view: SubViewport
var camera: Camera3D
var light: OmniLight3D
var target: Vector3

func sample(distance: float, label: String) -> float:
	camera.look_at_from_position(target + Vector3(0, 0, -(distance + 5.0)), target)
	camera.fov = rad_to_deg(2.0 * atan(2.0 / (distance + 5.0)))
	for i in 8:
		await process_frame
	RenderingServer.force_draw(false, 1.0 / 60.0)
	var picture := view.get_texture().get_image()
	picture.save_png(OUT.path_join("%s-%dm.png" % [label, int(distance)]))
	var total := 0.0
	for x in range(248, 264):
		for y in range(248, 264):
			total += picture.get_pixel(x, y).get_luminance()
	return total / 256.0

func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("light-distance pixel test requires a real GPU renderer")
		finish("light distance pixels")
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(512, 512)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var chunk := Chunk.new(99173, Vector2i.ZERO, 4)
	for node in chunk.find_children("*", "OmniLight3D", true, false):
		if node.get_meta("stream_room_light", false):
			light = node.duplicate() as OmniLight3D
			break
	assert(light != null)
	var old_begin := light.distance_fade_begin
	chunk.prepare_runtime_rendering(ChunkManager.ROOM_LIGHT_FADE_BEGIN)
	for node in chunk.find_children("*", "OmniLight3D", true, false):
		if node.get_meta("stream_room_light", false):
			light.distance_fade_shadow = node.distance_fade_shadow
			break
	chunk.free()
	view.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.01, 0.01, 0.01)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.01
	view.add_child(environment)
	target = light.position + Vector3(0, -0.8, 5.0)
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4, 3, 0.03)
	wall.mesh = mesh
	wall.position = target
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.65, 0.65)
	material.roughness = 1.0
	material.metallic_specular = 0.0
	wall.material_override = material
	view.add_child(wall)
	camera = Camera3D.new()
	camera.far = 100.0
	view.add_child(camera)
	camera.current = true
	var near := await sample(20.0, "authored")
	expect(near > 0.15, "lighting fixture did not illuminate the test wall")
	for distance in [36.0, 48.0, 60.0]:
		light.distance_fade_begin = old_begin
		var old := await sample(distance, "authored")
		light.distance_fade_begin = ChunkManager.ROOM_LIGHT_FADE_BEGIN
		var fixed := await sample(distance, "extended")
		expect(old < fixed * 0.5, "fixture did not reproduce old dark-at-distance failure")
		expect(fixed >= near * 0.9, "extended room lighting still darkened the fixed wall patch")
		print("LIGHT_DISTANCE_PIXELS %.0fm old=%.3f fixed=%.3f near=%.3f" % [distance, old, fixed, near])
	view.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("light distance pixels")
