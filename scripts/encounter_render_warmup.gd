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
