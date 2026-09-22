extends SceneTree
## Actual generated rooms, native materials, preview-only breathing wall.
## godot --path . --script tools/preview_breathing_environments.gd
## -- --capture --theme=1 --out-dir=/tmp/liminal-breathing-environments
const Probe = preload("res://tools/lib/breathing_wall_probe.gd")
const SEED := 980712989
var themes: Array[int] = WorldGen.THEMES.duplicate()
var out_dir := "/tmp/liminal-breathing-environments"
var capture := false
var world: Node3D
var room: Chunk
var camera: Camera3D
var torch: SpotLight3D
var effect: Node3D
var label: Label
var current := 0
var elapsed := 0.0
var playing := true
var busy := true
var records: Array[Dictionary] = []
var report := {}
var angle := 0.0
var focus := Vector3.ZERO
var normal := Vector3.BACK
var across := Vector3.RIGHT
const SIZE_NAMES := ["small", "medium", "large"]
var size_index := 2
var all_sizes := false
var vary_size := false
var size_profiles: Array[Dictionary] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg == "--all-sizes": all_sizes = true
		if arg.begins_with("--size="):
			var requested := SIZE_NAMES.find(arg.trim_prefix("--size="))
			if requested >= 0: size_index = requested
		if arg.begins_with("--theme="): themes.assign([int(arg.trim_prefix("--theme="))])
		if arg.begins_with("--themes="):
			themes.clear()
			for value in arg.trim_prefix("--themes=").split(","): themes.append(int(value))
		if arg.begins_with("--out-dir="): out_dir = arg.trim_prefix("--out-dir=")
	call_deferred("_start")

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Visual preview needs a GPU renderer; omit --headless.")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	root.window_input.connect(_input)
	world = Node3D.new()
	root.add_child(world)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 18)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	if capture:
		DirAccess.make_dir_recursive_absolute(out_dir)
		for i in themes.size():
			current = i
			await _load_theme()
			if effect != null:
				for preset in (range(3) if all_sizes else [size_index]):
					size_index = preset
					torch.visible = true
					await _capture_current_size()
			else:
				records.append(report.duplicate(true))
		var file := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(records, "  "))
		await _cleanup()
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		var passed := records.size() == themes.size() * (3 if all_sizes else 1) and records.all(func(record: Dictionary) -> bool:
			return record.get("collision_pass", false) and record.get("original_mesh_restored", false) and record.get("original_material_restored", false) and record.get("all_band_resources_restored", false) and not record.has("capture_error"))
		quit(0 if passed else 1)
	else:
		await _load_theme()
		busy = false

func _capture_current_size() -> void:
	_apply_size()
	report["samples"] = []
	for pose in [0.0, 0.5, 1.0, 0.0]:
		effect.set_amount(pose)
		await physics_frame
		await physics_frame
		await _check_collision(pose)
		label.text = "%s — %s / %s\nActual room/materials + player-strength flashlight • preview only" % [DescentRun.THEME_NAMES[themes[current]], SIZE_NAMES[size_index], "rest" if pose == 0.0 else "bow %.0f%%" % (pose * 100)]
		for warm in 8:
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 60.0)
		var file := "%02d_%s_%s.png" % [themes[current], SIZE_NAMES[size_index], "rest" if pose == 0.0 else "half" if pose == 0.5 else "peak"]
		var error := root.get_texture().get_image().save_png(out_dir.path_join(file))
		if error != OK: report["capture_error"] = error
	torch.visible = false
	effect.set_amount(1.0)
	label.text = "%s — peak bow, native lighting only" % DescentRun.THEME_NAMES[themes[current]]
	for warm in 8:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	var native_error := root.get_texture().get_image().save_png(out_dir.path_join("%02d_%s_native.png" % [themes[current], SIZE_NAMES[size_index]]))
	if native_error != OK: report["capture_error"] = native_error
	effect.set_amount(0.0)
	report["original_mesh_restored"] = effect.mesh_node.mesh == effect.original
	report["original_material_restored"] = effect.mesh_node.material_override == effect.original_material
	report["all_band_resources_restored"] = effect.originals_restored()
	report["collision_pass"] = report.samples.all(func(sample: Dictionary) -> bool:
		return sample.misses == 0 and sample.max_collision_error_m < 0.01 and sample.max_band_error_m < 0.0001)
	records.append(report.duplicate(true))
	print(JSON.stringify(report))

func _load_theme() -> void:
	busy = true
	await _cleanup()
	var theme := themes[current]
	label.text = "Finding an ordinary wall in %s…" % DescentRun.THEME_NAMES[theme]
	await process_frame
	report = {"theme": theme, "name": DescentRun.THEME_NAMES[theme], "seed": SEED, "status": "no suitable patch", "samples": []}
	var selection := {}
	var ws := WorldGen.level_seed(SEED, theme)
	for at in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 1), Vector2i(-1, -1)]:
		room = Chunk.new(ws, at, theme)
		selection = _select_patch(room)
		if not selection.is_empty():
			break
		room.free()
		room = null
	if room == null:
		label.text = "%s: no safe patch in 9 sampled cells.\nN/P: next/previous environment" % DescentRun.THEME_NAMES[theme]
		return
	world.add_child(room)
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(theme)
	world.add_child(env)
	effect = Probe.new()
	room.add_child(effect)
	effect.attach(selection.face, selection.center, selection.size)
	var band_names: Array[String] = []
	for band: Dictionary in selection.companions:
		effect.attach_companion(band.mesh, band.transform)
		band_names.append(band.mesh.material_override.resource_name)
	report["attached_bands"] = band_names
	size_profiles = selection.profiles
	focus = room.to_global(selection.center)
	normal = selection.face.normal
	across = selection.face.u
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.06
	world.add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.10, -0.10, -0.06)
	torch.light_color = Color(0.88, 0.93, 1.0)
	torch.light_energy = 4.5
	torch.spot_range = 21.0
	torch.spot_angle = 46.0
	torch.spot_attenuation = 1.15
	torch.light_volumetric_fog_energy = 1.25
	torch.shadow_enabled = true
	camera.add_child(torch)
	angle = 0.28
	_update_camera()
	camera.current = true
	report.merge({"status": "preview ready", "cell": str(room.cell), "material": selection.face.material, "patch_size": str(selection.size), "center": str(selection.center), "normal": str(normal), "native_fragment_shading_preserved": true, "shader_mapping_anchored_to_rest": effect.motion_material != null}, true)
	report["triplanar_mapping_anchored_to_rest"] = effect.mapped_material != null
	_apply_size()
	elapsed = 0.0
	_update_label()
	await physics_frame

func _select_patch(chunk: Chunk) -> Dictionary:
	var scanner := SurfaceWear.new()
	scanner.host = chunk
	scanner.ctx = chunk._build_context
	for child in chunk.get_children(): scanner._scan(child, Transform3D.IDENTITY, -1)
	var meshes := chunk.find_children("*", "MeshInstance3D", true, false)
	var blockers: Array[Dictionary] = []
	for node: MeshInstance3D in meshes:
		if node.mesh == null or not node.visible: continue
		blockers.append({"mesh": node, "transform": _relative(node, chunk), "bounds": node.mesh.get_aabb()})
	for face: SurfaceWear.Face in scanner.walls:
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh) or face.size.x < 2.3 or face.size.y < 1.6:
			continue
		var companions := _wall_bands(face, blockers, chunk)
		var obstacles: Array[Dictionary] = []
		for blocker: Dictionary in blockers:
			if not companions.has(blocker): obstacles.append(blocker)
		for height in [2.2, 1.4]:
			var size_ := Vector2(minf(3.0, face.size.x - 0.3), minf(float(height), face.size.y - 0.3))
			for vertical in [1.35, 2.0, 2.6]:
				for offset in [0.0, -0.4, 0.4]:
					var center: Vector3 = face.center + face.u * (face.size.x - size_.x) * float(offset)
					center.y = clampf(chunk._floor_h() + float(vertical), face.center.y - face.size.y * 0.5 + size_.y * 0.5 + 0.1, face.center.y + face.size.y * 0.5 - size_.y * 0.5 - 0.1)
					if _patch_clear(face, center, size_, obstacles):
						return {"face": face, "center": center, "size": size_, "companions": companions, "profiles": _size_profiles(face, center, size_, obstacles)}
	return {}

func _wall_bands(face: SurfaceWear.Face, blockers: Array[Dictionary], chunk: Chunk) -> Array[Dictionary]:
	# Only generated wall strips: same backing plane and span, shallow depth,
	# direct room child, and a known architectural finish. Furniture stays solid.
	var finishes: Array = {
		0: ["darkwood", "crown"], 4: ["steel"], 5: ["asy_tile"],
		6: ["sch_red", "charcoal"], 7: ["brass", "mall_trim"],
		8: ["prison_dado", "prison_iron"],
	}.get(chunk.theme, [])
	var bands: Array[Dictionary] = []
	var wall_frame := Transform3D(Basis(face.u, face.v, face.normal), face.center)
	for item: Dictionary in blockers:
		var mesh: MeshInstance3D = item.mesh
		if mesh == face.mesh or mesh.get_parent() != chunk or not mesh.mesh is BoxMesh:
			continue
		if mesh.material_override == null or not mesh.material_override.resource_name in finishes:
			continue
		var bounds: AABB = wall_frame.affine_inverse() * item.transform * item.bounds
		if bounds.position.z < -0.015 or bounds.position.z > 0.04 or bounds.end.z > 0.13:
			continue
		if bounds.size.x < face.size.x * 0.95 or bounds.size.y >= bounds.size.x:
			continue
		if absf(bounds.position.x + face.size.x * 0.5) > 0.08 or absf(bounds.end.x - face.size.x * 0.5) > 0.08:
			continue
		if bounds.end.y < -face.size.y * 0.5 or bounds.position.y > face.size.y * 0.5:
			continue
		bands.append(item)
	return bands

func _size_profiles(face: SurfaceWear.Face, center: Vector3, base: Vector2, blockers: Array[Dictionary]) -> Array[Dictionary]:
	var small := {"size": Vector2(minf(1.8, base.x), minf(1.2, base.y)), "depth": 0.18}
	var medium := {"size": base, "depth": 0.30}
	var large := medium.duplicate()
	var offset := center - face.center
	var limit := Vector2(minf(6.0, face.size.x - 2.0 * absf(offset.dot(face.u)) - 0.2), minf(3.6, face.size.y - 2.0 * absf(offset.dot(face.v)) - 0.2))
	var best_score := base.x * base.y * 0.30
	for scale_ in [1.0, 0.8, 0.6]:
		var candidate := Vector2(maxf(base.x, limit.x * float(scale_)), maxf(base.y, limit.y * float(scale_)))
		for depth in [0.65, 0.50, 0.30]:
			var score: float = candidate.x * candidate.y * float(depth)
			if score > best_score and _patch_clear(face, center, candidate, blockers, float(depth)):
				large = {"size": candidate, "depth": float(depth)}
				best_score = score
	return [small, medium, large]

func _apply_size() -> void:
	if effect == null: return
	var profile := size_profiles[size_index]
	effect.configure_size(profile.size, profile.depth)
	report["size_preset"] = SIZE_NAMES[size_index]
	report["patch_size"] = str(profile.size)
	report["depth_m"] = profile.depth

func _update_label() -> void:
	if effect == null: return
	label.text = "%s — %s bulge: %.1f × %.1f m, %.0f cm deep%s\n1/2/3 sizes · V vary each breath · N/P environments · Space pause · R rest · B peak · ←/→ angle · F flashlight" % [DescentRun.THEME_NAMES[themes[current]], SIZE_NAMES[size_index], effect.patch_size.x, effect.patch_size.y, effect.amplitude * 100.0, " • varying" if vary_size else ""]

func _patch_clear(face: SurfaceWear.Face, center: Vector3, size_: Vector2, blockers: Array[Dictionary], depth := 0.30) -> bool:
	var eye := center + face.normal * (3.0 * cos(0.28)) + face.u * (3.0 * sin(0.28))
	if eye.x < 0.4 or eye.x > 11.6 or eye.z < 0.4 or eye.z > 11.6: return false
	var frame := Transform3D(Basis(face.u, face.v, face.normal), center)
	var envelope := AABB(Vector3(-size_.x * 0.5, -size_.y * 0.5, -0.02), Vector3(size_.x, size_.y, depth + 0.12))
	for blocker in blockers:
		if blocker.mesh == face.mesh: continue
		var bounds: AABB = frame.affine_inverse() * blocker.transform * blocker.bounds
		var camera_line: AABB = blocker.transform * blocker.bounds
		if envelope.intersects(bounds) or camera_line.intersects_segment(eye, center + face.normal * 0.1) != null:
			var material: Material = blocker.mesh.material_override
			var name_ := material.resource_name if material != null else "unknown"
			var reasons: Dictionary = report.get("blockers", {})
			reasons[name_] = int(reasons.get(name_, 0)) + 1
			report["blockers"] = reasons
			return false
	return true

func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func _check_collision(pose: float) -> void:
	var space := root.world_3d.direct_space_state
	var max_error := 0.0
	var missed := 0
	for fraction in [-0.4, 0.0, 0.4]:
		var x: float = fraction * effect.patch_size.x
		var expected: Vector3 = room.to_global(effect.frame * Vector3(x, 0, effect.height_at(x, 0)))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(expected + normal, expected - normal * 0.2))
		if hit.is_empty(): missed += 1
		else: max_error = maxf(max_error, hit.position.distance_to(expected))
	var band_error := 0.0
	var bent_vertices := 0
	if pose > 0.0:
		for band: Node3D in effect.companions:
			var source: PackedVector3Array = band.source_arrays[Mesh.ARRAY_VERTEX]
			var moved: PackedVector3Array = band.mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i in source.size():
				var before: Vector3 = band.from_mesh * source[i]
				var after: Vector3 = band.from_mesh * moved[i]
				var displacement: float = effect.height_at(before.x, before.y, pose)
				var expected := before + Vector3(0, 0, displacement)
				band_error = maxf(band_error, after.distance_to(expected))
				if displacement > 0.001: bent_vertices += 1
	report.samples.append({"amount": pose, "misses": missed, "max_collision_error_m": max_error,
		"max_band_error_m": band_error, "bent_band_vertices": bent_vertices})

func _update_camera() -> void:
	camera.position = focus + normal * (3.0 * cos(angle)) + across * (3.0 * sin(angle))
	camera.look_at(focus, Vector3.UP)

func _process(delta: float) -> bool:
	if not busy and effect != null and playing:
		var previous_cycle := floori(elapsed / 7.0)
		elapsed += delta
		var cycle := floori(elapsed / 7.0)
		if vary_size and cycle != previous_cycle:
			effect.set_amount(0.0)
			size_index = (size_index + 1 + posmod(WorldGen.h(SEED, themes[current], cycle, 23017), 2)) % 3
			_apply_size()
			_update_label()
		effect.set_amount(pow(sin(PI * fmod(elapsed, 7.0) / 7.0), 2.0))
	return false

func _input(event: InputEvent) -> void:
	if busy or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: quit()
		KEY_N, KEY_P:
			current = posmod(current + (1 if event.keycode == KEY_N else -1), themes.size())
			await _load_theme()
			busy = false
		KEY_SPACE: playing = not playing
		KEY_1, KEY_2, KEY_3:
			vary_size = false
			size_index = event.keycode - KEY_1
			_apply_size()
			_update_label()
		KEY_V:
			vary_size = not vary_size
			_update_label()
		KEY_F:
			if torch != null: torch.visible = not torch.visible
		KEY_R, KEY_B:
			playing = false
			if effect != null: effect.set_amount(0.0 if event.keycode == KEY_R else 1.0)
		KEY_LEFT, KEY_RIGHT:
			angle = clampf(angle + (-0.12 if event.keycode == KEY_LEFT else 0.12), -0.75, 0.75)
			if camera != null: _update_camera()

func _cleanup() -> void:
	if effect != null: effect.restore()
	effect = null
	camera = null
	torch = null
	room = null
	for child in world.get_children(): child.queue_free()
	await process_frame
	await physics_frame
