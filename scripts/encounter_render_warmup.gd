extends Node
## A small, unpresented viewport draws the floor's encounter resources during
## startup/the opaque transition. Loading a GLB alone never visits its runtime
## materials, posed bounds, morph variants or screen-reading canvas shader.
const Surface := preload("res://scripts/environment_breath_surface.gd")
const FIXTURE_LIGHT_POSITION := Vector3(0, 4, 3)
const DoorwaySurface := preload("res://scripts/native_doorway_surface.gd")
const Aftershock := preload("res://scripts/reality_aftershock.gd")
const PowerSurfaces := preload("res://scripts/blackout_surfaces.gd")
const PowerEnvironment := preload("res://scripts/blackout_environment.gd")
signal completed
var finished := false
var model_indices: Array[int] = []
var material_count := 0
var blackout_mesh_count := 0
var blackout_label_count := 0
var _samples: Node3D
var _lights: Node3D
var _environment: Environment
var _torch: SpotLight3D
var _power_surfaces := PowerSurfaces.new()
var _power_environment := PowerEnvironment.new()
var _blackout_materials: Array = []
var _view: SubViewport
var _covered_source: SubViewport
var _retained: Node
var _figures: Array[ShadowFigure] = []
var _draw_times := {}

func _exit_tree() -> void:
	_resume_covered_source()
	if is_instance_valid(_retained):
		_retained.free()
		_retained = null

func prepare(source: Viewport, theme: int, rooms: Node3D, live_power_pass := false,
		wander_only := false, realm_theme := -1) -> void:
	var started := Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless":
		finished = true
		completed.emit()
		return
	if live_power_pass:
		# Submit the real arrival, then hold that covered frame while only the
		# sample tray changes. Drawing both worlds re-runs the full floor's
		# shadows, GI and post-processing on every encounter warmup frame.
		await _draw_state("arrival")
		if source is SubViewport and source.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_covered_source = source
			_covered_source.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view = SubViewport.new()
	_view.size = Vector2i(256, 128)
	_view.own_world_3d = true
	add_child(_view)
	# Match formats/features: a different MSAA level can itself invalidate the
	# engine's pipeline precompilation assumptions for the real world viewport.
	for feature in ["msaa_3d", "msaa_2d", "use_taa", "use_hdr_2d", "screen_space_aa",
			"positional_shadow_atlas_16_bits", "transparent_bg", "scaling_3d_mode"]:
		_view.set(feature, source.get(feature))
	# Tile resolution doesn't change shader variants; avoid a second 8K atlas.
	_view.positional_shadow_atlas_size = 1024
	GraphicsQuality.configure_shadow_atlas(_view)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var source_environment := source.find_world_3d().environment
	var source_camera := source.get_camera_3d()
	if source_camera != null and source_camera.environment != null:
		source_environment = source_camera.environment
	if source_environment != null:
		_environment = source_environment.duplicate() as Environment
		# The real arrival camera draws the lit floor during preparation. A second
		# set of SDFGI cascades for this tray of unrelated meshes is discarded
		# after a dozen frames and makes every sample change revoxelize the tray.
		_environment.sdfgi_enabled = false
		var world := WorldEnvironment.new()
		world.environment = _environment
		_view.add_child(world)
	_samples = Node3D.new()
	_view.add_child(_samples)
	_prepare_lighting(rooms)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.0
	_view.add_child(camera)
	camera.position = Vector3(0, 2.5, 12)
	camera.current = true
	_prepare_torch(source_camera, camera)
	if theme == 6:
		var desk := Chunk.school_workstation_render_sample()
		# Straddle the fixture's shadow split so the CRT and case also cast
		# their close-up shadows during the covered draw.
		desk.position = FIXTURE_LIGHT_POSITION + Vector3(-1.5, -2.0, -0.1)
		desk.rotation.y = 0.5
		_view.add_child(desk)
	if theme == 4 or realm_theme == 4:
		_warm_airport_terminal()
	if theme in [2, 11] or realm_theme in [2, 11]:
		_warm_hallway_props(theme, realm_theme)
	var warm_water := theme in [2, 9] or realm_theme in [2, 9]
	if wander_only:
		# Wander suspends hostile figures, hallway apparitions and Descent rules.
		# Its torch, living walls and native doorways still need their first draw.
		_warm_surfaces(rooms)
		_warm_gameplay_effects(rooms, theme, warm_water, true)
		_torch.visible = true
		await _draw_state("wander")
		_finish(theme, started)
		return
	model_indices.assign(ShadowFigures.DARK_ROSTER)
	var signature: int = ShadowFigures.THEME_WALKER.get(theme, -1)
	if signature >= 0 and not model_indices.has(signature): model_indices.append(signature)
	for i in model_indices.size():
		# Draw the complete presence, including particle and fog materials.
		# Loading only ShadowWalkerVisual misses the actor's additional passes.
		var actor := ShadowFigure.new()
		actor.walker_model_index = model_indices[i]
		actor.announce = false
		actor.set_meta("render_warmup", true)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.position.x = (i - (model_indices.size() - 1) * 0.5) * 2.5
		_view.add_child(actor)
		actor.remove_from_group(&"hostile_shadow_figure")
		_figures.append(actor)
		var visual := actor._walker
		visual.disappear(0.0) # Stop the appearance tween before setting a fixed pose.
		visual.set_manifestation(1.0)
		visual.prepare_burn_cache()
	var corner_samples := Node3D.new()
	corner_samples.position = Vector3(0, 1, 5)
	_view.add_child(corner_samples)
	CornerApparitions.prepare_render_samples(corner_samples)
	_warm_surfaces(rooms)
	_warm_blackout_surfaces(rooms, live_power_pass)
	_warm_gameplay_effects(rooms, theme, warm_water)
	var effect := Aftershock.new()
	_view.add_child(effect)
	effect.set_process(false)
	effect._material.set_shader_parameter("strength", 0.25)
	effect.visible = true
	RuntimeDiagnostics.mark("encounter_warmup_prepared", {
		"level": theme, "models": model_indices, "materials": material_count,
		"blackout_meshes": blackout_mesh_count, "blackout_labels": blackout_label_count,
		"setup_ms": (Time.get_ticks_usec() - started) / 1000.0 - float(_draw_times.get("arrival", 0.0))})
	await _draw_state("lit")
	# Exercise the production overlays on isolated samples, never live rooms.
	var blackout_variants := {}
	_power_surfaces.apply(_samples, blackout_variants)
	_power_environment.apply(_environment)
	_lights.visible = false
	await _draw_state("blackout")
	_torch.visible = true
	await _draw_state("torch")
	_blackout_materials = blackout_variants.values()
	_power_surfaces.restore()
	_power_environment.restore()
	_lights.visible = true
	await _draw_state("restored")
	# Burn fragments use a separate MultiMesh vertex layout and shader. Keep
	# its owner alive just like the body materials after the temporary draw.
	# One actor covers the shared fragment format for every roster model.
	if not _figures.is_empty():
		var actor := _figures[0]
		actor._ignite(false, false)
		if is_instance_valid(actor._burn_particles):
			actor._burn_particles.set_process(false)
		actor._flash.light_energy = 1.0
	# Fragments and the mutation samples occupy separate meshes. Exercise
	# both layouts in the same submission.
	_warm_mutation_reveal()
	await _draw_state("burn_and_reveal")
	# The live effect shares the cached materials and meshes. Its temporary
	# bodies and particle emitter can go away with the loading scene.
	corner_samples.free()
	_finish(theme, started)


func _finish(theme: int, started: int) -> void:
	finished = true
	_release_view()
	_resume_covered_source()
	process_mode = Node.PROCESS_MODE_DISABLED
	RuntimeDiagnostics.mark("encounter_warmup_finished", {"level": theme,
		"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0, "draw_ms": _draw_times})
	completed.emit()

func _resume_covered_source() -> void:
	if is_instance_valid(_covered_source):
		_covered_source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_covered_source = null

func _release_view() -> void:
	# Keep only the resource owners, outside the scene/physics tree. Dropping
	# their last references can discard prepared pipelines. The temporary world,
	# SDFGI cascades, shadow atlas and render buffers must not live all floor.
	# This detached tree is explicitly freed by _exit_tree on floor replacement.
	_retained = Node.new()
	_lights.free()
	# The authored beam and dust own resources too; freeing the camera must
	# not discard their prepared pipelines before the first flashlight use.
	_torch.get_parent().remove_child(_torch)
	_retained.add_child(_torch)
	for child in _view.get_children():
		if child is Camera3D or child is WorldEnvironment:
			child.free()
		else:
			_view.remove_child(child)
			_retained.add_child(child)
	_view.free()
	_view = null
	_environment = null

func _draw_state(phase: String) -> void:
	# Two draws include deferred surface uploads and the screen-copy mip chain.
	var started := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_draw_times[phase] = (Time.get_ticks_usec() - started) / 1000.0

func _prepare_torch(source_camera: Camera3D, camera: Camera3D) -> void:
	if source_camera != null:
		for child in source_camera.get_children():
			if child is SpotLight3D and child.get_meta("visible_source", "") == "player_held_flashlight":
				_torch = child.duplicate(0) as SpotLight3D
				break
	if _torch == null:
		_torch = SpotLight3D.new()
		_torch.set_meta("visible_source", "player_held_flashlight")
		_torch.shadow_enabled = true
		_torch.spot_range = 24.0
		_torch.spot_angle = 65.0
	else:
		# The live dust script refers to its player. Draw an inert copy of its
		# actual MultiMesh/material, with no gameplay callbacks or live mutation.
		for child in _torch.find_children("*", "Node", true, false):
			child.set_script(null)
			if child is GeometryInstance3D:
				child.visible = true
				if child.top_level: child.position = Vector3(0, 2.5, 6)
	camera.add_child(_torch)
	_torch.visible = false

func _prepare_lighting(rooms: Node3D) -> void:
	_lights = Node3D.new()
	_view.add_child(_lights)
	var seen := {}
	for light in rooms.find_children("*", "Light3D", true, false):
		var key := light.get_class() + str(light.shadow_enabled)
		if light is OmniLight3D: key += str(light.omni_shadow_mode)
		if seen.has(key): continue
		seen[key] = true
		var sample := light.duplicate(0) as Light3D
		sample.set_script(null)
		for child in sample.get_children(): child.free()
		_lights.add_child(sample)
		sample.position = FIXTURE_LIGHT_POSITION
		sample.rotation = Vector3.ZERO
		sample.visible = true
		if sample is OmniLight3D: sample.omni_range = 24.0
		if sample is SpotLight3D:
			sample.spot_range = 24.0
			sample.spot_angle = 65.0
	if (GameSettings.current == null or int(GameSettings.current.get_value("reflections")) > 0) \
			and not rooms.find_children("*", "ReflectionProbe", true, false).is_empty():
		var probe := ReflectionProbe.new()
		probe.size = Vector3(24, 16, 24)
		# Exercise receiving reflections without rendering the sample tray from
		# all six directions as well as from the warmup camera.
		probe.cull_mask = 0
		_lights.add_child(probe)

func _warm_blackout_surfaces(rooms: Node3D, live_power_pass: bool) -> void:
	var seen := {}
	for node in rooms.find_children("*", "MeshInstance3D", true, false):
		var original := node as MeshInstance3D
		if original.mesh == null: continue
		# Keep actual vertex formats, GI/shadow modes and shader combinations.
		# Replacing imported meshes with boxes misses their pipeline variants.
		var key: Array = [original.gi_mode, original.cast_shadow]
		for i in original.mesh.get_surface_count():
			if original.mesh is ArrayMesh:
				key.append(original.mesh.surface_get_format(i))
			elif original.mesh is PrimitiveMesh:
				key.append([original.mesh.get_class(), original.mesh.add_uv2])
			else:
				key.append(original.mesh.get_rid())
			# The live camera covers actual powered materials under the loading
			# screen. The mutation outline/ghost still needs each vertex layout.
			if not live_power_pass:
				key.append(_material_key(original.get_active_material(i)))
		if not live_power_pass:
			key.append(_material_key(original.material_overlay))
		if seen.has(key): continue
		seen[key] = true
		var mesh := MeshInstance3D.new()
		mesh.mesh = original.mesh
		mesh.gi_mode = original.gi_mode
		mesh.cast_shadow = original.cast_shadow
		mesh.material_override = original.material_override
		mesh.material_overlay = original.material_overlay
		for i in original.mesh.get_surface_count():
			mesh.set_surface_override_material(i, original.get_surface_override_material(i))
		_samples.add_child(mesh)
		var bounds := mesh.mesh.get_aabb()
		var extent := maxf(0.01, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
		mesh.scale = Vector3.ONE * (0.65 / extent)
		mesh.position = Vector3(-7 + blackout_mesh_count % 20 * 0.7,
			-0.5 + blackout_mesh_count / 20 * 0.7, 1) - bounds.get_center() * mesh.scale
		blackout_mesh_count += 1
	# Labels have generated materials, including a separate shaded blackout
	# variant; they are not MeshInstance3D descendants and need their own pass.
	seen.clear()
	for label in rooms.find_children("*", "Label3D", true, false):
		if label.text.is_empty(): continue
		var key: Array = [label.alpha_cut, label.billboard, label.no_depth_test,
			label.fixed_size, label.double_sided, label.texture_filter, label.shaded,
			label.font, label.outline_size, label.alpha_antialiasing_mode]
		if seen.has(key): continue
		seen[key] = true
		var sample := label.duplicate(0) as Label3D
		sample.set_script(null)
		for child in sample.get_children(): child.free()
		_samples.add_child(sample)
		sample.position = Vector3(-6 + blackout_label_count * 2, 3, 2)
		sample.rotation = Vector3.ZERO
		sample.scale = Vector3.ONE
		sample.visible = true
		blackout_label_count += 1
	# An arrival can have no signs. Draw a room number in the same blackout
	# pass so switching a later cell's lettering to shaded is already prepared.
	var room_number := Label3D.new()
	room_number.text = "A-01"
	room_number.font_size = 96
	room_number.position = Vector3(-6, 3, 2) if seen.is_empty() else Vector3(-6, 4, 2)
	_samples.add_child(room_number)
	blackout_label_count += 1

func _material_key(material: Material) -> Array:
	var key: Array = []
	while material != null:
		key.append(material.shader if material is ShaderMaterial else material)
		material = material.next_pass
	return key

func _warm_mutation_reveal() -> void:
	# Use the same mesh-only snapshot and shadow modes as vanished room props.
	var ghost := DescentMutationCoordinator.new()._snapshot_visuals([_samples])
	var reveal := MutationRevealEffect.new()
	_view.add_child(reveal)
	reveal.configure({"kind": "door", "nodes": [_samples], "ghost": ghost,
		"position": Vector3(0, 0, 3), "edge": {"dir": 2, "after": {"w": 3.0}}})
	reveal.set_process(false)

## The first gate can also stream into the hidden Airport while the player
## is walking through the Office. Loading its assets doesn't exercise their
## render pipelines. Use the same covered draw for both entry paths.
func _warm_airport_terminal() -> void:
	# These samples only need a lit draw. The active floor supplies its own
	# blackout and reveal samples.
	var terminal := Node3D.new()
	_view.add_child(terminal)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var materials: Array[Material] = [
		Mats.terrazzo_photo(), Mats.airport_ceiling(), Mats.airport_wall(),
		Mats.steel(), Mats.air_panel(), Mats.airport_glass(),
		Mats.airport_carpet(), Mats.asphalt(), Mats.apron_night(),
		Mats.poster_lightbox(Chunk.POSTER_AIRPORT[0]), Mats.adbox(0),
	]
	for i in materials.size():
		_add_effect_quad(terminal, quad, materials[i], Vector3(-3.0 + i * 0.62, 4.2, 2.0))

	# Exercise the imported vertex formats with the belt and glass overrides
	# used on the moving walkway in the concourse.
	var packed := load(Chunk.AIRPORT_WALKWAY_PATH) as PackedScene
	if packed != null:
		var walkway := packed.instantiate() as Node3D
		Chunk.AIRPORT_LEVEL_BUILDER.apply_walkway_materials(walkway, 1.0)
		walkway.scale = Vector3.ONE * 0.32
		walkway.position = Vector3(0.5, 2.0, 3.0)
		walkway.rotation = Vector3(0.4, 0.3, 0.1)
		terminal.add_child(walkway)


func _warm_hallway_props(theme: int, realm_theme: int) -> void:
	# A hallway wave is these props' first draw with blend shapes. Sample the
	# source assets even when a seeded arrival has none of them in view.
	var host := Node3D.new()
	_view.add_child(host)
	if theme == 2 or realm_theme == 2:
		_warm_wave_model(host, Chunk.LIGHT_SWITCH_PATH)
		_warm_wave_model(host, Chunk.OUTLET_PATH)
	if theme == 11 or realm_theme == 11:
		# The generated canopy has ordinary position, normal, tangent and UV
		# streams. Its membrane normals are axial, so the live wave bakes UVs.
		_add_wave_prop(host, 0, Mats.bloom_growth())
		_add_wave_prop(host, 0, Surface.anchored_material(Mats.bloom_tissue()))
		_warm_wave_model(host, Chunk.BLOOM_VINES_PATH, Mats.bloom_growth())
		_warm_wave_model(host, Chunk.BRUTAL_LIGHT_PATH)


func _warm_wave_model(host: Node3D, path: String, override: Material = null) -> void:
	var packed := load(path) as PackedScene
	if packed == null: return
	var model := packed.instantiate()
	var seen := {}
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var source := node.mesh as ArrayMesh
		if source == null: continue
		for i in source.get_surface_count():
			var material := override if override != null else node.get_active_material(i)
			if material == null: continue
			var format := source.surface_get_format(i)
			var key := [format, material]
			if seen.has(key): continue
			_add_wave_prop(host, format, material)
			seen[key] = true
	model.free()


func _add_wave_prop(host: Node3D, format: int, material: Material) -> void:
	var sample := MeshInstance3D.new()
	sample.mesh = _wave_prop_mesh(format, material is ShaderMaterial)
	sample.material_override = Surface.wrap_native_shader(material) if material is ShaderMaterial else material
	var i := host.get_child_count()
	sample.position = FIXTURE_LIGHT_POSITION + Vector3(-2.0 + i % 8 * 0.6, -1.0, 0.15 + i / 8)
	sample.set_blend_shape_value(0, 0.5)
	host.add_child(sample)


func _wave_prop_mesh(format: int, wrapped: bool) -> ArrayMesh:
	# Match the production morph's vertex layout without reading an entire
	# imported mesh back from the GPU just to draw a few pixels at load time.
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	box.add_uv2 = bool(format & Mesh.ARRAY_FORMAT_TEX_UV2)
	var arrays := box.get_mesh_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if format & Mesh.ARRAY_FORMAT_COLOR:
		var colors := PackedColorArray()
		colors.resize(positions.size())
		colors.fill(Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = colors
	var flags := 0
	for channel in 4:
		var slot := Mesh.ARRAY_CUSTOM0 + channel
		var shift := Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT + channel * Mesh.ARRAY_FORMAT_CUSTOM_BITS
		var encoding := (format >> shift) & Mesh.ARRAY_FORMAT_CUSTOM_MASK
		if wrapped and channel < 2:
			var rest := positions if channel == 0 else normals
			arrays[slot] = rest.to_byte_array().to_float32_array()
			encoding = Mesh.ARRAY_CUSTOM_RGB_FLOAT
		elif format & (1 << slot):
			if encoding >= Mesh.ARRAY_CUSTOM_R_FLOAT:
				var floats := PackedFloat32Array()
				floats.resize(positions.size() * (encoding - Mesh.ARRAY_CUSTOM_R_FLOAT + 1))
				arrays[slot] = floats
			else:
				var bytes := PackedByteArray()
				bytes.resize(positions.size() * (8 if encoding == Mesh.ARRAY_CUSTOM_RGBA_HALF else 4))
				arrays[slot] = bytes
		else:
			continue
		flags |= encoding << shift
	var blend := []
	blend.resize(Mesh.ARRAY_MAX)
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
		blend[slot] = arrays[slot]
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_blend_shape("wave")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [blend], {}, flags)
	return mesh


func _warm_surfaces(rooms: Node3D) -> void:
	# Hallway waves wrap the same shaders as breathing walls, including
	# floors and props along the moving section of a corridor.
	var materials := {}
	for node in rooms.find_children("*", "MeshInstance3D", true, false):
		if not (node.mesh is BoxMesh or node.mesh is QuadMesh): continue
		var material: Material = node.material_override
		if not (material is ShaderMaterial or material is StandardMaterial3D): continue
		var key: Resource = material.shader if material is ShaderMaterial else material
		if materials.has(key): continue
		materials[key] = true
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(0.6, 0.6, 0.05)
		mesh.material_override = material
		mesh.position = Vector3(-6 + material_count % 12, 4.5 + material_count / 12, 0)
		_view.add_child(mesh)
		var face := SurfaceWear.Face.new()
		face.mesh = mesh
		face.transform = mesh.transform
		face.u = Vector3.RIGHT
		face.v = Vector3.UP
		face.normal = Vector3.BACK
		var surface := Surface.new()
		_view.add_child(surface)
		if surface.setup({"face": face, "center": mesh.position,
				"size": Vector2(0.5, 0.5), "depth": 0.1, "companions": []}, "breath"):
			surface.pose(PackedFloat32Array([0.5]))
		material_count += 1
		# Bound loading work to the floor's common architectural materials.
		if material_count >= 24: break


func _warm_gameplay_effects(rooms: Node3D, theme: int, warm_water: bool, wander_only := false) -> void:
	var host := Node3D.new()
	host.name = "GameplayEffectWarmup"
	_view.add_child(host)
	var wall_shaders: Array[ShaderMaterial] = []
	var seen_shaders := {}
	# DoorwaySurface builds its shader from the registered opening or the
	# room's wall finish. Floors, signage and furniture never supply it.
	for manager in rooms.get_children():
		if not manager is ChunkManager:
			continue
		for room: Chunk in manager.chunks.values():
			var sources: Array[Material] = [room._wall_material()]
			for site: Dictionary in room.native_doorway_sites.values():
				sources.append(site.material)
			for mat in sources:
				if mat is ShaderMaterial and mat.shader != null and not seen_shaders.has(mat.shader):
					seen_shaders[mat.shader] = true
					wall_shaders.append(mat)
	DoorwaySurface.prepare_render_samples(host, wall_shaders, theme)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	if not wander_only:
		_warm_photo_and_realm_effects(host, quad)
	var window_mat := ShaderMaterial.new()
	window_mat.shader = SelfReturnDoorSite.WINDOW_SHADER
	_add_effect_quad(host, quad, window_mat, Vector3(1.6, 2.4, 2.5))
	var vhs_mat := ShaderMaterial.new()
	vhs_mat.shader = preload("res://shaders/vhs_tape.gdshader")
	_add_effect_quad(host, quad, vhs_mat, Vector3(2.4, 2.4, 2.5))
	if warm_water:
		# Submit the same drop instances and sheet geometry the player creates
		# on the first wet physics tick, including a visit from a dry floor.
		var splash := Player.WaterInteraction.new()
		host.add_child(splash)
		splash._splash(Vector3(3.2, 2.4, 2.5), 0.7, Vector2.ZERO)
		splash.advance(0.12)


func _warm_photo_and_realm_effects(host: Node3D, quad: QuadMesh) -> void:
	# The viewfinder, photographic evidence and realm visits belong to Descent.
	var mask := ColorRect.new()
	mask.size = Vector2(64, 64)
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = preload("res://shaders/viewfinder_mask.gdshader")
	mask.material = mask_mat
	_view.add_child(mask)
	# The reticle's lines use a separate canvas pipeline. Draw them under the
	# loading screen so the first camera raise doesn't compile it during play.
	_view.add_child(PhotoCamera.PhotoReticle.new())
	# Warm portal anomaly crack + outer glow shaders.
	var portal_mat := ShaderMaterial.new()
	portal_mat.shader = PhotoAnomaly.PORTAL_SHADER
	if not PhotoAnomaly.PORTAL_PANOS.is_empty():
		portal_mat.set_shader_parameter("pano", PhotoAnomaly._portal_pano(PhotoAnomaly.PORTAL_PANOS[0]))
	_add_effect_quad(host, quad, portal_mat, Vector3(-0.8, 2.4, 2.5))
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = PhotoAnomaly.PORTAL_GLOW_SHADER
	_add_effect_quad(host, quad, glow_mat, Vector3(0.0, 2.4, 2.5))
	# A photographic realm leads through this luminous seam.
	var leak_mat := ShaderMaterial.new()
	leak_mat.shader = RealmDoorLeak.SHADER
	leak_mat.set_shader_parameter("strength", 0.5)
	_add_effect_quad(host, quad, leak_mat, Vector3(0.8, 2.4, 2.5))


func _add_effect_quad(parent: Node3D, quad: QuadMesh, material: Material, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh.position = pos
	parent.add_child(mesh)
