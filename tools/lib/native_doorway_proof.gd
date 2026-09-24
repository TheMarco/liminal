extends Node3D
## Native doorway visual; the level's existing doorway owns stable topology. A continuous native
## wall develops an organic tear; its rim resolves into the native casing.
## Stable open state uses the actual builder's meshes and collision unchanged.
const WIDTH := 3.2
const TOP := Chunk.DOOR_TOP
const HALF_DEPTH := Chunk.T
const SEGMENTS := 192
const SPARK_COUNT := 288
const WISP_COUNT := 56
const TRANSITION_SECONDS := 0.9
const HOT_BURST_INTERVAL := 0.12
var phase := 0.0
var _collision_phase := -1.0
var chunks: Array[Chunk] = []
var chunk_dirs: Array[int] = []
var doorway_width := WIDTH
var wall_depth := HALF_DEPTH
var has_native_closed := false
var wall_left := 6.0
var wall_right := 6.0
var wall: MeshInstance3D
var wall_far: MeshInstance3D
var rim: MeshInstance3D
var rim_far: MeshInstance3D
var closed: MeshInstance3D
var closed_far: MeshInstance3D
var body: StaticBody3D
var collider: CollisionShape3D
var closed_shape: BoxShape3D
var rim_material: Material
var wall_material: Material
var far_material: Material
var sparks: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var veil: MeshInstance3D
var soft_edge: MeshInstance3D
var soft_edge_material: ShaderMaterial
var hot_fragments: Node3D
var _next_hot_burst := 0.0
var _hot_burst := 0
var mist_material: ShaderMaterial
var veil_material: ShaderMaterial
var magic_clock := 0.0
var opening := true
var magic_enabled := false
var soft_deformation := true
var _half := Vector2.ONE
var _magic_amount := 0.0
var height := 3.0
var opening_top := TOP
var pool_profile: Array[Vector2] = []
var _wall_vertices := PackedVector3Array()
var _wall_normals := PackedVector3Array()
var _wall_near_vertices := PackedVector3Array()
var _wall_near_normals := PackedVector3Array()
var _wall_far_vertices := PackedVector3Array()
var _wall_far_normals := PackedVector3Array()
var _rim_vertices := PackedVector3Array()
var _rim_normals := PackedVector3Array()
var _rim_near_vertices := PackedVector3Array()
var _rim_near_normals := PackedVector3Array()
var _rim_far_vertices := PackedVector3Array()
var _rim_far_normals := PackedVector3Array()

func setup(left: Chunk, right: Chunk, left_dir := 2, initial_phase := 0.0,
		opening_width := WIDTH, opening_along := 6.0) -> void:
	chunks.clear()
	chunk_dirs.clear()
	for item in [{"chunk": left, "dir": left_dir},
			{"chunk": right, "dir": WorldGen.OPP[left_dir]}]:
		var chunk: Chunk = item["chunk"]
		var dir: int = item["dir"]
		if not chunk.native_doorway_site(dir).is_empty():
			chunks.append(chunk)
			chunk_dirs.append(dir)
	doorway_width = opening_width
	wall_left = 12.0 - opening_along if left_dir == 0 else opening_along
	wall_right = 12.0 - wall_left
	# Each side can have a different native ceiling datum. The wall must seal
	# the taller side; the lower ceiling simply meets it as it normally would.
	var near_site: Dictionary = left.native_doorway_site(left_dir)
	var far_site: Dictionary = right.native_doorway_site(WorldGen.OPP[left_dir])
	wall_depth = float(near_site.get("half_depth", HALF_DEPTH))
	has_native_closed = not near_site.get("closed_nodes", []).is_empty() \
		or not far_site.get("closed_nodes", []).is_empty()
	var floor_y: float = near_site.get("floor", 0.0)
	height = maxf(left.ceil_h, right.ceil_h) - floor_y
	opening_top = float(near_site.get("head", TOP)) - floor_y
	pool_profile.clear()
	if left.theme == 9:
		var profile: Array[Vector2]
		if WorldGen.pool_doorway_kind(left.wseed, left.cell, left_dir) \
				== WorldGen.POOL_OPENING_ARCH:
			profile = PoolOpeningMesh.arched_door_profile(doorway_width,
				float(near_site["head"]), clampf(doorway_width * 0.28, 0.95, 1.35), 18)
		else:
			profile = PoolOpeningMesh.rounded_door_profile(doorway_width,
				float(near_site["head"]), 0.52, 9)
		pool_profile.append(Vector2(-doorway_width * 0.5, 0.0))
		pool_profile.append(Vector2(doorway_width * 0.5, 0.0))
		for index in range(profile.size() - 1, -1, -1):
			pool_profile.append(profile[index] - Vector2(0.0, floor_y))
	var material: Material = near_site.get("material", left._wall_material())
	var opposite_material: Material = far_site.get("material", material)
	wall = MeshInstance3D.new()
	wall_material = _magic_material(material) if material is ShaderMaterial else material
	wall.material_override = wall_material
	add_child(wall)
	wall_far = MeshInstance3D.new()
	far_material = _magic_material(opposite_material) if opposite_material is ShaderMaterial \
		else opposite_material
	wall_far.material_override = far_material
	add_child(wall_far)
	rim = MeshInstance3D.new()
	rim_material = material
	if left.theme == 1 and material is ShaderMaterial:
		rim_material = material.duplicate()
		var shader := Shader.new()
		shader.code = material.shader.code.replace("uniform float ceil_h", "uniform float casing_amount = 0.0;\nuniform vec4 casing_color : source_color;\nuniform float ceil_h") \
			.replace("ALBEDO = c;", "ALBEDO = mix(c, casing_color.rgb, casing_amount);") \
			.replace("ROUGHNESS = 0.42;", "ROUGHNESS = mix(0.42, 0.5, casing_amount);") \
			.replace("SPECULAR = 0.35;", "SPECULAR = mix(0.35, 0.5, casing_amount);")
		rim_material.shader = shader
		rim_material = _magic_material(rim_material)
		(rim_material as ShaderMaterial).set_shader_parameter("casing_color", Mats.paint_white().albedo_color)
	rim.material_override = rim_material
	add_child(rim)
	rim_far = MeshInstance3D.new()
	rim_far.material_override = far_material
	add_child(rim_far)
	closed = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12, height, wall_depth)
	closed.mesh = box
	closed.position = Vector3((wall_right-wall_left)*0.5, height*0.5, -wall_depth*0.5)
	closed.material_override = material
	add_child(closed)
	closed_far = MeshInstance3D.new()
	closed_far.mesh = box
	closed_far.position = Vector3((wall_right-wall_left)*0.5, height*0.5, wall_depth*0.5)
	closed_far.material_override = opposite_material
	add_child(closed_far)
	# Moving contours stay out of static GI caches. The stable solid wall can
	# contribute to SDFGI dynamically, so its held state inherits room bounce.
	for mesh in [wall, wall_far, rim, rim_far, closed, closed_far]:
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC \
			if mesh == closed or mesh == closed_far else GeometryInstance3D.GI_MODE_DISABLED
	body = StaticBody3D.new()
	add_child(body)
	collider = CollisionShape3D.new()
	body.add_child(collider)
	closed_shape = BoxShape3D.new()
	closed_shape.size = Vector3(12, height, wall_depth * 2)
	sparks = MultiMeshInstance3D.new()
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.instance_count = SPARK_COUNT
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055,0.055)
	instances.mesh = quad
	sparks.multimesh = instances
	var spark_material := ShaderMaterial.new()
	spark_material.shader = preload("res://tools/lib/doorway_sparks.gdshader")
	sparks.material_override = spark_material
	add_child(sparks)
	veil = MeshInstance3D.new()
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	veil.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	veil_material = ShaderMaterial.new()
	veil_material.shader = preload("res://tools/lib/doorway_mist.gdshader")
	veil_material.set_shader_parameter("membrane",true)
	veil.material_override = veil_material
	add_child(veil)
	smoke = MultiMeshInstance3D.new()
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mist_instances := MultiMesh.new()
	mist_instances.transform_format = MultiMesh.TRANSFORM_3D
	mist_instances.use_colors = true
	mist_instances.use_custom_data = true
	mist_instances.instance_count = WISP_COUNT
	var mist_quad := QuadMesh.new()
	mist_quad.size = Vector2(1.05,1.05)
	mist_instances.mesh = mist_quad
	smoke.multimesh = mist_instances
	mist_material = ShaderMaterial.new()
	mist_material.shader = veil_material.shader
	smoke.material_override = mist_material
	add_child(smoke)
	# Transparent edge-only defocus, in front of both wall faces. Ordinary
	# depth testing preserves foreground objects; smoke renders over it.
	soft_edge = MeshInstance3D.new()
	soft_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	soft_edge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	soft_edge_material = ShaderMaterial.new()
	soft_edge_material.shader = preload("res://tools/lib/doorway_soft_edge.gdshader")
	soft_edge_material.render_priority = -10
	soft_edge.material_override = soft_edge_material
	var edge_vertices := PackedVector3Array()
	var edge_normals := PackedVector3Array()
	var edge_half_width := minf(6.0,maxf(3.0,doorway_width*0.5+0.7))
	for side in [-1.0,1.0]:
		var a := Vector3(-edge_half_width,0,side*0.235)
		var b := Vector3(edge_half_width,0,side*0.235)
		var c := Vector3(edge_half_width,height,side*0.235)
		var d := Vector3(-edge_half_width,height,side*0.235)
		for p in ([a,c,b,a,d,c] if side > 0 else [a,b,c,a,c,d]):
			edge_vertices.append(p)
			edge_normals.append(Vector3(0,0,side))
	soft_edge.mesh = _mesh(edge_vertices,edge_normals)
	add_child(soft_edge)
	hot_fragments = Node3D.new()
	hot_fragments.name = "DoorwayBurnFragments"
	add_child(hot_fragments)
	pose(initial_phase)

func _magic_material(source: ShaderMaterial) -> ShaderMaterial:
	var material: ShaderMaterial = source.duplicate()
	var shader := Shader.new()
	shader.code = source.shader.code.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://tools/lib/doorway_magic.gdshaderinc\"") \
		.replace("void vertex() {", "void vertex() {\n magic_local = VERTEX;") \
		.replace("SPECULAR =", "vec4 magic = doorway_magic(magic_local);\n ALBEDO *= 1.0+magic.a;\n EMISSION = magic.rgb;\n SPECULAR =")
	material.shader = shader
	return material

func advance_magic(dt: float) -> void:
	magic_clock += dt
	for material in [wall_material,far_material,rim_material,soft_edge_material]:
		if material is ShaderMaterial:
			material.set_shader_parameter("magic_clock",magic_clock if opening else -magic_clock)
			material.set_shader_parameter("magic_amount",_magic_amount)
	# The cut itself inherits the wall/trim finish, never an emissive outline.
	if rim_material is ShaderMaterial:
		rim_material.set_shader_parameter("magic_amount",0.0)
	# Independent boundary blending: it must not re-enable magical layers.
	var soft_only := soft_deformation and not magic_enabled
	var blur_fade_start := 0.75 if not pool_profile.is_empty() else 0.92
	var blur_fade_end := 0.90 if not pool_profile.is_empty() else 1.0
	var edge_amount := smoothstep(0.0,0.08,phase) \
		* (1.0-smoothstep(blur_fade_start,blur_fade_end,phase)) \
		if soft_only else _magic_amount
	soft_edge_material.set_shader_parameter("magic_amount",edge_amount)
	soft_edge_material.set_shader_parameter("edge_core",0.10 if soft_only else 0.025)
	soft_edge_material.set_shader_parameter("edge_width",0.55 if soft_only else 0.24)
	soft_edge_material.set_shader_parameter("blur_radius",28.0 if soft_only else 7.0)
	soft_edge_material.set_shader_parameter("edge_opacity",1.0 if soft_only else 0.96)
	if sparks == null: return
	sparks.visible = _magic_amount > 0.001
	smoke.visible = sparks.visible
	veil.visible = sparks.visible and phase > 0.0 and phase < 1.0
	soft_edge.visible = edge_amount > 0.001 and phase > 0.0 and phase < 1.0
	# Closing leaves already-emitted shards alive to cool and dissolve using
	# their own lifetime. Do not cut the whole white cloud on the final pose.
	var keep_closing_tail := magic_enabled and not opening and hot_fragments.get_child_count() > 0
	hot_fragments.visible = sparks.visible or keep_closing_tail
	for material in [mist_material,veil_material]:
		material.set_shader_parameter("clock",magic_clock if opening else -magic_clock)
		material.set_shader_parameter("strength",_magic_amount)
	if not sparks.visible:
		if not keep_closing_tail:
			for fragment in hot_fragments.get_children(): fragment.queue_free()
		_next_hot_burst = magic_clock
		return
	if _magic_amount > 0.08 and magic_clock >= _next_hot_burst:
		_emit_hot_fragments()
		_next_hot_burst = magic_clock+HOT_BURST_INTERVAL
	for i in sparks.multimesh.instance_count:
		# Independent seeds avoid evenly spaced beads chasing one another.
		var life := fposmod(magic_clock*(0.23+_particle_random(i,1)*0.24)+_particle_random(i,2),1.0)
		var angle := _particle_random(i,3)*TAU+magic_clock*(0.06+_particle_random(i,4)*0.10)
		var ray := Vector2(cos(angle),sin(angle))
		var radius := _aperture_radius(ray,_half)
		var drift := pow(1.0-life if opening else life,2.0)
		var curl := Vector2(-ray.y,ray.x)*sin(life*PI)*0.16
		var p := Vector2(0,opening_top/2)+ray*(radius+0.02+0.85*drift)+curl
		var side := -1.0 if i%2 == 0 else 1.0
		var at := Vector3(p.x,maxf(0.035,p.y),side*(0.23+drift*0.80))
		sparks.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,at))
		var color := Color(0.78,0.82,0.76).lerp(Color(0.87,0.84,0.77),float(i%7)/6.0)
		color.a = pow(sin(life*PI),2.0)*_magic_amount*0.65
		sparks.multimesh.set_instance_color(i,color)
		# Mix fine airborne dust with glints and occasional elongated embers.
		var size := (0.55+float(i%11)/10.0*1.25)*(0.55 if i%5==0 else 1.0)
		sparks.multimesh.set_instance_custom_data(i,Color(size,size*(2.8 if i%9==0 else 1.0),1.7+float(i%5)*0.55,0))
	for i in smoke.multimesh.instance_count:
		var life := fposmod(magic_clock*(0.13+_particle_random(i,5)*0.09)+_particle_random(i,6),1.0)
		var drift := life if opening else 1.0-life
		var angle := _particle_random(i,7)*TAU+magic_clock*0.10+sin(life*PI)*0.22
		var ray := Vector2(cos(angle),sin(angle))
		var radius := _aperture_radius(ray,_half)
		var p := Vector2(0,opening_top/2)+ray*(radius+drift*0.45)
		var side := -1.0 if i%2==0 else 1.0
		var at := Vector3(p.x,maxf(0.1,p.y+drift*0.45),side*(0.20+drift*0.65))
		smoke.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,at))
		smoke.multimesh.set_instance_color(i,Color(1,1,1,pow(sin(life*PI),2.0)*0.8))
		smoke.multimesh.set_instance_custom_data(i,Color(0.75+drift*0.95,1.0+drift*0.85,_particle_random(i,8),0))

func _emit_hot_fragments() -> void:
	# Reuse the ghost death's actual faceted particles and opaque HDR shader;
	# no changes to monster materials, death behaviour or shared resources.
	var reduced := GameSettings.flashing_reduced()
	var count := 112 if reduced else 320
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in count:
		var seed_index := i+_hot_burst*count
		var angle := _particle_random(seed_index,11)*TAU
		var ray := Vector2(cos(angle),sin(angle))
		var p := Vector2(0,opening_top/2)+ray*_aperture_radius(ray,_half)
		# Never clamp emitted fragments into a horizontal line on the carpet.
		if p.y < 0.06 or p.y > height-0.08: continue
		var side := -1.0 if i%2 == 0 else 1.0
		points.append(Vector3(p.x,p.y,side*(0.23+_particle_random(seed_index,12)*0.025)))
		normals.append(Vector3(ray.x*0.45,ray.y*0.25,side).normalized())
	_hot_burst += 1
	if points.is_empty(): return
	var fragments := ShadowBurnFragments.new()
	hot_fragments.add_child(fragments)
	var peak := 12.0
	if HdrOutput.is_active(get_window()):
		peak = clampf(HdrOutput.output_max_linear_value(get_window())*5.0,12.0,32.0)
	fragments.configure({"points":points,"normals":normals},
		minf(1.45,peak) if reduced else peak*_magic_amount)

func _particle_random(index: int, salt: int) -> float:
	return fposmod(sin(float(index)*127.1+float(salt)*311.7)*43758.5453,1.0)

func pose(value: float, update_collision := true) -> void:
	phase = clampf(value, 0.0, 1.0)
	# Let the wall web, dust and smoke recede over the last ~0.4 s of closing,
	# even with the faster geometry. Detached hot shards finish independently.
	var fade_start := 0.42 if not opening else 0.14
	_magic_amount = smoothstep(0.0,fade_start,phase)*(1.0-smoothstep(0.78,1.0,phase)) if magic_enabled else 0.0
	if GameSettings.flashing_reduced(): _magic_amount *= 0.3
	for index in chunks.size():
		chunks[index].show_native_doorway(chunk_dirs[index], phase >= 1.0, false,
			phase > 0.0 and phase < 1.0)
	closed.visible = phase <= 0.0 and not has_native_closed
	closed_far.visible = closed.visible
	wall.visible = phase > 0.0 and phase < 1.0
	wall_far.visible = wall.visible
	rim.visible = wall.visible
	rim_far.visible = rim.visible
	if phase >= 1.0:
		advance_magic(0.0)
		if update_collision: sync_collision()
		return
	if phase <= 0.0:
		advance_magic(0.0)
		if update_collision: sync_collision()
		return
	_wall_vertices.clear()
	_wall_normals.clear()
	_wall_near_vertices.clear()
	_wall_near_normals.clear()
	_wall_far_vertices.clear()
	_wall_far_normals.clear()
	_rim_vertices.clear()
	_rim_normals.clear()
	_rim_near_vertices.clear()
	_rim_near_normals.clear()
	_rim_far_vertices.clear()
	_rim_far_normals.clear()
	var u := smoothstep(0.0, 1.0, phase)
	# Reach the carpet before the rim becomes painted casing: no lingering
	# window sill which suddenly disappears on the final frame.
	var half := Vector2((doorway_width/2-0.08)*pow(u, 0.75), opening_top/2*smoothstep(0.0,0.62,phase))
	var center := Vector2(0, opening_top/2)
	_half = half
	for material in [wall_material,far_material,rim_material,soft_edge_material]:
		if material is ShaderMaterial:
			material.set_shader_parameter("magic_half",half)
			material.set_shader_parameter("magic_phase",phase)
			material.set_shader_parameter("magic_center_y",opening_top*0.5)
	var emergence := smoothstep(0.50, 0.95, u)
	var trim_half := half + Vector2(0.16, 0.14)*emergence
	var depth := wall_depth + 0.06*emergence
	if not chunks.is_empty() and chunks[0].theme == 1 and rim_material is ShaderMaterial:
		(rim_material as ShaderMaterial).set_shader_parameter("casing_amount", smoothstep(0.88, 1.0, phase))
	var angles: Array[float] = []
	for i in SEGMENTS: angles.append(TAU*float(i)/SEGMENTS)
	# Include exact square corners: angular sampling alone would bevel them.
	for corner in [Vector2(-wall_left,0), Vector2(wall_right,0),
			Vector2(-wall_left,height), Vector2(wall_right,height)]:
		angles.append(fposmod((corner-center).angle(), TAU))
	for extent in [half, trim_half]:
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]: angles.append(fposmod(Vector2(sx*extent.x,sy*extent.y).angle(), TAU))
	angles.sort()
	var inner: Array[Vector2] = []
	var trim: Array[Vector2] = []
	var outer: Array[Vector2] = []
	for angle in angles:
		var ray := Vector2(cos(angle), sin(angle))
		var floor_limit := center.y/maxf(-ray.y,0.000001) if ray.y < 0.0 else INF
		var p := center + ray*minf(_aperture_radius(ray,half),floor_limit)
		var q := center + ray*minf(_aperture_radius(ray,trim_half),floor_limit)
		p.y = maxf(0.0,p.y)
		q.y = maxf(0.0,q.y)
		inner.append(p)
		trim.append(q)
		var distance := (wall_right if ray.x > 0.0 else wall_left) \
			/maxf(absf(ray.x), 0.000001)
		distance = minf(distance, ((height-center.y) if ray.y > 0 else center.y)/maxf(absf(ray.y), 0.000001))
		outer.append(center+ray*distance)
	for i in angles.size():
		var j := (i+1)%angles.size()
		for side in [-1.0, 1.0]:
			var normal := Vector3(0,0,side)
			_quad(outer[i], outer[j], trim[j], trim[i], wall_depth*side, normal, false)
			_quad(trim[i], trim[j], inner[j], inner[i], depth*side, normal, true)
			# Join raised casing to the wall; no floating border or coplanar skin.
			# The doorway has no threshold. Once this contour reaches the
			# carpet, a casing return here would lie flat across the floor.
			if emergence > 0.0 and (trim[i].y > 0.00001 or trim[j].y > 0.00001):
				var n := Vector3(trim[j].y-trim[i].y, trim[i].x-trim[j].x, 0).normalized()
				_face(_at(trim[i],wall_depth*side), _at(trim[j],wall_depth*side), _at(trim[j],depth*side), _at(trim[i],depth*side), n, true)
		if inner[i].y > 0.00001 or inner[j].y > 0.00001:
			var n := Vector3(inner[i].y-inner[j].y, inner[j].x-inner[i].x, 0).normalized()
			_face(_at(inner[i],-depth), _at(inner[j],-depth), _at(inner[j],depth), _at(inner[i],depth), n, true)
	wall.mesh = _mesh(_wall_near_vertices, _wall_near_normals)
	wall_far.mesh = _mesh(_wall_far_vertices, _wall_far_normals)
	rim.mesh = _mesh(_rim_near_vertices, _rim_near_normals)
	rim_far.mesh = _mesh(_rim_far_vertices, _rim_far_normals)
	var membrane_vertices := PackedVector3Array()
	var membrane_normals := PackedVector3Array()
	for i in inner.size():
		for p in [center,inner[(i+1)%inner.size()],inner[i]]:
			membrane_vertices.append(_at(p,0.0))
			membrane_normals.append(Vector3.FORWARD)
	veil.mesh = _mesh(membrane_vertices,membrane_normals)
	# Newly evaluated contour is also the particle emitter, never a stale rim.
	advance_magic(0.0)
	if update_collision: sync_collision()

func sync_collision() -> bool:
	# Render poses run at display rate. Physics consumes the latest completed
	# mesh once per tick; no extra geometry evaluation or idle shape rebuilds.
	if _collision_phase == phase: return false
	_collision_phase = phase
	for index in chunks.size():
		var site: Dictionary = chunks[index].native_doorway_site(chunk_dirs[index])
		for shape: CollisionShape3D in site["shapes"]:
			shape.disabled = phase < 1.0
		for shape: CollisionShape3D in site.get("closed_shapes", []):
			shape.disabled = phase > 0.0
	collider.disabled = phase >= 1.0 or (phase <= 0.0 and has_native_closed)
	if phase >= 1.0: return true
	if phase <= 0.0 and has_native_closed: return true
	collider.position = Vector3((wall_right-wall_left)*0.5, height*0.5, 0.0) \
		if phase <= 0.0 else Vector3.ZERO
	if phase <= 0.0:
		collider.shape = closed_shape
		return true
	var faces := _wall_vertices.duplicate()
	faces.append_array(_rim_vertices)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	return true

func _aperture_radius(ray: Vector2, half: Vector2) -> float:
	# Same shape evaluator as the shader. Low-frequency, asymmetric lobes,
	# not noise-jitter or a scaled rounded rectangle. Native corners appear last.
	var extent := half.max(Vector2.ONE*0.00001)
	var ellipse := 1.0/(ray/extent).length()
	var rectangle := minf(extent.x/maxf(absf(ray.x),0.000001),extent.y/maxf(absf(ray.y),0.000001))
	var angle := ray.angle()
	var lobes := 0.13*sin(angle*3.0+phase*1.3)+0.065*sin(angle*5.0-phase*1.7)+0.035*cos(angle*7.0+0.8)
	# Stable chipped plaster and narrow outward fissures. Integer angular
	# frequencies join at the seam; no clock/noise reseeding makes them crawl.
	var chips := (absf(sin(angle*13.0+0.8*sin(angle*3.0)))-0.5)*0.14
	var fissures := pow(maxf(0.0,sin(angle*17.0+1.7*sin(angle*5.0))),6.0)*0.16
	var fractured := ellipse*(1.0+lobes)+(chips+fissures)*smoothstep(0.0,0.28,phase)
	var finished := _pool_aperture_radius(ray) if not pool_profile.is_empty() else rectangle
	var radius := lerpf(maxf(0.00001,fractured),finished,smoothstep(0.70,1.0,phase))
	# An aperture that only approaches floor height leaves a thin horizontal
	# reveal (a sill). Extend the lower contour BELOW the carpet instead, well
	# before the finished casing appears; pose clips it at the floor plane.
	# The upper organic contour is unchanged, in either animation direction.
	var below_floor := minf(extent.x/maxf(absf(ray.x),0.000001),
		(opening_top/2+0.18)/maxf(-ray.y,0.000001))
	var floor_release := smoothstep(0.40,0.68,phase)*smoothstep(0.0,0.55,-ray.y)
	return lerpf(radius,below_floor,floor_release)


func _pool_aperture_radius(ray: Vector2) -> float:
	var centre := Vector2(0.0, opening_top * 0.5)
	var nearest := INF
	for index in pool_profile.size():
		var from := pool_profile[index] - centre
		var edge := pool_profile[(index + 1) % pool_profile.size()] \
			- pool_profile[index]
		var denominator := ray.cross(edge)
		if absf(denominator) < 0.000001: continue
		var distance := from.cross(edge) / denominator
		var along := from.cross(ray) / denominator
		if distance > 0.0 and along >= -0.0001 and along <= 1.0001:
			nearest = minf(nearest, distance)
	return nearest if is_finite(nearest) else 0.00001

func _at(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x,p.y,z)

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, z: float, n: Vector3, casing: bool) -> void:
	_face(_at(a,z),_at(b,z),_at(c,z),_at(d,z),n,casing)

func _face(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3,casing: bool) -> void:
	_triangle(a,b,c,n,casing)
	_triangle(a,c,d,n,casing)

func _triangle(a: Vector3,b: Vector3,c: Vector3,n: Vector3,casing: bool) -> void:
	var cross_value := (b-a).cross(c-a)
	if cross_value.length_squared() < 0.0000000001: return
	# Godot front faces use clockwise winding.
	var points := [a,c,b] if cross_value.dot(n) > 0 else [a,b,c]
	for p in points:
		if casing:
			_rim_vertices.append(p)
			_rim_normals.append(n)
			if n.z > 0.5:
				_rim_far_vertices.append(p)
				_rim_far_normals.append(n)
			else:
				_rim_near_vertices.append(p)
				_rim_near_normals.append(n)
		else:
			_wall_vertices.append(p)
			_wall_normals.append(n)
			if n.z > 0.5:
				_wall_far_vertices.append(p)
				_wall_far_normals.append(n)
			else:
				_wall_near_vertices.append(p)
				_wall_near_normals.append(n)

func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var uvs := PackedVector2Array()
	for vertex in vertices:
		uvs.append(Vector2((vertex.x+wall_left)/12.0,
			vertex.y/maxf(height,0.001)))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
