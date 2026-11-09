extends RefCounted
## Visible direct/indirect fittings. Geometry, emitting faces and light origins
## are authored together so a lighting change cannot leave a detached source.
const BALLAST := preload("res://scripts/bloom_fixture_flicker.gd")
static var _round_mask: ImageTexture
static var _shadow_meshes := {}

static func round_mask() -> ImageTexture:
	if _round_mask == null:
		var pixels := Image.create(128,128,false,Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var radius := (Vector2(x+0.5,y+0.5)-Vector2(64,64)).length()
				var value := clampf(64.0-radius,0.0,1.0)
				pixels.set_pixel(x,y,Color(value,value,value))
		_round_mask = ImageTexture.create_from_image(pixels)
	return _round_mask

static func mesh_bounds_in(mesh: MeshInstance3D, parent: Node3D) -> AABB:
	var relative := mesh.transform
	var ancestor := mesh.get_parent()
	while ancestor != null and ancestor != parent:
		if ancestor is Node3D: relative = ancestor.transform*relative
		ancestor = ancestor.get_parent()
	return relative*mesh.get_aabb()

static func lower_face(parent: Node3D, lens: MeshInstance3D, color: Color,
		energy: float, reach: float, shadow_tier: int, source: String) -> AreaLight3D:
	var bounds := mesh_bounds_in(lens,parent)
	var face := bounds.get_center()
	face.y = bounds.position.y
	return rectangular(parent,lens,Vector2(bounds.size.x,bounds.size.z),
		face,false,color,energy,reach,shadow_tier,source)

## Opal globes and glass cylinders emit around their luminous volume. Keep
## the point approximation inside that volume, never suspended below it.
static func bulb(parent: Node3D, lens: MeshInstance3D, color: Color,
		energy: float, reach: float, shadow_tier: int, source: String) -> OmniLight3D:
	var bounds := mesh_bounds_in(lens,parent)
	var light := OmniLight3D.new()
	light.name = "OpalLight"
	light.position = bounds.get_center()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.light_size = minf(bounds.size.x,bounds.size.z)*0.5
	light.light_volumetric_fog_energy = 0.45
	light.set_meta("visible_source",source)
	parent.add_child(light)
	light.set_meta("fixture_emitter",light.get_path_to(lens))
	light.set_meta("fixture_volume",true)
	GraphicsQuality.configure_practical_light(light,shadow_tier)
	return light

static func bounds_in(root: Node3D, parent: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var box := mesh_bounds_in(mesh,parent)
		result = result.merge(box) if found else box
		found = true
	return result

static func rectangular(parent: Node3D, lens: MeshInstance3D, size: Vector2,
		face: Vector3, upward: bool, color: Color, energy: float,
		reach: float, shadow_tier: int, source: String) -> AreaLight3D:
	var light := AreaLight3D.new()
	light.name = "UpperLight" if upward else "LowerLight"
	light.position = face + Vector3.UP * (0.015 if upward else -0.03)
	light.rotation.x = PI/2.0 if upward else -PI/2.0
	light.area_size = size
	light.area_range = reach
	light.area_attenuation = 0.4 if upward else 1.0
	light.light_color = color
	light.light_energy = energy
	light.light_size = 0.08
	light.light_specular = 1.0
	light.light_volumetric_fog_energy = 0.15 if upward else 0.45
	light.shadow_opacity = 0.8
	light.set_meta("visible_source", source)
	light.set_meta("fixture_face", face)
	light.set_meta("fixture_upward", upward)
	parent.add_child(light)
	light.set_meta("fixture_emitter", light.get_path_to(lens))
	GraphicsQuality.configure_practical_light(light, shadow_tier)
	return light

static func suspended_strip(scene: ChunkSceneWriter, at: Vector3,
		ceiling: float, body_size: Vector3, lens_size: Vector3,
		trim: Material, material: StandardMaterial3D, dead: bool,
		color: Color, down_energy: float, up_energy: float,
		reach: float, shadow_tier: int, source: String, up_reach := 9.0) -> Array[Light3D]:
	var fixture := Node3D.new()
	fixture.name = "SuspendedFixture"
	fixture.position = Vector3(at.x, ceiling - 0.48, at.z)
	fixture.set_meta("practical_fixture", source)
	scene.add_node(fixture)
	var body := scene.model_box(fixture,Vector3(0,-0.06,0),body_size,trim)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lower := scene.model_box(fixture,Vector3(0,-0.12,0),lens_size,material)
	lower.name = "LowerDiffuser"
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var upper_size := Vector3(lens_size.x,0.05,lens_size.z)
	var upper_y := -0.06+body_size.y*0.5+upper_size.y*0.5
	var upper := scene.model_box(fixture,Vector3(0,upper_y,0),upper_size,material)
	upper.name = "UpperDiffuser"
	upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var upper_face := upper_y+upper_size.y*0.5
	for sign_value in [-1.0,1.0]:
		var stem := Vector3(0,(upper_face+0.48)*0.5,0)
		if body_size.x > body_size.z: stem.x = sign_value*body_size.x*0.32
		else: stem.z = sign_value*body_size.z*0.32
		scene.model_box(fixture,stem,Vector3(0.018,0.48-upper_face,0.018),trim)
	var lights: Array[Light3D] = []
	if dead: return lights
	var size := Vector2(lens_size.x,lens_size.z)
	lights.append(rectangular(fixture,lower,size,Vector3(0,-0.12-lens_size.y*0.5,0),
		false,color,down_energy,reach,shadow_tier,source))
	lights.append(rectangular(fixture,upper,size,Vector3(0,upper_face,0),
		true,color,up_energy,up_reach,4,source))
	return lights

static func ballast(scene: ChunkSceneWriter, lights: Array[Light3D],
		material: StandardMaterial3D, rng_seed: int, at: Vector3) -> BloomFixtureFlicker:
	var controller := BALLAST.new()
	controller.lights = lights
	controller.mats = [material]
	controller.rng_seed = rng_seed
	var buzz := AudioStreamPlayer3D.new()
	buzz.stream = SoundBank.buzz()
	buzz.unit_size = 3.0
	buzz.max_distance = 15.0
	buzz.volume_db = -26.0
	buzz.bus = SoundBank.HALL_BUS
	buzz.autoplay = true
	buzz.position = at
	scene.add_node(buzz)
	controller.buzz = buzz
	scene.add_node(controller)
	return controller


## Area shadows use a paraboloid projection. A room-sized two-triangle wall
## can miss the blocker entirely; use metre-sized faces without adding draws,
## moving the surface, or changing its collision/UVs. Imported meshes are kept.
static func prepare_shadow_mesh(instance: MeshInstance3D) -> void:
	if not instance.mesh is BoxMesh and not instance.mesh is PlaneMesh: return
	if instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return
	var basis := instance.basis
	var ancestor := instance.get_parent()
	while ancestor is Node3D:
		basis = ancestor.basis*basis
		ancestor = ancestor.get_parent()
	var size := instance.mesh.get_aabb().size*basis.get_scale().abs()
	var segments := Vector3i(maxi(0,ceili(size.x)-1),maxi(0,ceili(size.y)-1),maxi(0,ceili(size.z)-1))
	if segments == Vector3i.ZERO: return
	var key := str(instance.mesh.get_rid())+str(segments)
	if not _shadow_meshes.has(key):
		var mesh := instance.mesh.duplicate()
		if mesh is BoxMesh:
			mesh.subdivide_width = maxi(mesh.subdivide_width,segments.x)
			mesh.subdivide_height = maxi(mesh.subdivide_height,segments.y)
			mesh.subdivide_depth = maxi(mesh.subdivide_depth,segments.z)
		else:
			mesh.subdivide_width = maxi(mesh.subdivide_width,segments.x if mesh.orientation!=PlaneMesh.FACE_X else segments.z)
			mesh.subdivide_depth = maxi(mesh.subdivide_depth,segments.z if mesh.orientation==PlaneMesh.FACE_Y else segments.y)
		if _shadow_meshes.size()>=128: _shadow_meshes.erase(_shadow_meshes.keys()[0])
		_shadow_meshes[key] = mesh
	instance.mesh = _shadow_meshes[key]
